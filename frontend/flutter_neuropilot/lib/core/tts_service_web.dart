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
    final utter = web.SpeechSynthesisUtterance(text);
    utter.volume = _volume;
    utter.rate = 1.0;
    utter.pitch = 1.0;
    utter.onstart = ((_) => _speakingCtl.add(true)).toJS;
    utter.onend = ((_) => _speakingCtl.add(false)).toJS;
    utter.onerror = ((_) => _speakingCtl.add(false)).toJS;
    _speakingCtl.add(true);
    synth.speak(utter);
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
