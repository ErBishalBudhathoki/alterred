import 'dart:async';
import 'tts_service.dart';

/// Stub implementation of [TtsService].
///
/// This implementation is used on platforms where text-to-speech is not supported
/// or when conditional imports fall back to this stub (e.g., during testing).
///
/// Implementation Details:
/// - All methods are no-ops.
/// - [supported] always returns false.
/// - Volume setters are clamped but have no effect.
///
/// Design Decisions:
/// - Allows the app to function without crashing on platforms lacking TTS support.
/// - Provides a consistent interface so consumers don't need platform checks at every call site.
class _StubTts implements TtsService {
  final _speakingCtl = StreamController<bool>.broadcast();
  double _volume = 1.0;

  @override
  bool get supported => false;

  @override
  double get volume => _volume;

  @override
  set volume(double v) => _volume = v.clamp(0.0, 1.0);

  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}

  @override
  Stream<bool> get speaking => _speakingCtl.stream;
}

/// Factory function to create the stub TTS service.
TtsService createTtsServiceImpl() => _StubTts();
