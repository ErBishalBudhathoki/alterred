import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/components/np_card.dart';
import '../core/design_tokens.dart';
import '../core/observability/logging_service.dart';
import '../core/observability/tracing_service.dart';
import '../core/observability/evaluation_service.dart';
import '../state/observability_provider.dart';

class ObservabilityScreen extends ConsumerStatefulWidget {
  const ObservabilityScreen({super.key});

  @override
  ConsumerState<ObservabilityScreen> createState() =>
      _ObservabilityScreenState();
}

class _ObservabilityScreenState extends ConsumerState<ObservabilityScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Observability Dashboard'),
        backgroundColor: DesignTokens.primary,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.analytics), text: 'Overview'),
            Tab(icon: Icon(Icons.list_alt), text: 'Logs'),
            Tab(icon: Icon(Icons.timeline), text: 'Traces'),
            Tab(icon: Icon(Icons.assessment), text: 'Evaluation'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(observabilityProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildLogsTab(),
          _buildTracesTab(),
          _buildEvaluationTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final observabilityState = ref.watch(observabilityProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(DesignTokens.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('System Health'),
          const SizedBox(height: DesignTokens.spacingMd),
          _buildSystemHealthCards(observabilityState),
          const SizedBox(height: DesignTokens.spacingLg),
          _buildSectionHeader('Performance Metrics'),
          const SizedBox(height: DesignTokens.spacingMd),
          _buildPerformanceMetrics(observabilityState),
          const SizedBox(height: DesignTokens.spacingLg),
          _buildSectionHeader('Activity Overview'),
          const SizedBox(height: DesignTokens.spacingMd),
          _buildActivityOverview(observabilityState),
        ],
      ),
    );
  }

  Widget _buildLogsTab() {
    final logState = ref.watch(logStateProvider);

    return Column(
      children: [
        _buildLogFilters(),
        Expanded(
          child: logState.when(
            data: (logs) => _buildLogsList(logs),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Text('Error loading logs: $error',
                  style: const TextStyle(color: Colors.red)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTracesTab() {
    final traceState = ref.watch(traceStateProvider);

    return Column(
      children: [
        _buildTraceFilters(),
        Expanded(
          child: traceState.when(
            data: (traces) => _buildTracesList(traces),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Text('Error loading traces: $error',
                  style: const TextStyle(color: Colors.red)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEvaluationTab() {
    final evaluationState = ref.watch(evaluationStateProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(DesignTokens.spacingMd),
      child: evaluationState.when(
        data: (state) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Evaluation Summary'),
            const SizedBox(height: DesignTokens.spacingMd),
            _buildEvaluationSummary(state),
            const SizedBox(height: DesignTokens.spacingLg),
            _buildSectionHeader('Recent Evaluations'),
            const SizedBox(height: DesignTokens.spacingMd),
            _buildRecentEvaluations(state),
            const SizedBox(height: DesignTokens.spacingLg),
            _buildSectionHeader('Performance Trends'),
            const SizedBox(height: DesignTokens.spacingMd),
            _buildPerformanceTrends(state),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error loading evaluation data: $error',
              style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildSystemHealthCards(ObservabilityState state) {
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
                    _getHealthIcon(state.systemHealth),
                    color: _getHealthColor(state.systemHealth),
                    size: 24,
                  ),
                  const SizedBox(width: DesignTokens.spacingSm),
                  Text('System Health', style: _cardTitleStyle()),
                ],
              ),
              const SizedBox(height: DesignTokens.spacingXs),
              Text(
                state.systemHealth.toUpperCase(),
                style: _cardValueStyle().copyWith(
                  color: _getHealthColor(state.systemHealth),
                ),
              ),
            ],
          ),
        ),
        NpCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Active Traces', style: _cardTitleStyle()),
              Text('${state.activeTraces}', style: _cardValueStyle()),
            ],
          ),
        ),
        NpCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Error Rate (24h)', style: _cardTitleStyle()),
              Text(
                '${(state.errorRate * 100).toStringAsFixed(1)}%',
                style: _cardValueStyle().copyWith(
                  color: state.errorRate > 0.05 ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
        ),
        NpCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Avg Response Time', style: _cardTitleStyle()),
              Text('${state.avgResponseTime}ms', style: _cardValueStyle()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceMetrics(ObservabilityState state) {
    return Row(
      children: [
        Expanded(
          child: NpCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CPU Usage', style: _cardTitleStyle()),
                const SizedBox(height: DesignTokens.spacingSm),
                LinearProgressIndicator(
                  value: state.cpuUsage / 100,
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    state.cpuUsage > 80
                        ? Colors.red
                        : state.cpuUsage > 60
                            ? Colors.orange
                            : Colors.green,
                  ),
                ),
                const SizedBox(height: DesignTokens.spacingXs),
                Text('${state.cpuUsage.toStringAsFixed(1)}%',
                    style: _cardValueStyle()),
              ],
            ),
          ),
        ),
        const SizedBox(width: DesignTokens.spacingSm),
        Expanded(
          child: NpCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Memory Usage', style: _cardTitleStyle()),
                const SizedBox(height: DesignTokens.spacingSm),
                LinearProgressIndicator(
                  value: state.memoryUsage / 100,
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    state.memoryUsage > 80
                        ? Colors.red
                        : state.memoryUsage > 60
                            ? Colors.orange
                            : Colors.green,
                  ),
                ),
                const SizedBox(height: DesignTokens.spacingXs),
                Text('${state.memoryUsage.toStringAsFixed(1)}%',
                    style: _cardValueStyle()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityOverview(ObservabilityState state) {
    return NpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Activity Timeline (Last 24h)', style: _cardTitleStyle()),
          const SizedBox(height: DesignTokens.spacingMd),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: state.activityHistory.asMap().entries.map((entry) {
                      return FlSpot(
                          entry.key.toDouble(), entry.value.toDouble());
                    }).toList(),
                    isCurved: true,
                    color: DesignTokens.primary,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: DesignTokens.primary.withValues(alpha: 0.1),
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

  Widget _buildLogFilters() {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacingMd),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        border: const Border(bottom: BorderSide(color: Colors.white24)),
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<LogLevel>(
              decoration: const InputDecoration(
                labelText: 'Log Level',
                border: OutlineInputBorder(),
              ),
              items: LogLevel.values.map((level) {
                return DropdownMenuItem(
                  value: level,
                  child: Text(level.name.toUpperCase()),
                );
              }).toList(),
              onChanged: (level) {
                ref.read(logFilterProvider.notifier).setLevel(level);
              },
            ),
          ),
          const SizedBox(width: DesignTokens.spacingSm),
          Expanded(
            child: TextFormField(
              decoration: const InputDecoration(
                labelText: 'Source Filter',
                border: OutlineInputBorder(),
              ),
              onChanged: (source) {
                ref.read(logFilterProvider.notifier).setSource(source);
              },
            ),
          ),
          const SizedBox(width: DesignTokens.spacingSm),
          ElevatedButton(
            onPressed: () {
              ref.read(logStateProvider.notifier).refresh();
            },
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsList(List<LogEntry> logs) {
    if (logs.isEmpty) {
      return const Center(
        child: Text('No logs found', style: TextStyle(color: Colors.white70)),
      );
    }

    return ListView.builder(
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        return _buildLogEntry(log);
      },
    );
  }

  Widget _buildLogEntry(LogEntry log) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spacingMd,
        vertical: DesignTokens.spacingXs,
      ),
      child: NpCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getLogLevelColor(log.level).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _getLogLevelColor(log.level)),
                  ),
                  child: Text(
                    log.level.name.toUpperCase(),
                    style: TextStyle(
                      color: _getLogLevelColor(log.level),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: DesignTokens.spacingSm),
                Text(
                  log.source,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatTimestamp(log.timestamp),
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.spacingXs),
            Text(
              log.message,
              style: const TextStyle(color: Colors.white),
            ),
            if (log.context.isNotEmpty) ...[
              const SizedBox(height: DesignTokens.spacingXs),
              Text(
                'Context: ${log.context}',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTraceFilters() {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacingMd),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        border: const Border(bottom: BorderSide(color: Colors.white24)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              decoration: const InputDecoration(
                labelText: 'Operation Filter',
                border: OutlineInputBorder(),
              ),
              onChanged: (operation) {
                ref.read(traceFilterProvider.notifier).setOperation(operation);
              },
            ),
          ),
          const SizedBox(width: DesignTokens.spacingSm),
          Expanded(
            child: DropdownButtonFormField<TraceStatus>(
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: TraceStatus.values.map((status) {
                return DropdownMenuItem(
                  value: status,
                  child: Text(status.name.toUpperCase()),
                );
              }).toList(),
              onChanged: (status) {
                ref.read(traceFilterProvider.notifier).setStatus(status);
              },
            ),
          ),
          const SizedBox(width: DesignTokens.spacingSm),
          ElevatedButton(
            onPressed: () {
              ref.read(traceStateProvider.notifier).refresh();
            },
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildTracesList(List<Trace> traces) {
    if (traces.isEmpty) {
      return const Center(
        child: Text('No traces found', style: TextStyle(color: Colors.white70)),
      );
    }

    return ListView.builder(
      itemCount: traces.length,
      itemBuilder: (context, index) {
        final trace = traces[index];
        return _buildTraceEntry(trace);
      },
    );
  }

  Widget _buildTraceEntry(Trace trace) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spacingMd,
        vertical: DesignTokens.spacingXs,
      ),
      child: NpCard(
        child: ExpansionTile(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      _getTraceStatusColor(trace.status).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _getTraceStatusColor(trace.status)),
                ),
                child: Text(
                  trace.status.name.toUpperCase(),
                  style: TextStyle(
                    color: _getTraceStatusColor(trace.status),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: DesignTokens.spacingSm),
              Expanded(
                child: Text(
                  trace.operation,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              if (trace.duration != null)
                Text(
                  '${trace.duration!.inMilliseconds}ms',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          subtitle: Text(
            'Trace ID: ${trace.traceId} | ${trace.spans.length} spans',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          children:
              trace.spans.values.map((span) => _buildSpanEntry(span)).toList(),
        ),
      ),
    );
  }

  Widget _buildSpanEntry(Span span) {
    return Padding(
      padding: const EdgeInsets.only(left: DesignTokens.spacingLg),
      child: ListTile(
        dense: true,
        leading: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: _getSpanStatusColor(span.status),
            shape: BoxShape.circle,
          ),
        ),
        title: Text(
          span.operation,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        subtitle: Text(
          'Duration: ${span.duration?.inMilliseconds ?? 0}ms | Events: ${span.events.length}',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        trailing: Text(
          span.status.name.toUpperCase(),
          style: TextStyle(
            color: _getSpanStatusColor(span.status),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildEvaluationSummary(EvaluationState state) {
    return Wrap(
      spacing: DesignTokens.spacingSm,
      runSpacing: DesignTokens.spacingSm,
      children: [
        NpCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Evaluations', style: _cardTitleStyle()),
              Text('${state.totalEvaluations}', style: _cardValueStyle()),
            ],
          ),
        ),
        NpCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Average Score', style: _cardTitleStyle()),
              Text(
                '${(state.averageScore * 100).toStringAsFixed(1)}%',
                style: _cardValueStyle().copyWith(
                  color: state.averageScore > 0.8
                      ? Colors.green
                      : state.averageScore > 0.6
                          ? Colors.orange
                          : Colors.red,
                ),
              ),
            ],
          ),
        ),
        NpCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Active Sessions', style: _cardTitleStyle()),
              Text('${state.activeSessions}', style: _cardValueStyle()),
            ],
          ),
        ),
        NpCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Evaluations (30d)', style: _cardTitleStyle()),
              Text('${state.evaluations30d}', style: _cardValueStyle()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentEvaluations(EvaluationState state) {
    if (state.recentEvaluations.isEmpty) {
      return const NpCard(
        child: Center(
          child: Text('No recent evaluations',
              style: TextStyle(color: Colors.white70)),
        ),
      );
    }

    return Column(
      children: state.recentEvaluations.map((evaluation) {
        return Padding(
          padding: const EdgeInsets.only(bottom: DesignTokens.spacingSm),
          child: NpCard(
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getEvaluationTypeColor(evaluation.type)
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getEvaluationTypeIcon(evaluation.type),
                  color: _getEvaluationTypeColor(evaluation.type),
                ),
              ),
              title: Text(
                evaluation.type.name.toUpperCase(),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Score: ${(evaluation.overallScore * 100).toStringAsFixed(1)}% | ${_formatTimestamp(evaluation.endTime)}',
                style: const TextStyle(color: Colors.white70),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: evaluation.overallScore > 0.8
                      ? Colors.green.withValues(alpha: 0.2)
                      : evaluation.overallScore > 0.6
                          ? Colors.orange.withValues(alpha: 0.2)
                          : Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${(evaluation.overallScore * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: evaluation.overallScore > 0.8
                        ? Colors.green
                        : evaluation.overallScore > 0.6
                            ? Colors.orange
                            : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPerformanceTrends(EvaluationState state) {
    return NpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Performance Trends (Last 30 days)', style: _cardTitleStyle()),
          const SizedBox(height: DesignTokens.spacingMd),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: state.performanceTrend.asMap().entries.map((entry) {
                      return FlSpot(entry.key.toDouble(), entry.value);
                    }).toList(),
                    isCurved: true,
                    color: Colors.green,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.green.withValues(alpha: 0.1),
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

  Color _getLogLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return Colors.grey;
      case LogLevel.info:
        return Colors.blue;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red;
      case LogLevel.critical:
        return Colors.purple;
    }
  }

  Color _getTraceStatusColor(TraceStatus status) {
    switch (status) {
      case TraceStatus.active:
        return Colors.blue;
      case TraceStatus.completed:
        return Colors.green;
      case TraceStatus.error:
        return Colors.red;
      case TraceStatus.cancelled:
        return Colors.orange;
    }
  }

  Color _getSpanStatusColor(SpanStatus status) {
    switch (status) {
      case SpanStatus.active:
        return Colors.blue;
      case SpanStatus.completed:
        return Colors.green;
      case SpanStatus.error:
        return Colors.red;
      case SpanStatus.cancelled:
        return Colors.orange;
    }
  }

  Color _getEvaluationTypeColor(EvaluationType type) {
    switch (type) {
      case EvaluationType.agent:
        return Colors.blue;
      case EvaluationType.workflow:
        return Colors.green;
      case EvaluationType.productivity:
        return Colors.purple;
      case EvaluationType.system:
        return Colors.orange;
    }
  }

  IconData _getEvaluationTypeIcon(EvaluationType type) {
    switch (type) {
      case EvaluationType.agent:
        return Icons.smart_toy;
      case EvaluationType.workflow:
        return Icons.account_tree;
      case EvaluationType.productivity:
        return Icons.trending_up;
      case EvaluationType.system:
        return Icons.computer;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
