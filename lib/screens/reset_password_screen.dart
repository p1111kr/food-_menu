import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meals/screens/auth.dart';
import 'package:meals/services/supabase_auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Screen shown after the user clicks the password reset deep link.

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = SupabaseAuthService();

  bool _isUpdating = false;
  bool _isPasswordVisible = false;
  bool _isConfirmVisible = false;
  bool _updateSuccessful = false;

  // The email from the recovery session  used for email bound security
  String? _recoveryEmail;

  // Whether the session email is still being resolved
  bool _isCheckingSession = true;

  // Whether a valid recovery session exists
  bool _hasValidSession = false;

  static const _primaryColor = Color(0xFF562100);
  static const _bgColor = Color(0xFF0A0A0A);
  static const _cardColor = Color(0xFF1A1A1A);

  @override
  void initState() {
    super.initState();
    _initializeRecovery();
  }

  // Checks the current auth session and extracts the recovery email
  Future<void> _initializeRecovery() async {
    debugPrint('[ResetPasswordScreen] _initializeRecovery started');

    // Wait briefly for the session to be fully established

    await Future.delayed(const Duration(milliseconds: 500));

    // 1. Validate session exists
    final session = _authService.currentSession;
    debugPrint(
        '[ResetPasswordScreen] session: ${session != null ? "exists" : "null"}');

    if (session == null) {
      debugPrint('[ResetPasswordScreen] No session found');
      if (mounted) {
        setState(() {
          _isCheckingSession = false;
          _hasValidSession = false;
        });
      }
      return;
    }

    debugPrint('[ResetPasswordScreen] Session user ID: ${session.user.id}');
    debugPrint(
        '[ResetPasswordScreen] Session user email: ${session.user.email}');

    // 2. Extract the recovery email from the sessions user
    final email = _authService.recoverySessionEmail;
    debugPrint('[ResetPasswordScreen] recoverySessionEmail: $email');

    if (mounted) {
      setState(() {
        _recoveryEmail = email;
        _isCheckingSession = false;
        _hasValidSession = email != null;
      });
    }
  }

  // Validates inputs and calls SupabaseAuthService updatePasswordSecurely
  // with the recovery email for emai bound security
  Future<void> _updatePassword() async {
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;
    debugPrint('[ResetPasswordScreen] _updatePassword: starting validation');

    // Input validation
    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      _showMessage('Please fill in all fields.', isError: true);
      return;
    }

    if (newPassword != confirmPassword) {
      _showMessage('Passwords do not match!', isError: true);
      return;
    }

    if (newPassword.length < 6) {
      _showMessage('Password must be at least 6 characters long.',
          isError: true);
      return;
    }

    // Security Check recovery email
    if (_recoveryEmail == null) {
      debugPrint('[ResetPasswordScreen] No recovery email available');
      _showMessage(
        'Unable to verify your account. Please request a new reset link.',
        isError: true,
      );
      return;
    }

    // Session check
    if (_authService.currentSession == null) {
      debugPrint('[ResetPasswordScreen] No valid session for password update');
      _showMessage(
        'Your reset link has expired or is invalid. Please request a new one.',
        isError: true,
      );
      return;
    }

    setState(() => _isUpdating = true);

    try {
      debugPrint(
          '[ResetPasswordScreen] updating password for recovery email: $_recoveryEmail');

      // Use the email bound secure update method
      await _authService.updatePasswordSecurely(
        newPassword: newPassword,
        expectedEmail: _recoveryEmail!,
      );

      debugPrint('[ResetPasswordScreen] password update succeeded');

      if (mounted) {
        setState(() => _updateSuccessful = true);
        _showMessage('Password updated successfully!');
      }
    } catch (e) {
      debugPrint('[ResetPasswordScreen] password update failed: $e');

      String message;

      if (e is RecoveryEmailMismatchException) {
        // Email mismatch security breach attempt or stale link
        message = e.message;
      } else if (e is AuthSessionMissingException) {
        message =
            'Your reset session has expired. Please request a new reset link.';
      } else {
        final errorStr = e.toString();
        if (errorStr.contains('weak_password') ||
            errorStr.contains('WeakPassword')) {
          message =
              'Password is too weak. Use at least 6 characters with a mix of letters, numbers, and symbols.';
        } else if (errorStr.contains('expired') ||
            errorStr.contains('expired_token') ||
            errorStr.contains('token_expired')) {
          message = 'This reset link has expired. Please request a new one.';
        } else if (errorStr.contains('already_used') ||
            errorStr.contains('already used')) {
          message =
              'This reset link has already been used. Please request a new one.';
        } else if (errorStr.contains('session_not_found') ||
            (errorStr.contains('session') && errorStr.contains('not found'))) {
          message =
              'Your reset session has expired. Please request a new reset link.';
        } else {
          message = 'Failed to update password. Please try again.';
        }
      }

      _showMessage(message, isError: true);
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  // Shows a SnackBar message to the user.
  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
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
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                children: [
                  const SizedBox(height: 40),
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
                  if (_hasValidSession && !_updateSuccessful)
                    Text(
                      'Reset Your Password',
                      style: GoogleFonts.philosopher(
                        fontSize: 18,
                        color: Colors.white70,
                      ),
                    ),
                  const SizedBox(height: 40),
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
                        child: _buildCardContent(),
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

  // Renders the appropriate card content based on state.
  Widget _buildCardContent() {
    if (_isCheckingSession) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: CircularProgressIndicator(color: Colors.white54),
        ),
      );
    }

    if (!_hasValidSession) {
      return _buildInvalidSessionContent();
    }

    if (_updateSuccessful) {
      return _buildSuccessContent();
    }

    return _buildResetForm();
  }

  Widget _buildInvalidSessionContent() {
    return Column(
      children: [
        const Icon(Icons.link_off, color: Colors.redAccent, size: 64),
        const SizedBox(height: 16),
        Text(
          'Invalid or Expired Link',
          style: GoogleFonts.philosopher(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'This password reset link is invalid or has expired.\n\n'
          'Please request a new reset link to continue.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white60, fontSize: 14),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AuthScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Back to Sign In',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildResetForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose a new password',
          style: GoogleFonts.philosopher(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),

        // Show the recovery email being used for this reset
        if (_recoveryEmail != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _primaryColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.email_outlined, color: _primaryColor, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _recoveryEmail!,
                    style: TextStyle(
                      color: _primaryColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

        const Text(
          'Your password must be at least 6 characters long.',
          style: TextStyle(color: Colors.white60, fontSize: 13),
        ),
        const SizedBox(height: 24),
        _buildGlassField(
          _newPasswordController,
          'New Password',
          Icons.lock_outline,
          isPassField: true,
          isPasswordVisible: _isPasswordVisible,
          onToggleVisibility: () =>
              setState(() => _isPasswordVisible = !_isPasswordVisible),
        ),
        const SizedBox(height: 16),
        _buildGlassField(
          _confirmPasswordController,
          'Confirm New Password',
          Icons.lock_reset_outlined,
          isPassField: true,
          isPasswordVisible: _isConfirmVisible,
          onToggleVisibility: () =>
              setState(() => _isConfirmVisible = !_isConfirmVisible),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isUpdating ? null : _updatePassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              disabledBackgroundColor: _primaryColor.withOpacity(0.5),
            ),
            child: _isUpdating
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text('Update Password',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessContent() {
    return Column(
      children: [
        const Icon(Icons.check_circle_outline, color: Colors.green, size: 64),
        const SizedBox(height: 16),
        Text(
          'Password Updated!',
          style: GoogleFonts.philosopher(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Your password has been changed successfully. You can now sign in with your new password.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white60, fontSize: 14),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () {
              // Sign out so the old session is cleared,
              // then navigate to auth screen
              _authService.signOut();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AuthScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Sign In',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ),
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
    IconData icon, {
    required bool isPassField,
    required bool isPasswordVisible,
    required VoidCallback onToggleVisibility,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassField ? !isPasswordVisible : false,
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
                  isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  color: Colors.white38,
                  size: 20,
                ),
                onPressed: onToggleVisibility,
              )
            : null,
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
