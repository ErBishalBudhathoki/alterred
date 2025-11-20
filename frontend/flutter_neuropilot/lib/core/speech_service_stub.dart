import 'dart:async';
import 'speech_service.dart';

class _StubSpeech implements SpeechService {
  final _partialCtl = StreamController<String>.broadcast();
  @override
  bool get supported => false;
  @override
  Future<String?> startOnce() async => null;
  @override
  Future<void> stop() async {}
  @override
  Stream<String> get partialUpdates => _partialCtl.stream;
}

SpeechService createSpeechServiceImpl() => _StubSpeech();