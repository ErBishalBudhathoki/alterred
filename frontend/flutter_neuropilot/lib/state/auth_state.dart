import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'session_state.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authInitializedProvider = FutureProvider<bool>((ref) async {
  final svc = ref.read(authServiceProvider);
  return await svc.initialize();
});

final authUserProvider = StreamProvider<User?>((ref) {
  final svc = ref.read(authServiceProvider);
  return svc.authStateChanges();
});

final idTokenSyncProvider = FutureProvider<void>((ref) async {
  final svc = ref.read(authServiceProvider);
  final tok = await svc.idToken();
  ref.read(tokenProvider.notifier).state = tok;
});

class AuthController {
  final Ref ref;
  AuthController(this.ref);

  Future<bool> signInEmail(String email, String password) async {
    final svc = ref.read(authServiceProvider);
    final ok = await ref.read(authInitializedProvider.future);
    if (!ok) return false;
    try {
      await svc.signInWithEmail(email, password);
      await ref.read(idTokenSyncProvider.future);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> signUpEmail(String email, String password, {String? displayName}) async {
    final svc = ref.read(authServiceProvider);
    final ok = await ref.read(authInitializedProvider.future);
    if (!ok) return false;
    try {
      await svc.signUpWithEmail(email, password, displayName: displayName);
      await ref.read(idTokenSyncProvider.future);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> signInGoogle() async {
    final svc = ref.read(authServiceProvider);
    final ok = await ref.read(authInitializedProvider.future);
    if (!ok) return false;
    final cred = await svc.signInWithGoogle();
    if (cred == null) return false;
    await ref.read(idTokenSyncProvider.future);
    return true;
  }

  Future<void> sendPasswordReset(String email) async {
    final svc = ref.read(authServiceProvider);
    final ok = await ref.read(authInitializedProvider.future);
    if (!ok) return;
    await svc.sendPasswordReset(email);
  }

  Future<void> signOut() async {
    final svc = ref.read(authServiceProvider);
    await svc.signOut();
    ref.read(tokenProvider.notifier).state = null;
  }
}

final authControllerProvider = Provider<AuthController>((ref) => AuthController(ref));
