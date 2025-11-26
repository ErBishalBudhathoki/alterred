import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'session_state.dart';

/// Manages authentication state and navigation flow using Riverpod.
///
/// Implementation Details:
/// - Wraps [AuthService] methods with Riverpod providers for reactive state updates.
/// - Handles user session synchronization with the backend via [idTokenSyncProvider].
/// - Determines the initial navigation route based on auth status.
///
/// Design Decisions:
/// - [navigationProvider] logic centralizes the routing decision (Login vs Chat).
/// - [AuthController] encapsulates auth actions to keep UI code clean.
///
/// Behavioral Specifications:
/// - [authUserProvider]: Emits the current Firebase User or null.
/// - [idTokenSyncProvider]: Fetches the ID token and updates [tokenProvider] for API calls.
/// - [navigationProvider]: Redirects to /login if unauthenticated, /chat if authenticated.

/// Provides access to the underlying [AuthService] instance.
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Ensures the auth service is initialized before use.
final authInitializedProvider = FutureProvider<bool>((ref) async {
  final svc = ref.read(authServiceProvider);
  return await svc.initialize();
});

/// Streams the current authentication state from Firebase.
final authUserProvider = StreamProvider<User?>((ref) {
  final svc = ref.read(authServiceProvider);
  return svc.authStateChanges();
});

/// Synchronizes the Firebase ID token with the application state.
///
/// This token is used for authenticated API requests.
final idTokenSyncProvider = FutureProvider<void>((ref) async {
  final svc = ref.read(authServiceProvider);
  final tok = await svc.idToken();
  ref.read(tokenProvider.notifier).state = tok;
});

/// Determines the initial route based on authentication status.
///
/// Returns:
/// - '/chat' if the user is authenticated.
/// - '/login' if the user is not authenticated or initialization fails.
final navigationProvider = FutureProvider<String>((ref) async {
  final isInitialized = await ref.watch(authInitializedProvider.future);
  if (!isInitialized) {
    return '/login';
  }

  final user = await ref.watch(authUserProvider.future);
  if (user != null) {
    await ref.read(idTokenSyncProvider.future);
    return '/chat';
  } else {
    return '/login';
  }
});

/// Controller for authentication actions.
///
/// Encapsulates sign-in, sign-up, and sign-out logic, updating
/// the application state via Riverpod providers.
class AuthController {
  final Ref ref;
  AuthController(this.ref);

  /// Signs in a user with email and password.
  ///
  /// Throws [FirebaseAuthException] on failure.
  Future<void> signInEmail(String email, String password) async {
    final svc = ref.read(authServiceProvider);
    final ok = await ref.read(authInitializedProvider.future);
    if (!ok) throw Exception('Auth service failed to initialize');

    await svc.signInWithEmail(email, password);
    await ref.read(idTokenSyncProvider.future);
  }

  /// Registers a new user with email and password.
  ///
  /// Throws [FirebaseAuthException] on failure.
  Future<void> signUpEmail(String email, String password,
      {String? displayName}) async {
    final svc = ref.read(authServiceProvider);
    final ok = await ref.read(authInitializedProvider.future);
    if (!ok) throw Exception('Auth service failed to initialize');

    await svc.signUpWithEmail(email, password, displayName: displayName);
    await ref.read(idTokenSyncProvider.future);
  }

  /// Signs in a user with Google.
  ///
  /// Returns true if successful, false otherwise.
  Future<bool> signInGoogle() async {
    final svc = ref.read(authServiceProvider);
    final ok = await ref.read(authInitializedProvider.future);
    if (!ok) return false;
    final cred = await svc.signInWithGoogle();
    if (cred == null) return false;
    await ref.read(idTokenSyncProvider.future);
    return true;
  }

  /// Sends a password reset email.
  ///
  /// Throws [FirebaseAuthException] on failure.
  Future<void> sendPasswordReset(String email) async {
    final svc = ref.read(authServiceProvider);
    final ok = await ref.read(authInitializedProvider.future);
    if (!ok) throw Exception('Auth service failed to initialize');
    await svc.sendPasswordReset(email);
  }

  /// Signs out the current user and clears the session token.
  Future<void> signOut() async {
    final svc = ref.read(authServiceProvider);
    await svc.signOut();
    ref.read(tokenProvider.notifier).state = null;
  }
}

/// Provides an instance of [AuthController].
final authControllerProvider =
    Provider<AuthController>((ref) => AuthController(ref));
