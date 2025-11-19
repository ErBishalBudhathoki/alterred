import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_neuropilot/core/components/np_dialog.dart';
import 'package:flutter_neuropilot/core/components/np_bottom_sheet.dart';
import 'package:flutter_neuropilot/core/components/np_avatar.dart';
import 'package:flutter_neuropilot/core/components/np_badge.dart';
import 'package:flutter_neuropilot/core/components/np_switch.dart';
import 'package:flutter_neuropilot/core/components/np_checkbox.dart';
import 'package:flutter_neuropilot/core/components/np_radio.dart';

void main() {
  testWidgets('NpDialog shows and closes', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    final ctx = tester.element(find.byType(SizedBox));
    NpDialog.show(context: ctx, title: 'Confirm', content: const Text('Proceed?'), primaryLabel: 'OK');
    await tester.pumpAndSettle();
    expect(find.text('Confirm'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm'), findsNothing);
  });

  testWidgets('NpBottomSheet shows contents', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    final ctx = tester.element(find.byType(SizedBox));
    NpBottomSheet.show(context: ctx, child: const Text('Sheet')); 
    await tester.pump();
    expect(find.text('Sheet'), findsOneWidget);
  });

  testWidgets('NpAvatar renders initials', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: NpAvatar(name: 'Ada Lovelace', size: 40))));
    expect(find.text('AL'), findsOneWidget);
  });

  testWidgets('NpBadge renders text', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: NpBadge(text: '3'))));
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('Switch/Checkbox/Radio interact', (tester) async {
    bool s = false;
    bool c = false;
    String? g;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          NpSwitch(value: s, onChanged: (v) => s = v),
          NpCheckbox(value: c, onChanged: (v) => c = v ?? false),
          NpRadio<String>(value: 'a', groupValue: g, onChanged: (v) => g = v),
        ]),
      ),
    ));
    await tester.tap(find.byType(Switch));
    await tester.tap(find.byType(Checkbox));
    await tester.tap(find.byType(Radio<String>));
    expect(s, isTrue);
    expect(c, isTrue);
    expect(g, equals('a'));
  });
}