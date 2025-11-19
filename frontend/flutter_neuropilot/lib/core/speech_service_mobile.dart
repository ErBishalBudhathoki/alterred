import 'dart:async';
import 'speech_service.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:ui' as ui;

class _MobileSpeech implements SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _available = false;
  bool _listening = false;
  final StreamController<String> _partialCtl = StreamController<String>.broadcast();
  String? _localeId;
  Timer? _silenceTimer;

  _MobileSpeech() {
    _init();
  }

  Future<void> _init() async {
    try {
      _available = await _speech.initialize();
      try {
        final sys = await _speech.systemLocale();
        _localeId = sys?.localeId;
      } catch (_) {
        final tag = ui.PlatformDispatcher.instance.locale.toLanguageTag();
        _localeId = tag.replaceAll('-', '_');
      }
    } catch (_) {
      _available = false;
    }
  }

  @override
  bool get supported => _available;

  @override
  Future<String?> startOnce() async {
    try {
      if (!_available) {
        _available = await _speech.initialize();
        if (!_available) return null;
      }
      if (_listening) await _speech.stop();
      _listening = true;
      final completer = Completer<String?>();
      String buffer = '';
      String lastNonEmpty = '';
      await _speech.listen(
        onResult: (res) {
          buffer = res.recognizedWords;
          if (buffer.isNotEmpty) {
            _partialCtl.add(buffer);
            lastNonEmpty = buffer;
          }
          if (res.finalResult) {
            _listening = false;
            completer.complete(lastNonEmpty.isNotEmpty ? lastNonEmpty : null);
          }
        },
        onSoundLevelChange: (level) {
          // Voice activity detection: stop after sustained silence
          if (level > 40) {
            _silenceTimer?.cancel();
          } else {
            _silenceTimer?.cancel();
            _silenceTimer = Timer(const Duration(milliseconds: 1500), () async {
              if (_listening) {
                try { await _speech.stop(); } catch (_) {}
                _listening = false;
                if (!completer.isCompleted) {
                  completer.complete(lastNonEmpty.isNotEmpty ? lastNonEmpty : null);
                }
              }
            });
          }
        },
        listenFor: const Duration(seconds: 120),
        pauseFor: const Duration(seconds: 2),
        partialResults: true,
        localeId: _localeId,
        cancelOnError: true,
        listenMode: stt.ListenMode.dictation,
      );
      return completer.future;
    } catch (_) {
      _listening = false;
      return null;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _speech.stop();
    } catch (_) {}
    _listening = false;
    _silenceTimer?.cancel();
  }

  @override
  Stream<String> get partialUpdates => _partialCtl.stream;
}

SpeechService createSpeechServiceImpl() => _MobileSpeech();