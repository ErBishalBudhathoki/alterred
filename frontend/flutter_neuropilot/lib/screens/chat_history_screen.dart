import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/design_tokens.dart';
import 'package:altered/l10n/app_localizations.dart';
import '../core/routes.dart';
import '../state/session_state.dart';
import '../state/chat_store.dart';

/// Screen for displaying the user's chat history.
///
/// Shows a paginated list of chat sessions, allows searching, deleting, and renaming sessions,
/// and provides navigation to specific chats.
///
/// Implementation Details:
/// - Uses a [ListView.builder] for efficient rendering of the session list.
/// - Implements infinite scrolling by detecting when the user scrolls near the bottom.
/// - Uses [Dismissible] for swipe-to-delete functionality.
/// - Manages state (search query, pagination) via Riverpod providers.
///
/// Design Decisions:
/// - Infinite scroll improves performance with large history.
/// - Search functionality filters sessions server-side (implied by provider updates).
/// - Long-press on a session tile triggers the rename dialog for better mobile UX.
///
/// Behavioral Specifications:
/// - [initState]: Attaches a scroll listener for pagination and a session listener for real-time updates.
/// - [onRefresh]: Resets pagination and reloads the session list.
/// - [onDismissed]: Deletes the session via [ChatStore] and invalidates the provider.
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
    // Pagination listener
    _scrollCtl.addListener(() {
      final pos = _scrollCtl.position;
      if (pos.pixels >= pos.maxScrollExtent - 48) {
        final p = ref.read(chatSessionsPageProvider);
        ref.read(chatSessionsPageProvider.notifier).state = p + 1;
      }
    });
    // Attach real-time listener for sessions
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
          // Search Bar
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
          // Session List
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

  /// Formats the last activity timestamp into a human-readable string.
  String _formatActivity(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
