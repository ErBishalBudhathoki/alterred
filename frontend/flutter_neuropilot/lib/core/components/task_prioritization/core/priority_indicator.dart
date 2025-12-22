import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/prioritized_task_model.dart';

/// Visual indicator for task priority with animated effects
class PriorityIndicator extends StatefulWidget {
  final TaskPriority priority;
  final TaskUrgency urgency;
  final double size;
  final bool showLabel;
  final bool animate;
  final PriorityIndicatorStyle style;

  const PriorityIndicator({
    super.key,
    required this.priority,
    required this.urgency,
    this.size = 24,
    this.showLabel = false,
    this.animate = true,
    this.style = PriorityIndicatorStyle.flag,
  });

  @override
  State<PriorityIndicator> createState() => _PriorityIndicatorState();
}

class _PriorityIndicatorState extends State<PriorityIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    if (widget.animate && _shouldAnimate()) {
      _controller.repeat(reverse: true);
    }
  }

  bool _shouldAnimate() {
    return widget.priority == TaskPriority.critical ||
        widget.urgency == TaskUrgency.overdue ||
        widget.urgency == TaskUrgency.today;
  }

  @override
  void didUpdateWidget(PriorityIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.animate != oldWidget.animate ||
        widget.priority != oldWidget.priority ||
        widget.urgency != oldWidget.urgency) {
      if (widget.animate && _shouldAnimate()) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _primaryColor => Color(widget.priority.colorValue);
  Color get _urgencyColor => Color(widget.urgency.colorValue);

  Color get _effectiveColor {
    // Use urgency color if it's more critical than priority
    if (widget.urgency == TaskUrgency.overdue) return _urgencyColor;
    if (widget.urgency == TaskUrgency.today &&
        widget.priority != TaskPriority.critical) {
      return _urgencyColor;
    }
    return _primaryColor;
  }

  IconData get _iconForStyle {
    switch (widget.style) {
      case PriorityIndicatorStyle.flag:
        return Icons.flag;
      case PriorityIndicatorStyle.circle:
        return Icons.circle;
      case PriorityIndicatorStyle.diamond:
        return Icons.diamond;
      case PriorityIndicatorStyle.star:
        return Icons.star;
      case PriorityIndicatorStyle.warning:
        return widget.priority == TaskPriority.critical
            ? Icons.warning
            : Icons.flag;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) {
      return _buildStaticIndicator();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _shouldAnimate() ? _pulseAnimation.value : 1.0,
          child: Transform.rotate(
            angle: _shouldAnimate() ? _rotationAnimation.value : 0.0,
            child: _buildStaticIndicator(),
          ),
        );
      },
    );
  }

  Widget _buildStaticIndicator() {
    final color = _effectiveColor;

    if (widget.showLabel) {
      return _buildWithLabel(color);
    }

    return _buildIconOnly(color);
  }

  Widget _buildIconOnly(Color color) {
    switch (widget.style) {
      case PriorityIndicatorStyle.circle:
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: _shouldAnimate()
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
        );

      case PriorityIndicatorStyle.diamond:
        return Transform.rotate(
          angle: 0.785398, // 45 degrees
          child: Container(
            width: widget.size * 0.8,
            height: widget.size * 0.8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              boxShadow: _shouldAnimate()
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
          ),
        );

      default:
        return Icon(
          _iconForStyle,
          size: widget.size,
          color: color,
          shadows: _shouldAnimate()
              ? [
                  Shadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 8,
                  ),
                ]
              : null,
        );
    }
  }

  Widget _buildWithLabel(Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: _shouldAnimate()
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.2),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _iconForStyle,
            size: widget.size * 0.7,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            widget.priority.label.toUpperCase(),
            style: GoogleFonts.inter(
              color: color,
              fontSize: widget.size * 0.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Different visual styles for priority indicators
enum PriorityIndicatorStyle {
  flag,
  circle,
  diamond,
  star,
  warning,
}

/// Compound indicator showing both priority and urgency
class CompoundPriorityIndicator extends StatelessWidget {
  final TaskPriority priority;
  final TaskUrgency urgency;
  final double size;
  final bool animate;

  const CompoundPriorityIndicator({
    super.key,
    required this.priority,
    required this.urgency,
    this.size = 32,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main priority indicator
        PriorityIndicator(
          priority: priority,
          urgency: urgency,
          size: size,
          animate: animate,
          style: PriorityIndicatorStyle.circle,
        ),

        // Urgency overlay for critical cases
        if (urgency == TaskUrgency.overdue || urgency == TaskUrgency.today)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: size * 0.4,
              height: size * 0.4,
              decoration: BoxDecoration(
                color: Color(urgency.colorValue),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF0F0505),
                  width: 1,
                ),
              ),
              child: Icon(
                urgency == TaskUrgency.overdue ? Icons.warning : Icons.schedule,
                size: size * 0.25,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}

/// Priority level bar indicator
class PriorityLevelBar extends StatefulWidget {
  final TaskPriority priority;
  final double width;
  final double height;
  final bool animate;

  const PriorityLevelBar({
    super.key,
    required this.priority,
    this.width = 60,
    this.height = 4,
    this.animate = true,
  });

  @override
  State<PriorityLevelBar> createState() => _PriorityLevelBarState();
}

class _PriorityLevelBarState extends State<PriorityLevelBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fillAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fillAnimation = Tween<double>(
      begin: 0.0,
      end: widget.priority.weight / 4.0, // Normalize to 0-1
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    if (widget.animate) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.value = 1.0;
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
      animation: _fillAnimation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.height / 2),
            color: Colors.white.withValues(alpha: 0.1),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _fillAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.height / 2),
                gradient: LinearGradient(
                  colors: [
                    Color(widget.priority.colorValue),
                    Color(widget.priority.colorValue).withValues(alpha: 0.7),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(widget.priority.colorValue)
                        .withValues(alpha: 0.3),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Animated priority badge with pulse effect
class AnimatedPriorityBadge extends StatefulWidget {
  final TaskPriority priority;
  final TaskUrgency urgency;
  final String? customLabel;
  final double fontSize;

  const AnimatedPriorityBadge({
    super.key,
    required this.priority,
    required this.urgency,
    this.customLabel,
    this.fontSize = 10,
  });

  @override
  State<AnimatedPriorityBadge> createState() => _AnimatedPriorityBadgeState();
}

class _AnimatedPriorityBadgeState extends State<AnimatedPriorityBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    if (_shouldPulse()) {
      _controller.repeat(reverse: true);
    }
  }

  bool _shouldPulse() {
    return widget.priority == TaskPriority.critical ||
        widget.urgency == TaskUrgency.overdue;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.urgency == TaskUrgency.overdue
        ? Color(widget.urgency.colorValue)
        : Color(widget.priority.colorValue);

    final label = widget.customLabel ??
        (widget.urgency == TaskUrgency.overdue
            ? 'OVERDUE'
            : widget.priority.label.toUpperCase());

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withValues(
                  alpha: _shouldPulse() ? _glowAnimation.value : 0.5),
              width: 1,
            ),
            boxShadow: _shouldPulse()
                ? [
                    BoxShadow(
                      color:
                          color.withValues(alpha: _glowAnimation.value * 0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: color,
              fontSize: widget.fontSize,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        );
      },
    );
  }
}
