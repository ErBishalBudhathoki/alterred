import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

export 'task_quest_card.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Color? color;
  final bool isActive;

  const GlassContainer({
    super.key,
    required this.child,
    required this.padding,
    required this.borderRadius,
    this.color,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(
              color: isActive
                  ? const Color(0xFFE2B58D).withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.08),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isActive
                  ? [
                      const Color(0xFFE2B58D).withValues(alpha: 0.15),
                      const Color(0xFFE2B58D).withValues(alpha: 0.05),
                    ]
                  : [
                      color ?? Colors.white.withValues(alpha: 0.08),
                      color ?? Colors.white.withValues(alpha: 0.02),
                    ],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class TaskItem extends StatelessWidget {
  final String title;
  final bool isDone;
  final bool isActive;
  final String? tag;
  final VoidCallback? onTap;

  const TaskItem({
    super.key,
    required this.title,
    required this.isDone,
    this.isActive = false,
    this.tag,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        borderRadius: BorderRadius.circular(20),
        padding: EdgeInsets.all(isActive ? 20 : 16),
        isActive: isActive,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: isDone ? const Color(0xFFE2B58D) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isActive ? const Color(0xFFE2B58D) : Colors.white24,
                  width: 2,
                ),
              ),
              child: isDone
                  ? const Icon(Icons.check, size: 16, color: Color(0xFF0F0505))
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: isActive ? 17 : 16,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      color: isDone ? Colors.white60 : Colors.white,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (tag != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2B58D).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color:
                                const Color(0xFFE2B58D).withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        tag!,
                        style: const TextStyle(
                          color: Color(0xFFE2B58D),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.more_vert, color: Colors.white30),
          ],
        ),
      ),
    );
  }
}

class TaskChecklist extends StatelessWidget {
  final List<String> steps;
  final Set<int> completedSteps;
  final ValueChanged<int> onToggleStep;
  final int? estimatedMinutes;
  final String? dopamineHack;

  const TaskChecklist({
    super.key,
    required this.steps,
    required this.completedSteps,
    required this.onToggleStep,
    this.estimatedMinutes,
    this.dopamineHack,
  });

  @override
  Widget build(BuildContext context) {
    // Find the first step that is NOT completed
    int firstIncompleteIndex = -1;
    for (int i = 0; i < steps.length; i++) {
      if (!completedSteps.contains(i)) {
        firstIncompleteIndex = i;
        break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (estimatedMinutes != null || dopamineHack != null) ...[
          GlassContainer(
            borderRadius: BorderRadius.circular(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (estimatedMinutes != null)
                  Text(
                    "Estimated time: $estimatedMinutes min",
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                if (dopamineHack != null) ...[
                  if (estimatedMinutes != null) const SizedBox(height: 10),
                  Text(
                    dopamineHack!,
                    style: GoogleFonts.inter(
                      color: const Color(0xFFE2B58D).withValues(alpha: 0.95),
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        for (int i = 0; i < steps.length; i++) ...[
          TaskItem(
            title: steps[i],
            isDone: completedSteps.contains(i),
            isActive: i == firstIncompleteIndex,
            tag: i == firstIncompleteIndex ? "NEXT STEP" : null,
            onTap: () => onToggleStep(i),
          ),
          if (i != steps.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}
