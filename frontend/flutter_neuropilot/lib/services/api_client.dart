import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

class ApiClient {
  final String baseUrl;
  final String? token;
  final http.Client _client;
  ApiClient({required this.baseUrl, this.token, http.Client? client}) : _client = client ?? http.Client();

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> health() async {
    final r = await _send(_client.get(Uri.parse('$baseUrl/health')));
    return _decodeEnsureOk(r);
  }

  Future<Map<String, dynamic>> metricsOverview() async {
    final r = await _send(_client.get(Uri.parse('$baseUrl/metrics/overview')));
    return _decodeEnsureOk(r);
  }

  Future<Map<String, dynamic>> calendarEventsToday() async {
    final r = await _send(_client.get(Uri.parse('$baseUrl/calendar/events/today')));
    return _decodeEnsureOk(r);
  }

  Future<Map<String, dynamic>> sessionsYesterday() async {
    final r = await _send(_client.get(Uri.parse('$baseUrl/sessions/yesterday')));
    return _decodeEnsureOk(r);
  }

  Future<Map<String, dynamic>> atomizeTask(String description) async {
    final r = await _send(_client.post(
      Uri.parse('$baseUrl/tasks/atomize'),
      headers: _headers(),
      body: jsonEncode({'description': description}),
    ));
    return _decodeEnsureOk(r);
  }

  Future<Map<String, dynamic>> scheduleTasks(List<String> items, int energy, List<int>? weights) async {
    final r = await _send(_client.post(
      Uri.parse('$baseUrl/tasks/schedule'),
      headers: _headers(),
      body: jsonEncode({'items': items, 'energy': energy, 'weights': weights}),
    ));
    return _decodeEnsureOk(r);
  }

  Future<Map<String, dynamic>> createCountdown(String query) async {
    final r = await _send(_client.post(
      Uri.parse('$baseUrl/time/countdown'),
      headers: _headers(),
      body: jsonEncode({'query': query}),
    ));
    return _decodeEnsureOk(r);
  }

  Future<Map<String, dynamic>> energyMatch(List<String> tasks, int energy) async {
    final r = await _send(_client.post(
      Uri.parse('$baseUrl/energy/match'),
      headers: _headers(),
      body: jsonEncode({'tasks': tasks, 'energy': energy}),
    ));
    return _decodeEnsureOk(r);
  }

  Future<Map<String, dynamic>> reduceOptions(List<String> options, int limit) async {
    final r = await _send(_client.post(
      Uri.parse('$baseUrl/decision/reduce'),
      headers: _headers(),
      body: jsonEncode({'options': options, 'limit': limit}),
    ));
    return _decodeEnsureOk(r);
  }

  Future<Map<String, dynamic>> decisionCommit(String choice) async {
    final r = await _send(_client.post(
      Uri.parse('$baseUrl/decision/commit'),
      headers: _headers(),
      body: jsonEncode({'choice': choice}),
    ));
    return _decodeEnsureOk(r);
  }

  Future<Map<String, dynamic>> captureExternal(String transcript) async {
    final r = await _send(_client.post(
      Uri.parse('$baseUrl/external/capture'),
      headers: _headers(),
      body: jsonEncode({'transcript': transcript}),
    ));
    return _decodeEnsureOk(r);
  }

  Future<List<dynamic>> externalNotes() async {
    final r = await _send(_client.get(Uri.parse('$baseUrl/external/notes')));
    final m = _decodeEnsureOk(r);
    return (m['notes'] as List<dynamic>? ?? []);
  }

  Future<Map<String, dynamic>> chatRespond(String text, {String? sessionId}) async {
    final payload = <String, dynamic>{'text': text};
    if (sessionId != null) payload['session_id'] = sessionId;
    final r = await _send(_client.post(
      Uri.parse('$baseUrl/chat/respond'),
      headers: _headers(),
      body: jsonEncode(payload),
    ));
    return _decodeEnsureOk(r);
  }

  Future<Map<String, dynamic>> chatCommand(String text, {String? sessionId}) async {
    final payload = <String, dynamic>{'text': text};
    if (sessionId != null) payload['session_id'] = sessionId;
    final r = await _send(_client.post(
      Uri.parse('$baseUrl/chat/command'),
      headers: _headers(),
      body: jsonEncode(payload),
    ));
    return _decodeEnsureOk(r);
  }

  Future<Map<String, dynamic>> chatHelp() async {
    final r = await _send(http.get(Uri.parse('$baseUrl/chat/help')));
    return _decodeEnsureOk(r);
  }

  Map<String, dynamic> _decodeEnsureOk(http.Response r) {
    final body = r.body.isEmpty ? '{}' : r.body;
    final map = jsonDecode(body) as Map<String, dynamic>;
    if (r.statusCode >= 200 && r.statusCode < 300) return map;
    final msg = map['error'] ?? map['message'] ?? 'Request failed (${r.statusCode})';
    throw msg;
  }

  Future<http.Response> _send(Future<http.Response> future) async {
    try {
      return await future.timeout(const Duration(seconds: 10));
    } on TimeoutException {
      debugPrint('Network timeout');
      throw 'Network timeout';
    } on Object catch (e) {
      debugPrint('Network error: $e');
      rethrow;
    }
  }
}
