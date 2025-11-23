import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  bool _initialized = false;

  Future<bool> initialize() async {
    if (_initialized) return true;
    try {
      await Firebase.initializeApp();
      _initialized = true;
      return true;
    } catch (_) {
      _initialized = false;
      return false;
    }
  }

  Stream<User?> authStateChanges() {
    return FirebaseAuth.instance.authStateChanges();
  }

  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> signUpWithEmail(String email, String password, {String? displayName}) async {
    final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
    if (displayName != null && displayName.isNotEmpty) {
      await cred.user?.updateDisplayName(displayName);
    }
    return cred;
  }

  Future<void> sendPasswordReset(String email) async {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final g = GoogleSignIn();
      final acc = await g.signIn();
      if (acc == null) return null;
      final auth = await acc.authentication;
      final cred = GoogleAuthProvider.credential(accessToken: auth.accessToken, idToken: auth.idToken);
      return await FirebaseAuth.instance.signInWithCredential(cred);
    } catch (_) {
      return null;
    }
  }

  Future<String?> idToken() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return null;
    return await u.getIdToken();
  }
}
