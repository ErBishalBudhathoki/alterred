import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/brain_capture_card.dart';
import '../core/context_snapshot_widget.dart';
import '../core/a2a_connection_card.dart';
import '../core/working_memory_panel.dart';
import '../core/appointment_guardian_widget.dart';
import '../core/brain_animations.dart';
import '../state/external_brain_provider.dart';
import '../models/brain_capture_model.dart';

class StandaloneExternalBrain extends ConsumerStatefulWidget {
  const StandaloneExternalBrain({super.key});

  @override
  ConsumerState<StandaloneExternalBrain> createState() =>
      _StandaloneExternalBrainState();
}

class _StandaloneExternalBrainState
    extends ConsumerState<StandaloneExternalBrain>
    with TickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      setState(() => _currentIndex = _tabController.index);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 160,
      floating: false,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        titlePadding: const EdgeInsets.only(bottom: 62.0),
        title: const Text(
          'External Brain',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.indigo[700]!,
                Colors.purple[600]!,
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 60,
                right: 20,
                child: Icon(
                  Icons.psychology,
                  size: 80,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
            ],
          ),
        ),
      ),
      bottom: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: Colors.white,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        tabAlignment: TabAlignment.start,
        labelPadding: const EdgeInsets.symmetric(horizontal: 12),
        tabs: const [
          Tab(icon: Icon(Icons.camera_alt, size: 20), text: 'Capture'),
          Tab(icon: Icon(Icons.timeline, size: 20), text: 'Context'),
          Tab(icon: Icon(Icons.link, size: 20), text: 'A2A'),
          Tab(icon: Icon(Icons.memory, size: 20), text: 'Memory'),
          Tab(icon: Icon(Icons.event, size: 20), text: 'Guardian'),
        ],
      ),
    );
  }

  Widget _buildCaptureTab() {
    final state = ref.watch(externalBrainProvider);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                CaptureEntranceAnimation(
                  child: QuickCaptureWidget(
                    onCapture: () {
                      // Refresh the captures list
                      ref.read(externalBrainProvider.notifier).loadCaptures();
                    },
                  ),
                ),
                const SizedBox(height: 16),
                if (state.stats != null) ...[
                  CaptureEntranceAnimation(
                    delay: const Duration(milliseconds: 200),
                    child: _buildStatsCard(state.stats!),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ),
        if (state.isLoading)
          const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
          )
        else if (state.captures.isEmpty)
          SliverToBoxAdapter(
            child: _buildEmptyState(
              icon: Icons.mic_none,
              title: 'No captures yet',
              subtitle: 'Start capturing your thoughts, tasks, and ideas',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final capture = state.captures[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: CaptureEntranceAnimation(
                      delay: Duration(milliseconds: index * 100),
                      child: BrainCaptureCard(
                        capture: capture,
                        onComplete: () {
                          // TODO: Mark as complete
                        },
                        onArchive: () {
                          // TODO: Archive capture
                        },
                      ),
                    ),
                  );
                },
                childCount: state.captures.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildContextTab() {
    final snapshots = ref.watch(contextSnapshotsProvider);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: CaptureEntranceAnimation(
              child: CreateSnapshotWidget(
                onCreated: () {
                  ref.read(externalBrainProvider.notifier).loadSnapshots();
                },
              ),
            ),
          ),
        ),
        if (snapshots.isEmpty)
          SliverToBoxAdapter(
            child: _buildEmptyState(
              icon: Icons.timeline,
              title: 'No context snapshots',
              subtitle: 'Create snapshots to save your current work context',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final snapshot = snapshots[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: CaptureEntranceAnimation(
                      delay: Duration(milliseconds: index * 100),
                      child: ContextSnapshotWidget(
                        snapshot: snapshot,
                        onRestore: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Context restored successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
                childCount: snapshots.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildA2ATab() {
    final connections = ref.watch(a2aConnectionsProvider);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: CaptureEntranceAnimation(
              child: A2AConnectionSetup(
                onConnectionCreated: () {
                  ref.read(externalBrainProvider.notifier).loadConnections();
                },
              ),
            ),
          ),
        ),
        if (connections.isEmpty)
          SliverToBoxAdapter(
            child: _buildEmptyState(
              icon: Icons.link_off,
              title: 'No connections yet',
              subtitle:
                  'Connect with accountability partners, coaches, or friends',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final connection = connections[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: CaptureEntranceAnimation(
                      delay: Duration(milliseconds: index * 100),
                      child: A2AConnectionCard(
                        connection: connection,
                        onMessage: () {
                          // TODO: Open messaging interface
                        },
                        onDisconnect: () {
                          // TODO: Disconnect partner
                        },
                      ),
                    ),
                  );
                },
                childCount: connections.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMemoryTab() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: CaptureEntranceAnimation(
              child: WorkingMemoryPanel(
                onItemAdded: () {
                  // Memory panel handles its own state
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuardianTab() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: CaptureEntranceAnimation(
              child: AppointmentGuardianWidget(
                onAppointmentTap: () {
                  // TODO: Handle appointment tap
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCard(CaptureStats stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Capture Statistics',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Today',
                    stats.todayCaptures.toString(),
                    Icons.today,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Week',
                    stats.weekCaptures.toString(),
                    Icons.date_range,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Total',
                    stats.totalCaptures.toString(),
                    Icons.all_inclusive,
                    Colors.purple,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Done',
                    stats.completedTasks.toString(),
                    Icons.check_circle,
                    Colors.teal,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildAppBar(),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildCaptureTab(),
            _buildContextTab(),
            _buildA2ATab(),
            _buildMemoryTab(),
            _buildGuardianTab(),
          ],
        ),
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                // TODO: Start voice capture
              },
              icon: const Icon(Icons.mic),
              label: const Text('Voice Capture'),
              backgroundColor: Colors.indigo[700],
            )
          : null,
    );
  }
}
