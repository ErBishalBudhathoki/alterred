import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:altered/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:altered/screens/chat_screen.dart' as chat;
import 'package:altered/state/session_state.dart';
import 'package:altered/services/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeApiClient extends ApiClient {
  FakeApiClient() : super(baseUrl: 'http://example.com');

  @override
  Future<Map<String, dynamic>> health() async {
    return {'ok': true, 'status': 'ok'};
  }

  @override
  Future<Map<String, dynamic>> createCountdown(String query) async {
    final lower = query.toLowerCase();
    if (lower.contains('5')) {
      final target =
          DateTime.now().add(const Duration(minutes: 5)).toIso8601String();
      return {
        'ok': true,
        'target': target,
        'duration_seconds': 300,
        'warnings': [15, 10, 5, 2],
        'timer_id': 't5'
      };
    }
    if (lower.contains('1 sec') ||
        lower.contains('1s') ||
        lower.contains('1 second')) {
      final target =
          DateTime.now().add(const Duration(seconds: 1)).toIso8601String();
      return {
        'ok': true,
        'target': target,
        'duration_seconds': 1,
        'warnings': [15, 10, 5, 2],
        'timer_id': 't1s'
      };
    }
    final target =
        DateTime.now().add(const Duration(minutes: 1)).toIso8601String();
    return {
      'ok': true,
      'target': target,
      'duration_seconds': 60,
      'warnings': [15, 10, 5, 2],
      'timer_id': 't1'
    };
  }
}

Widget _buildApp(Widget child, {ApiClient? api}) {
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(api ?? FakeApiClient()),
    ],
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
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});

  testWidgets('Displays HM status for active timer', (tester) async {
    await tester.pumpWidget(_buildApp(const chat.ChatScreen()));
    await tester.pump(const Duration(milliseconds: 50));
    // Type a create command
    await tester.enterText(find.byType(TextField), 'set timer for 5 min');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));

    final textWidgets = tester.widgetList<Text>(find.byType(Text));
    final textValues =
        textWidgets.map((w) => w.data).whereType<String>().toList();
    // ignore: avoid_print
    print(
        'Timer test visible texts (${textValues.length}): ${textValues.take(80).join(' | ')}');

    // Expect HM formatting
    expect(find.textContaining('Timer set for 00:05:00.'), findsOneWidget);
    expect(find.byKey(const ValueKey('timer-card-t5')), findsOneWidget);
    expect(find.textContaining('of 00:05:00'), findsWidgets);
  });

  testWidgets('Completed timer fades out and disappears', (tester) async {
    await tester.pumpWidget(_buildApp(const chat.ChatScreen()));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.enterText(find.byType(TextField), 'set timer for 1 sec');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('timer-card-t1s')), findsOneWidget);
    // Let ticker run for >1s
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 200));
    // No timer cards should remain
    expect(find.byKey(const ValueKey('timer-card-t1s')), findsNothing);
    expect(find.textContaining('Completed'), findsNothing);
  });
}
