import 'dart:async';
import 'tts_service.dart';

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

TtsService createTtsServiceImpl() => _StubTts();
