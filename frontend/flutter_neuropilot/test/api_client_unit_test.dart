// Unit tests for `ApiClient` error handling and decode logic.
// These tests stub HTTP client with `MockClient` to validate:
// - 2xx decode path returns the parsed map
// - Non-2xx responses throw an error extracted from JSON
// - Token/baseUrl wiring remains intact
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:altered/services/api_client.dart';

ApiClient _clientWith(MockClient mc) =>
    ApiClient(baseUrl: 'http://example', token: 't', client: mc);

void main() {
  /// Verifies that 2xx responses are decoded to a map.
  test('ApiClient decodes 2xx JSON', () async {
    final c = _clientWith(
        MockClient((req) async => http.Response('{"message":"ok"}', 200)));
    final m = await c.health();
    expect(m['message'], 'ok');
    expect(c.token, 't');
    expect(c.baseUrl, 'http://example');
  });

  /// Verifies that non-2xx responses throw with a meaningful message.
  test('ApiClient throws on non-2xx', () async {
    final c = _clientWith(
        MockClient((req) async => http.Response('{"error":"bad"}', 400)));
    expect(() => c.metricsOverview(), throwsA('bad'));
  });

  /// Ensures default error message when response body has no error field.
  test('ApiClient throws default message on bad body', () async {
    final c = _clientWith(
        MockClient((req) async => http.Response('{"note":"none"}', 500)));
    expect(() => c.sessionsYesterday(), throwsA(isA<String>()));
  });
}
