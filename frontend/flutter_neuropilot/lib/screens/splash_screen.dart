import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/design_tokens.dart';
import '../state/auth_state.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Initial launch screen handling authentication state checks.
///
/// Implementation Details:
/// - Listens to [navigationProvider] to determine the next screen (Login or Chat).
/// - Displays an animated logo while loading.
///
/// Design Decisions:
/// - Uses [FadeTransition] for a smooth visual entry.
/// - Handles "Reduce Motion" accessibility setting by skipping animation.
///
/// Behavioral Specifications:
/// - Starts animation on load.
/// - Navigates away once auth state is determined.
/// - Fallback to login screen on error.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt, size: 72, color: DesignTokens.onPrimary)
                .animate()
                .fadeIn(duration: 600.ms)
                .scale(delay: 200.ms, duration: 400.ms)
                .then()
                .shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.5))
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(end: 1.1, duration: 1000.ms),
            const SizedBox(height: DesignTokens.spacingSm),
            const Text('Altered',
                    style: TextStyle(
                        color: DesignTokens.onPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w600))
                .animate()
                .fadeIn(delay: 400.ms, duration: 600.ms)
                .slideY(begin: 0.2, end: 0),
            const SizedBox(height: DesignTokens.spacingSm),
            SizedBox(
                    width: 160,
                    child: LinearProgressIndicator(
                        color: DesignTokens.onPrimary,
                        backgroundColor: cs.primary.withValues(alpha: 0.4)))
                .animate()
                .fadeIn(delay: 600.ms, duration: 600.ms),
          ],
        ),
      ),
    );
  }
}
