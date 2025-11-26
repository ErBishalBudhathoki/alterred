import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

/// Firebase initialization and configuration logic.
///
/// Implementation Details:
/// - Uses `String.fromEnvironment` to inject configuration at build time for web.
/// - Delegates to platform-native configuration files (google-services.json / GoogleService-Info.plist) for mobile.
///
/// Design Decisions:
/// - Environment variable injection for web allows flexible deployment without committing secrets.
/// - Separate initialization path for web vs. mobile handles platform differences.
///
/// Behavioral Specifications:
/// - [initFirebase]: Initializes the Firebase app instance.
/// - [_webOptionsFromEnv]: Parsed environment variables into [FirebaseOptions].
/// - Throws [UnsupportedError] if required web config is missing.
FirebaseOptions _webOptionsFromEnv() {
  const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  const appId = String.fromEnvironment('FIREBASE_APP_ID');
  const messagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  const storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  const measurementId = String.fromEnvironment('FIREBASE_MEASUREMENT_ID');
  if (projectId.isEmpty) {
    throw UnsupportedError('Missing Firebase web env');
  }
  return FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    authDomain: authDomain.isEmpty ? null : authDomain,
    storageBucket: storageBucket.isEmpty ? null : storageBucket,
    measurementId: measurementId.isEmpty ? null : measurementId,
  );
}

Future<void> initFirebase() async {
  if (kIsWeb) {
    try {
      await Firebase.initializeApp(options: _webOptionsFromEnv());
    } catch (e) {
      debugPrint('Failed to initialize Firebase: $e');
    }
  } else {
    await Firebase.initializeApp();
  }
}
