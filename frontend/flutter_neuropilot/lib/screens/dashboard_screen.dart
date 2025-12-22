import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../state/auth_state.dart';
import '../state/tasks_provider.dart';
import '../state/user_settings_store.dart';
import '../state/energy_store.dart';
import '../state/metrics_state.dart';
import '../core/components/np_avatar.dart';
import '../core/notion/widgets/notion_quick_capture.dart';
import 'quick_capture_modal.dart';
import 'notification_settings_screen.dart';
import 'create_task_screen.dart';
import 'chat_screen.dart';
import 'taskflow_agent_screen.dart';
import 'settings_screen.dart';
import 'time_perception_screen.dart';

// =============================================================================
// THEME & CONSTANTS
// =============================================================================
class DashTheme {
  // Core colors
  static const Color bg = Color(0xFF0A0A0F);
  static const Color surface = Color(0xFF12121A);
  static const Color surfaceLight = Color(0xFF1A1A24);

  // Accent colors
  static const Color primary = Color(0xFFFF6B35);
  static const Color accent = Color(0xFFE8B86D);
  static const Color success = Color(0xFF4ADE80);
  static const Color info = Color(0xFF60A5FA);
  static const Color warning = Color(0xFFFBBF24);
  static const Color danger = Color(0xFFEF4444);

  // Text colors
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFF6B35), Color(0xFFFF8F5A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFE8B86D), Color(0xFFF0D090)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// =============================================================================
// MAIN DASHBOARD WIDGET
// =============================================================================
class NeuroPilotDashboard extends ConsumerStatefulWidget {
  const NeuroPilotDashboard({super.key});

  @override
  ConsumerState<NeuroPilotDashboard> createState() =>
      _NeuroPilotDashboardState();
}

class _NeuroPilotDashboardState extends ConsumerState<NeuroPilotDashboard>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _pulseController;

  // Dashboard state
  int _currentEnergy = 5;
  int _tasksCompletedToday = 0;
  int _focusMinutesToday = 0;
  int _currentStreak = 0;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _loadDashboardData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    // Load energy history
    final energyStore = ref.read(energyStoreProvider);
    final history = await energyStore.getHistory();
    if (history.isNotEmpty && mounted) {
      setState(() {
        _currentEnergy = history.last['level'] as int? ?? 5;
      });
    }

    // Calculate tasks completed today
    final tasksAsync = ref.read(tasksProvider);
    tasksAsync.whenData((tasks) {
      final today = DateTime.now();
      final completedToday = tasks
          .where((t) =>
              t.status == 'completed' &&
              t.createdAt != null &&
              t.createdAt!.day == today.day &&
              t.createdAt!.month == today.month &&
              t.createdAt!.year == today.year)
          .length;

      if (mounted) {
        setState(() {
          _tasksCompletedToday = completedToday;
          _focusMinutesToday = completedToday * 25; // Estimate
          _currentStreak = completedToday > 0 ? 1 : 0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return Scaffold(
      backgroundColor: DashTheme.bg,
      body: Stack(
        children: [
          // Background gradient blobs
          const _BackgroundEffects(),

          // Main content
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: () async {
                await _loadDashboardData();
                ref.invalidate(tasksProvider);
              },
              color: DashTheme.primary,
              backgroundColor: DashTheme.surface,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Header
                  SliverToBoxAdapter(
                    child: _AnimatedSection(
                      controller: _fadeController,
                      delay: 0.0,
                      child: _buildHeader(),
                    ),
                  ),

                  // Quick Stats Row
                  SliverToBoxAdapter(
                    child: _AnimatedSection(
                      controller: _fadeController,
                      delay: 0.1,
                      child: _buildQuickStats(),
                    ),
                  ),

                  // Energy & Focus Card
                  SliverToBoxAdapter(
                    child: _AnimatedSection(
                      controller: _fadeController,
                      delay: 0.2,
                      child: _buildEnergyFocusCard(),
                    ),
                  ),

                  // Quick Actions
                  SliverToBoxAdapter(
                    child: _AnimatedSection(
                      controller: _fadeController,
                      delay: 0.3,
                      child: _buildQuickActions(),
                    ),
                  ),

                  // Today's Tasks
                  SliverToBoxAdapter(
                    child: _AnimatedSection(
                      controller: _fadeController,
                      delay: 0.4,
                      child: _buildTodaysTasks(),
                    ),
                  ),

                  // Notion Quick Capture
                  SliverToBoxAdapter(
                    child: _AnimatedSection(
                      controller: _fadeController,
                      delay: 0.45,
                      child: _buildNotionQuickCapture(),
                    ),
                  ),

                  // AI Assistant Card
                  SliverToBoxAdapter(
                    child: _AnimatedSection(
                      controller: _fadeController,
                      delay: 0.5,
                      child: _buildAssistantCard(),
                    ),
                  ),

                  // Bottom padding for nav bar
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 100),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // HEADER SECTION
  // ===========================================================================
  Widget _buildHeader() {
    final userAsync = ref.watch(authUserProvider);
    final settings = ref.watch(userSettingsProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: userAsync.when(
        data: (user) {
          if (user == null) return const SizedBox.shrink();

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .snapshots(),
            builder: (context, snapshot) {
              String firstName = 'Pilot';
              String? photoUrl = user.photoURL;

              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>?;
                if (data != null) {
                  firstName = data['firstName'] ??
                      data['first_name'] ??
                      data['name']?.toString().split(' ').first ??
                      user.displayName?.split(' ').first ??
                      'Pilot';
                  photoUrl =
                      data['photoUrl'] ?? data['photo_url'] ?? user.photoURL;
                }
              } else if (user.displayName != null) {
                firstName = user.displayName!.split(' ').first;
              }

              final hour = DateTime.now().hour;
              String greeting;
              IconData greetingIcon;
              if (hour < 12) {
                greeting = 'Good morning';
                greetingIcon = Icons.wb_sunny_outlined;
              } else if (hour < 17) {
                greeting = 'Good afternoon';
                greetingIcon = Icons.wb_cloudy_outlined;
              } else {
                greeting = 'Good evening';
                greetingIcon = Icons.nightlight_outlined;
              }

              return Row(
                children: [
                  // Avatar with status ring
                  Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: DashTheme.primaryGradient,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: DashTheme.bg,
                          ),
                          child: NpAvatar(
                            name: firstName,
                            imageUrl: photoUrl,
                            characterStyle: settings.characterStyle,
                            size: 48,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: DashTheme.success,
                            shape: BoxShape.circle,
                            border: Border.all(color: DashTheme.bg, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),

                  // Greeting
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(greetingIcon,
                                color: DashTheme.accent, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              greeting,
                              style: const TextStyle(
                                color: DashTheme.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          firstName,
                          style: const TextStyle(
                            color: DashTheme.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Action buttons
                  _IconBtn(
                    icon: Icons.notifications_outlined,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationSettingsScreen(),
                      ),
                    ),
                    badge: true,
                  ),
                  const SizedBox(width: 8),
                  _IconBtn(
                    icon: Icons.settings_outlined,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
        loading: () => const SizedBox(height: 64),
        error: (_, __) => const SizedBox(height: 64),
      ),
    );
  }

  // ===========================================================================
  // QUICK STATS ROW
  // ===========================================================================
  Widget _buildQuickStats() {
    final metricsAsync = ref.watch(metricsProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: metricsAsync.when(
        data: (metrics) {
          final tasksCompleted =
              metrics['tasks_completed'] ?? _tasksCompletedToday;
          final avgStress =
              (metrics['avg_stress_level'] as num?)?.toDouble() ?? 0.0;

          return Row(
            children: [
              Expanded(
                child: _StatChip(
                  icon: Icons.local_fire_department,
                  iconColor: DashTheme.primary,
                  value: '$_currentStreak',
                  label: 'Streak',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatChip(
                  icon: Icons.check_circle_outline,
                  iconColor: DashTheme.success,
                  value: '$tasksCompleted',
                  label: 'Done',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatChip(
                  icon: Icons.psychology_outlined,
                  iconColor: avgStress > 7
                      ? DashTheme.danger
                      : avgStress > 4
                          ? DashTheme.warning
                          : DashTheme.info,
                  value: avgStress > 0 ? avgStress.toStringAsFixed(1) : '-',
                  label: 'Stress',
                ),
              ),
            ],
          );
        },
        loading: () => Row(
          children: [
            Expanded(
              child: _StatChip(
                icon: Icons.local_fire_department,
                iconColor: DashTheme.primary,
                value: '$_currentStreak',
                label: 'Streak',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatChip(
                icon: Icons.check_circle_outline,
                iconColor: DashTheme.success,
                value: '$_tasksCompletedToday',
                label: 'Done',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatChip(
                icon: Icons.timer_outlined,
                iconColor: DashTheme.info,
                value: '${_focusMinutesToday}m',
                label: 'Focus',
              ),
            ),
          ],
        ),
        error: (_, __) => Row(
          children: [
            Expanded(
              child: _StatChip(
                icon: Icons.local_fire_department,
                iconColor: DashTheme.primary,
                value: '$_currentStreak',
                label: 'Streak',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatChip(
                icon: Icons.check_circle_outline,
                iconColor: DashTheme.success,
                value: '$_tasksCompletedToday',
                label: 'Done',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatChip(
                icon: Icons.timer_outlined,
                iconColor: DashTheme.info,
                value: '${_focusMinutesToday}m',
                label: 'Focus',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // ENERGY & FOCUS CARD
  // ===========================================================================
  Widget _buildEnergyFocusCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: _GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Energy Level',
                  style: TextStyle(
                    color: DashTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                GestureDetector(
                  onTap: () => _showEnergyPicker(),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: DashTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_outlined,
                            color: DashTheme.primary, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Update',
                          style: TextStyle(
                            color: DashTheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Energy bar
            Row(
              children: [
                _EnergyIcon(level: _currentEnergy),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _getEnergyLabel(_currentEnergy),
                            style: const TextStyle(
                              color: DashTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '$_currentEnergy/10',
                            style: const TextStyle(
                              color: DashTheme.textMuted,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _EnergyBar(level: _currentEnergy),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Suggestion based on energy
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: DashTheme.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    color: DashTheme.accent,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _getEnergySuggestion(_currentEnergy),
                      style: const TextStyle(
                        color: DashTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getEnergyLabel(int level) {
    if (level <= 2) return 'Very Low';
    if (level <= 4) return 'Low';
    if (level <= 6) return 'Moderate';
    if (level <= 8) return 'Good';
    return 'Excellent';
  }

  String _getEnergySuggestion(int level) {
    if (level <= 3) {
      return 'Consider low-effort tasks or take a short break.';
    } else if (level <= 5) {
      return 'Good for routine tasks. Save complex work for later.';
    } else if (level <= 7) {
      return 'Great time for focused work. Tackle important tasks!';
    }
    return 'Peak energy! Perfect for challenging tasks.';
  }

  void _showEnergyPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _EnergyPickerSheet(
        currentLevel: _currentEnergy,
        onSelect: (level) async {
          final energyStore = ref.read(energyStoreProvider);
          await energyStore.logEnergy(level);
          setState(() => _currentEnergy = level);
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }

  // ===========================================================================
  // QUICK ACTIONS
  // ===========================================================================
  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              color: DashTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.mic,
                  label: 'Voice\nCapture',
                  gradient: DashTheme.primaryGradient,
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) => const QuickCaptureModal(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.add_task,
                  label: 'New\nTask',
                  gradient: DashTheme.accentGradient,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreateTaskScreen(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.account_tree,
                  label: 'Task\nFlow',
                  color: DashTheme.info,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TaskFlowAgentScreen(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.psychology,
                  label: 'Task\nPriority',
                  color: const Color(0xFFE2B58D),
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/task-prioritization',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.timer,
                  label: 'Focus\nTimer',
                  color: DashTheme.success,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FocusSessionScreen(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TODAY'S TASKS
  // ===========================================================================
  Widget _buildTodaysTasks() {
    final tasksAsync = ref.watch(tasksProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Today's Tasks",
                style: TextStyle(
                  color: DashTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreateTaskScreen(),
                    ),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: DashTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, color: DashTheme.primary, size: 18),
                      SizedBox(width: 4),
                      Text(
                        'Add Task',
                        style: TextStyle(
                          color: DashTheme.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          tasksAsync.when(
            data: (tasks) {
              // Filter for pending tasks, sorted by priority
              final pendingTasks = tasks
                  .where((t) => t.status == 'pending')
                  .toList()
                ..sort((a, b) {
                  const priorityOrder = {
                    'critical': 0,
                    'high': 1,
                    'medium': 2,
                    'low': 3
                  };
                  return (priorityOrder[a.priority.toLowerCase()] ?? 3)
                      .compareTo(priorityOrder[b.priority.toLowerCase()] ?? 3);
                });

              if (pendingTasks.isEmpty) {
                return _EmptyTasksCard(
                  onAddTask: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreateTaskScreen(),
                    ),
                  ),
                );
              }

              return Column(
                children: pendingTasks.take(4).map((task) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _TaskCard(
                      task: task,
                      onComplete: () async {
                        final notifier = ref.read(tasksProvider.notifier);
                        await notifier.updateTask(
                          task.copyWith(status: 'completed'),
                        );
                        setState(() => _tasksCompletedToday++);
                      },
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(
                  color: DashTheme.primary,
                  strokeWidth: 2,
                ),
              ),
            ),
            error: (_, __) => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Unable to load tasks',
                  style: TextStyle(color: DashTheme.textMuted),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // NOTION QUICK CAPTURE
  // ===========================================================================
  Widget _buildNotionQuickCapture() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Quick Capture',
                style: TextStyle(
                  color: DashTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.pushNamed(context, '/notion-settings');
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome,
                          color: Color(0xFF6366F1), size: 18),
                      SizedBox(width: 4),
                      Text(
                        'Notion',
                        style: TextStyle(
                          color: Color(0xFF6366F1),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const NotionQuickCaptureWidget(),
        ],
      ),
    );
  }

  // ===========================================================================
  // AI ASSISTANT CARD
  // ===========================================================================
  Widget _buildAssistantCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: _GlassCard(
        gradient: LinearGradient(
          colors: [
            DashTheme.primary.withValues(alpha: 0.15),
            DashTheme.accent.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        child: Row(
          children: [
            // AI Avatar with pulse
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: DashTheme.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: DashTheme.primary.withValues(
                            alpha: 0.3 + (_pulseController.value * 0.2)),
                        blurRadius: 12 + (_pulseController.value * 8),
                        spreadRadius: _pulseController.value * 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 28,
                  ),
                );
              },
            ),
            const SizedBox(width: 16),

            // Text content
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Assistant Ready',
                    style: TextStyle(
                      color: DashTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Chat or speak to get help with tasks, decisions, and focus.',
                    style: TextStyle(
                      color: DashTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Action buttons
            Column(
              children: [
                _MiniActionBtn(
                  icon: Icons.chat_bubble_outline,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ChatScreen(initialVoiceMode: false),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _MiniActionBtn(
                  icon: Icons.mic_none,
                  isPrimary: true,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ChatScreen(initialVoiceMode: true),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// REUSABLE COMPONENTS
// =============================================================================

class _GlassCard extends StatelessWidget {
  final Widget child;
  final Gradient? gradient;

  const _GlassCard({required this.child, this.gradient});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: gradient,
            color: gradient == null
                ? DashTheme.surface.withValues(alpha: 0.8)
                : null,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool badge;

  const _IconBtn({
    required this.icon,
    required this.onTap,
    this.badge = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: DashTheme.surfaceLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: DashTheme.textSecondary, size: 22),
          ),
          if (badge)
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: DashTheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatChip({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: DashTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: DashTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: DashTheme.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EnergyIcon extends StatelessWidget {
  final int level;

  const _EnergyIcon({required this.level});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;

    if (level <= 3) {
      color = DashTheme.danger;
      icon = Icons.battery_1_bar;
    } else if (level <= 5) {
      color = DashTheme.warning;
      icon = Icons.battery_3_bar;
    } else if (level <= 7) {
      color = DashTheme.info;
      icon = Icons.battery_5_bar;
    } else {
      color = DashTheme.success;
      icon = Icons.battery_full;
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: 26),
    );
  }
}

class _EnergyBar extends StatelessWidget {
  final int level;

  const _EnergyBar({required this.level});

  @override
  Widget build(BuildContext context) {
    Color barColor;
    if (level <= 3) {
      barColor = DashTheme.danger;
    } else if (level <= 5) {
      barColor = DashTheme.warning;
    } else if (level <= 7) {
      barColor = DashTheme.info;
    } else {
      barColor = DashTheme.success;
    }

    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: DashTheme.surfaceLight,
        borderRadius: BorderRadius.circular(4),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: level / 10,
        child: Container(
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: barColor.withValues(alpha: 0.4),
                blurRadius: 6,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Gradient? gradient;
  final Color? color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    this.gradient,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: gradient,
          color: color?.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (color ?? Colors.white).withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: gradient != null ? Colors.white : color,
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: gradient != null
                    ? Colors.white.withValues(alpha: 0.9)
                    : DashTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final dynamic task;
  final VoidCallback onComplete;

  const _TaskCard({required this.task, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    Color priorityColor;
    switch (task.priority.toLowerCase()) {
      case 'critical':
        priorityColor = DashTheme.danger;
        break;
      case 'high':
        priorityColor = DashTheme.primary;
        break;
      case 'medium':
        priorityColor = DashTheme.warning;
        break;
      default:
        priorityColor = DashTheme.info;
    }

    final dateStr =
        task.dueDate != null ? DateFormat('MMM d').format(task.dueDate!) : '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DashTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          // Checkbox
          GestureDetector(
            onTap: onComplete,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: priorityColor.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: priorityColor.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Task info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: const TextStyle(
                    color: DashTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (task.description != null && task.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      task.description!,
                      style: const TextStyle(
                        color: DashTheme.textMuted,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),

          // Priority & date
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: priorityColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  task.priority.toUpperCase(),
                  style: TextStyle(
                    color: priorityColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (dateStr.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    dateStr,
                    style: const TextStyle(
                      color: DashTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyTasksCard extends StatelessWidget {
  final VoidCallback onAddTask;

  const _EmptyTasksCard({required this.onAddTask});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: DashTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.check_circle_outline,
            color: DashTheme.success.withValues(alpha: 0.5),
            size: 40,
          ),
          const SizedBox(height: 12),
          const Text(
            'All caught up!',
            style: TextStyle(
              color: DashTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'No pending tasks. Add a new one to get started.',
            style: TextStyle(
              color: DashTheme.textMuted,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onAddTask,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: DashTheme.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Add Task',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniActionBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;

  const _MiniActionBtn({
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          gradient: isPrimary ? DashTheme.primaryGradient : null,
          color: isPrimary ? null : DashTheme.surfaceLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isPrimary ? Colors.white : DashTheme.textSecondary,
          size: 18,
        ),
      ),
    );
  }
}

// =============================================================================
// ANIMATION HELPERS
// =============================================================================

class _AnimatedSection extends StatelessWidget {
  final AnimationController controller;
  final double delay;
  final Widget child;

  const _AnimatedSection({
    required this.controller,
    required this.delay,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.15),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Interval(delay, delay + 0.4, curve: Curves.easeOutCubic),
      )),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
          parent: controller,
          curve: Interval(delay, delay + 0.4, curve: Curves.easeOut),
        )),
        child: child,
      ),
    );
  }
}

// =============================================================================
// BACKGROUND EFFECTS
// =============================================================================

class _BackgroundEffects extends StatelessWidget {
  const _BackgroundEffects();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Top-left blob
        Positioned(
          top: -80,
          left: -80,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: DashTheme.primary.withValues(alpha: 0.15),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
        // Right blob
        Positioned(
          top: 200,
          right: -60,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: DashTheme.accent.withValues(alpha: 0.1),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
        // Bottom blob
        Positioned(
          bottom: 100,
          left: 40,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: DashTheme.info.withValues(alpha: 0.08),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// ENERGY PICKER BOTTOM SHEET
// =============================================================================

class _EnergyPickerSheet extends StatefulWidget {
  final int currentLevel;
  final Function(int) onSelect;

  const _EnergyPickerSheet({
    required this.currentLevel,
    required this.onSelect,
  });

  @override
  State<_EnergyPickerSheet> createState() => _EnergyPickerSheetState();
}

class _EnergyPickerSheetState extends State<_EnergyPickerSheet> {
  late int _selectedLevel;

  @override
  void initState() {
    super.initState();
    _selectedLevel = widget.currentLevel;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: const BoxDecoration(
        color: DashTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: DashTheme.textMuted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          const Text(
            'How\'s your energy?',
            style: TextStyle(
              color: DashTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This helps match tasks to your current state',
            style: TextStyle(
              color: DashTheme.textMuted,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),

          // Energy slider
          Row(
            children: [
              const Icon(Icons.battery_1_bar,
                  color: DashTheme.danger, size: 20),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: _getEnergyColor(_selectedLevel),
                    inactiveTrackColor: DashTheme.surfaceLight,
                    thumbColor: _getEnergyColor(_selectedLevel),
                    overlayColor:
                        _getEnergyColor(_selectedLevel).withValues(alpha: 0.2),
                    trackHeight: 8,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 12,
                    ),
                  ),
                  child: Slider(
                    value: _selectedLevel.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    onChanged: (value) {
                      setState(() => _selectedLevel = value.round());
                    },
                  ),
                ),
              ),
              const Icon(Icons.battery_full,
                  color: DashTheme.success, size: 20),
            ],
          ),

          const SizedBox(height: 16),

          // Level display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: _getEnergyColor(_selectedLevel).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$_selectedLevel',
                  style: TextStyle(
                    color: _getEnergyColor(_selectedLevel),
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _getEnergyText(_selectedLevel),
                  style: const TextStyle(
                    color: DashTheme.textSecondary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Confirm button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => widget.onSelect(_selectedLevel),
              style: ElevatedButton.styleFrom(
                backgroundColor: DashTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Update Energy',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getEnergyColor(int level) {
    if (level <= 3) return DashTheme.danger;
    if (level <= 5) return DashTheme.warning;
    if (level <= 7) return DashTheme.info;
    return DashTheme.success;
  }

  String _getEnergyText(int level) {
    if (level <= 2) return 'Very Low';
    if (level <= 4) return 'Low';
    if (level <= 6) return 'Moderate';
    if (level <= 8) return 'Good';
    return 'Excellent';
  }
}
