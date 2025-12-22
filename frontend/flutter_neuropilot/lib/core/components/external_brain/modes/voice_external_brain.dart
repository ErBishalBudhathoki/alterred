import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/brain_animations.dart';
import '../state/external_brain_provider.dart';
import '../models/brain_capture_model.dart';
import '../models/context_snapshot_model.dart';

class VoiceExternalBrain extends ConsumerStatefulWidget {
  final bool isListening;
  final String? currentTranscript;
  final VoidCallback? onVoiceCapture;
  final VoidCallback? onMemoryAccess;

  const VoiceExternalBrain({
    super.key,
    required this.isListening,
    this.currentTranscript,
    this.onVoiceCapture,
    this.onMemoryAccess,
  });

  @override
  ConsumerState<VoiceExternalBrain> createState() => _VoiceExternalBrainState();
}

class _VoiceExternalBrainState extends ConsumerState<VoiceExternalBrain>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(VoiceExternalBrain oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Show/hide based on listening state or when there's a transcript
    final shouldShow = widget.isListening || 
                      (widget.currentTranscript?.isNotEmpty == true);
    
    if (shouldShow != _isVisible) {
      setState(() => _isVisible = shouldShow);
      if (shouldShow) {
        _slideController.forward();
      } else {
        _slideController.reverse();
      }
    }
  }

  Widget _buildVoiceCaptureInterface() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.indigo[50]!,
            Colors.white,
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Voice wave animation
          VoiceWaveAnimation(
            isListening: widget.isListening,
            color: Colors.indigo[700]!,
            size: 80,
          ),
          const SizedBox(height: 16),
          
          // Status text
          Text(
            widget.isListening 
                ? 'Listening for External Brain capture...'
                : 'Processing voice input...',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.indigo[700],
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          
          if (widget.currentTranscript?.isNotEmpty == true) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                widget.currentTranscript!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // TODO: Cancel capture
                    },
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (widget.currentTranscript?.isNotEmpty == true) {
                        final notifier = ref.read(externalBrainProvider.notifier);
                        await notifier.captureVoice(widget.currentTranscript!);
                        widget.onVoiceCapture?.call();
                      }
                    },
                    icon: const Icon(Icons.save, size: 16),
                    label: const Text('Capture'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo[700],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickMemoryAccess() {
    final workingMemory = ref.watch(workingMemoryProvider);
    final recentCaptures = ref.watch(activeCapturesProvider);

    if (workingMemory.isEmpty && recentCaptures.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.memory,
                size: 16,
                color: Colors.indigo[700],
              ),
              const SizedBox(width: 6),
              Text(
                'Quick Memory Access',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.indigo[700],
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: widget.onMemoryAccess,
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Working memory items
          if (workingMemory.isNotEmpty) ...[
            Text(
              'Working Memory',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            ...workingMemory.take(3).map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    _getMemoryTypeIcon(item.type),
                    size: 12,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.content,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )),
          ],
          
          // Recent captures
          if (recentCaptures.isNotEmpty) ...[
            if (workingMemory.isNotEmpty) const SizedBox(height: 8),
            Text(
              'Recent Captures',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            ...recentCaptures.take(2).map((capture) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    _getCaptureTypeIcon(capture.type),
                    size: 12,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      capture.title ?? capture.content,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  IconData _getMemoryTypeIcon(WorkingMemoryType type) {
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

  IconData _getCaptureTypeIcon(BrainCaptureType type) {
    return type.when(
      voice: (transcript, audioPath, confidence) => Icons.mic,
      text: (text) => Icons.text_fields,
      image: (imagePath, description) => Icons.image,
      task: (description, dueDate, priority, subtasks) => Icons.task_alt,
      note: (content, category) => Icons.note,
      reminder: (message, reminderTime, recurring) => Icons.alarm,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildVoiceCaptureInterface(),
            _buildQuickMemoryAccess(),
          ],
        ),
      ),
    );
  }
}

class VoiceBrainCommands extends ConsumerWidget {
  final String transcript;
  final VoidCallback? onCommandExecuted;

  const VoiceBrainCommands({
    super.key,
    required this.transcript,
    this.onCommandExecuted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commands = _parseVoiceCommands(transcript);
    
    if (commands.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.psychology,
                size: 16,
                color: Colors.amber[700],
              ),
              const SizedBox(width: 6),
              Text(
                'External Brain Commands',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.amber[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...commands.map((command) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: InkWell(
              onTap: () => _executeCommand(context, ref, command),
              child: Row(
                children: [
                  Icon(
                    command.icon,
                    size: 14,
                    color: Colors.amber[700],
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      command.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.amber[800],
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: Colors.amber[600],
                  ),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }

  List<VoiceCommand> _parseVoiceCommands(String transcript) {
    final commands = <VoiceCommand>[];
    final lower = transcript.toLowerCase();

    if (lower.contains('remember') || lower.contains('note')) {
      commands.add(VoiceCommand(
        type: VoiceCommandType.capture,
        description: 'Capture as note',
        icon: Icons.note_add,
        data: {'content': transcript},
      ));
    }

    if (lower.contains('task') || lower.contains('todo')) {
      commands.add(VoiceCommand(
        type: VoiceCommandType.task,
        description: 'Create task',
        icon: Icons.task_alt,
        data: {'content': transcript},
      ));
    }

    if (lower.contains('remind') || lower.contains('reminder')) {
      commands.add(VoiceCommand(
        type: VoiceCommandType.reminder,
        description: 'Set reminder',
        icon: Icons.alarm_add,
        data: {'content': transcript},
      ));
    }

    if (lower.contains('context') || lower.contains('snapshot')) {
      commands.add(VoiceCommand(
        type: VoiceCommandType.snapshot,
        description: 'Create context snapshot',
        icon: Icons.camera_alt,
        data: {'title': 'Voice snapshot'},
      ));
    }

    return commands;
  }

  Future<void> _executeCommand(BuildContext context, WidgetRef ref, VoiceCommand command) async {
    final notifier = ref.read(externalBrainProvider.notifier);

    switch (command.type) {
      case VoiceCommandType.capture:
        await notifier.captureText(command.data['content'] as String);
        break;
      case VoiceCommandType.task:
        await notifier.captureText(command.data['content'] as String);
        break;
      case VoiceCommandType.reminder:
        await notifier.addToWorkingMemory(
          command.data['content'] as String,
          WorkingMemoryType.temporaryReminder,
        );
        break;
      case VoiceCommandType.snapshot:
        await notifier.createSnapshot(
          DateTime.now().millisecondsSinceEpoch.toString(),
          {
            'title': command.data['title'] as String,
            'timestamp': DateTime.now().toIso8601String(),
            'source': 'voice',
          },
        );
        break;
    }

    onCommandExecuted?.call();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${command.description} completed'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}

class VoiceCommand {
  final VoiceCommandType type;
  final String description;
  final IconData icon;
  final Map<String, dynamic> data;

  VoiceCommand({
    required this.type,
    required this.description,
    required this.icon,
    required this.data,
  });
}

enum VoiceCommandType {
  capture,
  task,
  reminder,
  snapshot,
}

class VoiceBrainFloatingPanel extends ConsumerStatefulWidget {
  final bool isVisible;
  final VoidCallback? onTap;

  const VoiceBrainFloatingPanel({
    super.key,
    required this.isVisible,
    this.onTap,
  });

  @override
  ConsumerState<VoiceBrainFloatingPanel> createState() => _VoiceBrainFloatingPanelState();
}

class _VoiceBrainFloatingPanelState extends ConsumerState<VoiceBrainFloatingPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    if (widget.isVisible) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(VoiceBrainFloatingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final workingMemory = ref.watch(workingMemoryProvider);
    final hasActiveItems = workingMemory.isNotEmpty;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.indigo[700],
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(20),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.psychology,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Brain',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (hasActiveItems) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          workingMemory.length.toString(),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.indigo[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}