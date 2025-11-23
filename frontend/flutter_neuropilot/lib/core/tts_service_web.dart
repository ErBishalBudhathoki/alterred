// Only compiled on web
import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'tts_service.dart';

class _WebTts implements TtsService {
  final _speakingCtl = StreamController<bool>.broadcast();
  double _volume = 1.0;

  @override
  bool get supported => true;

  @override
  double get volume => _volume;

  @override
  set volume(double v) {
    _volume = v.clamp(0.0, 1.0);
  }

  @override
  Future<void> speak(String text) async {
    final synth = web.window.speechSynthesis;
    final utterance = web.SpeechSynthesisUtterance(text);
    utterance.volume = _volume;
    utterance.rate = 1.0;
    utterance.pitch = 1.0;
    utterance.onstart = ((web.Event e) {
      _speakingCtl.add(true);
    }).toJS;
    utterance.onend = ((web.Event e) {
      _speakingCtl.add(false);
    }).toJS;
    utterance.onerror = ((web.Event e) {
      _speakingCtl.add(false);
    }).toJS;
    _speakingCtl.add(true);
    synth.speak(utterance);
  }

  @override
  Future<void> stop() async {
    final synth = web.window.speechSynthesis;
    synth.cancel();
    _speakingCtl.add(false);
  }

  @override
  Stream<bool> get speaking => _speakingCtl.stream;
}

TtsService createTtsServiceImpl() => _WebTts();
