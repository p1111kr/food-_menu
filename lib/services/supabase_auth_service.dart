import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Exception thrown when a password recovery email mismatch is detected.
class RecoveryEmailMismatchException implements Exception {
  final String message;
  RecoveryEmailMismatchException(this.message);

  @override
  String toString() => message;
}

class OAuthFlowState {
  // Whether a Google OAuth sign in is in progress
  static bool inProgress = false;

  // Whether the signedIn event has already been handled by AppEntry
  static bool signedInHandled = false;

  // Timestamp when the OAuth browser was launched
  static DateTime? launchTime;

  // True once the app went to background after OAuth launch
  static bool wasBackgrounded = false;

  // Resets all flags back to idle.
  static void reset() {
    inProgress = false;
    signedInHandled = false;
    launchTime = null;
    wasBackgrounded = false;
  }

  // Marks that an OAuth flow is starting right now.
  static void markStarted() {
    inProgress = true;
    signedInHandled = false;
    launchTime = DateTime.now();
    wasBackgrounded = false;
  }
}

class SupabaseAuthService {
  final supabase = Supabase.instance.client;

  bool get isLoggedIn => supabase.auth.currentSession != null;

  Session? get currentSession => supabase.auth.currentSession;

  User? get currentUser => supabase.auth.currentUser;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) {
    debugPrint('[SupabaseAuthService] signUp for $email');
    return supabase.auth.signUp(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    debugPrint('[SupabaseAuthService] signIn for $email');
    return supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signInWithGoogle() async {
    debugPrint('[SupabaseAuthService] signInWithGoogle starting');
    try {
      OAuthFlowState.markStarted();
      debugPrint('[SupabaseAuthService] OAuthFlowState marked inProgress=true');

      final result = await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.flutter://login-callback/',
        queryParams: {
          'prompt': 'select_account',
        },
      );

      debugPrint(
          '[SupabaseAuthService] signInWithOAuth returned: launched=$result');
    } catch (e, stackTrace) {
      debugPrint('[SupabaseAuthService] signInWithGoogle failed: $e');
      debugPrint('[SupabaseAuthService] stackTrace: $stackTrace');
      OAuthFlowState.reset();
      rethrow;
    }
  }

  Future<void> closeOAuthBrowser() async {
    debugPrint(
        '[SupabaseAuthService] closeOAuthBrowser: native flow — no manual cleanup needed');
  }

  Future<void> ensureProfileExists() async {
    final user = currentUser;
    if (user == null) {
      debugPrint('[SupabaseAuthService] ensureProfileExists: no user');
      return;
    }

    debugPrint(
        '[SupabaseAuthService] ensureProfileExists: userId=${user.id} email=${user.email}');

    try {
      // Check if profile already exists existing user signing in again?
      final existingProfile = await supabase
          .from('profiles')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      if (existingProfile != null) {
        debugPrint(
            '[SupabaseAuthService] profile already exists — skipping creation');
        return;
      }

      // Create new profile for the first time Google OAuth user
      final displayName = user.userMetadata?['full_name'] ??
          user.userMetadata?['name'] ??
          user.email?.split('@').first ??
          'User';

      await supabase.from('profiles').insert({
        'id': user.id,
        'email': user.email,
        'name': displayName,
        'role': 'user',
        'created_at': DateTime.now().toIso8601String(),
      });
      debugPrint(
          '[SupabaseAuthService] profile created for Google user: $displayName');
    } catch (e) {
      debugPrint(
          '[SupabaseAuthService] ensureProfileExists error (non-fatal): $e');
    }
  }

  Future<void> resetPassword(String email) {
    debugPrint('[SupabaseAuthService] resetPassword for $email');
    return supabase.auth.resetPasswordForEmail(email);
  }

  // Checks if a user with the given email exists in the system.
  // verify the account is registered before sending a reset link.
  Future<bool> emailExists(String email) async {
    debugPrint('[SupabaseAuthService] emailExists check: $email');
    try {
      final result = await supabase
          .from('profiles')
          .select('id')
          .eq('email', email)
          .maybeSingle();
      final exists = result != null;
      debugPrint(
          '[SupabaseAuthService] emailExists: $email -> ${exists ? "EXISTS" : "NOT_FOUND"}');
      return exists;
    } catch (e) {
      debugPrint('[SupabaseAuthService] emailExists error: $e');

      return true;
    }
  }

  // Returns the email address of the currently authenticated user.
  // Returns `null` if no session exists or the email is unavailable.
  String? get recoverySessionEmail {
    final user = currentUser;
    if (user == null) {
      debugPrint('[SupabaseAuthService] recoverySessionEmail: no user');
      return null;
    }
    final email = user.email;
    debugPrint(
        '[SupabaseAuthService] recoverySessionEmail: $email (userId: ${user.id})');
    return email;
  }

  /// Updates the password only if the recovery session email matches

  /// This ensures the password reset link is bound to the specific account

  Future<UserResponse> updatePasswordSecurely({
    required String newPassword,
    required String expectedEmail,
  }) async {
    debugPrint('[SupabaseAuthService] updatePasswordSecurely starting');

    // 1. Validate session
    final session = currentSession;
    if (session == null) {
      debugPrint('[SupabaseAuthService] updatePasswordSecurely: no session');
      throw AuthSessionMissingException();
    }

    // 2. Get the email of the user in the recovery session
    final sessionEmail = recoverySessionEmail;
    debugPrint(
        '[SupabaseAuthService] updatePasswordSecurely: sessionEmail=$sessionEmail expectedEmail=$expectedEmail');

    if (sessionEmail == null) {
      debugPrint(
          '[SupabaseAuthService] updatePasswordSecurely: no email on session user');
      throw RecoveryEmailMismatchException(
        'Unable to verify your account. Please request a new reset link.',
      );
    }

    // 3. Verify the session email matches the expected recovery email
    if (sessionEmail.toLowerCase() != expectedEmail.toLowerCase()) {
      debugPrint('[SupabaseAuthService] *** EMAIL MISMATCH DETECTED *** '
          'sessionEmail=$sessionEmail expectedEmail=$expectedEmail');
      throw RecoveryEmailMismatchException(
        'Security verification failed: the reset link is bound to a different '
        'account. Please request a new reset link for your email address.',
      );
    }

    debugPrint(
        '[SupabaseAuthService] email verified OK — proceeding with password update');

    // 4. Perform the actual password update via gotrue
    final response = await supabase.auth.updateUser(
      UserAttributes(password: newPassword),
    );
    debugPrint(
        '[SupabaseAuthService] updatePassword completed: user=${response.user?.id}');
    return response;
  }

  // Direct password update for non recovery use cases

  Future<UserResponse> updatePassword(String newPassword) async {
    debugPrint('[SupabaseAuthService] updatePassword starting (direct)');
    final response = await supabase.auth.updateUser(
      UserAttributes(password: newPassword),
    );
    debugPrint(
        '[SupabaseAuthService] updatePassword completed: user=${response.user?.id}');
    return response;
  }

  Future<void> signOut() async {
    debugPrint('[SupabaseAuthService] signOut');
    await supabase.auth.signOut();
    debugPrint('[SupabaseAuthService] signOut complete');
  }
}
