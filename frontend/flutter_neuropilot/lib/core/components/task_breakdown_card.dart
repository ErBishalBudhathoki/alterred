import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../design_tokens.dart';
import 'agent_widgets.dart';

class TaskBreakdownCard extends StatefulWidget {
  final List<dynamic> steps;
  final String title;
  final int? estimatedTime;
  final String? dopamineHack;
  final Set<int>? initialCompletedSteps;
  final ValueChanged<Set<int>>? onStepsChanged;

  const TaskBreakdownCard({
    super.key,
    required this.steps,
    this.title = 'Action Plan',
    this.estimatedTime,
    this.dopamineHack,
    this.initialCompletedSteps,
    this.onStepsChanged,
  });

  @override
  State<TaskBreakdownCard> createState() => _TaskBreakdownCardState();
}

class _TaskBreakdownCardState extends State<TaskBreakdownCard> {
  late Set<int> _completedSteps;

  @override
  void initState() {
    super.initState();
    _completedSteps = widget.initialCompletedSteps != null
        ? Set.from(widget.initialCompletedSteps!)
        : {};
  }

  void _toggleStep(int index) {
    setState(() {
      if (_completedSteps.contains(index)) {
        _completedSteps.remove(index);
      } else {
        _completedSteps.add(index);
        HapticFeedback.lightImpact();
      }
      widget.onStepsChanged?.call(_completedSteps);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Convert dynamic list to string list
    final stringSteps = widget.steps.map((e) => e.toString()).toList();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: DesignTokens.spacingMd),
      padding: const EdgeInsets.all(DesignTokens.spacingMd),
      decoration: BoxDecoration(
        // Use dark background to match TaskFlowAgentScreen color scheme
        color: const Color(0xFF0F0505).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        border: Border.all(
          color: const Color(0xFFE2B58D).withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(DesignTokens.spacingXs),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2B58D).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                ),
                child: const Icon(
                  Icons.checklist_rounded,
                  size: 16,
                  color: Color(0xFFE2B58D),
                ),
              ),
              const SizedBox(width: DesignTokens.spacingSm),
              Text(
                widget.title,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFE2B58D),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spacingMd),
          TaskChecklist(
            steps: stringSteps,
            completedSteps: _completedSteps,
            onToggleStep: _toggleStep,
            estimatedMinutes: widget.estimatedTime,
            dopamineHack: widget.dopamineHack,
          ),
        ],
      ),
    ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack);
  }
}
