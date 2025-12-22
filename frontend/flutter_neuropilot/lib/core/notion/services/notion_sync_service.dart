import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notion_models.dart';
import 'notion_service.dart';
import 'notion_auth_service.dart';
import '../../observability/logging_service.dart';

/// Bidirectional sync service between Notion and Firestore
class NotionSyncService {
  static NotionSyncService? _instance;
  static NotionSyncService get instance => _instance ??= NotionSyncService._();
  
  NotionSyncService._();

  final Logger _logger = Logger('NotionSyncService');
  final NotionService _notionService = NotionService.instance;
  final NotionAuthService _authService = NotionAuthService.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  final StreamController<NotionSyncOperation> _syncController = StreamController.broadcast();
  final Map<String, NotionSyncOperation> _activeSyncs = {};
  Timer? _backgroundSyncTimer;
  bool _isInitialized = false;

  /// Stream of sync operations
  Stream<NotionSyncOperation> get syncStream => _syncController.stream;

  /// Initialize the sync service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Start background sync timer
      _backgroundSyncTimer = Timer.periodic(
        const Duration(minutes: 15),
        (_) => _performBackgroundSync(),
      );

      _isInitialized = true;
      _logger.info('Notion sync service initialized');

    } catch (e, stackTrace) {
      _logger.error('Failed to initialize sync service', {'error': e.toString()}, stackTrace);
    }
  }

  /// Sync metrics to Notion
  Future<void> syncMetricsToNotion(String userId, Map<String, dynamic> metrics) async {
    final syncId = 'metrics_${DateTime.now().millisecondsSinceEpoch}';
    
    try {
      _startSync(syncId, 'metrics', 'export', metrics);

      if (!_authService.isAuthenticated) {
        throw Exception('Not authenticated with Notion');
      }

      // Get or create metrics database
      final databaseId = await _getOrCreateMetricsDatabase();
      
      // Create database entry with metrics
      final properties = _buildMetricsProperties(metrics);
      
      final page = await _notionService.createDatabaseEntry(
        databaseId: databaseId,
        properties: properties,
      );

      // Store sync record in Firestore
      await _storeSyncRecord(userId, {
        'type': 'metrics_export',
        'notion_page_id': page.id,
        'data': metrics,
        'synced_at': FieldValue.serverTimestamp(),
      });

      _completeSync(syncId, {'notion_page_id': page.id});
      
      _logger.info('Successfully synced metrics to Notion', {
        'user_id': userId,
        'page_id': page.id,
        'metrics_count': metrics.length,
      });

    } catch (e, stackTrace) {
      _failSync(syncId, e.toString());
      _logger.error('Failed to sync metrics to Notion', {
        'user_id': userId,
        'error': e.toString(),
      }, stackTrace);
      rethrow;
    }
  }

  /// Sync tasks to Notion
  Future<void> syncTasksToNotion(String userId, List<Map<String, dynamic>> tasks) async {
    final syncId = 'tasks_${DateTime.now().millisecondsSinceEpoch}';
    
    try {
      _startSync(syncId, 'tasks', 'export', {'tasks': tasks});

      if (!_authService.isAuthenticated) {
        throw Exception('Not authenticated with Notion');
      }

      // Get or create tasks database
      final databaseId = await _getOrCreateTasksDatabase();
      
      final syncedTasks = <String>[];
      
      for (final task in tasks) {
        try {
          final properties = _buildTaskProperties(task);
          
          final page = await _notionService.createDatabaseEntry(
            databaseId: databaseId,
            properties: properties,
          );

          syncedTasks.add(page.id);

          // Update task with Notion page ID
          await _updateTaskWithNotionId(userId, task['id'], page.id);

        } catch (e) {
          _logger.warning('Failed to sync individual task', {
            'task_id': task['id'],
            'error': e.toString(),
          });
        }
      }

      _completeSync(syncId, {'synced_tasks': syncedTasks});
      
      _logger.info('Successfully synced tasks to Notion', {
        'user_id': userId,
        'total_tasks': tasks.length,
        'synced_tasks': syncedTasks.length,
      });

    } catch (e, stackTrace) {
      _failSync(syncId, e.toString());
      _logger.error('Failed to sync tasks to Notion', {
        'user_id': userId,
        'error': e.toString(),
      }, stackTrace);
      rethrow;
    }
  }

  /// Sync memory chunks to Notion
  Future<void> syncMemoryToNotion(String userId, List<Map<String, dynamic>> memories) async {
    final syncId = 'memory_${DateTime.now().millisecondsSinceEpoch}';
    
    try {
      _startSync(syncId, 'memory', 'backup', {'memories': memories});

      if (!_authService.isAuthenticated) {
        throw Exception('Not authenticated with Notion');
      }

      // Get or create memory backup page
      final pageId = await _getOrCreateMemoryBackupPage();
      
      // Create blocks for memories
      final blocks = memories.map((memory) => _buildMemoryBlock(memory)).toList();
      
      await _notionService.appendBlocks(
        pageId: pageId,
        blocks: blocks,
      );

      // Store sync record
      await _storeSyncRecord(userId, {
        'type': 'memory_backup',
        'notion_page_id': pageId,
        'memory_count': memories.length,
        'synced_at': FieldValue.serverTimestamp(),
      });

      _completeSync(syncId, {'notion_page_id': pageId});
      
      _logger.info('Successfully synced memory to Notion', {
        'user_id': userId,
        'memory_count': memories.length,
      });

    } catch (e, stackTrace) {
      _failSync(syncId, e.toString());
      _logger.error('Failed to sync memory to Notion', {
        'user_id': userId,
        'error': e.toString(),
      }, stackTrace);
      rethrow;
    }
  }

  /// Create quick note in Notion
  Future<NotionPage> createQuickNote({
    required String userId,
    required String title,
    required String content,
    List<String>? tags,
    Map<String, dynamic>? metadata,
  }) async {
    final syncId = 'quick_note_${DateTime.now().millisecondsSinceEpoch}';
    
    try {
      _startSync(syncId, 'note', 'create', {
        'title': title,
        'content': content,
        'tags': tags,
      });

      if (!_authService.isAuthenticated) {
        throw Exception('Not authenticated with Notion');
      }

      // Create blocks for content
      final blocks = [
        {
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [
              {
                'type': 'text',
                'text': {'content': content},
              }
            ],
          },
        },
      ];

      // Add tags if provided
      if (tags != null && tags.isNotEmpty) {
        blocks.add({
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [
              {
                'type': 'text',
                'text': {'content': 'Tags: ${tags.join(', ')}'},
              }
            ],
          },
        });
      }

      final page = await _notionService.createPage(
        title: title,
        blocks: blocks,
      );

      // Store in Firestore
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notion_notes')
          .doc(page.id)
          .set({
        'title': title,
        'content': content,
        'tags': tags ?? [],
        'notion_page_id': page.id,
        'notion_url': page.url,
        'created_at': FieldValue.serverTimestamp(),
        'metadata': metadata ?? {},
      });

      _completeSync(syncId, {'notion_page_id': page.id});
      
      _logger.info('Successfully created quick note in Notion', {
        'user_id': userId,
        'page_id': page.id,
        'title': title,
      });

      return page;

    } catch (e, stackTrace) {
      _failSync(syncId, e.toString());
      _logger.error('Failed to create quick note', {
        'user_id': userId,
        'title': title,
        'error': e.toString(),
      }, stackTrace);
      rethrow;
    }
  }

  /// Retrieve data from Notion and sync to Firestore
  Future<void> syncFromNotion(String userId) async {
    final syncId = 'import_${DateTime.now().millisecondsSinceEpoch}';
    
    try {
      _startSync(syncId, 'import', 'sync_from_notion', {});

      if (!_authService.isAuthenticated) {
        throw Exception('Not authenticated with Notion');
      }

      // Search for NeuroPilot-related pages
      final pages = await _notionService.searchPages(
        query: 'NeuroPilot',
        pageSize: 100,
      );

      final importedPages = <String>[];
      
      for (final page in pages) {
        try {
          // Store page data in Firestore
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('notion_imports')
              .doc(page.id)
              .set({
            'title': page.title,
            'url': page.url,
            'created_time': page.createdTime,
            'last_edited_time': page.lastEditedTime,
            'properties': page.properties,
            'imported_at': FieldValue.serverTimestamp(),
          });

          importedPages.add(page.id);

        } catch (e) {
          _logger.warning('Failed to import individual page', {
            'page_id': page.id,
            'error': e.toString(),
          });
        }
      }

      _completeSync(syncId, {'imported_pages': importedPages});
      
      _logger.info('Successfully synced from Notion', {
        'user_id': userId,
        'total_pages': pages.length,
        'imported_pages': importedPages.length,
      });

    } catch (e, stackTrace) {
      _failSync(syncId, e.toString());
      _logger.error('Failed to sync from Notion', {
        'user_id': userId,
        'error': e.toString(),
      }, stackTrace);
      rethrow;
    }
  }

  /// Perform full sync (both directions)
  Future<void> performFullSync(String userId) async {
    final syncId = 'full_sync_${DateTime.now().millisecondsSinceEpoch}';
    
    try {
      _startSync(syncId, 'full', 'bidirectional_sync', {});

      if (!_authService.isAuthenticated) {
        throw Exception('Not authenticated with Notion');
      }

      _logger.info('Starting full sync', {'user_id': userId});

      // Sync from Firestore to Notion
      await syncFromNotion(userId);

      // Get user data from Firestore
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();

      if (userData != null) {
        // Sync metrics if enabled
        if (userData['notion_sync_metrics'] == true) {
          final metricsSnapshot = await _firestore
              .collection('users')
              .doc(userId)
              .collection('metrics')
              .orderBy('timestamp', descending: true)
              .limit(30)
              .get();

          if (metricsSnapshot.docs.isNotEmpty) {
            final metrics = metricsSnapshot.docs.first.data();
            await syncMetricsToNotion(userId, metrics);
          }
        }

        // Sync tasks if enabled
        if (userData['notion_sync_tasks'] == true) {
          final tasksSnapshot = await _firestore
              .collection('users')
              .doc(userId)
              .collection('tasks')
              .where('completed', isEqualTo: false)
              .get();

          if (tasksSnapshot.docs.isNotEmpty) {
            final tasks = tasksSnapshot.docs.map((doc) => doc.data()).toList();
            await syncTasksToNotion(userId, tasks);
          }
        }

        // Sync memory if enabled
        if (userData['notion_sync_memory'] == true) {
          final memorySnapshot = await _firestore
              .collection('users')
              .doc(userId)
              .collection('memory_chunks')
              .orderBy('timestamp', descending: true)
              .limit(50)
              .get();

          if (memorySnapshot.docs.isNotEmpty) {
            final memories = memorySnapshot.docs.map((doc) => doc.data()).toList();
            await syncMemoryToNotion(userId, memories);
          }
        }
      }

      _completeSync(syncId, {'status': 'completed'});
      
      _logger.info('Full sync completed successfully', {'user_id': userId});

    } catch (e, stackTrace) {
      _failSync(syncId, e.toString());
      _logger.error('Full sync failed', {
        'user_id': userId,
        'error': e.toString(),
      }, stackTrace);
      rethrow;
    }
  }

  /// Sync a specific page to Firestore
  Future<void> syncPageToFirestore(String userId, String pageId) async {
    final syncId = 'page_sync_${DateTime.now().millisecondsSinceEpoch}';
    
    try {
      _startSync(syncId, 'page', 'import', {'page_id': pageId});

      if (!_authService.isAuthenticated) {
        throw Exception('Not authenticated with Notion');
      }

      // Get page from Notion
      final page = await _notionService.getPage(pageId);

      // Store in Firestore
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notion_pages')
          .doc(pageId)
          .set({
        'title': page.title,
        'url': page.url,
        'created_time': page.createdTime,
        'last_edited_time': page.lastEditedTime,
        'properties': page.properties,
        'synced_at': FieldValue.serverTimestamp(),
      });

      _completeSync(syncId, {'page_id': pageId});
      
      _logger.info('Successfully synced page to Firestore', {
        'user_id': userId,
        'page_id': pageId,
      });

    } catch (e, stackTrace) {
      _failSync(syncId, e.toString());
      _logger.error('Failed to sync page to Firestore', {
        'user_id': userId,
        'page_id': pageId,
        'error': e.toString(),
      }, stackTrace);
      rethrow;
    }
  }

  /// Get sync status for user
  Future<Map<String, dynamic>> getSyncStatus(String userId) async {
    try {
      final syncRecords = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notion_syncs')
          .orderBy('synced_at', descending: true)
          .limit(10)
          .get();

      final recentSyncs = syncRecords.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();

      return {
        'is_connected': _authService.isAuthenticated,
        'active_syncs': _activeSyncs.length,
        'recent_syncs': recentSyncs,
        'last_sync': recentSyncs.isNotEmpty ? recentSyncs.first['synced_at'] : null,
      };

    } catch (e, stackTrace) {
      _logger.error('Failed to get sync status', {
        'user_id': userId,
        'error': e.toString(),
      }, stackTrace);
      return {
        'is_connected': false,
        'active_syncs': 0,
        'recent_syncs': [],
        'error': e.toString(),
      };
    }
  }

  /// Perform background sync
  Future<void> _performBackgroundSync() async {
    if (!_authService.isAuthenticated) return;

    try {
      _logger.debug('Performing background sync');
      
      // Get users who have enabled auto-sync
      final users = await _firestore
          .collection('users')
          .where('notion_auto_sync', isEqualTo: true)
          .get();

      for (final userDoc in users.docs) {
        try {
          await syncFromNotion(userDoc.id);
        } catch (e) {
          _logger.warning('Background sync failed for user', {
            'user_id': userDoc.id,
            'error': e.toString(),
          });
        }
      }

    } catch (e, stackTrace) {
      _logger.error('Background sync failed', {'error': e.toString()}, stackTrace);
    }
  }

  /// Helper methods for database management
  Future<String> _getOrCreateMetricsDatabase() async {
    // In production, this would check for existing database or create new one
    return 'metrics_database_id';
  }

  Future<String> _getOrCreateTasksDatabase() async {
    // In production, this would check for existing database or create new one
    return 'tasks_database_id';
  }

  Future<String> _getOrCreateMemoryBackupPage() async {
    // In production, this would check for existing page or create new one
    return 'memory_backup_page_id';
  }

  /// Build properties for different data types
  Map<String, dynamic> _buildMetricsProperties(Map<String, dynamic> metrics) {
    return {
      'Name': {
        'title': [
          {
            'text': {'content': 'Metrics - ${DateTime.now().toIso8601String().split('T')[0]}'},
          }
        ],
      },
      'Date': {
        'date': {'start': DateTime.now().toIso8601String().split('T')[0]},
      },
      'Tasks Completed': {
        'number': metrics['tasks_completed'] ?? 0,
      },
      'Time Accuracy': {
        'number': metrics['avg_time_accuracy'] ?? 0.0,
      },
      'Stress Level': {
        'number': metrics['avg_stress_level'] ?? 0.0,
      },
      'Hyperfocus Interrupts': {
        'number': metrics['hyperfocus_interrupts'] ?? 0,
      },
    };
  }

  Map<String, dynamic> _buildTaskProperties(Map<String, dynamic> task) {
    return {
      'Name': {
        'title': [
          {
            'text': {'content': task['title'] ?? 'Untitled Task'},
          }
        ],
      },
      'Status': {
        'select': {'name': task['status'] ?? 'Todo'},
      },
      'Priority': {
        'select': {'name': task['priority'] ?? 'Medium'},
      },
      'Due Date': task['due_date'] != null ? {
        'date': {'start': task['due_date']},
      } : null,
      'Created': {
        'date': {'start': task['created_at'] ?? DateTime.now().toIso8601String()},
      },
    }..removeWhere((key, value) => value == null);
  }

  Map<String, dynamic> _buildMemoryBlock(Map<String, dynamic> memory) {
    return {
      'object': 'block',
      'type': 'paragraph',
      'paragraph': {
        'rich_text': [
          {
            'type': 'text',
            'text': {
              'content': '${memory['type']}: ${memory['content']}',
            },
          }
        ],
      },
    };
  }

  /// Sync operation management
  void _startSync(String id, String type, String operation, Map<String, dynamic> data) {
    final sync = NotionSyncOperation(
      id: id,
      type: type,
      operation: operation,
      status: NotionSyncStatus.syncing,
      timestamp: DateTime.now(),
      data: data,
    );

    _activeSyncs[id] = sync;
    _syncController.add(sync);
  }

  void _completeSync(String id, Map<String, dynamic> result) {
    final sync = _activeSyncs[id];
    if (sync != null) {
      final completedSync = sync.copyWith(
        status: NotionSyncStatus.success,
        data: {...sync.data, ...result},
      );
      
      _activeSyncs.remove(id);
      _syncController.add(completedSync);
    }
  }

  void _failSync(String id, String error) {
    final sync = _activeSyncs[id];
    if (sync != null) {
      final failedSync = sync.copyWith(
        status: NotionSyncStatus.error,
        errorMessage: error,
      );
      
      _activeSyncs.remove(id);
      _syncController.add(failedSync);
    }
  }

  /// Store sync record in Firestore
  Future<void> _storeSyncRecord(String userId, Map<String, dynamic> data) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notion_syncs')
        .add(data);
  }

  /// Update task with Notion page ID
  Future<void> _updateTaskWithNotionId(String userId, String taskId, String notionPageId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .doc(taskId)
        .update({
      'notion_page_id': notionPageId,
      'synced_at': FieldValue.serverTimestamp(),
    });
  }

  /// Dispose resources
  void dispose() {
    _backgroundSyncTimer?.cancel();
    _syncController.close();
  }
}