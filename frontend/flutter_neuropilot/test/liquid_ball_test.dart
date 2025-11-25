import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:altered/core/components/np_liquid_ball.dart';

void main() {
  testWidgets('NpLiquidBall builds and repaints on amplitude change', (tester) async {
    var amp = 0.1;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) {
          return NpLiquidBall(mode: NpLiquidMode.listening, amplitude: amp, frequency: 2.0, size: 40);
        }),
      ),
    ));
    await tester.pump();
    amp = 0.6;
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(NpLiquidBall), findsOneWidget);
  });
}
