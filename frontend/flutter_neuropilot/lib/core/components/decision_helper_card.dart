import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../design_tokens.dart';
import 'agent_widgets.dart';
import 'np_button.dart';

class DecisionHelperCard extends StatefulWidget {
  final List<String> options;
  final Function(String) onOptionSelected;
  final Function(String) onSelectionChanged;
  final Future<void> Function() onReevaluate;
  final String? initialSelection;

  const DecisionHelperCard({
    super.key,
    required this.options,
    required this.onOptionSelected,
    required this.onSelectionChanged,
    required this.onReevaluate,
    this.initialSelection,
  });

  @override
  State<DecisionHelperCard> createState() => _DecisionHelperCardState();
}

class _DecisionHelperCardState extends State<DecisionHelperCard> {
  String? _selectedOption;
  bool _isReevaluating = false;

  @override
  void initState() {
    super.initState();
    _selectedOption = widget.initialSelection;
  }

  void _handleSelection(String option) {
    setState(() {
      _selectedOption = option;
    });
    widget.onSelectionChanged(option);
  }

  Future<void> _handleReevaluate() async {
    setState(() {
      _isReevaluating = true;
    });
    try {
      await widget.onReevaluate();
    } catch (e) {
      debugPrint('Re-evaluation error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isReevaluating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use dark theme colors matching other cards
    final bgColor = const Color(0xFF0F0505).withValues(alpha: 0.85);
    const accentColor = Color(0xFFE2B58D);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: DesignTokens.spacingMd),
      padding: const EdgeInsets.all(DesignTokens.spacingMd),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.2),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(DesignTokens.spacingXs),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                ),
                child: const Icon(
                  Icons.help_outline,
                  size: 16,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: DesignTokens.spacingSm),
              Text(
                'Decision Helper',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spacingMd),
          if (widget.options.isNotEmpty) ...[
            Text(
              'Here are your top options:',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: DesignTokens.spacingSm),
            ...widget.options.asMap().entries.map((e) {
              final isTopPick = e.key == 0;
              final isSelected = _selectedOption == e.value;

              return Padding(
                padding: const EdgeInsets.only(bottom: DesignTokens.spacingSm),
                child: TaskItem(
                  title: e.value,
                  isDone: isSelected,
                  isActive: isTopPick || isSelected,
                  tag:
                      isSelected ? "SELECTED" : (isTopPick ? "TOP PICK" : null),
                  onTap: () => _handleSelection(e.value),
                ),
              ).animate().fadeIn(delay: (e.key * 100).ms).slideX();
            }),
          ] else
            Text(
              'Would you like me to reduce these options to the top 2?',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          const SizedBox(height: DesignTokens.spacingLg),
          Row(
            children: [
              Expanded(
                child: NpButton(
                  label: widget.options.isNotEmpty
                      ? 'Commit Top 1'
                      : 'Yes, please',
                  type: NpButtonType.primary,
                  onPressed: () {
                    if (widget.options.isNotEmpty) {
                      _handleSelection(widget.options.first);
                    } else {
                      // Trigger reduce action if no options yet (fallback logic handled by parent if needed)
                      widget.onOptionSelected("reduce my options to the top 2");
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spacingSm),
          Row(
            children: [
              Expanded(
                child: NpButton(
                  label: widget.options.isNotEmpty
                      ? 'Re-evaluate with AI'
                      : 'No, show all',
                  type: NpButtonType.secondary,
                  loading: _isReevaluating,
                  onPressed: _isReevaluating ? null : _handleReevaluate,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack);
  }
}
