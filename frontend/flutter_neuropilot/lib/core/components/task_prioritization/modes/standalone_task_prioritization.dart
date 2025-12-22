import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/prioritized_task_model.dart';
import '../core/task_priority_card.dart';
import '../core/countdown_timer_widget.dart';
import '../core/task_priority_animations.dart';
import '../state/task_prioritization_provider.dart';
import '../../np_button.dart';
import '../../np_app_bar.dart';

/// Standalone full-screen task prioritization experience
class StandaloneTaskPrioritization extends ConsumerStatefulWidget {
  final Function(PrioritizedTaskModel, String) onTaskSelected;
  final VoidCallback? onScheduleTask;
  final VoidCallback? onTakeNote;
  final VoidCallback? onAtomizeTask;
  final VoidCallback? onBack;
  final bool enableAutoSelect;
  final int countdownSeconds;

  const StandaloneTaskPrioritization({
    super.key,
    required this.onTaskSelected,
    this.onScheduleTask,
    this.onTakeNote,
    this.onAtomizeTask,
    this.onBack,
    this.enableAutoSelect = true,
    this.countdownSeconds = 60,
  });

  @override
  ConsumerState<StandaloneTaskPrioritization> createState() =>
      _StandaloneTaskPrioritizationState();
}

class _StandaloneTaskPrioritizationState
    extends ConsumerState<StandaloneTaskPrioritization>
    with TickerProviderStateMixin {
  int? _selectedIndex;
  bool _showAllDetails = false;
  late AnimationController _backgroundController;
  late AnimationController _entranceController;
  late Animation<double> _backgroundAnimation;

  @override
  void initState() {
    super.initState();

    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _backgroundAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _backgroundController,
      curve: Curves.easeInOut,
    ));

    // Start entrance animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _entranceController.forward();
    });

    // Auto-fetch prioritization if not already loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(taskPrioritizationProvider);
      if (!state.hasData && !state.isLoading) {
        ref.read(taskPrioritizationProvider.notifier).fetchPrioritizedTasks();
      }
    });
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  void _handleTaskSelection(int index) {
    setState(() {
      _selectedIndex = _selectedIndex == index ? null : index;
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

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: NpAppBar(
        title: 'Task Prioritization',
        showBack: widget.onBack != null,
        actions: [
          if (!isCompleted)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.read(taskPrioritizationProvider.notifier).refresh();
              },
              tooltip: 'Refresh priorities',
            ),
        ],
      ),
      body: Stack(
        children: [
          // Animated background
          _buildAnimatedBackground(),

          // Main content
          SafeArea(
            child: _buildMainContent(state, isCompleted),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _backgroundAnimation,
      builder: (context, child) {
        return Stack(
          children: [
            // Base gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0A0A0F),
                    Color(0xFF12121A),
                    Color(0xFF1A1A24),
                  ],
                ),
              ),
            ),

            // Floating orbs
            Positioned(
              top: 100 + (50 * _backgroundAnimation.value),
              left: 50 + (30 * _backgroundAnimation.value),
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFE2B58D).withValues(alpha: 0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                  child: Container(),
                ),
              ),
            ),

            Positioned(
              bottom: 150 - (40 * _backgroundAnimation.value),
              right: 80 - (20 * _backgroundAnimation.value),
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF6C7494).withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                  child: Container(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMainContent(TaskPrioritizationState state, bool isCompleted) {
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

    return _buildPrioritizationContent(state);
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFE2B58D).withValues(alpha: 0.2),
                  const Color(0xFF6C7494).withValues(alpha: 0.2),
                ],
              ),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFE2B58D),
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Analyzing Your Tasks',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Finding the perfect tasks for your current energy level...',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.white60,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 24),
            Text(
              'Unable to Load Tasks',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              error,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                NpButton(
                  label: 'Retry',
                  icon: Icons.refresh,
                  type: NpButtonType.primary,
                  onPressed: () {
                    ref.read(taskPrioritizationProvider.notifier).refresh();
                  },
                ),
                const SizedBox(width: 16),
                if (widget.onBack != null)
                  NpButton(
                    label: 'Go Back',
                    icon: Icons.arrow_back,
                    type: NpButtonType.secondary,
                    onPressed: widget.onBack,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF10B981).withValues(alpha: 0.2),
                  const Color(0xFF059669).withValues(alpha: 0.2),
                ],
              ),
            ),
            child: const Icon(
              Icons.check_circle_outline,
              size: 60,
              color: Color(0xFF10B981),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'All Caught Up!',
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No pending tasks to prioritize.\nTime to take a well-deserved break!',
            style: GoogleFonts.inter(
              fontSize: 18,
              color: Colors.white60,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          if (widget.onBack != null)
            NpButton(
              label: 'Back to Dashboard',
              icon: Icons.dashboard,
              type: NpButtonType.primary,
              onPressed: widget.onBack,
            ),
        ],
      ),
    );
  }

  Widget _buildCompletedState(TaskPrioritizationState state) {
    final selectedTask = state.selectedTask;
    if (selectedTask == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),

          // Success icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF10B981).withValues(alpha: 0.2),
                  const Color(0xFF059669).withValues(alpha: 0.2),
                ],
              ),
            ),
            child: const Icon(
              Icons.check_circle,
              size: 50,
              color: Color(0xFF10B981),
            ),
          ),

          const SizedBox(height: 32),

          Text(
            'Task Selected!',
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 16),

          Text(
            'Ready to start working on:',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.white60,
            ),
          ),

          const SizedBox(height: 32),

          // Selected task card
          TaskPriorityCard(
            task: selectedTask,
            isSelected: true,
            displayMode: TaskCardDisplayMode.detailed,
            animate: false,
            showDescription: true,
          ),

          const SizedBox(height: 32),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: NpButton(
                  label: 'Start Working',
                  icon: Icons.play_arrow,
                  type: NpButtonType.primary,
                  onPressed: () {
                    // Navigate to focus mode or task details
                    widget.onBack?.call();
                  },
                ),
              ),
              const SizedBox(width: 16),
              if (widget.onAtomizeTask != null)
                Expanded(
                  child: NpButton(
                    label: 'Atomize Task',
                    icon: Icons.auto_awesome,
                    type: NpButtonType.secondary,
                    onPressed: widget.onAtomizeTask,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Additional actions
          Row(
            children: [
              if (widget.onScheduleTask != null)
                Expanded(
                  child: NpButton(
                    label: 'Schedule',
                    icon: Icons.calendar_today,
                    type: NpButtonType.secondary,
                    onPressed: widget.onScheduleTask,
                  ),
                ),
              if (widget.onScheduleTask != null && widget.onTakeNote != null)
                const SizedBox(width: 12),
              if (widget.onTakeNote != null)
                Expanded(
                  child: NpButton(
                    label: 'Take Note',
                    icon: Icons.note_add,
                    type: NpButtonType.secondary,
                    onPressed: widget.onTakeNote,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrioritizationContent(TaskPrioritizationState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section
          _buildHeaderSection(state),

          const SizedBox(height: 32),

          // Countdown timer (if enabled)
          if (widget.enableAutoSelect) _buildCountdownSection(),

          const SizedBox(height: 24),

          // Task cards
          _buildTaskCardsSection(state),

          const SizedBox(height: 32),

          // Details section
          _buildDetailsSection(state),

          const SizedBox(height: 32),

          // Action buttons
          _buildActionSection(state),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(TaskPrioritizationState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Prioritized Tasks',
          style: GoogleFonts.inter(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'I\'ve selected ${state.tasks.length} tasks from your ${state.originalTaskCount} pending tasks based on your current energy and priorities.',
          style: GoogleFonts.inter(
            fontSize: 16,
            color: Colors.white70,
            height: 1.5,
          ),
        ),

        const SizedBox(height: 24),

        // Stats row
        Row(
          children: [
            _buildStatCard(
              'Tasks Selected',
              '${state.tasks.length}',
              Icons.task_alt,
              const Color(0xFFE2B58D),
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              'Total Tasks',
              '${state.originalTaskCount}',
              Icons.list,
              const Color(0xFF6C7494),
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              'Recommended',
              state.tasks.where((t) => t.isRecommended).length.toString(),
              Icons.star,
              const Color(0xFFFBBF24),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountdownSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE2B58D).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFFE2B58D).withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.timer,
                color: Color(0xFFE2B58D),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Auto-Selection Timer',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          CountdownTimerWidget(
            totalSeconds: widget.countdownSeconds,
            autoStart: widget.enableAutoSelect,
            enableAutoSelect: widget.enableAutoSelect,
            displayMode: CountdownDisplayMode.detailed,
            onComplete: _handleAutoSelect,
            showControls: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCardsSection(TaskPrioritizationState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select a Task to Focus On',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        for (int i = 0; i < state.tasks.length; i++) ...[
          AnimatedTaskEntry(
            index: i,
            totalItems: state.tasks.length,
            child: TaskPriorityCard(
              task: state.tasks[i],
              isSelected: _selectedIndex == i,
              isRecommended: state.tasks[i].isRecommended,
              onTap: () => _handleTaskSelection(i),
              displayMode: TaskCardDisplayMode.detailed,
              showDescription: true,
              animate: false,
            ),
          ),
          if (i < state.tasks.length - 1) const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildDetailsSection(TaskPrioritizationState state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    size: 20,
                    color: Color(0xFFE2B58D),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Prioritization Reasoning',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFE2B58D),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => setState(() => _showAllDetails = !_showAllDetails),
                child: Row(
                  children: [
                    Text(
                      _showAllDetails ? 'Show Less' : 'Show More',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFFE2B58D),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Icon(
                      _showAllDetails ? Icons.expand_less : Icons.expand_more,
                      color: const Color(0xFFE2B58D),
                      size: 18,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            state.reasoning,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white70,
              height: 1.5,
            ),
            maxLines: _showAllDetails ? null : 3,
            overflow: _showAllDetails ? null : TextOverflow.ellipsis,
          ),
          if (_showAllDetails) ...[
            const SizedBox(height: 20),
            Divider(color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 16),

            // Additional details
            Text(
              'Task Analysis',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),

            for (final task in state.tasks) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.title,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Text(
                          'Score: ${task.priorityScore.toStringAsFixed(1)}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFFE2B58D),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task.priorityReasoning,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildActionSection(TaskPrioritizationState state) {
    final hasSelection = _selectedIndex != null;

    return Column(
      children: [
        // Primary actions
        Row(
          children: [
            Expanded(
              child: NpButton(
                label: hasSelection ? 'Start Selected Task' : 'Start Top Pick',
                icon: hasSelection ? Icons.play_arrow : Icons.star,
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

        const SizedBox(height: 16),

        // Secondary actions
        Row(
          children: [
            if (widget.onAtomizeTask != null)
              Expanded(
                child: NpButton(
                  label: 'Atomize Task',
                  icon: Icons.auto_awesome,
                  type: NpButtonType.secondary,
                  onPressed: widget.onAtomizeTask,
                ),
              ),
            if (widget.onAtomizeTask != null &&
                (widget.onScheduleTask != null || widget.onTakeNote != null))
              const SizedBox(width: 12),
            if (widget.onScheduleTask != null)
              Expanded(
                child: NpButton(
                  label: 'Schedule',
                  icon: Icons.calendar_today,
                  type: NpButtonType.secondary,
                  onPressed: widget.onScheduleTask,
                ),
              ),
            if (widget.onScheduleTask != null && widget.onTakeNote != null)
              const SizedBox(width: 12),
            if (widget.onTakeNote != null)
              Expanded(
                child: NpButton(
                  label: 'Take Note',
                  icon: Icons.note_add,
                  type: NpButtonType.secondary,
                  onPressed: widget.onTakeNote,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
