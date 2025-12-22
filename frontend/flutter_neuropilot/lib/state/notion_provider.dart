import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../core/notion/models/notion_models.dart';
import '../core/notion/services/notion_auth_service.dart';
import '../core/notion/services/notion_service.dart';
import '../core/notion/services/notion_sync_service.dart';
import '../core/notion/services/notion_template_service.dart';

/// Main Notion state
class NotionState {
  final bool isConnected;
  final bool isLoading;
  final String? error;
  final List<NotionPage> pages;
  final List<NotionPage> searchResults;
  final NotionConnection? connection;
  final NotionSettings settings;

  const NotionState({
    this.isConnected = false,
    this.isLoading = false,
    this.error,
    this.pages = const [],
    this.searchResults = const [],
    this.connection,
    this.settings = const NotionSettings(),
  });

  NotionState copyWith({
    bool? isConnected,
    bool? isLoading,
    String? error,
    List<NotionPage>? pages,
    List<NotionPage>? searchResults,
    NotionConnection? connection,
    NotionSettings? settings,
  }) {
    return NotionState(
      isConnected: isConnected ?? this.isConnected,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      pages: pages ?? this.pages,
      searchResults: searchResults ?? this.searchResults,
      connection: connection ?? this.connection,
      settings: settings ?? this.settings,
    );
  }
}

/// Main Notion notifier
class NotionNotifier extends StateNotifier<NotionState> {
  NotionNotifier(this.ref) : super(const NotionState()) {
    _initialize();
  }

  final Ref ref;

  Future<void> _initialize() async {
    try {
      final authService = NotionAuthService.instance;
      final connection = await authService.getCurrentConnection();

      state = state.copyWith(
        isConnected: connection?.isConnected ?? false,
        connection: connection,
      );

      // Don't auto-fetch pages on web - CORS prevents direct API calls
      // Pages will be fetched through backend proxy when needed
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Connect to Notion
  Future<void> connect() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final authService = NotionAuthService.instance;
      final connection = await authService.authenticate();
      
      state = state.copyWith(
        isConnected: connection.isConnected,
        connection: connection,
        isLoading: false,
      );
      
      if (connection.isConnected) {
        await refreshPages();
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Disconnect from Notion
  Future<void> disconnect() async {
    try {
      final authService = NotionAuthService.instance;
      await authService.disconnect();
      
      state = state.copyWith(
        isConnected: false,
        connection: null,
        pages: [],
        searchResults: [],
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Refresh pages
  Future<void> refreshPages() async {
    if (!state.isConnected) return;
    
    state = state.copyWith(isLoading: true);
    
    try {
      final notionService = NotionService.instance;
      final pages = await notionService.searchPages(pageSize: 50);
      
      state = state.copyWith(
        pages: pages,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Search pages
  Future<void> searchPages(String query) async {
    if (!state.isConnected || query.isEmpty) return;
    
    state = state.copyWith(isLoading: true);
    
    try {
      final notionService = NotionService.instance;
      final results = await notionService.searchPages(query: query, pageSize: 20);
      
      state = state.copyWith(
        searchResults: results,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Create quick note
  Future<void> createQuickNote(String content) async {
    if (!state.isConnected) {
      throw Exception('Notion not connected');
    }
    
    try {
      final syncService = NotionSyncService.instance;
      await syncService.createQuickNote(
        userId: 'current_user', // In production, get from auth
        title: 'Quick Note - ${DateTime.now().toIso8601String().substring(0, 16)}',
        content: content,
      );
      
      // Refresh pages to show the new note
      await refreshPages();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  /// Create from template
  Future<void> createFromTemplate(NotionTemplate template) async {
    if (!state.isConnected) {
      throw Exception('Notion not connected');
    }
    
    try {
      final templateService = NotionTemplateService.instance;
      await templateService.createFromTemplate(
        template: template,
        userId: 'current_user', // In production, get from auth
      );
      
      // Refresh pages to show the new page
      await refreshPages();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  /// Export metrics to Notion
  Future<void> exportMetrics(Map<String, dynamic> metrics) async {
    if (!state.isConnected) {
      throw Exception('Notion not connected');
    }
    
    try {
      final syncService = NotionSyncService.instance;
      await syncService.syncMetricsToNotion('current_user', metrics);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  /// Sync with Firestore
  Future<void> syncWithFirestore() async {
    if (!state.isConnected) {
      throw Exception('Notion not connected');
    }
    
    try {
      final syncService = NotionSyncService.instance;
      await syncService.performFullSync('current_user');
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  /// Open page in Notion
  Future<void> openPageInNotion(String pageId) async {
    try {
      final notionService = NotionService.instance;
      await notionService.openPageInBrowser(pageId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  /// Sync page to Firestore
  Future<void> syncPageToFirestore(String pageId) async {
    try {
      final syncService = NotionSyncService.instance;
      await syncService.syncPageToFirestore('current_user', pageId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  /// Duplicate page
  Future<void> duplicatePage(String pageId) async {
    try {
      final notionService = NotionService.instance;
      await notionService.duplicatePage(pageId);
      await refreshPages();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  /// Update settings
  void updateSettings(NotionSettings settings) {
    state = state.copyWith(settings: settings);
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Main Notion provider
final notionProvider = StateNotifierProvider<NotionNotifier, NotionState>((ref) {
  return NotionNotifier(ref);
});

/// Notion connection state provider
final notionConnectionProvider = StreamProvider<NotionConnection>((ref) {
  return NotionAuthService.instance.connectionStream;
});

/// Notion auth service provider
final notionAuthServiceProvider = Provider<NotionAuthService>((ref) {
  return NotionAuthService.instance;
});

/// Notion service provider
final notionServiceProvider = Provider<NotionService>((ref) {
  return NotionService.instance;
});

/// Notion sync service provider
final notionSyncServiceProvider = Provider<NotionSyncService>((ref) {
  return NotionSyncService.instance;
});

/// Notion template service provider
final notionTemplateServiceProvider = Provider<NotionTemplateService>((ref) {
  return NotionTemplateService.instance;
});

/// Notion sync operations stream provider
final notionSyncOperationsProvider = StreamProvider<NotionSyncOperation>((ref) {
  return NotionSyncService.instance.syncStream;
});

/// Notion sync status provider
final notionSyncStatusProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, userId) async {
  return await NotionSyncService.instance.getSyncStatus(userId);
});

/// Notion quick capture state
class NotionQuickCaptureState {
  final bool isCapturing;
  final String? error;
  final NotionPage? lastCreatedPage;

  const NotionQuickCaptureState({
    this.isCapturing = false,
    this.error,
    this.lastCreatedPage,
  });

  NotionQuickCaptureState copyWith({
    bool? isCapturing,
    String? error,
    NotionPage? lastCreatedPage,
  }) {
    return NotionQuickCaptureState(
      isCapturing: isCapturing ?? this.isCapturing,
      error: error ?? this.error,
      lastCreatedPage: lastCreatedPage ?? this.lastCreatedPage,
    );
  }
}

/// Notion quick capture notifier
class NotionQuickCaptureNotifier extends StateNotifier<NotionQuickCaptureState> {
  NotionQuickCaptureNotifier(this.ref) : super(const NotionQuickCaptureState());

  final Ref ref;

  /// Create quick note
  Future<void> createQuickNote({
    required String userId,
    required String title,
    required String content,
    List<String>? tags,
    Map<String, dynamic>? metadata,
  }) async {
    state = state.copyWith(isCapturing: true, error: null);

    try {
      final syncService = ref.read(notionSyncServiceProvider);
      final page = await syncService.createQuickNote(
        userId: userId,
        title: title,
        content: content,
        tags: tags,
        metadata: metadata,
      );

      state = state.copyWith(
        isCapturing: false,
        lastCreatedPage: page,
      );

    } catch (e) {
      state = state.copyWith(
        isCapturing: false,
        error: e.toString(),
      );
    }
  }

  /// Create from template
  Future<void> createFromTemplate({
    required String userId,
    required NotionTemplate template,
    Map<String, dynamic>? customData,
  }) async {
    state = state.copyWith(isCapturing: true, error: null);

    try {
      final templateService = ref.read(notionTemplateServiceProvider);
      final page = await templateService.createFromTemplate(
        template: template,
        userId: userId,
        customData: customData,
      );

      state = state.copyWith(
        isCapturing: false,
        lastCreatedPage: page,
      );

    } catch (e) {
      state = state.copyWith(
        isCapturing: false,
        error: e.toString(),
      );
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Notion quick capture provider
final notionQuickCaptureProvider = StateNotifierProvider<NotionQuickCaptureNotifier, NotionQuickCaptureState>((ref) {
  return NotionQuickCaptureNotifier(ref);
});

/// Notion pages provider
final notionPagesProvider = FutureProvider.family<List<NotionPage>, String>((ref, query) async {
  final notionService = ref.read(notionServiceProvider);
  return await notionService.searchPages(query: query, pageSize: 50);
});

/// Notion settings state
class NotionSettings {
  final bool autoSync;
  final bool syncMetrics;
  final bool syncTasks;
  final bool syncMemory;
  final List<NotionTemplate> enabledTemplates;
  final String? defaultParentPageId;

  const NotionSettings({
    this.autoSync = false,
    this.syncMetrics = true,
    this.syncTasks = true,
    this.syncMemory = false,
    this.enabledTemplates = const [],
    this.defaultParentPageId,
  });

  NotionSettings copyWith({
    bool? autoSync,
    bool? syncMetrics,
    bool? syncTasks,
    bool? syncMemory,
    List<NotionTemplate>? enabledTemplates,
    String? defaultParentPageId,
  }) {
    return NotionSettings(
      autoSync: autoSync ?? this.autoSync,
      syncMetrics: syncMetrics ?? this.syncMetrics,
      syncTasks: syncTasks ?? this.syncTasks,
      syncMemory: syncMemory ?? this.syncMemory,
      enabledTemplates: enabledTemplates ?? this.enabledTemplates,
      defaultParentPageId: defaultParentPageId ?? this.defaultParentPageId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'auto_sync': autoSync,
      'sync_metrics': syncMetrics,
      'sync_tasks': syncTasks,
      'sync_memory': syncMemory,
      'enabled_templates': enabledTemplates.map((t) => t.name).toList(),
      'default_parent_page_id': defaultParentPageId,
    };
  }

  factory NotionSettings.fromJson(Map<String, dynamic> json) {
    return NotionSettings(
      autoSync: json['auto_sync'] ?? false,
      syncMetrics: json['sync_metrics'] ?? true,
      syncTasks: json['sync_tasks'] ?? true,
      syncMemory: json['sync_memory'] ?? false,
      enabledTemplates: (json['enabled_templates'] as List<dynamic>?)
          ?.map((name) => NotionTemplate.values.firstWhere(
                (t) => t.name == name,
                orElse: () => NotionTemplate.dailyReflection,
              ))
          .toList() ?? [],
      defaultParentPageId: json['default_parent_page_id'],
    );
  }
}

/// Notion settings notifier
class NotionSettingsNotifier extends StateNotifier<NotionSettings> {
  NotionSettingsNotifier() : super(const NotionSettings()) {
    _loadSettings();
  }

  /// Load settings from storage
  Future<void> _loadSettings() async {
    // In production, load from secure storage or Firestore
    // For now, use default settings
  }

  /// Update auto sync setting
  void setAutoSync(bool enabled) {
    state = state.copyWith(autoSync: enabled);
    _saveSettings();
  }

  /// Update sync metrics setting
  void setSyncMetrics(bool enabled) {
    state = state.copyWith(syncMetrics: enabled);
    _saveSettings();
  }

  /// Update sync tasks setting
  void setSyncTasks(bool enabled) {
    state = state.copyWith(syncTasks: enabled);
    _saveSettings();
  }

  /// Update sync memory setting
  void setSyncMemory(bool enabled) {
    state = state.copyWith(syncMemory: enabled);
    _saveSettings();
  }

  /// Update enabled templates
  void setEnabledTemplates(List<NotionTemplate> templates) {
    state = state.copyWith(enabledTemplates: templates);
    _saveSettings();
  }

  /// Toggle template
  void toggleTemplate(NotionTemplate template) {
    final templates = List<NotionTemplate>.from(state.enabledTemplates);
    if (templates.contains(template)) {
      templates.remove(template);
    } else {
      templates.add(template);
    }
    setEnabledTemplates(templates);
  }

  /// Set default parent page
  void setDefaultParentPageId(String? pageId) {
    state = state.copyWith(defaultParentPageId: pageId);
    _saveSettings();
  }

  /// Save settings to storage
  Future<void> _saveSettings() async {
    // In production, save to secure storage or Firestore
  }
}

/// Notion settings provider
final notionSettingsProvider = StateNotifierProvider<NotionSettingsNotifier, NotionSettings>((ref) {
  return NotionSettingsNotifier();
});

/// Notion integration status provider
final notionIntegrationStatusProvider = Provider<Map<String, dynamic>>((ref) {
  final notionState = ref.watch(notionProvider);
  
  return {
    'is_connected': notionState.isConnected,
    'workspace_name': notionState.connection?.workspaceName,
    'connection_state': notionState.connection?.state.name ?? 'disconnected',
    'auto_sync_enabled': notionState.settings.autoSync,
    'sync_features': {
      'metrics': notionState.settings.syncMetrics,
      'tasks': notionState.settings.syncTasks,
      'memory': notionState.settings.syncMemory,
    },
    'enabled_templates_count': notionState.settings.enabledTemplates.length,
    'error': notionState.error,
    'pages_count': notionState.pages.length,
  };
});

/// Available templates provider
final availableTemplatesProvider = Provider<List<Map<String, dynamic>>>((ref) {
  return NotionTemplate.values.map((template) => {
    'template': template,
    'name': template.displayName,
    'description': template.description,
    'icon': template.icon,
  }).toList();
});

/// Notion metrics sync provider
final notionMetricsSyncProvider = FutureProvider.family<void, Map<String, dynamic>>((ref, params) async {
  final userId = params['user_id'] as String;
  final metrics = params['metrics'] as Map<String, dynamic>;
  
  final syncService = ref.read(notionSyncServiceProvider);
  await syncService.syncMetricsToNotion(userId, metrics);
});

/// Notion tasks sync provider
final notionTasksSyncProvider = FutureProvider.family<void, Map<String, dynamic>>((ref, params) async {
  final userId = params['user_id'] as String;
  final tasks = params['tasks'] as List<Map<String, dynamic>>;
  
  final syncService = ref.read(notionSyncServiceProvider);
  await syncService.syncTasksToNotion(userId, tasks);
});

/// Notion memory sync provider
final notionMemorySyncProvider = FutureProvider.family<void, Map<String, dynamic>>((ref, params) async {
  final userId = params['user_id'] as String;
  final memories = params['memories'] as List<Map<String, dynamic>>;
  
  final syncService = ref.read(notionSyncServiceProvider);
  await syncService.syncMemoryToNotion(userId, memories);
});