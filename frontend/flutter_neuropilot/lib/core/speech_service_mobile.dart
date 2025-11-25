import 'dart:async';
import 'speech_service.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show debugPrint;

class _MobileSpeech implements SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _available = false;
  bool _listening = false;
  final StreamController<String> _partialCtl =
      StreamController<String>.broadcast();
  final StreamController<double> _levelCtl =
      StreamController<double>.broadcast();
  String? _localeId;
  Timer? _silenceTimer;
  int _listenAttempts = 0;
  int _errors = 0;
  int _partials = 0;
  DateTime? _listenStart;
  double _avgLevel = 0.0;
  int _levelSamples = 0;
  Timer? _readyProbe;

  _MobileSpeech() {
    _init();
  }

  Future<void> _init() async {
    try {
      _available = await _speech.initialize(
        onError: (err) {
          _errors++;
          _listening = false;
          _silenceTimer?.cancel();
          _available = false;
          debugPrint('MobileSTT: initialize error=$err');
          try {
            _speech.cancel();
          } catch (_) {}
        },
        onStatus: (String status) {
          debugPrint('MobileSTT: status=$status');
          _listening = status == 'listening';
        },
      );
      debugPrint('MobileSTT: initialize available=$_available');
      try {
        final sys = await _speech.systemLocale();
        _localeId = sys?.localeId;
        debugPrint('MobileSTT: systemLocale=$_localeId');
      } catch (_) {
        final tag = ui.PlatformDispatcher.instance.locale.toLanguageTag();
        _localeId = tag.replaceAll('-', '_');
        debugPrint('MobileSTT: fallback locale=$_localeId');
      }
    } catch (_) {
      _available = false;
      debugPrint('MobileSTT: initialize threw; available=false');
    }
  }

  @override
  bool get supported => _available;

  @override
  Future<String?> startOnce() async {
    try {
      if (!_available) {
        _available = await _speech.initialize(
          onError: (err) {
            _errors++;
            _listening = false;
            _silenceTimer?.cancel();
          },
          onStatus: (String status) {
            // Diagnose availability/starting/stopping states
            _listening = status == 'listening';
          },
        );
        if (!_available) return null;
      }
      if (_listening) await _speech.stop();
      try {
        await _speech.cancel();
      } catch (_) {}
      _listening = true;
      _listenAttempts++;
      _listenStart = DateTime.now();
      _partials = 0;
      _avgLevel = 0.0;
      _levelSamples = 0;
      debugPrint(
          'MobileSTT: listen start attempts=$_listenAttempts locale=$_localeId');
      final completer = Completer<String?>();
      String buffer = '';
      String lastNonEmpty = '';
      await _speech.listen(
        onResult: (res) {
          buffer = res.recognizedWords;
          if (buffer.isNotEmpty) {
            _partialCtl.add(buffer);
            lastNonEmpty = buffer;
            _partials++;
            debugPrint('MobileSTT: partial="$buffer"');
          }
          if (res.finalResult) {
            _listening = false;
            final durMs = _listenStart != null
                ? DateTime.now().difference(_listenStart!).inMilliseconds
                : 0;
            debugPrint(
                'MobileSTT: final="$lastNonEmpty" durationMs=$durMs partials=$_partials avgLevel=${_avgLevel.toStringAsFixed(1)}');
            completer.complete(lastNonEmpty.isNotEmpty ? lastNonEmpty : null);
          }
        },
        onSoundLevelChange: (level) {
          // Voice activity detection: stop after sustained silence
          final normalized = (level / 100).clamp(0.0, 1.0);
          _levelCtl.add(normalized);
          // accumulate average level for diagnostics
          _avgLevel = ((_avgLevel * _levelSamples) + level) / (++_levelSamples);
          // noise gate threshold; avoid premature termination until we have at least one partial
          if (level > 2) {
            _silenceTimer?.cancel();
          } else {
            _silenceTimer?.cancel();
            _silenceTimer = Timer(const Duration(milliseconds: 10000), () async {
              if (_listening) {
                try {
                  await _speech.stop();
                } catch (_) {}
                _listening = false;
                if (!completer.isCompleted) {
                  // if we never got a partial, return null to prompt a retry
                  completer
                      .complete(lastNonEmpty.isNotEmpty ? lastNonEmpty : null);
                  final durMs = _listenStart != null
                      ? DateTime.now().difference(_listenStart!).inMilliseconds
                      : 0;
                  debugPrint(
                      'MobileSTT: stop due to silence durationMs=$durMs partials=$_partials avgLevel=${_avgLevel.toStringAsFixed(1)}');
                }
              }
            });
          }
        },
        listenFor: const Duration(seconds: 120),
        pauseFor: const Duration(seconds: 3),
        localeId: _localeId,
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: stt.ListenMode.dictation,
        ),
      );
      _readyProbe?.cancel();
      _readyProbe = Timer(const Duration(milliseconds: 5000), () async {
        if (_listening && _partials == 0 && _levelSamples < 1) {
          try {
            await _speech.cancel();
          } catch (_) {}
          _listening = false;
          if (!completer.isCompleted) {
            final durMs = _listenStart != null
                ? DateTime.now().difference(_listenStart!).inMilliseconds
                : 0;
            debugPrint(
                'MobileSTT: readiness probe failed durationMs=$durMs levelSamples=$_levelSamples avgLevel=${_avgLevel.toStringAsFixed(1)}');
            completer.complete(null);
          }
        }
      });
      return completer.future.then((value) {
        final dur = _listenStart != null
            ? DateTime.now().difference(_listenStart!).inMilliseconds
            : 0;
        debugPrint(
            'MobileSTT: session end durationMs=$dur errors=$_errors attempts=$_listenAttempts');
        return value;
      });
    } catch (e) {
      _listening = false;
      _errors++;
      debugPrint('MobileSTT: listen threw error=$e');
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
    _readyProbe?.cancel();
  }

  @override
  Stream<String> get partialUpdates => _partialCtl.stream;
  @override
  Stream<double> get levelUpdates => _levelCtl.stream;
}

SpeechService createSpeechServiceImpl() => _MobileSpeech();
