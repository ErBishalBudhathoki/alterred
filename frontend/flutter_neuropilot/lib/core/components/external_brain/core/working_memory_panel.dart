import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/context_snapshot_model.dart';
import '../state/external_brain_provider.dart';
import 'brain_animations.dart';

class WorkingMemoryPanel extends ConsumerStatefulWidget {
  final bool isCompact;
  final VoidCallback? onItemAdded;

  const WorkingMemoryPanel({
    super.key,
    this.isCompact = false,
    this.onItemAdded,
  });

  @override
  ConsumerState<WorkingMemoryPanel> createState() => _WorkingMemoryPanelState();
}

class _WorkingMemoryPanelState extends ConsumerState<WorkingMemoryPanel>
    with TickerProviderStateMixin {
  final TextEditingController _quickAddController = TextEditingController();
  WorkingMemoryType _selectedType = WorkingMemoryType.quickNote;
  bool _showAddForm = false;
  late AnimationController _formController;

  @override
  void initState() {
    super.initState();
    _formController = AnimationController(
      duration: BrainAnimations.memoryItemDuration,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _quickAddController.dispose();
    _formController.dispose();
    super.dispose();
  }

  void _toggleAddForm() {
    setState(() {
      _showAddForm = !_showAddForm;
      if (_showAddForm) {
        _formController.forward();
      } else {
        _formController.reverse();
      }
    });
  }

  Future<void> _addItem() async {
    if (_quickAddController.text.trim().isEmpty) return;

    final notifier = ref.read(externalBrainProvider.notifier);
    await notifier.addToWorkingMemory(
      _quickAddController.text.trim(),
      _selectedType,
    );

    _quickAddController.clear();
    _toggleAddForm();
    widget.onItemAdded?.call();
  }

  Color _getTypeColor(WorkingMemoryType type) {
    switch (type) {
      case WorkingMemoryType.quickNote:
        return Colors.blue;
      case WorkingMemoryType.temporaryReminder:
        return Colors.orange;
      case WorkingMemoryType.activeTask:
        return Colors.green;
      case WorkingMemoryType.reference:
        return Colors.purple;
      case WorkingMemoryType.calculation:
        return Colors.teal;
      case WorkingMemoryType.phoneNumber:
        return Colors.indigo;
      case WorkingMemoryType.address:
        return Colors.brown;
      case WorkingMemoryType.code:
        return Colors.red;
    }
  }

  IconData _getTypeIcon(WorkingMemoryType type) {
    switch (type) {
      case WorkingMemoryType.quickNote:
        return Icons.note;
      case WorkingMemoryType.temporaryReminder:
        return Icons.alarm;
      case WorkingMemoryType.activeTask:
        return Icons.task_alt;
      case WorkingMemoryType.reference:
        return Icons.bookmark;
      case WorkingMemoryType.calculation:
        return Icons.calculate;
      case WorkingMemoryType.phoneNumber:
        return Icons.phone;
      case WorkingMemoryType.address:
        return Icons.location_on;
      case WorkingMemoryType.code:
        return Icons.code;
    }
  }

  String _getTypeLabel(WorkingMemoryType type) {
    switch (type) {
      case WorkingMemoryType.quickNote:
        return 'Quick Note';
      case WorkingMemoryType.temporaryReminder:
        return 'Reminder';
      case WorkingMemoryType.activeTask:
        return 'Active Task';
      case WorkingMemoryType.reference:
        return 'Reference';
      case WorkingMemoryType.calculation:
        return 'Calculation';
      case WorkingMemoryType.phoneNumber:
        return 'Phone Number';
      case WorkingMemoryType.address:
        return 'Address';
      case WorkingMemoryType.code:
        return 'Code Snippet';
    }
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          Icons.memory,
          color: Colors.indigo[700],
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          'Working Memory',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.indigo[700],
              ),
        ),
        const Spacer(),
        IconButton(
          icon: Icon(
            _showAddForm ? Icons.close : Icons.add,
            size: 20,
          ),
          onPressed: _toggleAddForm,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }

  Widget _buildAddForm() {
    return SizeTransition(
      sizeFactor: CurvedAnimation(
        parent: _formController,
        curve: BrainAnimations.memoryCurve,
      ),
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.indigo[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.indigo[200]!),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<WorkingMemoryType>(
                    initialValue: _selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: WorkingMemoryType.values
                        .map((type) => DropdownMenuItem(
                              value: type,
                              child: Row(
                                children: [
                                  Icon(
                                    _getTypeIcon(type),
                                    size: 16,
                                    color: _getTypeColor(type),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(_getTypeLabel(type)),
                                ],
                              ),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedType = value);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _quickAddController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: _getHintText(_selectedType),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.all(12),
              ),
              onSubmitted: (_) => _addItem(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add to Memory'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo[700],
                      foregroundColor: Colors.white,
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

  String _getHintText(WorkingMemoryType type) {
    switch (type) {
      case WorkingMemoryType.quickNote:
        return 'Quick thought or note...';
      case WorkingMemoryType.temporaryReminder:
        return 'Remember to...';
      case WorkingMemoryType.activeTask:
        return 'Current task or action...';
      case WorkingMemoryType.reference:
        return 'Important reference info...';
      case WorkingMemoryType.calculation:
        return '2 + 2 = 4, or complex calculation...';
      case WorkingMemoryType.phoneNumber:
        return '+1 (555) 123-4567';
      case WorkingMemoryType.address:
        return '123 Main St, City, State';
      case WorkingMemoryType.code:
        return 'Code snippet or command...';
    }
  }

  Widget _buildMemoryItems() {
    final workingMemory = ref.watch(workingMemoryProvider);

    if (workingMemory.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.psychology_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              'Working memory is empty',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add quick notes, reminders, or temporary info',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: workingMemory.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = workingMemory[index];
        return CaptureEntranceAnimation(
          delay: Duration(milliseconds: index * 50),
          child: WorkingMemoryItemWidget(
            item: item,
            onRemove: () {
              ref
                  .read(externalBrainProvider.notifier)
                  .removeFromWorkingMemory(item.id);
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildAddForm(),
            const SizedBox(height: 12),
            _buildMemoryItems(),
          ],
        ),
      ),
    );
  }
}

class WorkingMemoryItemWidget extends ConsumerStatefulWidget {
  final WorkingMemoryItem item;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;

  const WorkingMemoryItemWidget({
    super.key,
    required this.item,
    this.onRemove,
    this.onTap,
  });

  @override
  ConsumerState<WorkingMemoryItemWidget> createState() =>
      _WorkingMemoryItemWidgetState();
}

class _WorkingMemoryItemWidgetState
    extends ConsumerState<WorkingMemoryItemWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _expireController;
  late Animation<double> _expireAnimation;
  bool _isExpiring = false;

  @override
  void initState() {
    super.initState();
    _expireController = AnimationController(
      duration: BrainAnimations.memoryExpireDuration,
      vsync: this,
    );
    _expireAnimation = CurvedAnimation(
      parent: _expireController,
      curve: Curves.easeInOut,
    );

    _checkExpiration();
  }

  @override
  void dispose() {
    _expireController.dispose();
    super.dispose();
  }

  void _checkExpiration() {
    if (widget.item.expiresAt != null) {
      final now = DateTime.now();
      final expiresAt = widget.item.expiresAt!;

      if (now.isAfter(expiresAt)) {
        _startExpiring();
      } else {
        final timeUntilExpiry = expiresAt.difference(now);
        Future.delayed(timeUntilExpiry, () {
          if (mounted) {
            _startExpiring();
          }
        });
      }
    }
  }

  void _startExpiring() {
    setState(() => _isExpiring = true);
    _expireController.forward();
  }

  Color _getTypeColor() {
    switch (widget.item.type) {
      case WorkingMemoryType.quickNote:
        return Colors.blue;
      case WorkingMemoryType.temporaryReminder:
        return Colors.orange;
      case WorkingMemoryType.activeTask:
        return Colors.green;
      case WorkingMemoryType.reference:
        return Colors.purple;
      case WorkingMemoryType.calculation:
        return Colors.teal;
      case WorkingMemoryType.phoneNumber:
        return Colors.indigo;
      case WorkingMemoryType.address:
        return Colors.brown;
      case WorkingMemoryType.code:
        return Colors.red;
    }
  }

  IconData _getTypeIcon() {
    switch (widget.item.type) {
      case WorkingMemoryType.quickNote:
        return Icons.note;
      case WorkingMemoryType.temporaryReminder:
        return Icons.alarm;
      case WorkingMemoryType.activeTask:
        return Icons.task_alt;
      case WorkingMemoryType.reference:
        return Icons.bookmark;
      case WorkingMemoryType.calculation:
        return Icons.calculate;
      case WorkingMemoryType.phoneNumber:
        return Icons.phone;
      case WorkingMemoryType.address:
        return Icons.location_on;
      case WorkingMemoryType.code:
        return Icons.code;
    }
  }

  Widget _buildExpirationIndicator() {
    if (widget.item.expiresAt == null) {
      return const SizedBox.shrink();
    }

    final now = DateTime.now();
    final expiresAt = widget.item.expiresAt!;
    final isExpired = now.isAfter(expiresAt);
    final timeLeft = expiresAt.difference(now);

    return AnimatedBuilder(
      animation: _expireAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isExpired
                ? Colors.red
                    .withValues(alpha: 0.1 + _expireAnimation.value * 0.2)
                : timeLeft.inMinutes < 5
                    ? Colors.orange.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            isExpired
                ? 'EXPIRED'
                : timeLeft.inHours > 0
                    ? '${timeLeft.inHours}h left'
                    : '${timeLeft.inMinutes}m left',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: isExpired
                      ? Colors.red[700]
                      : timeLeft.inMinutes < 5
                          ? Colors.orange[700]
                          : Colors.grey[600],
                ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _getTypeColor();

    return AnimatedBuilder(
      animation: _expireAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _isExpiring ? 1.0 - _expireAnimation.value * 0.1 : 1.0,
          child: Opacity(
            opacity: _isExpiring ? 1.0 - _expireAnimation.value * 0.5 : 1.0,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: color.withValues(alpha: 0.2),
                  width: widget.item.isPinned == true ? 2 : 1,
                ),
              ),
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        _getTypeIcon(),
                        size: 14,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.item.content,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: widget.item.isPinned == true
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (widget.item.isPinned == true) ...[
                                Icon(
                                  Icons.push_pin,
                                  size: 10,
                                  color: color,
                                ),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                _formatTime(widget.item.createdAt),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.grey[600],
                                      fontSize: 10,
                                    ),
                              ),
                              const Spacer(),
                              _buildExpirationIndicator(),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: widget.onRemove,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 24, minHeight: 24),
                      color: Colors.grey[600],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }
}
