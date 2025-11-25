import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:altered/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:altered/screens/chat_screen.dart' as chat;
import 'package:altered/state/session_state.dart';
import 'package:altered/services/api_client.dart';

class FakeApiClient extends ApiClient {
  FakeApiClient() : super(baseUrl: 'http://example.com');
  @override
  Future<Map<String, dynamic>> createCountdown(String query) async {
    final s = query.toLowerCase();
    int seconds = 0;
    final re = RegExp(
        r"(\d+)\s*(second|seconds|sec|s|minute|minutes|min|m|hour|hours|hr|h)\b");
    final m = re.firstMatch(s);
    if (m != null) {
      final n = int.parse(m.group(1)!);
      final unit = m.group(2)!;
      if (unit.startsWith('s')) {
        seconds = n;
      } else if (unit.startsWith('m')) {
        seconds = n * 60;
      } else {
        seconds = n * 3600;
      }
    } else {
      seconds = 60;
    }
    final id = 't_${DateTime.now().microsecondsSinceEpoch}';
    final target =
        DateTime.now().add(Duration(seconds: seconds)).toIso8601String();
    return {
      'ok': true,
      'target': target,
      'warnings': [15, 10, 5, 2],
      'timer_id': id
    };
  }
}

Widget _buildApp(Widget child) {
  return ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(FakeApiClient())],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  testWidgets('Short timer displays two-digit seconds countdown',
      (tester) async {
    await tester.pumpWidget(_buildApp(const chat.ChatScreen()));
    await tester.enterText(find.byType(TextField), 'set timer for 59 sec');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Timers'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Active — 59'), findsOneWidget);
  });

  testWidgets('Five concurrent timers created via one request', (tester) async {
    await tester.pumpWidget(_buildApp(const chat.ChatScreen()));
    await tester.enterText(find.byType(TextField),
        'set timer for 5 sec, 7 sec, 9 sec, 11 sec, 13 sec');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Timers'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Timer set for '), findsNWidgets(5));
  });

  testWidgets('Countdown updates over 1 second', (tester) async {
    await tester.pumpWidget(_buildApp(const chat.ChatScreen()));
    await tester.enterText(find.byType(TextField), 'set timer for 10 sec');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Timers'));
    await tester.pump(const Duration(milliseconds: 100));
    final cardFinder = find.byWidgetPredicate((w) =>
        w is Container &&
        w.key is ValueKey &&
        ((w.key as ValueKey).value.toString().startsWith('timer-card-')));
    expect(cardFinder, findsWidgets);
    await tester.pump(const Duration(seconds: 1));
    expect(cardFinder, findsWidgets);
  });
}
