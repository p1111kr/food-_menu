import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meals/services/supabase_auth_service.dart';

// Screen for entering the email address to receive a password reset link
// The link opens the app via the existing deep link infrastructure which
// triggers the reset password flow in ResetPasswordScreen
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _authService = SupabaseAuthService();
  bool _isSending = false;
  bool _emailSent = false;

  static const _primaryColor = Color(0xFF562100);
  static const _bgColor = Color(0xFF0A0A0A);
  static const _cardColor = Color(0xFF1A1A1A);

  Future<void> _sendResetEmail() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showMessage('Please enter your email address.', isError: true);
      return;
    }

    if (!_isValidEmail(email)) {
      _showMessage('Please enter a valid email address.', isError: true);
      return;
    }

    setState(() => _isSending = true);

    try {
      // First verify the email belongs to a registered user
      debugPrint('[ForgotPasswordScreen] checking if email exists: $email');
      final exists = await _authService.emailExists(email);

      if (!exists) {
        debugPrint(
            '[ForgotPasswordScreen] email $email not found in registered users');
        _showMessage(
          'No account found with that email address.',
          isError: true,
        );
        setState(() => _isSending = false);
        return;
      }

      debugPrint('[ForgotPasswordScreen] sending reset email to $email');
      await _authService.resetPassword(email);
      debugPrint('[ForgotPasswordScreen] reset email sent successfully');

      setState(() => _emailSent = true);

      _showMessage('Reset link sent! Check your inbox.');
    } catch (e) {
      debugPrint('[ForgotPasswordScreen] failed to send reset email: $e');
      _showMessage('Failed to send reset email. Please try again.',
          isError: true);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          // Background glow
          Positioned(
            top: -100,
            right: -100,
            child: _buildGlowCircle(_primaryColor.withOpacity(0.5)),
          ),
          Positioned(
            bottom: -150,
            left: -100,
            child: _buildGlowCircle(const Color(0xFF160202).withOpacity(0.4)),
          ),

          // Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                children: [
                  const SizedBox(height: 40),

                  // App title
                  Text(
                    'Agerga',
                    style: GoogleFonts.philosopher(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 3.0,
                      shadows: [
                        Shadow(
                          color: _primaryColor.withOpacity(0.8),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Back button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.white54, size: 20),
                      label: const Text('Back to Sign In',
                          style: TextStyle(color: Colors.white54)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Card
                  ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: _cardColor.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(32),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: _emailSent
                            ? _buildEmailSentContent()
                            : _buildEmailForm(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reset Password',
          style: GoogleFonts.philosopher(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          "Enter your email address and we'll send you a link to reset your password.",
          style: TextStyle(color: Colors.white60, fontSize: 14),
        ),
        const SizedBox(height: 28),
        _buildGlassField(
          _emailController,
          'Email Address',
          Icons.email_outlined,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isSending ? null : _sendResetEmail,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              disabledBackgroundColor: _primaryColor.withOpacity(0.5),
            ),
            child: _isSending
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text('Send Reset Link',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailSentContent() {
    return Column(
      children: [
        const Icon(Icons.check_circle_outline, color: Colors.green, size: 64),
        const SizedBox(height: 16),
        Text(
          'Email Sent!',
          style: GoogleFonts.philosopher(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Check your inbox at ${_emailController.text.trim()} and tap the reset link to continue.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white60, fontSize: 14),
        ),
        const SizedBox(height: 8),
        const Text(
          'If you don\'t see the email, check your spam folder.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: () {
              setState(() => _emailSent = false);
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.white.withOpacity(0.3)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Send to another email',
                style: TextStyle(color: Colors.white70)),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Back to Sign In',
              style: TextStyle(color: Colors.white54)),
        ),
      ],
    );
  }

  Widget _buildGlowCircle(Color color) {
    return Container(
      width: 400,
      height: 400,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 100, spreadRadius: 50)],
      ),
    );
  }

  Widget _buildGlassField(
    TextEditingController controller,
    String hint,
    IconData icon,
  ) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      autocorrect: false,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _primaryColor),
        ),
      ),
    );
  }
}
