import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/prioritized_task_model.dart';
import '../core/task_priority_card.dart';
import '../core/countdown_timer_widget.dart';
import '../core/task_priority_animations.dart';
import '../state/task_prioritization_provider.dart';
import '../../np_button.dart';

/// Task prioritization widget optimized for chat mode
class ChatTaskPrioritization extends ConsumerStatefulWidget {
  final Function(PrioritizedTaskModel, String) onTaskSelected;
  final VoidCallback? onScheduleTask;
  final VoidCallback? onTakeNote;
  final VoidCallback? onRefresh;
  final VoidCallback? onAtomizeTask;
  final bool enableAutoSelect;
  final int countdownSeconds;
  final bool showQuickActions;

  const ChatTaskPrioritization({
    super.key,
    required this.onTaskSelected,
    this.onScheduleTask,
    this.onTakeNote,
    this.onRefresh,
    this.onAtomizeTask,
    this.enableAutoSelect = false,
    this.countdownSeconds = 60,
    this.showQuickActions = true,
  });

  @override
  ConsumerState<ChatTaskPrioritization> createState() =>
      _ChatTaskPrioritizationState();
}

class _ChatTaskPrioritizationState extends ConsumerState<ChatTaskPrioritization>
    with TickerProviderStateMixin {
  int? _selectedIndex;
  bool _showDetails = false;
  late AnimationController _entranceController;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: TaskPriorityAnimations.extraSlowDuration,
    );

    // Start entrance animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _entranceController.forward();
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  void _handleTaskSelection(int index) {
    if (_selectedIndex == index) return;

    setState(() {
      _selectedIndex = index;
    });
  }

  void _handleTaskConfirmation() {
    final state = ref.read(taskPrioritizationProvider);
    if (_selectedIndex == null || !state.hasData) return;

    final task = state.tasks[_selectedIndex!];
    ref.read(taskPrioritizationProvider.notifier).selectTask(task, 'manual');
    widget.onTaskSelected(task, 'manual');
  }

  void _handleAutoSelect() {
    final state = ref.read(taskPrioritizationProvider);
    if (!state.hasData) return;

    final task = state.tasks.first;
    ref.read(taskPrioritizationProvider.notifier).selectTask(task, 'auto');
    widget.onTaskSelected(task, 'auto');
  }

  void _handleStartTopPick() {
    final state = ref.read(taskPrioritizationProvider);
    if (!state.hasData) return;

    final task = state.tasks.first;
    ref.read(taskPrioritizationProvider.notifier).selectTask(task, 'manual');
    widget.onTaskSelected(task, 'manual');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(taskPrioritizationProvider);
    final isCompleted = ref.watch(prioritizationCompletedProvider);

    if (state.isLoading) {
      return _buildLoadingState();
    }

    if (state.hasError) {
      return _buildErrorState(state.error!);
    }

    if (!state.hasData) {
      return _buildEmptyState();
    }

    return _buildPrioritizationWidget(state, isCompleted);
  }

  Widget _buildLoadingState() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0505).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFFE2B58D).withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2B58D).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.psychology,
                  size: 20,
                  color: Color(0xFFE2B58D),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Analyzing Tasks',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFE2B58D),
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Finding the best tasks for you...',
                      style: GoogleFonts.inter(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Loading skeletons
          for (int i = 0; i < 3; i++) ...[
            const TaskPriorityCardSkeleton(
              displayMode: TaskCardDisplayMode.compact,
            ),
            if (i < 2) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0505).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.error_outline,
                  size: 20,
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unable to Load Tasks',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      error,
                      style: GoogleFonts.inter(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: NpButton(
                  label: 'Retry',
                  icon: Icons.refresh,
                  type: NpButtonType.secondary,
                  onPressed: () {
                    ref.read(taskPrioritizationProvider.notifier).refresh();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0505).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFFE2B58D).withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: Color(0xFFE2B58D),
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'All caught up!',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No pending tasks to prioritize. Time for a break!',
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPrioritizationWidget(
      TaskPrioritizationState state, bool isCompleted) {
    const accentColor = Color(0xFFE2B58D);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0505).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
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
          _buildHeader(accentColor, isCompleted, state),
          if (!isCompleted && widget.enableAutoSelect)
            _buildCountdownSection(accentColor),
          if (!isCompleted) _buildTaskSummary(accentColor, state),
          _buildTaskList(accentColor, state, isCompleted),
          if (_showDetails) _buildDetailsSection(accentColor, state),
          if (!isCompleted) _buildActionButtons(accentColor, state),
          if (!isCompleted && widget.showQuickActions)
            _buildQuickActionsSection(accentColor),
        ],
      ),
    ).animate().scale(
          duration: TaskPriorityAnimations.normalDuration,
          curve: Curves.easeOutBack,
        );
  }

  Widget _buildHeader(
      Color accentColor, bool isCompleted, TaskPrioritizationState state) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isCompleted ? Icons.check_circle : Icons.psychology,
              size: 20,
              color: accentColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCompleted ? 'Task Selected' : 'Task Prioritization',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                    fontSize: 16,
                  ),
                ),
                Text(
                  isCompleted
                      ? 'Selection complete'
                      : '${state.tasks.length} of ${state.originalTaskCount} tasks selected',
                  style: GoogleFonts.inter(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (!isCompleted && widget.onRefresh != null)
            IconButton(
              icon: Icon(Icons.refresh, color: accentColor, size: 20),
              onPressed: () {
                ref.read(taskPrioritizationProvider.notifier).refresh();
                widget.onRefresh?.call();
              },
              tooltip: 'Refresh priorities',
            ),
        ],
      ),
    );
  }

  Widget _buildCountdownSection(Color accentColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: CountdownTimerWidget(
        totalSeconds: widget.countdownSeconds,
        autoStart: widget.enableAutoSelect,
        enableAutoSelect: widget.enableAutoSelect,
        displayMode: CountdownDisplayMode.linear,
        onComplete: _handleAutoSelect,
        customLabel: 'Auto-select in',
      ),
    );
  }

  Widget _buildTaskSummary(Color accentColor, TaskPrioritizationState state) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        'Choose one task to focus on:',
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTaskList(
      Color accentColor, TaskPrioritizationState state, bool isCompleted) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: state.tasks.asMap().entries.map((entry) {
          final index = entry.key;
          final task = entry.value;
          final isSelected = _selectedIndex == index;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TaskPriorityCard(
              task: task,
              isSelected: isSelected,
              isRecommended: task.isRecommended && !isCompleted,
              onTap: isCompleted ? null : () => _handleTaskSelection(index),
              displayMode: TaskCardDisplayMode.standard,
              animate: true,
              animationIndex: index,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDetailsSection(
      Color accentColor, TaskPrioritizationState state) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 16, color: accentColor),
              const SizedBox(width: 8),
              Text(
                'Why these tasks?',
                style: GoogleFonts.inter(
                  color: accentColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            state.reasoning,
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildActionButtons(Color accentColor, TaskPrioritizationState state) {
    final hasSelection = _selectedIndex != null;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Primary action row
          Row(
            children: [
              Expanded(
                child: NpButton(
                  label: hasSelection ? 'Start Task' : 'Start Top Pick',
                  type: NpButtonType.primary,
                  onPressed: () {
                    if (hasSelection) {
                      _handleTaskConfirmation();
                    } else {
                      _handleStartTopPick();
                    }
                  },
                ),
              ),
            ],
          ),

          // Atomize button
          if (widget.onAtomizeTask != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildAtomizeButton(accentColor, state),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),

          // Learn more toggle
          GestureDetector(
            onTap: () => setState(() => _showDetails = !_showDetails),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _showDetails ? 'Hide details' : 'Learn more',
                  style: GoogleFonts.inter(
                    color: accentColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Icon(
                  _showDetails ? Icons.expand_less : Icons.expand_more,
                  color: accentColor,
                  size: 18,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAtomizeButton(Color accentColor, TaskPrioritizationState state) {
    final taskName = _selectedIndex != null
        ? state.tasks[_selectedIndex!].title
        : state.tasks.first.title;

    return GestureDetector(
      onTap: widget.onAtomizeTask,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, size: 18, color: accentColor),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Atomize "${taskName.length > 20 ? '${taskName.substring(0, 20)}...' : taskName}"',
                style: GoogleFonts.inter(
                  color: accentColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection(Color accentColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 12),
          Text(
            'Quick Actions',
            style: GoogleFonts.inter(
              color: Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (widget.onScheduleTask != null)
                Expanded(
                  child: _buildQuickActionButton(
                    Icons.calendar_today,
                    'Schedule',
                    widget.onScheduleTask!,
                    accentColor,
                  ),
                ),
              if (widget.onScheduleTask != null && widget.onTakeNote != null)
                const SizedBox(width: 12),
              if (widget.onTakeNote != null)
                Expanded(
                  child: _buildQuickActionButton(
                    Icons.note_add,
                    'Take Note',
                    widget.onTakeNote!,
                    accentColor,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(
    IconData icon,
    String label,
    VoidCallback onTap,
    Color accentColor,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: accentColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
