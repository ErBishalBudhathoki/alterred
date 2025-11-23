import 'dart:async';
import 'speech_service.dart';

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

SpeechService createSpeechServiceImpl() => _StubSpeech();
