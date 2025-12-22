import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart'; // for debugPrint
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'tts_service.dart';

class _MobileTts implements TtsService {
  final AudioPlayer _player = AudioPlayer();
  final _speakingCtl = StreamController<bool>.broadcast();
  double _volume = 1.0;
  String? _voice;
  String? _quality;
  
  @override
  void Function(String text)? onSpeakStart;
  
  @override
  void Function()? onSpeakEnd;

  /// Creates a mobile TTS service and configures event handlers.
  _MobileTts() {
    _player.onPlayerComplete.listen((_) {
      _speakingCtl.add(false);
      onSpeakEnd?.call();
    });
  }

  @override
  bool get supported => true;

  @override
  double get volume => _volume;

  @override
  set volume(double v) {
    _volume = v.clamp(0.0, 1.0);
    _player.setVolume(_volume);
  }

  /// Speaks the provided text using the backend Piper TTS engine.
  @override
  Future<void> speak(String text) async {
    await stop();
    _speakingCtl.add(true);
    onSpeakStart?.call(text);

    try {
      // Determine base URL based on platform (assuming emulator for Android)
      final baseUrl =
          Platform.isAndroid ? 'http://10.0.2.2:8000' : 'http://localhost:8000';
      final url = Uri.parse('$baseUrl/tts/speak');

      final payload = <String, dynamic>{
        'text': text,
        'speed': 1.0,
      };
      if (_voice != null) {
        payload['voice'] = _voice;
      }
      if (_quality != null) {
        payload['quality'] = _quality;
      }

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      final rid = response.headers['x-request-id'];

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        await _player.play(BytesSource(bytes));
      } else {
        debugPrint(
            'TTS Error: status=${response.statusCode} request_id=$rid body=${response.body}');
        _speakingCtl.add(false);
        onSpeakEnd?.call();
      }
    } catch (e) {
      debugPrint('TTS Exception: $e');
      _speakingCtl.add(false);
      onSpeakEnd?.call();
    }
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    _speakingCtl.add(false);
    onSpeakEnd?.call();
  }

  @override
  void setOptions({String? voice, String? quality}) {
    if (voice != null) _voice = voice;
    if (quality != null) _quality = quality;
  }

  @override
  Stream<bool> get speaking => _speakingCtl.stream;
}

TtsService createTtsServiceImpl() => _MobileTts();
