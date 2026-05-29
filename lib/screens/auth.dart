import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:meals/screens/admin_dashboard.dart';
import 'package:meals/screens/tabs.dart';
import 'package:meals/screens/forgot_password_screen.dart';
import 'package:meals/providers/meals_provider.dart';
import 'package:meals/services/supabase_auth_service.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _isLogin = true;
  bool _isPasswordVisible = false;
  final _supabaseAuth = SupabaseAuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();

  //Handles a successful email password authentication.
  //Ensures profile exists, fetches role, and navigates to the correct screen.
  Future<void> _onAuthenticated() async {
    debugPrint('[AuthScreen] _onAuthenticated: user authenticated');

    ref.invalidate(mealsProvider);
    ref.invalidate(allMealsProvider);

    // Fetch role from Supabase Profiles table
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    debugPrint('[AuthScreen] authenticated user id: ${user?.id}');

    bool isAdmin = false;
    if (user != null) {
      final profile = await supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      debugPrint('[AuthScreen] fetched profile: $profile');
      final role = profile?['role'] as String?;
      debugPrint('[AuthScreen] fetched role: $role');

      isAdmin = role == 'admin';
      debugPrint('[AuthScreen] admin detection result: $isAdmin');
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (ctx) =>
            isAdmin ? const AdminDashboardScreen() : const TabScreen(),
      ),
    );
  }

  // Handles the Google OAuth sign-in/sign-up button press.
  // still have some issues here
  Future<void> _handleGoogleSignIn() async {
    debugPrint('[AuthScreen] _handleGoogleSignIn: starting');
    try {
      await _supabaseAuth.signInWithGoogle();
      // The browser/CCT is now open for Google authentication.
      debugPrint('[AuthScreen] _handleGoogleSignIn: browser opened for OAuth');
    } catch (e) {
      debugPrint('[AuthScreen] _handleGoogleSignIn failed: $e');
      _showError(e.toString());
    }
  }

  // our SUBMIT LOGIC

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty ||
        password.isEmpty ||
        (!_isLogin && confirmPassword.isEmpty)) {
      _showError('Please fill in all fields');
      return;
    }

    if (!_isLogin && password != confirmPassword) {
      _showError('Passwords do not match!');
      return;
    }

    try {
      if (_isLogin) {
        await _supabaseAuth.signIn(
          email: email,
          password: password,
        );
      } else {
        final response = await _supabaseAuth.signUp(
          email: email,
          password: password,
        );

        if (response.user != null) {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Verification email sent. Please confirm your email before logging in.',
              ),
            ),
          );

          setState(() {
            _isLogin = true;
            _confirmPasswordController.clear();
            _passwordController.clear();
          });
          return;
        }
      }

      ref.invalidate(mealsProvider);
      ref.invalidate(allMealsProvider);

      // Navigate based on role
      await _onAuthenticated();
    } catch (e) {
      _showError(e.toString());
    }
  }

  // our FORGOT PASSWORD LOGIC
  void _navigateToForgotPassword() {
    debugPrint('[AuthScreen] navigating to ForgotPasswordScreen');
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deviceSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: _buildGlowCircle(const Color(0xFF562100).withOpacity(0.5)),
          ),
          Positioned(
            bottom: -150,
            left: -100,
            child: _buildGlowCircle(const Color(0xFF160202).withOpacity(0.4)),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: deviceSize.height * 0.45,
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(
                      'https://static.spotapps.co/spots/22/8e7e936bc9421b91a95c2be8be5898/full'),
                  fit: BoxFit.cover,
                  colorFilter:
                      ColorFilter.mode(Colors.black54, BlendMode.darken),
                ),
              ),
            ),
          ),
          Positioned(
            top: deviceSize.height * 0.15,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Agerga',
                style: GoogleFonts.philosopher(
                  fontSize: 54,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 4.0,
                  shadows: [
                    Shadow(
                        color: const Color(0xFF562100).withOpacity(0.8),
                        blurRadius: 20),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    height: deviceSize.height * 0.58,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A).withOpacity(0.8),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          Text(
                            _isLogin ? 'Sign In' : 'Sign Up',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 24),
                          if (!_isLogin) ...[
                            _buildGlassField(_nameController, 'Full Name',
                                Icons.person_outline),
                            const SizedBox(height: 16),
                          ],
                          _buildGlassField(
                              _emailController, 'Email', Icons.mail_outline),
                          const SizedBox(height: 16),
                          _buildGlassField(_passwordController, 'Password',
                              Icons.lock_outline,
                              isPassField: true),
                          if (!_isLogin) ...[
                            const SizedBox(height: 16),
                            _buildGlassField(_confirmPasswordController,
                                'Confirm Password', Icons.lock_reset_outlined,
                                isPassField: true),
                          ],

                          // our FORGOT PASSWORD BUTTON
                          if (_isLogin)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _navigateToForgotPassword,
                                child: const Text(
                                  'Forgot password?',
                                  style: TextStyle(
                                      color: Color(0xFF562100),
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),

                          const SizedBox(height: 24),
                          _buildGradientButton(),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _handleGoogleSignIn,
                            icon: const Icon(Icons.login),
                            label: const Text('Continue with Google'),
                          ),
                          const SizedBox(height: 20),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isLogin = !_isLogin;
                                if (_isLogin)
                                  _confirmPasswordController.clear();
                              });
                            },
                            child: Text(
                              _isLogin
                                  ? "Need an account? Create one"
                                  : "Have an account? Sign in",
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  //  HELPERS
  Widget _buildGlassField(
      TextEditingController controller, String hint, IconData icon,
      {bool isPassField = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassField ? !_isPasswordVisible : false,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        suffixIcon: isPassField
            ? IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  color: Colors.white38,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              )
            : null,
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF562100))),
      ),
    );
  }

  Widget _buildGlowCircle(Color color) {
    return Container(
      width: 400,
      height: 400,
      decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
        BoxShadow(color: color, blurRadius: 100, spreadRadius: 50)
      ]),
    );
  }

  Widget _buildGradientButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
            colors: [Color(0xFF562100), Color(0xFF160202)]),
      ),
      child: ElevatedButton(
        onPressed: _submit,
        style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16))),
        child: Text(_isLogin ? 'LOG IN' : 'SIGN UP',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
