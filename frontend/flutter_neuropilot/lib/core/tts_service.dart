import 'tts_service_stub.dart'
    if (dart.library.html) 'tts_service_web.dart'
    if (dart.library.io) 'tts_service_mobile.dart';

abstract class TtsService {
  bool get supported;
  double get volume;
  set volume(double v);
  Future<void> speak(String text);
  Future<void> stop();
  Stream<bool> get speaking;
}

TtsService createTtsService() => createTtsServiceImpl();
