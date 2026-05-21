import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meals/screens/tabs.dart';
import 'package:meals/screens/auth.dart';
import 'package:meals/screens/admin_dashboard.dart';

// THEME CONFIGURATION
final theme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    brightness: Brightness.dark,
    seedColor: const Color.fromARGB(255, 131, 57, 0),
  ),
  textTheme: GoogleFonts.latoTextTheme(),
);

void main() async {
  //Ensures Flutter is ready before we talk to SharedPreferences
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  final isAdmin = prefs.getBool('isAdmin') ?? false;

  runApp(
    ProviderScope(
      child: App(
        startScreen: isLoggedIn
            ? (isAdmin ? const AdminDashboardScreen() : const TabScreen())
            : const AuthScreen(),
      ),
    ),
  );
}

class App extends StatelessWidget {
  const App({super.key, required this.startScreen});

  final Widget startScreen;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: startScreen,
    );
  }
}
