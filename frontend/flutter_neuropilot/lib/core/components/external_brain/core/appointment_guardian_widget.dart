import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'brain_animations.dart';

class AppointmentGuardianWidget extends ConsumerStatefulWidget {
  final bool isCompact;
  final VoidCallback? onAppointmentTap;

  const AppointmentGuardianWidget({
    super.key,
    this.isCompact = false,
    this.onAppointmentTap,
  });

  @override
  ConsumerState<AppointmentGuardianWidget> createState() =>
      _AppointmentGuardianWidgetState();
}

class _AppointmentGuardianWidgetState
    extends ConsumerState<AppointmentGuardianWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  List<CalendarEvent> _upcomingEvents = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _loadUpcomingEvents();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadUpcomingEvents() async {
    setState(() => _isLoading = true);

    // TODO: Implement calendar API integration
    await Future.delayed(const Duration(seconds: 1));

    // Mock data for demonstration
    setState(() {
      _upcomingEvents = [
        CalendarEvent(
          id: '1',
          title: 'Team Meeting',
          startTime: DateTime.now().add(const Duration(minutes: 30)),
          endTime: DateTime.now().add(const Duration(minutes: 90)),
          location: 'Conference Room A',
          isImportant: true,
        ),
        CalendarEvent(
          id: '2',
          title: 'Doctor Appointment',
          startTime: DateTime.now().add(const Duration(hours: 2)),
          endTime: DateTime.now().add(const Duration(hours: 3)),
          location: 'Medical Center',
          isImportant: true,
          preparationTime: const Duration(minutes: 15),
        ),
        CalendarEvent(
          id: '3',
          title: 'Project Review',
          startTime: DateTime.now().add(const Duration(hours: 4)),
          endTime: DateTime.now().add(const Duration(hours: 5)),
          isImportant: false,
        ),
      ];
      _isLoading = false;
    });

    _checkForUrgentEvents();
  }

  void _checkForUrgentEvents() {
    final now = DateTime.now();
    final urgentEvents = _upcomingEvents.where((event) {
      final timeUntil = event.startTime.difference(now);
      return timeUntil.inMinutes <= 15 && timeUntil.inMinutes > 0;
    }).toList();

    if (urgentEvents.isNotEmpty) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
    }
  }

  Widget _buildHeader() {
    return Row(
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Icon(
                Icons.event_available,
                color: Colors.green[700],
                size: 20,
              ),
            );
          },
        ),
        const SizedBox(width: 8),
        Text(
          'Appointment Guardian',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.green[700],
              ),
        ),
        const Spacer(),
        if (_isLoading)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _loadUpcomingEvents,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
      ],
    );
  }

  Widget _buildEventsList() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_upcomingEvents.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.event_note,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              'No upcoming appointments',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your calendar is clear for now',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _upcomingEvents.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final event = _upcomingEvents[index];
        return CaptureEntranceAnimation(
          delay: Duration(milliseconds: index * 100),
          child: AppointmentEventCard(
            event: event,
            onTap: widget.onAppointmentTap,
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
            const SizedBox(height: 12),
            _buildEventsList(),
          ],
        ),
      ),
    );
  }
}

class AppointmentEventCard extends StatefulWidget {
  final CalendarEvent event;
  final VoidCallback? onTap;

  const AppointmentEventCard({
    super.key,
    required this.event,
    this.onTap,
  });

  @override
  State<AppointmentEventCard> createState() => _AppointmentEventCardState();
}

class _AppointmentEventCardState extends State<AppointmentEventCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _urgencyController;
  late Animation<Color?> _urgencyAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _urgencyController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    final urgencyColor = _getEventUrgencyColor();
    _urgencyAnimation = ColorTween(
      begin: urgencyColor.withValues(alpha: 0.1),
      end: urgencyColor.withValues(alpha: 0.3),
    ).animate(CurvedAnimation(
      parent: _urgencyController,
      curve: Curves.easeInOut,
    ));

    _checkUrgency();
  }

  @override
  void dispose() {
    _urgencyController.dispose();
    super.dispose();
  }

  void _checkUrgency() {
    final now = DateTime.now();
    final timeUntil = widget.event.startTime.difference(now);

    if (timeUntil.inMinutes <= 15 && timeUntil.inMinutes > 0) {
      _urgencyController.repeat(reverse: true);
    }
  }

  Color _getEventUrgencyColor() {
    final now = DateTime.now();
    final timeUntil = widget.event.startTime.difference(now);

    if (timeUntil.inMinutes <= 5) {
      return Colors.red;
    } else if (timeUntil.inMinutes <= 15) {
      return Colors.orange;
    } else if (timeUntil.inMinutes <= 30) {
      return Colors.amber;
    } else {
      return Colors.blue;
    }
  }

  String _getTimeUntilText() {
    final now = DateTime.now();
    final timeUntil = widget.event.startTime.difference(now);

    if (timeUntil.isNegative) {
      return 'Started ${_formatDuration(timeUntil.abs())} ago';
    } else if (timeUntil.inMinutes < 1) {
      return 'Starting now';
    } else if (timeUntil.inMinutes <= 60) {
      return 'In ${timeUntil.inMinutes} minutes';
    } else if (timeUntil.inHours <= 24) {
      return 'In ${timeUntil.inHours} hours';
    } else {
      return 'In ${timeUntil.inDays} days';
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }

  Widget _buildPreparationReminder() {
    if (widget.event.preparationTime == null) {
      return const SizedBox.shrink();
    }

    final now = DateTime.now();
    final prepTime =
        widget.event.startTime.subtract(widget.event.preparationTime!);
    final timeUntilPrep = prepTime.difference(now);

    if (timeUntilPrep.inMinutes > 30 || timeUntilPrep.isNegative) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.amber[200]!),
      ),
      child: Row(
        children: [
          Icon(
            Icons.schedule,
            size: 14,
            color: Colors.amber[700],
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              timeUntilPrep.isNegative
                  ? 'Preparation time started'
                  : 'Prepare in ${timeUntilPrep.inMinutes} minutes',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.amber[700],
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransitionTime() {
    if (widget.event.location == null) {
      return const SizedBox.shrink();
    }

    // Estimate travel time based on location (simplified)
    final estimatedTravelTime = _estimateTravelTime(widget.event.location!);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Icon(
            Icons.directions,
            size: 14,
            color: Colors.blue[700],
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Allow $estimatedTravelTime minutes travel time',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  int _estimateTravelTime(String location) {
    // Simplified travel time estimation
    if (location.toLowerCase().contains('home') ||
        location.toLowerCase().contains('office')) {
      return 5;
    } else if (location.toLowerCase().contains('center') ||
        location.toLowerCase().contains('hospital') ||
        location.toLowerCase().contains('clinic')) {
      return 20;
    } else {
      return 15;
    }
  }

  Widget _buildActions() {
    if (!_isExpanded) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        const SizedBox(height: 8),
        const Divider(height: 1),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  // TODO: Implement snooze functionality
                },
                icon: const Icon(Icons.snooze, size: 16),
                label: const Text('Snooze'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: Implement join/navigate functionality
                },
                icon: const Icon(Icons.launch, size: 16),
                label: const Text('Join/Navigate'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getEventUrgencyColor(),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final urgencyColor = _getEventUrgencyColor();

    return AnimatedBuilder(
      animation: _urgencyAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: _urgencyAnimation.value,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: urgencyColor.withValues(alpha: 0.3),
              width: widget.event.isImportant ? 2 : 1,
            ),
          ),
          child: InkWell(
            onTap: () {
              setState(() => _isExpanded = !_isExpanded);
              widget.onTap?.call();
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: urgencyColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          widget.event.isImportant
                              ? Icons.priority_high
                              : Icons.event,
                          size: 14,
                          color: urgencyColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.event.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _getTimeUntilText(),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: urgencyColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                  if (widget.event.location != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 12,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.event.location!,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_isExpanded) ...[
                    _buildPreparationReminder(),
                    _buildTransitionTime(),
                    _buildActions(),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class CalendarEvent {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String? location;
  final String? description;
  final bool isImportant;
  final Duration? preparationTime;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.location,
    this.description,
    this.isImportant = false,
    this.preparationTime,
  });
}
