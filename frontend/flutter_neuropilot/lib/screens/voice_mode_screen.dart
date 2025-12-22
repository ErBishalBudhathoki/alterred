import 'dart:ui';
import 'package:flutter/material.dart';

// --- Constants (Colors from CSS) ---
class VoiceAppColors {
  static const Color backgroundDark = Color(0xFF0F0505);
  static const Color primary = Color(0xFFE1B58E); // Warm beige/gold
  static const Color accentCool = Color(0xFF6C7494); // Slate blue
  static const Color backgroundLight = Color(0xFFF8F7F6);

  static Color glassBorder = Colors.white.withValues(alpha: 0.1);
  static Color glassBg = Colors.white.withValues(alpha: 0.05);
}

class VoiceModeScreen extends StatefulWidget {
  final bool isListening;
  final bool isMuted;
  final String agentText;
  final Widget? centerCard;
  final String headerTitle;
  final String headerSubtitle;
  final VoidCallback? onBack;
  final VoidCallback? onMenu;
  final VoidCallback? onMute;
  final VoidCallback? onPause;
  final VoidCallback? onKeyboard;
  final VoidCallback? onAddAnother;
  final VoidCallback? onConfirm;
  final Function(String)? onOptionSelected;

  const VoiceModeScreen({
    super.key,
    this.isListening = false,
    this.isMuted = false,
    this.agentText = "Break down the email task",
    this.centerCard,
    this.headerTitle = "FOCUS COACH",
    this.headerSubtitle = "Voice Dialogue",
    this.onBack,
    this.onMenu,
    this.onMute,
    this.onPause,
    this.onKeyboard,
    this.onAddAnother,
    this.onConfirm,
    this.onOptionSelected,
  });

  @override
  State<VoiceModeScreen> createState() => _VoiceModeScreenState();
}

class _VoiceModeScreenState extends State<VoiceModeScreen>
    with TickerProviderStateMixin {
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();

    // Setup Floating Animation for the Card
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: 0, end: -12).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  Widget _buildAgentContent() {
    final lines = widget.agentText.split('\n');
    final options = <String>[];
    final introBuffer = StringBuffer();
    final optionRegex =
        RegExp(r'^[\*\-\d\.]+\s+(\[[ xX]\]\s+)?(\*\*)?(.+?)(\*\*)?$');

    bool parsingOptions = false;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        if (!parsingOptions) introBuffer.writeln(line);
        continue;
      }

      final match = optionRegex.firstMatch(trimmed);
      if (match != null) {
        parsingOptions = true;
        // Group 3 is the main text content
        String optionText = match.group(3) ?? trimmed;
        // Clean up markdown bold markers if they exist inside the group
        optionText = optionText.replaceAll('**', '').trim();
        options.add(optionText);
      } else {
        if (!parsingOptions) {
          introBuffer.writeln(line);
        } else {
          // If we were parsing options and hit a non-option line,
          // usually implies end of list or multi-line option.
          // For simplicity, we'll append to the last option if it makes sense,
          // or just ignore for now to keep it clean.
          // Here, let's treat it as part of the last option if it's short.
          if (options.isNotEmpty) {
            options[options.length - 1] = "${options.last} $trimmed";
          }
        }
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: FadeInTextSection(
              text: introBuffer.toString().trim(),
              isListening: widget.isListening),
        ),
        if (options.isNotEmpty) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _VoiceOptionsList(
              options: options,
              onSelected: widget.onOptionSelected,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Screen height helper for spacing
    // final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: VoiceAppColors.backgroundDark,
      body: Stack(
        children: [
          // 1. Background Gradients/Blobs
          const Positioned.fill(child: BackgroundGradients()),

          // 2. Bottom Visualizer (Behind content)
          const Positioned.fill(
            child: VisualizerBackgroundEffect(),
          ),

          // 3. Main Foreground Content
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Header
                        CustomHeader(
                          title: widget.headerTitle,
                          subtitle: widget.headerSubtitle,
                          onBack: widget.onBack,
                          onMenu: widget.onMenu,
                        ),

                        // Floating Task Card
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: widget.centerCard != null
                              ? AnimatedBuilder(
                                  animation: _floatAnimation,
                                  builder: (context, child) {
                                    return Transform.translate(
                                      offset: Offset(0, _floatAnimation.value),
                                      child: child,
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20),
                                    child: widget.centerCard,
                                  ),
                                )
                              : AnimatedBuilder(
                                  animation: _floatAnimation,
                                  builder: (context, child) {
                                    return Transform.translate(
                                      offset: Offset(0, _floatAnimation.value),
                                      child: child,
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20),
                                    child: VoiceTaskCard(
                                      onAddAnother: widget.onAddAnother,
                                      onConfirm: widget.onConfirm,
                                    ),
                                  ),
                                ),
                        ),

                        // Bottom Section
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Text Response with Options
                            _buildAgentContent(),

                            const SizedBox(height: 24),

                            // Audio Waveform
                            const SizedBox(
                                height: 48, child: AudioWaveVisualizer()),

                            const SizedBox(height: 32),

                            // Bottom Controls
                            BottomControls(
                              onKeyboard: widget.onKeyboard,
                              onMute: widget.onMute,
                              onPause: widget.onPause,
                              isListening: widget.isListening,
                              isMuted: widget.isMuted,
                            ),

                            const SizedBox(height: 20),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// --- BACKGROUND COMPONENTS ---
// ---------------------------------------------------------------------------

class BackgroundGradients extends StatelessWidget {
  const BackgroundGradients({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base Layer (Full Screen Fill)
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  VoiceAppColors.backgroundDark,
                  VoiceAppColors.backgroundDark.withValues(alpha: 0.8),
                  VoiceAppColors.primary.withValues(alpha: 0.05),
                ],
              ),
            ),
          ),
        ),
        // Top Blob (Primary Gold)
        Positioned(
          top: -160,
          left: MediaQuery.of(context).size.width / 2 - 400,
          child: Container(
            width: 800,
            height: 600,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: VoiceAppColors.primary.withValues(alpha: 0.05),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
              child: const SizedBox(),
            ),
          ),
        ),
        // Bottom Blob (Accent Blue)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 600,
          child: Container(
            decoration: BoxDecoration(
              color: VoiceAppColors.accentCool.withValues(alpha: 0.05),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
              child: const SizedBox(),
            ),
          ),
        ),
      ],
    );
  }
}

class _VoiceOptionsList extends StatelessWidget {
  final List<String> options;
  final Function(String)? onSelected;

  const _VoiceOptionsList({
    required this.options,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: options.map((option) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _VoiceOptionCard(
            text: option,
            onTap: () => onSelected?.call(option),
          ),
        );
      }).toList(),
    );
  }
}

class _VoiceOptionCard extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _VoiceOptionCard({
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: VoiceAppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: VoiceAppColors.primary,
                size: 16,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VisualizerBackgroundEffect extends StatefulWidget {
  const VisualizerBackgroundEffect({super.key});

  @override
  State<VisualizerBackgroundEffect> createState() =>
      _VisualizerBackgroundEffectState();
}

class _VisualizerBackgroundEffectState extends State<VisualizerBackgroundEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _breatheController;

  @override
  void initState() {
    super.initState();
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breatheController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        // The breathing orb
        AnimatedBuilder(
          animation: _breatheController,
          builder: (context, child) {
            final scale = 1.0 + (_breatheController.value * 0.2); // 1.0 to 1.2
            final opacity =
                0.5 + (_breatheController.value * 0.3); // 0.5 to 0.8

            return Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 300,
                  height: 300,
                  margin: const EdgeInsets.only(bottom: 40),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        VoiceAppColors.primary.withValues(alpha: 0.4),
                        VoiceAppColors.accentCool.withValues(alpha: 0.2),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.6, 0.8],
                    ),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                    child: Container(),
                  ),
                ),
              ),
            );
          },
        ),
        // Ripples
        const Positioned(bottom: 160, child: RippleEffect(delay: 0)),
        const Positioned(bottom: 160, child: RippleEffect(delay: 1000)),
        const Positioned(bottom: 160, child: RippleEffect(delay: 2000)),

        // Gradient Mask for "Immersive" look
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.0), // Transparent at bottom
                  VoiceAppColors.backgroundDark
                      .withValues(alpha: 0.0), // Transparent at top
                ],
                stops: const [
                  0.0,
                  1.0,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// --- ANIMATIONS: RIPPLES & WAVES ---
// ---------------------------------------------------------------------------

class RippleEffect extends StatefulWidget {
  final int delay;
  const RippleEffect({super.key, required this.delay});

  @override
  State<RippleEffect> createState() => _RippleEffectState();
}

class _RippleEffectState extends State<RippleEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final size = 100.0 + (500.0 * _controller.value); // 100px -> 600px
        // final opacity = (1.0 - _controller.value) * 0.6;
        final borderColor = Color.lerp(
          VoiceAppColors.primary.withValues(alpha: 0.4),
          VoiceAppColors.accentCool.withValues(alpha: 0.1),
          _controller.value,
        );

        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: borderColor ?? Colors.transparent,
              width: 2 * (1 - _controller.value),
            ),
          ),
        );
      },
    );
  }
}

class AudioWaveVisualizer extends StatelessWidget {
  const AudioWaveVisualizer({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _WaveBar(delay: 0),
        SizedBox(width: 6),
        _WaveBar(delay: 100),
        SizedBox(width: 6),
        _WaveBar(delay: 200),
        SizedBox(width: 6),
        _WaveBar(delay: 300),
        SizedBox(width: 6),
        _WaveBar(delay: 400),
      ],
    );
  }
}

class _WaveBar extends StatefulWidget {
  final int delay;
  const _WaveBar({required this.delay});

  @override
  State<_WaveBar> createState() => _WaveBarState();
}

class _WaveBarState extends State<_WaveBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // scaleY from 1.0 down to 0.4
        final scale = 1.0 - (_controller.value * 0.6);
        final opacity = 0.8 - (_controller.value * 0.4);

        return Container(
          width: 6,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.5),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          transform: Matrix4.diagonal3Values(1.0, scale, 1.0),
          transformAlignment: Alignment.center,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// --- UI COMPONENTS ---
// ---------------------------------------------------------------------------

class CustomHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onBack;
  final VoidCallback? onMenu;

  const CustomHeader({
    super.key,
    this.title = "FOCUS COACH",
    this.subtitle = "Voice Dialogue",
    this.onBack,
    this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _GlassCircleButton(icon: Icons.arrow_back, onTap: onBack),
          Column(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: VoiceAppColors.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          _GlassCircleButton(icon: Icons.more_vert, onTap: onMenu),
        ],
      ),
    );
  }
}

class _GlassCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _GlassCircleButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Center(
              child: Icon(icon,
                  color: Colors.white.withValues(alpha: 0.7), size: 24),
            ),
          ),
        ),
      ),
    );
  }
}

class VoiceTaskCard extends StatelessWidget {
  final VoidCallback? onAddAnother;
  final VoidCallback? onConfirm;

  const VoiceTaskCard({super.key, this.onAddAnother, this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "Suggested breakdown" hint
        Container(
          margin: const EdgeInsets.only(bottom: 24, left: 4),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
              topLeft: Radius.circular(4),
              bottomLeft: Radius.circular(4),
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          child: Text(
            "Here is a suggested breakdown.",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 16,
            ),
          ),
        ),

        // Main Glass Card
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: VoiceAppColors.primary.withValues(alpha: 0.15),
                blurRadius: 40,
                spreadRadius: 0,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1919).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: VoiceAppColors.primary.withValues(alpha: 0.3)),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      VoiceAppColors.accentCool.withValues(alpha: 0.1),
                      VoiceAppColors.primary.withValues(alpha: 0.05),
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    // Card Header
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                VoiceAppColors.primary.withValues(alpha: 0.2),
                                VoiceAppColors.accentCool
                                    .withValues(alpha: 0.2),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: const Icon(
                            Icons.checklist,
                            color: VoiceAppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Task Breakdown",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const PulseDot(),
                                const SizedBox(width: 8),
                                Text(
                                  "DRAFTING EMAIL",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.4),
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // List Items
                    const _TaskItem(
                      text: "Draft email subject",
                      isSelected: true,
                      showAudioIcon: true,
                    ),
                    const SizedBox(height: 12),
                    const _TaskItem(
                      text: "Write introduction",
                      isSelected: false,
                    ),
                    const SizedBox(height: 12),
                    const _TaskItem(
                      text: "Find relevant data points",
                      isSelected: false,
                    ),

                    const SizedBox(height: 24),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: onAddAnother,
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.05),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add,
                                    size: 18,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Add Another",
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.9),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: onConfirm,
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    VoiceAppColors.primary,
                                    Color(0xFFD4A076)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: VoiceAppColors.primary
                                        .withValues(alpha: 0.3),
                                    blurRadius: 20,
                                    spreadRadius: 0,
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Confirm Selection",
                                    style: TextStyle(
                                      color: VoiceAppColors.backgroundDark,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13, // Slightly smaller to fit
                                    ),
                                  ),
                                  SizedBox(width: 4), // Reduced spacing
                                  Icon(
                                    Icons.arrow_forward,
                                    size: 18,
                                    color: VoiceAppColors.backgroundDark,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class PulseDot extends StatefulWidget {
  const PulseDot({super.key});

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: VoiceAppColors.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _TaskItem extends StatelessWidget {
  final String text;
  final bool isSelected;
  final bool showAudioIcon;

  const _TaskItem({
    required this.text,
    required this.isSelected,
    this.showAudioIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isSelected
            ? VoiceAppColors.primary.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? VoiceAppColors.primary.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.05),
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: VoiceAppColors.primary.withValues(alpha: 0.1),
                  blurRadius: 15,
                ),
              ]
            : [],
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? VoiceAppColors.primary : null,
              border: Border.all(
                color: isSelected
                    ? VoiceAppColors.primary
                    : Colors.white.withValues(alpha: 0.2),
                width: isSelected ? 0 : 2,
              ),
            ),
            child: isSelected
                ? const Icon(
                    Icons.check,
                    size: 16,
                    color: VoiceAppColors.backgroundDark,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          if (showAudioIcon)
            Icon(
              Icons.graphic_eq,
              color: VoiceAppColors.primary.withValues(alpha: 0.8),
              size: 18,
            ),
        ],
      ),
    );
  }
}

class FadeInTextSection extends StatefulWidget {
  final String text;
  final bool isListening;

  const FadeInTextSection(
      {super.key, required this.text, required this.isListening});

  @override
  State<FadeInTextSection> createState() => _FadeInTextSectionState();
}

class _FadeInTextSectionState extends State<FadeInTextSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _opacityAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Column(
          children: [
            Text(
              widget.text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w300,
                color: Colors.white.withValues(alpha: 0.9),
                shadows: [
                  Shadow(
                      color: Colors.white.withValues(alpha: 0.3),
                      blurRadius: 20),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (widget.isListening) const PulseText(),
          ],
        ),
      ),
    );
  }
}

class PulseText extends StatefulWidget {
  const PulseText({super.key});

  @override
  State<PulseText> createState() => _PulseTextState();
}

class _PulseTextState extends State<PulseText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.5, end: 1.0).animate(_controller),
      child: Text(
        "LISTENING...",
        style: TextStyle(
          color: VoiceAppColors.primary.withValues(alpha: 0.6),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 2.0,
        ),
      ),
    );
  }
}

class BottomControls extends StatelessWidget {
  final VoidCallback? onKeyboard;
  final VoidCallback? onMute;
  final VoidCallback? onPause;
  final bool isListening;
  final bool isMuted;

  const BottomControls({
    super.key,
    this.onKeyboard,
    this.onMute,
    this.onPause,
    this.isListening = false,
    this.isMuted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 20, spreadRadius: 5),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(50),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Keyboard Button
              IconButton(
                onPressed: onKeyboard,
                icon: Icon(
                  Icons.keyboard,
                  color: Colors.white.withValues(alpha: 0.6),
                  size: 26,
                ),
              ),

              // Mute Button (Large Pill)
              Expanded(
                child: GestureDetector(
                  onTap: onMute,
                  child: Container(
                    height: 56,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          VoiceAppColors.accentCool.withValues(alpha: 0.2),
                          Colors.white.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isMuted ? Icons.mic_off : Icons.mic,
                            color: VoiceAppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isMuted ? "Unmute" : "Mute",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Pause Button
              IconButton(
                onPressed: onPause,
                icon: Icon(
                  Icons.pause,
                  color: Colors.white.withValues(alpha: 0.6),
                  size: 26,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
