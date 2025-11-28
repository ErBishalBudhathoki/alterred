import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

/// API Client
///
/// Handles all HTTP communication with the backend API.
/// Provides methods for all available endpoints (chat, tasks, calendar, metrics, etc.).
///
/// Implementation Details:
/// - Uses the `http` package for requests.
/// - Automatically injects the Authorization header if a token is present.
/// - Implements a retry mechanism (`_sendWithRetry`) for robust networking.
/// - Centralizes error handling and JSON decoding in `_decodeEnsureOk`.
///
/// Design Decisions:
/// - Wrapper methods (e.g., `atomizeTask`, `chatRespond`) provide strong typing for API calls.
/// - `baseUrl` and `token` are injected, allowing for easy configuration and testing.
/// - Returns `Map<String, dynamic>` for flexibility, relying on call sites to parse specific models.
///
/// Behavioral Specifications:
/// - Throws exceptions on non-200 responses or network timeouts.
/// - Retries requests once by default for specific endpoints like chat.
class ApiClient {
  final String baseUrl;
  final String? token;
  final http.Client _client;

  /// Creates an instance of [ApiClient].
  ///
  /// [baseUrl]: The root URL of the API.
  /// [token]: Optional Bearer token for authentication.
  /// [client]: Optional http.Client for testing.
  ApiClient({required this.baseUrl, this.token, http.Client? client})
      : _client = client ?? http.Client();

  /// Helper to construct headers with optional Auth token.
  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  /// Checks the health of the backend.
  Future<Map<String, dynamic>> health() async {
    final r = await _send(_client.get(Uri.parse('$baseUrl/health')));
    return _decodeEnsureOk(r);
  }

  /// Retrieves a daily overview of metrics.
  Future<Map<String, dynamic>> metricsOverview() async {
    final r = await _send(_client.get(Uri.parse('$baseUrl/metrics/overview')));
    return _decodeEnsureOk(r);
  }

  /// Fetches calendar events for the current day.
  Future<Map<String, dynamic>> calendarEventsToday() async {
    final r =
        await _send(_client.get(Uri.parse('$baseUrl/calendar/events/today')));
    return _decodeEnsureOk(r);
  }

  Future<Map<String, dynamic>> googleUserinfo() async {
    final r = await _send(_client.get(Uri.parse('$baseUrl/auth/google/userinfo')));
    return _decodeEnsureOk(r);
  }

  /// Fetches session history from yesterday.
  Future<Map<String, dynamic>> sessionsYesterday() async {
    final r =
        await _send(_client.get(Uri.parse('$baseUrl/sessions/yesterday')));
    return _decodeEnsureOk(r);
  }

  /// Breaks down a complex task into smaller subtasks.
  Future<Map<String, dynamic>> atomizeTask(String description) async {
    final r = await _send(_client.post(
      Uri.parse('$baseUrl/tasks/atomize'),
      headers: _headers(),
      body: jsonEncode({'description': description}),
    ));
    return _decodeEnsureOk(r);
  }

  /// Schedules a list of tasks based on energy levels and weights.
  Future<Map<String, dynamic>> scheduleTasks(
      List<String> items, int energy, List<int>? weights) async {
    final r = await _send(_client.post(
      Uri.parse('$baseUrl/tasks/schedule'),
      headers: _headers(),
      body: jsonEncode({'items': items, 'energy': energy, 'weights': weights}),
    ));
    return _decodeEnsureOk(r);
  }

  /// Creates a countdown timer from a natural language query.
  Future<Map<String, dynamic>> createCountdown(String query) async {
    final r = await _send(_client.post(
      Uri.parse('$baseUrl/time/countdown'),
      headers: _headers(),
      body: jsonEncode({'query': query}),
    ));
    return _decodeEnsureOk(r);
  }

  /// Matches tasks to the user's current energy level.
  Future<Map<String, dynamic>> energyMatch(
      List<String> tasks, int energy) async {
    final r = await _send(_client.post(
      Uri.parse('$baseUrl/energy/match'),
      headers: _headers(),
      body: jsonEncode({'tasks': tasks, 'energy': energy}),
    ));
    return _decodeEnsureOk(r);
  }

  /// Reduces a list of options to a smaller subset to reduce choice overload.
  Future<Map<String, dynamic>> reduceOptions(
      List<String> options, int limit) async {
    final r = await _send(_client.post(
      Uri.parse('$baseUrl/decision/reduce'),
      headers: _headers(),
      body: jsonEncode({'options': options, 'limit': limit}),
    ));
    return _decodeEnsureOk(r);
  }

  /// Commits a decision choice.
  Future<Map<String, dynamic>> decisionCommit(String choice) async {
    final r = await _send(_client.post(
      Uri.parse('$baseUrl/decision/commit'),
      headers: _headers(),
      body: jsonEncode({'choice': choice}),
    ));
    return _decodeEnsureOk(r);
  }

  /// Captures an external transcript or note.
  Future<Map<String, dynamic>> captureExternal(String transcript) async {
    final r = await _send(_client.post(
      Uri.parse('$baseUrl/external/capture'),
      headers: _headers(),
      body: jsonEncode({'transcript': transcript}),
    ));
    return _decodeEnsureOk(r);
  }

  /// Retrieves all external notes.
  Future<List<dynamic>> externalNotes() async {
    final r = await _send(_client.get(Uri.parse('$baseUrl/external/notes')));
    final m = _decodeEnsureOk(r);
    return (m['notes'] as List<dynamic>? ?? []);
  }

  /// Sends a user message to the chat agent and gets a response.
  ///
  /// Supports optional [sessionId] and [googleSearch] flag.
  Future<Map<String, dynamic>> chatRespond(String text,
      {String? sessionId, bool? googleSearch}) async {
    final payload = <String, dynamic>{'text': text};
    if (sessionId != null) payload['session_id'] = sessionId;
    if (googleSearch != null) payload['google_search'] = googleSearch;
    final r = await _sendWithRetry(
        _client.post(
          Uri.parse('$baseUrl/chat/respond'),
          headers: _headers(),
          body: jsonEncode(payload),
        ),
        timeoutSeconds: 20,
        retries: 1);
    return _decodeEnsureOk(r);
  }

  /// Sends a command to the chat agent.
  Future<Map<String, dynamic>> chatCommand(String text,
      {String? sessionId, bool? googleSearch}) async {
    final payload = <String, dynamic>{'text': text};
    if (sessionId != null) payload['session_id'] = sessionId;
    if (googleSearch != null) payload['google_search'] = googleSearch;
    final r = await _sendWithRetry(
        _client.post(
          Uri.parse('$baseUrl/chat/command'),
          headers: _headers(),
          body: jsonEncode(payload),
        ),
        timeoutSeconds: 20,
        retries: 1);
    return _decodeEnsureOk(r);
  }

  /// Retrieves help information for the chat interface.
  Future<Map<String, dynamic>> chatHelp() async {
    final r = await _send(http.get(Uri.parse('$baseUrl/chat/help')));
    return _decodeEnsureOk(r);
  }

  // Generic HTTP methods for new endpoints
  Future<Map<String, dynamic>> get(String path) async {
    final r = await _send(_client.get(
      Uri.parse('$baseUrl$path'),
      headers: _headers(),
    ));
    return _decodeEnsureOk(r);
  }

  Future<Map<String, dynamic>> post(
      String path, Map<String, dynamic> body) async {
    final r = await _send(_client.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers(),
      body: jsonEncode(body),
    ));
    return _decodeEnsureOk(r);
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final r = await _send(_client.delete(
      Uri.parse('$baseUrl$path'),
      headers: _headers(),
    ));
    return _decodeEnsureOk(r);
  }

  /// Decodes the response body and ensures the status code is 2xx.
  ///
  /// Throws the error message from the body or a default message on failure.
  Map<String, dynamic> _decodeEnsureOk(http.Response r) {
    final body = r.body.isEmpty ? '{}' : r.body;
    final map = jsonDecode(body) as Map<String, dynamic>;
    if (r.statusCode >= 200 && r.statusCode < 300) return map;
    final msg =
        map['error'] ?? map['message'] ?? 'Request failed (${r.statusCode})';
    throw msg;
  }

  /// Wraps a future with error handling.
  Future<http.Response> _send(Future<http.Response> future) async {
    try {
      return await future.timeout(const Duration(seconds: 10));
    } on TimeoutException {
      debugPrint('Network timeout');
      throw TimeoutException('Network timeout');
    } on Object catch (e) {
      debugPrint('Network error: $e');
      rethrow;
    }
  }

  /// Wraps a future with retry logic and error handling.
  Future<http.Response> _sendWithRetry(Future<http.Response> future,
      {int timeoutSeconds = 10, int retries = 0}) async {
    int attempt = 0;
    while (true) {
      try {
        return await future.timeout(Duration(seconds: timeoutSeconds));
      } on TimeoutException {
        debugPrint('Network timeout');
        if (attempt >= retries) {
          throw TimeoutException('Network timeout');
        }
        await Future.delayed(Duration(milliseconds: 300 * (attempt + 1)));
        attempt++;
        continue;
      } on Object catch (e) {
        debugPrint('Network error: $e');
        rethrow;
      }
    }
  }
}
