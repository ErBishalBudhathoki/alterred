import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/prioritized_task_model.dart';
import '../core/task_priority_card.dart';
import '../core/countdown_timer_widget.dart';
import '../core/task_priority_animations.dart';
import '../state/task_prioritization_provider.dart';

/// Task prioritization widget optimized for voice mode
class VoiceTaskPrioritization extends ConsumerStatefulWidget {
  final Function(PrioritizedTaskModel, String) onTaskSelected;
  final Function(String)? onOptionSelected;
  final VoidCallback? onAddAnother;
  final VoidCallback? onConfirm;
  final bool enableAutoSelect;
  final int countdownSeconds;
  final bool showVoiceOptions;

  const VoiceTaskPrioritization({
    super.key,
    required this.onTaskSelected,
    this.onOptionSelected,
    this.onAddAnother,
    this.onConfirm,
    this.enableAutoSelect = false,
    this.countdownSeconds = 60,
    this.showVoiceOptions = true,
  });

  @override
  ConsumerState<VoiceTaskPrioritization> createState() =>
      _VoiceTaskPrioritizationState();
}

class _VoiceTaskPrioritizationState
    extends ConsumerState<VoiceTaskPrioritization>
    with TickerProviderStateMixin {
  int? _selectedIndex;
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(
      begin: 0,
      end: -8,
    ).animate(CurvedAnimation(
      parent: _floatController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _floatController.dispose();
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

  List<String> _generateVoiceOptions(TaskPrioritizationState state) {
    if (!state.hasData) return [];

    final options = <String>[];

    // Add task selection options
    for (int i = 0; i < state.tasks.length; i++) {
      final task = state.tasks[i];
      options.add('Start "${task.title}"');
    }

    // Add utility options
    options.add('Tell me more about these tasks');
    options.add('Refresh the task list');
    options.add('I\'ll choose later');

    return options;
  }

  void _handleVoiceOption(String option, TaskPrioritizationState state) {
    if (option.startsWith('Start "')) {
      // Extract task title and find matching task
      final title = option.substring(7, option.length - 1);
      final taskIndex = state.tasks.indexWhere((t) => t.title == title);
      if (taskIndex != -1) {
        final task = state.tasks[taskIndex];
        ref.read(taskPrioritizationProvider.notifier).selectTask(task, 'voice');
        widget.onTaskSelected(task, 'voice');
      }
    } else if (option.contains('more about')) {
      widget.onOptionSelected
          ?.call('Tell me more about why these tasks were prioritized');
    } else if (option.contains('Refresh')) {
      ref.read(taskPrioritizationProvider.notifier).refresh();
      widget.onOptionSelected?.call('Refreshing task priorities');
    } else if (option.contains('choose later')) {
      widget.onOptionSelected?.call('I\'ll choose a task later');
    }
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

    if (isCompleted) {
      return _buildCompletedState(state);
    }

    return _buildPrioritizationCard(state);
  }

  Widget _buildLoadingState() {
    return AnimatedBuilder(
      animation: _floatAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatAnimation.value),
          child: _buildVoiceCard(
            title: 'Analyzing Tasks',
            subtitle: 'Finding the best tasks for you...',
            icon: Icons.psychology,
            child: Column(
              children: [
                const SizedBox(height: 20),
                for (int i = 0; i < 3; i++) ...[
                  const TaskPriorityCardSkeleton(
                    displayMode: TaskCardDisplayMode.voice,
                  ),
                  if (i < 2) const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState(String error) {
    return AnimatedBuilder(
      animation: _floatAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatAnimation.value),
          child: _buildVoiceCard(
            title: 'Unable to Load Tasks',
            subtitle: error,
            icon: Icons.error_outline,
            iconColor: Colors.red,
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildVoiceButton(
                  'Retry',
                  Icons.refresh,
                  () {
                    ref.read(taskPrioritizationProvider.notifier).refresh();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return AnimatedBuilder(
      animation: _floatAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatAnimation.value),
          child: _buildVoiceCard(
            title: 'All Caught Up!',
            subtitle: 'No pending tasks to prioritize. Time for a break!',
            icon: Icons.check_circle_outline,
            iconColor: const Color(0xFF10B981),
            child: const SizedBox(height: 20),
          ),
        );
      },
    );
  }

  Widget _buildCompletedState(TaskPrioritizationState state) {
    final selectedTask = state.selectedTask;
    if (selectedTask == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _floatAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatAnimation.value),
          child: _buildVoiceCard(
            title: 'Task Selected',
            subtitle: 'Ready to start working on "${selectedTask.title}"',
            icon: Icons.check_circle,
            iconColor: const Color(0xFF10B981),
            child: Column(
              children: [
                const SizedBox(height: 20),
                TaskPriorityCard(
                  task: selectedTask,
                  isSelected: true,
                  displayMode: TaskCardDisplayMode.voice,
                  animate: false,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildVoiceButton(
                        'Start Working',
                        Icons.play_arrow,
                        widget.onConfirm,
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

  Widget _buildPrioritizationCard(TaskPrioritizationState state) {
    return Column(
      children: [
        // Main floating card
        AnimatedBuilder(
          animation: _floatAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _floatAnimation.value),
              child: _buildVoiceCard(
                title: 'Task Prioritization',
                subtitle: '${state.tasks.length} tasks ready for selection',
                icon: Icons.psychology,
                child: Column(
                  children: [
                    // Countdown timer
                    if (widget.enableAutoSelect) ...[
                      const SizedBox(height: 16),
                      CountdownTimerWidget(
                        totalSeconds: widget.countdownSeconds,
                        autoStart: widget.enableAutoSelect,
                        enableAutoSelect: widget.enableAutoSelect,
                        displayMode: CountdownDisplayMode.voice,
                        onComplete: _handleAutoSelect,
                        showControls: false,
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Task cards
                    for (int i = 0; i < state.tasks.length; i++) ...[
                      AnimatedTaskEntry(
                        index: i,
                        totalItems: state.tasks.length,
                        child: TaskPriorityCard(
                          task: state.tasks[i],
                          isSelected: _selectedIndex == i,
                          isRecommended: state.tasks[i].isRecommended,
                          onTap: () => _handleTaskSelection(i),
                          displayMode: TaskCardDisplayMode.voice,
                          animate: false,
                        ),
                      ),
                      if (i < state.tasks.length - 1)
                        const SizedBox(height: 16),
                    ],

                    const SizedBox(height: 24),

                    // Action buttons
                    _buildVoiceActionButtons(state),
                  ],
                ),
              ),
            );
          },
        ),

        // Voice options (if enabled)
        if (widget.showVoiceOptions) ...[
          const SizedBox(height: 24),
          _buildVoiceOptions(state),
        ],
      ],
    );
  }

  Widget _buildVoiceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    Color? iconColor,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE2B58D).withValues(alpha: 0.15),
            blurRadius: 40,
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1919).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFFE2B58D).withValues(alpha: 0.3),
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF6C7494).withValues(alpha: 0.1),
                  const Color(0xFFE2B58D).withValues(alpha: 0.05),
                ],
              ),
            ),
            child: Column(
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            (iconColor ?? const Color(0xFFE2B58D))
                                .withValues(alpha: 0.2),
                            const Color(0xFF6C7494).withValues(alpha: 0.2),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: iconColor ?? const Color(0xFFE2B58D),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                child,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceActionButtons(TaskPrioritizationState state) {
    final hasSelection = _selectedIndex != null;

    return Row(
      children: [
        if (hasSelection) ...[
          Expanded(
            child: _buildVoiceButton(
              'Start Task',
              Icons.play_arrow,
              _handleTaskConfirmation,
              isPrimary: true,
            ),
          ),
        ] else ...[
          Expanded(
            child: _buildVoiceButton(
              'Start Top Pick',
              Icons.star,
              _handleStartTopPick,
              isPrimary: true,
            ),
          ),
        ],
        if (widget.onAddAnother != null) ...[
          const SizedBox(width: 12),
          Expanded(
            child: _buildVoiceButton(
              'Add Another',
              Icons.add,
              widget.onAddAnother,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVoiceButton(
    String label,
    IconData icon,
    VoidCallback? onTap, {
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  colors: [Color(0xFFE2B58D), Color(0xFFD4A076)],
                )
              : null,
          color: isPrimary ? null : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPrimary
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.1),
          ),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: const Color(0xFFE2B58D).withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isPrimary
                  ? const Color(0xFF0F0505)
                  : Colors.white.withValues(alpha: 0.9),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                color: isPrimary
                    ? const Color(0xFF0F0505)
                    : Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceOptions(TaskPrioritizationState state) {
    final options = _generateVoiceOptions(state);

    return Column(
      children: options.map((option) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildVoiceOptionCard(option, state),
        );
      }).toList(),
    );
  }

  Widget _buildVoiceOptionCard(String option, TaskPrioritizationState state) {
    return GestureDetector(
      onTap: () => _handleVoiceOption(option, state),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE2B58D).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: Color(0xFFE2B58D),
                size: 16,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                option,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
