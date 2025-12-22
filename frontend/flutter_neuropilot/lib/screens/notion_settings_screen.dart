import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/design_tokens.dart';
import '../core/components/np_card.dart';
import '../state/notion_provider.dart';
import '../core/notion/models/notion_models.dart';

class NotionSettingsScreen extends ConsumerWidget {
  const NotionSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notionSettingsProvider);
    final connection = ref.watch(notionConnectionProvider);
    final availableTemplates = ref.watch(availableTemplatesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notion Settings'),
        backgroundColor: DesignTokens.primary,
      ),
      body: connection.when(
        data: (conn) => _buildSettingsContent(
            context, ref, settings, conn, availableTemplates),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: DesignTokens.error),
              const SizedBox(height: DesignTokens.spacingMd),
              Text('Error loading Notion connection',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: DesignTokens.spacingSm),
              Text(error.toString(),
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsContent(
    BuildContext context,
    WidgetRef ref,
    NotionSettings settings,
    NotionConnection connection,
    List<Map<String, dynamic>> availableTemplates,
  ) {
    if (!connection.isConnected) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.link_off,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: DesignTokens.spacingMd),
            Text(
              'Not Connected to Notion',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: DesignTokens.spacingSm),
            Text(
              'Please connect to Notion from the main settings screen first.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DesignTokens.spacingLg),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Settings'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(DesignTokens.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Connection Status
          _buildConnectionStatus(context, connection),
          const SizedBox(height: DesignTokens.spacingLg),

          // Sync Settings
          _buildSyncSettings(context, ref, settings),
          const SizedBox(height: DesignTokens.spacingLg),

          // Template Settings
          _buildTemplateSettings(context, ref, settings, availableTemplates),
          const SizedBox(height: DesignTokens.spacingLg),

          // Quick Actions
          _buildQuickActions(context, ref),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus(
      BuildContext context, NotionConnection connection) {
    return NpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: DesignTokens.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: DesignTokens.success,
                  size: 24,
                ),
              ),
              const SizedBox(width: DesignTokens.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connected to Notion',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: DesignTokens.success,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (connection.workspaceName != null)
                      Text(
                        connection.workspaceName!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spacingMd),
          _buildInfoRow(
              context, 'Connected', _formatDateTime(connection.connectedAt)),
          if (connection.expiresAt != null)
            _buildInfoRow(
                context, 'Expires', _formatDateTime(connection.expiresAt)),
          _buildInfoRow(context, 'Bot ID', connection.botId ?? 'Unknown'),
          _buildInfoRow(context, 'Capabilities',
              '${connection.capabilities.length} features'),
        ],
      ),
    );
  }

  Widget _buildSyncSettings(
      BuildContext context, WidgetRef ref, NotionSettings settings) {
    return NpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sync Settings',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: DesignTokens.spacingMd),
          _buildSwitchTile(
            context,
            'Auto Sync',
            'Automatically sync data in the background',
            Icons.sync,
            settings.autoSync,
            (value) =>
                ref.read(notionSettingsProvider.notifier).setAutoSync(value),
          ),
          const Divider(),
          _buildSwitchTile(
            context,
            'Sync Metrics',
            'Export daily metrics to Notion database',
            Icons.analytics_outlined,
            settings.syncMetrics,
            (value) =>
                ref.read(notionSettingsProvider.notifier).setSyncMetrics(value),
          ),
          _buildSwitchTile(
            context,
            'Sync Tasks',
            'Sync tasks between NeuroPilot and Notion',
            Icons.task_outlined,
            settings.syncTasks,
            (value) =>
                ref.read(notionSettingsProvider.notifier).setSyncTasks(value),
          ),
          _buildSwitchTile(
            context,
            'Sync Memory',
            'Backup memory chunks to Notion',
            Icons.memory_outlined,
            settings.syncMemory,
            (value) =>
                ref.read(notionSettingsProvider.notifier).setSyncMemory(value),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateSettings(
    BuildContext context,
    WidgetRef ref,
    NotionSettings settings,
    List<Map<String, dynamic>> availableTemplates,
  ) {
    return NpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ADHD Templates',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                '${settings.enabledTemplates.length}/${availableTemplates.length} enabled',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spacingSm),
          Text(
            'Enable templates for quick creation of ADHD-focused pages',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: DesignTokens.spacingMd),
          ...availableTemplates.map((templateData) {
            final template = templateData['template'] as NotionTemplate;
            final isEnabled = settings.enabledTemplates.contains(template);

            return _buildTemplateTile(
              context,
              templateData['name'] as String,
              templateData['description'] as String,
              templateData['icon'] as String,
              isEnabled,
              () => ref
                  .read(notionSettingsProvider.notifier)
                  .toggleTemplate(template),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, WidgetRef ref) {
    return NpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: DesignTokens.spacingMd),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _syncNow(context, ref),
                  icon: const Icon(Icons.sync, size: 18),
                  label: const Text('Sync Now'),
                ),
              ),
              const SizedBox(width: DesignTokens.spacingSm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _exportMetrics(context, ref),
                  icon: const Icon(Icons.upload, size: 18),
                  label: const Text('Export Metrics'),
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spacingSm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _createQuickNote(context, ref),
                  icon: const Icon(Icons.note_add, size: 18),
                  label: const Text('Quick Note'),
                ),
              ),
              const SizedBox(width: DesignTokens.spacingSm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openNotionWorkspace(context),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Open Notion'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          Text(
            value ?? 'Unknown',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: DesignTokens.success,
      ),
    );
  }

  Widget _buildTemplateTile(
    BuildContext context,
    String name,
    String description,
    String icon,
    bool isEnabled,
    VoidCallback onToggle,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isEnabled
              ? DesignTokens.success.withValues(alpha: 0.1)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            icon,
            style: const TextStyle(fontSize: 20),
          ),
        ),
      ),
      title: Text(name),
      subtitle: Text(description),
      trailing: Switch(
        value: isEnabled,
        onChanged: (_) => onToggle(),
        activeThumbColor: DesignTokens.success,
      ),
    ).animate(target: isEnabled ? 1 : 0).fadeIn();
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'Unknown';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _syncNow(BuildContext context, WidgetRef ref) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Perform sync (this would trigger actual sync operations)
      await Future.delayed(const Duration(seconds: 2)); // Simulate sync

      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync completed successfully!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    }
  }

  Future<void> _exportMetrics(BuildContext context, WidgetRef ref) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Export metrics (this would trigger actual export)
      await Future.delayed(const Duration(seconds: 2)); // Simulate export

      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Metrics exported to Notion!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _createQuickNote(BuildContext context, WidgetRef ref) async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Quick Note'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: DesignTokens.spacingMd),
            TextField(
              controller: contentController,
              decoration: const InputDecoration(
                labelText: 'Content',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                Navigator.of(context).pop({
                  'title': titleController.text,
                  'content': contentController.text,
                });
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != null && context.mounted) {
      try {
        // Create note in Notion
        await ref.read(notionQuickCaptureProvider.notifier).createQuickNote(
              userId: 'current_user_id', // Get from auth
              title: result['title']!,
              content: result['content']!,
            );

        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note created in Notion!')),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create note: $e')),
        );
      }
    }
  }

  Future<void> _openNotionWorkspace(BuildContext context) async {
    // In production, this would open the user's Notion workspace
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening Notion workspace...')),
    );
  }
}
