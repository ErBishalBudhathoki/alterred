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
    final ok = await ctl.signInEmail(_email.text.trim(), _password.text.trim());
    setState(() => _loading = false);
    if (!ok) {
      NpSnackbar.show(context, 'Invalid email or password',
          type: NpSnackType.destructive);
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil(Routes.chat, (r) => false);
  }

  Future<void> _google() async {
    setState(() => _loading = true);
    final ctl = ref.read(authControllerProvider);
    final ok = await ctl.signInGoogle();
    setState(() => _loading = false);
    if (!ok) {
      NpSnackbar.show(context, 'Google sign-in failed',
          type: NpSnackType.warning);
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
    await ctl.sendPasswordReset(_email.text.trim());
    NpSnackbar.show(context, 'Check your inbox for reset link',
        type: NpSnackType.info);
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
            Text('Welcome Back', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: DesignTokens.spacingMd),
            NpTextField(
                controller: _email,
                label: 'Email Address',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next),
            const SizedBox(height: DesignTokens.spacingSm),
            NpPasswordField(controller: _password, label: 'Password'),
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
            ]),
            const SizedBox(height: DesignTokens.spacingMd),
            NpButton(
                label: 'Sign In',
                onPressed: _loading ? null : _submit,
                icon: Icons.login,
                loading: _loading),
            const SizedBox(height: DesignTokens.spacingSm),
            NpButton(
                label: 'Continue with Google',
                onPressed: _loading ? null : _google,
                icon: Icons.account_circle,
                type: NpButtonType.secondary,
                loading: _loading),
            const SizedBox(height: DesignTokens.spacingLg),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text("Don't have an account?"),
              TextButton(
                  onPressed: () =>
                      Navigator.of(context).pushReplacementNamed(Routes.signup),
                  child: const Text('Sign Up')),
            ]),
          ],
        ),
      ),
    );
  }
}
