import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../design_tokens.dart';
import 'np_button.dart';

class ReevaluationCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final Function(String, String) onAction; // actionType, value

  const ReevaluationCard({
    super.key,
    required this.data,
    required this.onAction,
  });

  @override
  State<ReevaluationCard> createState() => _ReevaluationCardState();
}

class _ReevaluationCardState extends State<ReevaluationCard> {
  String? _expandedOption;
  bool _showFullPattern = true;

  @override
  Widget build(BuildContext context) {
    final analysis = widget.data['analysis'] as List<dynamic>? ?? [];
    final patternNote = widget.data['pattern_note'] as String? ?? '';
    final recommendation = widget.data['recommendation'] as String? ?? '';
    final rationale = widget.data['rationale'] as String? ?? '';

    // Use dark theme colors matching other cards
    final bgColor = const Color(0xFF0F0505).withValues(alpha: 0.95);
    const accentColor = Color(0xFFE2B58D);
    const successColor = Color(0xFF8DE2B5);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: DesignTokens.spacingMd),
      padding: const EdgeInsets.all(DesignTokens.spacingMd),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(DesignTokens.spacingXs),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                ),
                child: const Icon(
                  Icons.analytics_outlined,
                  size: 16,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: DesignTokens.spacingSm),
              Text(
                'Deep Analysis',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spacingMd),

          // Recommendation Hero
          if (recommendation.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(DesignTokens.spacingMd),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    successColor.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                border: Border.all(color: successColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RECOMMENDATION',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: successColor,
                    ),
                  ),
                  const SizedBox(height: DesignTokens.spacingXs),
                  Text(
                    recommendation,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (rationale.isNotEmpty) ...[
                    const SizedBox(height: DesignTokens.spacingSm),
                    Text(
                      rationale,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                  const SizedBox(height: DesignTokens.spacingMd),
                  Row(
                    children: [
                      Expanded(
                        child: NpButton(
                          label: 'Schedule This',
                          type: NpButtonType.primary,
                          onPressed: () =>
                              widget.onAction('schedule', recommendation),
                        ),
                      ),
                      const SizedBox(width: DesignTokens.spacingSm),
                      Expanded(
                        child: NpButton(
                          label: 'Save as Note',
                          type: NpButtonType.secondary,
                          onPressed: () => widget.onAction('note',
                              'Recommendation: $recommendation\nReason: $rationale'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn().slideY(),
            const SizedBox(height: DesignTokens.spacingLg),
          ],

          // Pattern Note
          if (patternNote.isNotEmpty) ...[
            InkWell(
              onTap: () => setState(() => _showFullPattern = !_showFullPattern),
              child: Container(
                padding: const EdgeInsets.all(DesignTokens.spacingSm),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.psychology,
                            size: 16, color: Colors.white70),
                        const SizedBox(width: DesignTokens.spacingSm),
                        Text(
                          'Pattern Detected',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          _showFullPattern
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 16,
                          color: Colors.white30,
                        ),
                      ],
                    ),
                    if (_showFullPattern) ...[
                      const SizedBox(height: DesignTokens.spacingSm),
                      Text(
                        patternNote,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: DesignTokens.spacingLg),
          ],

          // Options List
          Text(
            'Analysis of Options',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: DesignTokens.spacingSm),
          ...analysis.map((item) {
            final option = item['option'] ?? '';
            final pro = item['pro'] ?? '';
            final con = item['con'] ?? '';
            final isExpanded = _expandedOption == option;

            return AnimatedContainer(
              duration: 300.ms,
              margin: const EdgeInsets.only(bottom: DesignTokens.spacingSm),
              decoration: BoxDecoration(
                color: isExpanded
                    ? accentColor.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                border: Border.all(
                  color: isExpanded
                      ? accentColor.withValues(alpha: 0.3)
                      : Colors.white10,
                ),
              ),
              child: Column(
                children: [
                  ListTile(
                    title: Text(
                      option,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight:
                            isExpanded ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.white30,
                    ),
                    onTap: () {
                      setState(() {
                        _expandedOption = isExpanded ? null : option;
                      });
                    },
                  ),
                  if (isExpanded)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        children: [
                          _buildProConRow(
                              Icons.check_circle_outline, successColor, pro),
                          const SizedBox(height: 8),
                          _buildProConRow(Icons.remove_circle_outline,
                              Colors.redAccent, con),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () =>
                                    widget.onAction('schedule', option),
                                child: const Text('Schedule',
                                    style: TextStyle(color: accentColor)),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack);
  }

  Widget _buildProConRow(IconData icon, Color color, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 13,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
