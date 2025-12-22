import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/prioritized_task_model.dart';
import 'priority_indicator.dart';
import 'task_meta_badge.dart';
import 'task_priority_animations.dart';
import '../../agent_widgets.dart';

/// Reusable task priority card component with multiple display modes
class TaskPriorityCard extends StatefulWidget {
  final PrioritizedTaskModel task;
  final bool isSelected;
  final bool isRecommended;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final TaskCardDisplayMode displayMode;
  final TaskCardSize size;
  final bool showMetaBadges;
  final bool showPriorityIndicator;
  final bool showDescription;
  final bool animate;
  final int animationIndex;

  const TaskPriorityCard({
    super.key,
    required this.task,
    this.isSelected = false,
    this.isRecommended = false,
    this.onTap,
    this.onLongPress,
    this.displayMode = TaskCardDisplayMode.standard,
    this.size = TaskCardSize.medium,
    this.showMetaBadges = true,
    this.showPriorityIndicator = true,
    this.showDescription = false,
    this.animate = true,
    this.animationIndex = 0,
  });

  @override
  State<TaskPriorityCard> createState() => _TaskPriorityCardState();
}

class _TaskPriorityCardState extends State<TaskPriorityCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _hoverAnimation;
  // bool _isHovered = false; // Unused

  @override
  void initState() {
    super.initState();

    _hoverController = AnimationController(
      vsync: this,
      duration: TaskPriorityAnimations.normalDuration,
    );

    _hoverAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: TaskPriorityAnimations.defaultCurve,
    ));
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  void _handleHoverEnter() {
    // setState(() => _isHovered = true);
    _hoverController.forward();
  }

  void _handleHoverExit() {
    // setState(() => _isHovered = false);
    _hoverController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    Widget card = _buildCard();

    // Wrap with animation if enabled
    if (widget.animate) {
      card = AnimatedTaskEntry(
        index: widget.animationIndex,
        child: card,
      );
    }

    // Wrap with selection animation
    card = AnimatedSelection(
      isSelected: widget.isSelected,
      onTap: widget.onTap,
      child: card,
    );

    return card;
  }

  Widget _buildCard() {
    switch (widget.displayMode) {
      case TaskCardDisplayMode.compact:
        return _buildCompactCard();
      case TaskCardDisplayMode.standard:
        return _buildStandardCard();
      case TaskCardDisplayMode.detailed:
        return _buildDetailedCard();
      case TaskCardDisplayMode.voice:
        return _buildVoiceCard();
      case TaskCardDisplayMode.minimal:
        return _buildMinimalCard();
    }
  }

  Widget _buildCompactCard() {
    return MouseRegion(
      onEnter: (_) => _handleHoverEnter(),
      onExit: (_) => _handleHoverExit(),
      child: AnimatedBuilder(
        animation: _hoverAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _hoverAnimation.value,
            child: GlassContainer(
              borderRadius: BorderRadius.circular(12),
              padding: const EdgeInsets.all(12),
              isActive: widget.isSelected || widget.isRecommended,
              child: Row(
                children: [
                  // Selection indicator
                  _buildSelectionIndicator(),
                  const SizedBox(width: 12),

                  // Task content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.task.title,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (widget.showMetaBadges)
                          TaskMetaBadgeGroup(
                            task: widget.task,
                            compact: true,
                            maxBadges: 2,
                          ),
                      ],
                    ),
                  ),

                  // Priority indicator
                  if (widget.showPriorityIndicator)
                    PriorityIndicator(
                      priority: widget.task.priority,
                      urgency: widget.task.urgency,
                      size: 16,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStandardCard() {
    return MouseRegion(
      onEnter: (_) => _handleHoverEnter(),
      onExit: (_) => _handleHoverExit(),
      child: AnimatedBuilder(
        animation: _hoverAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _hoverAnimation.value,
            child: GlassContainer(
              borderRadius: BorderRadius.circular(16),
              padding: const EdgeInsets.all(16),
              isActive: widget.isSelected || widget.isRecommended,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSelectionIndicator(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.task.title,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            if (widget.showDescription &&
                                widget.task.description != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                widget.task.description!,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.white60,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (widget.showPriorityIndicator)
                        PriorityIndicator(
                          priority: widget.task.priority,
                          urgency: widget.task.urgency,
                          size: 20,
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Reasoning
                  Text(
                    widget.task.priorityReasoning,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white60,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 12),

                  // Meta badges and tags
                  Row(
                    children: [
                      Expanded(
                        child: widget.showMetaBadges
                            ? TaskMetaBadgeGroup(
                                task: widget.task,
                                compact: false,
                                maxBadges: 3,
                              )
                            : const SizedBox.shrink(),
                      ),
                      if (_shouldShowRecommendedTag()) _buildRecommendedTag(),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailedCard() {
    return MouseRegion(
      onEnter: (_) => _handleHoverEnter(),
      onExit: (_) => _handleHoverExit(),
      child: AnimatedBuilder(
        animation: _hoverAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _hoverAnimation.value,
            child: GlassContainer(
              borderRadius: BorderRadius.circular(20),
              padding: const EdgeInsets.all(20),
              isActive: widget.isSelected || widget.isRecommended,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with priority indicator
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSelectionIndicator(),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.task.title,
                                    style: GoogleFonts.inter(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                if (widget.showPriorityIndicator)
                                  CompoundPriorityIndicator(
                                    priority: widget.task.priority,
                                    urgency: widget.task.urgency,
                                    size: 24,
                                  ),
                              ],
                            ),
                            if (widget.task.description != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                widget.task.description!,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Colors.white70,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Priority reasoning
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lightbulb_outline,
                          size: 16,
                          color: Color(0xFFE2B58D),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.task.priorityReasoning,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.white70,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Meta information
                  if (widget.showMetaBadges)
                    TaskMetaBadgeGroup(
                      task: widget.task,
                      compact: false,
                      maxBadges: 5,
                    ),

                  // Progress bar if applicable
                  if (widget.task.completionProgress > 0) ...[
                    const SizedBox(height: 12),
                    _buildProgressBar(),
                  ],

                  // Tags row
                  if (_shouldShowRecommendedTag()) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Spacer(),
                        _buildRecommendedTag(),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVoiceCard() {
    return GlassContainer(
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(24),
      isActive: widget.isSelected || widget.isRecommended,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with large selection indicator
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? const Color(0xFFE2B58D)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.isSelected || widget.isRecommended
                        ? const Color(0xFFE2B58D)
                        : Colors.white24,
                    width: 2,
                  ),
                ),
                child: widget.isSelected
                    ? const Icon(
                        Icons.check,
                        size: 20,
                        color: Color(0xFF0F0505),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.task.title,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.task.priorityReasoning,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Large meta badges for voice mode
          if (widget.showMetaBadges)
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                TaskMetaBadge(
                  icon: Icons.flag,
                  text: widget.task.priority.label.toUpperCase(),
                  color: Color(widget.task.priority.colorValue),
                  fontSize: 12,
                ),
                TaskMetaBadge.duration(widget.task.estimatedDurationMinutes),
                if (widget.task.dueDate != null)
                  TaskMetaBadge.dueDate(widget.task.dueDate),
              ],
            ),

          if (_shouldShowRecommendedTag()) ...[
            const SizedBox(height: 16),
            Center(child: _buildRecommendedTag()),
          ],
        ],
      ),
    );
  }

  Widget _buildMinimalCard() {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: widget.isSelected
              ? const Color(0xFFE2B58D).withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: widget.isSelected
                ? const Color(0xFFE2B58D).withValues(alpha: 0.3)
                : Colors.white10,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? const Color(0xFFE2B58D)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: widget.isSelected
                      ? const Color(0xFFE2B58D)
                      : Colors.white24,
                ),
              ),
              child: widget.isSelected
                  ? const Icon(
                      Icons.check,
                      size: 12,
                      color: Color(0xFF0F0505),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.task.title,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.showPriorityIndicator)
              PriorityIndicator(
                priority: widget.task.priority,
                urgency: widget.task.urgency,
                size: 12,
                animate: false,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionIndicator() {
    return Container(
      width: 24,
      height: 24,
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(
        color: widget.isSelected ? const Color(0xFFE2B58D) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.isSelected || widget.isRecommended
              ? const Color(0xFFE2B58D)
              : Colors.white24,
          width: 2,
        ),
      ),
      child: widget.isSelected
          ? const Icon(
              Icons.check,
              size: 16,
              color: Color(0xFF0F0505),
            )
          : null,
    );
  }

  Widget _buildProgressBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progress',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white60,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${(widget.task.completionProgress * 100).round()}%',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white60,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: Colors.white.withValues(alpha: 0.1),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: widget.task.completionProgress,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  bool _shouldShowRecommendedTag() {
    return widget.isRecommended && !widget.isSelected;
  }

  Widget _buildRecommendedTag() {
    return AnimatedPriorityBadge(
      priority: widget.task.priority,
      urgency: widget.task.urgency,
      customLabel: 'RECOMMENDED',
      fontSize: 10,
    );
  }
}

/// Display modes for task priority cards
enum TaskCardDisplayMode {
  compact, // Minimal single-line display
  standard, // Standard card with reasoning
  detailed, // Full-featured card with all details
  voice, // Optimized for voice mode
  minimal, // Ultra-minimal for lists
}

/// Size variants for task priority cards
enum TaskCardSize {
  small,
  medium,
  large,
}

/// Loading placeholder for task priority cards
class TaskPriorityCardSkeleton extends StatelessWidget {
  final TaskCardDisplayMode displayMode;
  final TaskCardSize size;

  const TaskPriorityCardSkeleton({
    super.key,
    this.displayMode = TaskCardDisplayMode.standard,
    this.size = TaskCardSize.medium,
  });

  @override
  Widget build(BuildContext context) {
    double height;
    switch (displayMode) {
      case TaskCardDisplayMode.compact:
        height = 60;
        break;
      case TaskCardDisplayMode.standard:
        height = 120;
        break;
      case TaskCardDisplayMode.detailed:
        height = 180;
        break;
      case TaskCardDisplayMode.voice:
        height = 160;
        break;
      case TaskCardDisplayMode.minimal:
        height = 40;
        break;
    }

    return TaskCardShimmer(
      height: height,
      width: double.infinity,
    );
  }
}
