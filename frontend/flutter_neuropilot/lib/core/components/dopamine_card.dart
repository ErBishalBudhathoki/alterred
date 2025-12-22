import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart'; // Keeping for list entrance if needed, but primarily using manual as requested

// Colors from screen.dart
class AppColors {
  static const Color backgroundDark = Color(0xFF0F0505);
  static const Color primary = Color(0xFFE1B58E); // Warm beige/gold
  static const Color accentCool = Color(0xFF6C7494); // Slate blue

  // ignore: unused_field
  static Color glassBorder = Colors.white.withValues(alpha: 0.1);
  // ignore: unused_field
  static Color glassBg = Colors.white.withValues(alpha: 0.05);
}

class DopamineCard extends StatefulWidget {
  final String content; // The markdown content from the agent
  final ValueChanged<String>? onOptionSelected;
  final VoidCallback? onClose;

  const DopamineCard(
      {super.key, required this.content, this.onOptionSelected, this.onClose});

  @override
  State<DopamineCard> createState() => _DopamineCardState();
}

class _DopamineCardState extends State<DopamineCard> {
  int? _selectedIndex;

  List<String> _parseItems(String content) {
    // Basic parsing of markdown list items
    final List<String> items = [];
    final lines = content.split('\n');
    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('**') && trimmed.contains(':**')) {
        // Handle "**Title:** Description" format
        items.add(trimmed.replaceAll('**', ''));
      } else if (trimmed.isNotEmpty &&
          !trimmed.startsWith('Try these') &&
          !trimmed.startsWith('✨')) {
        items.add(trimmed);
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final items = _parseItems(widget.content);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "Suggested breakdown" hint styled container
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
            "Here are some dopamine hacks for you.",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 16,
              fontFamily: 'Plus Jakarta Sans',
            ),
          ),
        ),

        // Main Glass Card
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.15),
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
                      color: AppColors.primary.withValues(alpha: 0.3)),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.accentCool.withValues(alpha: 0.1),
                      AppColors.primary.withValues(alpha: 0.05),
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
                                AppColors.primary.withValues(alpha: 0.2),
                                AppColors.accentCool.withValues(alpha: 0.2),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: const Icon(
                            Icons
                                .auto_awesome, // Changed from checklist to auto_awesome for Dopamine
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Dpmn Hacks", // Shortened for style
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontFamily: 'Plus Jakarta Sans',
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const PulseDot(),
                                  const SizedBox(width: 8),
                                  Text(
                                    "INSTANT BOOST",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          Colors.white.withValues(alpha: 0.4),
                                      letterSpacing: 1.2,
                                      fontFamily: 'Plus Jakarta Sans',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (widget.onClose != null)
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: widget.onClose,
                          ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // List Items
                    ...items.asMap().entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedIndex = entry.key;
                            });
                            widget.onOptionSelected?.call(entry.value);
                          },
                          child: _TaskItem(
                            text: entry.value,
                            isSelected: _selectedIndex == entry.key,
                          ),
                        ),
                      ).animate().fadeIn(delay: (entry.key * 100).ms).slideX();
                    }),
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
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _TaskItem extends StatelessWidget {
  final String text;
  final bool isSelected;

  const _TaskItem({
    required this.text,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Split title and description if possible
    String title = text;
    String description = "";
    if (text.contains(':')) {
      final parts = text.split(':');
      title = parts[0].trim();
      description = parts.sublist(1).join(':').trim();
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppColors.primary : null,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : Colors.white.withValues(alpha: 0.2),
                    width: isSelected ? 0 : 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        size: 16,
                        color: AppColors.backgroundDark,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : Colors.white
                            .withValues(alpha: 0.9), // Slightly brighter
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    fontFamily: 'Plus Jakarta Sans',
                  ),
                ),
              ),
            ],
          ),
          if (description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 36.0, top: 4),
              child: Text(
                description,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                  fontFamily: 'Plus Jakarta Sans',
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
