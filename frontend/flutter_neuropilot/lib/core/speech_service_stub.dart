import 'speech_service.dart';

class _StubSpeech implements SpeechService {
  @override
  bool get supported => false;
  @override
  Future<String?> startOnce() async => null;
  @override
  Future<void> stop() async {}
}

SpeechService createSpeechServiceImpl() => _StubSpeech();