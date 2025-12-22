import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/components/np_card.dart';
import '../core/design_tokens.dart';
import '../state/metrics_state.dart';
import '../core/orchestration/state/orchestration_provider.dart';
import '../core/orchestration/models/agent_model.dart';
import '../core/orchestration/models/workflow_model.dart';
import '../state/notion_provider.dart';

class MetricsScreen extends ConsumerWidget {
  const MetricsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsyncValue = ref.watch(metricsProvider);
    final orchestrationState = ref.watch(orchestrationProvider);
    final systemHealth = ref.watch(systemHealthProvider);
    final orchestrationStats = ref.watch(orchestrationStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Metrics Dashboard'),
        backgroundColor: DesignTokens.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(orchestrationProvider.notifier).refresh();
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              switch (value) {
                case 'export_notion':
                  await _exportToNotion(context, ref);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export_notion',
                child: ListTile(
                  leading: Icon(Icons.auto_awesome),
                  title: Text('Export to Notion'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DesignTokens.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Orchestration System Health
            _buildSectionHeader(context, 'Orchestration System Health'),
            const SizedBox(height: DesignTokens.spacingMd),
            _buildOrchestrationHealth(
                context, orchestrationState, systemHealth),
            const SizedBox(height: DesignTokens.spacingLg),

            // Agent Status
            _buildSectionHeader(context, 'Agent Status'),
            const SizedBox(height: DesignTokens.spacingMd),
            _buildAgentStatus(context, ref, orchestrationState),
            const SizedBox(height: DesignTokens.spacingLg),

            // Workflow Executions
            _buildSectionHeader(context, 'Active Workflows'),
            const SizedBox(height: DesignTokens.spacingMd),
            _buildActiveWorkflows(context, ref),
            const SizedBox(height: DesignTokens.spacingLg),

            // Test Scenarios Status
            _buildSectionHeader(context, 'Test Scenarios Status'),
            const SizedBox(height: DesignTokens.spacingMd),
            _buildTestScenariosStatus(context, ref),
            const SizedBox(height: DesignTokens.spacingLg),

            // Original Metrics
            metricsAsyncValue.when(
              data: (metrics) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(context, 'Daily Overview'),
                  const SizedBox(height: DesignTokens.spacingMd),
                  _buildSummaryCards(metrics),
                  const SizedBox(height: DesignTokens.spacingLg),
                  _buildSectionHeader(context, 'Stress Level History'),
                  const SizedBox(height: DesignTokens.spacingMd),
                  _buildStressLevelChart(metrics['stress_history']),
                  const SizedBox(height: DesignTokens.spacingLg),
                  _buildSectionHeader(context, 'Strategy Effectiveness'),
                  const SizedBox(height: DesignTokens.spacingMd),
                  _buildStrategyEffectiveness(metrics['strategy_stats']),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Text('Error loading metrics: $err',
                    style: const TextStyle(color: Colors.red)),
              ),
            ),

            // Orchestration Statistics
            const SizedBox(height: DesignTokens.spacingLg),
            _buildSectionHeader(context, 'Orchestration Statistics'),
            const SizedBox(height: DesignTokens.spacingMd),
            _buildOrchestrationStats(context, orchestrationStats),
          ],
        ),
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

  Widget _buildOrchestrationHealth(
    BuildContext context,
    OrchestrationState state,
    Map<String, dynamic> health,
  ) {
    final overallHealth = health['overall_health'] as String? ?? 'unknown';
    final agentHealth = health['agents'] as Map<String, dynamic>? ?? {};
    final safetyHealth = health['safety'] as Map<String, dynamic>? ?? {};

    return Wrap(
      spacing: DesignTokens.spacingSm,
      runSpacing: DesignTokens.spacingSm,
      children: [
        NpCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getHealthIcon(overallHealth),
                    color: _getHealthColor(overallHealth),
                    size: 24,
                  ),
                  const SizedBox(width: DesignTokens.spacingSm),
                  Text('System Health', style: _cardTitleStyle()),
                ],
              ),
              const SizedBox(height: DesignTokens.spacingXs),
              Text(
                overallHealth.toUpperCase(),
                style: _cardValueStyle().copyWith(
                  color: _getHealthColor(overallHealth),
                ),
              ),
            ],
          ),
        ),
        NpCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Agents Healthy', style: _cardTitleStyle()),
              Text(
                '${agentHealth['healthy'] ?? 0}/${agentHealth['total'] ?? 0}',
                style: _cardValueStyle(),
              ),
              Text(
                '${agentHealth['health_percentage'] ?? 0}%',
                style: _cardTitleStyle(),
              ),
            ],
          ),
        ),
        NpCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Safety Violations (24h)', style: _cardTitleStyle()),
              Text(
                '${safetyHealth['violations_24h'] ?? 0}',
                style: _cardValueStyle().copyWith(
                  color: (safetyHealth['violations_24h'] ?? 0) > 5
                      ? Colors.red
                      : Colors.green,
                ),
              ),
            ],
          ),
        ),
        NpCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('System Status', style: _cardTitleStyle()),
              Text(
                state.isRunning ? 'RUNNING' : 'STOPPED',
                style: _cardValueStyle().copyWith(
                  color: state.isRunning ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAgentStatus(
    BuildContext context,
    WidgetRef ref,
    OrchestrationState state,
  ) {
    final agents = state.agents.values.toList();

    if (agents.isEmpty) {
      return const NpCard(
        child: Center(child: Text('No agents registered')),
      );
    }

    return Column(
      children: agents.map((agent) {
        final metrics = agent.getMetrics();
        return Padding(
          padding: const EdgeInsets.only(bottom: DesignTokens.spacingSm),
          child: NpCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            agent.metadata.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            agent.metadata.description,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(agent.status),
                  ],
                ),
                const SizedBox(height: DesignTokens.spacingSm),
                Wrap(
                  spacing: DesignTokens.spacingXs,
                  runSpacing: DesignTokens.spacingXs,
                  children: [
                    _buildMetricChip('Type', agent.metadata.type.name),
                    _buildMetricChip('Priority', '${agent.metadata.priority}'),
                    if (metrics['execution_count'] != null)
                      _buildMetricChip(
                          'Executions', '${metrics['execution_count']}'),
                    if (metrics['success_rate'] != null)
                      _buildMetricChip(
                        'Success Rate',
                        '${(metrics['success_rate'] * 100).toStringAsFixed(0)}%',
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActiveWorkflows(BuildContext context, WidgetRef ref) {
    final activeExecutions = ref.watch(activeExecutionsProvider);

    if (activeExecutions.isEmpty) {
      return const NpCard(
        child: Center(
          child: Text(
            'No active workflows',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return Column(
      children: activeExecutions.map((execution) {
        final progress = execution.stepExecutions.length /
            (execution.stepExecutions.length + 1);

        return Padding(
          padding: const EdgeInsets.only(bottom: DesignTokens.spacingSm),
          child: NpCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        execution.workflowId,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _buildWorkflowStatusBadge(execution.status),
                  ],
                ),
                const SizedBox(height: DesignTokens.spacingSm),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getWorkflowStatusColor(execution.status),
                  ),
                ),
                const SizedBox(height: DesignTokens.spacingXs),
                Text(
                  '${execution.stepExecutions.length} steps completed',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTestScenariosStatus(BuildContext context, WidgetRef ref) {
    final morningRoutine = ref.watch(morningRoutineExecutionProvider);
    final decisionParalysis = ref.watch(decisionParalysisExecutionProvider);
    final hyperfocusProtection =
        ref.watch(hyperfocusProtectionExecutionProvider);

    return Column(
      children: [
        _buildScenarioCard(
          'Morning Routine',
          'Energy → Calendar → Task Planning → Time Estimation',
          morningRoutine,
          Icons.wb_sunny,
          Colors.orange,
        ),
        const SizedBox(height: DesignTokens.spacingSm),
        _buildScenarioCard(
          'Decision Paralysis',
          'Detect → Reduce Options → Auto-Decide',
          decisionParalysis,
          Icons.psychology,
          Colors.purple,
        ),
        const SizedBox(height: DesignTokens.spacingSm),
        _buildScenarioCard(
          'Hyperfocus Protection',
          'Detect → Interrupt → Force Break',
          hyperfocusProtection,
          Icons.shield,
          Colors.blue,
        ),
      ],
    );
  }

  Widget _buildScenarioCard(
    String title,
    String description,
    WorkflowExecution? execution,
    IconData icon,
    Color color,
  ) {
    final isActive = execution != null;
    final status = execution?.status.name ?? 'inactive';

    return NpCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(DesignTokens.spacingSm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: DesignTokens.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isActive ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: isActive ? Colors.green : Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrchestrationStats(
    BuildContext context,
    Map<String, dynamic> stats,
  ) {
    final agentStats = stats['agents'] as Map<String, dynamic>? ?? {};
    final workflowStats = stats['workflows'] as Map<String, dynamic>? ?? {};
    final executionStats = stats['executions'] as Map<String, dynamic>? ?? {};

    return Wrap(
      spacing: DesignTokens.spacingSm,
      runSpacing: DesignTokens.spacingSm,
      children: [
        NpCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Agents', style: _cardTitleStyle()),
              Text(
                '${agentStats['total_agents'] ?? 0}',
                style: _cardValueStyle(),
              ),
            ],
          ),
        ),
        NpCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Active Agents', style: _cardTitleStyle()),
              Text(
                '${agentStats['active_agents'] ?? 0}',
                style: _cardValueStyle(),
              ),
            ],
          ),
        ),
        NpCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Workflows', style: _cardTitleStyle()),
              Text(
                '${workflowStats['total'] ?? 0}',
                style: _cardValueStyle(),
              ),
            ],
          ),
        ),
        NpCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Running Executions', style: _cardTitleStyle()),
              Text(
                '${executionStats['running_executions'] ?? 0}',
                style: _cardValueStyle(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(AgentStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getStatusColor(status),
          width: 1,
        ),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(
          color: _getStatusColor(status),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildWorkflowStatusBadge(WorkflowExecutionStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: _getWorkflowStatusColor(status).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getWorkflowStatusColor(status),
          width: 1,
        ),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(
          color: _getWorkflowStatusColor(status),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMetricChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
        ),
      ),
    );
  }

  Color _getStatusColor(AgentStatus status) {
    switch (status) {
      case AgentStatus.idle:
        return Colors.grey;
      case AgentStatus.active:
        return Colors.green;
      case AgentStatus.busy:
        return Colors.orange;
      case AgentStatus.error:
        return Colors.red;
      case AgentStatus.disabled:
        return Colors.grey.shade700;
      case AgentStatus.monitoring:
        return Colors.blue;
    }
  }

  Color _getWorkflowStatusColor(WorkflowExecutionStatus status) {
    switch (status) {
      case WorkflowExecutionStatus.pending:
        return Colors.grey;
      case WorkflowExecutionStatus.running:
        return Colors.blue;
      case WorkflowExecutionStatus.completed:
        return Colors.green;
      case WorkflowExecutionStatus.failed:
        return Colors.red;
      case WorkflowExecutionStatus.cancelled:
        return Colors.orange;
      case WorkflowExecutionStatus.paused:
        return Colors.yellow;
    }
  }

  IconData _getHealthIcon(String health) {
    switch (health) {
      case 'excellent':
        return Icons.check_circle;
      case 'good':
        return Icons.check_circle_outline;
      case 'fair':
        return Icons.warning_amber;
      case 'poor':
        return Icons.error_outline;
      case 'critical':
        return Icons.error;
      default:
        return Icons.help_outline;
    }
  }

  Color _getHealthColor(String health) {
    switch (health) {
      case 'excellent':
        return Colors.green;
      case 'good':
        return Colors.lightGreen;
      case 'fair':
        return Colors.yellow;
      case 'poor':
        return Colors.orange;
      case 'critical':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildSummaryCards(Map<String, dynamic> metrics) {
    return Wrap(
      spacing: DesignTokens.spacingSm,
      runSpacing: DesignTokens.spacingSm,
      children: [
        NpCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tasks Completed', style: _cardTitleStyle()),
              Text('${metrics['tasks_completed'] ?? 0}',
                  style: _cardValueStyle()),
            ],
          ),
        ),
        NpCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Avg. Time Accuracy', style: _cardTitleStyle()),
              Text(
                  '${metrics['avg_time_accuracy']?.toStringAsFixed(1) ?? 0.0}%',
                  style: _cardValueStyle()),
            ],
          ),
        ),
        NpCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Avg. Stress Level', style: _cardTitleStyle()),
              Text('${metrics['avg_stress_level']?.toStringAsFixed(1) ?? 0.0}',
                  style: _cardValueStyle()),
            ],
          ),
        ),
        NpCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hyperfocus Interrupts', style: _cardTitleStyle()),
              Text('${metrics['hyperfocus_interrupts'] ?? 0}',
                  style: _cardValueStyle()),
            ],
          ),
        ),
      ],
    );
  }

  TextStyle _cardTitleStyle() {
    return const TextStyle(
      fontSize: DesignTokens.bodySize,
      color: Colors.white70,
    );
  }

  TextStyle _cardValueStyle() {
    return const TextStyle(
      fontSize: DesignTokens.titleLargeSize,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    );
  }

  Widget _buildStressLevelChart(List<dynamic>? stressHistory) {
    if (stressHistory == null || stressHistory.isEmpty) {
      return const NpCard(
          child: Center(child: Text('No stress data available.')));
    }

    final List<FlSpot> spots = stressHistory.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.toDouble());
    }).toList();

    return NpCard(
      child: SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            gridData: const FlGridData(show: false),
            titlesData: const FlTitlesData(show: false),
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: Colors.white70, width: 1),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: DesignTokens.primary,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(show: false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStrategyEffectiveness(Map<String, dynamic>? strategyStats) {
    if (strategyStats == null || strategyStats.isEmpty) {
      return const NpCard(
          child: Center(child: Text('No strategy data available.')));
    }

    final List<PieChartSectionData> sections = [];
    strategyStats.forEach((strategy, data) {
      final successRate = data['success_rate'] as double;
      sections.add(
        PieChartSectionData(
          color: _getColorForStrategy(strategy),
          value: successRate,
          title: '${successRate.toStringAsFixed(0)}%',
          radius: 50,
          titleStyle: const TextStyle(
            fontSize: DesignTokens.bodySize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    });

    return NpCard(
      child: SizedBox(
        height: 200,
        child: PieChart(
          PieChartData(
            sections: sections,
            centerSpaceRadius: 40,
            sectionsSpace: 2,
            borderData: FlBorderData(show: false),
          ),
        ),
      ),
    );
  }

  Color _getColorForStrategy(String strategy) {
    // Simple color assignment for demonstration. In a real app, this might be more sophisticated.
    switch (strategy) {
      case 'Pomodoro':
        return Colors.blue.shade300;
      case 'Deep Work':
        return Colors.green.shade300;
      case 'Mindfulness':
        return Colors.purple.shade300;
      default:
        return Colors.grey.shade300;
    }
  }

  Future<void> _exportToNotion(BuildContext context, WidgetRef ref) async {
    try {
      final notionNotifier = ref.read(notionProvider.notifier);
      final metricsAsyncValue = ref.read(metricsProvider);

      await metricsAsyncValue.when(
        data: (metrics) async {
          await notionNotifier.exportMetrics(metrics);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Metrics exported to Notion successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        loading: () async {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please wait for metrics to load'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        },
        error: (error, stack) async {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to export metrics: $error'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
