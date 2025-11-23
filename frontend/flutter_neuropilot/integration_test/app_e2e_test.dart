import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_neuropilot/core/routes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Create a short timer from chat input', (tester) async {
    await tester
        .pumpWidget(MaterialApp(routes: Routes.map, initialRoute: Routes.chat));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    await tester.enterText(find.byType(TextField), 'set timer for 5 sec');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Timers'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('Active'), findsWidgets);
  });
}

/// Basic Android E2E: create a short timer via chat input
/// and verify it appears in the Timers section.
