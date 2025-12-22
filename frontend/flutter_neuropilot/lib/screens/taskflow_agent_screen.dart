import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:flutter_animate/flutter_animate.dart'; // For animations
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/body_doubling_service.dart';
import '../core/cloud_stt_service.dart';
import '../core/speech_service.dart';
import '../state/session_state.dart';
import '../state/user_settings_store.dart';
import '../core/components/agent_widgets.dart';

class TaskFlowAgentScreen extends ConsumerStatefulWidget {
  const TaskFlowAgentScreen({super.key});

  @override
  ConsumerState<TaskFlowAgentScreen> createState() =>
      _TaskFlowAgentScreenState();
}

class _TaskFlowAgentScreenState extends ConsumerState<TaskFlowAgentScreen> {
  final TextEditingController _taskController = TextEditingController();

  final SpeechService _speech = createSpeechService();
  StreamSubscription<String>? _speechPartialSub;
  StreamSubscription<double>? _speechLevelSub;
  Timer? _cloudAmpTimer;
  int _sttSessionId = 0;
  bool _isListening = false;
  double _soundLevel = 0.0;
  String _partialTranscript = '';
  String? _sttError;
  String? _activeSttProvider;

  bool _isAtomizing = false;
  String? _atomizeError;
  List<String> _microSteps = const [];
  final Set<int> _completedSteps = {};
  bool _showCelebration = false;
  int _streak = 0;
  String? _dopamineHack;
  int? _estimatedMinutes;
  int _atomizeRequestId = 0;
  String? _lastAtomizedDescription;

  Future<void> _showBodyDoubleConfigDialog() async {
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
              _buildModeOption(
                icon: Icons.timer_outlined,
                title: "Focus Assistance",
                subtitle: "Frequent check-ins (5m)",
                mode: BodyDoublingMode.focusAssistance,
              ),
              const SizedBox(height: 12),
              _buildModeOption(
                icon: Icons.people_outline,
                title: "Accountability",
                subtitle: "Progress updates (15m)",
                mode: BodyDoublingMode.accountability,
              ),
              const SizedBox(height: 12),
              _buildModeOption(
                icon: Icons.monitor_heart_outlined,
                title: "Productivity Tracking",
                subtitle: "Silent monitoring",
                mode: BodyDoublingMode.productivityTracking,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
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

  Widget _buildModeOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required BodyDoublingMode mode,
  }) {
    return InkWell(
      onTap: () {
        ref.read(bodyDoublingServiceProvider.notifier).startSession(
              mode,
              task: _taskController.text.isNotEmpty
                  ? _taskController.text
                  : "current task",
            );
        Navigator.pop(context);
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

  Future<void> _showCheckInDialog(String message) async {
    final responseController = TextEditingController();
    await showDialog(
      context: context,
      barrierDismissible: false,
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
              Row(
                children: [
                  const Icon(Icons.notifications_active,
                      color: Color(0xFFE2B58D)),
                  const SizedBox(width: 12),
                  Text(
                    "Check-in",
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: responseController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "I'm working on...",
                  hintStyle:
                      TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      ref
                          .read(bodyDoublingServiceProvider.notifier)
                          .dismissCheckIn();
                      Navigator.pop(context);
                    },
                    child: Text(
                      "Dismiss",
                      style:
                          TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      ref
                          .read(bodyDoublingServiceProvider.notifier)
                          .respondToCheckIn(responseController.text);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE2B58D),
                      foregroundColor: Colors.black,
                    ),
                    child: const Text("Reply"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cloudAmpTimer?.cancel();
    try {
      _speechPartialSub?.cancel();
      _speechLevelSub?.cancel();
    } catch (_) {}
    _speech.stop();
    _taskController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep Cloud STT service alive while screen is mounted
    ref.watch(cloudSttServiceProvider);

    // Listen for check-in messages
    ref.listen(bodyDoublingServiceProvider, (prev, next) {
      if (next.pendingCheckInMessage != null &&
          !next.isWaitingForResponse &&
          next.pendingCheckInMessage != prev?.pendingCheckInMessage) {
        // Just a notification
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 15),
            content: Text(
              next.pendingCheckInMessage!,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: const Color(0xFF1A1A1A),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: const Color(0xFFE2B58D),
              onPressed: () {
                ref.read(bodyDoublingServiceProvider.notifier).dismissCheckIn();
              },
            ),
          ),
        );
      } else if (next.pendingCheckInMessage != null &&
          next.isWaitingForResponse) {
        // Needs a dialog response
        _showCheckInDialog(next.pendingCheckInMessage!);
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0F0505),
      body: Stack(
        children: [
          // Background Gradient Orbs
          Positioned(
            top: -100,
            right: -100,
            child: _GradientOrb(
              color: const Color(0xFF683A32).withValues(alpha: 0.5),
              size: 500,
            ),
          ),
          Positioned(
            bottom: -50,
            left: -100,
            child: _GradientOrb(
              color: const Color(0xFF6C7494).withValues(alpha: 0.3),
              size: 600,
            ),
          ),

          // Main Content
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        _buildBodyDoublingToggle(),
                        const SizedBox(height: 32),
                        Text(
                          "What's on your mind?",
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildTaskInput(),
                        const SizedBox(height: 24),
                        _buildAtomizeButton(),
                        const SizedBox(height: 40),
                        _buildMicroStepsHeader(),
                        const SizedBox(height: 20),
                        _buildTaskList(),
                        const SizedBox(height: 40),
                        if (!_showCelebration)
                          Center(
                            child: GlassContainer(
                              borderRadius: BorderRadius.circular(50),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 14),
                              color: const Color(0xFF0F0505)
                                  .withValues(alpha: 0.6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.favorite,
                                      color: Color(0xFFE2B58D), size: 20),
                                  const SizedBox(width: 12),
                                  Text(
                                    "One step at a time. You're doing great.",
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Floating Motivational Message
          // if (!_showCelebration)
          //   Align(
          //     alignment: Alignment.bottomCenter,
          //     child: Padding(
          //       padding: const EdgeInsets.only(bottom: 24),
          //       child: GlassContainer(
          //         borderRadius: BorderRadius.circular(50),
          //         padding:
          //             const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          //         color: const Color(0xFF0F0505).withValues(alpha: 0.6),
          //         child: Row(
          //           mainAxisSize: MainAxisSize.min,
          //           children: [
          //             const Icon(Icons.favorite,
          //                 color: Color(0xFFE2B58D), size: 20),
          //             const SizedBox(width: 12),
          //             Text(
          //               "One step at a time. You're doing great.",
          //               style: GoogleFonts.inter(
          //                 color: Colors.white.withValues(alpha: 0.9),
          //                 fontSize: 14,
          //                 fontWeight: FontWeight.w500,
          //               ),
          //             ),
          //           ],
          //         ),
          //       ),
          //     ),
          //   ),

          // Celebration Overlay
          if (_showCelebration)
            _TaskCompletionOverlay(
              streak: _streak,
              onStartNew: _resetTask,
              onTakeBreak: _takeBreak,
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon:
                const Icon(Icons.chevron_left, color: Colors.white70, size: 28),
          ),
          Text(
            "TASKFLOW AGENT",
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          GlassContainer(
            borderRadius: BorderRadius.circular(50),
            padding: const EdgeInsets.all(8),
            child:
                const Icon(Icons.smart_toy_outlined, color: Color(0xFFE2B58D)),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyDoublingToggle() {
    final bodyDoubleState = ref.watch(bodyDoublingServiceProvider);
    final isActive = bodyDoubleState.isActive;
    final mode = bodyDoubleState.mode;

    String modeText = "Body-Doubling Mode";
    String subText = "Visual presence support";

    if (isActive) {
      final duration = bodyDoubleState.sessionDuration;
      final minutes = duration.inMinutes;
      switch (mode) {
        case BodyDoublingMode.focusAssistance:
          modeText = "Focus Partner Active";
          subText = "Time: ${minutes}m • Checking every ~5m";
          break;
        case BodyDoublingMode.accountability:
          modeText = "Accountability Mode";
          subText = "Time: ${minutes}m • Updates every ~15m";
          break;
        case BodyDoublingMode.productivityTracking:
          modeText = "Productivity Tracker";
          subText = "Time Focused: ${minutes}m";
          break;
      }
    }

    return GlassContainer(
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(20),
      isActive: isActive,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF6C7494).withValues(alpha: 0.2),
                  Colors.transparent
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white10),
            ),
            child: Icon(Icons.group_outlined,
                color: isActive ? Colors.white : const Color(0xFFE2B58D)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  modeText,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  subText,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isActive,
            activeThumbColor: const Color(0xFFE2B58D),
            activeTrackColor: const Color(0xFFE2B58D).withValues(alpha: 0.3),
            onChanged: (val) {
              if (val) {
                _showBodyDoubleConfigDialog();
              } else {
                ref.read(bodyDoublingServiceProvider.notifier).stopSession();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTaskInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            TextField(
              controller: _taskController,
              maxLines: 5,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 18),
              onChanged: (_) {
                final currentText = _taskController.text.trim();
                if (_lastAtomizedDescription != null &&
                    currentText != _lastAtomizedDescription &&
                    !_isAtomizing &&
                    _microSteps.isNotEmpty) {
                  setState(() {
                    _microSteps = const [];
                    _completedSteps.clear();
                    _estimatedMinutes = null;
                    _dopamineHack = null;
                  });
                }
                if (_atomizeError != null || _sttError != null) {
                  setState(() {
                    _atomizeError = null;
                    _sttError = null;
                  });
                }
              },
              decoration: InputDecoration(
                hintText: "Describe the task that feels stuck...",
                hintStyle:
                    TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Colors.white12),
                ),
                contentPadding: const EdgeInsets.all(20),
              ),
            ),
            Positioned(
              bottom: 12,
              right: 12,
              child: GestureDetector(
                onTap: _toggleListening,
                child: GlassContainer(
                  borderRadius: BorderRadius.circular(50),
                  padding: const EdgeInsets.all(8),
                  color: _isListening
                      ? Colors.white
                          .withValues(alpha: 0.04 + (0.08 * _soundLevel))
                      : null,
                  child: Icon(
                    _isListening ? Icons.stop : Icons.mic,
                    color: _isListening
                        ? Colors.white.withValues(alpha: 0.9)
                        : const Color(0xFFE2B58D),
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_isListening || _partialTranscript.isNotEmpty || _sttError != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              _sttError ??
                  (_partialTranscript.isNotEmpty
                      ? _partialTranscript
                      : "Listening..."),
              style: GoogleFonts.inter(
                color: _sttError != null
                    ? Colors.white.withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAtomizeButton() {
    final isDisabled = _isAtomizing;

    return GestureDetector(
      onTap: isDisabled ? null : _atomizeTask,
      child: Opacity(
        opacity: isDisabled ? 0.7 : 1.0,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE2B58D), Color(0xFFDCB08A)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE2B58D).withValues(alpha: 0.25),
                blurRadius: 25,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isAtomizing) ...[
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(Color(0xFF0F0505)),
                  ),
                ),
              ] else ...[
                const Icon(Icons.auto_awesome,
                    color: Color(0xFF0F0505), size: 20),
              ],
              const SizedBox(width: 8),
              Text(
                _isAtomizing ? "Atomizing..." : "Atomize Task",
                style: GoogleFonts.inter(
                  color: const Color(0xFF0F0505),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMicroStepsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "MICRO-STEPS",
          style: GoogleFonts.inter(
            color: const Color(0xFF6C7494),
            letterSpacing: 1.5,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFFE2B58D),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "In Progress",
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTaskList() {
    if (_atomizeError != null) {
      return GlassContainer(
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Text(
          _atomizeError!,
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 13,
            height: 1.35,
          ),
        ),
      );
    }

    if (_microSteps.isEmpty) {
      return GlassContainer(
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Text(
          "Atomize a task to get micro-steps.",
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 13,
          ),
        ),
      );
    }

    return TaskChecklist(
      steps: _microSteps,
      completedSteps: _completedSteps,
      onToggleStep: _toggleStep,
      estimatedMinutes: _estimatedMinutes,
      dopamineHack: _dopamineHack,
    );
  }

  void _toggleStep(int index) {
    setState(() {
      if (_completedSteps.contains(index)) {
        _completedSteps.remove(index);
      } else {
        _completedSteps.add(index);
        HapticFeedback.lightImpact(); // Tactile feedback for each step

        // Check if all steps are completed
        if (_completedSteps.length == _microSteps.length &&
            _microSteps.isNotEmpty) {
          _triggerCelebration();
        }
      }
    });

    // Update Body Doubling Context with new active step
    // Find the first step that is NOT completed
    int firstIncompleteIndex = -1;
    for (int i = 0; i < _microSteps.length; i++) {
      if (!_completedSteps.contains(i)) {
        firstIncompleteIndex = i;
        break;
      }
    }

    final activeStep =
        firstIncompleteIndex != -1 ? _microSteps[firstIncompleteIndex] : null;

    ref
        .read(bodyDoublingServiceProvider.notifier)
        .updateMicroSteps(_microSteps, activeStep);
  }

  void _triggerCelebration() {
    HapticFeedback.mediumImpact();
    // Small delay to let the checkmark animation finish before showing overlay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _showCelebration = true;
          _streak++;
        });
        HapticFeedback.heavyImpact();
      }
    });
  }

  void _resetTask() {
    setState(() {
      _showCelebration = false;
      _microSteps = const [];
      _completedSteps.clear();
      _estimatedMinutes = null;
      _dopamineHack = null;
      _taskController.clear();
      _lastAtomizedDescription = null;
    });
  }

  void _takeBreak() {
    setState(() => _showCelebration = false);
    // Could navigate to a break screen or breathing exercise here
    // For now, just close overlay
  }

  Future<void> _atomizeTask() async {
    final description = _taskController.text.trim();
    if (description.isEmpty) {
      setState(() => _atomizeError = "Add a short description first.");
      return;
    }

    final requestId = ++_atomizeRequestId;
    setState(() {
      _isAtomizing = true;
      _atomizeError = null;
      _microSteps = const [];
      _completedSteps.clear();
      _estimatedMinutes = null;
      _dopamineHack = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final r = await api.atomizeTask(description);
      if (!mounted || requestId != _atomizeRequestId) return;

      final stepsRaw = r['micro_steps'];
      final steps = (stepsRaw is List)
          ? stepsRaw
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList()
          : <String>[];

      setState(() {
        _lastAtomizedDescription = description;
        _microSteps = steps;
        _estimatedMinutes = r['estimated_time_minutes'] is int
            ? r['estimated_time_minutes'] as int
            : int.tryParse('${r['estimated_time_minutes']}');
        _dopamineHack = r['dopamine_hack']?.toString();
        _isAtomizing = false;
      });
    } catch (e) {
      if (!mounted || requestId != _atomizeRequestId) return;
      setState(() {
        _isAtomizing = false;
        _atomizeError = "Couldn't atomize right now. Try again in a moment.";
      });
    }
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _stopListening();
      return;
    }
    await _startListening();
  }

  Future<void> _startListening() async {
    final settings = ref.read(userSettingsProvider);
    final sessionId = ++_sttSessionId;

    setState(() {
      _isListening = true;
      _soundLevel = 0.0;
      _partialTranscript = '';
      _sttError = null;
      _activeSttProvider = settings.sttProvider;
    });

    if (settings.sttProvider == 'cloud') {
      final cloudStt = ref.read(cloudSttServiceProvider);
      try {
        await cloudStt.startRecording();
      } catch (_) {
        if (!mounted || sessionId != _sttSessionId) return;
        setState(() {
          _isListening = false;
          _sttError = "Microphone not available.";
        });
        return;
      }

      _cloudAmpTimer?.cancel();
      int silenceMs = 0;
      final startTime = DateTime.now();

      _cloudAmpTimer =
          Timer.periodic(const Duration(milliseconds: 100), (timer) async {
        if (!mounted || sessionId != _sttSessionId) {
          timer.cancel();
          return;
        }
        if (!_isListening) {
          timer.cancel();
          return;
        }
        final amp = await cloudStt.getAmplitude();
        double level = (amp + 60) / 60;
        if (level < 0) level = 0;
        if (level > 1) level = 1;

        if (mounted && sessionId == _sttSessionId) {
          setState(() => _soundLevel = level);
        }

        if (level < 0.05) {
          silenceMs += 100;
        } else {
          silenceMs = 0;
        }

        if (silenceMs > 2500 &&
            DateTime.now().difference(startTime).inSeconds > 1) {
          timer.cancel();
          if (!mounted) return;
          final transcript = await cloudStt.stopAndTranscribe();
          if (!mounted || sessionId != _sttSessionId) return;
          _applyTranscript(transcript, sessionId);
        }
      });

      return;
    }

    _speechPartialSub?.cancel();
    _speechLevelSub?.cancel();
    _speechPartialSub = _speech.partialUpdates.listen((t) {
      if (!mounted || sessionId != _sttSessionId) return;
      final trimmed = t.trim();
      if (trimmed.isEmpty) return;
      setState(() => _partialTranscript = trimmed);
    });
    _speechLevelSub = _speech.levelUpdates.listen((lvl) {
      if (!mounted || sessionId != _sttSessionId) return;
      setState(() => _soundLevel = lvl);
    });

    final transcript = await _speech.startOnce();
    if (!mounted || sessionId != _sttSessionId) return;
    _applyTranscript(transcript, sessionId);
  }

  Future<void> _stopListening() async {
    final sessionId = _sttSessionId;
    _cloudAmpTimer?.cancel();
    _cloudAmpTimer = null;
    try {
      _speechPartialSub?.cancel();
      _speechLevelSub?.cancel();
    } catch (_) {}
    if (_activeSttProvider == 'cloud') {
      try {
        final cloudStt = ref.read(cloudSttServiceProvider);
        await cloudStt.stopAndTranscribe();
      } catch (_) {}
    } else {
      await _speech.stop();
    }

    if (!mounted || sessionId != _sttSessionId) return;
    setState(() {
      _isListening = false;
      _soundLevel = 0.0;
      _partialTranscript = '';
      _activeSttProvider = null;
    });
  }

  void _applyTranscript(String? transcript, int sessionId) {
    if (!mounted || sessionId != _sttSessionId) return;

    final t = transcript?.trim() ?? '';
    if (t.isEmpty) {
      setState(() {
        _isListening = false;
        _soundLevel = 0.0;
        _partialTranscript = '';
        _sttError = "Didn't catch that. Tap the mic to try again.";
        _activeSttProvider = null;
      });
      return;
    }

    final current = _taskController.text;
    final newText = current.trim().isEmpty
        ? t
        : (current.endsWith('\n') || current.endsWith(' ')
            ? '$current$t'
            : '$current\n$t');

    _taskController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );

    setState(() {
      _isListening = false;
      _soundLevel = 0.0;
      _partialTranscript = '';
      _sttError = null;
      _activeSttProvider = null;
    });
  }
}

class _GradientOrb extends StatelessWidget {
  final Color color;
  final double size;

  const _GradientOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

class _TaskCompletionOverlay extends StatelessWidget {
  final int streak;
  final VoidCallback onStartNew;
  final VoidCallback onTakeBreak;

  const _TaskCompletionOverlay({
    required this.streak,
    required this.onStartNew,
    required this.onTakeBreak,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Backdrop Blur
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.black.withValues(alpha: 0.7)),
          ),
        ).animate().fadeIn(duration: 400.ms),

        // Celebration Content
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Glowing Checkmark
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE2B58D).withValues(alpha: 0.2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE2B58D).withValues(alpha: 0.4),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                  border: Border.all(
                    color: const Color(0xFFE2B58D).withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.check,
                  size: 60,
                  color: Color(0xFFE2B58D),
                ),
              )
                  .animate()
                  .scale(
                      duration: 600.ms,
                      curve: Curves.elasticOut,
                      begin: const Offset(0.5, 0.5))
                  .then()
                  .shimmer(duration: 1200.ms, color: Colors.white54),

              const SizedBox(height: 32),

              // Title
              Text(
                "Task\nComplete!",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.1,
                  shadows: [
                    Shadow(
                      color: const Color(0xFFE2B58D).withValues(alpha: 0.5),
                      blurRadius: 20,
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(delay: 200.ms, duration: 500.ms)
                  .slideY(begin: 0.2, end: 0),

              const SizedBox(height: 40),

              // Action Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      "You conquered it!",
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Dopamine boost received. What's next?",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFF6C7494),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Streak Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2B58D).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color:
                                const Color(0xFFE2B58D).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text("🔥", style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Text(
                            "$streak Task Streak",
                            style: GoogleFonts.inter(
                              color: const Color(0xFFE2B58D),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _ActionButton(
                      label: "Start a New Task",
                      icon: Icons.add_circle_outline,
                      color: const Color(0xFFE2B58D),
                      textColor: const Color(0xFF0F0505),
                      onTap: onStartNew,
                    ),
                    const SizedBox(height: 12),
                    _ActionButton(
                      label: "Take a Break",
                      icon: Icons.coffee_outlined,
                      color: Colors.white10,
                      textColor: Colors.white,
                      onTap: onTakeBreak,
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(delay: 400.ms, duration: 500.ms)
                  .slideY(begin: 0.2, end: 0),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
