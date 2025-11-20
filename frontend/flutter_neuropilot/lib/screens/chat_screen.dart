import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_neuropilot/l10n/app_localizations.dart';
import '../core/design_tokens.dart';
import '../core/chat_message.dart';
import '../core/components/np_app_bar.dart';
import '../core/components/np_text_field.dart';
import '../core/components/np_button.dart';
import '../core/components/np_chip.dart';
import '../core/components/np_snackbar.dart';
import '../core/components/np_progress.dart';
import '../services/api_client.dart';
import '../core/speech_service.dart';
import '../state/session_state.dart';
import '../core/routes.dart';
import '../core/link_opener.dart';

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
}

enum _TimerAction { create, query, unknown }

class _TimerParseResult {
  _TimerParseResult(this.action, {this.seconds, this.additional = false});
  final _TimerAction action;
  final int? seconds;
  final bool additional;
}

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final List<ChatMessage> _messages = [];
  final TextEditingController _input = TextEditingController();
  bool _loading = false;
  bool _voiceMode = false;
  final SpeechService _speech = createSpeechService();
  final LinkOpener _linkOpener = createLinkOpener();
  final List<String> _engaged = [];
  bool _backendOk = false;
  Timer? _heartbeat;
  List<String> _dynamicSuggestions = [];
  bool _listening = false;
  late final AnimationController _pulseCtl;
  late final Animation<double> _pulseScale;
  String _partialText = '';

  StreamSubscription<String>? _partialSub;

  // Proactive Check-in State (Always Active)
  int _sessionDurationMinutes = 0;
  Timer? _sessionTimer;
  int _checkInIntervalSeconds = 120; // 2 minutes
  Timer? _inactivityTimer;
  DateTime? _lastActivityTime;

  // Just-in-Time Prompts State (mobile lifecycle)
  DateTime? _appPausedTime;
  final int _jitThresholdSeconds = 30; // Trigger after 30s away
  String _currentTask = ""; // Track what user is working on

  final List<_TimerItem> _timers = [];
  Timer? _timerTicker;
  String? _activeTimerId;
  int _pulseSpeedMs = 900;
  int _pulseThresholdPercent = 20;
  double _pulseMaxFreq = 3.0;
  Color? _pulseBaseColor;
  Color? _pulseAlertColor;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final api = ref.watch(apiClientProvider);
    return Scaffold(
      appBar: NpAppBar(
        title: l.chatTitle,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).pushNamed(Routes.settings),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_loading || (_engaged.isNotEmpty && !_listening))
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
                          .map((e) => NpChip(label: e, selected: true))
                          .toList(),
                    ],
                  ),
                ],
              ),
            ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: DesignTokens.spacingLg),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spacingLg,
                  vertical: DesignTokens.spacingSm),
              decoration: BoxDecoration(
                color: _backendOk ? DesignTokens.success : DesignTokens.error,
                borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _backendOk
                          ? 'Connected to backend'
                          : 'Backend unreachable. Retrying...',
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
                  const SizedBox(width: DesignTokens.spacingSm),
                  NpButton(
                    label: 'External Brain',
                    icon: Icons.library_books,
                    type: NpButtonType.secondary,
                    onPressed: () async {
                      final b = Uri.base;
                      final hostPort = b.port == 0 ? b.host : '${b.host}:${b.port}';
                      final url = '${b.scheme}://$hostPort/#/external';
                      final ok = await _linkOpener.open(url);
                      if (!ok) {
                        NpSnackbar.show(context, 'Opening external app failed. Navigating in-app instead.', type: NpSnackType.warning);
                        Navigator.of(context).pushNamed(Routes.external);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          if (_listening)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spacingLg,
                  vertical: DesignTokens.spacingSm),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spacingLg,
                    vertical: DesignTokens.spacingSm),
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
                    Expanded(
                        child: Text('Listening...',
                            style: const TextStyle(
                                color: DesignTokens.onPrimary))),
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
                        await _speech.stop();
                        setState(() => _listening = false);
                      },
                    ),
                  ],
                ),
              ),
            ),
          if (_timers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spacingLg,
                  vertical: DesignTokens.spacingSm),
              child: Column(
                children: _timers.map((t) {
                  final active =
                      _activeTimerId == t.id && !t.paused && !t.completed;
                  final bg = Theme.of(context).colorScheme.surface;
                  final borderColor = t.completed
                      ? Theme.of(context).colorScheme.secondary
                      : active
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline;
                  final fg = Theme.of(context).colorScheme.onSurface;
                  final remainingLabel = _formatHMSSigned(t.remainingSeconds);
                  final originalHMS = _formatHMS(t.totalSeconds);
                  final status = t.completed
                      ? 'Completed: $originalHMS.'
                      : t.paused
                          ? 'Paused: $remainingLabel of $originalHMS.'
                          : active
                              ? 'Active — $remainingLabel of $originalHMS.'
                              : 'Counting down — $remainingLabel of $originalHMS.';
                  return GestureDetector(
                    onTap: () {
                      setState(() => _activeTimerId = t.id);
                    },
                    child: AnimatedOpacity(
                      opacity: t.completed ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 500),
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(
                            bottom: DesignTokens.spacingSm),
                        padding: const EdgeInsets.symmetric(
                            horizontal: DesignTokens.spacingLg,
                            vertical: DesignTokens.spacingSm),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius:
                              BorderRadius.circular(DesignTokens.radiusMd),
                          border: Border.all(color: borderColor, width: 2),
                        ),
                        child: Row(
                          children: [
                            AnimatedBuilder(
                              animation: _pulseCtl,
                              builder: (context, _) {
                                final base = _pulseBaseColor ?? borderColor;
                                final alert = _pulseAlertColor ??
                                    Theme.of(context).colorScheme.error;
                                final total =
                                    t.totalSeconds <= 0 ? 1 : t.totalSeconds;
                                final frac = t.remainingSeconds / total;
                                final th = _pulseThresholdPercent / 100.0;
                                final activePulse =
                                    !t.completed && !t.paused && frac <= th;
                                if (!activePulse) {
                                  return Icon(Icons.timer, color: base);
                                }
                                final activation =
                                    ((th - frac) / th).clamp(0.0, 1.0);
                                final freq =
                                    1.0 + activation * (_pulseMaxFreq - 1.0);
                                final wave = 0.5 +
                                    0.5 *
                                        math.sin(2 *
                                            math.pi *
                                            (_pulseCtl.value * freq));
                                final col = Color.lerp(base, alert,
                                    (wave * activation).clamp(0.0, 1.0))!;
                                final scale = 1.0 + 0.12 * activation * wave;
                                return Transform.scale(
                                  scale: scale,
                                  child: Icon(Icons.timer, color: col),
                                );
                              },
                            ),
                            const SizedBox(width: DesignTokens.spacingSm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Timer set for $originalHMS.',
                                      style: TextStyle(color: fg)),
                                  const SizedBox(
                                      height: DesignTokens.spacingXs),
                                  Row(
                                    children: [
                                      Expanded(
                                          child: Text(status,
                                              style: TextStyle(color: fg))),
                                      if (active)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(left: 8.0),
                                          child: NpChip(
                                              label: 'Active', selected: true),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: DesignTokens.spacingSm),
                            if (!t.completed)
                              Row(
                                children: [
                                  NpButton(
                                    label: t.paused ? 'Resume' : 'Pause',
                                    icon: t.paused
                                        ? Icons.play_arrow
                                        : Icons.pause,
                                    type: NpButtonType.secondary,
                                    onPressed: () {
                                      setState(() {
                                        if (t.paused) {
                                          t.paused = false;
                                          _activeTimerId = t.id;
                                          t.completed = false;
                                          t.target = DateTime.now().add(
                                              Duration(
                                                  seconds: t.remainingSeconds));
                                          _appendAssistant(
                                              'Timer resumed. Counting down from ${_formatExactDuration(t.remainingSeconds)}.');
                                        } else {
                                          t.paused = true;
                                          _appendAssistant(
                                              'Timer paused with ${_formatExactDuration(t.remainingSeconds)} remaining.');
                                        }
                                      });
                                    },
                                  ),
                                  const SizedBox(width: DesignTokens.spacingXs),
                                  NpButton(
                                    label: 'Cancel',
                                    icon: Icons.cancel,
                                    type: NpButtonType.secondary,
                                    onPressed: () {
                                      setState(() {
                                        _timers
                                            .removeWhere((x) => x.id == t.id);
                                        if (_activeTimerId == t.id) {
                                          _activeTimerId = _timers.isNotEmpty
                                              ? _timers.last.id
                                              : null;
                                        }
                                      });
                                      _appendAssistant('Timer cancelled.');
                                    },
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(DesignTokens.spacingLg),
              itemCount: _messages.length,
              itemBuilder: (ctx, i) {
                final m = _messages[i];
                final align = m.role == 'user'
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start;
                final bg = m.role == 'user'
                    ? Theme.of(ctx).colorScheme.primary
                    : Theme.of(ctx).colorScheme.surface;
                final fg = m.role == 'user'
                    ? DesignTokens.onPrimary
                    : Theme.of(ctx).colorScheme.onSurface;
                return Column(
                  crossAxisAlignment: align,
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(
                          vertical: DesignTokens.spacingSm),
                      padding: const EdgeInsets.symmetric(
                          horizontal: DesignTokens.spacingLg,
                          vertical: DesignTokens.spacingSm),
                      decoration: BoxDecoration(
                          color: bg,
                          borderRadius:
                              BorderRadius.circular(DesignTokens.radiusMd)),
                      child: Text(m.content, style: TextStyle(color: fg)),
                    ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(DesignTokens.spacingLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.suggestionsLabel,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: DesignTokens.spacingSm),
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
                        label: l.suggestReduce,
                        onTap: () => _setInput(l.exampleReduce)),
                    NpChip(
                        label: l.suggestEnergyMatch,
                        onTap: () => _setInput(l.exampleEnergyMatch)),
                    NpChip(
                        label: l.suggestCapture,
                        onTap: () => _setInput(l.exampleCapture)),
                    NpChip(
                      label: '🚨 Doom Scroll Rescue',
                      onTap: () => _triggerDoomScrollRescue(),
                      selected: true,
                    ),
                    ..._dynamicSuggestions
                        .map((s) => NpChip(label: s, onTap: () => _setInput(s)))
                        .toList(),
                  ],
                ),
                const SizedBox(height: DesignTokens.spacingSm),
                Row(
                  children: [
                    Expanded(
                      child: NpTextField(
                          controller: _input,
                          label: _voiceMode
                              ? l.voiceModeLabel
                              : l.typeMessageLabel),
                    ),
                    const SizedBox(width: DesignTokens.spacingSm),
                    NpButton(
                      label: _voiceMode ? l.recordLabel : l.sendLabel,
                      icon: _voiceMode ? Icons.mic : Icons.send,
                      type: NpButtonType.primary,
                      loading: _loading,
                      onPressed: () async {
                        if (_voiceMode) {
                          if (_speech.supported) {
                            setState(() {
                              _engaged.add('SpeechRecognition');
                              _listening = true;
                            });
                            _partialSub?.cancel();
                            _partialSub = _speech.partialUpdates.listen((s) {
                              setState(() => _partialText = s);
                            });
                            final t = await _speech.startOnce();
                            final lastPartial = _partialText;
                            _partialSub?.cancel();
                            final candidate = (t != null && t.trim().isNotEmpty)
                                ? t.trim()
                                : (lastPartial.trim().isNotEmpty
                                    ? lastPartial.trim()
                                    : '');
                            final finalText = _formatTranscript(candidate);
                            setState(() {
                              _engaged.remove('SpeechRecognition');
                              _listening = false;
                              _partialText = '';
                            });
                            if (finalText.isNotEmpty) {
                              _input.text = finalText;
                              await _handleSubmit(api, isVoice: true);
                            } else {
                              NpSnackbar.show(context,
                                  'Voice recognition failed. Please check microphone permissions and try again. Check browser console for details.',
                                  type: NpSnackType.warning);
                            }
                          } else {
                            NpSnackbar.show(context,
                                'Voice recording not supported on this device/browser.',
                                type: NpSnackType.destructive);
                          }
                          return;
                        }
                        await _handleSubmit(api);
                      },
                    ),
                    const SizedBox(width: DesignTokens.spacingSm),
                    NpButton(
                      label: l.voiceToggleLabel,
                      icon: _voiceMode ? Icons.keyboard : Icons.mic,
                      type: NpButtonType.secondary,
                      onPressed: () => setState(() => _voiceMode = !_voiceMode),
                    ),
                  ],
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
  }

  String _formatTranscript(String s) {
    final t = s.trim();
    if (t.isEmpty) return '';
    final endsPunct = t.endsWith('.') || t.endsWith('!') || t.endsWith('?');
    if (endsPunct) return t;
    final lower = t.toLowerCase();
    const starters = [
      'who', 'what', 'when', 'where', 'why', 'how',
      'can', 'could', 'would', 'should', 'is', 'are',
      'do', 'did', 'will', 'might', 'may', 'shall', 'have', 'has'
    ];
    final isQuestion = starters.any((w) => lower.startsWith('$w '));
    return isQuestion ? '$t?' : t;
  }

  void _triggerDoomScrollRescue() async {
    // Manual trigger - user clicked the rescue button
    debugPrint("Manual doom scroll rescue triggered");
    await _triggerJustInTimePrompt(0); // 0 seconds means manual trigger
  }

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
    }
  }

  Intent _inferIntent(String q) {
    final s = q.toLowerCase();
    if (s.contains('health') || s.contains('status')) return Intent.health;
    if (s.contains('atomize')) return Intent.atomize;
    if (s.contains('schedule')) return Intent.schedule;
    if (s.contains('countdown') || s.contains('timer') || s.contains('iso'))
      return Intent.countdown;
    if (s.contains('reduce') || s.contains('decide')) return Intent.reduce;
    if (s.contains('energy')) return Intent.energyMatch;
    if (s.contains('capture') || s.contains('voice'))
      return Intent.externalCapture;
    if (s.contains('appointment') ||
        s.contains('calendar') ||
        s.contains('event')) return Intent.calendarToday;
    if (s == 'help' || s.contains('help') || s.contains('commands'))
      return Intent.help;
    if (s.contains('overview') ||
        s.contains('today') ||
        s.contains('planned') ||
        s.contains('plans')) return Intent.overview;
    if (s.contains('sessions') || s.contains('yesterday'))
      return Intent.sessions;
    return Intent.unknown;
  }

  void _startProactiveCheckins() {
    setState(() {
      _sessionDurationMinutes = 0;
      _lastActivityTime = DateTime.now();
    });
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

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _lastActivityTime = DateTime.now();

    _inactivityTimer = Timer(Duration(seconds: _checkInIntervalSeconds), () {
      debugPrint(
          "Inactivity timer fired after $_checkInIntervalSeconds seconds!");
      _checkInProactive();
    });
  }

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
      _disengage('Proactive Check-in');

      final reply = (r['text'] as String?) ?? '';
      final tools = r['tools'] as List<dynamic>? ?? [];

      // Handle tool outputs - display check-in message
      for (var t in tools) {
        if (t is Map && t.containsKey('check_in')) {
          final prompt = t['prompt'] as String;
          _appendAssistant(prompt);
        }
      }

      if (reply.isNotEmpty && tools.isEmpty) {
        _appendAssistant(reply);
      }
    } catch (e) {
      debugPrint("Check-in failed: $e");
    } finally {
      _resetInactivityTimer();
    }
  }

  void _startCountdown(String timerId, String targetIso) {
    final target = DateTime.parse(targetIso);
    final now = DateTime.now();
    final diff = target.difference(now);
    if (diff.isNegative) return;

    final total = diff.inSeconds;
    final item = _TimerItem(
      id: timerId,
      target: target,
      totalSeconds: total,
      remainingSeconds: total,
    );
    setState(() {
      _timers.add(item);
      _activeTimerId = timerId;
    });

    _appendAssistant(
        'Timer set for ${_formatExactDuration(total)}. Counting down now.');

    if (_timerTicker == null) {
      _timerTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_timers.isEmpty) {
          _timerTicker?.cancel();
          _timerTicker = null;
          return;
        }
        setState(() {
          final nowTick = DateTime.now();
          for (final t in _timers) {
            if (!t.paused && !t.completed) {
              final rem = t.target.difference(nowTick).inSeconds;
              t.remainingSeconds = rem < 0 ? 0 : rem;
              if (t.remainingSeconds <= 0) {
                t.completed = true;
                t.completedAt = DateTime.now();
                _appendAssistant('Timer completed.');
              }
            }
          }
          _timers.removeWhere((x) =>
              x.completed &&
              x.completedAt != null &&
              DateTime.now().difference(x.completedAt!).inMilliseconds > 700);
        });
      });
    }
  }

  Future<void> _handleSubmit(ApiClient api,
      {bool isVoice = false, String? textOverride}) async {
    final text = textOverride ?? _input.text.trim();
    if (text.isEmpty) return;

    // Reset inactivity timer on user interaction
    _resetInactivityTimer();

    setState(() {
      _messages.add(ChatMessage(role: 'user', content: text));
      _loading = true;
    });
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
          } else {
            for (final q in queries) {
              final r = await api.createCountdown(q);
              final target = r['target'] as String?;
              final id = r['timer_id'] as String?;
              if (target == null || id == null) {
                throw 'Timer creation failed.';
              }
              _startCountdown(id, target);
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
      final rr = await api.chatRespond(text);
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
        if (toolsList.isNotEmpty) {
          // Filter out internal tool data from display if it's just the mode switch
          final displayTools = toolsList
              .where((t) => !(t is Map &&
                  (t.containsKey('ui_mode') || t['mode'] == 'stop')))
              .toList();
          if (displayTools.isNotEmpty || reply.isNotEmpty) {
            _appendAssistant(
                '${reply.isNotEmpty ? reply + "\n" : ''}${displayTools.isNotEmpty ? "Tools: $displayTools" : ""}');
          }
        } else {
          _appendAssistant(reply);
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
          final lines = notes.map((e) => '- ${(e as Map<String,dynamic>)['title'] ?? 'Untitled'}').join('\n');
          _appendAssistant('External Brain captured. Task: ${r['task_id']}\nNotes:\n$lines');
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
            final r = await api.chatCommand(text);
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
      NpSnackbar.show(context, '$e', type: NpSnackType.destructive);
      _appendAssistant('Error: $e');
    } finally {
      setState(() => _loading = false);
      _input.clear();
    }
  }

  void _appendAssistant(String content) {
    setState(() {
      _messages.add(ChatMessage(role: 'assistant', content: content));
    });
  }

  void _engage(String name) {
    setState(() => _engaged.add(name));
  }

  void _disengage(String name) {
    setState(() => _engaged.remove(name));
  }

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
          if (unit.startsWith('s'))
            secs = n;
          else if (unit.startsWith('m'))
            secs = n * 60;
          else
            secs = n * 3600;
        }
      }
      return _TimerParseResult(_TimerAction.create,
          seconds: secs, additional: s.contains('another'));
    }
    return _TimerParseResult(_TimerAction.unknown);
  }

  String _formatHMS(int seconds) {
    if (seconds < 0) seconds = -seconds;
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatHMSSigned(int seconds) {
    final sign = seconds < 0 ? '-' : '';
    return '$sign${_formatHMS(seconds)}';
  }

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

  @override
  void initState() {
    super.initState();

    // Observe app lifecycle for Just-in-Time Prompts on mobile
    WidgetsBinding.instance.addObserver(this);

    // Auto-start proactive check-ins
    _startProactiveCheckins();

    // Ping backend health on startup to reflect connectivity in UI
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadPulsePrefs();
      await _pingBackend();
      _heartbeat?.cancel();
      _heartbeat = Timer.periodic(const Duration(seconds: 10), (_) async {
        await _pingBackend();
      });
    });
    _pulseCtl = AnimationController(
        vsync: this, duration: Duration(milliseconds: _pulseSpeedMs))
      ..repeat(reverse: true);
    _pulseScale = Tween<double>(begin: 0.9, end: 1.15)
        .animate(CurvedAnimation(parent: _pulseCtl, curve: Curves.easeInOut));
  }

  Future<void> _loadPulsePrefs() async {
    final p = await SharedPreferences.getInstance();
    final speed = p.getInt('pulse_speed_ms');
    final th = p.getInt('pulse_threshold_percent');
    final freq = p.getDouble('pulse_max_freq');
    final base = p.getInt('pulse_base_color');
    final alert = p.getInt('pulse_alert_color');
    setState(() {
      if (speed != null) _pulseSpeedMs = speed;
      if (th != null) _pulseThresholdPercent = th;
      if (freq != null) _pulseMaxFreq = freq;
      _pulseBaseColor = base != null ? Color(base) : null;
      _pulseAlertColor = alert != null ? Color(alert) : null;
      _pulseCtl.duration = Duration(milliseconds: _pulseSpeedMs);
      _pulseCtl.repeat(reverse: true);
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
    final api = ref.read(apiClientProvider);
    try {
      final r = await api.health();
      setState(() => _backendOk = r['ok'] == true);
    } catch (_) {
      setState(() => _backendOk = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeat?.cancel();
    _pulseCtl.dispose();
    _partialSub?.cancel();
    _sessionTimer?.cancel();
    _inactivityTimer?.cancel();
    super.dispose();
  }
}
