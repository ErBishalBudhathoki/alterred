import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:altered/l10n/app_localizations.dart';
import 'package:altered/screens/settings_screen.dart';
import 'package:altered/state/auth_state.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
    FlutterSecureStorage.setMockInitialValues({});
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

    await tester.pump(const Duration(milliseconds: 200));

    const storage = FlutterSecureStorage();
    final speed = await storage.read(key: 'pulse_speed_ms');
    final threshold = await storage.read(key: 'pulse_threshold_percent');
    final maxFreq = await storage.read(key: 'pulse_max_freq');
    expect(speed, isNotNull);
    expect(threshold, isNotNull);
    expect(maxFreq, isNotNull);
  });
}
