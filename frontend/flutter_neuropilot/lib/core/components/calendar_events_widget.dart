import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../design_tokens.dart';
import '../../state/session_state.dart'; // For apiClientProvider

class CalendarEventsWidget extends StatelessWidget {
  final List<dynamic> events;

  const CalendarEventsWidget({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: events.map((e) => _EventCard(event: e)).toList(),
    );
  }
}

class _EventCard extends ConsumerStatefulWidget {
  final dynamic event;

  const _EventCard({required this.event});

  @override
  ConsumerState<_EventCard> createState() => _EventCardState();
}

class _EventCardState extends ConsumerState<_EventCard> {
  late Map<String, dynamic> _eventData;
  bool _isDeleted = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _eventData = Map<String, dynamic>.from(widget.event);
  }

  Future<void> _launchUrl(String? url) async {
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _handleDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Event?'),
        content: const Text('Are you sure you want to delete this event?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final calendarId = _eventData['_calendarId'] ?? 'primary';

      final api = ref.read(apiClientProvider);
      await api.post('/calendar/events/delete', {
        'calendarId': calendarId,
        'eventId': _eventData['id'],
      });

      if (mounted) {
        setState(() {
          _isDeleted = true;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  Future<void> _handleEdit() async {
    final updated = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _EditEventDialog(event: _eventData),
    );

    if (updated != null) {
      setState(() => _isLoading = true);
      try {
        final api = ref.read(apiClientProvider);
        final calendarId = _eventData['_calendarId'] ?? 'primary';

        // Prepare updates
        final updates = {
          'summary': updated['summary'],
          'description': updated['description'],
        };

        // Handle dates
        // API expects ISO strings.
        // If All Day?
        // Basic impl: assume DateTime
        if (updated['start'] != null) {
          updates['start'] = {
            'dateTime': (updated['start'] as DateTime).toIso8601String()
          };
        }
        if (updated['end'] != null) {
          updates['end'] = {
            'dateTime': (updated['end'] as DateTime).toIso8601String()
          };
        }

        final res = await api.post('/calendar/events/update', {
          'calendarId': calendarId,
          'eventId': _eventData['id'],
          'updates': updates,
        });

        // Verify success
        if (res['ok'] == true) {
          // Merge updates into local state for immediate UI feedback
          setState(() {
            _eventData['summary'] = updated['summary'];
            _eventData['description'] = updated['description'];
            if (updated['start'] != null) {
              _eventData['start'] = {
                'dateTime': (updated['start'] as DateTime).toIso8601String()
              };
            }
            if (updated['end'] != null) {
              _eventData['end'] = {
                'dateTime': (updated['end'] as DateTime).toIso8601String()
              };
            }
            _isLoading = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Event updated')),
            );
          }
        } else {
          throw res['error'] ?? 'Unknown error';
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDeleted) return const SizedBox.shrink();

    final summary = _eventData['summary'] ?? 'Untitled';
    final location = _eventData['location'];
    final start = _eventData['start'] ?? {};
    final end = _eventData['end'] ?? {};
    final link = _eventData['htmlLink'];

    DateTime? startTime;
    DateTime? endTime;
    bool isAllDay = false;

    if (start['dateTime'] != null) {
      startTime = DateTime.tryParse(start['dateTime'])?.toLocal();
    } else if (start['date'] != null) {
      startTime = DateTime.tryParse(start['date'])?.toLocal();
      isAllDay = true;
    }

    if (end['dateTime'] != null) {
      endTime = DateTime.tryParse(end['dateTime'])?.toLocal();
    } else if (end['date'] != null) {
      endTime = DateTime.tryParse(end['date'])?.toLocal();
    }

    // Formats
    final monthFormat = DateFormat('MMM');
    final dayFormat = DateFormat('d');
    final timeFormat = DateFormat('h:mm a');

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final creator = _eventData['creator']?['email'] as String?;
    final organizer = _eventData['organizer']?['email'] as String?;
    final calendarSummary = _eventData['_calendarSummary'] as String?;

    String? displayInfo;
    if (calendarSummary != null && calendarSummary.isNotEmpty) {
      displayInfo = calendarSummary;
    } else if (organizer != null &&
        !organizer.contains('@group.calendar.google.com') &&
        !organizer.contains('@import.calendar.google.com')) {
      displayInfo = organizer;
    } else if (creator != null &&
        !creator.contains('@group.calendar.google.com') &&
        !creator.contains('@import.calendar.google.com')) {
      displayInfo = creator;
    }

    // Buttons Widget
    Widget buildButtons() {
      if (_isLoading) {
        return const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2));
      }
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Edit'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: _handleEdit,
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.delete, size: 16),
            label: const Text('Delete'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              visualDensity: VisualDensity.compact,
              side: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
            ),
            onPressed: _handleDelete,
          ),
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: DesignTokens.spacingMd),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
          onTap: () {
            if (link != null) {
              _launchUrl(link);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.spacingMd),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 600;

                final dateBlock = Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (startTime != null) ...[
                        Text(
                          monthFormat.format(startTime).toUpperCase(),
                          style: tt.labelSmall?.copyWith(
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          dayFormat.format(startTime),
                          style: tt.titleLarge?.copyWith(
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                            height: 1.0,
                          ),
                        ),
                      ] else
                        Icon(Icons.event, color: cs.onPrimaryContainer),
                    ],
                  ),
                );

                final detailsBlock = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary,
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        decoration:
                            _isLoading ? TextDecoration.lineThrough : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time,
                            size: 14, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          isAllDay
                              ? 'All Day'
                              : startTime != null
                                  ? '${timeFormat.format(startTime)}${endTime != null ? ' - ${timeFormat.format(endTime)}' : ''}'
                                  : 'Time TBD',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    if (location != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.location_on,
                              size: 14, color: cs.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (displayInfo != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 14, color: cs.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              displayInfo,
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                );

                if (isMobile) {
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            dateBlock,
                            const SizedBox(width: DesignTokens.spacingMd),
                            Expanded(child: detailsBlock),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [buildButtons()],
                        )
                      ]);
                } else {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      dateBlock,
                      const SizedBox(width: DesignTokens.spacingMd),
                      Expanded(child: detailsBlock),
                      const SizedBox(width: DesignTokens.spacingMd),
                      buildButtons(),
                    ],
                  );
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _EditEventDialog extends StatefulWidget {
  final Map<String, dynamic> event;

  const _EditEventDialog({required this.event});

  @override
  State<_EditEventDialog> createState() => _EditEventDialogState();
}

class _EditEventDialogState extends State<_EditEventDialog> {
  late TextEditingController _summaryCtrl;
  late TextEditingController _descCtrl;
  late DateTime _startDate;
  late TimeOfDay _startTime;
  late DateTime _endDate;
  late TimeOfDay _endTime;

  @override
  void initState() {
    super.initState();
    _summaryCtrl = TextEditingController(text: widget.event['summary'] ?? '');
    _descCtrl = TextEditingController(text: widget.event['description'] ?? '');

    // Parse times or default to now
    final start = widget.event['start'];
    final end = widget.event['end'];

    DateTime now = DateTime.now();
    if (start['dateTime'] != null) {
      _startDate = DateTime.parse(start['dateTime']).toLocal();
      _startTime = TimeOfDay.fromDateTime(_startDate);
    } else {
      _startDate = now;
      _startTime = TimeOfDay.fromDateTime(now);
    }

    if (end['dateTime'] != null) {
      _endDate = DateTime.parse(end['dateTime']).toLocal();
      _endTime = TimeOfDay.fromDateTime(_endDate);
    } else {
      _endDate = now.add(const Duration(hours: 1));
      _endTime = TimeOfDay.fromDateTime(_endDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Event'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _summaryCtrl,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 16),
            _buildDateTimeRow('Start', _startDate, _startTime, (d, t) {
              setState(() {
                _startDate = d;
                _startTime = t;
              });
            }),
            const SizedBox(height: 8),
            _buildDateTimeRow('End', _endDate, _endTime, (d, t) {
              setState(() {
                _endDate = d;
                _endTime = t;
              });
            }),
            const SizedBox(height: 16),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () {
              // Combine dates
              final startDt = DateTime(_startDate.year, _startDate.month,
                  _startDate.day, _startTime.hour, _startTime.minute);
              final endDt = DateTime(_endDate.year, _endDate.month,
                  _endDate.day, _endTime.hour, _endTime.minute);

              Navigator.pop(context, {
                'summary': _summaryCtrl.text,
                'description': _descCtrl.text,
                'start': startDt,
                'end': endDt,
              });
            },
            child: const Text('Save')),
      ],
    );
  }

  Widget _buildDateTimeRow(String label, DateTime date, TimeOfDay time,
      Function(DateTime, TimeOfDay) onChange) {
    return Row(
      children: [
        SizedBox(
            width: 40,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.bold))),
        Expanded(
          child: OutlinedButton(
            onPressed: () async {
              final d = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                  initialDate: date);
              if (d != null) onChange(d, time);
            },
            child: Text('${date.month}/${date.day}/${date.year}'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            onPressed: () async {
              final t =
                  await showTimePicker(context: context, initialTime: time);
              if (t != null) onChange(date, t);
            },
            child: Text(time.format(context)),
          ),
        ),
      ],
    );
  }
}
