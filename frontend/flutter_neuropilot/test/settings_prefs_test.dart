import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:altered/l10n/app_localizations.dart';
import 'package:altered/screens/settings_screen.dart';
import 'package:altered/state/auth_state.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Flutter test binding imported via flutter_test

// Widget test for Settings persistence.
// Renders `SettingsScreen`, manipulates sliders, and verifies values
// persisted to `SharedPreferences`.
void main() {
  testWidgets('Settings sliders persist to SharedPreferences', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tester.view.physicalSize = const Size(1024, 2048);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authUserProvider.overrideWith((ref) => Stream<User?>.value(null)),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 800));
    final sliders = find.byType(Slider);
    expect(sliders, findsWidgets);

    await tester.drag(sliders.at(0), const Offset(50, 0));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.drag(sliders.at(1), const Offset(80, 0));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.drag(sliders.at(2), const Offset(60, 0));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.pump();

    final p = await SharedPreferences.getInstance();
    expect(p.getInt('pulse_threshold_percent'), isNotNull);
    expect(p.getInt('pulse_speed_ms'), isNotNull);
    expect(p.getDouble('pulse_max_freq'), isNotNull);
  });
}
