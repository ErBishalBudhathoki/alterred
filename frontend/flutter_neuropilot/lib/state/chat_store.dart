import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../core/chat_message.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint, VoidCallback;
import 'package:firebase_core/firebase_core.dart';

/// Represents a single chat session with metadata.
///
/// Implementation Details:
/// - Stores session ID, title, creation/activity timestamps, and unread count.
/// - Includes a preview snippet for list displays.
/// - Provides `toMap` and `fromMap` for serialization.
class ChatSession {
  final String id;
  String? title;
  DateTime createdAt;
  DateTime lastActivity;
  int unreadCount;
  String? preview;
  ChatSession({
    required this.id,
    this.title,
    DateTime? createdAt,
    DateTime? lastActivity,
    int? unreadCount,
    this.preview,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastActivity = lastActivity ?? DateTime.now(),
        unreadCount = unreadCount ?? 0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'lastActivity': lastActivity.toIso8601String(),
        'unreadCount': unreadCount,
        'preview': preview,
      };

  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is String) {
      return DateTime.tryParse(v) ?? DateTime.now();
    }
    if (v is Timestamp) {
      return v.toDate();
    }
    return DateTime.now();
  }

  static ChatSession fromMap(Map<String, dynamic> m) => ChatSession(
        id: (m['id'] as String?) ?? '',
        title: m['title'] as String?,
        createdAt: _parseDate(m['createdAt']),
        lastActivity: _parseDate(m['lastActivity']),
        unreadCount:
            (m['unreadCount'] is num) ? (m['unreadCount'] as num).toInt() : 0,
        preview: m['preview'] as String?,
      );
}

/// Manages chat sessions and messages, handling local storage and Firestore sync.
///
/// Implementation Details:
/// - Uses a dual-write approach: SharedPreferences for local cache, Firestore for cloud sync.
/// - Maintains an in-memory cache of messages to reduce reads.
/// - Sets up real-time listeners for sessions and messages if sync is enabled.
///
/// Design Decisions:
/// - Sync is optional and controlled by a user preference.
/// - Messages are stored in subcollections under the user document in Firestore.
/// - Local storage acts as the source of truth for offline capability.
///
/// Behavioral Specifications:
/// - [listSessions]: Retrieves a paginated list of chat sessions, optionally filtered by query.
/// - [createSession]: Creates a new session locally and syncs to Firestore if enabled.
/// - [addMessage]: Adds a message to a session, updates session metadata, and syncs.
/// - [markRead]: Resets the unread count for a session.
/// - [deleteSession]: Removes a session and its messages from both local and cloud storage.
class ChatStore {
  final Uuid _uuid = const Uuid();
  final Map<String, List<ChatMessage>> _cache = {};
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
      _messageSubs = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sessionsSub;

  // Callbacks for real-time updates
  VoidCallback? onSessionsUpdated;

  FirebaseFirestore get _fs => FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  String? get _projectId => Firebase.app().options.projectId;

  String _previewFor(String role, String text) {
    final t = text.trim();
    if (role == 'assistant') {
      final l = t.toLowerCase();
      final hasErr = l.startsWith('error') ||
          l.contains('internal') ||
          l.contains('permission') ||
          l.contains('timeout') ||
          l.contains('network');
      final hasJson = t.contains('{') && t.contains('}');
      if (hasErr || hasJson) return 'Error encountered';
    }
    return t.length > 80 ? t.substring(0, 80) : t;
  }

  Future<bool> _syncEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool('firestore_sync_enabled') ?? false;
  }

  Future<List<ChatSession>> _readAllSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('chat_sessions');
    final list = raw == null || raw.isEmpty
        ? <ChatSession>[]
        : List<Map<String, dynamic>>.from((jsonDecode(raw) as List<dynamic>)
                .map((e) => Map<String, dynamic>.from(e as Map)))
            .map(ChatSession.fromMap)
            .toList();
    list.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
    return list;
  }

  Future<void> _writeAllSessions(List<ChatSession> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'chat_sessions', jsonEncode(sessions.map((e) => e.toMap()).toList()));
  }

  /// Lists available chat sessions with pagination and search.
  Future<List<ChatSession>> listSessions(
      {String? query, int offset = 0, int limit = 20}) async {
    final list = await _readAllSessions();
    Iterable<ChatSession> it = list;
    if (query != null && query.trim().isNotEmpty) {
      final q = query.toLowerCase();
      it = it.where((s) {
        final t = (s.title ?? s.id).toLowerCase();
        return t.contains(q);
      });
    }
    final arr = it.toList();
    final end = (offset + limit) > arr.length ? arr.length : (offset + limit);
    return arr.sublist(offset, end);
  }

  /// Creates a new chat session.
  Future<ChatSession> createSession({String? title}) async {
    final id = _uuid.v4();
    final s = ChatSession(id: id, title: title);
    final sessions = await _readAllSessions();
    sessions.insert(0, s);
    await _writeAllSessions(sessions);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_session_id', id);
    await prefs.setString('chat_history_$id', jsonEncode([]));
    _cache.remove(id);
    try {
      if (await _syncEnabled() && _uid != null) {
        debugPrint(
            'CreateSession Firestore write uid=$_uid project=$_projectId session=$id');
        await _fs
            .collection('users')
            .doc(_uid)
            .collection('sessions')
            .doc(id)
            .set(s.toMap(), SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('CreateSession Firestore error: $e');
    }
    return s;
  }

  /// Updates the title of a session.
  Future<void> updateTitle(String id, String? title) async {
    final sessions = await _readAllSessions();
    for (final s in sessions) {
      if (s.id == id) {
        s.title = title;
        break;
      }
    }
    await _writeAllSessions(sessions);
    try {
      if (await _syncEnabled() && _uid != null) {
        debugPrint(
            'UpdateTitle Firestore write uid=$_uid project=$_projectId session=$id');
        await _fs
            .collection('users')
            .doc(_uid)
            .collection('sessions')
            .doc(id)
            .set({'title': title}, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('UpdateTitle Firestore error: $e');
    }
  }

  /// Retrieves messages for a specific session with pagination.
  Future<List<ChatMessage>> getMessages(String id,
      {int page = 0, int pageSize = 50}) async {
    if (_cache.containsKey(id)) {
      final all = _cache[id]!;
      final start = (all.length - (page + 1) * pageSize);
      final safeStart = start < 0 ? 0 : start;
      final end = all.length - page * pageSize;
      final safeEnd = end < 0 ? 0 : end;
      return all.sublist(safeStart, safeEnd);
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('chat_history_$id');
    final all = raw == null || raw.isEmpty
        ? <ChatMessage>[]
        : List<Map<String, dynamic>>.from((jsonDecode(raw) as List<dynamic>)
                .map((e) => Map<String, dynamic>.from(e as Map)))
            .map((e) => ChatMessage(
                  role: (e['role'] as String?) ?? 'user',
                  content: (e['content'] as String?) ?? '',
                  time: DateTime.tryParse((e['time'] as String?) ?? '') ??
                      DateTime.now(),
                ))
            .toList();
    _cache[id] = all;
    final start = (all.length - (page + 1) * pageSize);
    final safeStart = start < 0 ? 0 : start;
    final end = all.length - page * pageSize;
    final safeEnd = end < 0 ? 0 : end;
    return all.sublist(safeStart, safeEnd);
  }

  /// Adds a message to a session.
  Future<void> addMessage(String id, ChatMessage m) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('chat_history_$id');
    final list = raw == null || raw.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from((jsonDecode(raw) as List<dynamic>)
            .map((e) => Map<String, dynamic>.from(e as Map)));
    list.add({
      'role': m.role,
      'content': m.content,
      'time': m.time.toIso8601String()
    });
    await prefs.setString('chat_history_$id', jsonEncode(list));
    final cache = _cache[id] ?? <ChatMessage>[];
    cache.add(m);
    _cache[id] = cache;
    final sessions = await _readAllSessions();
    for (final s in sessions) {
      if (s.id == id) {
        s.lastActivity = DateTime.now();
        s.preview = _previewFor(m.role, m.content);
        if (m.role == 'assistant') {
          s.unreadCount = s.unreadCount + 1;
        }
        break;
      }
    }
    await _writeAllSessions(sessions);
    try {
      if (await _syncEnabled() && _uid != null) {
        debugPrint(
            'AddMessage Firestore write uid=$_uid project=$_projectId session=$id role=${m.role}');
        await _fs
            .collection('users')
            .doc(_uid)
            .collection('sessions')
            .doc(id)
            .set({
          'lastActivity': DateTime.now().toIso8601String(),
          'preview': m.content.trim().length > 80
              ? m.content.trim().substring(0, 80)
              : m.content.trim(),
          'unreadCount': m.role == 'assistant'
              ? FieldValue.increment(1)
              : FieldValue.increment(0),
        }, SetOptions(merge: true));
        await _fs
            .collection('users')
            .doc(_uid)
            .collection('messages')
            .doc(id)
            .collection('messages')
            .add({
          'role': m.role,
          'content': m.content,
          'time': m.time.toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('AddMessage Firestore error: $e');
    }
  }

  /// Marks all messages in a session as read.
  Future<void> markRead(String id) async {
    final sessions = await _readAllSessions();
    for (final s in sessions) {
      if (s.id == id) {
        s.unreadCount = 0;
        break;
      }
    }
    await _writeAllSessions(sessions);
    try {
      if (await _syncEnabled() && _uid != null) {
        debugPrint(
            'MarkRead Firestore write uid=$_uid project=$_projectId session=$id');
        await _fs
            .collection('users')
            .doc(_uid)
            .collection('sessions')
            .doc(id)
            .set({
          'unreadCount': 0,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('MarkRead Firestore error: $e');
    }
  }

  /// Deletes a session and its history.
  Future<void> deleteSession(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await _readAllSessions();
    sessions.removeWhere((s) => s.id == id);
    await _writeAllSessions(sessions);
    await prefs.remove('chat_history_$id');
    _cache.remove(id);
    try {
      if (await _syncEnabled() && _uid != null) {
        debugPrint(
            'DeleteSession Firestore write uid=$_uid project=$_projectId session=$id');
        await _fs
            .collection('users')
            .doc(_uid)
            .collection('sessions')
            .doc(id)
            .delete();
        final msgs = await _fs
            .collection('users')
            .doc(_uid)
            .collection('messages')
            .doc(id)
            .collection('messages')
            .get();
        for (final d in msgs.docs) {
          await d.reference.delete();
        }
      }
    } catch (e) {
      debugPrint('DeleteSession Firestore error: $e');
    }
  }

  /// Attaches a listener for real-time session updates from Firestore.
  Future<void> attachSessionsListener() async {
    try {
      if (await _syncEnabled() && _uid != null) {
        _sessionsSub?.cancel();
        _sessionsSub = _fs
            .collection('users')
            .doc(_uid)
            .collection('sessions')
            .snapshots()
            .listen((snap) async {
          final prefs = await SharedPreferences.getInstance();
          final sessions = <ChatSession>[];
          for (final d in snap.docs) {
            final data = d.data();
            final merged = {
              ...data,
              'id': (data['id'] as String?) ?? d.id,
            };
            try {
              sessions.add(ChatSession.fromMap(merged));
            } catch (e) {
              debugPrint(
                  'Session deserialize error for doc ${d.id}: $e, data=$data');
            }
          }
          sessions.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
          await prefs.setString('chat_sessions',
              jsonEncode(sessions.map((e) => e.toMap()).toList()));
          onSessionsUpdated?.call();
        }, onError: (e) async {
          debugPrint(
              'Firestore sessions listener error (uid=${_uid ?? 'null'} project=${_projectId ?? 'null'}): $e');
          try {
            await _sessionsSub?.cancel();
          } catch (_) {}
          _sessionsSub = null;
        });
      }
    } catch (_) {}
  }

  /// Attaches a listener for real-time message updates for a specific session.
  Future<void> attachMessagesListener(String id) async {
    try {
      if (await _syncEnabled() && _uid != null) {
        _messageSubs[id]?.cancel();
        _messageSubs[id] = _fs
            .collection('users')
            .doc(_uid)
            .collection('messages')
            .doc(id)
            .collection('messages')
            .orderBy('time')
            .snapshots()
            .listen((snap) async {
          final prefs = await SharedPreferences.getInstance();
          final raw = prefs.getString('chat_history_$id');
          final localList = raw == null || raw.isEmpty
              ? <Map<String, dynamic>>[]
              : List<Map<String, dynamic>>.from((jsonDecode(raw) as List)
                  .map((e) => Map<String, dynamic>.from(e as Map)));
          final localTimes = localList
              .map((e) => e['time'] as String?)
              .whereType<String>()
              .toSet();
          var changed = false;
          for (final d in snap.docs) {
            final m = d.data();
            final t = (m['time'] as String?) ?? '';
            if (!localTimes.contains(t)) {
              localList
                  .add({'role': m['role'], 'content': m['content'], 'time': t});
              changed = true;
            }
          }
          if (changed) {
            await prefs.setString('chat_history_$id', jsonEncode(localList));
            _cache[id] = localList
                .map((e) => ChatMessage(
                    role: e['role'] as String? ?? 'user',
                    content: e['content'] as String? ?? '',
                    time: DateTime.tryParse(e['time'] as String? ?? '') ??
                        DateTime.now()))
                .toList();
          }
        }, onError: (e) async {
          debugPrint(
              'Firestore messages listener error (uid=${_uid ?? 'null'} project=${_projectId ?? 'null'} session=$id): $e');
          try {
            await _messageSubs[id]?.cancel();
          } catch (_) {}
          _messageSubs.remove(id);
        });
      }
    } catch (_) {}
  }

  /// Cancels all active Firestore listeners.
  Future<void> disposeListeners() async {
    try {
      _sessionsSub?.cancel();
      for (final s in _messageSubs.values) {
        await s.cancel();
      }
      _messageSubs.clear();
    } catch (_) {}
  }
}

final chatStoreProvider = Provider<ChatStore>((ref) => ChatStore());
final chatSearchQueryProvider = StateProvider<String>((ref) => '');
final chatSessionsPageProvider = StateProvider<int>((ref) => 0);
final chatSessionsProvider = FutureProvider<List<ChatSession>>((ref) async {
  final store = ref.read(chatStoreProvider);
  final q = ref.watch(chatSearchQueryProvider);
  final page = ref.watch(chatSessionsPageProvider);
  final limit = (page + 1) * 20;
  return await store.listSessions(query: q, offset: 0, limit: limit);
});
