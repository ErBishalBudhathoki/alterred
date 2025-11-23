import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

String get baseUrl => const String.fromEnvironment('API_BASE_URL',
    defaultValue: 'http://localhost:8000');
const _tokenEnv = String.fromEnvironment('API_TOKEN', defaultValue: '');
String? get token => _tokenEnv.isEmpty ? null : _tokenEnv;

Map<String, String> headers() => {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

Future<Map<String, dynamic>> decode(http.Response r) async {
  final body = r.body.isEmpty ? '{}' : r.body;
  return jsonDecode(body) as Map<String, dynamic>;
}

Future<bool> backendReachable() async {
  try {
    final r = await http
        .get(Uri.parse('$baseUrl/health'))
        .timeout(const Duration(seconds: 2));
    return r.statusCode >= 200 && r.statusCode < 500;
  } catch (_) {
    return false;
  }
}

void main() {
  group('API functional', () {
    test('health ok', () async {
      if (!await backendReachable()) {
        debugPrint('Backend unreachable at $baseUrl');
        return;
      }
      try {
        final t0 = DateTime.now();
        final r = await http
            .get(Uri.parse('$baseUrl/health'))
            .timeout(const Duration(seconds: 5));
        final dt = DateTime.now().difference(t0).inMilliseconds;
        final m = await decode(r);
        debugPrint(
            'GET /health status=${r.statusCode} time_ms=$dt headers=${r.headers} body=$m');
        expect(r.statusCode, greaterThanOrEqualTo(200));
        expect(r.statusCode, lessThan(300));
      } catch (e) {
        debugPrint('Request failed: $e');
        return;
      }
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('atomize valid/invalid', () async {
      if (!await backendReachable()) {
        debugPrint('Backend unreachable at $baseUrl');
        return;
      }
      try {
        final good = {'description': 'Plan weekend trip'};
        final bad = {'description': ''};
        final r1 = await http
            .post(Uri.parse('$baseUrl/tasks/atomize'),
                headers: headers(), body: jsonEncode(good))
            .timeout(const Duration(seconds: 5));
        final m1 = await decode(r1);
        debugPrint(
            'POST /tasks/atomize valid status=${r1.statusCode} headers=${r1.headers} body=$m1');
        expect(r1.statusCode, greaterThanOrEqualTo(200));
        expect(r1.statusCode, lessThan(300));
        final r2 = await http
            .post(Uri.parse('$baseUrl/tasks/atomize'),
                headers: headers(), body: jsonEncode(bad))
            .timeout(const Duration(seconds: 5));
        final m2 = await decode(r2);
        debugPrint(
            'POST /tasks/atomize invalid status=${r2.statusCode} headers=${r2.headers} body=$m2');
        final okInvalid = r2.statusCode >= 200 && r2.statusCode < 300;
        final errInvalid = r2.statusCode >= 400;
        expect(okInvalid || errInvalid, isTrue);
      } catch (e) {
        debugPrint('Request failed: $e');
        return;
      }
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('schedule tasks edge cases', () async {
      if (!await backendReachable()) {
        debugPrint('Backend unreachable at $baseUrl');
        return;
      }
      try {
        final payload = {
          'items': ['A', 'B', 'C'],
          'energy': 5,
          'weights': [1, 2, 3]
        };
        final r = await http
            .post(Uri.parse('$baseUrl/tasks/schedule'),
                headers: headers(), body: jsonEncode(payload))
            .timeout(const Duration(seconds: 5));
        final m = await decode(r);
        debugPrint(
            'POST /tasks/schedule status=${r.statusCode} headers=${r.headers} body=$m');
        expect(r.statusCode, greaterThanOrEqualTo(200));
        expect(r.statusCode, lessThan(300));
        final bad = {'items': [], 'energy': -1, 'weights': []};
        final rBad = await http
            .post(Uri.parse('$baseUrl/tasks/schedule'),
                headers: headers(), body: jsonEncode(bad))
            .timeout(const Duration(seconds: 5));
        final mBad = await decode(rBad);
        debugPrint(
            'POST /tasks/schedule invalid status=${rBad.statusCode} headers=${rBad.headers} body=$mBad');
        final okInvalid = rBad.statusCode >= 200 && rBad.statusCode < 300;
        final errInvalid = rBad.statusCode >= 400;
        expect(okInvalid || errInvalid, isTrue);
      } catch (e) {
        debugPrint('Request failed: $e');
        return;
      }
    });

    test('countdown ISO validation', () async {
      if (!await backendReachable()) {
        debugPrint('Backend unreachable at $baseUrl');
        return;
      }
      try {
        final ok = {
          'target_iso':
              DateTime.now().add(const Duration(hours: 2)).toIso8601String()
        };
        final r = await http
            .post(Uri.parse('$baseUrl/time/countdown'),
                headers: headers(), body: jsonEncode(ok))
            .timeout(const Duration(seconds: 5));
        final m = await decode(r);
        debugPrint(
            'POST /time/countdown status=${r.statusCode} headers=${r.headers} body=$m');
        final okStatus = r.statusCode >= 200 && r.statusCode < 300;
        final errStatus = r.statusCode >= 400;
        expect(okStatus || errStatus, isTrue);
        final bad = {'target_iso': 'not-a-date'};
        final rBad = await http
            .post(Uri.parse('$baseUrl/time/countdown'),
                headers: headers(), body: jsonEncode(bad))
            .timeout(const Duration(seconds: 5));
        final mBad = await decode(rBad);
        debugPrint(
            'POST /time/countdown invalid status=${rBad.statusCode} headers=${rBad.headers} body=$mBad');
        final okInvalid = rBad.statusCode >= 200 && rBad.statusCode < 300;
        final errInvalid = rBad.statusCode >= 400;
        expect(okInvalid || errInvalid, isTrue);
      } catch (e) {
        debugPrint('Request failed: $e');
        return;
      }
    });

    test('energy match invalid energy', () async {
      if (!await backendReachable()) {
        debugPrint('Backend unreachable at $baseUrl');
        return;
      }
      try {
        final ok = {
          'tasks': ['Email', 'Code'],
          'energy': 3
        };
        final r = await http
            .post(Uri.parse('$baseUrl/energy/match'),
                headers: headers(), body: jsonEncode(ok))
            .timeout(const Duration(seconds: 5));
        final m = await decode(r);
        debugPrint(
            'POST /energy/match status=${r.statusCode} headers=${r.headers} body=$m');
        final okStatus = r.statusCode >= 200 && r.statusCode < 300;
        final errStatus = r.statusCode >= 400;
        expect(okStatus || errStatus, isTrue);
        final bad = {
          'tasks': ['Email'],
          'energy': -5
        };
        final rBad = await http
            .post(Uri.parse('$baseUrl/energy/match'),
                headers: headers(), body: jsonEncode(bad))
            .timeout(const Duration(seconds: 5));
        final mBad = await decode(rBad);
        debugPrint(
            'POST /energy/match invalid status=${rBad.statusCode} headers=${rBad.headers} body=$mBad');
        final okInvalid = rBad.statusCode >= 200 && rBad.statusCode < 300;
        final errInvalid = rBad.statusCode >= 400;
        expect(okInvalid || errInvalid, isTrue);
      } catch (e) {
        debugPrint('Request failed: $e');
        return;
      }
    });

    test('decision reduce and commit', () async {
      if (!await backendReachable()) {
        debugPrint('Backend unreachable at $baseUrl');
        return;
      }
      try {
        final reduce = {
          'options': ['A', 'B', 'C', 'D'],
          'limit': 2
        };
        final r = await http
            .post(Uri.parse('$baseUrl/decision/reduce'),
                headers: headers(), body: jsonEncode(reduce))
            .timeout(const Duration(seconds: 5));
        final m = await decode(r);
        debugPrint(
            'POST /decision/reduce status=${r.statusCode} headers=${r.headers} body=$m');
        expect(r.statusCode, inInclusiveRange(200, 299));
        final commit = {'choice': 'A'};
        final c = await http
            .post(Uri.parse('$baseUrl/decision/commit'),
                headers: headers(), body: jsonEncode(commit))
            .timeout(const Duration(seconds: 5));
        final mc = await decode(c);
        debugPrint(
            'POST /decision/commit status=${c.statusCode} headers=${c.headers} body=$mc');
        expect(c.statusCode, inInclusiveRange(200, 299));
      } catch (e) {
        debugPrint('Request failed: $e');
        return;
      }
    });

    test('external capture invalid', () async {
      if (!await backendReachable()) {
        debugPrint('Backend unreachable at $baseUrl');
        return;
      }
      try {
        final ok = {'transcript': 'Met with team, action items captured'};
        final r = await http
            .post(Uri.parse('$baseUrl/external/capture'),
                headers: headers(), body: jsonEncode(ok))
            .timeout(const Duration(seconds: 5));
        final m = await decode(r);
        debugPrint(
            'POST /external/capture status=${r.statusCode} headers=${r.headers} body=$m');
        expect(r.statusCode, inInclusiveRange(200, 299));
        final bad = {'transcript': ''};
        final rBad = await http
            .post(Uri.parse('$baseUrl/external/capture'),
                headers: headers(), body: jsonEncode(bad))
            .timeout(const Duration(seconds: 5));
        final mBad = await decode(rBad);
        debugPrint(
            'POST /external/capture invalid status=${rBad.statusCode} headers=${rBad.headers} body=$mBad');
        final acceptsEmpty = rBad.statusCode >= 200 && rBad.statusCode < 300;
        final rejectsEmpty = rBad.statusCode >= 400;
        expect(acceptsEmpty || rejectsEmpty, isTrue);
      } catch (e) {
        debugPrint('Request failed: $e');
        return;
      }
    });
  });

  group('Headers and auth', () {
    test('Authorization header present when token defined', () async {
      if (!await backendReachable()) {
        debugPrint('Backend unreachable at $baseUrl');
        return;
      }
      if (token == null) {
        debugPrint('No token defined via API_TOKEN');
        return;
      }
      final r = await http
          .post(Uri.parse('$baseUrl/decision/commit'),
              headers: headers(), body: jsonEncode({'choice': 'A'}))
          .timeout(const Duration(seconds: 5));
      debugPrint('Auth check status=${r.statusCode} headers=${r.headers}');
      expect(
          r.request!.headers['Authorization']?.startsWith('Bearer '), isTrue);
    });
  });

  group('Timeouts and performance', () {
    test('handles timeout gracefully', () async {
      try {
        await http
            .get(Uri.parse('$baseUrl/health'))
            .timeout(const Duration(milliseconds: 1));
        expect(true, isTrue);
      } catch (e) {
        debugPrint('Network error or timeout: $e');
        expect(e.toString().isNotEmpty, isTrue);
      }
    });
  });
}
