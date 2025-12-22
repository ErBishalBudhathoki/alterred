// Only compiled on web
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'speech_service.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class _WebSpeech implements SpeechService {
  JSObject? _rec;
  bool _running = false;
  final StreamController<String> _partialCtl =
      StreamController<String>.broadcast();
  final StreamController<double> _levelCtl =
      StreamController<double>.broadcast();
  
  /// Whether hardware AEC is enabled (via getUserMedia constraints)
  bool _aecEnabled = false;
  
  /// MediaStream for AEC-enabled audio capture
  JSObject? _mediaStream;

  @override
  bool get supported {
    final hasWebkit =
        globalContext.hasProperty('webkitSpeechRecognition'.toJS).toDart;
    final hasStandard =
        globalContext.hasProperty('SpeechRecognition'.toJS).toDart;
    return hasWebkit || hasStandard;
  }
  
  /// Initializes WebRTC-based echo cancellation by requesting microphone
  /// with AEC constraints. This primes the browser's audio pipeline.
  Future<void> _initializeAEC() async {
    if (_aecEnabled) return;
    
    try {
      final navigator = globalContext.getProperty<JSObject>('navigator'.toJS);
      final mediaDevices = navigator.getProperty<JSObject>('mediaDevices'.toJS);
      
      // Request microphone with WebRTC echo cancellation constraints
      final constraints = {
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        }
      }.jsify();
      
      final promise = mediaDevices.callMethod<JSPromise>('getUserMedia'.toJS, constraints);
      final stream = await promise.toDart;
      
      if (stream != null) {
        _mediaStream = stream as JSObject;
        _aecEnabled = true;
        debugPrint('[WebSpeech] AEC initialized via getUserMedia constraints');
      }
    } catch (e) {
      debugPrint('[WebSpeech] AEC initialization failed (non-critical): $e');
      // Non-critical - speech recognition will still work without hardware AEC
    }
  }
  
  /// Releases the AEC media stream
  void _releaseAEC() {
    if (_mediaStream != null) {
      try {
        final tracks = _mediaStream!.callMethod<JSArray>('getTracks'.toJS);
        final length = (tracks.getProperty<JSAny>('length'.toJS).dartify() as num).toInt();
        for (var i = 0; i < length; i++) {
          final track = tracks.getProperty<JSObject>(i.toJS);
          track.callMethod('stop'.toJS);
        }
        _mediaStream = null;
        _aecEnabled = false;
        debugPrint('[WebSpeech] AEC media stream released');
      } catch (e) {
        debugPrint('[WebSpeech] Error releasing AEC stream: $e');
      }
    }
  }

  /// Starts speech recognition using the Web Speech API.
  ///
  /// Uses either `SpeechRecognition` or `webkitSpeechRecognition`.
  /// Sets `continuous=false` and `interimResults=true` for dictation mode.
  /// Initializes WebRTC AEC before starting recognition.
  @override
  Future<String?> startOnce() async {
    if (!supported) return null;
    
    // Initialize WebRTC-based echo cancellation
    await _initializeAEC();
    
    final ctorName =
        globalContext.hasProperty('webkitSpeechRecognition'.toJS).toDart
            ? 'webkitSpeechRecognition'
            : 'SpeechRecognition';
    final ctor = globalContext.getProperty<JSFunction>(ctorName.toJS);
    _rec = ctor.callAsConstructorVarArgs<JSObject>();
    _rec!.setProperty('continuous'.toJS, false.toJS);
    _rec!.setProperty('interimResults'.toJS, true.toJS);
    debugPrint(
        '[WebSpeech] using constructor $ctorName, continuous=false, interimResults=true, AEC=$_aecEnabled');
    try {
      final nav = globalContext.getProperty<JSObject>('navigator'.toJS);
      final hasLang = nav.hasProperty('language'.toJS).toDart;
      final lang =
          hasLang ? nav.getProperty<JSAny>('language'.toJS) : 'en-US'.toJS;
      _rec!.setProperty('lang'.toJS, lang);
      debugPrint('WebSpeech: language=$lang');
    } catch (_) {
      _rec!.setProperty('lang'.toJS, 'en-US'.toJS);
      debugPrint('WebSpeech: language fallback=en-US');
    }
    final c = Completer<String?>();
    _running = true;
    String last = '';
    _rec!.setProperty(
        'onresult'.toJS,
        (JSAny event) {
          try {
            final jsEvent = event as JSObject;
            final results =
                jsEvent.getProperty<JSAny>('results'.toJS) as JSObject;
            final idxAny = jsEvent.getProperty<JSAny>('resultIndex'.toJS);
            final idxNum = idxAny.dartify() as num?;
            var idx = idxNum?.toInt() ?? 0;
            int resultsLen = 0;
            try {
              final lenAny =
                  results.getProperty<JSAny>('length'.toJS).dartify();
              resultsLen = (lenAny is num) ? lenAny.toInt() : 0;
            } catch (_) {}
            if (resultsLen <= 0) return;
            if (idx < 0 || idx >= resultsLen) idx = resultsLen - 1;
            final result = results.getProperty<JSAny>(idx.toJS) as JSObject;
            bool hasItem0 = false;
            try {
              hasItem0 = result.hasProperty(0.toJS).toDart;
            } catch (_) {}
            if (!hasItem0) return;
            final item = result.getProperty<JSAny>(0.toJS) as JSObject;
            final transcriptAny = item.getProperty<JSAny>('transcript'.toJS);
            final tStr = transcriptAny.dartify()?.toString() ?? '';
            debugPrint('WebSpeech: onresult idx=$idx transcript="$tStr"');
            if (tStr.isNotEmpty) {
              // Prefer longest observed transcript to avoid truncated finals
              if (tStr.length >= last.length) {
                last = tStr;
              }
              _partialCtl.add(last);
            }
            final finalProp = result.getProperty<JSAny>('isFinal'.toJS);
            final finalVal = finalProp.dartify();
            final isFinal = finalVal is bool ? finalVal : false;
            debugPrint(
                'WebSpeech: result isFinal=${isFinal ? 'true' : 'false'}');
            if (isFinal) {
              _running = false;
              _rec!.callMethod('stop'.toJS);
              if (!c.isCompleted) c.complete(last.isNotEmpty ? last : null);
            }
          } catch (e) {
            debugPrint('WebSpeech: onresult error=${e.toString()}');
            _running = false;
            try {
              _rec!.callMethod('stop'.toJS);
            } catch (_) {}
            if (!c.isCompleted) c.complete(null);
          }
        }.toJS);
    _rec!.setProperty(
        'onspeechend'.toJS,
        (JSAny _) {
          debugPrint('WebSpeech: onspeechend');
          _levelCtl.add(0.0);
          if (_running) {
            _running = false;
            try {
              _rec!.callMethod('stop'.toJS);
            } catch (_) {}
          }
        }.toJS);
    _rec!.setProperty(
        'onend'.toJS,
        (JSAny _) {
          debugPrint('WebSpeech: onend');
          if (!c.isCompleted) c.complete(last.isNotEmpty ? last : null);
        }.toJS);
    _rec!.setProperty(
        'onerror'.toJS,
        (JSAny event) {
          try {
            final ev = event as JSObject;
            final err = ev.getProperty<JSAny>('error'.toJS).dartify();
            final hasMsg = ev.hasProperty('message'.toJS).toDart;
            final msg =
                hasMsg ? ev.getProperty<JSAny>('message'.toJS).dartify() : null;
            debugPrint(
                'WebSpeech: onerror error=${err?.toString()} message=${msg?.toString()}');
          } catch (_) {
            debugPrint('WebSpeech: onerror (details unavailable)');
          }
          _running = false;
          try {
            _rec!.callMethod('stop'.toJS);
          } catch (_) {}
          if (!c.isCompleted) c.complete(null);
        }.toJS);
    debugPrint('WebSpeech: start');
    _rec!.callMethod('start'.toJS);
    _levelCtl.add(0.2);
    Timer(const Duration(seconds: 60), () {
      if (!c.isCompleted) {
        debugPrint('WebSpeech: timeout reached, stopping');
        _running = false;
        try {
          _rec!.callMethod('stop'.toJS);
        } catch (_) {}
        c.complete(last.isNotEmpty ? last : null);
      }
    });
    return c.future;
  }

  @override
  Future<void> stop() async {
    _running = false;
    try {
      if (_rec != null) {
        debugPrint('[WebSpeech] manual stop');
        _rec!.callMethod('stop'.toJS);
      }
    } catch (_) {}
    _levelCtl.add(0.0);
    
    // Release AEC resources when stopping
    _releaseAEC();
  }

  @override
  Stream<String> get partialUpdates => _partialCtl.stream;
  @override
  Stream<double> get levelUpdates => _levelCtl.stream;
}

SpeechService createSpeechServiceImpl() => _WebSpeech();
