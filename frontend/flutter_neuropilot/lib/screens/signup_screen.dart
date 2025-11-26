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

/// Screen for new user registration.
///
/// Implementation Details:
/// - Collects name, email, and password.
/// - Enforces password strength requirements (length, case, numbers, special chars).
/// - Requires Terms of Service acceptance.
///
/// Design Decisions:
/// - Real-time password strength indicator guides users to create secure passwords.
/// - Multi-step validation ensures data integrity before API call.
///
/// Behavioral Specifications:
/// - Updates password strength bar as user types.
/// - Blocks submission if inputs are invalid or terms not accepted.
/// - Creates account via [AuthController] and redirects to chat on success.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});
  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _accepted = false;
  bool _loading = false;

  int get _strength {
    final s = _password.text;
    int score = 0;
    if (s.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(s)) score++;
    if (RegExp(r'[0-9]').hasMatch(s)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(s)) score++;
    return score;
  }

  bool get _validEmail {
    final s = _email.text.trim();
    final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return re.hasMatch(s);
  }

  Future<void> _submit() async {
    if (!_accepted) {
      NpSnackbar.show(context, 'Please accept Terms and Privacy',
          type: NpSnackType.warning);
      return;
    }
    if (!_validEmail || _strength < 3) {
      NpSnackbar.show(context, 'Please enter a valid email and strong password',
          type: NpSnackType.warning);
      return;
    }
    if (_firstName.text.trim().isEmpty || _lastName.text.trim().isEmpty) {
      NpSnackbar.show(context, 'Please enter your first and last name',
          type: NpSnackType.warning);
      return;
    }
    setState(() => _loading = true);
    final ctl = ref.read(authControllerProvider);
    final displayName = '${_firstName.text.trim()} ${_lastName.text.trim()}';
    try {
      await ctl.signUpEmail(_email.text.trim(), _password.text.trim(),
          displayName: displayName);
      if (!mounted) return;
      setState(() => _loading = false);
      Navigator.of(context).pushNamedAndRemoveUntil(Routes.chat, (r) => false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      String msg;
      switch (e.code) {
        case 'email-already-in-use':
          msg = 'Email is already used';
          break;
        case 'invalid-email':
          msg = 'The email address is badly formatted.';
          break;
        case 'weak-password':
          msg = 'The password provided is too weak.';
          break;
        case 'operation-not-allowed':
          msg = 'Email/password accounts are not enabled.';
          break;
        default:
          msg = 'Signup failed: ${e.message}';
      }
      NpSnackbar.show(context, msg, type: NpSnackType.destructive);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      NpSnackbar.show(context, 'An unexpected error occurred: $e',
          type: NpSnackType.destructive);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final barColor = switch (_strength) {
      0 || 1 => DesignTokens.error,
      2 => DesignTokens.warning,
      _ => DesignTokens.success,
    };
    final barValue = (_strength.clamp(0, 4)) / 4.0;
    return Scaffold(
      appBar: const NpAppBar(title: 'Sign Up'),
      body: Padding(
        padding: const EdgeInsets.all(DesignTokens.spacingLg),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Create Account', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: DesignTokens.spacingMd),
          Row(
            children: [
              Expanded(
                child: NpTextField(
                    controller: _firstName,
                    label: 'First Name',
                    textInputAction: TextInputAction.next),
              ),
              const SizedBox(width: DesignTokens.spacingSm),
              Expanded(
                child: NpTextField(
                    controller: _lastName,
                    label: 'Last Name',
                    textInputAction: TextInputAction.next),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spacingSm),
          NpTextField(
              controller: _email,
              label: 'Email Address',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next),
          const SizedBox(height: DesignTokens.spacingSm),
          NpPasswordField(controller: _password, label: 'Password'),
          const SizedBox(height: DesignTokens.spacingXs),
          Row(children: [
            Expanded(
                child: LinearProgressIndicator(
                    value: barValue,
                    color: barColor,
                    backgroundColor: cs.secondaryContainer)),
            const SizedBox(width: DesignTokens.spacingSm),
            Text(_strength <= 1
                ? 'Weak'
                : (_strength == 2 ? 'Medium' : 'Strong')),
          ]),
          const SizedBox(height: DesignTokens.spacingSm),
          Row(children: [
            NpCheckbox(
                value: _accepted,
                onChanged: (v) => setState(() => _accepted = v ?? false)),
            const SizedBox(width: DesignTokens.spacingSm),
            const Expanded(
                child:
                    Text('I agree to the Terms of Service and Privacy Policy')),
          ]),
          const SizedBox(height: DesignTokens.spacingMd),
          NpButton(
              label: 'Create Account',
              onPressed: _loading ? null : _submit,
              icon: Icons.person_add,
              loading: _loading),
          const SizedBox(height: DesignTokens.spacingLg),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('Already have an account?'),
            TextButton(
                onPressed: () =>
                    Navigator.of(context).pushReplacementNamed(Routes.login),
                child: const Text('Log In')),
          ]),
        ]),
      ),
    );
  }
}
