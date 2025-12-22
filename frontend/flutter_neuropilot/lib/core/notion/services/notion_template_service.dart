import 'dart:async';
import '../models/notion_models.dart';
import 'notion_service.dart';
import '../../observability/logging_service.dart';

/// ADHD-focused Notion template service
class NotionTemplateService {
  static NotionTemplateService? _instance;
  static NotionTemplateService get instance => _instance ??= NotionTemplateService._();
  
  NotionTemplateService._();

  final Logger _logger = Logger('NotionTemplateService');
  final NotionService _notionService = NotionService.instance;

  /// Create a page from template
  Future<NotionPage> createFromTemplate({
    required NotionTemplate template,
    required String userId,
    Map<String, dynamic>? customData,
  }) async {
    try {
      final templateData = _getTemplateData(template, customData);
      
      final page = await _notionService.createPage(
        title: templateData['title'],
        blocks: templateData['blocks'],
        properties: templateData['properties'],
      );

      _logger.info('Created page from template', {
        'template': template.name,
        'page_id': page.id,
        'user_id': userId,
      });

      return page;

    } catch (e, stackTrace) {
      _logger.error('Failed to create page from template', {
        'template': template.name,
        'user_id': userId,
        'error': e.toString(),
      }, stackTrace);
      rethrow;
    }
  }

  /// Get template data for specific template
  Map<String, dynamic> _getTemplateData(NotionTemplate template, Map<String, dynamic>? customData) {
    final now = DateTime.now();
    final today = now.toIso8601String().split('T')[0];
    
    switch (template) {
      case NotionTemplate.dailyReflection:
        return _getDailyReflectionTemplate(today, customData);
      case NotionTemplate.weeklyReview:
        return _getWeeklyReviewTemplate(today, customData);
      case NotionTemplate.hyperfocusSession:
        return _getHyperfocusSessionTemplate(now, customData);
      case NotionTemplate.energyTracking:
        return _getEnergyTrackingTemplate(today, customData);
      case NotionTemplate.goalSetting:
        return _getGoalSettingTemplate(customData);
      case NotionTemplate.decisionLog:
        return _getDecisionLogTemplate(now, customData);
      case NotionTemplate.resourceLibrary:
        return _getResourceLibraryTemplate(customData);
      case NotionTemplate.moodTracker:
        return _getMoodTrackerTemplate(today, customData);
      case NotionTemplate.medicationLog:
        return _getMedicationLogTemplate(today, customData);
      case NotionTemplate.appointmentNotes:
        return _getAppointmentNotesTemplate(now, customData);
      case NotionTemplate.contextSnapshot:
        return _getContextSnapshotTemplate(now, customData);
      case NotionTemplate.achievementLog:
        return _getAchievementLogTemplate(now, customData);
      case NotionTemplate.strategyNotes:
        return _getStrategyNotesTemplate(customData);
      case NotionTemplate.sensoryEnvironment:
        return _getSensoryEnvironmentTemplate(customData);
      case NotionTemplate.transitionRitual:
        return _getTransitionRitualTemplate(customData);
    }
  }

  /// Daily Reflection Template
  Map<String, dynamic> _getDailyReflectionTemplate(String date, Map<String, dynamic>? customData) {
    return {
      'title': '📝 Daily Reflection - $date',
      'properties': {
        'Date': {
          'date': {'start': date},
        },
        'Energy Level': {
          'select': {'name': customData?['energy_level'] ?? 'Medium'},
        },
        'Mood': {
          'select': {'name': customData?['mood'] ?? 'Neutral'},
        },
      },
      'blocks': [
        {
          'object': 'block',
          'type': 'heading_2',
          'heading_2': {
            'rich_text': [{'type': 'text', 'text': {'content': '🌅 Morning Intentions'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': 'What are my top 3 priorities for today?'}}],
          },
        },
        {
          'object': 'block',
          'type': 'bulleted_list_item',
          'bulleted_list_item': {
            'rich_text': [{'type': 'text', 'text': {'content': '1. '}}],
          },
        },
        {
          'object': 'block',
          'type': 'bulleted_list_item',
          'bulleted_list_item': {
            'rich_text': [{'type': 'text', 'text': {'content': '2. '}}],
          },
        },
        {
          'object': 'block',
          'type': 'bulleted_list_item',
          'bulleted_list_item': {
            'rich_text': [{'type': 'text', 'text': {'content': '3. '}}],
          },
        },
        {
          'object': 'block',
          'type': 'heading_2',
          'heading_2': {
            'rich_text': [{'type': 'text', 'text': {'content': '⚡ Energy & Focus'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': 'How am I feeling today? What might affect my focus?'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': ''}}],
          },
        },
        {
          'object': 'block',
          'type': 'heading_2',
          'heading_2': {
            'rich_text': [{'type': 'text', 'text': {'content': '🌙 Evening Reflection'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': 'What went well today?'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': ''}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': 'What was challenging?'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': ''}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': 'What did I learn about myself?'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': ''}}],
          },
        },
      ],
    };
  }

  /// Hyperfocus Session Template
  Map<String, dynamic> _getHyperfocusSessionTemplate(DateTime startTime, Map<String, dynamic>? customData) {
    return {
      'title': '🎯 Hyperfocus Session - ${startTime.toIso8601String().split('T')[0]}',
      'properties': {
        'Start Time': {
          'date': {'start': startTime.toIso8601String()},
        },
        'Topic': {
          'rich_text': [{'type': 'text', 'text': {'content': customData?['topic'] ?? ''}}],
        },
        'Duration (planned)': {
          'number': customData?['planned_duration'] ?? 120,
        },
      },
      'blocks': [
        {
          'object': 'block',
          'type': 'heading_2',
          'heading_2': {
            'rich_text': [{'type': 'text', 'text': {'content': '🎯 Session Setup'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': 'What am I hyperfocusing on?'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': customData?['topic'] ?? ''}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': 'What do I want to achieve?'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': ''}}],
          },
        },
        {
          'object': 'block',
          'type': 'heading_2',
          'heading_2': {
            'rich_text': [{'type': 'text', 'text': {'content': '⏰ Break Reminders'}}],
          },
        },
        {
          'object': 'block',
          'type': 'to_do',
          'to_do': {
            'rich_text': [{'type': 'text', 'text': {'content': 'Take a break after 2 hours'}}],
            'checked': false,
          },
        },
        {
          'object': 'block',
          'type': 'to_do',
          'to_do': {
            'rich_text': [{'type': 'text', 'text': {'content': 'Drink water'}}],
            'checked': false,
          },
        },
        {
          'object': 'block',
          'type': 'to_do',
          'to_do': {
            'rich_text': [{'type': 'text', 'text': {'content': 'Stretch/move'}}],
            'checked': false,
          },
        },
        {
          'object': 'block',
          'type': 'heading_2',
          'heading_2': {
            'rich_text': [{'type': 'text', 'text': {'content': '📝 Session Notes'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': 'Key insights and progress:'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': ''}}],
          },
        },
        {
          'object': 'block',
          'type': 'heading_2',
          'heading_2': {
            'rich_text': [{'type': 'text', 'text': {'content': '🏁 Session Wrap-up'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': 'What did I accomplish?'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': ''}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': 'Next steps:'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': ''}}],
          },
        },
      ],
    };
  }

  /// Context Snapshot Template
  Map<String, dynamic> _getContextSnapshotTemplate(DateTime timestamp, Map<String, dynamic>? customData) {
    return {
      'title': '📸 Context Snapshot - ${timestamp.toIso8601String().split('T')[0]} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
      'properties': {
        'Timestamp': {
          'date': {'start': timestamp.toIso8601String()},
        },
        'Interruption Type': {
          'select': {'name': customData?['interruption_type'] ?? 'Unknown'},
        },
        'Priority': {
          'select': {'name': customData?['priority'] ?? 'Medium'},
        },
      },
      'blocks': [
        {
          'object': 'block',
          'type': 'heading_2',
          'heading_2': {
            'rich_text': [{'type': 'text', 'text': {'content': '🎯 Current Task'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': customData?['current_task'] ?? 'What was I working on?'}}],
          },
        },
        {
          'object': 'block',
          'type': 'heading_2',
          'heading_2': {
            'rich_text': [{'type': 'text', 'text': {'content': '🧠 Mental State'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': 'What was I thinking about?'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': customData?['thoughts'] ?? ''}}],
          },
        },
        {
          'object': 'block',
          'type': 'heading_2',
          'heading_2': {
            'rich_text': [{'type': 'text', 'text': {'content': '📋 Next Steps'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': 'When I return, I need to:'}}],
          },
        },
        {
          'object': 'block',
          'type': 'bulleted_list_item',
          'bulleted_list_item': {
            'rich_text': [{'type': 'text', 'text': {'content': customData?['next_step_1'] ?? ''}}],
          },
        },
        {
          'object': 'block',
          'type': 'bulleted_list_item',
          'bulleted_list_item': {
            'rich_text': [{'type': 'text', 'text': {'content': customData?['next_step_2'] ?? ''}}],
          },
        },
        {
          'object': 'block',
          'type': 'heading_2',
          'heading_2': {
            'rich_text': [{'type': 'text', 'text': {'content': '🔗 Resources & Links'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': 'Important links or files I was using:'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': customData?['resources'] ?? ''}}],
          },
        },
      ],
    };
  }

  /// Energy Tracking Template
  Map<String, dynamic> _getEnergyTrackingTemplate(String date, Map<String, dynamic>? customData) {
    return {
      'title': '⚡ Energy Tracking - $date',
      'properties': {
        'Date': {
          'date': {'start': date},
        },
        'Overall Energy': {
          'select': {'name': customData?['overall_energy'] ?? 'Medium'},
        },
      },
      'blocks': [
        {
          'object': 'block',
          'type': 'heading_2',
          'heading_2': {
            'rich_text': [{'type': 'text', 'text': {'content': '🌅 Morning (6-12 PM)'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': 'Energy Level: ___/10'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': 'What affected my energy?'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': ''}}],
          },
        },
        {
          'object': 'block',
          'type': 'heading_2',
          'heading_2': {
            'rich_text': [{'type': 'text', 'text': {'content': '☀️ Afternoon (12-6 PM)'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': 'Energy Level: ___/10'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': 'What affected my energy?'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': ''}}],
          },
        },
        {
          'object': 'block',
          'type': 'heading_2',
          'heading_2': {
            'rich_text': [{'type': 'text', 'text': {'content': '🌙 Evening (6-12 AM)'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': 'Energy Level: ___/10'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': 'What affected my energy?'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': ''}}],
          },
        },
        {
          'object': 'block',
          'type': 'heading_2',
          'heading_2': {
            'rich_text': [{'type': 'text', 'text': {'content': '📊 Patterns & Insights'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': 'What patterns do I notice?'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': ''}}],
          },
        },
      ],
    };
  }

  /// Weekly Review Template
  Map<String, dynamic> _getWeeklyReviewTemplate(String date, Map<String, dynamic>? customData) {
    return {
      'title': '📊 Weekly Review - Week of $date',
      'properties': {
        'Week Of': {
          'date': {'start': date},
        },
        'Overall Rating': {
          'select': {'name': customData?['overall_rating'] ?? 'Good'},
        },
      },
      'blocks': [
        {
          'object': 'block',
          'type': 'heading_2',
          'heading_2': {
            'rich_text': [{'type': 'text', 'text': {'content': '🎯 Goals Review'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': 'What goals did I set for this week?'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': ''}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': 'What did I accomplish?'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': ''}}],
          },
        },
        {
          'object': 'block',
          'type': 'heading_2',
          'heading_2': {
            'rich_text': [{'type': 'text', 'text': {'content': '🏆 Wins & Achievements'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': 'What went really well this week?'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': ''}}],
          },
        },
        {
          'object': 'block',
          'type': 'heading_2',
          'heading_2': {
            'rich_text': [{'type': 'text', 'text': {'content': '🔄 Challenges & Learning'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': 'What was challenging?'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': ''}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': 'What did I learn?'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': ''}}],
          },
        },
        {
          'object': 'block',
          'type': 'heading_2',
          'heading_2': {
            'rich_text': [{'type': 'text', 'text': {'content': '🎯 Next Week Planning'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': 'Top 3 priorities for next week:'}}],
          },
        },
        {
          'object': 'block',
          'type': 'bulleted_list_item',
          'bulleted_list_item': {
            'rich_text': [{'type': 'text', 'text': {'content': '1. '}}],
          },
        },
        {
          'object': 'block',
          'type': 'bulleted_list_item',
          'bulleted_list_item': {
            'rich_text': [{'type': 'text', 'text': {'content': '2. '}}],
          },
        },
        {
          'object': 'block',
          'type': 'bulleted_list_item',
          'bulleted_list_item': {
            'rich_text': [{'type': 'text', 'text': {'content': '3. '}}],
          },
        },
      ],
    };
  }

  /// Add other template methods here (goal setting, decision log, etc.)
  /// For brevity, I'll include a few more key ones:

  Map<String, dynamic> _getGoalSettingTemplate(Map<String, dynamic>? customData) {
    return {
      'title': '🎯 Goal Setting - ${customData?['goal_name'] ?? 'New Goal'}',
      'properties': {
        'Goal Type': {
          'select': {'name': customData?['goal_type'] ?? 'Personal'},
        },
        'Priority': {
          'select': {'name': customData?['priority'] ?? 'High'},
        },
        'Target Date': customData?['target_date'] != null ? {
          'date': {'start': customData!['target_date']},
        } : null,
      }..removeWhere((key, value) => value == null),
      'blocks': [
        {
          'object': 'block',
          'type': 'heading_2',
          'heading_2': {
            'rich_text': [{'type': 'text', 'text': {'content': '🎯 Goal Definition'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': 'What exactly do I want to achieve?'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': customData?['description'] ?? ''}}],
          },
        },
        {
          'object': 'block',
          'type': 'heading_2',
          'heading_2': {
            'rich_text': [{'type': 'text', 'text': {'content': '🧩 Breaking It Down'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': 'What are the smaller steps?'}}],
          },
        },
        {
          'object': 'block',
          'type': 'to_do',
          'to_do': {
            'rich_text': [{'type': 'text', 'text': {'content': 'Step 1: '}}],
            'checked': false,
          },
        },
        {
          'object': 'block',
          'type': 'to_do',
          'to_do': {
            'rich_text': [{'type': 'text', 'text': {'content': 'Step 2: '}}],
            'checked': false,
          },
        },
        {
          'object': 'block',
          'type': 'to_do',
          'to_do': {
            'rich_text': [{'type': 'text', 'text': {'content': 'Step 3: '}}],
            'checked': false,
          },
        },
      ],
    };
  }

  Map<String, dynamic> _getDecisionLogTemplate(DateTime timestamp, Map<String, dynamic>? customData) {
    return {
      'title': '🤔 Decision Log - ${customData?['decision_title'] ?? 'Important Decision'}',
      'properties': {
        'Date': {
          'date': {'start': timestamp.toIso8601String().split('T')[0]},
        },
        'Decision Type': {
          'select': {'name': customData?['decision_type'] ?? 'Personal'},
        },
        'Urgency': {
          'select': {'name': customData?['urgency'] ?? 'Medium'},
        },
      },
      'blocks': [
        {
          'object': 'block',
          'type': 'heading_2',
          'heading_2': {
            'rich_text': [{'type': 'text', 'text': {'content': '❓ The Decision'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': 'What decision do I need to make?'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': customData?['decision_description'] ?? ''}}],
          },
        },
        {
          'object': 'block',
          'type': 'heading_2',
          'heading_2': {
            'rich_text': [{'type': 'text', 'text': {'content': '⚖️ Options'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': 'Option A:'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': ''}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': 'Option B:'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': ''}}],
          },
        },
        {
          'object': 'block',
          'type': 'heading_2',
          'heading_2': {
            'rich_text': [{'type': 'text', 'text': {'content': '✅ Final Decision'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': 'I decided to:'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': ''}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': 'Why:'}}],
          },
        },
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': ''}}],
          },
        },
      ],
    };
  }

  // Add placeholder methods for remaining templates
  Map<String, dynamic> _getResourceLibraryTemplate(Map<String, dynamic>? customData) => _getBasicTemplate('📚 Resource Library', customData);
  Map<String, dynamic> _getMoodTrackerTemplate(String date, Map<String, dynamic>? customData) => _getBasicTemplate('😊 Mood Tracker - $date', customData);
  Map<String, dynamic> _getMedicationLogTemplate(String date, Map<String, dynamic>? customData) => _getBasicTemplate('💊 Medication Log - $date', customData);
  Map<String, dynamic> _getAppointmentNotesTemplate(DateTime timestamp, Map<String, dynamic>? customData) => _getBasicTemplate('📅 Appointment Notes', customData);
  Map<String, dynamic> _getAchievementLogTemplate(DateTime timestamp, Map<String, dynamic>? customData) => _getBasicTemplate('🏆 Achievement Log', customData);
  Map<String, dynamic> _getStrategyNotesTemplate(Map<String, dynamic>? customData) => _getBasicTemplate('💡 Strategy Notes', customData);
  Map<String, dynamic> _getSensoryEnvironmentTemplate(Map<String, dynamic>? customData) => _getBasicTemplate('🌟 Sensory Environment', customData);
  Map<String, dynamic> _getTransitionRitualTemplate(Map<String, dynamic>? customData) => _getBasicTemplate('🔄 Transition Ritual', customData);

  Map<String, dynamic> _getBasicTemplate(String title, Map<String, dynamic>? customData) {
    return {
      'title': title,
      'properties': {},
      'blocks': [
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [{'type': 'text', 'text': {'content': 'Template content coming soon...'}}],
          },
        },
      ],
    };
  }
}