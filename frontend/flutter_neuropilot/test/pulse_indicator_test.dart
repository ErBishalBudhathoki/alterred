import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:altered/core/components/pulse_indicator.dart';

void main() {
  testWidgets('PulseIndicator renders correctly in idle mode',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PulseIndicator(mode: PulseMode.idle),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(PulseIndicator), findsOneWidget);
    expect(find.byIcon(Icons.mic_none), findsOneWidget);
  });

  testWidgets('PulseIndicator renders correctly in listening mode',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PulseIndicator(mode: PulseMode.listening),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500)); // Allow animation to start

    expect(find.byType(PulseIndicator), findsOneWidget);
    expect(find.byIcon(Icons.mic), findsOneWidget);
  });
}
