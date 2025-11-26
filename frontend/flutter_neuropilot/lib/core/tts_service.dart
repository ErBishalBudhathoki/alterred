import 'tts_service_stub.dart'
    if (dart.library.js_interop) 'tts_service_web.dart'
    if (dart.library.io) 'tts_service_mobile.dart';

/// Text-to-Speech Service Interface
///
/// Defines the contract for speech synthesis across different platforms.
///
/// Implementation Details:
/// - Abstract base class defining common methods for text-to-speech.
/// - Uses conditional imports to load the correct implementation (Mobile, Web, Stub).
///
/// Design Decisions:
/// - `speak` is asynchronous to allow awaiting completion (where supported).
/// - `speaking` stream provides real-time status for UI updates (e.g., animating an avatar).
///
/// Behavioral Specifications:
/// - [supported]: Returns true if TTS is available on the current platform.
/// - [speak]: Synthesizes the provided text into audio.
/// - [stop]: Interrupts any current speech.
abstract class TtsService {
  /// Whether text-to-speech is supported on this device/platform.
  bool get supported;

  /// The current volume level (0.0 to 1.0).
  double get volume;

  /// Sets the volume level (clamped between 0.0 and 1.0).
  set volume(double v);

  /// Speaks the provided text.
  ///
  /// Returns a Future that completes when speech starts (or finishes, depending on platform implementation).
  Future<void> speak(String text);

  /// Stops any currently playing speech.
  Future<void> stop();

  /// Stream of boolean values indicating whether speech is currently active.
  Stream<bool> get speaking;
}

TtsService createTtsService() => createTtsServiceImpl();
