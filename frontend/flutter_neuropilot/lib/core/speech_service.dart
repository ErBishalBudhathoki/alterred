import 'speech_service_stub.dart'
    if (dart.library.html) 'speech_service_web.dart'
    if (dart.library.io) 'speech_service_mobile.dart';

abstract class SpeechService {
  bool get supported;
  Future<String?> startOnce();
  Future<void> stop();
  Stream<String> get partialUpdates;
  Stream<double> get levelUpdates;
}

SpeechService createSpeechService() => createSpeechServiceImpl();
