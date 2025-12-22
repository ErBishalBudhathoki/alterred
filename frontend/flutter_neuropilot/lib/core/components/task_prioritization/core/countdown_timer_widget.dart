import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'task_priority_animations.dart';

/// Reusable countdown timer widget with multiple display modes
class CountdownTimerWidget extends StatefulWidget {
  final int totalSeconds;
  final bool autoStart;
  final bool enableAutoSelect;
  final VoidCallback? onComplete;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onReset;
  final CountdownDisplayMode displayMode;
  final CountdownSize size;
  final String? customLabel;
  final bool showControls;
  final CountdownTimerController? controller;

  const CountdownTimerWidget({
    super.key,
    required this.totalSeconds,
    this.autoStart = false,
    this.enableAutoSelect = false,
    this.onComplete,
    this.onPause,
    this.onResume,
    this.onReset,
    this.displayMode = CountdownDisplayMode.compact,
    this.size = CountdownSize.medium,
    this.customLabel,
    this.showControls = true,
    this.controller,
  });

  @override
  State<CountdownTimerWidget> createState() => _CountdownTimerWidgetState();
}

class _CountdownTimerWidgetState extends State<CountdownTimerWidget>
    with TickerProviderStateMixin {
  late int _remainingSeconds;
  Timer? _timer;
  bool _isRunning = false;
  bool _isPaused = false;
  bool _isCompleted = false;

  late AnimationController _pulseController;
  late AnimationController _progressController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.totalSeconds;
    widget.controller?._attach(this);

    _setupAnimations();

    if (widget.autoStart && widget.enableAutoSelect) {
      _startTimer();
    }
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _progressController = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.totalSeconds),
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _progressAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.linear,
    ));
  }

  @override
  void didUpdateWidget(CountdownTimerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.totalSeconds != oldWidget.totalSeconds) {
      _resetTimer();
    }
  }

  @override
  void dispose() {
    widget.controller?._detach();
    _timer?.cancel();
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _startTimer() {
    if (_isCompleted || _isRunning) return;

    setState(() {
      _isRunning = true;
      _isPaused = false;
    });

    _progressController.forward();
    _pulseController.repeat(reverse: true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _remainingSeconds--;
      });

      if (_remainingSeconds <= 0) {
        _completeTimer();
      } else {
        _updatePulseSpeed();
      }
    });
  }

  void _pauseTimer() {
    if (!_isRunning || _isPaused) return;

    setState(() {
      _isPaused = true;
      _isRunning = false;
    });

    _timer?.cancel();
    _progressController.stop();
    _pulseController.stop();

    widget.onPause?.call();
  }

  void _resumeTimer() {
    if (!_isPaused) return;

    setState(() {
      _isPaused = false;
      _isRunning = true;
    });

    _startTimer();
    widget.onResume?.call();
  }

  void _resetTimer() {
    _timer?.cancel();
    _progressController.reset();
    _pulseController.reset();

    setState(() {
      _remainingSeconds = widget.totalSeconds;
      _isRunning = false;
      _isPaused = false;
      _isCompleted = false;
    });

    widget.onReset?.call();
  }

  void _completeTimer() {
    _timer?.cancel();
    _progressController.stop();
    _pulseController.stop();

    setState(() {
      _remainingSeconds = 0;
      _isRunning = false;
      _isPaused = false;
      _isCompleted = true;
    });

    widget.onComplete?.call();
  }

  void _updatePulseSpeed() {
    final progress = _remainingSeconds / widget.totalSeconds;

    if (progress <= 0.2) {
      // Critical - fast pulse
      _pulseController.duration = const Duration(milliseconds: 300);
    } else if (progress <= 0.5) {
      // Warning - medium pulse
      _pulseController.duration = const Duration(milliseconds: 600);
    } else {
      // Normal - slow pulse
      _pulseController.duration = const Duration(milliseconds: 1000);
    }
  }

  Color _getTimerColor() {
    if (_isCompleted) return const Color(0xFF10B981); // Green

    final progress = _remainingSeconds / widget.totalSeconds;

    if (progress <= 0.2) return const Color(0xFFEF4444); // Red
    if (progress <= 0.5) return const Color(0xFFF97316); // Orange
    return const Color(0xFFE2B58D); // Default
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.displayMode) {
      case CountdownDisplayMode.compact:
        return _buildCompactTimer();
      case CountdownDisplayMode.detailed:
        return _buildDetailedTimer();
      case CountdownDisplayMode.circular:
        return _buildCircularTimer();
      case CountdownDisplayMode.linear:
        return _buildLinearTimer();
      case CountdownDisplayMode.voice:
        return _buildVoiceTimer();
    }
  }

  Widget _buildCompactTimer() {
    return AnimatedCountdown(
      totalSeconds: widget.totalSeconds,
      remainingSeconds: _remainingSeconds,
      isPaused: _isPaused,
      onComplete: widget.onComplete,
    );
  }

  Widget _buildDetailedTimer() {
    final color = _getTimerColor();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Timer display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isCompleted
                    ? Icons.check_circle
                    : _isPaused
                        ? Icons.pause_circle
                        : Icons.timer,
                color: color,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                _isCompleted
                    ? 'Completed!'
                    : _isPaused
                        ? 'Paused'
                        : _formatTime(_remainingSeconds),
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Progress bar
          _buildProgressBar(color),

          if (widget.showControls) ...[
            const SizedBox(height: 12),
            _buildControls(),
          ],
        ],
      ),
    );
  }

  Widget _buildCircularTimer() {
    final color = _getTimerColor();
    final progress = _remainingSeconds / widget.totalSeconds;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _isRunning ? _pulseAnimation.value : 1.0,
          child: SizedBox(
            width: _getSizeValue() * 2,
            height: _getSizeValue() * 2,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background circle
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),

                // Progress circle
                SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: CircularProgressIndicator(
                    value: 1.0 - progress,
                    strokeWidth: 4,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),

                // Center content
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _formatTime(_remainingSeconds),
                      style: GoogleFonts.inter(
                        fontSize: _getSizeValue() * 0.2,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (widget.customLabel != null)
                      Text(
                        widget.customLabel!,
                        style: GoogleFonts.inter(
                          fontSize: _getSizeValue() * 0.1,
                          color: Colors.white70,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLinearTimer() {
    final color = _getTimerColor();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.customLabel ?? 'Auto-select in',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              _formatTime(_remainingSeconds),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildProgressBar(color),
      ],
    );
  }

  Widget _buildVoiceTimer() {
    final color = _getTimerColor();

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _isRunning ? _pulseAnimation.value : 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isCompleted
                      ? Icons.check_circle
                      : _isPaused
                          ? Icons.pause_circle
                          : Icons.timer,
                  color: color,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _isCompleted
                      ? 'Time\'s up!'
                      : _isPaused
                          ? 'Paused'
                          : _formatTime(_remainingSeconds),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressBar(Color color) {
    final progress = _remainingSeconds / widget.totalSeconds;

    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        return Container(
          height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: Colors.white.withValues(alpha: 0.1),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.7)],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildControlButton(
          icon: Icons.refresh,
          onTap: _resetTimer,
          tooltip: 'Reset',
        ),
        _buildControlButton(
          icon: _isRunning
              ? Icons.pause
              : _isPaused
                  ? Icons.play_arrow
                  : Icons.play_arrow,
          onTap: _isRunning
              ? _pauseTimer
              : _isPaused
                  ? _resumeTimer
                  : _startTimer,
          tooltip: _isRunning
              ? 'Pause'
              : _isPaused
                  ? 'Resume'
                  : 'Start',
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: Colors.white70,
          ),
        ),
      ),
    );
  }

  double _getSizeValue() {
    switch (widget.size) {
      case CountdownSize.small:
        return 60;
      case CountdownSize.medium:
        return 80;
      case CountdownSize.large:
        return 120;
    }
  }
}

/// Display modes for the countdown timer
enum CountdownDisplayMode {
  compact, // Minimal badge-style display
  detailed, // Full featured with controls
  circular, // Circular progress indicator
  linear, // Linear progress bar
  voice, // Optimized for voice mode
}

/// Size variants for the countdown timer
enum CountdownSize {
  small,
  medium,
  large,
}

/// Countdown timer controller for external control
class CountdownTimerController {
  _CountdownTimerWidgetState? _state;

  void _attach(_CountdownTimerWidgetState state) {
    _state = state;
  }

  void _detach() {
    _state = null;
  }

  void start() => _state?._startTimer();
  void pause() => _state?._pauseTimer();
  void resume() => _state?._resumeTimer();
  void reset() => _state?._resetTimer();

  bool get isRunning => _state?._isRunning ?? false;
  bool get isPaused => _state?._isPaused ?? false;
  bool get isCompleted => _state?._isCompleted ?? false;
  int get remainingSeconds => _state?._remainingSeconds ?? 0;
}

/// Controlled countdown timer widget
class ControlledCountdownTimer extends StatefulWidget {
  final CountdownTimerController controller;
  final int totalSeconds;
  final CountdownDisplayMode displayMode;
  final CountdownSize size;
  final VoidCallback? onComplete;

  const ControlledCountdownTimer({
    super.key,
    required this.controller,
    required this.totalSeconds,
    this.displayMode = CountdownDisplayMode.compact,
    this.size = CountdownSize.medium,
    this.onComplete,
  });

  @override
  State<ControlledCountdownTimer> createState() =>
      _ControlledCountdownTimerState();
}

class _ControlledCountdownTimerState extends State<ControlledCountdownTimer> {
  @override
  void initState() {
    super.initState();
    // Controller attachment is handled by the CountdownTimerWidget
  }

  @override
  Widget build(BuildContext context) {
    return CountdownTimerWidget(
      totalSeconds: widget.totalSeconds,
      displayMode: widget.displayMode,
      size: widget.size,
      onComplete: widget.onComplete,
    );
  }
}
