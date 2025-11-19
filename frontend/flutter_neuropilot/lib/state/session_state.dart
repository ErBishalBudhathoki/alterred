import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

final baseUrlProvider = Provider<String>((ref) => const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8000'));
final tokenProvider = StateProvider<String?>((ref) => null);
final localeProvider = StateProvider<Locale?>((ref) => null);
final savedLocaleProvider = FutureProvider<Locale?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final code = prefs.getString('locale_code');
  if (code == null) return null;
  final parts = code.split('_');
  return parts.length == 2 ? Locale(parts[0], parts[1]) : Locale(parts[0]);
});
final apiClientProvider = Provider<ApiClient>((ref) {
  final base = ref.watch(baseUrlProvider);
  final tok = ref.watch(tokenProvider);
  return ApiClient(baseUrl: base, token: tok);
});