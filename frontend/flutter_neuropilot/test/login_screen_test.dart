import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:altered/core/routes.dart';
// Screens imported via Routes; direct imports not required here.
import 'package:altered/state/auth_state.dart';
import 'package:altered/core/components/np_button.dart';
import 'package:altered/l10n/app_localizations.dart';

class _AuthControllerStub extends AuthController {
  _AuthControllerStub(super.ref);
  bool emailOk = true;
  bool googleOk = false;
  @override
  Future<bool> signInEmail(String email, String password) async => emailOk;
  @override
  Future<bool> signInGoogle() async => googleOk;
}

void main() {
  testWidgets('Login invalid email shows warning', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authUserProvider.overrideWith((ref) => Stream.value(null)),
        authControllerProvider
            .overrideWith((ref) => _AuthControllerStub(ref)..emailOk = false),
      ],
      child: MaterialApp(
        routes: Routes.map,
        initialRoute: Routes.login,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'bad');
    await tester.enterText(find.byType(TextField).last, 'pass');
    await tester.tap(find.widgetWithText(NpButton, 'Sign In'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
        find.text('Please enter a valid email and password'), findsOneWidget);
  });
}

/// Widget tests for `LoginScreen` validating error feedback
/// when invalid credentials are submitted.
