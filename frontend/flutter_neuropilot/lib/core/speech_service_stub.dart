import 'dart:async';
import 'speech_service.dart';

/// Stub implementation of [SpeechService].
///
/// This implementation is used on platforms where speech recognition is not supported
/// or when conditional imports fall back to this stub (e.g., during testing).
///
/// Implementation Details:
/// - All methods are no-ops or return default "empty" values.
/// - [supported] always returns false.
///
/// Design Decisions:
/// - Used to prevent runtime crashes on unsupported platforms by providing a valid, albeit non-functional, object.
/// - Keeps the main code clean by avoiding null checks for the service itself.
class _StubSpeech implements SpeechService {
  final _partialCtl = StreamController<String>.broadcast();
  final _levelCtl = StreamController<double>.broadcast();

  @override
  bool get supported => false;

  @override
  Future<String?> startOnce() async => null;

  @override
  Future<void> stop() async {}

  @override
  Stream<String> get partialUpdates => _partialCtl.stream;

  @override
  Stream<double> get levelUpdates => _levelCtl.stream;
}

/// Factory function to create the stub speech service.
SpeechService createSpeechServiceImpl() => _StubSpeech();
