// Only compiled on web
import 'dart:async';
import 'dart:html' as html;
import 'tts_service.dart';

class _WebTts implements TtsService {
  final _speakingCtl = StreamController<bool>.broadcast();
  double _volume = 1.0;

  @override
  bool get supported => html.window.speechSynthesis != null;

  @override
  double get volume => _volume;

  @override
  set volume(double v) {
    _volume = v.clamp(0.0, 1.0);
  }

  @override
  Future<void> speak(String text) async {
    final synth = html.window.speechSynthesis;
    if (synth == null) return;
    final utter = html.SpeechSynthesisUtterance(text);
    utter.volume = _volume;
    utter.rate = 1.0;
    utter.pitch = 1.0;
    utter.onStart.listen((_) => _speakingCtl.add(true));
    utter.onEnd.listen((_) => _speakingCtl.add(false));
    utter.onError.listen((_) => _speakingCtl.add(false));
    _speakingCtl.add(true);
    synth.speak(utter);
  }

  @override
  Future<void> stop() async {
    final synth = html.window.speechSynthesis;
    synth?.cancel();
    _speakingCtl.add(false);
  }

  @override
  Stream<bool> get speaking => _speakingCtl.stream;
}

TtsService createTtsServiceImpl() => _WebTts();
