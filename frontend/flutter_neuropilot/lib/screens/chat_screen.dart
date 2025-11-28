import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:altered/l10n/app_localizations.dart';
import '../core/design_tokens.dart';
import '../core/chat_message.dart';
import '../core/components/np_app_bar.dart';
import '../core/components/np_text_field.dart';
import '../core/components/np_button.dart';
import '../core/components/np_chip.dart';
import '../core/components/np_snackbar.dart';
import '../core/components/np_progress.dart';
import '../core/components/np_bottom_sheet.dart';
import '../core/components/np_badge.dart';
import '../core/components/np_badge.dart';
import '../core/components/pulse_indicator.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/api_client.dart';
import '../state/session_state.dart';
import '../state/chat_store.dart';
import '../core/speech_service.dart';
import '../core/tts_service.dart';
import '../core/routes.dart';
// import '../core/link_opener.dart';

/// The main chat interface for the application.
///
/// Implementation Details:
/// - Uses [ConsumerStatefulWidget] to integrate with Riverpod providers.
/// - Manages local state for chat messages, voice mode, timers, and proactive check-ins.
/// - Integrates with [ApiClient] for backend communication.
/// - Handles voice input/output using [SpeechService] and [TtsService].
///
/// Design Decisions:
/// - Uses a polling mechanism for timers to ensure UI updates.
/// - Implements a "Body Double" feature with proactive check-ins based on inactivity.
/// - Supports both text and voice interaction modes.
/// - Uses a "Focus Mode" to reduce distractions.
///
/// Behavioral Specifications:
/// - Messages are persisted locally via [ChatStore] and synced to Firestore if enabled.
/// - Timers are managed locally and can be created/queried via natural language.
/// - The interface adapts to "Focus Mode" and "Minimal Mode" settings.

/// Represents the intent of a user's message.
///
/// Used for fallback routing when the orchestrator is unavailable or for client-side logic.
enum Intent {
  health,
  atomize,
  schedule,
  countdown,
  reduce,
  energyMatch,
  externalCapture,
  calendarToday,
  help,
  overview,
  sessions,
  unknown,
}

/// Represents a countdown timer item.
class _TimerItem {
  _TimerItem({
    required this.id,
    required this.target,
    required this.totalSeconds,
    required this.remainingSeconds,
  });
  final String id;
  DateTime target;
  final int totalSeconds;
  int remainingSeconds;
  bool paused = false;
  bool completed = false;

  DateTime? completedAt;
  int lastProgressState = 0; // 0: >50%, 1: <=50%, 2: <=20%
}

/// Actions inferred from a timer command.
enum _TimerAction { create, query, unknown }

/// Result of parsing a timer command.
class _TimerParseResult {
  _TimerParseResult(this.action, {this.seconds, this.additional = false});
  final _TimerAction action;
  final int? seconds;
  final bool additional;
}

/// The main chat screen widget.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

/// The state class for [ChatScreen].
///
/// Manages:
/// - Chat message list and input controller.
/// - Voice recognition and synthesis state.
/// - Timer logic and UI updates.
/// - Proactive check-in (Body Double) timers.
/// - Connection status and error handling.
class _ChatScreenState extends ConsumerState<ChatScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _input = TextEditingController();
  bool _loading = false;
  bool _voiceMode = false;
  final SpeechService _speech = createSpeechService();
  final TtsService _tts = createTtsService();
  // final LinkOpener _linkOpener = createLinkOpener();
  final List<String> _engaged = [];
  bool _backendOk = false;
  Timer? _heartbeat;
  List<String> _dynamicSuggestions = [];
  bool _listening = false;
  late final AnimationController _pulseCtl;
  late final Animation<double> _pulseScale;
  String _partialText = '';
  bool _showModeBanner = false;
  String _modeBannerText = '';
  Timer? _modeBannerTimer;
  bool _focusMode = false;
  final bool _minimalMode = false;
  bool _showTimersSection = false;
  bool _showInactivityPrompt = false;
  bool _bodyDoubleActive = false;
  String _inactivityPromptText = '';
  bool _voiceOutput = false;
  bool _speaking = false;
  double _volume = 1.0;
  double _soundLevel = 0.0;
  bool _voiceSession = false;
  int _consecutiveSilence = 0;
  Timer? _voiceRestartTimer; // Cancellable timer for voice session restart
  String? _pendingVoiceText;
  bool _offlineHoldNoticeShown = false;

  StreamSubscription<String>? _partialSub;
  StreamSubscription<double>? _levelSub;
  StreamSubscription<bool>? _speakingSub;

  // Proactive Check-in State (Always Active)
  int _sessionDurationMinutes = 0;
  Timer? _sessionTimer;
  final int _checkInIntervalSeconds = 120; // 2 minutes
  Timer? _inactivityTimer;
  DateTime? _lastActivityTime;
  bool _proactiveStarted = false;

  // Just-in-Time Prompts State (mobile lifecycle)
  DateTime? _appPausedTime;
  final int _jitThresholdSeconds = 30; // Trigger after 30s away
  String _currentTask = ""; // Track what user is working on

  final List<_TimerItem> _timers = [];
  Timer? _timerTicker;
  Timer? _testRebuilder;
  Ticker? _shortTimerTicker;
  int _epochBaseMs = 0;
  String? _activeTimerId;
  int _pulseSpeedMs = 900;
  Color? _pulseBaseColor;

  // Pagination
  int _currentPage = 0;
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;

  @override
  void dispose() {
    // Stop animations and timers first
    _pulseCtl.dispose();
    _timerTicker?.cancel();
    _testRebuilder?.cancel();
    _shortTimerTicker?.dispose();
    _heartbeat?.cancel();
    _modeBannerTimer?.cancel();
    _sessionTimer?.cancel();
    _inactivityTimer?.cancel();
    _voiceRestartTimer?.cancel();

    // Cancel subscriptions
    _partialSub?.cancel();
    _levelSub?.cancel();
    _speakingSub?.cancel();

    // Dispose controllers and listeners
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _input.dispose();

    if (!kIsWeb) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }

  /// Loads older messages when scrolling up.
  void _scrollListener() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 100 &&
        !_isLoadingMore &&
        _hasMoreMessages) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final currentId = ref.read(chatSessionIdProvider);
      // If session ID isn't in provider, try to get it from store logic if needed,
      // but typically it should be set.
      if (currentId == null) {
        setState(() => _isLoadingMore = false);
        return;
      }

      final store = ref.read(chatStoreProvider);
      final next = _currentPage + 1;
      final msgs = await store.getMessages(currentId, page: next, pageSize: 50);
      if (!mounted) return;

      if (msgs.isEmpty) {
        setState(() {
          _hasMoreMessages = false;
          _isLoadingMore = false;
        });
        return;
      }

      setState(() {
        _currentPage = next;
        // Prepend older messages
        _messages.insertAll(0, msgs);
        _isLoadingMore = false;
        _hasMoreMessages = msgs.length >= 50;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  /// Scrolls the chat to the bottom to show the latest message.
  ///
  /// Uses SchedulerBinding to ensure scrolling happens after the frame is built.
  void _scrollToBottom() {
    // With reverse: true, the "bottom" is scroll offset 0.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      try {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } catch (_) {
        // Silently fail - scroll controller might not be ready yet
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final api = ref.watch(apiClientProvider);
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 700;
    final hp = isWide ? DesignTokens.spacingXl : DesignTokens.spacingLg;
    return Scaffold(
      appBar: NpAppBar(
        title: 'Altered',
        showBack: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).pushNamed(Routes.settings),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'More Options',
            onSelected: (value) async {
              switch (value) {
                case 'new_chat':
                  final store = ref.read(chatStoreProvider);
                  final s = await store.createSession();
                  ref.read(chatSessionIdProvider.notifier).state = s.id;
                  await store.attachMessagesListener(s.id);
                  await store.markRead(s.id);
                  ref.invalidate(chatSessionsProvider);
                  setState(() {
                    _messages.clear();
                    _currentPage = 0;
                    _hasMoreMessages = true;
                  });
                  break;
                case 'chats':
                  Navigator.of(context).pushNamed(Routes.chats);
                  break;
                case 'focus_mode':
                  setState(() => _focusMode = !_focusMode);
                  _showModeBannerNow(l.focusModeLabel);
                  break;
                case 'body_double':
                  setState(() {
                    _bodyDoubleActive = !_bodyDoubleActive;
                    if (_bodyDoubleActive) {
                      _startProactiveCheckins();
                      NpSnackbar.show(context, 'Body Double Active',
                          type: NpSnackType.success);
                    } else {
                      _inactivityTimer?.cancel();
                      _sessionTimer?.cancel();
                      _proactiveStarted = false;
                      NpSnackbar.show(context, 'Body Double Paused',
                          type: NpSnackType.info);
                    }
                  });
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'new_chat',
                child: ListTile(
                  leading: Icon(Icons.add),
                  title: Text('New Chat'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'chats',
                child: ListTile(
                  leading: Icon(Icons.chat),
                  title: Text('Chats'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              CheckedPopupMenuItem<String>(
                value: 'focus_mode',
                checked: _focusMode,
                child: const Text('Focus Mode'),
              ),
              CheckedPopupMenuItem<String>(
                value: 'body_double',
                checked: _bodyDoubleActive,
                child: const Text('Body Double'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_focusMode &&
              !_minimalMode &&
              !_listening &&
              (_loading || _engaged.isNotEmpty))
            Padding(
              padding: const EdgeInsets.all(DesignTokens.spacingSm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const NpLinearProgress(),
                  const SizedBox(height: DesignTokens.spacingXs),
                  Wrap(
                    spacing: DesignTokens.spacingSm,
                    children: [
                      NpChip(
                          label: _backendOk
                              ? 'Backend: Connected'
                              : 'Backend: Offline',
                          selected: _backendOk),
                      ..._engaged
                          .toSet()
                          .take(4)
                          .map((e) => NpChip(label: e, selected: true)),
                    ],
                  ),
                ],
              ),
            ),
          if (!_backendOk)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hp),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                    horizontal: hp, vertical: DesignTokens.spacingSm),
                decoration: BoxDecoration(
                  color: DesignTokens.error,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Backend unreachable. Retry to reconnect.',
                        style: TextStyle(color: DesignTokens.onPrimary),
                      ),
                    ),
                    NpButton(
                      label: 'Retry',
                      icon: Icons.refresh,
                      type: NpButtonType.secondary,
                      onPressed: () async {
                        await _pingBackend();
                      },
                    ),
                  ],
                ),
              ),
            ),
          if (_listening)
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: hp, vertical: DesignTokens.spacingSm),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                    horizontal: hp, vertical: DesignTokens.spacingSm),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                ),
                child: Row(
                  children: [
                    ScaleTransition(
                      scale: _pulseScale,
                      child:
                          const Icon(Icons.mic, color: DesignTokens.onPrimary),
                    ),
                    const SizedBox(width: DesignTokens.spacingSm),
                    const Expanded(
                        child: Text('Listening...',
                            style: TextStyle(color: DesignTokens.onPrimary))),
                    const SizedBox(width: DesignTokens.spacingSm),
                    if (_partialText.isNotEmpty)
                      Expanded(
                          child: Text(_partialText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: DesignTokens.onPrimary))),
                    NpButton(
                      label: 'Stop',
                      icon: Icons.stop,
                      type: NpButtonType.secondary,
                      onPressed: () {
                        // Cancel any pending restart and stop all voice services
                        _voiceRestartTimer?.cancel();
                        _voiceRestartTimer = null;
                        _speech.stop();
                        _tts.stop();
                        setState(() {
                          _listening = false;
                          _voiceSession = false;
                          _voiceOutput = false;
                          _partialText = '';
                          _soundLevel = 0.0;
                          _consecutiveSilence = 0;
                          _engaged.remove('SpeechRecognition');
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          if (_timers.isNotEmpty && !_focusMode && !_minimalMode && !_listening)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: hp,
                vertical: DesignTokens.spacingSm,
              ),
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Timers'),
                    trailing: Icon(_showTimersSection
                        ? Icons.expand_less
                        : Icons.expand_more),
                    onTap: () => setState(
                        () => _showTimersSection = !_showTimersSection),
                  ),
                  if (_showTimersSection)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: _timers.isEmpty
                          ? Align(
                              alignment: Alignment.centerLeft,
                              child: Text('No timers running.',
                                  style:
                                      Theme.of(context).textTheme.bodyMedium))
                          : ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 240),
                              child: SingleChildScrollView(
                                child: Column(
                                  children: _timers
                                      .map((t) => _timerCard(context, t))
                                      .toList(),
                                ),
                              ),
                            ),
                    ),
                ],
              ),
            ),
          // End timers list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              reverse: true,
              padding: EdgeInsets.symmetric(
                  horizontal: hp, vertical: DesignTokens.spacingLg),
              itemCount: _messages.length,
              itemBuilder: (ctx, i) {
                // Since we are using reverse: true, the list is visually reversed.
                // We want index 0 to be the bottom-most item (latest message).
                // _messages is stored [oldest, ..., newest].
                // So we map visual index i to _messages.length - 1 - i.
                final m = _messages[_messages.length - 1 - i];
                final isUser = m.role == 'user';
                return Padding(
                  padding:
                      const EdgeInsets.only(bottom: DesignTokens.spacingMd),
                  child: Row(
                    mainAxisAlignment: isUser
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment
                        .start, // Align avatars to top for better visibility on long messages
                    children: [
                      if (!isUser) ...[
                        CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.secondaryContainer,
                          radius: 16,
                          child: Icon(Icons.auto_awesome,
                              size: 16,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer),
                        ),
                        const SizedBox(width: DesignTokens.spacingSm),
                      ],
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: DesignTokens.spacingLg,
                              vertical: DesignTokens.spacingMd),
                          decoration: BoxDecoration(
                            color: isUser
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.only(
                              topLeft:
                                  const Radius.circular(DesignTokens.radiusLg),
                              topRight:
                                  const Radius.circular(DesignTokens.radiusLg),
                              bottomLeft: isUser
                                  ? const Radius.circular(DesignTokens.radiusLg)
                                  : const Radius.circular(
                                      DesignTokens.radiusSm),
                              bottomRight: isUser
                                  ? const Radius.circular(DesignTokens.radiusSm)
                                  : const Radius.circular(
                                      DesignTokens.radiusLg),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Text(
                            m.content,
                            style: TextStyle(
                              color: isUser
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.onSurface,
                              fontSize: DesignTokens.bodySize,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                      if (isUser) ...[
                        const SizedBox(width: DesignTokens.spacingSm),
                        CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          radius: 16,
                          child: Icon(Icons.person,
                              size: 16,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer),
                        ),
                      ],
                    ],
                  ),
                ).animate().fadeIn(duration: 300.ms).slideY(
                    begin: 0.2,
                    end: 0,
                    duration: 300.ms,
                    curve: Curves.easeOut);
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: hp, vertical: DesignTokens.spacingLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_isTestEnv &&
                    !_focusMode &&
                    !_minimalMode &&
                    !_listening) ...[
                  Text(l.suggestionsLabel,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: DesignTokens.spacingXs),
                  Wrap(
                    spacing: DesignTokens.spacingSm,
                    runSpacing: DesignTokens.spacingSm,
                    children: [
                      NpChip(
                          label: l.suggestAtomize,
                          onTap: () => _setInput(l.exampleAtomize)),
                      NpChip(
                          label: l.suggestCountdown,
                          onTap: () => _setInput(l.exampleCountdown)),
                      NpChip(
                        label: 'More…',
                        onTap: () => _showMoreSuggestions(context, l),
                      ),
                    ],
                  ),
                  const SizedBox(height: DesignTokens.spacingSm),
                ],
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _showInactivityPrompt
                      ? Padding(
                          padding: const EdgeInsets.only(
                              bottom: DesignTokens.spacingXs),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: DesignTokens.spacingMd,
                                  vertical: DesignTokens.spacingXs),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .secondaryContainer
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(
                                    DesignTokens.radiusMd),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.waving_hand, size: 16),
                                  const SizedBox(width: DesignTokens.spacingXs),
                                  Flexible(
                                    child: Text(
                                      _inactivityPromptText.isNotEmpty
                                          ? _inactivityPromptText
                                          : 'Ready when you are',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w500),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _showModeBanner
                      ? Padding(
                          padding: const EdgeInsets.only(
                              bottom: DesignTokens.spacingXs),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(_modeBannerText),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                Container(
                  padding: const EdgeInsets.all(DesignTokens
                      .spacingSm), // Reduced padding for cleaner look
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surface
                        .withValues(alpha: 0.9), // Glassmorphism-ish
                    borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => _showVoiceControls(context),
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: PulseIndicator(
                            mode: _listening
                                ? PulseMode.listening
                                : (_speaking
                                    ? PulseMode.speaking
                                    : (_loading || _engaged.isNotEmpty
                                        ? PulseMode.processing
                                        : PulseMode.idle)),
                            amplitude: _listening
                                ? (_soundLevel > 1.0
                                    ? 1.0
                                    : _soundLevel) // Normalize if needed
                                : (_speaking ? 0.4 : 0.0),
                            size: 56,
                          ),
                        ),
                      ),
                      const SizedBox(width: DesignTokens.spacingSm),
                      if (!_listening) ...[
                        Expanded(
                          child: NpTextField(
                              controller: _input,
                              label: _voiceMode
                                  ? l.voiceModeLabel
                                  : l.typeMessageLabel,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) async {
                                if (!_voiceMode) {
                                  await _handleSubmit(api);
                                }
                              }),
                        ),
                      ],
                      const SizedBox(width: DesignTokens.spacingSm),
                      if (!_listening)
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: IconButton(
                            icon: Icon(_voiceMode ? Icons.mic : Icons.send),
                            color: Theme.of(context).colorScheme.onPrimary,
                            onPressed: () async {
                              if (_voiceMode) {
                                if (_speech.supported) {
                                  setState(() {
                                    if (!_engaged
                                        .contains('SpeechRecognition')) {
                                      _engaged.add('SpeechRecognition');
                                    }
                                    _listening = true;
                                  });
                                  _partialSub?.cancel();
                                  _partialSub =
                                      _speech.partialUpdates.listen((s) {
                                    setState(() => _partialText = s);
                                  });
                                  _levelSub?.cancel();
                                  _levelSub = _speech.levelUpdates.listen((v) {
                                    setState(() => _soundLevel = v);
                                  });
                                  final t = await _speech.startOnce();
                                  final lastPartial = _partialText;
                                  _partialSub?.cancel();
                                  _levelSub?.cancel();
                                  final a = (t ?? '').trim();
                                  final b = lastPartial.trim();
                                  final candidate =
                                      (a.length >= b.length && a.isNotEmpty)
                                          ? a
                                          : (b.isNotEmpty ? b : '');
                                  final finalText =
                                      _formatTranscript(candidate);
                                  setState(() {
                                    _engaged.remove('SpeechRecognition');
                                    _listening = false;
                                    _partialText = '';
                                    _soundLevel = 0.0;
                                  });
                                  if (finalText.isNotEmpty) {
                                    _input.text = finalText;
                                    await _handleSubmit(api, isVoice: true);
                                  } else {
                                    if (context.mounted) {
                                      NpSnackbar.show(context,
                                          'Voice recognition failed. Please check microphone permissions and try again. Check browser console for details.',
                                          type: NpSnackType.warning);
                                    }
                                  }
                                } else {
                                  if (context.mounted) {
                                    NpSnackbar.show(context,
                                        'Voice recording not supported on this device/browser.',
                                        type: NpSnackType.destructive);
                                  }
                                }
                                return;
                              }
                              await _handleSubmit(api);
                            },
                          ),
                        ),
                      const SizedBox(width: DesignTokens.spacingXs),
                      if (!_listening)
                        IconButton(
                          icon: Icon(_voiceMode ? Icons.keyboard : Icons.mic,
                              color: Theme.of(context).colorScheme.secondary),
                          tooltip: l.voiceToggleLabel,
                          onPressed: () =>
                              setState(() => _voiceMode = !_voiceMode),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _setInput(String s) {
    _input.text = s;
    _resetInactivityTimer();
    setState(() => _showInactivityPrompt = false);
  }

  /// Formats the voice transcript with basic punctuation.
  ///
  /// Adds a question mark if the sentence starts with a question word.
  String _formatTranscript(String s) {
    final t = s.trim();
    if (t.isEmpty) return '';
    final endsPunct = t.endsWith('.') || t.endsWith('!') || t.endsWith('?');
    if (endsPunct) return t;
    final lower = t.toLowerCase();
    const starters = [
      'who',
      'what',
      'when',
      'where',
      'why',
      'how',
      'can',
      'could',
      'would',
      'should',
      'is',
      'are',
      'do',
      'did',
      'will',
      'might',
      'may',
      'shall',
      'have',
      'has'
    ];
    final isQuestion = starters.any((w) => lower.startsWith('$w '));
    return isQuestion ? '$t?' : t;
  }

  void _triggerDoomScrollRescue() async {
    // Manual trigger - user clicked the rescue button
    debugPrint("Manual doom scroll rescue triggered");
    await _triggerJustInTimePrompt(0); // 0 seconds means manual trigger
  }

  /// Triggers a "Just-in-Time" prompt to re-engage the user.
  ///
  /// Called when the app resumes from the background or upon manual trigger.
  /// Uses the "TaskFlow Agent" to generate a context-aware prompt.
  Future<void> _triggerJustInTimePrompt(int durationSeconds) async {
    final api = ref.read(apiClientProvider);
    try {
      _engage('TaskFlow Agent');

      // Determine current task from recent messages or use generic
      String activity = _currentTask.isNotEmpty ? _currentTask : "your task";
      if (_messages.isNotEmpty) {
        // Try to extract task from last user message
        final lastUserMsg = _messages.reversed.firstWhere(
          (m) => m.role == 'user',
          orElse: () => ChatMessage(role: 'user', content: ''),
        );
        if (lastUserMsg.content.isNotEmpty &&
            lastUserMsg.content.length < 100) {
          activity = lastUserMsg.content;
        }
      }

      final prompt = durationSeconds > 0
          ? "System: User was away for $durationSeconds seconds and just returned. Use just_in_time_prompt tool with activity='$activity' and duration_seconds=$durationSeconds."
          : "System: User requested doom scroll rescue. Use just_in_time_prompt tool with activity='$activity'.";

      debugPrint("Triggering JIT prompt: $prompt");
      final r = await api.chatRespond(prompt);
      _disengage('TaskFlow Agent');

      final reply = (r['text'] as String?) ?? '';
      final tools = r['tools'] as List<dynamic>? ?? [];

      // Handle JIT rescue response
      for (var t in tools) {
        if (t is Map && t['ui_mode'] == 'jit_rescue') {
          final rescuePrompt = t['prompt'] as String;
          _appendAssistant("🚨 $rescuePrompt");
          // Update current task if provided
          if (t['activity'] != null && (t['activity'] as String).isNotEmpty) {
            _currentTask = t['activity'] as String;
          }
        }
      }

      if (reply.isNotEmpty &&
          !tools.any((t) => t is Map && t['ui_mode'] == 'jit_rescue')) {
        _appendAssistant(reply);
      }
    } catch (e) {
      debugPrint("JIT prompt failed: $e");
      if (!mounted) return;
      NpSnackbar.show(context, '$e', type: NpSnackType.warning);
    }
  }

  /// Infers the user's intent from the message content.
  ///
  /// Used as a fallback when the orchestrator is unavailable or for simple local commands.
  Intent _inferIntent(String q) {
    final s = q.toLowerCase();
    if (s.contains('health') || s.contains('status')) {
      return Intent.health;
    }
    if (s.contains('atomize')) {
      return Intent.atomize;
    }
    if (s.contains('schedule')) {
      return Intent.schedule;
    }
    if (s.contains('countdown') || s.contains('timer') || s.contains('iso')) {
      return Intent.countdown;
    }
    if (s.contains('reduce') || s.contains('decide')) {
      return Intent.reduce;
    }
    if (s.contains('energy')) {
      return Intent.energyMatch;
    }
    if (s.contains('capture') || s.contains('voice')) {
      return Intent.externalCapture;
    }
    if (s.contains('appointment') ||
        s.contains('calendar') ||
        s.contains('event')) {
      return Intent.calendarToday;
    }
    if (s == 'help' || s.contains('help') || s.contains('commands')) {
      return Intent.help;
    }
    if (s.contains('overview') ||
        s.contains('today') ||
        s.contains('planned') ||
        s.contains('plans')) {
      return Intent.overview;
    }
    if (s.contains('sessions') || s.contains('yesterday')) {
      return Intent.sessions;
    }
    return Intent.unknown;
  }

  /// Activates the "Body Double" mode.
  ///
  /// Starts a periodic timer to track session duration and monitors user inactivity.
  void _startProactiveCheckins() {
    if (_proactiveStarted) {
      return;
    }
    setState(() {
      _sessionDurationMinutes = 0;
      _lastActivityTime = DateTime.now();
    });
    _proactiveStarted = true;
    debugPrint(
        "Proactive check-ins started. Interval: $_checkInIntervalSeconds seconds");

    // Track session duration
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      setState(() {
        _sessionDurationMinutes++;
      });
    });

    // Start inactivity monitoring
    _resetInactivityTimer();
  }

  /// Resets the inactivity timer.
  ///
  /// Called whenever the user interacts with the app.
  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _lastActivityTime = DateTime.now();
    if (_isTestEnv) return;
    _inactivityTimer = Timer(Duration(seconds: _checkInIntervalSeconds), () {
      debugPrint(
          "Inactivity timer fired after $_checkInIntervalSeconds seconds!");
      _checkInProactive();
    });
  }

  /// Performs a proactive check-in if the user has been inactive.
  ///
  /// Sends a prompt to the backend to generate a check-in message using the "body_double_checkin" tool.
  Future<void> _checkInProactive() async {
    // Verify user has been inactive
    final secondsSince =
        DateTime.now().difference(_lastActivityTime!).inSeconds;
    if (secondsSince < _checkInIntervalSeconds) {
      debugPrint("User was active recently, resetting timer");
      _resetInactivityTimer();
      return;
    }

    final api = ref.read(apiClientProvider);
    try {
      _engage('Proactive Check-in');
      debugPrint(
          "Triggering proactive check-in. Duration: $_sessionDurationMinutes min");
      final r = await api.chatRespond(
          "System: User has been silent for $_checkInIntervalSeconds seconds. "
          "Session active for $_sessionDurationMinutes minutes. "
          "Please use body_double_checkin tool with duration_minutes=$_sessionDurationMinutes.");
      if (!mounted) return;
      _disengage('Proactive Check-in');

      final reply = (r['text'] as String?) ?? '';
      final tools = r['tools'] as List<dynamic>? ?? [];

      for (var t in tools) {
        if (t is Map && t.containsKey('check_in')) {
          final prompt = t['prompt'] as String;
          setState(() {
            _inactivityPromptText = prompt;
            _showInactivityPrompt = true;
          });
        }
      }
      if (reply.isNotEmpty && tools.isEmpty) {
        setState(() {
          _inactivityPromptText = reply;
          _showInactivityPrompt = true;
        });
      }
    } catch (e) {
      debugPrint("Check-in failed: $e");
      if (mounted) {
        NpSnackbar.show(context, '$e', type: NpSnackType.warning);
      }
    } finally {
      if (mounted) {
        _disengage('Proactive Check-in');
        _resetInactivityTimer();
      }
    }
  }

  /// Starts a countdown timer.
  ///
  /// Creates a [_TimerItem] and updates the UI periodically.
  void _startCountdown(String timerId, String targetIso) {
    final target = DateTime.parse(targetIso);
    final now = DateTime.now();
    final diff = target.difference(now);
    if (diff.isNegative) return;

    final total = (diff.inMilliseconds / 1000).ceil();
    final item = _TimerItem(
      id: timerId,
      target: target,
      totalSeconds: total,
      remainingSeconds: total,
    );
    setState(() {
      _timers.add(item);
      _activeTimerId = timerId;
      _showTimersSection = true;
    });

    _appendAssistant('Timer created for ${_formatExactDuration(total)}.');

    if (total <= 1) {
      _testRebuilder?.cancel();
      int elapsedMs = 0;
      _testRebuilder = Timer.periodic(const Duration(milliseconds: 100), (tm) {
        if (!mounted) {
          tm.cancel();
          return;
        }
        setState(() {});
        elapsedMs += 100;
        if (_timers.isEmpty || elapsedMs >= 2200) {
          tm.cancel();
        }
      });
      _shortTimerTicker?.dispose();
      _shortTimerTicker = Ticker((_) {
        if (!mounted) return;
        setState(() {});
        if (_timers.isEmpty) {
          _shortTimerTicker?.stop();
          _shortTimerTicker?.dispose();
          _shortTimerTicker = null;
        }
      });
      _shortTimerTicker!.start();
    }

    _timerTicker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (_timers.isEmpty) {
        _timerTicker?.cancel();
        _timerTicker = null;
        return;
      }
      setState(() {
        final nowTick = DateTime.now();
        final removeIds = <String>[];
        for (final t in _timers) {
          if (!t.paused && !t.completed) {
            final now = _now();
            final rem = t.target.difference(now).inMilliseconds / 1000;
            t.remainingSeconds = rem.ceil();

            // Audio Cues Logic
            if (t.totalSeconds > 10) {
              final progress =
                  (t.remainingSeconds / t.totalSeconds).clamp(0.0, 1.0);
              int newState = 0;
              if (progress <= 0.2) {
                newState = 2;
              } else if (progress <= 0.5) {
                newState = 1;
              }

              if (newState > t.lastProgressState) {
                if (newState == 1) {
                  _tts.speak("Halfway point.");
                } else if (newState == 2) {
                  _tts.speak("Final stretch.");
                }
                t.lastProgressState = newState;
              }
            }

            if (t.remainingSeconds <= 0) {
              t.completed = true;
              t.completedAt = DateTime.now();
              _appendAssistant(
                  'Timer completed: ${_formatExactDuration(t.totalSeconds)}.');
              removeIds.add(t.id);
            }
          }
        }
        if (removeIds.isNotEmpty) {
          _timers.removeWhere((x) => removeIds.contains(x.id));
          if (_activeTimerId != null && removeIds.contains(_activeTimerId)) {
            _activeTimerId = _timers.isNotEmpty ? _timers.last.id : null;
          }
        }
        // In normal runtime, completed timers fade out and are removed.
        _timers.removeWhere((x) =>
            x.completed &&
            x.completedAt != null &&
            DateTime.now().difference(x.completedAt!).inMilliseconds > 700);
      });
    });
  }

  /// Handles message submission.
  ///
  /// Processes the input text, sends it to the backend (or orchestrator), and handles the response.
  /// Supports both text and voice input.
  Future<void> _handleSubmit(ApiClient api,
      {bool isVoice = false, String? textOverride}) async {
    final text = textOverride ?? _input.text.trim();
    if (text.isEmpty) return;

    // Reset inactivity timer on user interaction
    _resetInactivityTimer();
    setState(() => _showInactivityPrompt = false);

    setState(() {
      _messages.add(ChatMessage(role: 'user', content: text));
      _loading = true;
    });
    _scrollToBottom();
    try {
      final store = ref.read(chatStoreProvider);
      final currentId = ref.read(chatSessionIdProvider);
      final ensured = await ref.read(ensureChatSessionIdProvider.future);
      final sid = currentId ?? ensured;
      await store.addMessage(sid, ChatMessage(role: 'user', content: text));
    } catch (_) {}
    try {
      final tc = _parseTimerCommand(text);
      if (tc.action == _TimerAction.query) {
        if (_timers.isEmpty) {
          _appendAssistant('You do not have any timers running.');
        } else {
          final lines = <String>[];
          for (final t in _timers) {
            final remainingLabel = _formatHMSSigned(t.remainingSeconds);
            final originalHMS = _formatHMS(t.totalSeconds);
            if (t.completed) {
              lines.add('- Completed: $originalHMS.');
            } else if (t.paused) {
              lines.add('- Paused: $remainingLabel of $originalHMS.');
            } else if (_activeTimerId == t.id) {
              lines.add('- Active — $remainingLabel of $originalHMS.');
            } else {
              lines.add('- Counting down — $remainingLabel of $originalHMS.');
            }
          }
          _appendAssistant(
              'Here is the status of your timers:\n${lines.join('\n')}');
        }
        return;
      }
      if (tc.action == _TimerAction.create) {
        _engage('Time Agent');
        try {
          final queries = _extractTimerQueries(text);
          if (queries.isEmpty) {
            final r = await api.createCountdown(text);
            final target = r['target'] as String?;
            final id = r['timer_id'] as String?;
            if (target == null || id == null) {
              throw 'Timer creation failed.';
            }
            _startCountdown(id, target);
            if (tc.seconds != null) {
              // No assistant echo; the timer card shows status
            }
          } else {
            for (final q in queries) {
              final r = await api.createCountdown(q);
              final target = r['target'] as String?;
              final id = r['timer_id'] as String?;
              if (target == null || id == null) {
                throw 'Timer creation failed.';
              }
              _startCountdown(id, target);
              final tq = _parseTimerCommand(q);
              if (tq.seconds != null) {
                // No assistant echo; the timer card shows status
              }
            }
          }
          _disengage('Time Agent');
        } catch (e) {
          _disengage('Time Agent');
          _appendAssistant(
              'Please specify a valid duration in seconds, minutes, or hours.');
        }
        return;
      }
      // Orchestrator-first routing
      _engage('ADK Orchestrator');
      Map<String, dynamic> rr;
      try {
        final sid = await ref.read(ensureChatSessionIdProvider.future);
        final gse = ref.read(googleSearchEnabledProvider);
        rr = await api.chatRespond(text, sessionId: sid, googleSearch: gse);
      } catch (e) {
        if (!mounted) return;
        _disengage('ADK Orchestrator');
        NpSnackbar.show(context, '$e', type: NpSnackType.warning);
        return;
      }
      _disengage('ADK Orchestrator');
      final reply = (rr['text'] as String?) ?? '';
      final tools = rr['tools'];
      final toolsList = (tools is List) ? tools : <dynamic>[];

      // Check for body double tool activation
      for (var tool in toolsList) {
        if (tool is Map && tool['ui_mode'] == 'dopamine_card') {
          final reframe = tool['reframe'];
          _appendAssistant(
              "✨ **Dopamine Hacks - Pick Your Favorite!** ✨\n\n$reframe");
        }
      }

      if (reply.isNotEmpty || toolsList.isNotEmpty) {
        final askEmail = text.toLowerCase().contains('email');
        final parts = <String>[];
        if (reply.isNotEmpty) parts.add(reply);
        if (askEmail) {
          try {
            final ui = await api.googleUserinfo();
            if (ui['ok'] == true) {
              final em = ui['email'] as String?;
              if (em != null && em.isNotEmpty) {
                parts.add('Your connected Google account: $em');
              }
            }
          } catch (_) {}
        }
        final displayTools = toolsList
            .where((t) => !(t is Map &&
                (t.containsKey('ui_mode') || t['mode'] == 'stop')))
            .toList();
        if (displayTools.isNotEmpty) {
          parts.add('Tools: $displayTools');
        }
        if (parts.isEmpty) {
          final s = text.toLowerCase();
          if (s.contains('appointment') ||
              s.contains('calendar') ||
              s.contains('event') ||
              s.contains('today')) {
            try {
              final r = await api.calendarEventsToday();
              final events = (r['result']?['events'] as List<dynamic>? ?? []);
              if (events.isEmpty) {
                parts.add('No events found for today.');
              } else {
                final lines = events
                    .map((e) =>
                        '- ${e['summary'] ?? 'Untitled'} (${e['start'] ?? ''} - ${e['end'] ?? ''})')
                    .join('\n');
                parts.add('Today\'s events:\n$lines');
              }
            } catch (_) {}
          }
        }
        if (parts.isEmpty) {
          _appendAssistant('');
        } else {
          _appendAssistant(parts.join('\n'));
        }
        return;
      }
      // Fallback to legacy intent mapping if orchestrator did not respond
      final intent = _inferIntent(text);
      switch (intent) {
        case Intent.health:
          _engage('System');
          final r = await api.health();
          _disengage('System');
          _appendAssistant('System is healthy. Time: ${r['time']}');
          break;
        case Intent.atomize:
          _engage('TaskFlow Agent');
          final r = await api.atomizeTask(text);
          _disengage('TaskFlow Agent');
          final steps = (r['micro_steps'] as List<dynamic>? ?? [])
              .map((e) => '- $e')
              .join('\n');
          _appendAssistant('Engaging TaskFlow Agent...\n$steps');
          break;
        case Intent.schedule:
          final items = text
              .split(RegExp(r'[\n,;]+'))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
          _engage('TaskFlow Agent');
          final r = await api.scheduleTasks(items, 5, null);
          _disengage('TaskFlow Agent');
          _appendAssistant('Schedule created: ${r.toString()}');
          break;
        case Intent.countdown:
          _engage('Time Agent');
          final r = await api.createCountdown(text);
          _disengage('Time Agent');
          _appendAssistant(
              'Timer set. ID: ${r['timer_id']} warnings=${r['warnings']}');
          _startCountdown(r['timer_id'], r['target']);
          break;
        case Intent.reduce:
          final opts = text
              .split(RegExp(r'[\n,;]+'))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
          _engage('Decision Agent');
          final r = await api.reduceOptions(opts, 3);
          _disengage('Decision Agent');
          final ro = (r['reduced_options'] as List<dynamic>? ?? []).join(', ');
          _appendAssistant('Decision Support engaged. Reduced to: $ro');
          break;
        case Intent.energyMatch:
          final tasks = text
              .split(RegExp(r'[\n,;]+'))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
          _engage('Energy Agent');
          final r = await api.energyMatch(tasks, 3);
          _disengage('Energy Agent');
          _appendAssistant('Energy match: ${r.toString()}');
          break;
        case Intent.externalCapture:
          _engage('External Brain');
          final r = await api.captureExternal(text);
          _disengage('External Brain');
          final notes = await api.externalNotes();
          final lines = notes
              .map((e) =>
                  '- ${(e as Map<String, dynamic>)['title'] ?? 'Untitled'}')
              .join('\n');
          _appendAssistant(
              'External Brain captured. Task: ${r['task_id']}\nNotes:\n$lines');
          break;
        case Intent.calendarToday:
          _engage('Calendar Agent');
          final r = await api.calendarEventsToday();
          _disengage('Calendar Agent');
          final events = (r['result']?['events'] as List<dynamic>? ?? []);
          if (events.isEmpty) {
            _appendAssistant('No events found for today.');
          } else {
            final lines = events
                .map((e) =>
                    '- ${e['summary'] ?? 'Untitled'} (${e['start'] ?? ''} - ${e['end'] ?? ''})')
                .join('\n');
            _appendAssistant('Today\'s events:\n$lines');
          }
          break;
        case Intent.help:
          _engage('Assistant');
          final r = await api.chatHelp();
          _disengage('Assistant');
          final cmds =
              (r['help']?['commands'] as List<dynamic>? ?? []).cast<String>();
          setState(() => _dynamicSuggestions = cmds);
          _appendAssistant(
              'Here are available commands. Tap a suggestion to auto-fill.');
          break;
        case Intent.overview:
          _engage('Metrics Agent');
          final ov = await api.metricsOverview();
          _disengage('Metrics Agent');
          _appendAssistant('Today overview: ${ov.toString()}');
          break;
        case Intent.sessions:
          _engage('Sessions Agent');
          final sy = await api.sessionsYesterday();
          _disengage('Sessions Agent');
          _appendAssistant('Yesterday sessions: ${sy.toString()}');
          break;
        case Intent.unknown:
          _engage('Command Router');
          try {
            final sid = await ref.read(ensureChatSessionIdProvider.future);
            final gse = ref.read(googleSearchEnabledProvider);
            final r =
                await api.chatCommand(text, sessionId: sid, googleSearch: gse);
            _disengage('Command Router');
            if (r['ok'] == true) {
              final sugg =
                  (r['suggestions'] as List<dynamic>? ?? []).cast<String>();
              if (sugg.isNotEmpty) setState(() => _dynamicSuggestions = sugg);
              _appendAssistant(r.toString());
            } else {
              _appendAssistant(
                  'I did not understand. Try "help" to see supported commands.');
            }
          } catch (_) {
            _disengage('Command Router');
            _appendAssistant('Error handling command. Try "help".');
          }
          break;
      }
    } catch (e) {
      if (!mounted) return;
      NpSnackbar.show(context, '$e', type: NpSnackType.destructive);
      _appendAssistant('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _input.clear();
      }
    }
  }

  /// Appends an assistant message to the chat and optionally speaks it.
  ///
  /// Adds the message to the local list, persists it to the [ChatStore],
  /// and triggers TTS if voice output is enabled.
  void _appendAssistant(String content) async {
    setState(() {
      _messages.add(ChatMessage(role: 'assistant', content: content));
    });
    _scrollToBottom();
    try {
      final store = ref.read(chatStoreProvider);
      final currentId = ref.read(chatSessionIdProvider);
      final ensured = await ref.read(ensureChatSessionIdProvider.future);
      final sid = currentId ?? ensured;
      await store.addMessage(
          sid, ChatMessage(role: 'assistant', content: content));
      await store.markRead(sid);
    } catch (_) {}

    // Speak the response if voice output is enabled
    if (_voiceOutput && _tts.supported) {
      setState(() => _speaking = true);
      _tts.volume = _volume;
      await _tts.speak(content);
      if (mounted) {
        setState(() => _speaking = false);
      }
    }
  }

  /// Shows the voice control bottom sheet.
  ///
  /// Allows the user to toggle voice session, voice output, and adjust volume.
  Future<void> _showVoiceControls(BuildContext context) async {
    await NpBottomSheet.show(
      context: context,
      child: StatefulBuilder(
        builder: (BuildContext context, StateSetter setSheetState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                      child: Text('Conversation Mode',
                          style: Theme.of(context).textTheme.titleMedium)),
                  Switch(
                      value: _voiceSession,
                      onChanged: (v) {
                        Navigator.pop(context);
                        _toggleVoiceSession();
                      }),
                ],
              ),
              const SizedBox(height: DesignTokens.spacingSm),
              Row(
                children: [
                  Expanded(
                      child: Text('Voice Output',
                          style: Theme.of(context).textTheme.titleMedium)),
                  Switch(
                      value: _voiceOutput,
                      onChanged: (v) {
                        setSheetState(() => _voiceOutput = v);
                        setState(() => _voiceOutput = v);
                      }),
                ],
              ),
              const SizedBox(height: DesignTokens.spacingSm),
              Row(children: [
                const Icon(Icons.volume_down),
                Expanded(
                  child: Slider(
                    value: _volume,
                    min: 0.0,
                    max: 1.0,
                    onChanged: (v) {
                      setSheetState(() => _volume = v);
                      setState(() {
                        _volume = v;
                        _tts.volume = v;
                      });
                    },
                  ),
                ),
                const Icon(Icons.volume_up),
              ]),
              const SizedBox(height: DesignTokens.spacingSm),
              Row(children: [
                Expanded(
                    child: Text('Microphone',
                        style: Theme.of(context).textTheme.titleMedium)),
                NpBadge(
                    text: _speech.supported ? 'Present' : 'Absent',
                    type: _speech.supported
                        ? NpBadgeType.success
                        : NpBadgeType.warning),
              ]),
              const SizedBox(height: DesignTokens.spacingSm),
              Row(children: [
                Expanded(
                    child: Text('Speaking',
                        style: Theme.of(context).textTheme.titleMedium)),
                NpBadge(
                    text: _speaking ? 'On' : 'Off',
                    type:
                        _speaking ? NpBadgeType.success : NpBadgeType.neutral),
              ]),
            ],
          );
        },
      ),
    );
  }

  /// Toggles the voice session state.
  ///
  /// Starts or stops the speech recognition and TTS loop.
  void _toggleVoiceSession() {
    setState(() => _voiceSession = !_voiceSession);
    if (_voiceSession) {
      _startListeningForSession();
    } else {
      // Immediately stop everything and cancel pending restarts
      _voiceRestartTimer?.cancel();
      _voiceRestartTimer = null;
      _speech.stop();
      _tts.stop();
      setState(() {
        _listening = false;
        _partialText = '';
        _soundLevel = 0.0;
        _consecutiveSilence = 0;
        _engaged.remove('SpeechRecognition');
      });
    }
  }

  /// Starts listening for voice input.
  ///
  /// Handles speech recognition lifecycle, partial results, and silence detection.
  /// Automatically submits the recognized text when silence is detected.
  Future<void> _startListeningForSession() async {
    if (!mounted) return;
    if (!(_voiceSession || _voiceOutput)) return;

    // Prevent starting if already listening
    if (_listening) return;

    if (_speaking) {
      _voiceRestartTimer?.cancel();
      _voiceRestartTimer = Timer(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        _startListeningForSession();
      });
      return;
    }
    try {
      await _tts.stop();
    } catch (_) {}
    if (!mounted) return;
    if (!_speech.supported) {
      if (mounted) {
        NpSnackbar.show(
            context, 'Voice recording not supported on this device/browser.',
            type: NpSnackType.destructive);
      }
      setState(() => _voiceSession = false);
      return;
    }
    setState(() {
      if (!_engaged.contains('SpeechRecognition')) {
        _engaged.add('SpeechRecognition');
      }
      _listening = true;
    });
    _partialSub?.cancel();
    _partialSub = _speech.partialUpdates.listen((s) {
      setState(() => _partialText = s);
    });
    _levelSub?.cancel();
    _levelSub = _speech.levelUpdates.listen((v) {
      setState(() => _soundLevel = v);
    });
    final t = await _speech.startOnce();
    final lastPartial = _partialText;
    _partialSub?.cancel();
    _levelSub?.cancel();
    final a = (t ?? '').trim();
    final b = lastPartial.trim();
    final candidate =
        (a.length >= b.length && a.isNotEmpty) ? a : (b.isNotEmpty ? b : '');
    final finalText = _formatTranscript(candidate);
    if (!mounted) return;
    setState(() {
      _engaged.remove('SpeechRecognition');
      _listening = false;
      _partialText = '';
      _soundLevel = 0.0;
    });
    if (finalText.isNotEmpty) {
      setState(() => _consecutiveSilence = 0);
      final api = ref.read(apiClientProvider);
      if (_backendOk) {
        _input.text = finalText;
        await _handleSubmit(api, isVoice: true);
      } else {
        _pendingVoiceText = finalText;
        if (!_offlineHoldNoticeShown) {
          _offlineHoldNoticeShown = true;
          _showModeBannerNow('Backend offline — holding your voice message');
        }
      }
    } else {
      setState(() => _consecutiveSilence++);

      // Stop after 3 consecutive empty recognitions to prevent infinite loop
      if (_consecutiveSilence >= 3) {
        if (mounted) {
          setState(() {
            _voiceSession = false;
            _voiceOutput = false;
            _consecutiveSilence = 0;
          });
          NpSnackbar.show(
            context,
            'Voice session paused due to inactivity. Click the voice button to resume.',
            type: NpSnackType.info,
          );
        }
        return;
      }

      if ((_voiceSession || _voiceOutput) && mounted) {
        // Only restart if we're still in voice session mode
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted || (!_voiceSession && !_voiceOutput)) return;
          // Only restart if session hasn't been stopped
          _startListeningForSession();
        });
      }
    }
  }

  /// Adds an agent or component to the list of engaged entities.
  ///
  /// Used to track active processes (e.g., 'Time Agent', 'SpeechRecognition').
  void _engage(String name) {
    setState(() {
      if (!_engaged.contains(name)) {
        _engaged.add(name);
      }
    });
  }

  /// Removes an agent or component from the list of engaged entities.
  void _disengage(String name) {
    setState(() {
      _engaged.removeWhere((e) => e == name);
    });
  }

  /// Formats a duration in seconds into a human-readable string (e.g., "1 hour 30 minutes").
  String _formatExactDuration(int seconds) {
    if (seconds <= 0) return '0 seconds';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final parts = <String>[];
    if (h > 0) parts.add('$h ${h == 1 ? 'hour' : 'hours'}');
    if (m > 0) parts.add('$m ${m == 1 ? 'minute' : 'minutes'}');
    if (h == 0 && s > 0) parts.add('$s ${s == 1 ? 'second' : 'seconds'}');
    return parts.join(' ');
  }

  /// Parses a natural language query for timer commands.
  ///
  /// Identifies if the user wants to create a timer or query existing timers.
  /// Extracts duration and unit if creating a timer.
  _TimerParseResult _parseTimerCommand(String q) {
    final s = q.toLowerCase();
    final hasTimerWord = s.contains('timer') || s.contains('countdown');
    final isQuery = hasTimerWord &&
        (s.contains('do i have') ||
            s.contains('any') ||
            s.contains('running') ||
            s.contains('status') ||
            s.contains('remaining') ||
            s.contains('what')) &&
        !(s.contains('start') ||
            s.contains('set') ||
            s.contains('add') ||
            s.contains('begin') ||
            s.contains('another'));
    if (isQuery) return _TimerParseResult(_TimerAction.query);
    final reNum = RegExp(
        r"(\d+)\s*(second|seconds|sec|s|minute|minutes|min|m|hour|hours|hr|h)\b");
    final m = reNum.firstMatch(s);
    if (hasTimerWord &&
        (s.contains('start') ||
            s.contains('set') ||
            s.contains('add') ||
            s.contains('begin') ||
            s.contains('another') ||
            m != null)) {
      int? secs;
      if (m != null) {
        final n = int.tryParse(m.group(1)!);
        final unit = m.group(2)!;
        if (n != null && n > 0) {
          if (unit.startsWith('s')) {
            secs = n;
          } else if (unit.startsWith('m')) {
            secs = n * 60;
          } else {
            secs = n * 3600;
          }
        }
      }
      return _TimerParseResult(_TimerAction.create,
          seconds: secs, additional: s.contains('another'));
    }
    return _TimerParseResult(_TimerAction.unknown);
  }

  /// Formats seconds into HH:MM:SS format.
  String _formatHMS(int seconds) {
    if (seconds < 0) seconds = -seconds;
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Formats seconds into HH:MM:SS format with a sign prefix.
  String _formatHMSSigned(int seconds) {
    final sign = seconds < 0 ? '-' : '';
    return '$sign${_formatHMS(seconds)}';
  }

  /// Extracts multiple timer queries from a single string.
  ///
  /// Useful for handling compound commands like "set a 5 minute timer and a 10 second timer".
  List<String> _extractTimerQueries(String q) {
    final s = q.toLowerCase();
    final re = RegExp(
        r"(\d+)\s*(second|seconds|sec|s|minute|minutes|min|m|hour|hours|hr|h)\b");
    final ms = re.allMatches(s).toList();
    if (ms.isEmpty) return [];
    final queries = <String>[];
    for (final m in ms) {
      final n = int.tryParse(m.group(1)!);
      final unit = m.group(2)!;
      if (n == null || n <= 0) continue;
      String normalized;
      if (unit.startsWith('s')) {
        normalized = 'set timer for $n seconds';
      } else if (unit.startsWith('m')) {
        normalized = 'set timer for $n minutes';
      } else {
        normalized = 'set timer for $n hours';
      }
      queries.add(normalized);
    }
    return queries;
  }

  /// Shows a bottom sheet with advanced tools and suggestions.
  ///
  /// Includes tools like 'Doom Scroll Rescue' and 'External Brain',
  /// as well as dynamic suggestions based on recent interactions.
  Future<void> _showMoreSuggestions(
      BuildContext context, AppLocalizations l) async {
    await NpBottomSheet.show(
      context: context,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.only(bottom: DesignTokens.spacingMd),
              child: Text(l.advancedToolsLabel,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      )),
            ),

            // Critical Tools Section
            Row(
              children: [
                Expanded(
                  child: _buildToolCard(
                    context,
                    label: 'Doom Scroll\nRescue',
                    icon: Icons.warning_amber_rounded,
                    color: DesignTokens.error,
                    onTap: () {
                      Navigator.pop(context);
                      _triggerDoomScrollRescue();
                    },
                  ),
                ),
                const SizedBox(width: DesignTokens.spacingMd),
                Expanded(
                  child: _buildToolCard(
                    context,
                    label: 'External\nBrain',
                    icon: Icons.psychology,
                    color: DesignTokens.primary,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed(Routes.external);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: DesignTokens.spacingXl),

            // Suggestions Section
            Text(l.suggestionsLabel,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    )),
            const SizedBox(height: DesignTokens.spacingSm),
            Wrap(
              spacing: DesignTokens.spacingSm,
              runSpacing: DesignTokens.spacingSm,
              children: [
                NpChip(
                    label: l.suggestReduce,
                    onTap: () {
                      Navigator.pop(context);
                      _setInput(l.exampleReduce);
                    }),
                NpChip(
                    label: l.suggestEnergyMatch,
                    onTap: () {
                      Navigator.pop(context);
                      _setInput(l.exampleEnergyMatch);
                    }),
                NpChip(
                    label: l.suggestCapture,
                    onTap: () {
                      Navigator.pop(context);
                      _setInput(l.exampleCapture);
                    }),
                ..._dynamicSuggestions.map((s) => NpChip(
                    label: s,
                    onTap: () {
                      Navigator.pop(context);
                      _setInput(s);
                    })),
              ],
            ),
            const SizedBox(height: DesignTokens.spacingLg),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  /// Builds a UI card for a tool (e.g., Doom Scroll Rescue).
  Widget _buildToolCard(BuildContext context,
      {required String label,
      required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(DesignTokens.spacingMd),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: DesignTokens.spacingSm),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);

    // Observe app lifecycle for Just-in-Time Prompts on mobile
    if (!kIsWeb) {
      WidgetsBinding.instance.addObserver(this);
    }

    // Auto-start proactive check-ins (disabled in tests)
    if (!_isTestEnv) {
      _startProactiveCheckins();
    }

    _pulseCtl = AnimationController(
        vsync: this, duration: Duration(milliseconds: _pulseSpeedMs));
    // Removed redundant setState listener as ScaleTransition handles the animation updates

    if (!_isTestEnv) {
      _pulseCtl.repeat(reverse: true);
    }
    if (_isTestEnv) {
      _testRebuilder?.cancel();
      _testRebuilder = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!mounted) return;
        setState(() {});
      });
    }
    _pulseScale = Tween<double>(begin: 0.9, end: 1.15)
        .animate(CurvedAnimation(parent: _pulseCtl, curve: Curves.easeInOut));
    _speakingSub?.cancel();
    _speakingSub = _tts.speaking.listen((s) {
      if (!mounted) return;
      setState(() => _speaking = s);
      if (!s && !_listening && !_loading && (_voiceSession || _voiceOutput)) {
        Future.delayed(
            const Duration(milliseconds: 1200), _startListeningForSession);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final tsMs =
          SchedulerBinding.instance.currentFrameTimeStamp.inMilliseconds;
      _epochBaseMs = DateTime.now().millisecondsSinceEpoch - tsMs;
      await _loadPulsePrefs();
      await _pingBackend();
      try {
        await ref.read(loadGoogleSearchEnabledProvider.future);
        await ref.read(loadFirestoreSyncEnabledProvider.future);
      } catch (_) {}
      try {
        final currentId = ref.read(chatSessionIdProvider);
        final ensured = await ref.read(ensureChatSessionIdProvider.future);
        final sid = currentId ?? ensured;
        ref.read(chatSessionIdProvider.notifier).state = sid;
        final store = ref.read(chatStoreProvider);
        await store.attachSessionsListener();
        await store.attachMessagesListener(sid);
        final pageMsgs = await store.getMessages(sid, page: 0, pageSize: 50);
        if (mounted) {
          setState(() {
            if (pageMsgs.isNotEmpty) {
              _messages.addAll(pageMsgs);
            }
            _hasMoreMessages = pageMsgs.length >= 50;
          });
          if (pageMsgs.isNotEmpty) _scrollToBottom();
        }
        await store.markRead(sid);
      } catch (_) {}
      if (!_isTestEnv) {
        _heartbeat?.cancel();
        _heartbeat = Timer.periodic(const Duration(seconds: 10), (_) async {
          await _pingBackend();
        });
      }
    });
  }

  Future<void> _loadPulsePrefs() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    final speed = p.getInt('pulse_speed_ms');
    final base = p.getInt('pulse_base_color');
    setState(() {
      if (speed != null) _pulseSpeedMs = speed;
      _pulseBaseColor = base != null ? Color(base) : null;
      _pulseCtl.duration = Duration(milliseconds: _pulseSpeedMs);
      if (!_isTestEnv) {
        _pulseCtl.repeat(reverse: true);
      }
    });
  }

  bool get _isTestEnv {
    final t = WidgetsBinding.instance.runtimeType.toString();
    return t.contains('TestWidgetsFlutterBinding') ||
        t.contains('LiveTestWidgetsFlutterBinding') ||
        t.contains('AutomatedTestWidgetsFlutterBinding');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _appPausedTime = DateTime.now();
      debugPrint("App paused at $_appPausedTime");
    } else if (state == AppLifecycleState.resumed) {
      if (_appPausedTime != null) {
        final awayDuration = DateTime.now().difference(_appPausedTime!);
        debugPrint("App resumed, was away for ${awayDuration.inSeconds}s");
        if (awayDuration.inSeconds >= _jitThresholdSeconds) {
          _triggerJustInTimePrompt(awayDuration.inSeconds);
        }
        _appPausedTime = null;
      }
    }
  }

  Future<void> _pingBackend() async {
    if (!mounted) return;
    final api = ref.read(apiClientProvider);
    try {
      final r = await api.health();
      final wasOk = _backendOk;
      if (!mounted) return;
      setState(() => _backendOk = r['ok'] == true);
      if (_backendOk && !wasOk && _pendingVoiceText != null) {
        final t = _pendingVoiceText!;
        _pendingVoiceText = null;
        _offlineHoldNoticeShown = false;
        await _handleSubmit(api, isVoice: true, textOverride: t);
        if (mounted) {
          _showModeBannerNow('Sent held voice message');
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _backendOk = false);
    }
  }

  DateTime _now() {
    return DateTime.now();
  }

  Widget _timerCard(BuildContext context, _TimerItem t) {
    final active = _activeTimerId == t.id && !t.paused && !t.completed;
    final cs = Theme.of(context).colorScheme;
    final now = _now();
    final remLive = (t.paused || t.completed)
        ? t.remainingSeconds
        : (() {
            final r = (t.target.difference(now).inMilliseconds / 1000).ceil();
            return r < 0 ? 0 : (r > t.totalSeconds ? t.totalSeconds : r);
          })();

    if (!t.paused && remLive <= 0) {
      scheduleMicrotask(() {
        if (!mounted) return;
        setState(() {
          _timers.removeWhere((x) => x.id == t.id);
          if (_activeTimerId == t.id) {
            _activeTimerId = _timers.isNotEmpty ? _timers.last.id : null;
          }
        });
      });
      return const SizedBox.shrink();
    }

    final total = t.totalSeconds > 0 ? t.totalSeconds : 1;
    final progress = (remLive / total).clamp(0.0, 1.0);

    // Color Logic
    Color timerColor;
    if (progress > 0.5) {
      timerColor = cs.primary;
    } else if (progress > 0.2) {
      timerColor = cs.tertiary;
    } else {
      timerColor = cs.error;
    }
    if (t.paused) timerColor = cs.outline;
    if (t.completed) timerColor = cs.secondary;

    final originalHMS = _formatHMS(t.totalSeconds);
    final remainingLabel = _formatHMS(remLive);

    return Container(
      key: ValueKey('timer-card-${t.id}'),
      margin: const EdgeInsets.only(bottom: DesignTokens.spacingSm),
      padding: const EdgeInsets.all(DesignTokens.spacingMd),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        border: Border.all(color: timerColor.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: timerColor.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Circular Progress with Time
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  value: progress,
                  backgroundColor: cs.surfaceContainerHighest,
                  color: timerColor,
                  strokeWidth: 6,
                  strokeCap: StrokeCap.round,
                ),
              ),
              if (t.paused)
                Icon(Icons.pause, color: timerColor)
              else if (t.completed)
                Icon(Icons.check, color: timerColor)
              else
                Icon(Icons.timer,
                    color: timerColor.withValues(alpha: 0.8), size: 24),
            ],
          ),
          const SizedBox(width: DesignTokens.spacingMd),
          // Text Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.completed
                      ? 'Completed'
                      : (t.paused ? 'Paused' : 'Focusing...'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: timerColor,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                ),
                Text(
                  remainingLabel,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: [const FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  'of $originalHMS',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          // Controls
          if (!t.completed)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.filledTonal(
                  icon: Icon(t.paused ? Icons.play_arrow : Icons.pause),
                  onPressed: () {
                    setState(() {
                      if (t.paused) {
                        t.paused = false;
                        _activeTimerId = t.id;
                        t.completed = false;
                        t.target =
                            _now().add(Duration(seconds: t.remainingSeconds));
                        _appendAssistant(
                            'Timer resumed. Counting down from ${_formatExactDuration(t.remainingSeconds)}.');
                      } else {
                        t.paused = true;
                        _appendAssistant(
                            'Timer paused with ${_formatExactDuration(t.remainingSeconds)} remaining.');
                      }
                    });
                  },
                  tooltip: t.paused ? 'Resume' : 'Pause',
                  style: IconButton.styleFrom(
                    backgroundColor: timerColor.withValues(alpha: 0.1),
                    foregroundColor: timerColor,
                  ),
                ),
                const SizedBox(width: DesignTokens.spacingXs),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _timers.removeWhere((x) => x.id == t.id);
                      if (_activeTimerId == t.id) {
                        _activeTimerId =
                            _timers.isNotEmpty ? _timers.last.id : null;
                      }
                    });
                    _appendAssistant('Timer cancelled.');
                  },
                  tooltip: 'Cancel',
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _showModeBannerNow(String text) {
    _modeBannerTimer?.cancel();
    setState(() {
      _modeBannerText = text;
      _showModeBanner = true;
    });
    _modeBannerTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() => _showModeBanner = false);
    });
  }
}
