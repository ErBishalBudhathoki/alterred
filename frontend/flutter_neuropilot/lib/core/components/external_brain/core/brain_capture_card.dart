import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/brain_capture_model.dart';
import '../state/external_brain_provider.dart';
import 'package:altered/state/notion_provider.dart';
import 'brain_animations.dart';

class BrainCaptureCard extends ConsumerStatefulWidget {
  final BrainCapture capture;
  final VoidCallback? onTap;
  final VoidCallback? onComplete;
  final VoidCallback? onArchive;
  final bool showActions;
  final bool isCompact;

  const BrainCaptureCard({
    super.key,
    required this.capture,
    this.onTap,
    this.onComplete,
    this.onArchive,
    this.showActions = true,
    this.isCompact = false,
  });

  @override
  ConsumerState<BrainCaptureCard> createState() => _BrainCaptureCardState();
}

class _BrainCaptureCardState extends ConsumerState<BrainCaptureCard>
    with TickerProviderStateMixin {
  late AnimationController _actionController;
  late Animation<double> _actionAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _actionController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _actionAnimation = CurvedAnimation(
      parent: _actionController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _actionController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _actionController.forward();
      } else {
        _actionController.reverse();
      }
    });
  }

  Color _getStatusColor() {
    switch (widget.capture.status) {
      case BrainCaptureStatus.pending:
        return Colors.orange;
      case BrainCaptureStatus.processing:
        return Colors.blue;
      case BrainCaptureStatus.structured:
        return Colors.green;
      case BrainCaptureStatus.completed:
        return Colors.teal;
      case BrainCaptureStatus.archived:
        return Colors.grey;
      case BrainCaptureStatus.failed:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon() {
    return widget.capture.type.when(
      voice: (transcript, audioPath, confidence) => Icons.mic,
      text: (text) => Icons.text_fields,
      image: (imagePath, description) => Icons.image,
      task: (description, dueDate, priority, subtasks) => Icons.task_alt,
      note: (content, category) => Icons.note,
      reminder: (message, reminderTime, recurring) => Icons.alarm,
    );
  }

  String _getTypeLabel() {
    return widget.capture.type.when(
      voice: (transcript, audioPath, confidence) => 'Voice',
      text: (text) => 'Text',
      image: (imagePath, description) => 'Image',
      task: (description, dueDate, priority, subtasks) => 'Task',
      note: (content, category) => 'Note',
      reminder: (message, reminderTime, recurring) => 'Reminder',
    );
  }

  Widget _buildStatusIndicator() {
    final color = _getStatusColor();
    final isProcessing = widget.capture.status == BrainCaptureStatus.processing;

    return ProcessingAnimation(
      isProcessing: isProcessing,
      color: color,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getStatusColor().withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getTypeIcon(),
            size: 16,
            color: _getStatusColor(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.capture.title ?? _getTypeLabel(),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  _buildStatusIndicator(),
                  const SizedBox(width: 6),
                  Text(
                    widget.capture.status?.name.toUpperCase() ?? 'UNKNOWN',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _getStatusColor(),
                      fontWeight: FontWeight.w500,
                      fontSize: 10,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatTime(widget.capture.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (widget.showActions) ...[
          const SizedBox(width: 8),
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
      ],
    );
  }

  Widget _buildContent() {
    if (widget.isCompact && !_isExpanded) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Text(
            widget.capture.content,
            style: Theme.of(context).textTheme.bodyMedium,
            maxLines: _isExpanded ? null : 3,
            overflow: _isExpanded ? null : TextOverflow.ellipsis,
          ),
        ),
        if (widget.capture.tags?.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: widget.capture.tags!.map((tag) => Chip(
              label: Text(
                tag,
                style: const TextStyle(fontSize: 11),
              ),
              backgroundColor: Colors.blue[50],
              side: BorderSide(color: Colors.blue[200]!),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            )).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildActions() {
    if (!widget.showActions || !_isExpanded) {
      return const SizedBox.shrink();
    }

    return SizeTransition(
      sizeFactor: _actionAnimation,
      child: Column(
        children: [
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              if (widget.capture.status != BrainCaptureStatus.completed) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onComplete,
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Complete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green[700],
                      side: BorderSide(color: Colors.green[300]!),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _saveToNotion(),
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('Notion'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6366F1),
                    side: const BorderSide(color: Color(0xFF6366F1)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onArchive,
                  icon: const Icon(Icons.archive, size: 16),
                  label: const Text('Archive'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    side: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _saveToNotion() async {
    try {
      final notionNotifier = ref.read(notionProvider.notifier);
      await notionNotifier.createQuickNote(
        '${widget.capture.title ?? _getTypeLabel()}: ${widget.capture.content}'
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('💾 Saved to Notion successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save to Notion: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
    return CaptureEntranceAnimation(
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: widget.onTap ?? _toggleExpanded,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                _buildContent(),
                _buildActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class QuickCaptureWidget extends ConsumerStatefulWidget {
  final VoidCallback? onCapture;
  final bool isVoiceMode;
  final bool isListening;

  const QuickCaptureWidget({
    super.key,
    this.onCapture,
    this.isVoiceMode = false,
    this.isListening = false,
  });

  @override
  ConsumerState<QuickCaptureWidget> createState() => _QuickCaptureWidgetState();
}

class _QuickCaptureWidgetState extends ConsumerState<QuickCaptureWidget> {
  final TextEditingController _textController = TextEditingController();
  bool _isExpanded = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _captureText() async {
    if (_textController.text.trim().isEmpty) return;

    final notifier = ref.read(externalBrainProvider.notifier);
    await notifier.captureText(_textController.text.trim());
    
    _textController.clear();
    setState(() => _isExpanded = false);
    widget.onCapture?.call();
  }

  Widget _buildVoiceMode() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue[50]!,
            Colors.indigo[50]!,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isListening ? Colors.blue : Colors.grey[300]!,
          width: widget.isListening ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          VoiceWaveAnimation(
            isListening: widget.isListening,
            color: Colors.blue,
            size: 80,
          ),
          const SizedBox(height: 16),
          Text(
            widget.isListening ? 'Listening...' : 'Tap to speak',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.blue[700],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isListening 
                ? 'Speak your thoughts, tasks, or reminders'
                : 'Voice capture ready',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTextMode() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: TextField(
              controller: _textController,
              maxLines: _isExpanded ? 4 : 1,
              decoration: InputDecoration(
                hintText: 'Quick capture: tasks, notes, reminders...',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isExpanded)
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => setState(() => _isExpanded = false),
                      ),
                    IconButton(
                      icon: Icon(
                        _isExpanded ? Icons.send : Icons.expand_more,
                        size: 20,
                      ),
                      onPressed: _isExpanded ? _captureText : () => setState(() => _isExpanded = true),
                    ),
                  ],
                ),
              ),
              onTap: () {
                if (!_isExpanded) {
                  setState(() => _isExpanded = true);
                }
              },
              onSubmitted: (_) => _captureText(),
            ),
          ),
          if (_isExpanded) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _captureText,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Capture'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    _textController.clear();
                    setState(() => _isExpanded = false);
                  },
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.isVoiceMode ? _buildVoiceMode() : _buildTextMode();
  }
}