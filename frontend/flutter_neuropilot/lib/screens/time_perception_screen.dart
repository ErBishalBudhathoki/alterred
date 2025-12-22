import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

// -----------------------------------------------------------------------------
// 1. THEME & CONSTANTS
// -----------------------------------------------------------------------------
class AppTheme {
  static const Color bgDark = Color(0xFF0F0505);
  static const Color primary = Color(0xFF683831);
  static const Color primaryHover = Color(0xFF7A423A);
  static const Color safeAccent = Color(0xFFE1B38C); // The orange/beige
  static const Color alertAccent = Color(0xFF6C7494); // The blue/grey
  static const Color textMuted = Color(0xFF838482);
}

// -----------------------------------------------------------------------------
// 2. STATE MANAGEMENT (RIVERPOD)
// -----------------------------------------------------------------------------

@immutable
class TimerState {
  final int remainingSeconds;
  final int totalSeconds;
  final int elapsedSeconds;
  final bool isPaused;
  final bool isHyperfocus;

  const TimerState({
    this.remainingSeconds = 1445, // 24:05 start
    this.totalSeconds = 1800, // 30m goal
    this.elapsedSeconds = 300, // 5m elapsed
    this.isPaused = false,
    this.isHyperfocus = true,
  });

  TimerState copyWith({
    int? remainingSeconds,
    int? totalSeconds,
    int? elapsedSeconds,
    bool? isPaused,
    bool? isHyperfocus,
  }) {
    return TimerState(
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      isPaused: isPaused ?? this.isPaused,
      isHyperfocus: isHyperfocus ?? this.isHyperfocus,
    );
  }
}

class TimerNotifier extends StateNotifier<TimerState> {
  Timer? _ticker;

  TimerNotifier() : super(const TimerState()) {
    _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!state.isPaused && state.remainingSeconds > 0) {
        state = state.copyWith(
          remainingSeconds: state.remainingSeconds - 1,
          elapsedSeconds: state.elapsedSeconds + 1,
        );
      }
    });
  }

  void togglePause() {
    state = state.copyWith(isPaused: !state.isPaused);
  }

  void addFiveMinutes() {
    state = state.copyWith(
      remainingSeconds: state.remainingSeconds + 300,
      totalSeconds: state.totalSeconds + 300,
    );
  }

  void completeSession() {
    state = state.copyWith(remainingSeconds: 0, isPaused: true);
    _ticker?.cancel();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

// Providers
final timerProvider = StateNotifierProvider<TimerNotifier, TimerState>((ref) {
  return TimerNotifier();
});

final progressProvider = Provider<double>((ref) {
  final state = ref.watch(timerProvider);
  if (state.totalSeconds == 0) return 0;
  // Calculate progress inversely (or directly based on elapsed)
  // Logic: how much of the ring is filled? usually elapsed / total
  return state.elapsedSeconds / state.totalSeconds;
});

final timeStringProvider = Provider<String>((ref) {
  final seconds = ref.watch(timerProvider).remainingSeconds;
  final m = (seconds / 60).floor().toString().padLeft(2, '0');
  final s = (seconds % 60).floor().toString().padLeft(2, '0');
  return "$m:$s";
});

// -----------------------------------------------------------------------------
// 3. UI SCREEN
// -----------------------------------------------------------------------------

class FocusSessionScreen extends ConsumerWidget {
  const FocusSessionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We use a Stack to layer the ambient background blobs behind the content
    return const Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        children: [
          // -- Background Ambient Glows --
          Positioned(
            top: -100,
            left: -80,
            child: _AmbientBlob(
              color: AppTheme.primary,
              size: 400,
              opacity: 0.2,
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: _AmbientBlob(
              color: AppTheme.alertAccent,
              size: 300,
              opacity: 0.15,
            ),
          ),

          // -- Main Foreground Content --
          SafeArea(
            child: Column(
              children: [
                _HeaderNav(),
                SizedBox(height: 10),
                _TaskTitleSection(),
                SizedBox(height: 30),
                _TimerSection(),
                SizedBox(height: 30),

                // Metrics Grid
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(child: _RealityCheckCard()),
                      SizedBox(width: 16),
                      Expanded(child: _PaceCard()),
                    ],
                  ),
                ),

                Spacer(),

                // Action Buttons
                _ActionControls(),
                SizedBox(height: 24),

                // Bottom Peek Panel
                _BottomLogPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 4. SUB-WIDGETS
// -----------------------------------------------------------------------------

class _HeaderNav extends StatelessWidget {
  const _HeaderNav();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new,
                size: 20, color: Colors.white70),
          ),
          Text(
            "Focus Session",
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          _GlassButton(
            width: 44,
            height: 44,
            onTap: () {},
            child: const Icon(Icons.settings, color: Colors.white70, size: 22),
          ),
        ],
      ),
    );
  }
}

class _TaskTitleSection extends StatelessWidget {
  const _TaskTitleSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            "Drafting Project Proposal",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              height: 1.2,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: AppTheme.safeAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: AppTheme.safeAccent.withValues(alpha: 0.6),
                        blurRadius: 6)
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "DEEP WORK PHASE",
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimerSection extends ConsumerWidget {
  const _TimerSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeStr = ref.watch(timeStringProvider);
    final progress = ref.watch(progressProvider);
    final isHyperfocus = ref.watch(timerProvider.select((s) => s.isHyperfocus));

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // The Glass Circle Background
        Container(
          width: 300,
          height: 300,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.02),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 40,
                  offset: const Offset(0, 10))
            ],
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),

        // Custom Paint Ring
        SizedBox(
          width: 280,
          height: 280,
          child: CustomPaint(
            painter: _RingPainter(progress: progress),
          ),
        ),

        // Text Content
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              timeStr,
              style: GoogleFonts.inter(
                fontSize: 64,
                fontWeight: FontWeight.w300,
                color: Colors.white,
                letterSpacing: -2.0,
                height: 1.0,
                fontFeatures: [const FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Est: 30m",
                    style:
                        GoogleFonts.inter(fontSize: 13, color: Colors.white54)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Container(
                      width: 3,
                      height: 3,
                      decoration: const BoxDecoration(
                          color: Colors.white24, shape: BoxShape.circle)),
                ),
                Text("Elapsed: 5m",
                    style:
                        GoogleFonts.inter(fontSize: 13, color: Colors.white54)),
              ],
            )
          ],
        ),

        // Hyperfocus Badge (Floating at bottom)
        if (isHyperfocus)
          Positioned(
            bottom: -16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                    color: AppTheme.safeAccent.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt, size: 16, color: AppTheme.safeAccent),
                  const SizedBox(width: 6),
                  Text(
                    "Hyperfocus Detected",
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.safeAccent,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _RealityCheckCard extends StatelessWidget {
  const _RealityCheckCard();

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("REALITY CHECK",
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMuted)),
              const Icon(Icons.schedule, size: 16, color: Colors.white30),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text("2:45",
                      style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const SizedBox(width: 4),
                  Text("PM",
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white38)),
                ],
              ),
              const SizedBox(height: 2),
              Text("Next meeting in 15m",
                  style:
                      GoogleFonts.inter(fontSize: 11, color: Colors.white38)),
            ],
          )
        ],
      ),
    );
  }
}

class _PaceCard extends StatelessWidget {
  const _PaceCard();

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("PACE",
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMuted)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.safeAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: AppTheme.safeAccent.withValues(alpha: 0.2)),
                ),
                child: Text("Steady",
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.safeAccent)),
              ),
            ],
          ),
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Planned",
                      style: GoogleFonts.inter(
                          fontSize: 10, color: Colors.white38)),
                  Text("Actual",
                      style: GoogleFonts.inter(
                          fontSize: 10, color: Colors.white38)),
                ],
              ),
              const SizedBox(height: 6),
              // Custom Bar
              Stack(
                children: [
                  Container(
                    height: 6,
                    width: double.infinity,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(3)),
                  ),
                  Container(
                    height: 6,
                    width: 70, // Dynamic in real app
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: const LinearGradient(
                          colors: [AppTheme.safeAccent, Color(0xFFD69E85)]),
                      boxShadow: [
                        BoxShadow(
                            color: AppTheme.safeAccent.withValues(alpha: 0.4),
                            blurRadius: 6)
                      ],
                    ),
                  ),
                  Positioned(
                    left: 60,
                    child:
                        Container(width: 2, height: 6, color: Colors.white54),
                  )
                ],
              )
            ],
          )
        ],
      ),
    );
  }
}

class _ActionControls extends ConsumerWidget {
  const _ActionControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(timerProvider.notifier);
    final isPaused = ref.watch(timerProvider.select((s) => s.isPaused));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            // +5m Button
            Expanded(
              flex: 2,
              child: _GlassButton(
                onTap: notifier.addFiveMinutes,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_circle_outline_rounded,
                        color: Colors.white70, size: 22),
                    const SizedBox(height: 2),
                    Text("+5m",
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white54)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Complete Button
            Expanded(
              flex: 5,
              child: GestureDetector(
                onTap: notifier.completeSession,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppTheme.safeAccent.withValues(alpha: 0.1)),
                    gradient: const LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [AppTheme.primary, AppTheme.primaryHover],
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5))
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Complete",
                          style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      const SizedBox(width: 8),
                      const Icon(Icons.check_rounded,
                          color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Pause Button
            Expanded(
              flex: 2,
              child: _GlassButton(
                onTap: notifier.togglePause,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                        isPaused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                        color: Colors.white70,
                        size: 22),
                    const SizedBox(height: 2),
                    Text(isPaused ? "Resume" : "Pause",
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white54)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomLogPanel extends StatelessWidget {
  const _BottomLogPanel();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
          ),
          child: Column(
            children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("PREVIOUS SEGMENT",
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: Colors.white38)),
                  Text("View Log",
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.safeAccent)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: const Icon(Icons.mail_outline_rounded,
                        color: Colors.white70, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Email Triage",
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                      Text("Completed in 25m",
                          style: GoogleFonts.inter(
                              fontSize: 12, color: AppTheme.textMuted)),
                    ],
                  ),
                  const Spacer(),
                  Text("-35m ago",
                      style: GoogleFonts.inter(
                          fontSize: 12, color: Colors.white24)),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 5. HELPER CLASSES & PAINTERS
// -----------------------------------------------------------------------------

class _RingPainter extends CustomPainter {
  final double progress;
  _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 8;

    // Background Arc
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, bgPaint);

    // Active Arc
    final paint = Paint()
      ..color = AppTheme.safeAccent
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Shadow/Glow for Active Arc
    final glowPaint = Paint()
      ..color = AppTheme.safeAccent
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle,
        sweepAngle, false, glowPaint);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle,
        sweepAngle, false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.05),
            Colors.white.withValues(alpha: 0.02)
          ],
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final double? width;
  final double? height;

  const _GlassButton(
      {required this.child, required this.onTap, this.width, this.height});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

class _AmbientBlob extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;
  const _AmbientBlob(
      {required this.color, required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0)
          ],
        ),
      ),
    );
  }
}
