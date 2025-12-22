import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/components/np_app_bar.dart';
import '../core/components/np_text_field.dart';
import '../core/components/np_password_field.dart';
import '../core/components/np_button.dart';
import '../core/components/np_checkbox.dart';
import '../core/components/np_snackbar.dart';
import '../core/design_tokens.dart';
import '../core/routes.dart';
import '../state/auth_state.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Screen for user authentication via email/password or Google Sign-In.
///
/// Implementation Details:
/// - Uses [AuthController] for authentication logic.
/// - Validates email and password inputs before submission.
/// - Supports "Remember Me" functionality (UI only, logic handled by [AuthController]).
///
/// Design Decisions:
/// - Clean, centralized form with clear feedback via [NpSnackbar].
/// - Separated "Forgot Password" flow for better UX.
///
/// Behavioral Specifications:
/// - Validates inputs on submit.
/// - Redirects to [ChatScreen] on success.
/// - Shows error snackbar on failure.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _remember = true;
  bool _loading = false;

  bool get _validEmail {
    final s = _email.text.trim();
    final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return re.hasMatch(s);
  }

  bool get _validPassword => _password.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (!_validEmail || !_validPassword) {
      NpSnackbar.show(context, 'Please enter a valid email and password',
          type: NpSnackType.warning);
      return;
    }
    setState(() => _loading = true);
    final ctl = ref.read(authControllerProvider);
    try {
      await ctl.signInEmail(_email.text.trim(), _password.text.trim());
      if (!mounted) return;
      setState(() => _loading = false);
      Navigator.of(context).pushNamedAndRemoveUntil(Routes.chat, (r) => false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      String msg;
      switch (e.code) {
        case 'user-not-found':
          msg = 'No user found for that email.';
          break;
        case 'wrong-password':
          msg = 'Wrong password provided.';
          break;
        case 'invalid-email':
          msg = 'The email address is badly formatted.';
          break;
        case 'user-disabled':
          msg = 'This user account has been disabled.';
          break;
        case 'invalid-credential':
          msg =
              'Invalid credentials. If you signed up with Google, please use that button.';
          break;
        default:
          msg = 'Login failed: ${e.message}';
      }
      NpSnackbar.show(context, msg, type: NpSnackType.destructive);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      NpSnackbar.show(context, 'An unexpected error occurred: $e',
          type: NpSnackType.destructive);
    }
  }

  Future<void> _google() async {
    setState(() => _loading = true);
    final ctl = ref.read(authControllerProvider);
    final ok = await ctl.signInGoogle();
    if (!mounted) return;
    setState(() => _loading = false);
    if (!ok) {
      NpSnackbar.show(context, 'Google sign-in failed',
          type: NpSnackType.destructive);
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil(Routes.chat, (r) => false);
  }

  Future<void> _reset() async {
    if (!_validEmail) {
      NpSnackbar.show(context, 'Please enter a valid email address',
          type: NpSnackType.warning);
      return;
    }
    final ctl = ref.read(authControllerProvider);
    try {
      await ctl.sendPasswordReset(_email.text.trim());
      if (!mounted) return;
      NpSnackbar.show(context, 'Check your inbox for reset link',
          type: NpSnackType.info);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String msg;
      switch (e.code) {
        case 'user-not-found':
          msg = 'No user found for that email.';
          break;
        case 'invalid-email':
          msg = 'The email address is badly formatted.';
          break;
        default:
          msg = 'Password reset failed: ${e.message}';
      }
      NpSnackbar.show(context, msg, type: NpSnackType.destructive);
    } catch (e) {
      if (!mounted) return;
      NpSnackbar.show(context, 'An unexpected error occurred: $e',
          type: NpSnackType.destructive);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const NpAppBar(title: 'Sign In'),
      body: Padding(
        padding: const EdgeInsets.all(DesignTokens.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Welcome Back', style: Theme.of(context).textTheme.titleLarge)
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.2, end: 0),
            const SizedBox(height: DesignTokens.spacingMd),
            NpTextField(
                    controller: _email,
                    label: 'Email Address',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next)
                .animate()
                .fadeIn(delay: 100.ms, duration: 400.ms)
                .slideY(begin: 0.2, end: 0),
            const SizedBox(height: DesignTokens.spacingSm),
            NpPasswordField(controller: _password, label: 'Password')
                .animate()
                .fadeIn(delay: 200.ms, duration: 400.ms)
                .slideY(begin: 0.2, end: 0),
            const SizedBox(height: DesignTokens.spacingSm),
            Row(children: [
              NpCheckbox(
                  value: _remember,
                  onChanged: (v) => setState(() => _remember = v ?? false)),
              const SizedBox(width: DesignTokens.spacingSm),
              const Text('Remember me'),
              const Spacer(),
              TextButton(
                  onPressed: _loading ? null : _reset,
                  child: const Text('Forgot password?')),
            ])
                .animate()
                .fadeIn(delay: 300.ms, duration: 400.ms)
                .slideY(begin: 0.2, end: 0),
            const SizedBox(height: DesignTokens.spacingMd),
            NpButton(
                    label: 'Sign In',
                    onPressed: _loading ? null : _submit,
                    icon: Icons.login,
                    loading: _loading)
                .animate()
                .fadeIn(delay: 400.ms, duration: 400.ms)
                .slideY(begin: 0.2, end: 0),
            const SizedBox(height: DesignTokens.spacingSm),
            NpButton(
                    label: 'Continue with Google',
                    onPressed: _loading ? null : _google,
                    icon: Icons.account_circle,
                    type: NpButtonType.secondary,
                    loading: _loading)
                .animate()
                .fadeIn(delay: 500.ms, duration: 400.ms)
                .slideY(begin: 0.2, end: 0),
            const SizedBox(height: DesignTokens.spacingLg),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text("Don't have an account?"),
              TextButton(
                  onPressed: () =>
                      Navigator.of(context).pushReplacementNamed(Routes.signup),
                  child: const Text('Sign Up')),
            ])
                .animate()
                .fadeIn(delay: 600.ms, duration: 400.ms)
                .slideY(begin: 0.2, end: 0),
          ],
        ),
      ),
    );
  }
}
