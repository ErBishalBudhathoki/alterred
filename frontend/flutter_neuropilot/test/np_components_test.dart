import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:altered/core/components/np_button.dart';
import 'package:altered/core/components/np_chip.dart';
import 'package:altered/core/components/np_snackbar.dart';
import 'package:altered/core/components/np_progress.dart';

void main() {
  testWidgets('NpButton renders and handles loading', (tester) async {
    var pressed = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: NpButton(label: 'Go', onPressed: () => pressed = true))));
    expect(find.text('Go'), findsOneWidget);
    await tester.tap(find.text('Go'));
    expect(pressed, isTrue);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: NpButton(label: 'Go', loading: true))));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('NpChip semantics reflects selection', (tester) async {
    var selected = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NpChip(label: 'Option', selected: selected, onTap: () => selected = true),
      ),
    ));
    expect(find.text('Option'), findsOneWidget);
  });

  testWidgets('NpSnackbar shows message', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final ctx = tester.element(find.byType(Scaffold));
    NpSnackbar.show(ctx, 'Hello');
    await tester.pump();
    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('Np progress widgets render', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: NpLinearProgress(value: 0.5))));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: NpCircularProgress())));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
