import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:altered/state/session_state.dart';

void main() {
  test('savedLocaleProvider loads locale from SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({'locale_code': 'en'});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final locale = await container.read(savedLocaleProvider.future);
    expect(locale, const Locale('en'));
  });

  test('apiClientProvider receives base url and token', () async {
    final container = ProviderContainer(overrides: [
      baseUrlProvider.overrideWith((ref) => 'http://example.com'),
      tokenProvider.overrideWith((ref) => 'abc'),
    ]);
    addTearDown(container.dispose);
    final client = container.read(apiClientProvider);
    expect(client.baseUrl, 'http://example.com');
    expect(client.token, 'abc');
  });
}

// Unit tests for Riverpod session providers.
// Validates `savedLocaleProvider` parsing and `apiClientProvider`
// wiring of base URL and token.
