// Only compiled on web
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'speech_service.dart';

class _WebSpeech implements SpeechService {
  JSObject? _rec;
  bool _running = false;
  final StreamController<String> _partialCtl =
      StreamController<String>.broadcast();

  @override
  bool get supported {
    final hasWebkit =
        globalContext.hasProperty('webkitSpeechRecognition'.toJS).toDart;
    final hasStandard =
        globalContext.hasProperty('SpeechRecognition'.toJS).toDart;
    return hasWebkit || hasStandard;
  }

  @override
  Future<String?> startOnce() async {
    if (!supported) return null;
    final ctorName = globalContext
            .hasProperty('webkitSpeechRecognition'.toJS)
            .toDart
        ? 'webkitSpeechRecognition'
        : 'SpeechRecognition';
    final ctor =
        globalContext.getProperty<JSFunction>(ctorName.toJS);
    _rec = ctor.callAsConstructorVarArgs<JSObject>();
    _rec!.setProperty('continuous'.toJS, false.toJS);
    _rec!.setProperty('interimResults'.toJS, true.toJS);
    print('WebSpeech: using constructor $ctorName, continuous=false, interimResults=true');
    try {
      final nav = globalContext.getProperty<JSObject>('navigator'.toJS);
      final hasLang = nav.hasProperty('language'.toJS).toDart;
      final lang = hasLang
          ? nav.getProperty<JSAny>('language'.toJS)
          : 'en-US'.toJS;
      _rec!.setProperty('lang'.toJS, lang);
      print('WebSpeech: language=$lang');
    } catch (_) {
      _rec!.setProperty('lang'.toJS, 'en-US'.toJS);
      print('WebSpeech: language fallback=en-US');
    }
    final c = Completer<String?>();
    _running = true;
    String last = '';
    _rec!.setProperty(
        'onresult'.toJS,
        (JSAny event) {
          try {
            final jsEvent = event as JSObject;
            final results = jsEvent.getProperty<JSAny>('results'.toJS) as JSObject;
            final idxAny = jsEvent.getProperty<JSAny>('resultIndex'.toJS);
            final idxNum = idxAny.dartify() as num?;
            final idx = idxNum?.toInt() ?? 0;
            final result = results.getProperty<JSAny>(idx.toJS) as JSObject;
            final item = result.getProperty<JSAny>(0.toJS) as JSObject;
            final transcriptAny = item.getProperty<JSAny>('transcript'.toJS);
            final tStr = transcriptAny.dartify()?.toString() ?? '';
            print('WebSpeech: onresult idx=$idx transcript="$tStr"');
            if (tStr.isNotEmpty) {
              last = tStr;
              _partialCtl.add(last);
            }
            final finalProp = result.getProperty<JSAny>('isFinal'.toJS);
            final finalVal = finalProp.dartify();
            final isFinal = finalVal is bool ? finalVal : false;
            print('WebSpeech: result isFinal=$isFinal');
            if (isFinal) {
              _running = false;
              _rec!.callMethod('stop'.toJS);
              if (!c.isCompleted) c.complete(last.isNotEmpty ? last : null);
            }
          } catch (e) {
            print('WebSpeech: onresult error=$e');
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
          print('WebSpeech: onspeechend');
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
          print('WebSpeech: onend');
          if (!c.isCompleted) c.complete(last.isNotEmpty ? last : null);
        }.toJS);
    _rec!.setProperty(
        'onerror'.toJS,
        (JSAny event) {
          try {
            final err = (event as JSObject).getProperty<JSAny>('error'.toJS).dartify();
            final hasMsg = (event as JSObject).hasProperty('message'.toJS).toDart;
            final msg = hasMsg ? (event as JSObject).getProperty<JSAny>('message'.toJS).dartify() : null;
            print('WebSpeech: onerror error=${err?.toString()} message=${msg?.toString()}');
          } catch (_) {
            print('WebSpeech: onerror (details unavailable)');
          }
          _running = false;
          try {
            _rec!.callMethod('stop'.toJS);
          } catch (_) {}
          if (!c.isCompleted) c.complete(null);
        }.toJS);
    print('WebSpeech: start');
    _rec!.callMethod('start'.toJS);
    Timer(const Duration(seconds: 60), () {
      if (!c.isCompleted) {
        print('WebSpeech: timeout reached, stopping');
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
        print('WebSpeech: manual stop');
        _rec!.callMethod('stop'.toJS);
      }
    } catch (_) {}
  }

  @override
  Stream<String> get partialUpdates => _partialCtl.stream;
}

SpeechService createSpeechServiceImpl() => _WebSpeech();
