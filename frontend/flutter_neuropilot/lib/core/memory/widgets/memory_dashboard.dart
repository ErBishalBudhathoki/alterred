import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../state/memory_provider.dart';
import '../models/memory_models.dart';
import '../services/session_manager.dart';
import '../../components/np_card.dart';
import '../../design_tokens.dart';
import '../../../state/notion_provider.dart';

/// Memory dashboard widget showing system status and metrics
class MemoryDashboard extends ConsumerWidget {
  const MemoryDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memoryState = ref.watch(memoryProvider);
    final systemHealth = ref.watch(memorySystemHealthProvider);
    final currentSession = ref.watch(currentSessionProvider);
    final metrics = ref.watch(memoryMetricsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(DesignTokens.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // System Health Section
          _buildSectionHeader(context, 'Memory System Health'),
          const SizedBox(height: DesignTokens.spacingMd),
          _buildSystemHealthCards(systemHealth),
          
          const SizedBox(height: DesignTokens.spacingLg),
          
          // Current Session Section
          _buildSectionHeader(context, 'Current Session'),
          const SizedBox(height: DesignTokens.spacingMd),
          _buildCurrentSessionCard(context, ref, currentSession),
          
          const SizedBox(height: DesignTokens.spacingLg),
          
          // Memory Metrics Section
          if (metrics != null) ...[
            _buildSectionHeader(context, 'Memory Metrics'),
            const SizedBox(height: DesignTokens.spacingMd),
            _buildMemoryMetricsCards(metrics),
            
            const SizedBox(height: DesignTokens.spacingLg),
            
            // Memory Distribution Chart
            _buildSectionHeader(context, 'Memory Distribution'),
            const SizedBox(height: DesignTokens.spacingMd),
            _buildMemoryDistributionChart(metrics),
          ],
          
          const SizedBox(height: DesignTokens.spacingLg),
          
          // Context Window Section
          _buildSectionHeader(context, 'Context Window'),
          const SizedBox(height: DesignTokens.spacingMd),
          _buildContextWindowCard(context, ref),
          
          const SizedBox(height: DesignTokens.spacingLg),
          
          // Quick Actions Section
          _buildSectionHeader(context, 'Quick Actions'),
          const SizedBox(height: DesignTokens.spacingMd),
          _buildQuickActions(context, ref, memoryState),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildSystemHealthCards(Map<String, dynamic> health) {
    return Wrap(
      spacing: DesignTokens.spacingSm,
      runSpacing: DesignTokens.spacingSm,
      children: [
        _buildHealthCard(
          'System Status',
          health['is_initialized'] ? 'Initialized' : 'Not Ready',
          health['is_initialized'] ? Colors.green : Colors.red,
          health['is_initialized'] ? Icons.check_circle : Icons.error,
        ),
        _buildHealthCard(
          'User Session',
          health['has_user'] ? 'Active' : 'No User',
          health['has_user'] ? Colors.green : Colors.orange,
          health['has_user'] ? Icons.person : Icons.person_off,
        ),
        _buildHealthCard(
          'Memory Session',
          health['has_active_session'] ? 'Active' : 'Inactive',
          health['has_active_session'] ? Colors.green : Colors.grey,
          health['has_active_session'] ? Icons.memory : Icons.memory_outlined,
        ),
        _buildHealthCard(
          'Storage Usage',
          '${health['storage_usage_mb'].toStringAsFixed(1)} MB',
          _getStorageColor(health['storage_usage_mb']),
          Icons.storage,
        ),
      ],
    );
  }

  Widget _buildHealthCard(String title, String value, Color color, IconData icon) {
    return NpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: DesignTokens.spacingXs),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: DesignTokens.bodySize,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spacingXs),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: DesignTokens.titleLargeSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentSessionCard(BuildContext context, WidgetRef ref, SessionStatus? session) {
    if (session == null || !session.hasActiveSession) {
      return NpCard(
        child: Column(
          children: [
            const Icon(
              Icons.play_circle_outline,
              size: 48,
              color: Colors.white54,
            ),
            const SizedBox(height: DesignTokens.spacingSm),
            const Text(
              'No Active Session',
              style: TextStyle(
                color: Colors.white70,
                fontSize: DesignTokens.bodySize,
              ),
            ),
            const SizedBox(height: DesignTokens.spacingSm),
            ElevatedButton(
              onPressed: () => _showStartSessionDialog(context, ref),
              child: const Text('Start Session'),
            ),
          ],
        ),
      );
    }

    return NpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Session Type',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: DesignTokens.bodySize,
                    ),
                  ),
                  Text(
                    session.sessionType?.name.toUpperCase() ?? 'UNKNOWN',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: DesignTokens.titleLargeSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green),
                ),
                child: const Text(
                  'ACTIVE',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spacingMd),
          Row(
            children: [
              Expanded(
                child: _buildSessionMetric(
                  'Duration',
                  _formatDuration(session.duration),
                  Icons.timer,
                ),
              ),
              Expanded(
                child: _buildSessionMetric(
                  'Memories',
                  '${session.chunkCount}',
                  Icons.memory,
                ),
              ),
              if (session.attentionScore != null)
                Expanded(
                  child: _buildSessionMetric(
                    'Attention',
                    '${(session.attentionScore! * 100).round()}%',
                    Icons.psychology,
                  ),
                ),
            ],
          ),
          const SizedBox(height: DesignTokens.spacingMd),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showSessionDetails(context, ref, session),
                  icon: const Icon(Icons.info_outline),
                  label: const Text('Details'),
                ),
              ),
              const SizedBox(width: DesignTokens.spacingSm),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _endSession(context, ref),
                  icon: const Icon(Icons.stop),
                  label: const Text('End Session'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withValues(alpha: 0.2),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSessionMetric(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: DesignTokens.titleLargeSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildMemoryMetricsCards(MemoryMetrics metrics) {
    return Wrap(
      spacing: DesignTokens.spacingSm,
      runSpacing: DesignTokens.spacingSm,
      children: [
        _buildMetricCard(
          'Total Memories',
          '${metrics.totalChunks}',
          Icons.memory,
          Colors.blue,
        ),
        _buildMetricCard(
          'Active Memories',
          '${metrics.activeChunks}',
          Icons.flash_on,
          Colors.green,
        ),
        _buildMetricCard(
          'Avg Relevance',
          '${(metrics.averageRelevanceScore * 100).round()}%',
          Icons.star,
          Colors.orange,
        ),
        _buildMetricCard(
          'Sessions',
          '${metrics.totalSessions}',
          Icons.history,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return NpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: DesignTokens.spacingXs),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: DesignTokens.bodySize,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spacingXs),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: DesignTokens.titleLargeSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryDistributionChart(MemoryMetrics metrics) {
    final sections = <PieChartSectionData>[];
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.pink,
      Colors.amber,
    ];

    int colorIndex = 0;
    for (final entry in metrics.chunksByType.entries) {
      if (entry.value > 0) {
        sections.add(
          PieChartSectionData(
            color: colors[colorIndex % colors.length],
            value: entry.value.toDouble(),
            title: '${entry.value}',
            radius: 60,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
        colorIndex++;
      }
    }

    return NpCard(
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 40,
                sectionsSpace: 2,
              ),
            ),
          ),
          const SizedBox(height: DesignTokens.spacingMd),
          Wrap(
            spacing: DesignTokens.spacingSm,
            runSpacing: DesignTokens.spacingXs,
            children: metrics.chunksByType.entries.map((entry) {
              final color = colors[metrics.chunksByType.keys.toList().indexOf(entry.key) % colors.length];
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${entry.key.name}: ${entry.value}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildContextWindowCard(BuildContext context, WidgetRef ref) {
    final contextWindow = ref.watch(contextWindowProvider);

    if (contextWindow == null) {
      return const NpCard(
        child: Center(
          child: Text(
            'No active context window',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return NpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Context Window',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: DesignTokens.titleLargeSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (contextWindow.needsCompaction)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: const Text(
                    'NEEDS COMPACTION',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: DesignTokens.spacingMd),
          LinearProgressIndicator(
            value: contextWindow.utilizationRatio,
            backgroundColor: Colors.white24,
            valueColor: AlwaysStoppedAnimation<Color>(
              contextWindow.utilizationRatio > 0.8 ? Colors.red : Colors.green,
            ),
          ),
          const SizedBox(height: DesignTokens.spacingXs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${contextWindow.currentTokens} / ${contextWindow.maxTokens} tokens',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              Text(
                '${(contextWindow.utilizationRatio * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spacingMd),
          Row(
            children: [
              Expanded(
                child: _buildContextMetric(
                  'Chunks',
                  '${contextWindow.chunks.length}',
                  Icons.memory,
                ),
              ),
              Expanded(
                child: _buildContextMetric(
                  'Compression',
                  '${(contextWindow.compressionRatio * 100).round()}%',
                  Icons.compress,
                ),
              ),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: contextWindow.needsCompaction
                      ? () => _compactContextWindow(context, ref)
                      : null,
                  icon: const Icon(Icons.compress, size: 16),
                  label: const Text('Compact'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContextMetric(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: DesignTokens.bodySize,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context, WidgetRef ref, MemoryState memoryState) {
    return Wrap(
      spacing: DesignTokens.spacingSm,
      runSpacing: DesignTokens.spacingSm,
      children: [
        _buildActionButton(
          'Optimize Memory',
          Icons.tune,
          memoryState.isOptimizing ? null : () => _optimizeMemory(context, ref),
          isLoading: memoryState.isOptimizing,
        ),
        _buildActionButton(
          'Search Memories',
          Icons.search,
          () => _showSearchDialog(context, ref),
        ),
        _buildActionButton(
          'Session History',
          Icons.history,
          () => _showSessionHistory(context, ref),
        ),
        _buildActionButton(
          'Restore Context',
          Icons.restore,
          () => _showRestoreContextDialog(context, ref),
        ),
        _buildActionButton(
          'Backup to Notion',
          Icons.auto_awesome,
          () => _backupToNotion(context, ref),
          color: const Color(0xFF6366F1),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    VoidCallback? onPressed, {
    bool isLoading = false,
    Color? color,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: color,
        foregroundColor: color != null ? Colors.white : null,
      ),
    );
  }

  Future<void> _backupToNotion(BuildContext context, WidgetRef ref) async {
    try {
      final notionNotifier = ref.read(notionProvider.notifier);
      final memoryState = ref.read(memoryProvider);
      
      // Create a memory backup in Notion
      final backupContent = _generateMemoryBackup(memoryState);
      await notionNotifier.createQuickNote('Memory Backup - ${DateTime.now().toIso8601String()}: $backupContent');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('💾 Memory backed up to Notion successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to backup to Notion: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _generateMemoryBackup(MemoryState memoryState) {
    final buffer = StringBuffer();
    buffer.writeln('# Memory System Backup');
    buffer.writeln('Generated: ${DateTime.now()}');
    buffer.writeln();
    
    if (memoryState.sessionStatus != null) {
      buffer.writeln('## Current Session');
      buffer.writeln('Type: ${memoryState.sessionStatus!.sessionType?.name ?? 'Unknown'}');
      buffer.writeln('Started: ${memoryState.sessionStatus!.duration}');
      buffer.writeln();
    }
    
    if (memoryState.recentMemories.isNotEmpty) {
      buffer.writeln('## Recent Memories (${memoryState.recentMemories.length})');
      for (final memory in memoryState.recentMemories.take(10)) {
        buffer.writeln('- ${memory.content} (${memory.timestamp})');
      }
      buffer.writeln();
    }
    
    buffer.writeln('## System Status');
    buffer.writeln('Total memories: ${memoryState.recentMemories.length}');
    buffer.writeln('Active session: ${memoryState.sessionStatus?.hasActiveSession ?? false}');
    
    return buffer.toString();
  }

  // Helper methods

  Color _getStorageColor(double storageMB) {
    if (storageMB < 10) return Colors.green;
    if (storageMB < 50) return Colors.orange;
    return Colors.red;
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  // Action handlers

  void _showStartSessionDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const StartSessionDialog(),
    );
  }

  void _showSessionDetails(BuildContext context, WidgetRef ref, SessionStatus session) {
    showDialog(
      context: context,
      builder: (context) => SessionDetailsDialog(session: session),
    );
  }

  void _endSession(BuildContext context, WidgetRef ref) {
    final actions = ref.read(memoryActionsProvider);
    actions.endSession();
  }

  void _compactContextWindow(BuildContext context, WidgetRef ref) {
    final actions = ref.read(memoryActionsProvider);
    actions.compactContextWindow();
  }

  void _optimizeMemory(BuildContext context, WidgetRef ref) {
    final actions = ref.read(memoryActionsProvider);
    actions.optimizeMemory();
  }

  void _showSearchDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const MemorySearchDialog(),
    );
  }

  void _showSessionHistory(BuildContext context, WidgetRef ref) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SessionHistoryScreen(),
      ),
    );
  }

  void _showRestoreContextDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const RestoreContextDialog(),
    );
  }
}

/// Start session dialog
class StartSessionDialog extends ConsumerStatefulWidget {
  const StartSessionDialog({super.key});

  @override
  ConsumerState<StartSessionDialog> createState() => _StartSessionDialogState();
}

class _StartSessionDialogState extends ConsumerState<StartSessionDialog> {
  SessionType selectedType = SessionType.mixed;
  final titleController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Start New Session'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: titleController,
            decoration: const InputDecoration(
              labelText: 'Session Title (Optional)',
              hintText: 'Enter a title for this session',
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<SessionType>(
            initialValue: selectedType,
            decoration: const InputDecoration(labelText: 'Session Type'),
            items: SessionType.values.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(type.name.toUpperCase()),
              );
            }).toList(),
            onChanged: (type) {
              if (type != null) {
                setState(() {
                  selectedType = type;
                });
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final actions = ref.read(memoryActionsProvider);
            actions.startSession(
              type: selectedType,
              title: titleController.text.isNotEmpty ? titleController.text : null,
            );
            Navigator.of(context).pop();
          },
          child: const Text('Start'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    titleController.dispose();
    super.dispose();
  }
}

/// Session details dialog
class SessionDetailsDialog extends StatelessWidget {
  final SessionStatus session;

  const SessionDetailsDialog({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Session Details'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Session ID', session.sessionId ?? 'Unknown'),
          _buildDetailRow('Type', session.sessionType?.name.toUpperCase() ?? 'Unknown'),
          _buildDetailRow('Duration', _formatDuration(session.duration)),
          _buildDetailRow('Memory Count', '${session.chunkCount}'),
          if (session.attentionScore != null)
            _buildDetailRow('Attention Score', '${(session.attentionScore! * 100).round()}%'),
          if (session.interruptionCount != null)
            _buildDetailRow('Interruptions', '${session.interruptionCount}'),
          if (session.lastActivity != null)
            _buildDetailRow('Last Activity', session.lastActivity!.toString()),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}

/// Memory search dialog
class MemorySearchDialog extends ConsumerStatefulWidget {
  const MemorySearchDialog({super.key});

  @override
  ConsumerState<MemorySearchDialog> createState() => _MemorySearchDialogState();
}

class _MemorySearchDialogState extends ConsumerState<MemorySearchDialog> {
  final searchController = TextEditingController();
  List<MemoryChunk> searchResults = [];
  bool isSearching = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Search Memories'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: 'Search Query',
                hintText: 'Enter keywords to search',
                suffixIcon: IconButton(
                  onPressed: _performSearch,
                  icon: const Icon(Icons.search),
                ),
              ),
              onSubmitted: (_) => _performSearch(),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : searchResults.isEmpty
                      ? const Center(child: Text('No results found'))
                      : ListView.builder(
                          itemCount: searchResults.length,
                          itemBuilder: (context, index) {
                            final memory = searchResults[index];
                            return ListTile(
                              title: Text(
                                memory.content.length > 50
                                    ? '${memory.content.substring(0, 50)}...'
                                    : memory.content,
                              ),
                              subtitle: Text(
                                '${memory.type.name} • ${memory.timestamp.toString().substring(0, 16)}',
                              ),
                              trailing: Text(
                                '${(memory.relevanceScore * 100).round()}%',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Future<void> _performSearch() async {
    if (searchController.text.trim().isEmpty) return;

    setState(() {
      isSearching = true;
    });

    try {
      final actions = ref.read(memoryActionsProvider);
      final results = await actions.searchMemories(searchController.text.trim());
      
      setState(() {
        searchResults = results;
        isSearching = false;
      });
    } catch (error) {
      setState(() {
        isSearching = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $error')),
        );
      }
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}

/// Restore context dialog
class RestoreContextDialog extends ConsumerWidget {
  const RestoreContextDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      title: const Text('Restore Session Context'),
      content: const Text(
        'This will restore the context from your most recent session. '
        'This can help you pick up where you left off.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            final actions = ref.read(memoryActionsProvider);
            final result = await actions.restoreSessionContext();
            
            if (!context.mounted) return;
            Navigator.of(context).pop();
            
            if (result != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Context restored from session: ${result.restoredSession.title}',
                  ),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No recent session found to restore'),
                ),
              );
            }
          },
          child: const Text('Restore'),
        ),
      ],
    );
  }
}

/// Session history screen
class SessionHistoryScreen extends ConsumerWidget {
  const SessionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session History'),
      ),
      body: FutureBuilder<List<MemorySession>>(
        future: ref.read(memoryActionsProvider).getSessionHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }
          
          final sessions = snapshot.data ?? [];
          
          if (sessions.isEmpty) {
            return const Center(
              child: Text('No sessions found'),
            );
          }
          
          return ListView.builder(
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              return ListTile(
                title: Text(session.title),
                subtitle: Text(
                  '${session.type.name} • ${session.startTime.toString().substring(0, 16)}',
                ),
                trailing: Text(
                  session.isActive ? 'Active' : 'Completed',
                  style: TextStyle(
                    color: session.isActive ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  // Show session details or restore context
                },
              );
            },
          );
        },
      ),
    );
  }
}