import 'package:flutter/material.dart';
import '../neuro_theme.dart';

class TaskQuestCard extends StatefulWidget {
  final String taskName;
  final List<dynamic> subtasks;
  final Map<String, dynamic> gamification;
  final Function(String) onTaskComplete;

  const TaskQuestCard({
    super.key,
    required this.taskName,
    required this.subtasks,
    required this.gamification,
    required this.onTaskComplete,
  });

  @override
  State<TaskQuestCard> createState() => _TaskQuestCardState();
}

class _TaskQuestCardState extends State<TaskQuestCard>
    with SingleTickerProviderStateMixin {
  int _currentPoints = 0;
  int _streak = 0;
  late List<bool> _completed;
  late AnimationController _controller;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _completed = List.filled(widget.subtasks.length, false);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _progressAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleTask(int index) {
    setState(() {
      _completed[index] = !_completed[index];
      if (_completed[index]) {
        _currentPoints += (widget.subtasks[index]['points'] as int? ?? 10);
        _streak++;
      } else {
        _currentPoints -= (widget.subtasks[index]['points'] as int? ?? 10);
        _streak = 0;
      }

      double progress =
          _completed.where((c) => c).length / widget.subtasks.length;
      _progressAnimation = Tween<double>(
        begin: _progressAnimation.value,
        end: progress,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

      _controller.forward(from: 0);
    });

    if (_completed.every((c) => c)) {
      widget.onTaskComplete(widget.taskName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NeuroDashboardTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: NeuroDashboardTheme.primary.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: NeuroDashboardTheme.primary.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.taskName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: NeuroDashboardTheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt,
                        size: 16, color: NeuroDashboardTheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      '$_currentPoints XP',
                      style: const TextStyle(
                        color: NeuroDashboardTheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _progressAnimation.value,
                  backgroundColor: NeuroDashboardTheme.backgroundDark,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      _progressAnimation.value == 1.0
                          ? Colors.green
                          : NeuroDashboardTheme.primary),
                  minHeight: 10,
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.subtasks.length,
            itemBuilder: (context, index) {
              final task = widget.subtasks[index];
              final isDone = _completed[index];
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isDone
                      ? NeuroDashboardTheme.primary.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: CheckboxListTile(
                  title: Text(
                    task['text'],
                    style: TextStyle(
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      color: isDone
                          ? Colors.grey
                          : NeuroDashboardTheme.accentBeige,
                    ),
                  ),
                  secondary: Text(
                    '+${task['points']} XP',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDone ? Colors.grey : NeuroDashboardTheme.primary,
                    ),
                  ),
                  value: isDone,
                  activeColor: NeuroDashboardTheme.primary,
                  onChanged: (val) => _toggleTask(index),
                ),
              );
            },
          ),
          if (_streak > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Center(
                child: Text(
                  "🔥 $_streak Streak! Keep going!",
                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
