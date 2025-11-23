import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/design_tokens.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/routes.dart';
import '../state/auth_state.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  late final Animation<double> _fade;
  bool _started = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _fade = CurvedAnimation(parent: _ctl, curve: Curves.easeInOut);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_started) return;
      _started = true;
      ref.listen<AsyncValue<bool>>(authInitializedProvider, (prev, next) async {
        if (_navigated || !mounted) return;
        if (next.hasError) {
          _navigated = true;
          Navigator.of(context)
              .pushNamedAndRemoveUntil(Routes.login, (r) => false);
          return;
        }
        if (next.hasValue && next.value == true) {
          try {
            await ref.read(idTokenSyncProvider.future);
          } catch (_) {}
          ref.listen<AsyncValue<User?>>(authUserProvider, (p, n) {
            if (_navigated || !mounted) return;
            if (n.hasValue) {
              final u = n.value;
              _navigated = true;
              Navigator.of(context).pushNamedAndRemoveUntil(
                  u != null ? Routes.chat : Routes.login, (r) => false);
            }
          });
        }
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      _ctl.value = 1;
    } else {
      _ctl.forward();
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.primary,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt, size: 72, color: DesignTokens.onPrimary),
              const SizedBox(height: DesignTokens.spacingSm),
              const Text('NeuroPilot',
                  style: TextStyle(
                      color: DesignTokens.onPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: DesignTokens.spacingSm),
              SizedBox(
                  width: 160,
                  child: LinearProgressIndicator(
                      color: DesignTokens.onPrimary,
                      backgroundColor: cs.primary.withValues(alpha: 0.4))),
            ],
          ),
        ),
      ),
    );
  }
}
