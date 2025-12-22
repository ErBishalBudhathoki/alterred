import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/a2a_connection_model.dart';
import 'brain_animations.dart';

class A2AConnectionCard extends ConsumerStatefulWidget {
  final A2AConnection connection;
  final VoidCallback? onTap;
  final VoidCallback? onMessage;
  final VoidCallback? onDisconnect;
  final bool showActions;

  const A2AConnectionCard({
    super.key,
    required this.connection,
    this.onTap,
    this.onMessage,
    this.onDisconnect,
    this.showActions = true,
  });

  @override
  ConsumerState<A2AConnectionCard> createState() => _A2AConnectionCardState();
}

class _A2AConnectionCardState extends ConsumerState<A2AConnectionCard>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: BrainAnimations.connectionPulseDuration,
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: BrainAnimations.connectionCurve,
    ));

    if (widget.connection.status == A2AConnectionStatus.connected) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _getStatusColor() {
    switch (widget.connection.status) {
      case A2AConnectionStatus.connected:
        return Colors.green;
      case A2AConnectionStatus.pending:
        return Colors.orange;
      case A2AConnectionStatus.disconnected:
        return Colors.grey;
      case A2AConnectionStatus.blocked:
        return Colors.red;
      case A2AConnectionStatus.error:
        return Colors.red;
    }
  }

  IconData _getTypeIcon() {
    switch (widget.connection.connectionType) {
      case A2AConnectionType.accountabilityPartner:
        return Icons.handshake;
      case A2AConnectionType.coach:
        return Icons.sports;
      case A2AConnectionType.friend:
        return Icons.people;
      case A2AConnectionType.colleague:
        return Icons.work;
      case A2AConnectionType.family:
        return Icons.family_restroom;
      case A2AConnectionType.therapist:
        return Icons.psychology;
      default:
        return Icons.person;
    }
  }

  String _getTypeLabel() {
    switch (widget.connection.connectionType) {
      case A2AConnectionType.accountabilityPartner:
        return 'Accountability Partner';
      case A2AConnectionType.coach:
        return 'Coach';
      case A2AConnectionType.friend:
        return 'Friend';
      case A2AConnectionType.colleague:
        return 'Colleague';
      case A2AConnectionType.family:
        return 'Family';
      case A2AConnectionType.therapist:
        return 'Therapist';
      default:
        return 'Connection';
    }
  }

  Widget _buildStatusIndicator() {
    final color = _getStatusColor();
    final isConnected =
        widget.connection.status == A2AConnectionStatus.connected;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Transform.scale(
          scale: isConnected ? _pulseAnimation.value : 1.0,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: isConnected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatar() {
    return Stack(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: _getStatusColor().withValues(alpha: 0.1),
          backgroundImage: widget.connection.partnerAvatar != null
              ? NetworkImage(widget.connection.partnerAvatar!)
              : null,
          child: widget.connection.partnerAvatar == null
              ? Icon(
                  _getTypeIcon(),
                  color: _getStatusColor(),
                  size: 20,
                )
              : null,
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: _buildStatusIndicator(),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        _buildAvatar(),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.connection.partnerName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                _getTypeLabel(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    widget.connection.status.name.toUpperCase(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _getStatusColor(),
                          fontWeight: FontWeight.w500,
                          fontSize: 10,
                        ),
                  ),
                  if (widget.connection.lastActivity != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '• ${_formatTime(widget.connection.lastActivity!)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[500],
                            fontSize: 10,
                          ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (widget.showActions) ...[
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
      ],
    );
  }

  Widget _buildSharedGoals() {
    if (widget.connection.sharedGoals?.isEmpty != false) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'Shared Goals',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: widget.connection.sharedGoals!
              .map((goal) => Chip(
                    label: Text(
                      goal,
                      style: const TextStyle(fontSize: 11),
                    ),
                    backgroundColor: _getStatusColor().withValues(alpha: 0.1),
                    side: BorderSide(
                        color: _getStatusColor().withValues(alpha: 0.3)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildActions() {
    if (!widget.showActions || !_isExpanded) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed:
                    widget.connection.status == A2AConnectionStatus.connected
                        ? widget.onMessage
                        : null,
                icon: const Icon(Icons.message, size: 16),
                label: const Text('Message'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getStatusColor(),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: widget.onDisconnect,
              icon: const Icon(Icons.link_off, size: 16),
              label: const Text('Disconnect'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red[700],
                side: BorderSide(color: Colors.red[300]!),
              ),
            ),
          ],
        ),
      ],
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
    return CaptureEntranceAnimation(
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap:
              widget.onTap ?? () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                if (_isExpanded) ...[
                  _buildSharedGoals(),
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

class A2AConnectionSetup extends ConsumerStatefulWidget {
  final VoidCallback? onConnectionCreated;

  const A2AConnectionSetup({
    super.key,
    this.onConnectionCreated,
  });

  @override
  ConsumerState<A2AConnectionSetup> createState() => _A2AConnectionSetupState();
}

class _A2AConnectionSetupState extends ConsumerState<A2AConnectionSetup> {
  final TextEditingController _partnerIdController = TextEditingController();
  final TextEditingController _partnerNameController = TextEditingController();
  A2AConnectionType _selectedType = A2AConnectionType.accountabilityPartner;
  bool _isConnecting = false;

  @override
  void dispose() {
    _partnerIdController.dispose();
    _partnerNameController.dispose();
    super.dispose();
  }

  Future<void> _connectPartner() async {
    if (_partnerIdController.text.trim().isEmpty ||
        _partnerNameController.text.trim().isEmpty) {
      return;
    }

    setState(() => _isConnecting = true);

    // TODO: Implement A2A connection logic
    await Future.delayed(const Duration(seconds: 2)); // Simulate API call

    setState(() => _isConnecting = false);

    _partnerIdController.clear();
    _partnerNameController.clear();
    widget.onConnectionCreated?.call();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connection request sent'),
          backgroundColor: Colors.green,
        ),
      );
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
            Row(
              children: [
                Icon(
                  Icons.link,
                  color: Colors.blue[700],
                ),
                const SizedBox(width: 8),
                Text(
                  'Connect with Partner',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _partnerIdController,
              decoration: const InputDecoration(
                labelText: 'Partner ID',
                hintText: 'PART-ABC123-XYZ789',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_add),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _partnerNameController,
              decoration: const InputDecoration(
                labelText: 'Partner Name',
                hintText: 'Enter their name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<A2AConnectionType>(
              initialValue: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Connection Type',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: A2AConnectionType.values
                  .map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(_getTypeLabel(type)),
                      ))
                  .toList(),
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
                onPressed: _isConnecting ? null : _connectPartner,
                icon: _isConnecting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.link),
                label: Text(_isConnecting
                    ? 'Connecting...'
                    : 'Send Connection Request'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.blue[700],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ask your partner to share their Partner ID with you. You can find your ID in Settings.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.blue[700],
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTypeLabel(A2AConnectionType type) {
    switch (type) {
      case A2AConnectionType.accountabilityPartner:
        return 'Accountability Partner';
      case A2AConnectionType.coach:
        return 'Coach';
      case A2AConnectionType.friend:
        return 'Friend';
      case A2AConnectionType.colleague:
        return 'Colleague';
      case A2AConnectionType.family:
        return 'Family';
      case A2AConnectionType.therapist:
        return 'Therapist';
    }
  }
}

class A2AMessageWidget extends StatelessWidget {
  final A2AMessage message;
  final bool isOutgoing;

  const A2AMessageWidget({
    super.key,
    required this.message,
    required this.isOutgoing,
  });

  Color _getTypeColor() {
    switch (message.type) {
      case A2AMessageType.encouragement:
        return Colors.green;
      case A2AMessageType.taskUpdate:
        return Colors.blue;
      case A2AMessageType.checkIn:
        return Colors.orange;
      case A2AMessageType.celebration:
        return Colors.purple;
      case A2AMessageType.support:
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon() {
    switch (message.type) {
      case A2AMessageType.encouragement:
        return Icons.thumb_up;
      case A2AMessageType.taskUpdate:
        return Icons.task_alt;
      case A2AMessageType.checkIn:
        return Icons.check_circle;
      case A2AMessageType.celebration:
        return Icons.celebration;
      case A2AMessageType.support:
        return Icons.favorite;
      default:
        return Icons.message;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getTypeColor();

    return Align(
      alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Card(
          color: isOutgoing ? color.withValues(alpha: 0.1) : Colors.grey[100],
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getTypeIcon(),
                      size: 14,
                      color: color,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      message.type.name.toUpperCase(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                    ),
                    const Spacer(),
                    Text(
                      _formatTime(message.timestamp),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                            fontSize: 10,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  message.content['text'] as String? ?? 'No content',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }
}
