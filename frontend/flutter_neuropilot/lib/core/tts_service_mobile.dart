import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'tts_service.dart';

class _MobileTts implements TtsService {
  final FlutterTts _tts = FlutterTts();
  final _speakingCtl = StreamController<bool>.broadcast();
  double _volume = 1.0;

  /// Creates a mobile TTS service and configures event handlers.
  _MobileTts() {
    _tts.setStartHandler(() {
      _speakingCtl.add(true);
    });
    _tts.setCompletionHandler(() {
      _speakingCtl.add(false);
    });
    _tts.setCancelHandler(() {
      _speakingCtl.add(false);
    });
  }

  @override
  bool get supported => true;

  @override
  double get volume => _volume;

  @override
  set volume(double v) {
    _volume = v.clamp(0.0, 1.0);
    _tts.setVolume(_volume);
  }

  /// Speaks the provided text using the native TTS engine.
  ///
  /// Configures default rate (0.5) and pitch (1.0) before speaking.
  /// Awaits completion to ensure sequential playback if awaited.
  @override
  Future<void> speak(String text) async {
    await _tts.stop();
    await _tts.setVolume(_volume);
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);
    _speakingCtl.add(true);
    try {
      await _tts.speak(text);
    } finally {
      _speakingCtl.add(false);
    }
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
    _speakingCtl.add(false);
  }

  @override
  Stream<bool> get speaking => _speakingCtl.stream;
}

TtsService createTtsServiceImpl() => _MobileTts();
