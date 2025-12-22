import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
import '../core/components/pulse_indicator.dart';
import '../core/components/calendar_events_widget.dart';
import '../core/components/task_breakdown_card.dart';
import '../core/components/dopamine_card.dart';
import '../core/components/decision_helper_card.dart';
import '../core/components/reevaluation_card.dart';
import '../core/components/task_prioritization_widget.dart';
import '../core/components/notion_page_widget.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import '../services/api_client.dart';
import '../state/session_state.dart';
import '../state/health_state.dart';
import '../state/chat_store.dart';
import '../core/speech_service.dart';
import '../core/cloud_stt_service.dart';
import '../core/tts_service.dart';
import '../core/routes.dart';
// import '../core/link_opener.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../state/user_settings_store.dart';
import '../state/energy_store.dart';
import 'voice_mode_screen.dart';
import '../core/components/agent_widgets.dart';
import '../services/body_doubling_service.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/echo_cancellation_service.dart';
import '../core/realtime_voice_service.dart';
import '../core/realtime_audio_capture.dart';
import '../state/realtime_voice_provider.dart';
import '../state/notion_provider.dart';

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
  taskPrioritization,
  unknown,
}

/// Represents a countdown timer item.
class _TimerItem {
  _TimerItem({
    required this.id,
    required this.target,
    required this.totalSeconds,
    required this.remainingSeconds,
    this.label,
  });
  final String id;
  DateTime target;
  final int totalSeconds;
  int remainingSeconds;
  final String? label;
  bool paused = false;
  bool completed = false;

  DateTime? completedAt;
  int? testStartMs;
  int? testCompletedAtMs;
  int lastProgressState = 0; // 0: >50%, 1: <=50%, 2: <=25%
  int lastCountdownMark = 0;
}

/// Actions inferred from a timer command.
enum _TimerAction { create, query, unknown }

enum _VoiceCardType {
  none,
  quickCapture,
  list,
  captureThought,
  taskBreakdown,
  decisionHelper,
  dopamine,
  timer,
  taskPrioritization,
  notionPage,
}

/// Result of parsing a timer command.
class _TimerParseResult {
  _TimerParseResult(this.action, {this.seconds, this.additional = false});
  final _TimerAction action;
  final int? seconds;
  final bool additional;
}

/// The main chat screen widget.
class ChatScreen extends ConsumerStatefulWidget {
  final bool initialVoiceMode;
  const ChatScreen({super.key, this.initialVoiceMode = false});
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
  static const int _maxVoiceCardStackSize = 5;
  static const double _timerHalfProgressThreshold = 0.5;
  static const double _timerSeventyFiveElapsedThreshold = 0.25;
  static const List<int> _timerCountdownCalloutsSeconds = [10, 5, 3, 2, 1];

  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _input = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  bool _loading = false;
  bool _isSubmitting = false; // Guard against double-submissions
  bool _voiceMode = false;
  final SpeechService _speech = createSpeechService();
  final TtsService _tts = createTtsService();
  final EchoCancellationService _echoCancellation = EchoCancellationService();
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
  DateTime? _lastTtsEndAt; // For echo cancellation cooldown
  DateTime? _lastTimerCreatedAt; // Cooldown for timer creation
  // Legacy timer confirmation state (no longer used because timers do not consume credits).

  // Calendar Events
  List<dynamic> _calendarEvents = [];
  List<dynamic> _taskBreakdownSteps = [];
  List<String> _decisionOptions = [];
  List<String> _genericListItems = [];
  String _genericListTitle = 'List';
  String _dopamineContent = '';
  List<PrioritizedTaskItem> _prioritizedTasks = [];
  String _prioritizationReasoning = '';
  int _originalTaskCount = 0;
  
  // Notion Page State
  Map<String, dynamic>? _notionPageData;
  
  String _modeBannerText = '';
  Timer? _modeBannerTimer;
  bool _focusMode = false;
  int _energyLevel = 5;
  final bool _minimalMode = false;
  bool _showTimersSection = false;
  bool _showInactivityPrompt = false;
  bool _bodyDoubleActive = false;
  String _inactivityPromptText = '';

  // Body Doubling Check-in State
  String? _pendingCheckInMessage;
  bool _showCheckInBanner = false;
  Timer? _checkInBannerTimer;
  int _checkInTimerSeconds = 0;
  Timer? _checkInCountdownTimer;

  bool _voiceOutput = false;
  bool _speaking = false;
  double _volume = 1.0;
  double _soundLevel = 0.0;
  bool _voiceSession = false;
  bool _voiceSessionActive = false;
  bool _micMuted = false;
  int _responseGeneration = 0;
  String? _sessionTtsVoice;
  String? _sessionTtsQuality;
  String? _bargeCandidate;
  String _currentTtsText = '';
  DateTime? _ttsStartAt;
  int _lastBargeInMs = 0;
  final int _minBargeDelayMs = 400;
  double _sessionMaxAmp = 0.0;
  int _consecutiveSilence = 0;
  Timer? _voiceRestartTimer; // Cancellable timer for voice session restart
  Timer? _cloudSttTimeoutTimer; // Timer for Cloud STT timeout
  String? _pendingVoiceText;
  bool _offlineHoldNoticeShown = false;
  bool _canResume = false;
  Completer<String?>? _voiceCompleter; // For Cloud STT

  StreamSubscription<String>? _partialSub;
  StreamSubscription<double>? _levelSub;
  StreamSubscription<bool>? _speakingSub;

  // Realtime Voice Mode (Gemini Live API)
  bool _useRealtimeVoice = false; // Toggle between legacy and realtime voice
  StreamSubscription<VoiceSessionState>? _realtimeStateSub;
  StreamSubscription<String>? _realtimeTextSub;
  StreamSubscription<TranscriptEvent>? _realtimeTranscriptSub;
  RealtimeAudioCapture? _realtimeAudioCapture;
  StreamSubscription<Uint8List>? _realtimeAudioSub;

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
  Timer? _ampTimer;
  Ticker? _shortTimerTicker;
  int _testNowMs = 0;
  String? _activeTimerId;
  int _pulseSpeedMs = 900;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _a2aSub;
  final Map<String, String> _lastA2AStatus = {};

  _VoiceCardType _voiceCardType = _VoiceCardType.none;
  final List<_VoiceCardType> _voiceCardStack = [];

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
    _ampTimer?.cancel();
    _shortTimerTicker?.dispose();
    _heartbeat?.cancel();
    _modeBannerTimer?.cancel();
    _sessionTimer?.cancel();
    _inactivityTimer?.cancel();
    _voiceRestartTimer?.cancel();
    _cloudSttTimeoutTimer?.cancel();
    _checkInBannerTimer?.cancel();
    _checkInCountdownTimer?.cancel();
    _a2aSub?.cancel();

    // Cancel subscriptions
    _partialSub?.cancel();
    _levelSub?.cancel();
    _speakingSub?.cancel();
    
    // Cancel realtime voice subscriptions
    _realtimeStateSub?.cancel();
    _realtimeTextSub?.cancel();
    _realtimeTranscriptSub?.cancel();
    _realtimeAudioSub?.cancel();
    _realtimeAudioCapture?.dispose();

    // Stop voice services
    _speech.stop();
    _tts.stop();
    // Note: Cloud STT is handled by provider autoDispose

    if (_voiceCompleter != null && !_voiceCompleter!.isCompleted) {
      _voiceCompleter!.complete(null);
    }

    // Dispose controllers and listeners
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _input.dispose();
    _inputFocusNode.dispose();

    // Stop voice session loop
    _voiceSessionActive = false;
    _speech.stop();
    _tts.stop();

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
      if (!_scrollController.position.hasContentDimensions) return;

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
    final isBackendOk = ref.watch(backendHealthProvider);
    final settings = ref.watch(userSettingsProvider);
    // Keep Cloud STT service alive while screen is mounted to prevent premature disposal
    ref.watch(cloudSttServiceProvider);

    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 700;
    final hp = isWide ? DesignTokens.spacingXl : DesignTokens.spacingLg;

    // Sync local backendOk with provider
    if (_backendOk != isBackendOk) {
      // Defer state update to next frame to avoid build collisions
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _backendOk = isBackendOk);
      });
    }

    // Keep Cloud STT service alive while screen is mounted to prevent premature disposal
    ref.watch(cloudSttServiceProvider);

    // Listen for voice settings changes and update TTS service
    ref.listen(userSettingsProvider, (prev, next) {
      if (prev?.ttsVoice != next.ttsVoice || prev?.ttsQuality != next.ttsQuality) {
        _tts.setOptions(voice: next.ttsVoice, quality: next.ttsQuality);
        debugPrint('[TTS] Settings updated: voice=${next.ttsVoice}, quality=${next.ttsQuality}');
      }
    });

    // Listen for body doubling check-in messages
    final bodyDoubleState = ref.watch(bodyDoublingServiceProvider);
    ref.listen(bodyDoublingServiceProvider, (prev, next) {
      if (next.pendingCheckInMessage != null &&
          next.pendingCheckInMessage != prev?.pendingCheckInMessage) {
        _showCheckInNotification(
            next.pendingCheckInMessage!, next.isWaitingForResponse);
      }
    });

    // Sync body double active state with provider
    if (_bodyDoubleActive != bodyDoubleState.isActive) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _bodyDoubleActive = bodyDoubleState.isActive);
        }
      });
    }

    if (_voiceMode) {
      final headerTitle = _voiceCardType == _VoiceCardType.captureThought
          ? 'BRAIN ASSISTANT'
          : 'FOCUS COACH';
      final headerSubtitle = _voiceCardType == _VoiceCardType.captureThought
          ? 'Voice Mode'
          : 'Voice Dialogue';

      String agentText = '';
      // Suppress agent text if a dynamic widget is active (dopamine, task, etc.)
      if (_voiceCardType != _VoiceCardType.none &&
          _voiceCardType != _VoiceCardType.captureThought &&
          _voiceCardType != _VoiceCardType.quickCapture) {
        agentText = '';
      } else {
        if (_currentTtsText.isNotEmpty) {
          agentText = _currentTtsText;
        } else {
          for (var i = _messages.length - 1; i >= 0; i--) {
            if (_messages[i].role == 'assistant') {
              agentText = _messages[i].content;
              break;
            }
          }
        }
        if (agentText.isEmpty) agentText = "I'm listening...";
      }

      return VoiceModeScreen(
        isListening: _listening,
        isMuted: _micMuted,
        agentText: agentText,
        headerTitle: headerTitle,
        headerSubtitle: headerSubtitle,
        centerCard: _buildPrimaryVoiceCard(context),
        onBack: () {
          setState(() {
            _voiceMode = false;
            _voiceSessionActive = false;
          });
        },
        onMute: () {
          setState(() {
            _micMuted = !_micMuted;
            if (_micMuted) {
              _speech.stop();
              _listening = false;
              _soundLevel = 0.0;
            }
          });
        },
        onPause: () {
          setState(() {
            // Transition to chat screen, but KEEP SESSION ACTIVE for background listening
            _voiceMode = false;
            // Stop TTS if speaking, but don't kill the session loop
            _tts.stop();
          });
        },
        onKeyboard: () {
          setState(() {
            _voiceMode = false;
          });
          // Request focus on the text field after a short delay to allow UI to rebuild
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) _inputFocusNode.requestFocus();
          });
        },
        onOptionSelected: (text) {
          _handleSubmit(api, textOverride: text);
        },
      );
    }

    return Scaffold(
      appBar: NpAppBar(
        title: 'Altered',
        // showBack defaults to true, which we want for navigation from Dashboard
        actions: [
          // Body Doubling Active Indicator
          if (_bodyDoubleActive)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spacingXs),
              child: GestureDetector(
                onTap: () async {
                  // Show stop confirmation or mode info
                  ref.read(bodyDoublingServiceProvider.notifier).stopSession();
                  setState(() => _bodyDoubleActive = false);
                  NpSnackbar.show(context, 'Body Double Stopped',
                      type: NpSnackType.info);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2B58D).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFE2B58D).withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people_outline,
                          size: 14, color: Color(0xFFE2B58D)),
                      const SizedBox(width: 4),
                      Text(
                        'BD',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFE2B58D),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (kDebugMode &&
              _voiceSessionActive &&
              settings.voiceLockDuringSession)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: DesignTokens.spacingXs),
              child: NpBadge(text: 'Voice Locked'),
            ),
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
                case 'metrics':
                  Navigator.of(context).pushNamed(Routes.metrics);
                  break;
                case 'focus_mode':
                  setState(() => _focusMode = !_focusMode);
                  _showModeBannerNow(l.focusModeLabel);
                  break;
                case 'body_double':
                  if (_bodyDoubleActive) {
                    // Stop body doubling
                    ref
                        .read(bodyDoublingServiceProvider.notifier)
                        .stopSession();
                    setState(() {
                      _bodyDoubleActive = false;
                      _inactivityTimer?.cancel();
                      _sessionTimer?.cancel();
                      _proactiveStarted = false;
                    });
                    NpSnackbar.show(context, 'Body Double Stopped',
                        type: NpSnackType.info);
                  } else {
                    // Show mode selection dialog
                    await _showBodyDoubleModeDialog();
                  }
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
              const PopupMenuItem<String>(
                value: 'metrics',
                child: ListTile(
                  leading: Icon(Icons.insights),
                  title: Text('Metrics'),
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
                    children: _engaged
                        .toSet()
                        .take(4)
                        .map((e) => NpChip(label: e, selected: true))
                        .toList(),
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
                      onPressed: () async {
                        // Cancel any pending restart and stop all voice services
                        _voiceRestartTimer?.cancel();
                        _voiceRestartTimer = null;
                        _speech.stop();
                        _tts.stop();

                        // Handle Cloud STT stop
                        if (_voiceCompleter != null &&
                            !_voiceCompleter!.isCompleted) {
                          // Show processing state?
                          setState(() => _partialText = 'Processing...');
                          final cloudStt = ref.read(cloudSttServiceProvider);
                          final text = await cloudStt.stopAndTranscribe();
                          _voiceCompleter!.complete(text);
                          _voiceCompleter = null;
                        }

                        setState(() {
                          _listening = false;
                          _voiceSession = false;
                          _voiceSessionActive = false;
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
          if (!_focusMode &&
              !_minimalMode &&
              !_showInactivityPrompt &&
              !_voiceMode &&
              !_voiceSessionActive)
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
            child: _voiceMode || _voiceSessionActive
                ? _buildVoiceDialoguePane(context, hp)
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: EdgeInsets.symmetric(
                        horizontal: hp, vertical: DesignTokens.spacingLg),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, i) {
                      final m = _messages[_messages.length - 1 - i];
                      final isUser = m.role == 'user';
                      return Padding(
                        padding: const EdgeInsets.only(
                            bottom: DesignTokens.spacingMd),
                        child: Row(
                          mainAxisAlignment: isUser
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isUser) ...[
                              CircleAvatar(
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .secondaryContainer,
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
                                    topLeft: const Radius.circular(
                                        DesignTokens.radiusLg),
                                    topRight: const Radius.circular(
                                        DesignTokens.radiusLg),
                                    bottomLeft: isUser
                                        ? const Radius.circular(
                                            DesignTokens.radiusLg)
                                        : const Radius.circular(
                                            DesignTokens.radiusSm),
                                    bottomRight: isUser
                                        ? const Radius.circular(
                                            DesignTokens.radiusSm)
                                        : const Radius.circular(
                                            DesignTokens.radiusLg),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    )
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (m.content.isNotEmpty)
                                      Text(
                                        m.content,
                                        style: TextStyle(
                                          color: isUser
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .onPrimary
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .onSurface,
                                          fontSize: DesignTokens.bodySize,
                                          height: 1.5,
                                        ),
                                      ),
                                    if (m.metadata != null &&
                                        m.metadata!['type'] ==
                                            'calendar_events')
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 8.0),
                                        child: CalendarEventsWidget(
                                          events: (m.metadata!['data'] as List)
                                              .cast<dynamic>(),
                                        ),
                                      ),
                                    if (m.metadata != null &&
                                        m.metadata!['type'] == 'task_breakdown')
                                      TaskBreakdownCard(
                                        steps: (m.metadata!['data'] as List)
                                            .cast<dynamic>(),
                                        estimatedTime:
                                            m.metadata!['estimated_time'],
                                        dopamineHack:
                                            m.metadata!['dopamine_hack'],
                                        initialCompletedSteps:
                                            (m.metadata!['completed_steps']
                                                    as List<dynamic>?)
                                                ?.map((e) => e as int)
                                                .toSet(),
                                        onStepsChanged: (newSet) {
                                          m.metadata!['completed_steps'] =
                                              newSet.toList();
                                        },
                                      ),
                                    if (m.metadata != null &&
                                        m.metadata!['type'] == 'dopamine_card')
                                      DopamineCard(
                                        content:
                                            m.metadata!['data'] as String? ??
                                                '',
                                      ),
                                    if (m.metadata != null &&
                                        m.metadata!['type'] ==
                                            'decision_helper')
                                      DecisionHelperCard(
                                        options: (m.metadata!['data'] as List)
                                            .cast<String>(),
                                        initialSelection:
                                            m.metadata!['selected_option']
                                                as String?,
                                        onSelectionChanged: (opt) {
                                          m.metadata!['selected_option'] = opt;
                                        },
                                        onOptionSelected: (opt) {
                                          m.metadata!['selected_option'] = opt;
                                          _handleSubmit(api,
                                              textOverride:
                                                  opt.startsWith('reduce')
                                                      ? opt
                                                      : 'I choose: $opt');
                                        },
                                        onReevaluate: () async {
                                          final options =
                                              (m.metadata!['data'] as List)
                                                  .cast<String>();
                                          if (options.isNotEmpty) {
                                            final optionsStr =
                                                options.join(', ');
                                            await _handleSubmit(
                                              api,
                                              textOverride:
                                                  'Re-evaluate these options: $optionsStr. Please provide a comprehensive analysis including:\n1. Contextual understanding.\n2. Pros and cons for each.\n3. A specific recommendation with rationale.\n4. Any relevant historical patterns.',
                                              forceOrchestrator: true,
                                            );
                                          } else {
                                            await _handleSubmit(
                                              api,
                                              textOverride:
                                                  'help me decide again',
                                              forceOrchestrator: true,
                                            );
                                          }
                                        },
                                      ),
                                    if (m.metadata != null &&
                                        m.metadata!['type'] ==
                                            'reevaluation_report')
                                      ReevaluationCard(
                                        data: m.metadata!['data']
                                            as Map<String, dynamic>,
                                        onAction: (actionType, value) {
                                          if (actionType == 'schedule') {
                                            _handleSubmit(api,
                                                textOverride:
                                                    'Schedule task: $value');
                                          } else if (actionType == 'note') {
                                            _handleSubmit(api,
                                                textOverride:
                                                    'Save note: $value');
                                          }
                                        },
                                      ),
                                    if (m.metadata != null &&
                                        m.metadata!['type'] ==
                                            'task_prioritization')
                                      TaskPrioritizationWidget(
                                        tasks: (m.metadata!['tasks'] as List)
                                            .map((t) =>
                                                PrioritizedTaskItem.fromJson(
                                                    t as Map<String, dynamic>))
                                            .toList(),
                                        reasoning: m.metadata!['reasoning']
                                                as String? ??
                                            '',
                                        originalTaskCount:
                                            m.metadata!['original_task_count']
                                                    as int? ??
                                                0,
                                        isCompleted: m.metadata!['is_completed']
                                                as bool? ??
                                            false,
                                        enableAutoSelect:
                                            false, // Disabled to prevent loops
                                        onCompleted: () {
                                          // Mark as completed in metadata to persist state
                                          m.metadata!['is_completed'] = true;
                                        },
                                        onTaskSelected: (task, method) async {
                                          // Mark as completed immediately
                                          m.metadata!['is_completed'] = true;
                                          try {
                                            // Only call API for non-adhoc tasks
                                            if (!task.id.startsWith('adhoc_')) {
                                              await api.selectTask(
                                                taskId: task.id,
                                                selectionMethod: method,
                                              );
                                            }
                                            // Update current task for body doubling
                                            _currentTask = task.title;

                                            // Show body doubling mode selection dialog
                                            await _showBodyDoubleModeDialog(
                                                task: task.title);

                                            _handleSubmit(api,
                                                textOverride:
                                                    'Starting focus session for: ${task.title}');
                                          } catch (e) {
                                            if (context.mounted) {
                                              NpSnackbar.show(context,
                                                  'Failed to select task: $e',
                                                  type: NpSnackType.warning);
                                            }
                                          }
                                        },
                                        onScheduleTask: () {
                                          final selectedTask =
                                              (m.metadata!['tasks'] as List)
                                                      .isNotEmpty
                                                  ? (m.metadata!['tasks']
                                                          as List)
                                                      .first['title']
                                                  : '';
                                          _handleSubmit(api,
                                              textOverride:
                                                  'Schedule task: $selectedTask');
                                        },
                                        onTakeNote: () {
                                          _handleSubmit(api,
                                              textOverride:
                                                  'capture: Task prioritization notes');
                                        },
                                        onRefresh: () async {
                                          _handleSubmit(api,
                                              textOverride:
                                                  'help me choose a task');
                                        },
                                        onAtomizeTask: (task) {
                                          _handleSubmit(api,
                                              textOverride:
                                                  'atomize: ${task.title}');
                                        },
                                      ),
                                    // Notion Page Created Widget
                                    if (m.metadata != null &&
                                        m.metadata!['type'] ==
                                            'notion_page_created')
                                      NotionPageWidget(
                                        pageData: m.metadata!['data']
                                            as Map<String, dynamic>,
                                        message: m.content,
                                      ),
                                    // Notion Search Results Widget
                                    if (m.metadata != null &&
                                        m.metadata!['type'] ==
                                            'notion_search_results')
                                      NotionSearchResultsWidget(
                                        pages: (m.metadata!['data'] as List)
                                            .cast<dynamic>(),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            if (isUser) ...[
                              const SizedBox(width: DesignTokens.spacingSm),
                              CircleAvatar(
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
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
                // Body Doubling Check-in Banner
                _buildCheckInBanner(),

                // Dynamic Widget in Chat Screen - Removed (moved to ListView)

                if (!_isTestEnv &&
                    !_focusMode &&
                    !_minimalMode &&
                    !_listening &&
                    !_voiceMode &&
                    !_voiceSessionActive) ...[
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
                          label: 'Prioritize Tasks',
                          semanticsLabel: 'Help me choose a task',
                          onTap: () => _setInput('Help me choose a task')),
                      NpChip(
                        label: 'More…',
                        semanticsLabel: 'Show advanced tools',
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
                if (_focusMode && !_listening)
                  Padding(
                    padding:
                        const EdgeInsets.only(bottom: DesignTokens.spacingXs),
                    child: Row(
                      children: [
                        const Icon(Icons.bolt_outlined, size: 16),
                        const SizedBox(width: DesignTokens.spacingXs),
                        Text(
                          'Energy $_energyLevel/10',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Theme.of(context).hintColor),
                        ),
                        const SizedBox(width: DesignTokens.spacingSm),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 4,
                              thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 8),
                              overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 14),
                              activeTrackColor:
                                  Theme.of(context).colorScheme.primary,
                              inactiveTrackColor: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.2),
                              thumbColor: Theme.of(context).colorScheme.primary,
                              overlayColor: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.08),
                            ),
                            child: Slider(
                              value: _energyLevel.toDouble(),
                              min: 1,
                              max: 10,
                              divisions: 9,
                              label: 'Energy $_energyLevel',
                              onChanged: (v) =>
                                  setState(() => _energyLevel = v.round()),
                              onChangeEnd: (v) async {
                                try {
                                  await api.logEnergy(v.round(),
                                      context: 'focus_mode');
                                  _showModeBannerNow('Energy logged');
                                } catch (_) {}
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
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
                        onTap: () async {
                          if (_listening) {
                            await _stopListeningManual();
                          } else {
                            setState(() {
                              _voiceMode = true;
                            });
                            if (!_voiceSessionActive) {
                              _toggleVoiceSession();
                            }
                          }
                        },
                        onLongPress: () {
                          if (!_listening) {
                            _showVoiceControls(context);
                          }
                        },
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: _voiceMode
                              ? const SizedBox.shrink()
                              : PulseIndicator(
                                  mode: _listening
                                      ? PulseMode.listening
                                      : (_speaking
                                          ? PulseMode.speaking
                                          : (_loading || _engaged.isNotEmpty
                                              ? PulseMode.processing
                                              : PulseMode.idle)),
                                  amplitude: _listening
                                      ? (_soundLevel > 1.0 ? 1.0 : _soundLevel)
                                      : (_speaking ? 0.4 : 0.0),
                                  size: 56,
                                ),
                        ),
                      ),
                      const SizedBox(width: DesignTokens.spacingSm),
                      Expanded(
                        child: NpTextField(
                            controller: _input,
                            focusNode: _inputFocusNode,
                            label: _listening
                                ? 'Listening... ($_partialText)'
                                : (_voiceMode
                                    ? l.voiceModeLabel
                                    : l.typeMessageLabel),
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) async {
                              if (!_voiceMode) {
                                await _handleSubmit(api);
                              }
                            }),
                      ),
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
                                if (!_voiceSessionActive) {
                                  _toggleVoiceSession();
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
                          onPressed: () async {
                            if (!_voiceMode) {
                              setState(() {
                                _voiceMode = true;
                              });
                              if (!_voiceSessionActive) {
                                _toggleVoiceSession();
                              }
                            } else {
                              setState(() {
                                _voiceMode = false;
                              });
                            }
                          },
                        ),
                      if (!_listening && _canResume)
                        IconButton(
                          icon: Icon(Icons.play_circle_outline,
                              color: Theme.of(context).colorScheme.secondary),
                          tooltip: 'Resume',
                          onPressed: () async {
                            await _handleSubmit(ref.read(apiClientProvider),
                                textOverride: 'Resume');
                          },
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

  Future<void> _stopListeningManual() async {
    if (!_listening) return;

    final settings = ref.read(userSettingsProvider);
    if (settings.sttProvider == 'cloud') {
      if (_voiceCompleter != null && !_voiceCompleter!.isCompleted) {
        // Prevent double-stop
        setState(() => _partialText = 'Processing...');
        final cloudStt = ref.read(cloudSttServiceProvider);
        try {
          final text = await cloudStt.stopAndTranscribe();
          if (_voiceCompleter != null && !_voiceCompleter!.isCompleted) {
            _voiceCompleter!.complete(text);
          }
        } catch (e) {
          debugPrint("Manual stop error: $e");
          if (_voiceCompleter != null && !_voiceCompleter!.isCompleted) {
            _voiceCompleter!.complete(null);
          }
        }
      }
    } else {
      await _speech.stop();
    }
  }

  Widget _buildVoiceDialoguePane(BuildContext context, double hp) {
    final l = AppLocalizations.of(context)!;
    final headerTitle = _voiceCardType == _VoiceCardType.captureThought
        ? 'BRAIN ASSISTANT'
        : (_voiceCardType == _VoiceCardType.dopamine
            ? 'DOPAMINE HACKS'
            : 'FOCUS COACH');
    final headerSubtitle = _voiceCardType == _VoiceCardType.captureThought
        ? 'Voice Mode'
        : (_voiceCardType == _VoiceCardType.dopamine
            ? 'Gamification'
            : 'Voice Dialogue');
    final listeningText = _listening
        ? (_partialText.isNotEmpty ? _partialText : l.voiceModeLabel)
        : '';

    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: hp, vertical: DesignTokens.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Column(
              children: [
                Text(
                  headerTitle,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: DesignTokens.spacingXs),
                Text(
                  headerSubtitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: DesignTokens.spacingXl),
          const SizedBox(height: DesignTokens.spacingLg),
          _buildPrimaryVoiceCard(context),
          const Spacer(),
          _buildVoiceListeningRegion(context, listeningText),
        ],
      ),
    );
  }

  Widget _buildPrimaryVoiceCard(BuildContext context) {
    Widget card;
    switch (_voiceCardType) {
      case _VoiceCardType.list:
        card = _buildListCard(context);
        break;
      case _VoiceCardType.captureThought:
        card = _buildCaptureThoughtCard(context);
        break;
      case _VoiceCardType.taskBreakdown:
        card = _buildTaskBreakdownCard(context);
        break;
      case _VoiceCardType.decisionHelper:
        card = _buildDecisionHelperCard(context);
        break;
      case _VoiceCardType.taskPrioritization:
        card = _buildTaskPrioritizationCard(context);
        break;
      case _VoiceCardType.quickCapture:
        card = _buildCaptureThoughtCard(context);
        break;
      case _VoiceCardType.dopamine:
        card = DopamineCard(
          content: _dopamineContent,
          onOptionSelected: (selectedOption) {
            _handleSubmit(ref.read(apiClientProvider),
                textOverride: "I choose: $selectedOption", timeoutSeconds: 60);
          },
          onClose: () => setState(() => _voiceCardType = _VoiceCardType.none),
        );
        break;
      case _VoiceCardType.timer:
        card = _buildTimerVoiceCard(context);
        break;
      case _VoiceCardType.notionPage:
        card = _buildNotionVoiceCard(context);
        break;
      case _VoiceCardType.none:
        if (_messages.isNotEmpty &&
            _messages.last.role == 'assistant' &&
            _messages.last.content.isNotEmpty) {
          card = Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: DesignTokens.spacingMd),
            child: SingleChildScrollView(
              child: Text(
                _messages.last.content,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          );
          break;
        }
        card = const SizedBox.shrink();
        break;
    }

    return _wrapVoiceCardWithHistory(context, card);
  }

  Widget _wrapVoiceCardWithHistory(BuildContext context, Widget card) {
    if (_voiceCardType == _VoiceCardType.none) return card;
    if (_voiceCardStack.length <= 1) return card;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        card,
        const SizedBox(height: DesignTokens.spacingSm),
        Center(
          child: TextButton(
            onPressed: () => _showVoiceCardHistory(context),
            child: const Text('More…'),
          ),
        ),
      ],
    );
  }

  String _voiceCardLabel(_VoiceCardType t) {
    switch (t) {
      case _VoiceCardType.timer:
        return 'Timers';
      case _VoiceCardType.list:
        return _calendarEvents.isNotEmpty ? 'Calendar' : 'List';
      case _VoiceCardType.taskBreakdown:
        return 'Task Breakdown';
      case _VoiceCardType.decisionHelper:
        return 'Decision Helper';
      case _VoiceCardType.taskPrioritization:
        return 'Task Prioritization';
      case _VoiceCardType.captureThought:
      case _VoiceCardType.quickCapture:
        return 'Capture Thought';
      case _VoiceCardType.dopamine:
        return 'Dopamine';
      case _VoiceCardType.notionPage:
        return 'Notion';
      case _VoiceCardType.none:
        return 'Chat';
    }
  }

  void _recordVoiceCard(_VoiceCardType t) {
    if (t == _VoiceCardType.none) return;
    _voiceCardStack.removeWhere((x) => x == t);
    _voiceCardStack.add(t);
    if (_voiceCardStack.length > _maxVoiceCardStackSize) {
      _voiceCardStack.removeRange(
          0, _voiceCardStack.length - _maxVoiceCardStackSize);
    }
  }

  void _showVoiceCardHistory(BuildContext context) {
    if (_voiceCardStack.length <= 1) return;
    final items = List<_VoiceCardType>.from(_voiceCardStack.reversed);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: items.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: Theme.of(ctx).dividerColor.withValues(alpha: 0.2),
            ),
            itemBuilder: (ctx, i) {
              final t = items[i];
              final isActive = t == _voiceCardType;
              return ListTile(
                title: Text(_voiceCardLabel(t)),
                trailing: isActive ? const Icon(Icons.check) : null,
                onTap: () {
                  Navigator.of(ctx).pop();
                  setState(() {
                    _voiceCardType = t;
                    _recordVoiceCard(t);
                  });
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTimerVoiceCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacingLg),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: cs.primary.withValues(alpha: 0.1),
                child: Icon(Icons.timer_outlined, color: cs.primary, size: 20),
              ),
              const SizedBox(width: DesignTokens.spacingSm),
              Text(
                'Active Timers',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () {
                  setState(() {
                    _voiceCardType = _VoiceCardType.none;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spacingMd),
          if (_timers.isEmpty)
            Text("No active timers",
                style: Theme.of(context).textTheme.bodyLarge)
          else
            Column(
              children: _timers.map((t) => _timerCard(context, t)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildNotionVoiceCard(BuildContext context) {
    if (_notionPageData == null) {
      return const SizedBox.shrink();
    }
    
    return NotionPageWidget(
      pageData: _notionPageData!,
    );
  }

  Widget _buildCaptureThoughtCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    ChatMessage? lastUser;
    for (var i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].role == 'user') {
        lastUser = _messages[i];
        break;
      }
    }
    final summary = lastUser?.content ?? '';
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacingLg),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: cs.primary.withValues(alpha: 0.1),
                child: Icon(Icons.psychology, color: cs.primary, size: 20),
              ),
              const SizedBox(width: DesignTokens.spacingSm),
              Text(
                'Capture Thought',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () {
                  setState(() {
                    _voiceCardType = _VoiceCardType.none;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spacingSm),
          Text(
            'Drafting • Summary',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: DesignTokens.spacingMd),
          if (summary.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(DesignTokens.spacingMd),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
              ),
              child: Text(
                summary,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          const SizedBox(height: DesignTokens.spacingLg),
          Row(
            children: [
              Expanded(
                child: NpButton(
                  label: 'Save to External Brain',
                  type: NpButtonType.primary,
                  onPressed: () async {
                    final api = ref.read(apiClientProvider);
                    final text = summary.isNotEmpty ? summary : _partialText;
                    if (text.isEmpty) return;
                    await _handleSubmit(api, textOverride: 'capture: $text');
                    setState(() {
                      _voiceCardType = _VoiceCardType.captureThought;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spacingSm),
          Row(
            children: [
              Expanded(
                child: NpButton(
                  label: 'Expand',
                  type: NpButtonType.secondary,
                  onPressed: () {
                    Navigator.of(context).pushNamed(Routes.external);
                  },
                ),
              ),
              const SizedBox(width: DesignTokens.spacingSm),
              Expanded(
                child: NpButton(
                  label: 'Discard',
                  type: NpButtonType.secondary,
                  onPressed: () {
                    _input.clear();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildListCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_calendarEvents.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(DesignTokens.spacingLg),
        constraints: const BoxConstraints(maxHeight: 400),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: cs.primary.withValues(alpha: 0.1),
                  child:
                      Icon(Icons.calendar_today, color: cs.primary, size: 20),
                ),
                const SizedBox(width: DesignTokens.spacingSm),
                Text(
                  'Calendar Events',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () {
                    setState(() {
                      _calendarEvents = [];
                      _voiceCardType = _VoiceCardType.none;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.spacingMd),
            Flexible(
              child: SingleChildScrollView(
                child: CalendarEventsWidget(events: _calendarEvents),
              ),
            ),
          ],
        ),
      );
    }

    // Generic List / Grocery List Fallback
    final title =
        _genericListTitle.isNotEmpty ? _genericListTitle : 'Grocery List';
    final items = _genericListItems.isNotEmpty
        ? _genericListItems
        : ['Get milk', 'Add milk']; // Fallback for demo if empty

    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacingLg),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: cs.primary.withValues(alpha: 0.1),
                child: Icon(Icons.shopping_cart_outlined,
                    color: cs.primary, size: 20),
              ),
              const SizedBox(width: DesignTokens.spacingSm),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              Text(
                'LIVE UPDATE',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: cs.onSurfaceVariant, letterSpacing: 1.2),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spacingMd),
          ...items.take(5).map((item) => Padding(
                padding: const EdgeInsets.only(bottom: DesignTokens.spacingSm),
                child: Row(
                  children: [
                    const Icon(Icons.radio_button_unchecked, size: 18),
                    const SizedBox(width: DesignTokens.spacingXs),
                    Expanded(
                      child: Text(
                        item,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: DesignTokens.spacingLg),
          Row(
            children: [
              Expanded(
                child: NpButton(
                  label: 'Add More',
                  type: NpButtonType.secondary,
                  onPressed: () {
                    setState(() {
                      _voiceCardType = _VoiceCardType.list;
                    });
                  },
                ),
              ),
              const SizedBox(width: DesignTokens.spacingSm),
              Expanded(
                child: NpButton(
                  label: 'Save & Close',
                  type: NpButtonType.primary,
                  onPressed: () async {
                    final api = ref.read(apiClientProvider);
                    ChatMessage? lastUser;
                    for (var i = _messages.length - 1; i >= 0; i--) {
                      if (_messages[i].role == 'user') {
                        lastUser = _messages[i];
                        break;
                      }
                    }
                    final base = lastUser?.content ?? '';
                    final text =
                        base.isNotEmpty ? '$title: $base' : title.toLowerCase();
                    await _handleSubmit(api, textOverride: text);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaskBreakdownCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacingLg),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: cs.primary.withValues(alpha: 0.1),
                child: Icon(Icons.view_timeline, color: cs.primary, size: 20),
              ),
              const SizedBox(width: DesignTokens.spacingSm),
              Text(
                'Task Breakdown',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () {
                  setState(() {
                    _voiceCardType = _VoiceCardType.none;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spacingSm),
          Text(
            'Drafting steps',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: DesignTokens.spacingMd),
          Column(
            children: _taskBreakdownSteps.isNotEmpty
                ? _taskBreakdownSteps
                    .asMap()
                    .entries
                    .map((e) => Padding(
                          padding: const EdgeInsets.only(
                              bottom: DesignTokens.spacingSm),
                          child: TaskItem(
                            title: e.value.toString(),
                            isDone: false,
                            isActive: e.key == 0,
                            tag: e.key == 0 ? "NEXT STEP" : null,
                            onTap: () {},
                          ),
                        ))
                    .toList()
                : [
                    TaskItem(
                      title: 'Draft email subject',
                      isDone: false,
                      isActive: true,
                      tag: "NEXT STEP",
                      onTap: () {},
                    ),
                    const SizedBox(height: DesignTokens.spacingSm),
                    TaskItem(
                      title: 'Write introduction',
                      isDone: false,
                      onTap: () {},
                    ),
                    const SizedBox(height: DesignTokens.spacingSm),
                    TaskItem(
                      title: 'Find reference data',
                      isDone: false,
                      onTap: () {},
                    ),
                  ],
          ),
          const SizedBox(height: DesignTokens.spacingLg),
          Row(
            children: [
              Expanded(
                child: NpButton(
                  label: 'Add Another',
                  type: NpButtonType.secondary,
                  onPressed: () {
                    setState(() {
                      _voiceCardType = _VoiceCardType.taskBreakdown;
                    });
                  },
                ),
              ),
              const SizedBox(width: DesignTokens.spacingSm),
              Expanded(
                child: NpButton(
                  label: 'Confirm Selection',
                  type: NpButtonType.primary,
                  onPressed: () async {
                    final api = ref.read(apiClientProvider);
                    ChatMessage? lastUser;
                    for (var i = _messages.length - 1; i >= 0; i--) {
                      if (_messages[i].role == 'user') {
                        lastUser = _messages[i];
                        break;
                      }
                    }
                    final base = lastUser?.content ?? '';
                    final text = base.isNotEmpty
                        ? 'atomize: $base'
                        : 'atomize this task';
                    await _handleSubmit(api, textOverride: text);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDecisionHelperCard(BuildContext context) {
    return DecisionHelperCard(
      options: _decisionOptions,
      onSelectionChanged: (opt) {
        // Voice mode selection logic if needed
      },
      onOptionSelected: (opt) {
        _handleSubmit(ref.read(apiClientProvider),
            textOverride: 'I choose: $opt');
      },
      onReevaluate: () async {
        final api = ref.read(apiClientProvider);
        if (_decisionOptions.isNotEmpty) {
          final optionsStr = _decisionOptions.join(', ');
          await _handleSubmit(
            api,
            textOverride:
                'Re-evaluate these options: $optionsStr. Please provide a comprehensive analysis including:\n1. Contextual understanding.\n2. Pros and cons for each.\n3. A specific recommendation with rationale.\n4. Any relevant historical patterns.',
            forceOrchestrator: true,
          );
        } else {
          await _handleSubmit(
            api,
            textOverride: 'show all options',
            forceOrchestrator: true,
          );
        }
      },
    );
  }

  Widget _buildTaskPrioritizationCard(BuildContext context) {
    final api = ref.read(apiClientProvider);
    return TaskPrioritizationWidget(
      tasks: _prioritizedTasks,
      reasoning: _prioritizationReasoning,
      originalTaskCount: _originalTaskCount,
      enableAutoSelect: false, // Disabled to prevent loops
      onTaskSelected: (task, method) async {
        try {
          // Only call API for non-adhoc tasks
          if (!task.id.startsWith('adhoc_')) {
            await api.selectTask(
              taskId: task.id,
              selectionMethod: method,
            );
          }
          // Update current task for body doubling
          _currentTask = task.title;

          // Show body doubling mode selection dialog
          await _showBodyDoubleModeDialog(task: task.title);

          _handleSubmit(api,
              textOverride: 'Starting focus session for: ${task.title}');
          setState(() => _voiceCardType = _VoiceCardType.none);
        } catch (e) {
          if (context.mounted) {
            NpSnackbar.show(context, 'Failed to select task: $e',
                type: NpSnackType.warning);
          }
        }
      },
      onScheduleTask: () {
        final selectedTask =
            _prioritizedTasks.isNotEmpty ? _prioritizedTasks.first.title : '';
        _handleSubmit(api, textOverride: 'Schedule task: $selectedTask');
      },
      onTakeNote: () {
        _handleSubmit(api, textOverride: 'capture: Task prioritization notes');
      },
      onRefresh: () async {
        _handleSubmit(api, textOverride: 'help me choose a task');
      },
      onAtomizeTask: (task) {
        _handleSubmit(api, textOverride: 'atomize: ${task.title}');
      },
    );
  }

  Widget _buildVoiceListeningRegion(
      BuildContext context, String listeningText) {
    final cs = Theme.of(context).colorScheme;
    final status = _listening
        ? 'LISTENING...'
        : (_loading || _speaking ? 'PROCESSING...' : '');
    return Column(
      children: [
        if (listeningText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: DesignTokens.spacingSm),
            child: Text(
              '"$listeningText"',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        if (status.isNotEmpty)
          Text(
            status,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        const SizedBox(height: DesignTokens.spacingSm),
        PulseIndicator(
          mode: _listening
              ? PulseMode.listening
              : (_speaking
                  ? PulseMode.speaking
                  : (_loading || _engaged.isNotEmpty
                      ? PulseMode.processing
                      : PulseMode.idle)),
          amplitude: _listening
              ? (_soundLevel > 1.0 ? 1.0 : _soundLevel)
              : (_speaking ? 0.4 : 0.0),
          size: 72,
        ),
      ],
    );
  }

  Future<void> _startVoiceSessionLoop() async {
    final api = ref.read(apiClientProvider);
    final settings = ref.read(userSettingsProvider);

    // Initial state setup
    if (mounted) {
      setState(() {
        if (!_engaged.contains('SpeechRecognition')) {
          _engaged.add('SpeechRecognition');
        }
        _listening = true;
        _partialText =
            settings.sttProvider == 'cloud' ? 'Listening (Cloud)...' : '';
      });
    }

    // Continuous loop for voice session
    while (_voiceSessionActive && mounted) {
      // 1. Handle Mute State
      if (_micMuted) {
        if (_listening) {
          setState(() {
            _listening = false;
            _soundLevel = 0.0;
          });
        }
        await Future.delayed(const Duration(milliseconds: 500));
        continue;
      }

      // 2. Ensure Listening State is Active
      if (!_listening) {
        setState(() => _listening = true);
      }

      final useCloud = settings.sttProvider == 'cloud';
      String? finalText;

      // 3. Perform Speech Recognition (Cloud or Local)
      if (useCloud) {
        final cloudStt = ref.read(cloudSttServiceProvider);
        try {
          await cloudStt.startRecording();
          _voiceCompleter = Completer<String?>();

          _ampTimer?.cancel();
          int silenceMs = 0;
          final startTime = DateTime.now();

          setState(() {
            _partialText = "Listening...";
          });

          _ampTimer =
              Timer.periodic(const Duration(milliseconds: 100), (timer) async {
            if (!mounted ||
                !_listening ||
                (_voiceCompleter?.isCompleted ?? true)) {
              timer.cancel();
              return;
            }
            final amp = await cloudStt.getAmplitude();
            double level = (amp + 60) / 60;
            if (level < 0) level = 0;
            if (level > 1) level = 1;
            setState(() => _soundLevel = level);

            // Silence Detection for Cloud STT
            // If sound level is low for > 2.5s, we assume user is done.
            if (level < 0.05) {
              silenceMs += 100;
            } else {
              silenceMs = 0;
            }

            // Stop if silent for 2.5s (after initial 1s buffer)
            if (silenceMs > 2500 &&
                DateTime.now().difference(startTime).inSeconds > 1) {
              debugPrint("Cloud STT: Silence detected, stopping...");
              timer.cancel();
              _cloudSttTimeoutTimer?.cancel();
              try {
                final text = await cloudStt.stopAndTranscribe();
                if (_voiceCompleter != null && !_voiceCompleter!.isCompleted) {
                  _voiceCompleter!.complete(text);
                }
              } catch (e) {
                if (_voiceCompleter != null && !_voiceCompleter!.isCompleted) {
                  _voiceCompleter!.complete(null);
                }
              }
            }
          });

          // 20s timeout safeguard (reduced from 30s to avoid backend limits)
          _cloudSttTimeoutTimer?.cancel();
          _cloudSttTimeoutTimer = Timer(const Duration(seconds: 20), () async {
            if (_voiceCompleter != null && !_voiceCompleter!.isCompleted) {
              debugPrint("Cloud STT: Auto-stopping after 20s timeout");
              try {
                final text = await cloudStt.stopAndTranscribe();
                if (_voiceCompleter != null && !_voiceCompleter!.isCompleted) {
                  _voiceCompleter!.complete(text);
                }
              } catch (e) {
                if (_voiceCompleter != null && !_voiceCompleter!.isCompleted) {
                  _voiceCompleter!.complete(null);
                }
              }
            }
          });

          finalText = await _voiceCompleter!.future;
          _ampTimer?.cancel();
          _cloudSttTimeoutTimer?.cancel();
        } catch (e) {
          _ampTimer?.cancel();
          _cloudSttTimeoutTimer?.cancel();
          if (mounted) {
            if (e.toString().toLowerCase().contains('permission')) {
              setState(() {
                _voiceSessionActive = false;
                _listening = false;
              });
              NpSnackbar.show(
                  context, 'Microphone permission required. Please enable.',
                  type: NpSnackType.destructive);
            } else {
              NpSnackbar.show(context, 'Cloud STT Error: $e',
                  type: NpSnackType.destructive);
            }
          }
          finalText = null;
        }
      } else {
        // Local STT
        if (_speech.supported) {
          _partialSub?.cancel();
          _partialSub = _speech.partialUpdates.listen((s) {
            final nowMs = DateTime.now().millisecondsSinceEpoch;
            final speaking = _speaking;
            final likelyEcho = _isLikelyEcho(s, _currentTtsText);

            if (speaking && likelyEcho) return;

            // Barge-in Logic
            final inputLen = s.trim().length;
            final sinceTtsMs = _ttsStartAt == null
                ? 999999
                : nowMs - _ttsStartAt!.millisecondsSinceEpoch;
            final novelty = _novelWordCount(s, _currentTtsText);
            const ampThresh = kIsWeb ? 0.5 : 0.35;
            final ampOk = _soundLevel >= ampThresh;
            final canBarge = speaking &&
                !likelyEcho &&
                sinceTtsMs >= _minBargeDelayMs &&
                novelty >= 1 &&
                inputLen >= 3 &&
                ampOk &&
                (nowMs - _lastBargeInMs > 1200);

            if (canBarge) {
              _lastBargeInMs = nowMs;
              _tts.stop();
              setState(() {
                _speaking = false;
                _currentTtsText = '';
                _ttsStartAt = null;
              });
              final cleaned = _stripEchoWords(s, _currentTtsText);
              if (cleaned.trim().isNotEmpty) {
                _bargeCandidate = cleaned;
              }
              _speech.stop(); // Stop recognition to process barge-in
            }

            // Update Partial Text
            if (!speaking) {
              if (_currentTtsText.isEmpty) {
                if (s.isNotEmpty) setState(() => _partialText = s);
              } else {
                final cleaned = _stripEchoWords(s, _currentTtsText);
                if (cleaned.trim().isNotEmpty) {
                  setState(() => _partialText = cleaned);
                }
              }
            } else if (canBarge) {
              final cleaned = _stripEchoWords(s, _currentTtsText);
              if (cleaned.trim().isNotEmpty) {
                setState(() => _partialText = cleaned);
              }
            }
          });

          _levelSub?.cancel();
          _levelSub = _speech.levelUpdates.listen((v) {
            setState(() => _soundLevel = v);
            if (v > _sessionMaxAmp) _sessionMaxAmp = v;
          });

          _sessionMaxAmp = 0.0;
          try {
            finalText = await _speech.startOnce();
          } catch (e) {
            debugPrint("Speech startOnce error: $e");
          }

          _partialSub?.cancel();
          _levelSub?.cancel();
        } else {
          // Not supported
          if (mounted) {
            NpSnackbar.show(context, 'Speech recognition not supported',
                type: NpSnackType.warning);
          }
          break;
        }
      }

      // 4. Process Final Text
      // Handle barge-in candidate if final text is empty
      if ((finalText == null || finalText.isEmpty) &&
          _bargeCandidate != null &&
          _bargeCandidate!.trim().isNotEmpty) {
        finalText = _bargeCandidate;
        _bargeCandidate = null;
      }

      if (finalText != null && finalText.isNotEmpty) {
        // Use echo cancellation service for software-based filtering
        if (_echoCancellation.isLikelyEcho(finalText)) {
          debugPrint('[VoiceSession] Echo detected by service, ignoring: "$finalText"');
          finalText = '';
        } else {
          // Additional legacy echo cancellation for final text
          // Use longer threshold (10s) to account for TTS playback + silence detection
          final sinceTtsEnd = _lastTtsEndAt == null
              ? 999999
              : DateTime.now().difference(_lastTtsEndAt!).inMilliseconds;

          // Increased threshold to 10s to prevent self-listening loops
          // Also check if we're still speaking or just finished
          if (_speaking || sinceTtsEnd < 10000) {
            if (_isLikelyEcho(finalText, _currentTtsText)) {
              debugPrint('[VoiceSession] Echo detected by legacy check, ignoring: "$finalText"');
              finalText = '';
            } else {
              // Try filtering with echo cancellation service
              final filtered = _echoCancellation.filterEchoWords(finalText);
              if (filtered.trim().isNotEmpty) {
                finalText = filtered;
              } else {
                final cleaned = _stripEchoWords(finalText, _currentTtsText);
                if (cleaned.trim().isEmpty) {
                  debugPrint('[VoiceSession] Cleaned text is empty, ignoring');
                  finalText = '';
                } else {
                  finalText = cleaned;
                }
              }
            }
          }
        }
      }

      if (finalText != null && finalText.isNotEmpty) {
        final formatted = _formatTranscript(finalText);
        if (formatted.isNotEmpty) {
          _input.text = formatted;
          _consecutiveSilence = 0;

          // Fire-and-forget submission to maintain listening loop
          _handleSubmit(api, isVoice: true);
        }
      } else {
        // Silence detected
        _consecutiveSilence++;
        if (_consecutiveSilence >= 3) {
          // Legacy inactivity handling retained but now only marks silence;
          // voice session timeout is controlled by _onVoiceSessionTick.
          _consecutiveSilence = 0;
        }
      }

      // Short delay before next iteration to prevent tight loops
      // Add extra delay after TTS to prevent self-listening
      if (_voiceSessionActive) {
        final sinceTtsEnd = _lastTtsEndAt == null
            ? 999999
            : DateTime.now().difference(_lastTtsEndAt!).inMilliseconds;
        
        // If TTS just ended, wait longer before listening again
        if (sinceTtsEnd < 2000) {
          final waitMs = 2000 - sinceTtsEnd;
          debugPrint('[VoiceSession] Waiting ${waitMs}ms after TTS before listening');
          await Future.delayed(Duration(milliseconds: waitMs.toInt()));
        } else {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
    }

    // Cleanup when session ends
    if (mounted) {
      setState(() {
        _engaged.remove('SpeechRecognition');
        _listening = false;
        _partialText = '';
        _soundLevel = 0.0;
      });
    }
  }

  void _setInput(String s) {
    _input.text = s;
    _resetInactivityTimer();
    setState(() => _showInactivityPrompt = false);
  }

  bool _isLikelyEcho(String input, String tts) {
    final rawInput = input.trim().toLowerCase();
    final rawTts = tts.toLowerCase();
    if (rawInput.isEmpty || rawTts.isEmpty) return false;

    // Direct containment - if input is part of TTS output
    if (rawTts.contains(rawInput)) return true;
    
    // Reverse containment - if TTS is part of input (partial echo)
    if (rawInput.contains(rawTts) && rawTts.length > 10) return true;

    // Normalized containment (remove punctuation)
    final inputNorm = rawInput.replaceAll(RegExp(r'[^\w\s]'), '').trim();
    final ttsNorm = rawTts.replaceAll(RegExp(r'[^\w\s]'), '').trim();
    if (ttsNorm.contains(inputNorm) && inputNorm.isNotEmpty) return true;
    if (inputNorm.contains(ttsNorm) && ttsNorm.length > 10) return true;

    // Phrase-level echo detection (e.g. "1-minute" vs "1 minute")
    final cleanInput = rawInput.replaceAll('-', ' ').replaceAll('_', ' ');
    final cleanTts = rawTts.replaceAll('-', ' ').replaceAll('_', ' ');

    // Specific common phrases that indicate echo
    final echoPatterns = [
      'timer set', 'time is up', 'focus session', 'starting focus',
      'body double', 'check in', 'checking in', 'how are you',
      'still working', 'great job', 'keep going', 'you got this',
      'listening', 'here with you', 'im here', "i'm here",
    ];
    
    for (final pattern in echoPatterns) {
      if (cleanTts.contains(pattern) && cleanInput.contains(pattern)) {
        return true;
      }
    }

    // Word overlap ratio - if 50% or more words match, likely echo
    final wordsIn =
        cleanInput.split(RegExp(r'\s+')).where((w) => w.length >= 3).toSet();
    final wordsTts =
        cleanTts.split(RegExp(r'\s+')).where((w) => w.length >= 3).toSet();
    if (wordsIn.isEmpty || wordsTts.isEmpty) return false;
    final inter = wordsIn.intersection(wordsTts).length;
    final ratio = inter / wordsIn.length;
    
    // Lower threshold to 0.5 for more aggressive echo detection
    return ratio >= 0.5;
  }

  int _novelWordCount(String input, String tts) {
    final wordsIn = input
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 3)
        .toSet();
    final wordsTts = tts
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 3)
        .toSet();
    if (wordsIn.isEmpty) return 0;
    return wordsIn.difference(wordsTts).length;
  }

  String _stripEchoWords(String input, String tts) {
    final wordsIn = input
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 2)
        .toList();
    final wordsTts = tts
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 2)
        .toSet();
    if (wordsIn.isEmpty) return '';
    final novel = wordsIn.where((w) => !wordsTts.contains(w)).toList();
    return novel.join(' ');
  }

  /// Formats the voice transcript with basic punctuation.
  ///
  /// Adds a question mark if the sentence starts with a question word.
  /// Capitalizes the first letter and adds a period if no other punctuation is present.
  /// Also handles basic mid-sentence punctuation.
  String _formatTranscript(String s) {
    var t = s.trim();
    if (t.isEmpty) return '';

    // Capitalize first letter
    t = t.substring(0, 1).toUpperCase() + t.substring(1);

    // Check if it ends with punctuation, if not, infer it
    if (!RegExp(r'[.!?]$').hasMatch(t)) {
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
      t = '$t${isQuestion ? '?' : '.'}';
    }

    return t;
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
        _updateVoiceCardForTool(t);
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
    if (s.contains('atomize') || s.contains('atomise')) {
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
    if (s.contains('prioritize') ||
        s.contains('prioritise') ||
        s.contains('choose a task') ||
        s.contains('pick a task') ||
        s.contains('what should i do') ||
        s.contains('too many tasks') ||
        s.contains('help me choose')) {
      return Intent.taskPrioritization;
    }
    return Intent.unknown;
  }

  void _updateVoiceCardForIntent(Intent intent) {
    // Allow card updates in both voice and text modes
    switch (intent) {
      case Intent.atomize:
        setState(() {
          _voiceCardType = _VoiceCardType.taskBreakdown;
          _recordVoiceCard(_VoiceCardType.taskBreakdown);
        });
        break;
      case Intent.reduce:
        setState(() {
          _voiceCardType = _VoiceCardType.decisionHelper;
          _recordVoiceCard(_VoiceCardType.decisionHelper);
        });
        break;
      case Intent.externalCapture:
        setState(() {
          _voiceCardType = _VoiceCardType.captureThought;
          _recordVoiceCard(_VoiceCardType.captureThought);
        });
        break;
      case Intent.schedule:
        setState(() {
          _voiceCardType = _VoiceCardType.list;
          _recordVoiceCard(_VoiceCardType.list);
        });
        break;
      case Intent.taskPrioritization:
        setState(() {
          _voiceCardType = _VoiceCardType.taskPrioritization;
          _recordVoiceCard(_VoiceCardType.taskPrioritization);
        });
        break;
      default:
        break;
    }
  }

  void _updateVoiceCardForTool(dynamic tool) {
    // Allow card updates in both voice and text modes
    if (tool is! Map) return;
    final uiMode = tool['ui_mode'] as String?;
    if (uiMode == null) return;
    debugPrint('Updating voice card for tool: $uiMode');
    switch (uiMode) {
      case 'dopamine_card':
        setState(() {
          _voiceCardType = _VoiceCardType.dopamine;
          _recordVoiceCard(_VoiceCardType.dopamine);
          if (tool['reframe'] is String) {
            _dopamineContent = tool['reframe'];
          }
          debugPrint(
              'Set voice card to dopamine. Content length: ${_dopamineContent.length}');
        });
        break;
      case 'resume_chip':
        setState(() {
          _voiceCardType = _VoiceCardType.captureThought;
          _recordVoiceCard(_VoiceCardType.captureThought);
        });
        break;
      case 'body_double':
        setState(() {
          _voiceCardType = _VoiceCardType.captureThought;
          _recordVoiceCard(_VoiceCardType.captureThought);
        });
        break;
      case 'jit_rescue':
        setState(() {
          _voiceCardType = _VoiceCardType.taskBreakdown;
          _recordVoiceCard(_VoiceCardType.taskBreakdown);
        });
        break;
      case 'calendar_events':
        final events = tool['args']?['events'];
        if (events is List) {
          setState(() {
            _calendarEvents = events;
            _voiceCardType = _VoiceCardType.list;
            _recordVoiceCard(_VoiceCardType.list);
          });
        }
        break;
      case 'paralysis_breaker':
        final opts = tool['result']?['options'];
        if (opts is List) {
          setState(() {
            _decisionOptions = opts.map((e) => e.toString()).toList();
            _voiceCardType = _VoiceCardType.decisionHelper;
            _recordVoiceCard(_VoiceCardType.decisionHelper);
          });
        }
        break;
      case 'task_prioritization':
        final tasks = tool['tasks'] as List<dynamic>? ?? [];
        final reasoning = tool['reasoning'] as String? ?? '';
        final originalCount = tool['original_task_count'] as int? ?? 0;
        setState(() {
          _prioritizedTasks = tasks
              .map((t) =>
                  PrioritizedTaskItem.fromJson(t as Map<String, dynamic>))
              .toList();
          _prioritizationReasoning = reasoning;
          _originalTaskCount = originalCount;
          _voiceCardType = _VoiceCardType.taskPrioritization;
          _recordVoiceCard(_VoiceCardType.taskPrioritization);
        });
        break;
      default:
        break;
    }
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
    if (!_bodyDoubleActive || !_proactiveStarted) return;
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
    if (!_bodyDoubleActive || !_proactiveStarted) return;
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
  void _startCountdown(String timerId, String targetIso,
      {int? durationSeconds, int? generationId, String? label}) {
    DateTime target;
    int total;
    if (durationSeconds != null && durationSeconds > 0) {
      target = DateTime.now().add(Duration(seconds: durationSeconds));
      total = durationSeconds;
    } else {
      target = DateTime.parse(targetIso);
      final now = DateTime.now();
      final diff = target.difference(now);
      if (diff.isNegative) return;
      total = (diff.inMilliseconds / 1000).ceil();
    }
    final item = _TimerItem(
      id: timerId,
      target: target,
      totalSeconds: total,
      remainingSeconds: total,
      label: label,
    );
    if (_isTestEnv) {
      item.testStartMs = _testNowMs;
    }
    setState(() {
      _timers.add(item);
      _activeTimerId = timerId;
      _showTimersSection = true;
      _voiceCardType = _VoiceCardType.timer;
      _recordVoiceCard(_VoiceCardType.timer);
    });

    _appendAssistant('Timer set for ${_formatHMS(total)}.',
        generationId: generationId);

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

    if (_timerTicker != null && !_timerTicker!.isActive) {
      _timerTicker = null;
    }
    _timerTicker ??= Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        _timerTicker = null;
        return;
      }

      try {
        if (_timers.isEmpty) {
          _timerTicker?.cancel();
          _timerTicker = null;
          return;
        }

        setState(() {
          final settings = ref.read(userSettingsProvider);
          final canSpeak =
              settings.timeBlindnessEnabled && _voiceOutput && _tts.supported;

          if (_isTestEnv) {
            _testNowMs += 100;
          }
          final removeIds = <String>[];
          for (final t in _timers) {
            if (!t.paused && !t.completed) {
              if (_isTestEnv) {
                final start = t.testStartMs ?? _testNowMs;
                t.testStartMs ??= start;
                final elapsedMs = _testNowMs - start;
                final elapsedSec = (elapsedMs / 1000).floor();
                t.remainingSeconds = t.totalSeconds - elapsedSec;
              } else {
                final now = _now();
                final rem = t.target.difference(now).inMilliseconds / 1000;
                t.remainingSeconds = rem.ceil();
              }

              if (t.remainingSeconds < 0) t.remainingSeconds = 0;
              if (t.remainingSeconds > t.totalSeconds) {
                t.remainingSeconds = t.totalSeconds;
              }

              // Audio Cues Logic
              if (canSpeak && !_speaking && t.totalSeconds > 10) {
                final progress =
                    (t.remainingSeconds / t.totalSeconds).clamp(0.0, 1.0);
                int newState = 0;
                if (progress <= _timerSeventyFiveElapsedThreshold) {
                  newState = 2;
                } else if (progress <= _timerHalfProgressThreshold) {
                  newState = 1;
                }

                if (newState > t.lastProgressState) {
                  if (newState == 1) {
                    _tts.speak("Halfway point.");
                  } else if (newState == 2) {
                    _tts.speak("75% complete.");
                  }
                  t.lastProgressState = newState;
                }
              }

              if (canSpeak && !_speaking && t.totalSeconds > 10) {
                final rem = t.remainingSeconds;
                if (rem > 0 && rem <= _timerCountdownCalloutsSeconds.first) {
                  if (_timerCountdownCalloutsSeconds.contains(rem) &&
                      rem != t.lastCountdownMark) {
                    t.lastCountdownMark = rem;
                    _tts.speak(rem == 1
                        ? '1 second remaining.'
                        : '$rem seconds remaining.');
                  }
                }
              }

              if (t.remainingSeconds <= 0) {
                t.completed = true;
                t.completedAt = DateTime.now();
                t.remainingSeconds = 0;
                if (_isTestEnv) {
                  t.testCompletedAtMs = _testNowMs;
                  t.remainingSeconds = 0;
                }
                final labelText = t.label != null ? ' for "${t.label}"' : '';
                _appendAssistant(
                    'Timer$labelText completed: ${_formatExactDuration(t.totalSeconds)}.');

                // Alert Logic
                if (canSpeak && !_speaking) {
                  _tts.speak(
                      "Time is up${labelText.isNotEmpty ? labelText : ''}.");
                }
                if (mounted) {
                  NpSnackbar.show(context, 'Timer$labelText finished!',
                      type: NpSnackType.success);
                }
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
          _timers.removeWhere((x) {
            if (!x.completed) return false;
            if (_isTestEnv) {
              final doneAt = x.testCompletedAtMs;
              return doneAt != null && (_testNowMs - doneAt) > 5000;
            }
            final doneAt = x.completedAt;
            return doneAt != null &&
                DateTime.now().difference(doneAt).inMilliseconds > 5000;
          });
        });
      } catch (e, stack) {
        debugPrint('Error in timer ticker: $e\n$stack');
      }
    });
  }

  void _logSystem(String event, Map<String, dynamic> data) {
    final timestamp = DateTime.now().toIso8601String();
    debugPrint('[$timestamp] SYSTEM_LOG: $event - $data');
  }

  Future<void> _createTimer(String text, int currentGen) async {
    _engage('Time Agent');
    try {
      final api = ref.read(apiClientProvider);
      final queries = _extractTimerQueries(text);
      bool created = false;

      if (queries.isEmpty) {
        final r = await api.createCountdown(text);
        final target = r['target'] as String?;
        final id = r['timer_id'] as String?;
        final dur = r['duration_seconds'] as int?;
        if (target == null || id == null) {
          throw 'Timer creation failed.';
        }
        _startCountdown(id, target,
            durationSeconds: dur, generationId: currentGen, label: text);
        created = true;
      } else {
        for (final q in queries) {
          final r = await api.createCountdown(q);
          final target = r['target'] as String?;
          final id = r['timer_id'] as String?;
          final dur = r['duration_seconds'] as int?;
          if (target == null || id == null) {
            throw 'Timer creation failed.';
          }
          _startCountdown(id, target,
              durationSeconds: dur, generationId: currentGen, label: q);
          created = true;
        }
      }

      if (created) {
        _lastTimerCreatedAt = DateTime.now();
        _logSystem('TimerActivated', {
          'command': text,
        });
      }
      _disengage('Time Agent');
    } catch (e) {
      _disengage('Time Agent');
      _appendAssistant(
          'Please specify a valid duration in seconds, minutes, or hours.',
          generationId: currentGen);
      _logSystem('TimerCreationError', {'error': e.toString()});
    }
  }

  /// Handles Notion-related commands
  Future<void> _handleNotionCommand(String text, int currentGen) async {
    final lower = text.toLowerCase();
    
    try {
      final notionNotifier = ref.read(notionProvider.notifier);
      
      if (lower.startsWith('/notion create') || lower.contains('create notion page')) {
        // Extract content after the command
        final content = text.replaceAll(RegExp(r'^/notion\s+create\s*', caseSensitive: false), '')
                           .replaceAll(RegExp(r'create\s+notion\s+page\s*', caseSensitive: false), '');
        
        if (content.isEmpty) {
          _appendAssistant('Please specify content for the Notion page. Example: "/notion create Daily Reflection"', 
                          generationId: currentGen);
          return;
        }
        
        await notionNotifier.createQuickNote(content);
        _appendAssistant('✅ Created Notion page: "$content"', generationId: currentGen);
        
      } else if (lower.startsWith('/notion template') || lower.contains('notion template')) {
        // Show available templates
        _appendAssistant(
          '📋 Available Notion Templates:\n'
          '• Daily Reflection\n'
          '• Hyperfocus Session\n'
          '• Context Snapshot\n'
          '• Energy Tracking\n'
          '• Weekly Review\n'
          '• Goal Setting\n'
          '• Decision Log\n'
          '• Resource Library\n'
          '• Mood Tracker\n'
          '• Medication Log\n'
          '• Appointment Notes\n'
          '• Achievement Log\n'
          '• Strategy Notes\n'
          '• Sensory Environment\n'
          '• Transition Ritual\n\n'
          'Use: "/notion template [name]" to create from template',
          generationId: currentGen
        );
        
      } else if (lower.contains('save to notion') || lower.contains('export to notion')) {
        // Save current conversation or last message to Notion
        if (_messages.isNotEmpty) {
          final lastMessage = _messages.last;
          await notionNotifier.createQuickNote('Chat Export: ${lastMessage.content}');
          _appendAssistant('💾 Saved to Notion successfully!', generationId: currentGen);
        } else {
          _appendAssistant('No content to save to Notion.', generationId: currentGen);
        }
        
      } else if (lower.startsWith('/notion sync')) {
        // Trigger sync
        await notionNotifier.syncWithFirestore();
        _appendAssistant('🔄 Notion sync completed!', generationId: currentGen);
        
      } else {
        // General Notion help
        _appendAssistant(
          '🚀 Notion Integration Commands:\n\n'
          '📝 **Create Content:**\n'
          '• "/notion create [content]" - Create a quick note\n'
          '• "save to notion" - Save current message\n'
          '• "export to notion" - Export conversation\n\n'
          '📋 **Templates:**\n'
          '• "/notion template" - List all templates\n'
          '• "/notion template [name]" - Create from template\n\n'
          '🔄 **Sync:**\n'
          '• "/notion sync" - Sync with Firestore\n\n'
          '⚙️ **Settings:**\n'
          '• Go to Settings > Notion Integration to connect your account',
          generationId: currentGen
        );
      }
      
    } catch (e) {
      _appendAssistant('❌ Notion command failed: $e\n\nMake sure you\'ve connected your Notion account in Settings.', 
                      generationId: currentGen);
    }
  }

  /// Handles message submission.
  ///
  /// Processes the input text, sends it to the backend (or orchestrator), and handles the response.
  /// Supports both text and voice input.
  Future<void> _handleSubmit(ApiClient api,
      {bool isVoice = false,
      String? textOverride,
      int timeoutSeconds = 45,
      bool forceOrchestrator = false}) async {
    if (_isSubmitting && !isVoice) return; // Prevent duplicate active requests

    var text = textOverride ?? _input.text.trim();
    if (text.isEmpty) return;

    // Reset inactivity timer on user interaction
    _resetInactivityTimer();
    setState(() => _showInactivityPrompt = false);

    final int currentGen = ++_responseGeneration;

    setState(() {
      _isSubmitting = true;
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

    final lower = text.toLowerCase();

    // Check for energy command
    final energyMatch = RegExp(r'^energy[:\s]+\s*(\d+)$', caseSensitive: false)
        .firstMatch(text);
    if (energyMatch != null) {
      final levelStr = energyMatch.group(1);
      if (levelStr != null) {
        final level = int.tryParse(levelStr);
        if (level != null && level >= 1 && level <= 10) {
          await ref.read(energyStoreProvider).logEnergy(level);
          _appendAssistant('Energy level $level logged.',
              generationId: currentGen);
        } else {
          _appendAssistant('Please specify an energy level between 1 and 10.',
              generationId: currentGen);
        }
      }
      if (mounted) {
        setState(() => _loading = false);
        _input.clear();
      }
      _isSubmitting = false;
      return;
    }

    try {
      if (!forceOrchestrator) {
        final tc = _parseTimerCommand(text);
        if (tc.action == _TimerAction.query) {
          if ((isVoice || _voiceMode || _voiceSessionActive) &&
              _timers.isNotEmpty) {
            setState(() {
              _voiceCardType = _VoiceCardType.timer;
              _recordVoiceCard(_VoiceCardType.timer);
            });
          }
          if (_timers.isEmpty) {
            _appendAssistant('You do not have any timers running.',
                generationId: currentGen);
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
                'Here is the status of your timers:\n${lines.join('\n')}',
                generationId: currentGen);
          }
          _isSubmitting = false;
          return;
        }
        if (tc.action == _TimerAction.create) {
          // 1. Loop Protection (Voice)
          if (isVoice) {
            // Double check for echo even if STT filter passed
            if (_lastTtsEndAt != null &&
                DateTime.now().difference(_lastTtsEndAt!).inSeconds < 5) {
              _logSystem(
                  'TimerLoopBlocked', {'reason': 'voice_echo', 'text': text});
              _isSubmitting = false;
              return;
            }
          }

          // 2. Cooldown
          if (_lastTimerCreatedAt != null &&
              DateTime.now().difference(_lastTimerCreatedAt!).inSeconds < 30) {
            _logSystem('TimerCooldownBlocked',
                {'last_created': _lastTimerCreatedAt.toString()});
            _appendAssistant(
                'Please wait 30 seconds before setting another timer.',
                generationId: currentGen);
            _isSubmitting = false;
            return;
          }

          // 3. Create Directly (No Confirmation)
          await _createTimer(text, currentGen);
          _isSubmitting = false;
          return;
        }

        // Check for Atomize Intent explicitly to ensure dynamic rendering
        // and prevent "note taking" fallback behavior.
        if (_inferIntent(text) == Intent.atomize) {
          _engage('TaskFlow Agent');
          try {
            final r = await api.atomizeTask(text);
            _disengage('TaskFlow Agent');
            final steps = (r['micro_steps'] as List<dynamic>? ?? []);

            setState(() {
              _taskBreakdownSteps = steps;
              _voiceCardType = _VoiceCardType.taskBreakdown;
              _recordVoiceCard(_VoiceCardType.taskBreakdown);
            });

            _appendAssistant('Here is a suggested breakdown for your task.',
                metadata: {'type': 'task_breakdown', 'data': steps},
                generationId: currentGen);
          } catch (e) {
            _disengage('TaskFlow Agent');
            _appendAssistant('Failed to atomize task: $e',
                generationId: currentGen);
          }
          _isSubmitting = false;
          return;
        }

        // Check for Reduce Intent explicitly to ensure dynamic rendering
        if (_inferIntent(text) == Intent.reduce) {
          final opts = text
              .replaceAll(RegExp(r'^reduce:?\s*', caseSensitive: false), '')
              .split(RegExp(r'[\n,;]+'))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();

          if (opts.isEmpty) {
            // Fallback to orchestrator if no options parsed, maybe it's a general query
          } else {
            _engage('Decision Agent');
            setState(() {
              // Optimistically clear old options to avoid stale data display
              _decisionOptions = [];
            });
            try {
              final r = await api.reduceOptions(opts, 3);
              _disengage('Decision Agent');
              final roList = (r['reduced_options'] as List<dynamic>? ?? [])
                  .map((e) => e.toString())
                  .toList();
              final ro = roList.join(', ');

              setState(() {
                _decisionOptions = roList;
                _voiceCardType = _VoiceCardType.decisionHelper;
                _recordVoiceCard(_VoiceCardType.decisionHelper);
              });

              _appendAssistant('Decision Support engaged. Reduced to: $ro',
                  metadata: {'type': 'decision_helper', 'data': roList},
                  generationId: currentGen);
              _isSubmitting = false;
              return;
            } catch (e) {
              _disengage('Decision Agent');
              // Fallthrough to orchestrator on error
            }
          }
        }

        // Check for Schedule Intent explicitly
        if (_inferIntent(text) == Intent.schedule) {
          final items = text
              .replaceAll(RegExp(r'^schedule:?\s*', caseSensitive: false), '')
              .split(RegExp(r'[\n,;]+'))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();

          if (items.isNotEmpty) {
            _engage('TaskFlow Agent');
            try {
              final r = await api.scheduleTasks(items, 5, null);
              _disengage('TaskFlow Agent');
              if (r.containsKey('schedule') && r['schedule'] is List) {
                final sched = (r['schedule'] as List<dynamic>).cast<String>();
                setState(() {
                  // Use task breakdown card for schedule as it supports ordered steps
                  _taskBreakdownSteps = sched;
                  _voiceCardType = _VoiceCardType.taskBreakdown;
                  _recordVoiceCard(_VoiceCardType.taskBreakdown);
                });
              }
              _appendAssistant('Schedule created.', generationId: currentGen);
              _isSubmitting = false;
              return;
            } catch (e) {
              _disengage('TaskFlow Agent');
            }
          }
        }

        // Check for Task Prioritization Intent explicitly
        if (_inferIntent(text) == Intent.taskPrioritization) {
          _engage('Task Prioritization');
          try {
            // Use the local energy level state or default to 5
            final energy = _energyLevel;
            final r = await api.getPrioritizedTasks(
              limit: 3,
              includeCalendar: true,
              energy: energy,
            );
            _disengage('Task Prioritization');

            if (r['ok'] == true && r['tasks'] is List) {
              final tasks = (r['tasks'] as List)
                  .map((t) =>
                      PrioritizedTaskItem.fromJson(t as Map<String, dynamic>))
                  .toList();
              final reasoning = r['reasoning'] as String? ?? '';
              final originalCount = r['original_task_count'] as int? ?? 0;

              setState(() {
                _prioritizedTasks = tasks;
                _prioritizationReasoning = reasoning;
                _originalTaskCount = originalCount;
                _voiceCardType = _VoiceCardType.taskPrioritization;
                _recordVoiceCard(_VoiceCardType.taskPrioritization);
              });

              _appendAssistant(
                'Here are your top tasks to focus on:',
                metadata: {
                  'type': 'task_prioritization',
                  'tasks': r['tasks'],
                  'reasoning': reasoning,
                  'original_task_count': originalCount,
                },
                generationId: currentGen,
              );
              _isSubmitting = false;
              return;
            }
          } catch (e) {
            _disengage('Task Prioritization');
            debugPrint('Task prioritization failed: $e');
            // Fallthrough to orchestrator on error
          }
        }

        // Check for Notion commands
        if (lower.startsWith('/notion') || lower.contains('save to notion') || lower.contains('export to notion')) {
          await _handleNotionCommand(text, currentGen);
          _isSubmitting = false;
          return;
        }
      }

      // Orchestrator-first routing
      _engage('ADK Orchestrator');
      Map<String, dynamic> rr;
      try {
        final sid = await ref.read(ensureChatSessionIdProvider.future);
        final gse = ref.read(userSettingsProvider).googleSearchEnabled;
        rr = await api.chatRespond(text,
            sessionId: sid, googleSearch: gse, timeoutSeconds: timeoutSeconds);
      } catch (e) {
        if (!mounted) {
          _isSubmitting = false;
          return;
        }
        _disengage('ADK Orchestrator');
        // Handle timeout specifically if requested
        debugPrint('Error handling chat response: $e');
        if ((e.toString().contains("timeout") ||
                e.toString().contains("ClientException")) &&
            e.toString().contains("Connection refused")) {
          if (text.startsWith("I choose:")) {
            final choice =
                text.replaceFirst("I choose:", "").trim().toLowerCase();
            String fallbackMsg =
                "I see you chose that! I'm having trouble connecting to the brain right now, but you should definitely go for it.";

            if (choice.contains("speed run")) {
              fallbackMsg += " Set a timer for 10 minutes and just START!";
            } else if (choice.contains("side quest")) {
              fallbackMsg +=
                  " Imagine this is a quest for 1000 XP. Your reward awaits!";
            } else if (choice.contains("roleplay")) {
              fallbackMsg +=
                  " You are the main character. The mission starts now!";
            } else {
              fallbackMsg += " Just take the first step!";
            }

            _appendAssistant(fallbackMsg, generationId: currentGen);
            _isSubmitting = false;
            return;
          }
        }
        NpSnackbar.show(context, '$e', type: NpSnackType.warning);
        _isSubmitting = false;
        return;
      }
      _disengage('ADK Orchestrator');
      final reply = (rr['text'] as String?) ?? '';
      final tools = rr['tools'];
      final toolsList = (tools is List) ? tools : <dynamic>[];

      bool suppressText = false;
      for (var tool in toolsList) {
        _updateVoiceCardForTool(tool);
        if (tool is Map && tool['ui_mode'] == 'dopamine_card') {
          // If a dopamine card is present, suppress the text reply to avoid redundancy
          suppressText = true;
        }
        if (tool is Map && tool['ui_mode'] == 'resume_chip') {
          final steps = (tool['next_steps'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList();
          final sugg = <String>["Resume"];
          if (steps.isNotEmpty) sugg.add(steps.first);
          setState(() {
            _dynamicSuggestions = sugg;
            _canResume = true;
          });
          _appendAssistant('Context restored. Tap Resume to continue.',
              generationId: currentGen);
        }
        if (tool is Map && tool['ui_mode'] == 'auto_log_energy') {
          final level = (tool['level'] as num?)?.toInt();
          if (level != null) {
            ref.read(energyStoreProvider).logEnergy(level);
            debugPrint('Auto-logged energy level: $level');
          }
        }
      }

      if (reply.isNotEmpty || toolsList.isNotEmpty) {
        final askEmail = lower.contains('email');
        final parts = <String>[];
        if (reply.isNotEmpty && !suppressText) parts.add(reply);
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

        Map<String, dynamic>? metadata;
        for (final t in toolsList) {
          if (t is Map &&
              t['tool'] == 'google_calendar_mcp:search_events' &&
              t['args'] is Map &&
              t['args']['events'] is List) {
            metadata = {'type': 'calendar_events', 'data': t['args']['events']};
          }
          if (t is Map && t['ui_mode'] == 'dopamine_card') {
            metadata = {'type': 'dopamine_card', 'data': t['reframe'] ?? ''};
          }
          if (t is Map && t['ui_mode'] == 'paralysis_breaker') {
            final opts = t['result']?['options'];
            if (opts is List) {
              metadata = {
                'type': 'decision_helper',
                'data': opts,
                'selected_option': null
              };
            }
          }
          if (t is Map && t['ui_mode'] == 'task_prioritization') {
            final tasks = t['tasks'] as List<dynamic>? ?? [];
            final reasoning = t['reasoning'] as String? ?? '';
            final originalCount = t['original_task_count'] as int? ?? 0;
            metadata = {
              'type': 'task_prioritization',
              'tasks': tasks,
              'reasoning': reasoning,
              'original_task_count': originalCount,
            };
            // Update state for voice mode
            setState(() {
              _prioritizedTasks = tasks
                  .map((t) =>
                      PrioritizedTaskItem.fromJson(t as Map<String, dynamic>))
                  .toList();
              _prioritizationReasoning = reasoning;
              _originalTaskCount = originalCount;
              _voiceCardType = _VoiceCardType.taskPrioritization;
              _recordVoiceCard(_VoiceCardType.taskPrioritization);
            });
            suppressText = true;
          }
          // Notion Page Created Widget
          if (t is Map && t['ui_mode'] == 'notion_page_created') {
            final pageData = t['data'] as Map<String, dynamic>? ?? {};
            metadata = {
              'type': 'notion_page_created',
              'data': pageData,
            };
            // Update state for voice mode
            setState(() {
              _notionPageData = pageData;
              _voiceCardType = _VoiceCardType.notionPage;
              _recordVoiceCard(_VoiceCardType.notionPage);
            });
          }
          // Notion Search Results Widget
          if (t is Map && t['ui_mode'] == 'notion_search_results') {
            final pages = t['data'] as List<dynamic>? ?? [];
            metadata = {
              'type': 'notion_search_results',
              'data': pages,
            };
          }
        }

        if (displayTools.isNotEmpty) {
          if (kDebugMode) {
            // parts.add('Tools: $displayTools');
          }
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
                // We have a widget for this, so just add a header
                parts.add('Here are your events for today:');
                metadata = {'type': 'calendar_events', 'data': events};
              }
            } catch (_) {}
          }
        }
        if (parts.isEmpty) {
          _appendAssistant('', metadata: metadata, generationId: currentGen);
        } else {
          _appendAssistant(parts.join('\n'),
              metadata: metadata, generationId: currentGen);
        }
        _isSubmitting = false;
        return;
      }
      final intent = _inferIntent(text);
      _updateVoiceCardForIntent(intent);
      switch (intent) {
        case Intent.health:
          _engage('System');
          final r = await api.health();
          _disengage('System');
          _appendAssistant('System is healthy. Time: ${r['time']}',
              generationId: currentGen);
          break;
        case Intent.atomize:
          _engage('TaskFlow Agent');
          final r = await api.atomizeTask(text);
          _disengage('TaskFlow Agent');
          final steps = (r['micro_steps'] as List<dynamic>? ?? [])
              .map((e) => '- $e')
              .join('\n');
          _appendAssistant('Engaging TaskFlow Agent...\n$steps',
              generationId: currentGen);
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
          // Parse result to update UI if it's a list
          if (r.containsKey('schedule') && r['schedule'] is List) {
            final sched = (r['schedule'] as List<dynamic>).cast<String>();
            setState(() {
              _genericListItems = sched;
              _genericListTitle = 'Optimized Schedule';
              _voiceCardType = _VoiceCardType.list;
              _recordVoiceCard(_VoiceCardType.list);
            });
          }
          _appendAssistant('Schedule created: ${r.toString()}',
              generationId: currentGen);
          break;
        case Intent.countdown:
          // Protection logic similar to _TimerAction.create
          if (isVoice) {
            if (_lastTtsEndAt != null &&
                DateTime.now().difference(_lastTtsEndAt!).inSeconds < 5) {
              _logSystem(
                  'TimerLoopBlocked', {'reason': 'voice_echo', 'text': text});
              break;
            }
          }
          if (_lastTimerCreatedAt != null &&
              DateTime.now().difference(_lastTimerCreatedAt!).inSeconds < 30) {
            _logSystem('TimerCooldownBlocked',
                {'last_created': _lastTimerCreatedAt.toString()});
            _appendAssistant(
                'Please wait 30 seconds before setting another timer.',
                generationId: currentGen);
            break;
          }

          // 3. Create Directly (No Confirmation)
          await _createTimer(text, currentGen);
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
          final roList = (r['reduced_options'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList();
          final ro = roList.join(', ');

          setState(() {
            _decisionOptions = roList;
            _voiceCardType = _VoiceCardType.decisionHelper;
            _recordVoiceCard(_VoiceCardType.decisionHelper);
          });

          _appendAssistant('Decision Support engaged. Reduced to: $ro',
              metadata: {'type': 'decision_helper', 'data': roList},
              generationId: currentGen);
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
          _appendAssistant('Energy match: ${r.toString()}',
              generationId: currentGen);
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
              'External Brain captured. Task: ${r['task_id']}\nNotes:\n$lines',
              generationId: currentGen);
          break;
        case Intent.calendarToday:
          _engage('Calendar Agent');
          final r = await api.calendarEventsToday();
          _disengage('Calendar Agent');
          final events = (r['result']?['events'] as List<dynamic>? ?? []);
          if (events.isEmpty) {
            _appendAssistant('No events found for today.',
                generationId: currentGen);
          } else {
            final lines = events
                .map((e) =>
                    '- ${e['summary'] ?? 'Untitled'} (${e['start'] ?? ''} - ${e['end'] ?? ''})')
                .join('\n');
            _appendAssistant('Today\'s events:\n$lines',
                generationId: currentGen);
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
              'Here are available commands. Tap a suggestion to auto-fill.',
              generationId: currentGen);
          break;
        case Intent.overview:
          _engage('Metrics Agent');
          final ov = await api.metricsOverview();
          _disengage('Metrics Agent');
          _appendAssistant('Today overview: ${ov.toString()}',
              generationId: currentGen);
          break;
        case Intent.sessions:
          _engage('Sessions Agent');
          final sy = await api.sessionsYesterday();
          _disengage('Sessions Agent');
          _appendAssistant('Yesterday sessions: ${sy.toString()}',
              generationId: currentGen);
          break;
        case Intent.unknown:
          _engage('Command Router');
          try {
            final sid = await ref.read(ensureChatSessionIdProvider.future);
            final gse = ref.read(userSettingsProvider).googleSearchEnabled;
            final r =
                await api.chatCommand(text, sessionId: sid, googleSearch: gse);
            _disengage('Command Router');
            if (r['ok'] == true) {
              final sugg =
                  (r['suggestions'] as List<dynamic>? ?? []).cast<String>();
              if (sugg.isNotEmpty) setState(() => _dynamicSuggestions = sugg);
              _appendAssistant(r.toString(), generationId: currentGen);
            } else {
              _appendAssistant(
                  'I did not understand. Try "help" to see supported commands.',
                  generationId: currentGen);
            }
          } catch (_) {
            _disengage('Command Router');
            _appendAssistant('Error handling command. Try "help".',
                generationId: currentGen);
          }
          break;
        case Intent.taskPrioritization:
          // Already handled above before orchestrator call
          // This case is here for exhaustiveness
          _engage('Task Prioritization');
          try {
            final energy = _energyLevel;
            final r = await api.getPrioritizedTasks(
              limit: 3,
              includeCalendar: true,
              energy: energy,
            );
            _disengage('Task Prioritization');

            if (r['ok'] == true && r['tasks'] is List) {
              final tasks = (r['tasks'] as List)
                  .map((t) =>
                      PrioritizedTaskItem.fromJson(t as Map<String, dynamic>))
                  .toList();
              final reasoning = r['reasoning'] as String? ?? '';
              final originalCount = r['original_task_count'] as int? ?? 0;

              setState(() {
                _prioritizedTasks = tasks;
                _prioritizationReasoning = reasoning;
                _originalTaskCount = originalCount;
                _voiceCardType = _VoiceCardType.taskPrioritization;
                _recordVoiceCard(_VoiceCardType.taskPrioritization);
              });

              _appendAssistant(
                'Here are your top tasks to focus on:',
                metadata: {
                  'type': 'task_prioritization',
                  'tasks': r['tasks'],
                  'reasoning': reasoning,
                  'original_task_count': originalCount,
                },
                generationId: currentGen,
              );
            } else {
              _appendAssistant(
                  r['reasoning'] as String? ?? 'Unable to prioritize tasks.',
                  generationId: currentGen);
            }
          } catch (e) {
            _disengage('Task Prioritization');
            _appendAssistant('Error prioritizing tasks: $e',
                generationId: currentGen);
          }
          break;
      }
    } catch (e) {
      if (!mounted) return;
      NpSnackbar.show(context, '$e', type: NpSnackType.destructive);
      _appendAssistant('Error: $e', generationId: currentGen);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _isSubmitting = false;
        });
        if (!isVoice) {
          _input.clear();
        }
      }
    }
  }

  /// Appends an assistant message to the chat and optionally speaks it.
  ///
  /// Adds the message to the local list, persists it to the [ChatStore],
  /// and triggers TTS if voice output is enabled.
  void _appendAssistant(String content,
      {Map<String, dynamic>? metadata, int? generationId}) async {
    setState(() {
      _messages.add(
          ChatMessage(role: 'assistant', content: content, metadata: metadata));
    });
    _scrollToBottom();
    try {
      final store = ref.read(chatStoreProvider);
      final currentId = ref.read(chatSessionIdProvider);
      final ensured = await ref.read(ensureChatSessionIdProvider.future);
      final sid = currentId ?? ensured;
      await store.addMessage(sid,
          ChatMessage(role: 'assistant', content: content, metadata: metadata));
      await store.markRead(sid);
    } catch (_) {}

    // Check generation ID to prevent stale TTS
    if (generationId != null && generationId != _responseGeneration) {
      debugPrint(
          "Skipping stale TTS (gen $generationId vs $_responseGeneration)");
      return;
    }

    // Speak the response if voice output is enabled
    if (_voiceOutput && _tts.supported) {
      // Stop any previous speech first to prevent overlap
      await _tts.stop();

      final settings = ref.read(userSettingsProvider);
      final useVoice = (_voiceSessionActive && settings.voiceLockDuringSession)
          ? (_sessionTtsVoice ?? settings.ttsVoice)
          : settings.ttsVoice;
      final useQuality =
          (_voiceSessionActive && settings.voiceLockDuringSession)
              ? (_sessionTtsQuality ?? settings.ttsQuality)
              : settings.ttsQuality;
      _tts.setOptions(voice: useVoice, quality: useQuality);

      setState(() {
        _speaking = true;
        _currentTtsText = content;
        _ttsStartAt = DateTime.now();
      });
      _tts.volume = _volume;

      // FIRE AND FORGET for Barge-in support
      // We do NOT await here if we are in a voice session,
      // so the voice loop can restart immediately.
      if (_voiceSessionActive) {
        _tts.speak(content).then((_) {
          if (mounted) {
            setState(() {
              _speaking = false;
              // Don't clear _currentTtsText immediately, as echo might arrive slightly after.
              // But we can clear it if we want to reset match logic.
              // Actually, keeping it allows "trailing echo" suppression.
            });
          }
        });
      } else {
        await _tts.speak(content);
        if (mounted) setState(() => _speaking = false);
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
              if (kDebugMode && _voiceSessionActive)
                Padding(
                  padding:
                      const EdgeInsets.only(bottom: DesignTokens.spacingSm),
                  child: Text(
                    'Session voice: ${_sessionTtsVoice ?? 'default'} / ${_sessionTtsQuality ?? 'default'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Realtime Voice (Beta)',
                              style: Theme.of(context).textTheme.titleMedium),
                          Text('Low-latency Gemini Live API',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              )),
                        ],
                      )),
                  Switch(
                      value: _useRealtimeVoice,
                      onChanged: (v) {
                        setSheetState(() => _useRealtimeVoice = v);
                        setState(() => _useRealtimeVoice = v);
                        if (v && _voiceSessionActive) {
                          // Restart session with realtime mode
                          _toggleVoiceSession();
                          Future.delayed(const Duration(milliseconds: 100), () {
                            _toggleVoiceSession();
                          });
                        }
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
  /// If realtime voice is enabled, uses Gemini Live API instead.
  void _toggleVoiceSession() {
    setState(() {
      _voiceSession = !_voiceSession;
      if (_voiceSession) {
        _voiceSessionActive = true;
        _voiceOutput = true; // Auto-enable output
        final settings = ref.read(userSettingsProvider);
        _sessionTtsVoice = settings.ttsVoice;
        _sessionTtsQuality = settings.ttsQuality;
        
        // Reset echo cancellation for new session
        _echoCancellation.reset();
        
        if (_useRealtimeVoice) {
          // Use Gemini Live API for realtime voice
          debugPrint('[VoiceSession] Starting REALTIME mode');
          _startRealtimeVoiceSession();
        } else {
          // Use legacy voice mode
          // Apply voice settings to TTS service immediately
          _tts.setOptions(
            voice: _sessionTtsVoice,
            quality: _sessionTtsQuality,
          );
          debugPrint('[VoiceSession] Started LEGACY mode with voice=$_sessionTtsVoice, quality=$_sessionTtsQuality');
          
          _startVoiceSessionLoop();
        }
      } else {
        _voiceSessionActive = false;
        _sessionTtsVoice = null;
        _sessionTtsQuality = null;
        
        if (_useRealtimeVoice) {
          // Stop realtime voice session
          _stopRealtimeVoiceSession();
        } else {
          _speech.stop();
          _tts.stop();
        }
        
        _listening = false;
        _engaged.remove('SpeechRecognition');

        // Ensure Cloud STT is also stopped if active
        if (_voiceCompleter != null && !_voiceCompleter!.isCompleted) {
          // We don't await here to avoid blocking UI, but we trigger the stop
          final cloudStt = ref.read(cloudSttServiceProvider);
          cloudStt.stopAndTranscribe().then((text) {
            if (_voiceCompleter != null && !_voiceCompleter!.isCompleted) {
              _voiceCompleter!.complete(text);
            }
          });
        }
      }
    });
  }
  
  /// Starts a realtime voice session using Gemini Live API
  Future<void> _startRealtimeVoiceSession() async {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? 'anonymous';
    final api = ref.read(apiClientProvider);
    
    // Build WebSocket URL from API base URL
    final baseUrl = api.baseUrl.replaceFirst('http', 'ws');
    
    final realtimeVoice = ref.read(realtimeVoiceServiceProvider);
    
    // Set up listeners
    _realtimeStateSub?.cancel();
    _realtimeStateSub = realtimeVoice.stateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        switch (state) {
          case VoiceSessionState.listening:
            _listening = true;
            _speaking = false;
            _partialText = 'Listening...';
            break;
          case VoiceSessionState.processing:
            _listening = false;
            _speaking = false;
            _partialText = 'Processing...';
            break;
          case VoiceSessionState.speaking:
            _listening = false;
            _speaking = true;
            // Pause audio capture while model is speaking to prevent echo
            _realtimeAudioCapture?.stop();
            break;
          case VoiceSessionState.connected:
            _listening = false;
            _speaking = false;
            _partialText = '';
            // Resume audio capture when model stops speaking
            _startRealtimeAudioCapture();
            break;
          case VoiceSessionState.disconnected:
          case VoiceSessionState.error:
            _voiceSessionActive = false;
            _voiceSession = false;
            _listening = false;
            _speaking = false;
            // Stop audio capture
            _realtimeAudioCapture?.stop();
            break;
          default:
            break;
        }
      });
    });
    
    _realtimeTextSub?.cancel();
    _realtimeTextSub = realtimeVoice.textStream.listen((text) {
      if (!mounted || text.isEmpty) return;
      _appendAssistant(text);
    });
    
    _realtimeTranscriptSub?.cancel();
    _realtimeTranscriptSub = realtimeVoice.transcriptStream.listen((event) {
      if (!mounted) return;
      if (event.isFinal && event.text.isNotEmpty) {
        // Add user message to chat
        _appendUser(event.text);
      } else {
        setState(() {
          _partialText = event.text;
        });
      }
    });
    
    // Connect to realtime voice service
    final config = RealtimeVoiceConfig(
      userId: userId,
      voice: 'Aoede',
      systemPrompt: '''You are NeuroPilot, a supportive AI assistant designed specifically for people with ADHD. 
You help with task management, focus sessions, and provide encouragement. 
Keep responses concise and actionable. Be warm, understanding, and patient.
When the user seems overwhelmed, help break things down into smaller steps.''',
      baseUrl: baseUrl,
    );
    
    final connected = await realtimeVoice.connect(config);
    if (!connected && mounted) {
      setState(() {
        _voiceSessionActive = false;
        _voiceSession = false;
      });
      NpSnackbar.show(context, 'Failed to connect to realtime voice service', type: NpSnackType.destructive);
      return;
    }
    
    // Start audio capture and streaming
    await _startRealtimeAudioCapture();
  }
  
  /// Starts capturing audio and streaming to the realtime voice service
  Future<void> _startRealtimeAudioCapture() async {
    // Don't start if not in realtime voice mode or already capturing
    if (!_useRealtimeVoice || !_voiceSessionActive) return;
    if (_realtimeAudioCapture?.isCapturing == true) return;
    
    debugPrint('[RealtimeVoice] Starting audio capture');
    
    // Create audio capture instance if needed
    _realtimeAudioCapture ??= RealtimeAudioCapture();
    
    final realtimeVoice = ref.read(realtimeVoiceServiceProvider);
    
    // Set up audio streaming to WebSocket
    _realtimeAudioSub?.cancel();
    _realtimeAudioSub = _realtimeAudioCapture!.audioStream.listen((audioData) {
      if (_voiceSessionActive && realtimeVoice.isConnected && !_speaking) {
        realtimeVoice.sendAudio(audioData);
      }
    });
    
    // Start capturing with echo cancellation enabled
    const config = AudioCaptureConfig(
      sampleRate: 16000,
      channelCount: 1,
      echoCancellation: true,
      noiseSuppression: true,
      autoGainControl: true,
    );
    
    final started = await _realtimeAudioCapture!.start(config);
    if (!started && mounted) {
      debugPrint('[RealtimeVoice] Failed to start audio capture');
      NpSnackbar.show(context, 'Failed to access microphone', type: NpSnackType.destructive);
    } else {
      debugPrint('[RealtimeVoice] Audio capture started successfully');
      setState(() {
        _listening = true;
      });
    }
  }
  
  /// Stops the realtime voice session
  Future<void> _stopRealtimeVoiceSession() async {
    // Stop audio capture first
    _realtimeAudioSub?.cancel();
    _realtimeAudioSub = null;
    await _realtimeAudioCapture?.stop();
    
    // Cancel subscriptions
    _realtimeStateSub?.cancel();
    _realtimeTextSub?.cancel();
    _realtimeTranscriptSub?.cancel();
    
    // Disconnect from WebSocket
    final realtimeVoice = ref.read(realtimeVoiceServiceProvider);
    await realtimeVoice.disconnect();
    
    debugPrint('[RealtimeVoice] Session stopped');
  }
  
  /// Appends a user message to the chat
  void _appendUser(String content) {
    if (content.trim().isEmpty) return;
    
    final msg = ChatMessage(
      role: 'user',
      content: content,
    );
    
    setState(() {
      _messages.add(msg);
    });
    
    // Persist to chat store
    final chatStore = ref.read(chatStoreProvider);
    final currentId = ref.read(chatSessionIdProvider);
    if (currentId != null) {
      chatStore.addMessage(currentId, msg);
    }
    
    _scrollToBottom();
  }

  /// Starts listening for voice input.
  ///
  /// Handles speech recognition lifecycle, partial results, and silence detection.
  /// Automatically submits the recognized text when silence is detected.
  Future<void> _startListeningForSession() async {
    if (!mounted) return;
    if (_voiceSessionActive) return;
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

      if (!_voiceSessionActive && (_voiceSession || _voiceOutput) && mounted) {
        // Only restart if we're still in voice session mode
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted ||
              (!_voiceSession && !_voiceOutput) ||
              _voiceSessionActive) {
            return;
          }
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
  /// Extracts duration and unit if creating a timer, and also treats bare
  /// duration phrases like "for 1 minute" as timer requests.
  _TimerParseResult _parseTimerCommand(String q) {
    final s = q.toLowerCase().trim();
    final hasTimerWord = s.contains('timer') || s.contains('countdown');

    final impliesTimerQuery = s.contains('time left') ||
        s.contains('remaining time') ||
        s.contains('how much time') ||
        s.contains('how long left');

    final hasCreateVerb = s.contains('start') ||
        s.contains('set') ||
        s.contains('add') ||
        s.contains('begin') ||
        s.contains('another');

    final hasQueryWording = s.contains('do i have') ||
        s.contains('any') ||
        s.contains('running') ||
        s.contains('status') ||
        s.contains('remaining') ||
        s.contains('what');

    // Detect timer status queries such as:
    // "Do I have any timers running?", "What timers are remaining?", etc.
    final isQuery = ((hasTimerWord && hasQueryWording) || impliesTimerQuery) &&
        !hasCreateVerb;
    if (isQuery) return _TimerParseResult(_TimerAction.query);

    // Extract a duration like "1 minute", "30 sec", "2 hours".
    final reNum = RegExp(
        r"(\d+)\s*(second|seconds|sec|s|minute|minutes|min|m|hour|hours|hr|h)\b");
    final m = reNum.firstMatch(s);
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

    // Heuristic: treat short, duration-only phrases as timer creation even
    // without the word "timer", e.g. "for 1 minute", "1 minute", "in 30 sec".
    final looksLikeBareDuration = !hasTimerWord &&
        secs != null &&
        !s.contains('meeting') &&
        !s.contains('call') &&
        !s.contains('calendar') &&
        (s == (m?.group(0) ?? s) ||
            s.startsWith('for ') ||
            s.startsWith('in '));

    if ((hasTimerWord && (hasCreateVerb || secs != null)) ||
        looksLikeBareDuration) {
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
                    semanticsLabel: 'Decision support tool',
                    onTap: () {
                      Navigator.pop(context);
                      _setInput(l.exampleReduce);
                    }),
                NpChip(
                    label: l.suggestEnergyMatch,
                    semanticsLabel: 'Energy matching tool',
                    onTap: () {
                      Navigator.pop(context);
                      _setInput(l.exampleEnergyMatch);
                    }),
                NpChip(
                    label: l.suggestCapture,
                    semanticsLabel: 'Voice capture tool',
                    onTap: () {
                      Navigator.pop(context);
                      _setInput(l.exampleCapture);
                    }),
                NpChip(
                    label: 'Restore Context…',
                    semanticsLabel: 'Restore previous session context',
                    onTap: () async {
                      Navigator.pop(context);
                      await _promptRestoreContext(context);
                    }),
                ..._dynamicSuggestions.map((s) => NpChip(
                    label: s,
                    semanticsLabel: 'Suggestion: $s',
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

  Future<void> _promptRestoreContext(BuildContext context) async {
    final ctl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Restore Context'),
          content: TextField(
            controller: ctl,
            decoration: const InputDecoration(labelText: 'Task ID'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final id = ctl.text.trim();
                Navigator.pop(ctx);
                if (id.isEmpty) return;
                final api = ref.read(apiClientProvider);
                await _handleSubmit(
                  api,
                  textOverride: 'restore context task_id: $id',
                );
              },
              child: const Text('Restore'),
            ),
          ],
        );
      },
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
    _voiceMode = widget.initialVoiceMode;
    // Automatically start voice session if entering in voice mode
    if (widget.initialVoiceMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_voiceSessionActive) {
          _toggleVoiceSession();
        }
      });
    }
    _scrollController.addListener(_scrollListener);

    // Observe app lifecycle for Just-in-Time Prompts on mobile
    if (!kIsWeb) {
      WidgetsBinding.instance.addObserver(this);
    }

    // Auto-start only when explicitly enabled
    if (!_isTestEnv && _bodyDoubleActive) {
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
    
    // Connect TTS to echo cancellation service
    _tts.onSpeakStart = (text) {
      _echoCancellation.onTtsStart(text);
    };
    _tts.onSpeakEnd = () {
      _echoCancellation.onTtsEnd();
    };
    
    _speakingSub?.cancel();
    _speakingSub = _tts.speaking.listen((s) {
      if (!mounted) return;
      setState(() {
        _speaking = s;
        if (!s) {
          _lastTtsEndAt = DateTime.now();
        }
      });
      if (!_voiceSessionActive &&
          !s &&
          !_listening &&
          !_loading &&
          (_voiceSession || _voiceOutput)) {
        Future.delayed(
            const Duration(milliseconds: 1200), _startListeningForSession);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadPulsePrefs();
      await _pingBackend();
      
      // Initialize TTS with user's saved voice settings
      try {
        final settings = ref.read(userSettingsProvider);
        if (settings.ttsVoice != null || settings.ttsQuality != null) {
          _tts.setOptions(
            voice: settings.ttsVoice,
            quality: settings.ttsQuality,
          );
          debugPrint('[TTS] Initialized with voice=${settings.ttsVoice}, quality=${settings.ttsQuality}');
        }
      } catch (e) {
        debugPrint('[TTS] Failed to initialize voice settings: $e');
      }
      
      try {
        // Warm up calendar status to ensure backend token refresh logic is triggered
        // This fixes the issue where calendar tool fails until Settings is visited
        final ts = DateTime.now().millisecondsSinceEpoch;
        await ref
            .read(apiClientProvider)
            .get('/auth/google/calendar/status?_=$ts');
      } catch (_) {}
      try {
        // await ref.read(loadGoogleSearchEnabledProvider.future);
        // await ref.read(loadFirestoreSyncEnabledProvider.future);
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
      try {
        _attachA2AListener();
      } catch (_) {}
      if (!_isTestEnv) {
        _heartbeat?.cancel();
        _heartbeat = Timer.periodic(const Duration(seconds: 30), (_) async {
          await _pingBackend();
        });
      }
    });
  }

  Future<void> _loadPulsePrefs() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    final speed = p.getInt('pulse_speed_ms');
    // final base = p.getInt('pulse_base_color');
    setState(() {
      if (speed != null) _pulseSpeedMs = speed;
      // _pulseBaseColor = base != null ? Color(base) : null;
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

  void _attachA2AListener() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _a2aSub?.cancel();
    final stream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('a2a')
        .snapshots()
        .handleError((e) {
      debugPrint('Chat A2A listener error: $e');
    });
    _a2aSub = stream.listen((snap) {
      final changed = <String, String>{};
      for (final d in snap.docs) {
        final id = d.id;
        if (id == 'meta') continue;
        final data = d.data();
        final pid = (data['partner_id'] as String?) ?? id;
        if (pid.isEmpty) continue;
        final st = (data['status'] as String?) ?? '';
        final prev = _lastA2AStatus[pid] ?? '';
        if (st.isNotEmpty && st != prev) {
          changed[pid] = st;
        }
      }
      if (changed.isEmpty) return;
      _lastA2AStatus.addAll(changed);
      if (!mounted) return;
      String? connPid;
      String? discPid;
      for (final e in changed.entries) {
        final v = e.value.toLowerCase();
        if (connPid == null && v.contains('connect')) connPid = e.key;
        if (discPid == null && (v.contains('disconn') || v.contains('fail'))) {
          discPid = e.key;
        }
      }
      if (connPid != null) {
        _showModeBannerNow('Partner connected: $connPid');
      } else if (discPid != null) {
        _showModeBannerNow('Partner disconnected: $discPid');
      }
    }, onError: (e) {
      debugPrint('Chat A2A listener onError: $e');
    });
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
    // DEPRECATED: Health checks are now handled by backendHealthProvider.
    // This method remains only to handle legacy offline-voice-queue processing
    // if state changes are detected via the provider listener in build().
    if (!mounted) return;
    final api = ref.read(apiClientProvider);

    // If we are back online and have pending voice text, send it.
    // We use the provider's state which is synced to _backendOk in build()
    if (_backendOk && _pendingVoiceText != null) {
      final t = _pendingVoiceText!;
      _pendingVoiceText = null;
      _offlineHoldNoticeShown = false;
      try {
        await _handleSubmit(api, isVoice: true, textOverride: t);
        if (mounted) {
          _showModeBannerNow('Sent held voice message');
        }
      } catch (_) {
        // If sending fails, we might be offline again, but we let the provider handle state
        _pendingVoiceText = t; // Restore text to queue
      }
    }
  }

  DateTime _now() {
    return DateTime.now();
  }

  Widget _timerCard(BuildContext context, _TimerItem t) {
    final cs = Theme.of(context).colorScheme;
    final now = _now();
    final remLive = (t.paused || t.completed)
        ? t.remainingSeconds
        : (() {
            final r = (t.target.difference(now).inMilliseconds / 1000).ceil();
            return r < 0 ? 0 : (r > t.totalSeconds ? t.totalSeconds : r);
          })();

    // If timer is just finished but not yet marked completed by ticker, we wait.
    // The ticker will handle marking it completed and triggering alerts.

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

  // ============ Body Doubling Methods ============

  /// Shows the body doubling mode selection dialog
  Future<void> _showBodyDoubleModeDialog({String? task}) async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassContainer(
          borderRadius: BorderRadius.circular(24),
          padding: const EdgeInsets.all(24),
          color: const Color(0xFF0F0505).withValues(alpha: 0.9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Body Doubling Setup",
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "How can I help you stay on track?",
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              _buildBodyDoubleModeOption(
                icon: Icons.timer_outlined,
                title: "Focus Assistance",
                subtitle: "Frequent check-ins (5m)",
                mode: BodyDoublingMode.focusAssistance,
                task: task,
              ),
              const SizedBox(height: 12),
              _buildBodyDoubleModeOption(
                icon: Icons.people_outline,
                title: "Accountability",
                subtitle: "Progress updates (15m)",
                mode: BodyDoublingMode.accountability,
                task: task,
              ),
              const SizedBox(height: 12),
              _buildBodyDoubleModeOption(
                icon: Icons.monitor_heart_outlined,
                title: "Productivity Tracking",
                subtitle: "Silent monitoring",
                mode: BodyDoublingMode.productivityTracking,
                task: task,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // Continue without body doubling
                    },
                    child: Text(
                      "Skip",
                      style:
                          TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBodyDoubleModeOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required BodyDoublingMode mode,
    String? task,
  }) {
    return InkWell(
      onTap: () {
        ref.read(bodyDoublingServiceProvider.notifier).startSession(
              mode,
              task: task ??
                  (_currentTask.isNotEmpty ? _currentTask : "current task"),
            );
        Navigator.pop(context);
        setState(() => _bodyDoubleActive = true);
        NpSnackbar.show(context, 'Body Double Active - $title',
            type: NpSnackType.success);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white12),
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withValues(alpha: 0.05),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFE2B58D)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 16, color: Colors.white30),
          ],
        ),
      ),
    );
  }

  /// Shows check-in notification as a banner above suggestions
  void _showCheckInNotification(String message, bool needsResponse) {
    _checkInBannerTimer?.cancel();
    _checkInCountdownTimer?.cancel();

    setState(() {
      _pendingCheckInMessage = message;
      _showCheckInBanner = true;
      _checkInTimerSeconds = 30; // 30 second countdown for check-in
    });

    // Start countdown timer
    _checkInCountdownTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _checkInTimerSeconds--;
        if (_checkInTimerSeconds <= 0) {
          timer.cancel();
          _dismissCheckInBanner();
        }
      });
    });

    // Auto-dismiss after 30 seconds if not interacted
    _checkInBannerTimer = Timer(const Duration(seconds: 30), () {
      if (mounted) _dismissCheckInBanner();
    });
  }

  void _dismissCheckInBanner() {
    _checkInBannerTimer?.cancel();
    _checkInCountdownTimer?.cancel();
    ref.read(bodyDoublingServiceProvider.notifier).dismissCheckIn();
    setState(() {
      _showCheckInBanner = false;
      _pendingCheckInMessage = null;
      _checkInTimerSeconds = 0;
    });
  }

  void _respondToCheckIn(String response) {
    _checkInBannerTimer?.cancel();
    _checkInCountdownTimer?.cancel();
    ref.read(bodyDoublingServiceProvider.notifier).respondToCheckIn(response);
    setState(() {
      _showCheckInBanner = false;
      _pendingCheckInMessage = null;
      _checkInTimerSeconds = 0;
    });
  }

  /// Builds the check-in banner widget with circular timer
  Widget _buildCheckInBanner() {
    if (!_showCheckInBanner || _pendingCheckInMessage == null) {
      return const SizedBox.shrink();
    }

    final progress = _checkInTimerSeconds / 30.0;
    const accentColor = Color(0xFFE2B58D);

    return Container(
      margin: const EdgeInsets.only(bottom: DesignTokens.spacingSm),
      padding: const EdgeInsets.all(DesignTokens.spacingMd),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Circular timer
          SizedBox(
            width: 36,
            height: 36,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 3,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _checkInTimerSeconds <= 10 ? Colors.orange : accentColor,
                  ),
                ),
                Text(
                  '$_checkInTimerSeconds',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: DesignTokens.spacingMd),
          // Message
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.notifications_active,
                        color: accentColor, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Check-in',
                      style: GoogleFonts.inter(
                        color: accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _pendingCheckInMessage!,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: DesignTokens.spacingSm),
          // Actions
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => _respondToCheckIn("Still working on it!"),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '👍',
                    style: GoogleFonts.inter(fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: _dismissCheckInBanner,
                child: Text(
                  'Dismiss',
                  style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.2);
  }
}
