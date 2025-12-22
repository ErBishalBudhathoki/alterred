import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/brain_capture_card.dart';
import '../core/context_snapshot_widget.dart';
import '../core/working_memory_panel.dart';
import '../core/brain_animations.dart';
import '../state/external_brain_provider.dart';

class ChatExternalBrain extends ConsumerStatefulWidget {
  final VoidCallback? onCapture;
  final VoidCallback? onContextRestore;
  final bool isCompact;

  const ChatExternalBrain({
    super.key,
    this.onCapture,
    this.onContextRestore,
    this.isCompact = true,
  });

  @override
  ConsumerState<ChatExternalBrain> createState() => _ChatExternalBrainState();
}

class _ChatExternalBrainState extends ConsumerState<ChatExternalBrain>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.indigo[50]!,
            Colors.purple[50]!,
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.psychology,
            color: Colors.indigo[700],
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'External Brain',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.indigo[700],
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              _isExpanded ? Icons.expand_less : Icons.expand_more,
              size: 20,
            ),
            onPressed: () => setState(() => _isExpanded = !_isExpanded),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                final notifier = ref.read(externalBrainProvider.notifier);
                await notifier.captureText('Quick capture from chat');
                widget.onCapture?.call();
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Quick Capture'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                // TODO: Create context snapshot
                widget.onContextRestore?.call();
              },
              icon: const Icon(Icons.camera_alt, size: 16),
              label: const Text('Snapshot'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    if (!_isExpanded) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: Colors.indigo[700],
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: Colors.indigo[700],
          tabs: const [
            Tab(text: 'Recent'),
            Tab(text: 'Memory'),
            Tab(text: 'Context'),
          ],
        ),
        SizedBox(
          height: 300,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildRecentCaptures(),
              _buildWorkingMemory(),
              _buildContextSnapshots(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentCaptures() {
    final captures = ref.watch(activeCapturesProvider);
    
    if (captures.isEmpty) {
      return _buildEmptyState(
        icon: Icons.mic_none,
        message: 'No recent captures',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: captures.take(5).length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final capture = captures[index];
        return CaptureEntranceAnimation(
          delay: Duration(milliseconds: index * 100),
          child: BrainCaptureCard(
            capture: capture,
            isCompact: true,
            showActions: false,
            onTap: () {
              // TODO: Handle capture tap
            },
          ),
        );
      },
    );
  }

  Widget _buildWorkingMemory() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: WorkingMemoryPanel(
        isCompact: true,
        onItemAdded: () {
          // Memory panel handles its own state
        },
      ),
    );
  }

  Widget _buildContextSnapshots() {
    final snapshots = ref.watch(contextSnapshotsProvider);
    
    if (snapshots.isEmpty) {
      return _buildEmptyState(
        icon: Icons.timeline,
        message: 'No context snapshots',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: snapshots.take(3).length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final snapshot = snapshots[index];
        return CaptureEntranceAnimation(
          delay: Duration(milliseconds: index * 100),
          child: ContextSnapshotWidget(
            snapshot: snapshot,
            isCompact: true,
            onRestore: widget.onContextRestore,
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          _buildHeader(),
          _buildQuickActions(),
          _buildTabContent(),
        ],
      ),
    );
  }
}

class ChatBrainQuickCapture extends ConsumerStatefulWidget {
  final String? initialText;
  final VoidCallback? onCapture;

  const ChatBrainQuickCapture({
    super.key,
    this.initialText,
    this.onCapture,
  });

  @override
  ConsumerState<ChatBrainQuickCapture> createState() => _ChatBrainQuickCaptureState();
}

class _ChatBrainQuickCaptureState extends ConsumerState<ChatBrainQuickCapture> {
  final TextEditingController _controller = TextEditingController();
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialText != null) {
      _controller.text = widget.initialText!;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_controller.text.trim().isEmpty) return;

    setState(() => _isCapturing = true);

    final notifier = ref.read(externalBrainProvider.notifier);
    await notifier.captureText(_controller.text.trim());

    setState(() => _isCapturing = false);
    _controller.clear();
    widget.onCapture?.call();

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Captured to External Brain'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.psychology,
                color: Colors.indigo[700],
              ),
              const SizedBox(width: 8),
              Text(
                'Quick Capture',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.indigo[700],
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLines: 4,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Enter your thought, task, or reminder...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isCapturing ? null : _capture,
                  icon: _isCapturing 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isCapturing ? 'Capturing...' : 'Capture'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo[700],
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );
  }
}

class ChatBrainSuggestions extends ConsumerWidget {
  final String chatContext;
  final VoidCallback? onSuggestionTap;

  const ChatBrainSuggestions({
    super.key,
    required this.chatContext,
    this.onSuggestionTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workingMemory = ref.watch(workingMemoryProvider);
    final recentCaptures = ref.watch(activeCapturesProvider);

    // Filter relevant items based on chat context
    final relevantMemory = workingMemory.where((item) =>
        item.content.toLowerCase().contains(chatContext.toLowerCase())
    ).take(3).toList();

    final relevantCaptures = recentCaptures.where((capture) =>
        capture.content.toLowerCase().contains(chatContext.toLowerCase())
    ).take(2).toList();

    if (relevantMemory.isEmpty && relevantCaptures.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 16,
                color: Colors.blue[700],
              ),
              const SizedBox(width: 6),
              Text(
                'From External Brain',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...relevantMemory.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: InkWell(
              onTap: onSuggestionTap,
              child: Text(
                '• ${item.content}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.blue[800],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )),
          ...relevantCaptures.map((capture) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: InkWell(
              onTap: onSuggestionTap,
              child: Text(
                '• ${capture.content}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.blue[800],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )),
        ],
      ),
    );
  }
}