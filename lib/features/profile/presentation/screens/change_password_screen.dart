// Change password for email/password accounts (Firebase Auth, not Firestore).
// Reauthenticate with current password, then call updatePassword.

import 'package:culinary_coach_app/app/theme/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:io';

// Lets email/password users change password via Firebase Auth reauthentication.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  // StatefulWidget: setState toggles loading spinner and password visibility icons.
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool _isGoogleUser(User user) {
    return user.providerData.any((p) => p.providerId == 'google.com');
  }

  bool _isPasswordUser(User user) {
    return user.providerData.any((p) => p.providerId == 'password');
  }

  // Reauth with current password, then updatePassword on Firebase Auth.
  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    final email = (user?.email ?? '').trim();
    if (user == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are not signed in.')),
      );
      return;
    }

    if (_isGoogleUser(user) && !_isPasswordUser(user)) {
      _showError(
        'This account uses Google sign-in. Password changes must be managed through Google.',
      );
      return;
    }

    final current = _currentController.text;
    final next = _newController.text;
    final confirm = _confirmController.text;

    if (current.isEmpty) {
      _showError('Please enter your current password.');
      return;
    }
    if (next.length < 8) {
      _showError('New password must be at least 8 characters.');
      return;
    }
    if (next != confirm) {
      _showError('Passwords do not match.');
      return;
    }
    if (current == next) {
      _showError('New password must be different from current password.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      // async/await: reauthenticate, then Firebase Auth updatePassword (not Firestore).
      final credential = EmailAuthProvider.credential(
        email: email,
        password: current,
      );
      await user.reauthenticateWithCredential(credential);
      try {
        await user.updatePassword(next);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login') {
          // Re-auth again and retry once.
          await user.reauthenticateWithCredential(credential);
          await user.updatePassword(next);
        }
        rethrow;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully.')),
      );
      // Success: pop back to ProfileScreen.
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      debugPrint('Change password failed: ${e.code} - ${e.message}');
      _showError(_mapAuthError(e));
    } on FirebaseException catch (e) {
      debugPrint('Change password failed: ${e.code} - ${e.message}');
      _showError('Could not update password. Please try again.');
    } on SocketException {
      _showError('No internet connection. Check your network.');
    } on Exception {
      _showError('Could not update password. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Current password is incorrect.';
      case 'weak-password':
        return 'New password is too weak. Use at least 8 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection. Check your network.';
      case 'requires-recent-login':
        return 'Please log in again before changing your password.';
      case 'user-mismatch':
      case 'user-not-found':
        return 'Account session error. Please log in again.';
      default:
        return 'Could not update password. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final isGoogle = _isGoogleUser(user);

    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        child: Column(
          children: [
            _SectionCard(
              title: 'Security',
              child: isGoogle
                  ? Text(
                      'Your account uses Google sign-in. Password changes must be managed through your Google account.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                    )
                  : Column(
                      children: [
                        _PasswordField(
                          label: 'Current password',
                          controller: _currentController,
                          obscure: !_showCurrent,
                          onToggle: () =>
                              setState(() => _showCurrent = !_showCurrent),
                        ),
                        const SizedBox(height: 10),
                        _PasswordField(
                          label: 'New password',
                          controller: _newController,
                          obscure: !_showNew,
                          onToggle: () => setState(() => _showNew = !_showNew),
                        ),
                        const SizedBox(height: 10),
                        _PasswordField(
                          label: 'Confirm new password',
                          controller: _confirmController,
                          obscure: !_showConfirm,
                          onToggle: () =>
                              setState(() => _showConfirm = !_showConfirm),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 18),
            if (!isGoogle)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submit,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_reset_rounded),
                  label: Text(_isLoading ? 'Updating...' : 'Update Password'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.outline),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.label,
    required this.controller,
    required this.obscure,
    required this.onToggle,
  });

  final String label;
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          const Icon(Icons.password_rounded, color: AppColors.primaryDeep, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                hintText: label,
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          IconButton(
            onPressed: onToggle,
            icon: Icon(
              obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
              color: AppColors.textMuted,
              size: 20,
            ),
            splashRadius: 18,
          ),
        ],
      ),
    );
  }
}

