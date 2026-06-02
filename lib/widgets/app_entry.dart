import "dart:async";
import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "package:app_links/app_links.dart";

import "package:meals/services/supabase_auth_service.dart";
import "package:meals/screens/tabs.dart";
import "package:meals/screens/auth.dart";
import "package:meals/screens/reset_password_screen.dart";
import "package:meals/screens/admin_dashboard.dart";

class AppEntry extends StatefulWidget {
  const AppEntry({super.key});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final _authService = SupabaseAuthService();
  final _appLinks = AppLinks();

  // The initial screen to show.
  late final Widget _initialScreen;

  // Whether we already handled a password recovery event
  bool _recoveryHandled = false;

  // Auth state subscription kept so we can cancel it on dispose
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<Uri>? _appLinksSubscription;

  static const _primaryColor = Color.fromARGB(255, 131, 57, 0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialScreen = _computeInitialScreen();
    _setupAuthListener();
    _setupAppLinksDebugListener();
    _logOAuthDebug("AppEntry initialized");
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _appLinksSubscription?.cancel();
    _logOAuthDebug("AppEntry disposed");
    super.dispose();
  }

  // Lifecycle observer — OAuth browser tracking
  // Tracks app lifecycle transitions to detect OAuth return.

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _logOAuthDebug("Lifecycle: $state");

    if (state == AppLifecycleState.paused && OAuthFlowState.inProgress) {
      OAuthFlowState.wasBackgrounded = true;
      _logOAuthDebug("App backgrounded during OAuth");
    }

    if (state == AppLifecycleState.resumed && OAuthFlowState.wasBackgrounded) {
      OAuthFlowState.wasBackgrounded = false;
      final elapsed = OAuthFlowState.launchTime != null
          ? DateTime.now().difference(OAuthFlowState.launchTime!).inMilliseconds
          : 0;
      _logOAuthDebug("App resumed after OAuth (elapsed: ${elapsed}ms)");

      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        _logOAuthDebug(
            "Session found on resume — OAuth completed. session.userId=${session.user.id}");
      } else {
        _logOAuthDebug(
            "No session on resume — waiting for auth callback or checking app_links...");

        _checkLatestAppLink();
      }
    }
  }

  // Initial screen
  Widget _computeInitialScreen() {
    final session = Supabase.instance.client.auth.currentSession;
    final hasSession = session != null;
    _logOAuthDebug("Session on init: ${hasSession ? "exists" : "null"}");

    if (!hasSession) {
      _logOAuthDebug("No session -> AuthScreen");
      return const AuthScreen();
    }

    return const _SessionGate();
  }

  // Auth state listener — SINGLE source of truth
  void _setupAuthListener() {
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      _logOAuthDebug(
          "Auth event: ${data.event} | session=${data.session != null ? "exists" : "null"} | userId=${data.session?.user.id} | email=${data.session?.user.email}");

      if (data.event == AuthChangeEvent.passwordRecovery) {
        _logOAuthDebug("*** PASSWORD RECOVERY event detected ***");

        if (!_recoveryHandled) {
          _recoveryHandled = true;

          _navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
            (route) => false,
          );
          _logOAuthDebug("Navigated to ResetPasswordScreen");
        }
      }
      // Handle signedIn emitted by supabase_flutter after:
      // Email password sign in supabase auth signInWithPassword
      // OAuth PKCE callback deep link getSessionFromUrl
      else if (data.event == AuthChangeEvent.signedIn) {
        _logOAuthDebug("*** SIGNED IN event detected ***");

        if (OAuthFlowState.inProgress) {
          // OAuth flow handle it here
          if (OAuthFlowState.signedInHandled) {
            _logOAuthDebug("OAuth signedIn already handled — skipping");
            return;
          }
          OAuthFlowState.signedInHandled = true;
          OAuthFlowState.inProgress = false;
          _logOAuthDebug("OAuth signedIn — proceeding with profile/nav");

          _authService.closeOAuthBrowser();
          _handleOAuthSignIn();
        } else {
          // Email password signin AuthScreen handles navigation
          _logOAuthDebug(
              "Non-OAuth sign-in (email/password) — AuthScreen handles nav");
        }
      }
      // Handle tokenRefreshed — indicates session is alive post-OAuth
      else if (data.event == AuthChangeEvent.tokenRefreshed) {
        _logOAuthDebug("Token refreshed — session alive");
      }
      // Handle signedOut to reset back to AuthScreen
      else if (data.event == AuthChangeEvent.signedOut) {
        _logOAuthDebug("*** SIGNED OUT event detected ***");
        _recoveryHandled = false;
        OAuthFlowState.reset();

        _navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthScreen()),
          (route) => false,
        );
        _logOAuthDebug("Navigated to AuthScreen after sign out");
      }
    });
  }

  void _setupAppLinksDebugListener() {
    _appLinksSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        _logOAuthDebug("AppLinks stream URI received: $uri");
        _logDeepLinkDetails(uri);
      },
      onError: (Object error, StackTrace stackTrace) {
        _logOAuthDebug("AppLinks stream error: $error");
        debugPrintStack(
          stackTrace: stackTrace,
          label: "[AppEntry] AppLinks stream stack",
        );
      },
    );

    _appLinks.getInitialLink().then((uri) {
      _logOAuthDebug("AppLinks initial URI: $uri");
      if (uri != null) {
        _logDeepLinkDetails(uri);
      }
    }).catchError((Object error) {
      _logOAuthDebug("AppLinks initial URI error: $error");
    });
  }

  // FALLBACK Checks the latest URI from app_links to see if supabase_flutter's
  //deep link handler missed the OAuth callback.

  void _checkLatestAppLink() {
    _appLinks.getLatestLink().then((Uri? latestUri) {
      if (latestUri != null) {
        _logOAuthDebug("FALLBACK: latest URI from app_links: $latestUri");
        _logDeepLinkDetails(latestUri);

        if (latestUri.scheme == "io.supabase.flutter" &&
            latestUri.host == "login-callback" &&
            latestUri.queryParameters.containsKey("code")) {
          _logOAuthDebug(
              "FALLBACK: OAuth code found in latest URI — exchanging...");

          Supabase.instance.client.auth.getSessionFromUrl(latestUri).then((_) {
            _logOAuthDebug("FALLBACK: getSessionFromUrl completed");

            final newSession = Supabase.instance.client.auth.currentSession;
            if (newSession != null) {
              _logOAuthDebug(
                  "FALLBACK: Session established after manual exchange!");
              if (!OAuthFlowState.signedInHandled) {
                OAuthFlowState.signedInHandled = true;
                OAuthFlowState.inProgress = false;
                _handleOAuthSignIn();
              }
            } else {
              _logOAuthDebug(
                  "FALLBACK: getSessionFromUrl completed but no session");
            }
          }).catchError((Object e) {
            _logOAuthDebug("FALLBACK: getSessionFromUrl error: $e");
          });
        }
      } else {
        _logOAuthDebug("FALLBACK: no latest URI available");
      }
    }).catchError((Object e) {
      _logOAuthDebug("FALLBACK: error checking latest URI: $e");
    });
  }

  // OAuth post signin handler

  // Handles post-OAuth sign in: ensures profile, fetches role, navigates.
  Future<void> _handleOAuthSignIn() async {
    _logOAuthDebug("_handleOAuthSignIn starting");

    // Ensure profile exists for new Google users
    await _authService.ensureProfileExists();

    // Fetch role
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      _logOAuthDebug("_handleOAuthSignIn: no session — aborting");
      return;
    }

    bool isAdmin = false;
    try {
      final profile = await Supabase.instance.client
          .from("profiles")
          .select("role")
          .eq("id", session.user.id)
          .maybeSingle();
      final role = profile?["role"] as String?;
      isAdmin = role == "admin";
      _logOAuthDebug("role=$role isAdmin=$isAdmin");
    } catch (e) {
      _logOAuthDebug("role fetch error: $e");
    }

    // Navigate to the appropriate home screen
    _navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) =>
            isAdmin ? const AdminDashboardScreen() : const TabScreen(),
      ),
      (route) => false,
    );
    _logOAuthDebug("Navigated to home (isAdmin=$isAdmin)");
  }

  // Debug logging

  void _logOAuthDebug(String message) {
    debugPrint("[AppEntry] $message");
  }

  void _logDeepLinkDetails(Uri uri) {
    _logOAuthDebug(
        "Deep link details: scheme=${uri.scheme} host=${uri.host} path=${uri.path}");
    _logOAuthDebug("Deep link query=${uri.queryParameters}");

    final error = uri.queryParameters["error"];
    final errorCode = uri.queryParameters["error_code"];
    final errorDescription = uri.queryParameters["error_description"];
    if (error != null || errorCode != null || errorDescription != null) {
      _logOAuthDebug(
          "OAuth callback error: error=$error error_code=$errorCode error_description=$errorDescription");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      key: const ValueKey("app_entry_material"),
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: _primaryColor,
        ),
        textTheme: GoogleFonts.latoTextTheme(),
      ),
      home: _initialScreen,
    );
  }
}

class _SessionGate extends StatefulWidget {
  const _SessionGate();

  @override
  State<_SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<_SessionGate> {
  Widget? _destination;

  @override
  void initState() {
    super.initState();
    _resolveRole();
  }

  Future<void> _resolveRole() async {
    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      debugPrint("[_SessionGate] No session -> AuthScreen");
      if (mounted) {
        setState(() => _destination = const AuthScreen());
      }
      return;
    }

    bool isAdmin = false;
    try {
      final profile = await Supabase.instance.client
          .from("profiles")
          .select("role")
          .eq("id", session.user.id)
          .maybeSingle();
      final role = profile?["role"] as String?;
      isAdmin = role == "admin";
      debugPrint(
          "[_SessionGate] Session: userId=${session.user.id} role=$role");
    } catch (e) {
      debugPrint("[_SessionGate] Role fetch error: $e");
    }

    if (mounted) {
      setState(() {
        _destination =
            isAdmin ? const AdminDashboardScreen() : const TabScreen();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_destination == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0A),
        body: Center(
          child: CircularProgressIndicator(color: Colors.white54),
        ),
      );
    }
    return _destination!;
  }
}
