import 'package:flutter/material.dart';

/// Shared animation configurations and utilities for task prioritization components
class TaskPriorityAnimations {
  // Animation durations
  static const Duration fastDuration = Duration(milliseconds: 200);
  static const Duration normalDuration = Duration(milliseconds: 300);
  static const Duration slowDuration = Duration(milliseconds: 500);
  static const Duration extraSlowDuration = Duration(milliseconds: 800);

  // Animation curves
  static const Curve defaultCurve = Curves.easeOutCubic;
  static const Curve bounceCurve = Curves.elasticOut;
  static const Curve sharpCurve = Curves.easeInOutQuart;

  // Stagger delays for list animations
  static const Duration staggerDelay = Duration(milliseconds: 100);
  static const Duration shortStaggerDelay = Duration(milliseconds: 50);

  /// Create a staggered animation controller for list items
  static AnimationController createStaggerController({
    required TickerProvider vsync,
    required int itemCount,
    Duration? duration,
  }) {
    return AnimationController(
      vsync: vsync,
      duration: duration ??
          Duration(
            milliseconds: 300 + (itemCount * 100),
          ),
    );
  }

  /// Create entrance animation for a single item
  static Animation<double> createEntranceAnimation({
    required AnimationController controller,
    required int index,
    int totalItems = 3,
  }) {
    final start = (index / totalItems) * 0.6;
    final end = start + 0.4;

    return Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: defaultCurve),
    ));
  }

  /// Create slide animation for entrance
  static Animation<Offset> createSlideAnimation({
    required AnimationController controller,
    required int index,
    int totalItems = 3,
    Offset beginOffset = const Offset(0, 0.3),
  }) {
    final start = (index / totalItems) * 0.6;
    final end = start + 0.4;

    return Tween<Offset>(
      begin: beginOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: defaultCurve),
    ));
  }

  /// Create scale animation for selection feedback
  static Animation<double> createSelectionScaleAnimation({
    required AnimationController controller,
  }) {
    return Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: bounceCurve,
    ));
  }

  /// Create pulse animation for recommended items
  static Animation<double> createPulseAnimation({
    required AnimationController controller,
  }) {
    return Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    ));
  }

  /// Create countdown progress animation
  static Animation<double> createCountdownAnimation({
    required AnimationController controller,
    required Duration totalDuration,
  }) {
    return Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.linear,
    ));
  }

  /// Create shimmer animation for loading states
  static Animation<double> createShimmerAnimation({
    required AnimationController controller,
  }) {
    return Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    ));
  }
}

/// Animated wrapper for task priority components with entrance effects
class AnimatedTaskEntry extends StatefulWidget {
  final Widget child;
  final int index;
  final int totalItems;
  final Duration? delay;
  final bool animate;

  const AnimatedTaskEntry({
    super.key,
    required this.child,
    required this.index,
    this.totalItems = 3,
    this.delay,
    this.animate = true,
  });

  @override
  State<AnimatedTaskEntry> createState() => _AnimatedTaskEntryState();
}

class _AnimatedTaskEntryState extends State<AnimatedTaskEntry>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: TaskPriorityAnimations.extraSlowDuration,
    );

    _fadeAnimation = TaskPriorityAnimations.createEntranceAnimation(
      controller: _controller,
      index: widget.index,
      totalItems: widget.totalItems,
    );

    _slideAnimation = TaskPriorityAnimations.createSlideAnimation(
      controller: _controller,
      index: widget.index,
      totalItems: widget.totalItems,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve:
          const Interval(0.0, 0.6, curve: TaskPriorityAnimations.bounceCurve),
    ));

    if (widget.animate) {
      _startAnimation();
    } else {
      _controller.value = 1.0;
    }
  }

  void _startAnimation() {
    final delay = widget.delay ?? Duration(milliseconds: widget.index * 100);

    Future.delayed(delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}

/// Animated selection feedback wrapper
class AnimatedSelection extends StatefulWidget {
  final Widget child;
  final bool isSelected;
  final VoidCallback? onTap;
  final Duration duration;

  const AnimatedSelection({
    super.key,
    required this.child,
    required this.isSelected,
    this.onTap,
    this.duration = TaskPriorityAnimations.normalDuration,
  });

  @override
  State<AnimatedSelection> createState() => _AnimatedSelectionState();
}

class _AnimatedSelectionState extends State<AnimatedSelection>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: TaskPriorityAnimations.bounceCurve,
    ));

    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: TaskPriorityAnimations.defaultCurve,
    ));

    if (widget.isSelected) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(AnimatedSelection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: widget.isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFFE2B58D)
                              .withValues(alpha: 0.3 * _glowAnimation.value),
                          blurRadius: 20 * _glowAnimation.value,
                          spreadRadius: 2 * _glowAnimation.value,
                        ),
                      ]
                    : null,
              ),
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}

/// Animated countdown timer with visual effects
class AnimatedCountdown extends StatefulWidget {
  final int totalSeconds;
  final int remainingSeconds;
  final bool isPaused;
  final VoidCallback? onComplete;

  const AnimatedCountdown({
    super.key,
    required this.totalSeconds,
    required this.remainingSeconds,
    this.isPaused = false,
    this.onComplete,
  });

  @override
  State<AnimatedCountdown> createState() => _AnimatedCountdownState();
}

class _AnimatedCountdownState extends State<AnimatedCountdown>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _urgencyController;
  late Animation<double> _pulseAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _urgencyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _colorAnimation = ColorTween(
      begin: const Color(0xFFE2B58D),
      end: const Color(0xFFEF4444),
    ).animate(CurvedAnimation(
      parent: _urgencyController,
      curve: Curves.easeInOut,
    ));

    _updateUrgencyAnimation();
  }

  void _updateUrgencyAnimation() {
    final progress = widget.remainingSeconds / widget.totalSeconds;

    if (progress <= 0.2) {
      // Critical - red and fast pulse
      _urgencyController.forward();
      _pulseController.duration = const Duration(milliseconds: 300);
    } else if (progress <= 0.5) {
      // Warning - orange
      _urgencyController.animateTo(0.5);
      _pulseController.duration = const Duration(milliseconds: 600);
    } else {
      // Normal - original color
      _urgencyController.reverse();
      _pulseController.duration = const Duration(milliseconds: 1000);
    }
  }

  @override
  void didUpdateWidget(AnimatedCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.remainingSeconds != oldWidget.remainingSeconds) {
      _updateUrgencyAnimation();

      if (widget.remainingSeconds <= 0 && oldWidget.remainingSeconds > 0) {
        widget.onComplete?.call();
      }
    }

    if (widget.isPaused != oldWidget.isPaused) {
      if (widget.isPaused) {
        _pulseController.stop();
      } else {
        _pulseController.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _urgencyController.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _urgencyController]),
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isPaused ? 1.0 : _pulseAnimation.value,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: (_colorAnimation.value ?? const Color(0xFFE2B58D))
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _colorAnimation.value ?? const Color(0xFFE2B58D),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.isPaused ? Icons.pause : Icons.timer,
                  size: 16,
                  color: _colorAnimation.value ?? const Color(0xFFE2B58D),
                ),
                const SizedBox(width: 6),
                Text(
                  widget.isPaused
                      ? 'Paused'
                      : _formatTime(widget.remainingSeconds),
                  style: TextStyle(
                    color: _colorAnimation.value ?? const Color(0xFFE2B58D),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Loading shimmer effect for task cards
class TaskCardShimmer extends StatefulWidget {
  final double height;
  final double width;

  const TaskCardShimmer({
    super.key,
    this.height = 120,
    this.width = double.infinity,
  });

  @override
  State<TaskCardShimmer> createState() => _TaskCardShimmerState();
}

class _TaskCardShimmerState extends State<TaskCardShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _shimmerAnimation = TaskPriorityAnimations.createShimmerAnimation(
      controller: _controller,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.white.withValues(alpha: 0.05),
                Colors.white.withValues(alpha: 0.1),
                Colors.white.withValues(alpha: 0.05),
              ],
              stops: [
                (_shimmerAnimation.value - 0.3).clamp(0.0, 1.0),
                _shimmerAnimation.value.clamp(0.0, 1.0),
                (_shimmerAnimation.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}
