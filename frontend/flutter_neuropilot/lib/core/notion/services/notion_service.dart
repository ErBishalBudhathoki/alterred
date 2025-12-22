import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../models/notion_models.dart';
import '../notion_mcp_config.dart';
import 'notion_auth_service.dart';
import '../../observability/logging_service.dart';

/// Core Notion API service with rate limiting and error handling
///
/// On Flutter Web, requests are proxied through the backend to avoid CORS issues.
/// On mobile/desktop, direct API calls can be used.
class NotionService {
  static NotionService? _instance;
  static NotionService get instance => _instance ??= NotionService._();

  NotionService._();

  final Logger _logger = Logger('NotionService');
  final NotionAuthService _authService = NotionAuthService.instance;
  final Map<String, dynamic> _cache = {};
  final List<DateTime> _requestTimes = [];

  /// Backend API base URL for proxy requests
  /// Set via: --dart-define=API_BASE_URL=http://localhost:8000
  static const String _backendBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  /// Whether to use backend proxy (required for web due to CORS)
  bool get _useBackendProxy => kIsWeb;

  /// Initialize the service
  Future<void> initialize() async {
    _logger.info('Notion service initialized', {
      'use_backend_proxy': _useBackendProxy,
      'backend_url': _backendBaseUrl,
    });
  }

  /// Create a new page
  Future<NotionPage> createPage({
    required String title,
    String? parentId,
    String? parentType,
    List<Map<String, dynamic>>? blocks,
    Map<String, dynamic>? properties,
  }) async {
    try {
      await _checkRateLimit();
      
      final body = {
        'parent': parentId != null ? {
          parentType ?? 'page_id': parentId,
        } : {
          'type': 'page_id',
          'page_id': await _getDefaultParentId(),
        },
        'properties': {
          'title': {
            'title': [
              {
                'text': {'content': title},
              }
            ],
          },
          ...?properties,
        },
        if (blocks != null) 'children': blocks,
      };

      final response = await _makeRequest(
        'POST',
        '/pages',
        body: body,
      );

      final page = NotionPage.fromJson(response);
      _logger.info('Created Notion page', {
        'page_id': page.id,
        'title': page.title,
      });

      return page;

    } catch (e, stackTrace) {
      _logger.error('Failed to create page', {
        'title': title,
        'error': e.toString(),
      }, stackTrace);
      rethrow;
    }
  }

  /// Update an existing page
  Future<NotionPage> updatePage({
    required String pageId,
    String? title,
    Map<String, dynamic>? properties,
    bool? archived,
  }) async {
    try {
      await _checkRateLimit();

      final body = <String, dynamic>{};
      
      if (title != null || properties != null) {
        body['properties'] = <String, dynamic>{};
        
        if (title != null) {
          body['properties']['title'] = {
            'title': [
              {
                'text': {'content': title},
              }
            ],
          };
        }
        
        if (properties != null) {
          body['properties'].addAll(properties);
        }
      }

      if (archived != null) {
        body['archived'] = archived;
      }

      final response = await _makeRequest(
        'PATCH',
        '/pages/$pageId',
        body: body,
      );

      final page = NotionPage.fromJson(response);
      _logger.info('Updated Notion page', {
        'page_id': page.id,
        'title': page.title,
      });

      return page;

    } catch (e, stackTrace) {
      _logger.error('Failed to update page', {
        'page_id': pageId,
        'error': e.toString(),
      }, stackTrace);
      rethrow;
    }
  }

  /// Get a page by ID
  Future<NotionPage> getPage(String pageId) async {
    try {
      await _checkRateLimit();

      // Check cache first
      final cacheKey = 'page_$pageId';
      if (_cache.containsKey(cacheKey)) {
        final cached = _cache[cacheKey];
        if (cached['expires_at'].isAfter(DateTime.now())) {
          return NotionPage.fromJson(cached['data']);
        }
      }

      final response = await _makeRequest('GET', '/pages/$pageId');
      final page = NotionPage.fromJson(response);

      // Cache the result
      _cache[cacheKey] = {
        'data': response,
        'expires_at': DateTime.now().add(NotionMCPConfig.cacheExpiry),
      };

      _logger.debug('Retrieved Notion page', {
        'page_id': page.id,
        'title': page.title,
      });

      return page;

    } catch (e, stackTrace) {
      _logger.error('Failed to get page', {
        'page_id': pageId,
        'error': e.toString(),
      }, stackTrace);
      rethrow;
    }
  }

  /// Search pages and databases
  Future<List<NotionPage>> searchPages({
    String? query,
    Map<String, dynamic>? filter,
    List<Map<String, dynamic>>? sorts,
    int? pageSize,
  }) async {
    try {
      await _checkRateLimit();

      final body = <String, dynamic>{};
      
      if (query != null && query.isNotEmpty) {
        body['query'] = query;
      }
      
      if (filter != null) {
        body['filter'] = filter;
      }
      
      if (sorts != null) {
        body['sort'] = sorts;
      }
      
      if (pageSize != null) {
        body['page_size'] = pageSize;
      }

      final response = await _makeRequest(
        'POST',
        '/search',
        body: body,
      );

      final results = <NotionPage>[];
      for (final result in response['results']) {
        if (result['object'] == 'page') {
          results.add(NotionPage.fromJson(result));
        }
      }

      _logger.debug('Searched Notion pages', {
        'query': query,
        'results_count': results.length,
      });

      return results;

    } catch (e, stackTrace) {
      _logger.error('Failed to search pages', {
        'query': query,
        'error': e.toString(),
      }, stackTrace);
      rethrow;
    }
  }

  /// Append blocks to a page
  Future<List<NotionBlock>> appendBlocks({
    required String pageId,
    required List<Map<String, dynamic>> blocks,
  }) async {
    try {
      await _checkRateLimit();

      final response = await _makeRequest(
        'PATCH',
        '/blocks/$pageId/children',
        body: {'children': blocks},
      );

      final resultBlocks = <NotionBlock>[];
      for (final block in response['results']) {
        resultBlocks.add(NotionBlock.fromJson(block));
      }

      _logger.info('Appended blocks to page', {
        'page_id': pageId,
        'blocks_count': blocks.length,
      });

      return resultBlocks;

    } catch (e, stackTrace) {
      _logger.error('Failed to append blocks', {
        'page_id': pageId,
        'error': e.toString(),
      }, stackTrace);
      rethrow;
    }
  }

  /// Create a database
  Future<NotionDatabase> createDatabase({
    required String title,
    required String parentId,
    required Map<String, Map<String, dynamic>> properties,
    String? description,
  }) async {
    try {
      await _checkRateLimit();

      final body = {
        'parent': {
          'type': 'page_id',
          'page_id': parentId,
        },
        'title': [
          {
            'type': 'text',
            'text': {'content': title},
          }
        ],
        'properties': properties,
        if (description != null) 'description': [
          {
            'type': 'text',
            'text': {'content': description},
          }
        ],
      };

      final response = await _makeRequest(
        'POST',
        '/databases',
        body: body,
      );

      final database = NotionDatabase.fromJson(response);
      _logger.info('Created Notion database', {
        'database_id': database.id,
        'title': database.title,
      });

      return database;

    } catch (e, stackTrace) {
      _logger.error('Failed to create database', {
        'title': title,
        'error': e.toString(),
      }, stackTrace);
      rethrow;
    }
  }

  /// Query a database
  Future<List<NotionPage>> queryDatabase({
    required String databaseId,
    Map<String, dynamic>? filter,
    List<Map<String, dynamic>>? sorts,
    int? pageSize,
  }) async {
    try {
      await _checkRateLimit();

      final body = <String, dynamic>{};
      
      if (filter != null) {
        body['filter'] = filter;
      }
      
      if (sorts != null) {
        body['sorts'] = sorts;
      }
      
      if (pageSize != null) {
        body['page_size'] = pageSize;
      }

      final response = await _makeRequest(
        'POST',
        '/databases/$databaseId/query',
        body: body,
      );

      final results = <NotionPage>[];
      for (final result in response['results']) {
        results.add(NotionPage.fromJson(result));
      }

      _logger.debug('Queried Notion database', {
        'database_id': databaseId,
        'results_count': results.length,
      });

      return results;

    } catch (e, stackTrace) {
      _logger.error('Failed to query database', {
        'database_id': databaseId,
        'error': e.toString(),
      }, stackTrace);
      rethrow;
    }
  }

  /// Create a database entry
  Future<NotionPage> createDatabaseEntry({
    required String databaseId,
    required Map<String, dynamic> properties,
    List<Map<String, dynamic>>? blocks,
  }) async {
    try {
      await _checkRateLimit();

      final body = {
        'parent': {
          'type': 'database_id',
          'database_id': databaseId,
        },
        'properties': properties,
        if (blocks != null) 'children': blocks,
      };

      final response = await _makeRequest(
        'POST',
        '/pages',
        body: body,
      );

      final page = NotionPage.fromJson(response);
      _logger.info('Created database entry', {
        'database_id': databaseId,
        'page_id': page.id,
      });

      return page;

    } catch (e, stackTrace) {
      _logger.error('Failed to create database entry', {
        'database_id': databaseId,
        'error': e.toString(),
      }, stackTrace);
      rethrow;
    }
  }

  /// Make HTTP request to Notion API (via backend proxy on web)
  Future<Map<String, dynamic>> _makeRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final token = await _authService.getAccessToken();
    if (token == null) {
      throw Exception('Not authenticated with Notion');
    }

    // Use backend proxy on web to avoid CORS issues
    final Uri uri;
    final Map<String, String> requestHeaders;

    if (_useBackendProxy) {
      // Route through backend proxy
      uri = Uri.parse('$_backendBaseUrl/notion$endpoint');
      requestHeaders = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        ...?headers,
      };
      _logger.debug('Using backend proxy for Notion request', {
        'endpoint': endpoint,
        'proxy_url': uri.toString(),
      });
    } else {
      // Direct API call (mobile/desktop)
      uri = Uri.parse('${NotionMCPConfig.notionApiBaseUrl}$endpoint');
      requestHeaders = {
        'Authorization': 'Bearer $token',
        'Notion-Version': NotionMCPConfig.notionApiVersion,
        'Content-Type': 'application/json',
        ...?headers,
      };
    }

    http.Response response;

    switch (method.toUpperCase()) {
      case 'GET':
        response = await http.get(uri, headers: requestHeaders);
        break;
      case 'POST':
        response = await http.post(
          uri,
          headers: requestHeaders,
          body: body != null ? json.encode(body) : null,
        );
        break;
      case 'PATCH':
        response = await http.patch(
          uri,
          headers: requestHeaders,
          body: body != null ? json.encode(body) : null,
        );
        break;
      case 'DELETE':
        response = await http.delete(uri, headers: requestHeaders);
        break;
      default:
        throw Exception('Unsupported HTTP method: $method');
    }

    _recordRequest();

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final responseData = json.decode(response.body);
      // Backend proxy wraps response in {ok: true, data: ...}
      if (_useBackendProxy && responseData is Map && responseData['data'] != null) {
        return responseData['data'] as Map<String, dynamic>;
      }
      return responseData;
    } else {
      Map<String, dynamic> errorBody;
      try {
        errorBody = json.decode(response.body);
      } catch (_) {
        errorBody = {'code': 'unknown', 'message': response.body};
      }

      // Backend proxy wraps errors in {ok: false, error: ..., message: ...}
      if (_useBackendProxy) {
        throw NotionApiException(
          statusCode: response.statusCode,
          code: errorBody['error']?.toString() ?? 'unknown',
          message: errorBody['message']?.toString() ?? 'Unknown error',
        );
      }

      throw NotionApiException(
        statusCode: response.statusCode,
        code: errorBody['code']?.toString() ?? 'unknown',
        message: errorBody['message']?.toString() ?? 'Unknown error',
      );
    }
  }

  /// Check and enforce rate limiting
  Future<void> _checkRateLimit() async {
    final now = DateTime.now();
    
    // Remove requests older than 1 second
    _requestTimes.removeWhere((time) => now.difference(time).inSeconds >= 1);
    
    // Check if we're at the rate limit
    if (_requestTimes.length >= NotionMCPConfig.maxRequestsPerSecond) {
      final oldestRequest = _requestTimes.first;
      final waitTime = const Duration(seconds: 1) - now.difference(oldestRequest);
      
      if (waitTime.inMilliseconds > 0) {
        _logger.debug('Rate limiting: waiting ${waitTime.inMilliseconds}ms');
        await Future.delayed(waitTime);
      }
    }
  }

  /// Record a request for rate limiting
  void _recordRequest() {
    _requestTimes.add(DateTime.now());
  }

  /// Get default parent page ID (create if needed)
  Future<String> _getDefaultParentId() async {
    // In production, this would get or create a default "NeuroPilot" page
    // For now, return a mock ID
    return 'default_parent_page_id';
  }

  /// Clear cache
  void clearCache() {
    _cache.clear();
    _logger.debug('Cleared Notion service cache');
  }

  /// Open page in browser
  Future<void> openPageInBrowser(String pageId) async {
    try {
      final page = await getPage(pageId);
      final uri = Uri.parse(page.url);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _logger.info('Opened Notion page in browser', {'page_id': pageId});
      } else {
        throw Exception('Could not launch Notion page URL');
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to open page in browser', {
        'page_id': pageId,
        'error': e.toString(),
      }, stackTrace);
      rethrow;
    }
  }

  /// Duplicate a page
  Future<NotionPage> duplicatePage(String pageId) async {
    try {
      await _checkRateLimit();
      
      // Get the original page
      final originalPage = await getPage(pageId);
      
      // Create a new page with similar properties
      final duplicatedPage = await createPage(
        title: '${originalPage.title} (Copy)',
        parentId: originalPage.parentId,
        parentType: originalPage.parentType,
        properties: originalPage.properties,
      );

      _logger.info('Duplicated Notion page', {
        'original_page_id': pageId,
        'new_page_id': duplicatedPage.id,
      });

      return duplicatedPage;

    } catch (e, stackTrace) {
      _logger.error('Failed to duplicate page', {
        'page_id': pageId,
        'error': e.toString(),
      }, stackTrace);
      rethrow;
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    final now = DateTime.now();
    int validEntries = 0;
    int expiredEntries = 0;

    for (final entry in _cache.values) {
      if (entry['expires_at'].isAfter(now)) {
        validEntries++;
      } else {
        expiredEntries++;
      }
    }

    return {
      'total_entries': _cache.length,
      'valid_entries': validEntries,
      'expired_entries': expiredEntries,
      'cache_hit_rate': validEntries / (_cache.isNotEmpty ? _cache.length : 1),
    };
  }
}

/// Notion API exception
class NotionApiException implements Exception {
  final int statusCode;
  final String code;
  final String message;

  const NotionApiException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  @override
  String toString() {
    return 'NotionApiException($statusCode): $code - $message';
  }
}