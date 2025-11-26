import 'package:flutter/material.dart';

/// A component to display user avatars or initials.
///
/// Implementation Details:
/// - Shows network image if [imageUrl] is provided.
/// - Fallback to initials derived from [name] if image is missing.
/// - Uses [ClipRRect] for circular masking.
///
/// Design Decisions:
/// - Generates a background color based on theme primary color with opacity.
/// - Uses a default '?' if name is missing or empty.
///
/// Behavioral Specifications:
/// - Calculates initials (First Last or just First).
/// - Handles loading/error states implicitly via standard Image widget behavior.
class NpAvatar extends StatelessWidget {
  final String? name;
  final String? imageUrl;
  final double size;
  const NpAvatar({super.key, this.name, this.imageUrl, this.size = 40});

  String _initials(String? n) {
    if (n == null || n.trim().isEmpty) return '?';
    final parts = n.trim().split(RegExp(r"\s+"));
    final first = parts.isNotEmpty ? parts.first[0] : '';
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.primary.withValues(alpha: 0.15);
    final fg = Theme.of(context).colorScheme.onSurface;
    final radius = BorderRadius.circular(size / 2);
    final child = imageUrl != null
        ? ClipRRect(
            borderRadius: radius,
            child: Image.network(
              imageUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: radius,
                  ),
                  alignment: Alignment.center,
                  child: Text(_initials(name),
                      style: TextStyle(
                          fontSize: size * 0.4,
                          color: fg,
                          fontWeight: FontWeight.w600)),
                );
              },
            ))
        : Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: radius,
            ),
            alignment: Alignment.center,
            child: Text(_initials(name),
                style: TextStyle(
                    fontSize: size * 0.4,
                    color: fg,
                    fontWeight: FontWeight.w600)),
          );
    return Semantics(
        label: name ?? 'Avatar', image: imageUrl != null, child: child);
  }
}
