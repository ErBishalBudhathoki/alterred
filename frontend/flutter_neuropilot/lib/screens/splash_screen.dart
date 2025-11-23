import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/design_tokens.dart';
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

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _fade = CurvedAnimation(parent: _ctl, curve: Curves.easeInOut);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_started) return;
      _started = true;
      try {
        final ok = await ref
            .read(authInitializedProvider.future)
            .timeout(const Duration(seconds: 3), onTimeout: () => false);
        if (ok) {
          try {
            await ref
                .read(idTokenSyncProvider.future)
                .timeout(const Duration(seconds: 2));
          } catch (_) {}
          
          // Only check auth state after Firebase is initialized
          await Future.delayed(const Duration(milliseconds: 2500));
          if (!mounted) return;
          final user = ref.read(authUserProvider).value;
          final route = user != null ? Routes.chat : Routes.login;
          Navigator.of(context).pushReplacementNamed(route);
        } else {
          // Firebase init failed, go to login
          await Future.delayed(const Duration(milliseconds: 2500));
          if (!mounted) return;
          Navigator.of(context).pushReplacementNamed(Routes.login);
        }
      } catch (_) {
        // Error during init, go to login
        await Future.delayed(const Duration(milliseconds: 2500));
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(Routes.login);
      }
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
