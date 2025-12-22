import 'package:flutter/material.dart';

class BrainAnimations {
  // Capture animations
  static const Duration captureEntranceDuration = Duration(milliseconds: 600);
  static const Duration captureProcessingDuration =
      Duration(milliseconds: 1200);
  static const Duration captureCompleteDuration = Duration(milliseconds: 400);

  // Context restoration animations
  static const Duration contextFadeDuration = Duration(milliseconds: 800);
  static const Duration contextSlideDuration = Duration(milliseconds: 500);

  // A2A connection animations
  static const Duration connectionPulseDuration = Duration(milliseconds: 2000);
  static const Duration messageBounceDuration = Duration(milliseconds: 300);

  // Working memory animations
  static const Duration memoryItemDuration = Duration(milliseconds: 400);
  static const Duration memoryExpireDuration = Duration(milliseconds: 600);

  // Voice capture animations
  static const Duration voiceWaveDuration = Duration(milliseconds: 1500);
  static const Duration voiceListeningDuration = Duration(milliseconds: 800);

  // Curves
  static const Curve captureEntranceCurve = Curves.elasticOut;
  static const Curve processingCurve = Curves.easeInOut;
  static const Curve completeCurve = Curves.bounceOut;
  static const Curve contextCurve = Curves.easeOutCubic;
  static const Curve connectionCurve = Curves.easeInOutSine;
  static const Curve memoryCurve = Curves.fastOutSlowIn;
  static const Curve voiceCurve = Curves.easeInOutQuart;
}

class CaptureEntranceAnimation extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final VoidCallback? onComplete;

  const CaptureEntranceAnimation({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.onComplete,
  });

  @override
  State<CaptureEntranceAnimation> createState() =>
      _CaptureEntranceAnimationState();
}

class _CaptureEntranceAnimationState extends State<CaptureEntranceAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: BrainAnimations.captureEntranceDuration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: BrainAnimations.captureEntranceCurve,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    ));

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
      }
    });

    Future.delayed(widget.delay, () {
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
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: SlideTransition(
            position: _slideAnimation,
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}

class ProcessingAnimation extends StatefulWidget {
  final Widget child;
  final bool isProcessing;
  final Color? color;

  const ProcessingAnimation({
    super.key,
    required this.child,
    required this.isProcessing,
    this.color,
  });

  @override
  State<ProcessingAnimation> createState() => _ProcessingAnimationState();
}

class _ProcessingAnimationState extends State<ProcessingAnimation>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: BrainAnimations.captureProcessingDuration,
      vsync: this,
    );

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: BrainAnimations.processingCurve,
    ));

    _shimmerAnimation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.linear,
    ));

    if (widget.isProcessing) {
      _startAnimations();
    }
  }

  void _startAnimations() {
    _pulseController.repeat(reverse: true);
    _shimmerController.repeat();
  }

  void _stopAnimations() {
    _pulseController.stop();
    _shimmerController.stop();
  }

  @override
  void didUpdateWidget(ProcessingAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isProcessing != oldWidget.isProcessing) {
      if (widget.isProcessing) {
        _startAnimations();
      } else {
        _stopAnimations();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isProcessing) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _shimmerController]),
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Stack(
            children: [
              widget.child,
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(_shimmerAnimation.value - 1, 0),
                        end: Alignment(_shimmerAnimation.value, 0),
                        colors: [
                          Colors.transparent,
                          (widget.color ?? Colors.blue).withValues(alpha: 0.1),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class VoiceWaveAnimation extends StatefulWidget {
  final bool isListening;
  final double amplitude;
  final Color color;
  final double size;

  const VoiceWaveAnimation({
    super.key,
    required this.isListening,
    this.amplitude = 1.0,
    this.color = Colors.blue,
    this.size = 100.0,
  });

  @override
  State<VoiceWaveAnimation> createState() => _VoiceWaveAnimationState();
}

class _VoiceWaveAnimationState extends State<VoiceWaveAnimation>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _pulseController;
  late List<Animation<double>> _waveAnimations;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _waveController = AnimationController(
      duration: BrainAnimations.voiceWaveDuration,
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: BrainAnimations.voiceListeningDuration,
      vsync: this,
    );

    _waveAnimations = List.generate(5, (index) {
      return Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _waveController,
        curve: Interval(
          index * 0.1,
          0.5 + index * 0.1,
          curve: BrainAnimations.voiceCurve,
        ),
      ));
    });

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    if (widget.isListening) {
      _startAnimations();
    }
  }

  void _startAnimations() {
    _waveController.repeat();
    _pulseController.repeat(reverse: true);
  }

  void _stopAnimations() {
    _waveController.stop();
    _pulseController.stop();
  }

  @override
  void didUpdateWidget(VoiceWaveAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening != oldWidget.isListening) {
      if (widget.isListening) {
        _startAnimations();
      } else {
        _stopAnimations();
      }
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_waveController, _pulseController]),
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isListening ? _pulseAnimation.value : 1.0,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: VoiceWavePainter(
                waveAnimations: _waveAnimations,
                color: widget.color,
                amplitude: widget.amplitude,
                isListening: widget.isListening,
              ),
            ),
          ),
        );
      },
    );
  }
}

class VoiceWavePainter extends CustomPainter {
  final List<Animation<double>> waveAnimations;
  final Color color;
  final double amplitude;
  final bool isListening;

  VoiceWavePainter({
    required this.waveAnimations,
    required this.color,
    required this.amplitude,
    required this.isListening,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    if (!isListening) {
      // Draw static circle
      canvas.drawCircle(center, size.width * 0.3, paint);
      return;
    }

    // Draw animated waves
    for (int i = 0; i < waveAnimations.length; i++) {
      final animation = waveAnimations[i];
      final radius =
          (size.width * 0.1) + (animation.value * size.width * 0.4 * amplitude);
      final opacity = (1.0 - animation.value) * 0.8;

      paint.color = color.withValues(alpha: opacity);
      canvas.drawCircle(center, radius, paint);
    }

    // Draw center dot
    paint
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, size.width * 0.05, paint);
  }

  @override
  bool shouldRepaint(VoiceWavePainter oldDelegate) {
    return oldDelegate.amplitude != amplitude ||
        oldDelegate.isListening != isListening ||
        oldDelegate.color != color;
  }
}

class ContextRestoreAnimation extends StatefulWidget {
  final Widget child;
  final bool isRestoring;
  final VoidCallback? onComplete;

  const ContextRestoreAnimation({
    super.key,
    required this.child,
    required this.isRestoring,
    this.onComplete,
  });

  @override
  State<ContextRestoreAnimation> createState() =>
      _ContextRestoreAnimationState();
}

class _ContextRestoreAnimationState extends State<ContextRestoreAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: BrainAnimations.contextFadeDuration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: BrainAnimations.contextCurve,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(-0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: BrainAnimations.contextCurve,
    ));

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
      }
    });

    if (widget.isRestoring) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(ContextRestoreAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRestoring != oldWidget.isRestoring) {
      if (widget.isRestoring) {
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: widget.child,
          ),
        );
      },
    );
  }
}
