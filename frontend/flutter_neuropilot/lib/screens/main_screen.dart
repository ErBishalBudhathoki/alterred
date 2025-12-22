import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/design_tokens.dart';
import '../state/navigation_state.dart';
import 'dashboard_screen.dart';
import 'metrics_screen.dart';
import 'observability_screen.dart';
import 'profile_screen.dart';
import 'external_brain_screen.dart';
import 'settings_screen.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(navigationIndexProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Screen mapping
    final screens = [
      const NeuroPilotDashboard(),
      const MetricsScreen(),
      const ObservabilityScreen(),
      const ProfileScreen(),
      const ExternalBrainScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      extendBody:
          false, // Prevent body from going behind the bottom bar to fix overlap
      body: IndexedStack(
        index: selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(DesignTokens.spacingLg),
          color: Colors.transparent, // Transparent container for SafeArea
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E293B)
                  : const Color(
                      0xFFF1F5F9), // Darker slate for dark mode, lighter slate for light mode for better contrast
              borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _NavBarItem(
                  icon: Icons.home_rounded,
                  index: 0,
                  selectedIndex: selectedIndex,
                  onTap: () =>
                      ref.read(navigationIndexProvider.notifier).state = 0,
                ),
                _NavBarItem(
                  icon: Icons.insights_rounded,
                  index: 1,
                  selectedIndex: selectedIndex,
                  onTap: () =>
                      ref.read(navigationIndexProvider.notifier).state = 1,
                ),
                _NavBarItem(
                  icon: Icons.monitor_heart_rounded,
                  index: 2,
                  selectedIndex: selectedIndex,
                  onTap: () =>
                      ref.read(navigationIndexProvider.notifier).state = 2,
                ),
                _NavBarItem(
                  icon: Icons.person_rounded,
                  index: 3,
                  selectedIndex: selectedIndex,
                  onTap: () =>
                      ref.read(navigationIndexProvider.notifier).state = 3,
                ),
                _NavBarItem(
                  icon: Icons.psychology_rounded,
                  index: 4,
                  selectedIndex: selectedIndex,
                  onTap: () =>
                      ref.read(navigationIndexProvider.notifier).state = 4,
                ),
                _NavBarItem(
                  icon: Icons.settings_rounded,
                  index: 5,
                  selectedIndex: selectedIndex,
                  onTap: () =>
                      ref.read(navigationIndexProvider.notifier).state = 5,
                ),
              ],
            ),
          ).animate().fadeIn(duration: 500.ms).slideY(begin: 1, end: 0),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final int index;
  final int selectedIndex;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.index,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = index == selectedIndex;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: MotionTokens.durationShort,
        curve: MotionTokens.curveAction,
        width: isSelected ? 56 : 48,
        height: isSelected ? 56 : 48,
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isSelected
              ? theme.colorScheme.onPrimary
              : (theme.brightness == Brightness.dark
                  ? const Color(0xFF94A3B8)
                  : const Color(
                      0xFF64748B)), // Slate 400 (dark) / Slate 500 (light) for better contrast
          size: 24,
        ),
      ),
    );
  }
}
