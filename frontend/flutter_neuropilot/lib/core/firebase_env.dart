import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

FirebaseOptions _webOptions() {
  return const FirebaseOptions(
    apiKey: 'AIzaSyAJLKL_cROVl7fOJsO1oZuOKDhjzf36O8w',
    appId: '1:848026269314:web:496ec795532a3b8363269b',
    messagingSenderId: '848026269314',
    projectId: 'neuropilot-23fb5',
    authDomain: 'neuropilot-23fb5.firebaseapp.com',
    storageBucket: 'neuropilot-23fb5.firebasestorage.app',
  );
}

Future<void> initFirebase() async {
  if (kIsWeb) {
    await Firebase.initializeApp(options: _webOptions());
  } else {
    await Firebase.initializeApp();
  }
}
