import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/design_tokens.dart';
import 'package:altered/l10n/app_localizations.dart';
import '../core/routes.dart';
import '../state/session_state.dart';
import '../state/chat_store.dart';

class ChatHistoryScreen extends ConsumerStatefulWidget {
  const ChatHistoryScreen({super.key});
  @override
  ConsumerState<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends ConsumerState<ChatHistoryScreen> {
  final ScrollController _scrollCtl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtl.addListener(() {
      final pos = _scrollCtl.position;
      if (pos.pixels >= pos.maxScrollExtent - 48) {
        final p = ref.read(chatSessionsPageProvider);
        ref.read(chatSessionsPageProvider.notifier).state = p + 1;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final store = ref.read(chatStoreProvider);
        await store.attachSessionsListener();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _scrollCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(chatSessionsProvider);
    final activeId = ref.watch(chatSessionIdProvider);
    final qCtl = TextEditingController(text: ref.read(chatSearchQueryProvider));

    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.chatHistoryTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l.newChatLabel,
            onPressed: () async {
              final nav = Navigator.of(context);
              final store = ref.read(chatStoreProvider);
              final s = await store.createSession();
              ref.read(chatSessionIdProvider.notifier).state = s.id;
              nav.pushReplacementNamed(Routes.chat);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(DesignTokens.spacingMd),
            child: TextField(
              controller: qCtl,
              decoration: const InputDecoration(
                hintText: 'Search chats',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) {
                ref.read(chatSessionsPageProvider.notifier).state = 0;
                ref.read(chatSearchQueryProvider.notifier).state = v;
              },
            ),
          ),
          Expanded(
            child: sessionsAsync.when(
              data: (sessions) {
                if (sessions.isEmpty) {
                  return Center(child: Text(l.noChatsLabel));
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.read(chatSessionsPageProvider.notifier).state = 0;
                    ref.invalidate(chatSessionsProvider);
                  },
                  child: ListView.builder(
                    controller: _scrollCtl,
                    itemCount: sessions.length,
                    itemBuilder: (ctx, i) {
                      final s = sessions[i];
                      final isActive = s.id == activeId;
                      return Dismissible(
                        key: ValueKey('chat-${s.id}'),
                        background: Container(
                          color: DesignTokens.error,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        secondaryBackground: Container(
                          color: DesignTokens.error,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) async {
                          final store = ref.read(chatStoreProvider);
                          await store.deleteSession(s.id);
                          ref.invalidate(chatSessionsProvider);
                        },
                        child: ListTile(
                          title: Text(
                            s.title == null || s.title!.isEmpty
                                ? s.id
                                : s.title!,
                            style: isActive
                                ? Theme.of(context).textTheme.titleMedium
                                : Theme.of(context).textTheme.bodyLarge,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (s.preview != null && s.preview!.isNotEmpty)
                                Text(
                                  s.preview!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              Text(
                                _formatActivity(s.lastActivity),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          trailing: s.unreadCount > 0
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: DesignTokens.secondary,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    '${s.unreadCount}',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSecondary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : null,
                          onLongPress: () async {
                            final titleCtl =
                                TextEditingController(text: s.title ?? '');
                            final newTitle = await showDialog<String>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(l.editChatTitleLabel),
                                content: TextField(
                                  controller: titleCtl,
                                  decoration:
                                      const InputDecoration(hintText: 'Title'),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: Text(l.cancelLabel),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(
                                        ctx, titleCtl.text.trim()),
                                    child: Text(l.saveLabel),
                                  ),
                                ],
                              ),
                            );
                            if (newTitle != null) {
                              final store = ref.read(chatStoreProvider);
                              await store.updateTitle(s.id, newTitle);
                              ref.invalidate(chatSessionsProvider);
                            }
                          },
                          onTap: () async {
                            final nav = Navigator.of(context);
                            ref.read(chatSessionIdProvider.notifier).state =
                                s.id;
                            final store = ref.read(chatStoreProvider);
                            await store.markRead(s.id);
                            nav.pushReplacementNamed(Routes.chat);
                          },
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
            ),
          ),
        ],
      ),
    );
  }

  String _formatActivity(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
