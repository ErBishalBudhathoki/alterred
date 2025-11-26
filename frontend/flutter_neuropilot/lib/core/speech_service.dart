import 'speech_service_stub.dart'
    if (dart.library.html) 'speech_service_web.dart'
    if (dart.library.io) 'speech_service_mobile.dart';

/// Speech Service Interface
///
/// Defines the contract for speech recognition across different platforms.
///
/// Implementation Details:
/// - Abstract base class defining common methods for speech recognition.
/// - Uses conditional imports to load the correct implementation (Mobile, Web, Stub).
///
/// Design Decisions:
/// - `startOnce` returns a `Future<String?>` for the final transcript, simplifying one-shot usage.
/// - `partialUpdates` stream allows for real-time feedback during dictation.
/// - `levelUpdates` stream enables visual feedback (e.g., audio visualizers).
///
/// Behavioral Specifications:
/// - [supported]: Returns true if speech recognition is available on the current platform.
/// - [startOnce]: Initiates a listening session and returns the final text result.
/// - [stop]: Manually terminates the listening session.
abstract class SpeechService {
  /// Whether speech recognition is supported on this device/platform.
  bool get supported;

  /// Starts a single listening session.
  ///
  /// Returns the final recognized text, or null if no speech was detected or an error occurred.
  Future<String?> startOnce();

  /// Stops the current listening session immediately.
  Future<void> stop();

  /// Stream of partial transcription updates during a session.
  Stream<String> get partialUpdates;

  /// Stream of audio level updates (0.0 to 1.0) for visualization.
  Stream<double> get levelUpdates;
}

SpeechService createSpeechService() => createSpeechServiceImpl();
