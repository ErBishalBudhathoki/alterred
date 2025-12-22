import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../design_tokens.dart';

enum PulseMode { idle, listening, speaking, processing }

class PulseIndicator extends StatelessWidget {
  final PulseMode mode;
  final double size;
  final double amplitude; // 0.0 to 1.0

  const PulseIndicator({
    super.key,
    required this.mode,
    this.size = 56,
    this.amplitude = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getColor(context);
    
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ripple 1
          if (mode != PulseMode.idle)
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
            )
                .animate(onPlay: (c) => c.repeat())
                .scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1.4, 1.4),
                  duration: _getDuration(),
                  curve: Curves.easeOut,
                )
                .fadeOut(
                  duration: _getDuration(),
                  curve: Curves.easeOut,
                ),

          // Outer ripple 2 (delayed)
          if (mode != PulseMode.idle)
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.withValues(alpha: 0.1),
                  width: 2,
                ),
              ),
            )
                .animate(onPlay: (c) => c.repeat(), delay: 400.ms)
                .scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1.4, 1.4),
                  duration: _getDuration(),
                  curve: Curves.easeOut,
                )
                .fadeOut(
                  duration: _getDuration(),
                  curve: Curves.easeOut,
                ),

          // Core circle
          Container(
            width: size * 0.6,
            height: size * 0.6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
          )
              .animate(
                target: mode == PulseMode.listening ? 1 : 0,
              )
              .scale(
                begin: const Offset(1.0, 1.0),
                end: Offset(1.0 + (amplitude * 0.5), 1.0 + (amplitude * 0.5)),
                duration: 100.ms,
              )
              .animate(
                onPlay: (c) => c.repeat(reverse: true),
              )
              .custom(
                duration: _getBreathingDuration(),
                builder: (context, value, child) {
                  // Breathing effect when not actively listening
                  if (mode == PulseMode.listening) return child;
                  final scale = 1.0 + (value * 0.1);
                  return Transform.scale(scale: scale, child: child);
                },
              ),
              
          // Icon
          Icon(
            _getIcon(),
            color: Colors.white,
            size: size * 0.3,
          ).animate().fadeIn(duration: 300.ms),
        ],
      ),
    );
  }

  Color _getColor(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    switch (mode) {
      case PulseMode.listening:
        return DesignTokens.error; // Red for recording
      case PulseMode.speaking:
        return DesignTokens.success; // Green for speaking
      case PulseMode.processing:
        return DesignTokens.warning; // Amber for processing
      case PulseMode.idle:
        return theme.primary; // Blue for idle
    }
  }

  IconData _getIcon() {
    switch (mode) {
      case PulseMode.listening:
        return Icons.mic;
      case PulseMode.speaking:
        return Icons.volume_up;
      case PulseMode.processing:
        return Icons.hourglass_empty;
      case PulseMode.idle:
        return Icons.mic_none;
    }
  }

  Duration _getDuration() {
    if (mode == PulseMode.listening) return 1000.ms;
    if (mode == PulseMode.speaking) return 800.ms;
    return 2000.ms;
  }
  
  Duration _getBreathingDuration() {
    if (mode == PulseMode.processing) return 600.ms;
    return 2000.ms;
  }
}
