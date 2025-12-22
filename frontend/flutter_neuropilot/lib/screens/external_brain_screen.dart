import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/components/external_brain/modes/standalone_external_brain.dart';

/// Enhanced External Brain Screen with comprehensive functionality
///
/// Features:
/// - Universal capture system (voice, text, images)
/// - Context restoration for interrupted tasks
/// - A2A (Agent-to-Agent) communication protocol
/// - Appointment guardian with Google Calendar integration
/// - Working memory support tools
/// - Advanced UI animations and effects
///
/// This replaces the basic external brain implementation with a robust,
/// modular system that integrates with chat and voice modes.
class ExternalBrainScreen extends ConsumerWidget {
  const ExternalBrainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const StandaloneExternalBrain();
  }
}
