import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:altered/state/chat_store.dart';
import 'package:altered/core/chat_message.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('Create session and list sessions sorted by last activity', () async {
    final store = ChatStore();
    final s1 = await store.createSession(title: 'Alpha');
    await Future.delayed(const Duration(milliseconds: 5));
    final s2 = await store.createSession(title: 'Beta');
    final list = await store.listSessions();
    expect(list.first.id, s2.id);
    expect(list.length, 2);
    expect(s1.id.isNotEmpty, true);
  });

  test('Add assistant message updates preview and unread; markRead clears',
      () async {
    final store = ChatStore();
    final s = await store.createSession(title: 'Chat');
    await store.addMessage(
        s.id, ChatMessage(role: 'assistant', content: 'Hello world'));
    var list = await store.listSessions();
    final found = list.firstWhere((x) => x.id == s.id);
    expect(found.preview, 'Hello world');
    expect(found.unreadCount, 1);
    await store.markRead(s.id);
    list = await store.listSessions();
    final after = list.firstWhere((x) => x.id == s.id);
    expect(after.unreadCount, 0);
  });

  test('Create more than 20 sessions preserves all in storage', () async {
    final store = ChatStore();
    for (int i = 0; i < 25; i++) {
      await store.createSession(title: 'S$i');
    }
    final firstPage = await store.listSessions();
    expect(firstPage.length, 20);
    final all = await store.listSessions(offset: 0, limit: 1000);
    expect(all.length, 25);
  });
}
