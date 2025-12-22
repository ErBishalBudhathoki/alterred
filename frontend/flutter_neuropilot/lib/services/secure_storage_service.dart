import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

class SecureStorageService {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
        // encryptedSharedPreferences: true, // Deprecated
        ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  static const _keyProfileStyle = 'profile_style';
  static const _keyAuthToken = 'auth_token'; // Example for auth token

  Future<void> saveProfileStyle(String style) async {
    await _storage.write(key: _keyProfileStyle, value: style);
  }

  Future<String?> getProfileStyle() async {
    return await _storage.read(key: _keyProfileStyle);
  }

  Future<void> saveAuthToken(String token) async {
    await _storage.write(key: _keyAuthToken, value: token);
  }

  Future<String?> getAuthToken() async {
    return await _storage.read(key: _keyAuthToken);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
