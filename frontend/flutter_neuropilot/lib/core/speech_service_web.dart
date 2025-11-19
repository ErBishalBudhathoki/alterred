// Only compiled on web
import 'dart:async';
import 'dart:js' as js;
import 'speech_service.dart';

class _WebSpeech implements SpeechService {
  js.JsObject? _rec;
  bool _running = false;
  final StreamController<String> _partialCtl = StreamController<String>.broadcast();

  @override
  bool get supported => js.context.hasProperty('webkitSpeechRecognition') || js.context.hasProperty('SpeechRecognition');

  @override
  Future<String?> startOnce() async {
    if (!supported) return null;
    final ctor = js.context.hasProperty('webkitSpeechRecognition')
        ? js.context['webkitSpeechRecognition']
        : js.context['SpeechRecognition'];
    _rec = js.JsObject(ctor);
    _rec!['continuous'] = false;
    _rec!['interimResults'] = true;
    try {
      final nav = js.context['navigator'];
      final lang = nav != null && nav.hasProperty('language') ? nav['language'] : 'en-US';
      _rec!['lang'] = lang;
    } catch (_) {
      _rec!['lang'] = 'en-US';
    }
    final c = Completer<String?>();
    _running = true;
    String last = '';
    print('[SpeechService] Starting recognition...');
    _rec!['onresult'] = js.allowInterop((event) {
      try {
        // Use JsObject to wrap the browser event and access properties
        final jsEvent = js.JsObject.fromBrowserObject(event);
        final results = jsEvent['results'];
        final idx = jsEvent['resultIndex'] ?? 0;
        final result = results[idx];
        final item = result[0];
        final transcript = item['transcript'];
        if (transcript != null && transcript.toString().isNotEmpty) {
          last = transcript.toString();
          _partialCtl.add(last);
          print('[SpeechService] Got transcript: "$last"');
        }
        bool isFinal = false;
        try { 
          final finalProp = result['isFinal'];
          isFinal = finalProp == true;
        } catch (_) {}
        print('[SpeechService] isFinal: $isFinal, last: "$last"');
        if (isFinal) {
          _running = false;
          _rec!.callMethod('stop');
          print('[SpeechService] Final result, completing with: "$last"');
          if (!c.isCompleted) c.complete(last.isNotEmpty ? last : null);
        }
      } catch (e) {
        print('[SpeechService] onresult error: $e');
        _running = false;
        try { _rec!.callMethod('stop'); } catch (_) {}
        if (!c.isCompleted) c.complete(null);
      }
    });
    _rec!['onspeechend'] = js.allowInterop((_) {
      print('[SpeechService] onspeechend fired, last: "$last", running: $_running');
      // If speech ends naturally, finalize with last partial
      if (_running) {
        _running = false;
        try { _rec!.callMethod('stop'); } catch (_) {}
        print('[SpeechService] Completing from onspeechend with: "$last"');
        if (!c.isCompleted) c.complete(last.isNotEmpty ? last : null);
      }
    });
    _rec!['onend'] = js.allowInterop((_) {
      print('[SpeechService] onend fired, last: "$last", completed: ${c.isCompleted}');
      if (!c.isCompleted) c.complete(last.isNotEmpty ? last : null);
    });
    _rec!['onerror'] = js.allowInterop((event) {
      _running = false;
      try { _rec!.callMethod('stop'); } catch (_) {}
      // Capture error details for debugging
      String errorType = 'unknown';
      try {
        errorType = event['error']?.toString() ?? 'unknown';
      } catch (_) {}
      // Log error to console for debugging
      print('[SpeechService] Recognition error: $errorType');
      if (!c.isCompleted) c.complete(null);
    });
    _rec!.callMethod('start');
    Timer(const Duration(seconds: 60), () {
      if (!c.isCompleted) {
        _running = false;
        try { _rec!.callMethod('stop'); } catch (_) {}
        c.complete(last.isNotEmpty ? last : null);
      }
    });
    return c.future;
  }

  @override
  Future<void> stop() async {
    _running = false;
    try { _rec?.callMethod('stop'); } catch (_) {}
  }

  @override
  Stream<String> get partialUpdates => _partialCtl.stream;
}

SpeechService createSpeechServiceImpl() => _WebSpeech();