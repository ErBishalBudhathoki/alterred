import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/neuro_theme.dart';
import '../state/user_settings_store.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(userSettingsProvider);
    final notifier = ref.read(userSettingsProvider.notifier);

    return Scaffold(
      backgroundColor: NeuroDashboardTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Notifications",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // System Push Enabled Chip
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: settings.systemPushEnabled
                        ? NeuroDashboardTheme.accentRust.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: settings.systemPushEnabled
                          ? NeuroDashboardTheme.accentRust
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: settings.systemPushEnabled
                            ? NeuroDashboardTheme.accentBeige
                            : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        settings.systemPushEnabled
                            ? "System Push Enabled"
                            : "System Push Disabled",
                        style: TextStyle(
                          color: settings.systemPushEnabled
                              ? NeuroDashboardTheme.accentBeige
                              : Colors.grey,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Daily Management Section
              const _SectionHeader("DAILY MANAGEMENT"),
              const SizedBox(height: 16),
              _NotificationCard(
                icon: Icons.check_circle_outline,
                title: "Task Reminders",
                subtitle: "Executive function prompts",
                value: settings.taskRemindersEnabled,
                onChanged: (v) =>
                    notifier.update((s) => s.copyWith(taskRemindersEnabled: v)),
              ),
              const SizedBox(height: 12),
              _NotificationCard(
                icon: Icons.access_time,
                title: "Time Blindness",
                subtitle: "Gentle nudges every 15-30m",
                value: settings.timeBlindnessEnabled,
                onChanged: (v) =>
                    notifier.update((s) => s.copyWith(timeBlindnessEnabled: v)),
                hasDropdown: true,
              ),
              const SizedBox(height: 32),

              // Well-being Support Section
              const _SectionHeader("WELL-BEING SUPPORT"),
              const SizedBox(height: 16),
              _NotificationCard(
                icon: Icons.battery_charging_full,
                title: "Energy Alerts",
                subtitle: "Check-in on energy levels",
                value: settings.energyAlertsEnabled,
                onChanged: (v) =>
                    notifier.update((s) => s.copyWith(energyAlertsEnabled: v)),
              ),
              const SizedBox(height: 12),
              _NotificationCard(
                icon: Icons.psychology,
                title: "Decision Support",
                subtitle: "Prompts when stuck",
                value: settings.decisionSupportEnabled,
                onChanged: (v) => notifier
                    .update((s) => s.copyWith(decisionSupportEnabled: v)),
              ),
              const SizedBox(height: 12),
              _NotificationCard(
                icon: Icons.group,
                title: "Body Doubling",
                subtitle: "Live session invites",
                value: settings.bodyDoublingEnabled,
                onChanged: (v) =>
                    notifier.update((s) => s.copyWith(bodyDoublingEnabled: v)),
                hasDropdown: true,
              ),

              const Spacer(),
              const Center(
                child: Text(
                  "Notifications help you stay on track, but you can turn\nthem off anytime for a quieter experience.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Save Button
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: NeuroDashboardTheme.accentBeige,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.save, size: 20),
                    SizedBox(width: 8),
                    Text(
                      "Save Preferences",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () {
                    notifier.update((s) => s.copyWith(
                          taskRemindersEnabled: true,
                          timeBlindnessEnabled: true,
                          energyAlertsEnabled: false,
                          decisionSupportEnabled: true,
                          bodyDoublingEnabled: false,
                          systemPushEnabled: true,
                        ));
                  },
                  child: const Text(
                    "Reset to Default",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.5),
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool hasDropdown;

  const _NotificationCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.hasDropdown = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: NeuroDashboardTheme.accentBeige,
            activeTrackColor:
                NeuroDashboardTheme.accentBeige.withValues(alpha: 0.3),
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
          ),
          if (hasDropdown) ...[
            const SizedBox(width: 8),
            Icon(Icons.keyboard_arrow_down,
                color: Colors.white.withValues(alpha: 0.3)),
          ],
        ],
      ),
    );
  }
}
