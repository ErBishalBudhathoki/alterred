import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/design_tokens.dart';
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

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _fade = CurvedAnimation(parent: _ctl, curve: Curves.easeInOut);
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
    ref.listen<AsyncValue<String>>(navigationProvider, (prev, next) {
      if (next.hasValue) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil(next.value!, (r) => false);
      } else if (next.hasError) {
        debugPrint('Navigation error: ${next.error}');
        // Fallback to login on error
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
      }
    });

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
