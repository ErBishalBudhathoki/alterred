import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/prioritized_task_model.dart';

/// Reusable badge component for displaying task metadata
class TaskMetaBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final double fontSize;
  final bool compact;
  final VoidCallback? onTap;

  const TaskMetaBadge({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
    this.fontSize = 11,
    this.compact = false,
    this.onTap,
  });

  /// Create effort badge
  factory TaskMetaBadge.effort(TaskEffort effort, {bool compact = false}) {
    return TaskMetaBadge(
      icon: _getEffortIcon(effort),
      text: effort.label,
      color: Color(effort.colorValue),
      compact: compact,
    );
  }

  /// Create duration badge
  factory TaskMetaBadge.duration(int minutes, {bool compact = false}) {
    final text =
        minutes < 60 ? '${minutes}m' : '${(minutes / 60).toStringAsFixed(1)}h';

    return TaskMetaBadge(
      icon: Icons.timer_outlined,
      text: text,
      color: const Color(0xFF6B7280),
      compact: compact,
    );
  }

  /// Create due date badge
  factory TaskMetaBadge.dueDate(DateTime? dueDate, {bool compact = false}) {
    if (dueDate == null) {
      return TaskMetaBadge(
        icon: Icons.schedule_outlined,
        text: 'No due date',
        color: const Color(0xFF6B7280),
        compact: compact,
      );
    }

    final urgency = TaskUrgency.fromDueDate(dueDate);
    final now = DateTime.now();
    final difference = dueDate.difference(now).inDays;

    String text;
    if (difference < 0) {
      text = '${difference.abs()}d overdue';
    } else if (difference == 0) {
      text = 'Today';
    } else if (difference == 1) {
      text = 'Tomorrow';
    } else if (difference <= 7) {
      text = '${difference}d';
    } else {
      text = '${(difference / 7).ceil()}w';
    }

    return TaskMetaBadge(
      icon: _getUrgencyIcon(urgency),
      text: text,
      color: Color(urgency.colorValue),
      compact: compact,
    );
  }

  /// Create status badge
  factory TaskMetaBadge.status(TaskStatus status, {bool compact = false}) {
    return TaskMetaBadge(
      icon: _getStatusIcon(status),
      text: status.label,
      color: Color(status.colorValue),
      compact: compact,
    );
  }

  /// Create tag badge
  factory TaskMetaBadge.tag(String tag, {bool compact = false}) {
    return TaskMetaBadge(
      icon: Icons.label_outline,
      text: tag,
      color: const Color(0xFF8B5CF6),
      compact: compact,
    );
  }

  /// Create progress badge
  factory TaskMetaBadge.progress(double progress, {bool compact = false}) {
    final percentage = (progress * 100).round();
    return TaskMetaBadge(
      icon: Icons.trending_up,
      text: '$percentage%',
      color: progress >= 0.8
          ? const Color(0xFF10B981)
          : progress >= 0.5
              ? const Color(0xFFFBBF24)
              : const Color(0xFF6B7280),
      compact: compact,
    );
  }

  static IconData _getEffortIcon(TaskEffort effort) {
    switch (effort) {
      case TaskEffort.low:
        return Icons.battery_1_bar;
      case TaskEffort.medium:
        return Icons.battery_3_bar;
      case TaskEffort.high:
        return Icons.battery_full;
    }
  }

  static IconData _getUrgencyIcon(TaskUrgency urgency) {
    switch (urgency) {
      case TaskUrgency.overdue:
        return Icons.warning;
      case TaskUrgency.today:
        return Icons.today;
      case TaskUrgency.tomorrow:
        return Icons.schedule;
      case TaskUrgency.thisWeek:
        return Icons.date_range;
      case TaskUrgency.later:
        return Icons.schedule_outlined;
    }
  }

  static IconData _getStatusIcon(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return Icons.radio_button_unchecked;
      case TaskStatus.inProgress:
        return Icons.play_circle_outline;
      case TaskStatus.completed:
        return Icons.check_circle_outline;
      case TaskStatus.cancelled:
        return Icons.cancel_outlined;
      case TaskStatus.blocked:
        return Icons.block;
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = compact ? _buildCompactBadge() : _buildFullBadge();

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }

  Widget _buildCompactBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: fontSize + 2, color: color),
          const SizedBox(width: 3),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: fontSize - 1,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: fontSize + 4, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: fontSize,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Collection of badges for a task
class TaskMetaBadgeGroup extends StatelessWidget {
  final PrioritizedTaskModel task;
  final bool compact;
  final int maxBadges;
  final MainAxisAlignment alignment;

  const TaskMetaBadgeGroup({
    super.key,
    required this.task,
    this.compact = false,
    this.maxBadges = 4,
    this.alignment = MainAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final badges = <Widget>[];

    // Priority badge (always show for high/critical)
    if (task.priority == TaskPriority.critical ||
        task.priority == TaskPriority.high) {
      badges.add(TaskMetaBadge(
        icon: Icons.flag,
        text: task.priority.label.toUpperCase(),
        color: Color(task.priority.colorValue),
        compact: compact,
        fontSize: compact ? 9 : 10,
      ));
    }

    // Effort badge
    badges.add(TaskMetaBadge.effort(task.effort, compact: compact));

    // Duration badge
    badges.add(TaskMetaBadge.duration(task.estimatedDurationMinutes,
        compact: compact));

    // Due date badge (if has due date)
    if (task.dueDate != null) {
      badges.add(TaskMetaBadge.dueDate(task.dueDate, compact: compact));
    }

    // Progress badge (if has progress)
    if (task.completionProgress > 0) {
      badges.add(
          TaskMetaBadge.progress(task.completionProgress, compact: compact));
    }

    // Tag badges (limit to remaining space)
    final remainingSlots = maxBadges - badges.length;
    if (remainingSlots > 0 && task.tags.isNotEmpty) {
      final tagsToShow = task.tags.take(remainingSlots);
      for (final tag in tagsToShow) {
        badges.add(TaskMetaBadge.tag(tag, compact: compact));
      }
    }

    // Limit total badges
    final finalBadges = badges.take(maxBadges).toList();

    return Wrap(
      spacing: compact ? 4 : 6,
      runSpacing: compact ? 2 : 4,
      alignment: WrapAlignment.start,
      children: finalBadges,
    );
  }
}

/// Animated badge that appears with a scale effect
class AnimatedTaskMetaBadge extends StatefulWidget {
  final TaskMetaBadge badge;
  final Duration delay;
  final bool animate;

  const AnimatedTaskMetaBadge({
    super.key,
    required this.badge,
    this.delay = Duration.zero,
    this.animate = true,
  });

  @override
  State<AnimatedTaskMetaBadge> createState() => _AnimatedTaskMetaBadgeState();
}

class _AnimatedTaskMetaBadgeState extends State<AnimatedTaskMetaBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    if (widget.animate) {
      Future.delayed(widget.delay, () {
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
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: widget.badge,
          ),
        );
      },
    );
  }
}

/// Interactive badge that responds to taps with visual feedback
class InteractiveTaskMetaBadge extends StatefulWidget {
  final TaskMetaBadge badge;
  final VoidCallback? onTap;
  final String? tooltip;

  const InteractiveTaskMetaBadge({
    super.key,
    required this.badge,
    this.onTap,
    this.tooltip,
  });

  @override
  State<InteractiveTaskMetaBadge> createState() =>
      _InteractiveTaskMetaBadgeState();
}

class _InteractiveTaskMetaBadgeState extends State<InteractiveTaskMetaBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  // bool _isPressed = false; // Unused

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    // setState(() => _isPressed = true);
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    // setState(() => _isPressed = false);
    _controller.reverse();
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    // setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: widget.badge,
        );
      },
    );

    if (widget.onTap != null) {
      child = GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: child,
      );
    }

    if (widget.tooltip != null) {
      child = Tooltip(
        message: widget.tooltip!,
        child: child,
      );
    }

    return child;
  }
}
