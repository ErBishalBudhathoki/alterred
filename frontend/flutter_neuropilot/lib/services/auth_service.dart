import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

/// Auth Service
///
/// Manages user authentication via Firebase Auth.
/// Supports Email/Password and Google Sign-In.
///
/// Implementation Details:
/// - Wraps `FirebaseAuth` instance for testability and abstraction.
/// - Handles platform-specific Google Sign-In logic (Web vs. Mobile).
/// - Provides a stream of auth state changes for real-time UI updates.
///
/// Design Decisions:
/// - Singleton-like initialization pattern via `initialize()`.
/// - Abstracts the underlying provider details from the rest of the app.
///
/// Behavioral Specifications:
/// - `signInWithGoogle`: Handles the OAuth flow and returns a `UserCredential`.
/// - `idToken`: Retrieves the current user's ID token for backend requests.
class AuthService {
  bool _initialized = false;

  /// Initializes the Firebase app if not already initialized.
  Future<bool> initialize() async {
    if (_initialized) return true;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
        debugPrint('AuthService: Firebase initialized');
      }
      _initialized = true;
      return true;
    } catch (e) {
      debugPrint('AuthService: Initialization failed - $e');
      _initialized = Firebase.apps.isNotEmpty;
      return _initialized;
    }
  }

  /// Exposes the authentication state as a stream.
  Stream<User?> authStateChanges() {
    return FirebaseAuth.instance.authStateChanges();
  }

  /// Signs in a user with email and password.
  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      debugPrint('AuthService: Attempting sign in for $email');
      return await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      debugPrint('AuthService: Sign in failed - $e');
      rethrow;
    }
  }

  /// Registers a new user with email and password.
  Future<UserCredential> signUpWithEmail(String email, String password,
      {String? displayName}) async {
    try {
      debugPrint('AuthService: Attempting sign up for $email');
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      if (displayName != null && displayName.isNotEmpty) {
        await cred.user?.updateDisplayName(displayName);
      }
      return cred;
    } catch (e) {
      debugPrint('AuthService: Sign up failed - $e');
      rethrow;
    }
  }

  /// Sends a password reset email.
  Future<void> sendPasswordReset(String email) async {
    try {
      debugPrint('AuthService: Sending password reset to $email');
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } catch (e) {
      debugPrint('AuthService: Password reset failed - $e');
      rethrow;
    }
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      debugPrint('AuthService: Signed out');
    } catch (e) {
      debugPrint('AuthService: Sign out failed - $e');
      rethrow;
    }
  }

  /// Signs in using Google OAuth.
  ///
  /// Handles both Web (via `GoogleAuthProvider`) and Mobile (via `GoogleSignIn` plugin).
  Future<UserCredential?> signInWithGoogle() async {
    try {
      debugPrint('AuthService: Starting Google Sign In');
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        return await FirebaseAuth.instance.signInWithPopup(provider);
      } else {
        final g = GoogleSignIn();
        final acc = await g.signIn();
        if (acc == null) return null;
        final auth = await acc.authentication;
        final cred = GoogleAuthProvider.credential(
            accessToken: auth.accessToken, idToken: auth.idToken);
        return await FirebaseAuth.instance.signInWithCredential(cred);
      }
    } catch (e) {
      debugPrint('AuthService: Google Sign In failed - $e');
      return null;
    }
  }

  /// Retrieves the current user's ID token.
  Future<String?> idToken() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return null;
    return await u.getIdToken();
  }
}
