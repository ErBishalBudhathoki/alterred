import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_neuropilot/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_neuropilot/screens/chat_screen.dart' as chat;
import 'package:flutter_neuropilot/state/session_state.dart';
import 'package:flutter_neuropilot/services/api_client.dart';

class FakeApiClient extends ApiClient {
  FakeApiClient() : super(baseUrl: 'http://example.com');
  @override
  Future<Map<String, dynamic>> createCountdown(String query) async {
    final lower = query.toLowerCase();
    if (lower.contains('5')) {
      final target =
          DateTime.now().add(const Duration(minutes: 5)).toIso8601String();
      return {
        'ok': true,
        'target': target,
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
        'warnings': [15, 10, 5, 2],
        'timer_id': 't1s'
      };
    }
    final target =
        DateTime.now().add(const Duration(minutes: 1)).toIso8601String();
    return {
      'ok': true,
      'target': target,
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
  testWidgets('Displays HM status for active timer', (tester) async {
    await tester.pumpWidget(_buildApp(const chat.ChatScreen()));
    // Type a create command
    await tester.enterText(find.byType(TextField), 'set timer for 5 min');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    // Expect HM formatting
    expect(find.textContaining('Timer set for 00:05:00.'), findsOneWidget);
    expect(find.textContaining('of 00:05:00.'), findsWidgets);
  });

  testWidgets('Completed timer fades out and disappears', (tester) async {
    await tester.pumpWidget(_buildApp(const chat.ChatScreen()));
    await tester.enterText(find.byType(TextField), 'set timer for 1 sec');
    await tester.tap(find.text('Send'));
    await tester.pump();
    // Let ticker run for >1s
    await tester.pump(const Duration(seconds: 2));
    // Allow fade-out to complete
    await tester.pump(const Duration(milliseconds: 800));
    // No timer cards should remain
    expect(find.byIcon(Icons.timer), findsNothing);
    expect(find.textContaining('Completed'), findsNothing);
  });
}
