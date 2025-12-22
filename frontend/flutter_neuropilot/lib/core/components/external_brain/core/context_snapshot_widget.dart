import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/context_snapshot_model.dart';
import '../state/external_brain_provider.dart';
import 'brain_animations.dart';

class ContextSnapshotWidget extends ConsumerStatefulWidget {
  final ContextSnapshot snapshot;
  final VoidCallback? onRestore;
  final VoidCallback? onDelete;
  final bool isCompact;

  const ContextSnapshotWidget({
    super.key,
    required this.snapshot,
    this.onRestore,
    this.onDelete,
    this.isCompact = false,
  });

  @override
  ConsumerState<ContextSnapshotWidget> createState() => _ContextSnapshotWidgetState();
}

class _ContextSnapshotWidgetState extends ConsumerState<ContextSnapshotWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isExpanded = false;
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  Future<void> _restoreContext() async {
    setState(() => _isRestoring = true);
    
    final notifier = ref.read(externalBrainProvider.notifier);
    final success = await notifier.restoreContext(widget.snapshot.id);
    
    setState(() => _isRestoring = false);
    
    if (success) {
      widget.onRestore?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Context restored successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to restore context'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getTypeColor() {
    switch (widget.snapshot.type) {
      case ContextType.work:
        return Colors.blue;
      case ContextType.personal:
        return Colors.green;
      case ContextType.creative:
        return Colors.purple;
      case ContextType.learning:
        return Colors.orange;
      case ContextType.meeting:
        return Colors.red;
      case ContextType.breakTime:
        return Colors.teal;
      case ContextType.transition:
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon() {
    switch (widget.snapshot.type) {
      case ContextType.work:
        return Icons.work;
      case ContextType.personal:
        return Icons.person;
      case ContextType.creative:
        return Icons.palette;
      case ContextType.learning:
        return Icons.school;
      case ContextType.meeting:
        return Icons.meeting_room;
      case ContextType.breakTime:
        return Icons.coffee;
      case ContextType.transition:
        return Icons.swap_horiz;
      default:
        return Icons.camera_alt;
    }
  }

  Widget _buildHeader() {
    final color = _getTypeColor();
    
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getTypeIcon(),
            size: 16,
            color: color,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.snapshot.title ?? 'Context Snapshot',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    widget.snapshot.isRestored == true 
                        ? Icons.check_circle 
                        : Icons.radio_button_unchecked,
                    size: 12,
                    color: widget.snapshot.isRestored == true 
                        ? Colors.green 
                        : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.snapshot.isRestored == true ? 'RESTORED' : 'AVAILABLE',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: widget.snapshot.isRestored == true 
                          ? Colors.green 
                          : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                      fontSize: 10,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatTime(widget.snapshot.timestamp),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(
            _isExpanded ? Icons.expand_less : Icons.expand_more,
            size: 20,
          ),
          onPressed: _toggleExpanded,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }

  Widget _buildContextItems() {
    if (widget.snapshot.items?.isEmpty != false) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'Context Items',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ...widget.snapshot.items!.take(3).map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Icon(
                _getItemIcon(item.type),
                size: 14,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.title,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        )),
        if (widget.snapshot.items!.length > 3)
          Text(
            '+${widget.snapshot.items!.length - 3} more items',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }

  IconData _getItemIcon(String type) {
    switch (type.toLowerCase()) {
      case 'app':
        return Icons.apps;
      case 'document':
        return Icons.description;
      case 'browser':
        return Icons.web;
      case 'file':
        return Icons.insert_drive_file;
      case 'note':
        return Icons.note;
      default:
        return Icons.circle;
    }
  }

  Widget _buildActions() {
    return SizeTransition(
      sizeFactor: CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isRestoring ? null : _restoreContext,
                  icon: _isRestoring 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.restore, size: 16),
                  label: Text(_isRestoring ? 'Restoring...' : 'Restore Context'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getTypeColor(),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: widget.onDelete,
                icon: const Icon(Icons.delete, size: 16),
                label: const Text('Delete'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red[700],
                  side: BorderSide(color: Colors.red[300]!),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ContextRestoreAnimation(
      isRestoring: _isRestoring,
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: _toggleExpanded,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                if (_isExpanded) ...[
                  if (widget.snapshot.description != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Text(
                        widget.snapshot.description!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                  _buildContextItems(),
                  _buildActions(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ContextTimelineWidget extends ConsumerWidget {
  final List<ContextSnapshot> snapshots;
  final VoidCallback? onSnapshotTap;

  const ContextTimelineWidget({
    super.key,
    required this.snapshots,
    this.onSnapshotTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (snapshots.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.timeline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No context snapshots yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create snapshots to save your current context',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: snapshots.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final snapshot = snapshots[index];
        return CaptureEntranceAnimation(
          delay: Duration(milliseconds: index * 100),
          child: ContextSnapshotWidget(
            snapshot: snapshot,
            onRestore: onSnapshotTap,
          ),
        );
      },
    );
  }
}

class CreateSnapshotWidget extends ConsumerStatefulWidget {
  final String? taskId;
  final VoidCallback? onCreated;

  const CreateSnapshotWidget({
    super.key,
    this.taskId,
    this.onCreated,
  });

  @override
  ConsumerState<CreateSnapshotWidget> createState() => _CreateSnapshotWidgetState();
}

class _CreateSnapshotWidgetState extends ConsumerState<CreateSnapshotWidget> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  ContextType _selectedType = ContextType.work;
  bool _isCreating = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createSnapshot() async {
    if (_titleController.text.trim().isEmpty) return;

    setState(() => _isCreating = true);

    final notifier = ref.read(externalBrainProvider.notifier);
    final snapshot = await notifier.createSnapshot(
      widget.taskId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'type': _selectedType.name,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );

    setState(() => _isCreating = false);

    if (snapshot != null) {
      _titleController.clear();
      _descriptionController.clear();
      widget.onCreated?.call();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Context snapshot created'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create Context Snapshot',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Snapshot Title',
                hintText: 'e.g., Working on project X',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Describe what you were working on...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ContextType>(
              initialValue: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Context Type',
                border: OutlineInputBorder(),
              ),
              items: ContextType.values.map((type) => DropdownMenuItem(
                value: type,
                child: Text(type.name.toUpperCase()),
              )).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedType = value);
                }
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isCreating ? null : _createSnapshot,
                icon: _isCreating 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.camera_alt),
                label: Text(_isCreating ? 'Creating...' : 'Create Snapshot'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}