import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart'; // for debugPrint
import 'package:http/http.dart' as http;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'tts_service.dart';

class _WebTts implements TtsService {
  final _speakingCtl = StreamController<bool>.broadcast();
  double _volume = 1.0;
  String? _voice;
  String? _quality;
  web.HTMLAudioElement? _audioElement;
  
  @override
  void Function(String text)? onSpeakStart;
  
  @override
  void Function()? onSpeakEnd;

  @override
  bool get supported => true;

  @override
  double get volume => _volume;

  @override
  set volume(double v) {
    _volume = v.clamp(0.0, 1.0);
    if (_audioElement != null) {
      _audioElement!.volume = _volume;
    }
  }

  @override
  void setOptions({String? voice, String? quality}) {
    if (voice != null) _voice = voice;
    if (quality != null) _quality = quality;
  }

  /// Speaks the provided text using the backend Piper TTS engine.
  ///
  /// Fetches audio as a blob and plays it using an HTML Audio element.
  @override
  Future<void> speak(String text) async {
    // Clean up markdown and special characters
    // Also remove emojis unless specifically asked to explain them (basic heuristic)
    // Regex to match emojis (Unicode ranges for emojis)
    final cleanText = text
        .replaceAll(
            RegExp(r'[\u{1F600}-\u{1F64F}]', unicode: true), '') // Emoticons
        .replaceAll(RegExp(r'[\u{1F300}-\u{1F5FF}]', unicode: true),
            '') // Symbols & Pictographs
        .replaceAll(RegExp(r'[\u{1F680}-\u{1F6FF}]', unicode: true),
            '') // Transport & Map Symbols
        .replaceAll(RegExp(r'[\u{1F700}-\u{1F77F}]', unicode: true),
            '') // Alchemical Symbols
        .replaceAll(RegExp(r'[\u{1F780}-\u{1F7FF}]', unicode: true),
            '') // Geometric Shapes Extended
        .replaceAll(RegExp(r'[\u{1F800}-\u{1F8FF}]', unicode: true),
            '') // Supplemental Arrows-C
        .replaceAll(RegExp(r'[\u{1F900}-\u{1F9FF}]', unicode: true),
            '') // Supplemental Symbols and Pictographs
        .replaceAll(RegExp(r'[\u{1FA00}-\u{1FA6F}]', unicode: true),
            '') // Chess Symbols
        .replaceAll(RegExp(r'[\u{1FA70}-\u{1FAFF}]', unicode: true),
            '') // Symbols and Pictographs Extended-A
        .replaceAll(
            RegExp(r'[\u{2600}-\u{26FF}]', unicode: true), '') // Misc Symbols
        .replaceAll(
            RegExp(r'[\u{2700}-\u{27BF}]', unicode: true), '') // Dingbats
        .replaceAll(RegExp(r'\*\*'), '') // Remove bold
        .replaceAll(RegExp(r'\*'), '') // Remove italics
        .replaceAll(RegExp(r'`'), '') // Remove code
        .replaceAll(RegExp(r'\[.*?\]'), '') // Remove tools/metadata
        .replaceAll(RegExp(r'https?://\S+'), '') // Remove URLs
        .replaceAll(RegExp(r'[#\-]+'), '') // Remove #, -, --
        .replaceAll(RegExp(r'\n'), '. ') // Replace newlines with pauses
        .replaceAll(RegExp(r'next line', caseSensitive: false),
            '') // Remove "next line" phrase
        .replaceAll(RegExp(r'\s+'), ' ') // Collapse whitespace
        .trim();

    debugPrint(
        '[WebTTS] speak called for: "${cleanText.substring(0, min(50, cleanText.length))}..."');
    await stop();
    _speakingCtl.add(true);
    
    // Notify echo cancellation service that TTS is starting
    onSpeakStart?.call(cleanText);

    try {
      // For web, we assume the backend is at localhost:8000 (or proxy)
      // If running via flutter run -d chrome, it might need CORS enabled on backend
      // Use 127.0.0.1 to avoid potential ipv6 resolution issues with localhost
      const baseUrl = 'http://127.0.0.1:8000';
      final url = Uri.parse('$baseUrl/tts/speak');
      debugPrint('[WebTTS] Fetching audio from: $url');

      http.Response? response;
      try {
        response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'text': cleanText,
                'speed': 1.0,
                if (_voice != null) 'voice': _voice,
                if (_quality != null) 'quality': _quality,
              }),
            )
            .timeout(const Duration(seconds: 20));
      } catch (e) {
        await Future.delayed(const Duration(milliseconds: 400));
        try {
          response = await http
              .post(
                url,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'text': cleanText,
                  'speed': 1.0,
                  if (_voice != null) 'voice': _voice,
                  if (_quality != null) 'quality': _quality,
                }),
              )
              .timeout(const Duration(seconds: 20));
        } catch (e2) {
          debugPrint('[WebTTS] TTS unreachable after retry: $e2');
          _speakingCtl.add(false);
          _fallbackSpeak(text);
          return;
        }
      }

      debugPrint(
          '[WebTTS] Response status: ${response.statusCode}, size: ${response.bodyBytes.length} bytes');

      final rid = response.headers['x-request-id'];

      if (response.statusCode == 200) {
        // Convert bytes to base64 data URI to avoid Blob/URL.createObjectURL issues in some contexts
        final base64Audio = base64Encode(response.bodyBytes);
        final audioUrl = 'data:audio/wav;base64,$base64Audio';
        debugPrint('[WebTTS] Created data URI (length: ${audioUrl.length})');

        _audioElement = web.HTMLAudioElement();
        _audioElement!.src = audioUrl;
        _audioElement!.volume = _volume;

        final completer = Completer<void>();

        // Ensure we handle the promise returned by play()
        _audioElement!.onended = ((web.Event e) {
          debugPrint('[WebTTS] Playback ended');
          _speakingCtl.add(false);
          onSpeakEnd?.call(); // Notify echo cancellation service
          _audioElement = null;
          if (!completer.isCompleted) completer.complete();
        }).toJS;

        _audioElement!.onerror = ((web.Event e) {
          debugPrint(
              '[WebTTS] Audio playback error: ${_audioElement?.error?.message}');
          _speakingCtl.add(false);
          onSpeakEnd?.call(); // Notify echo cancellation service
          _audioElement = null;
          if (!completer.isCompleted) {
            completer.completeError("Playback failed");
          }
        }).toJS;

        // Handle autoplay policy
        try {
          debugPrint('[WebTTS] Attempting to play...');
          await _audioElement!.play().toDart;
          debugPrint('[WebTTS] Playback started successfully');
          await completer.future;
        } catch (e) {
          debugPrint('[WebTTS] Autoplay failed: $e');
          _speakingCtl.add(false);
          onSpeakEnd?.call();
          if (!completer.isCompleted) completer.completeError(e);
        }
      } else {
        debugPrint(
            '[WebTTS] TTS Error: ${response.statusCode} request_id=$rid ${response.body}');
        _speakingCtl.add(false);
        onSpeakEnd?.call();
      }
    } catch (e) {
      debugPrint('[WebTTS] TTS Exception: $e');
      _speakingCtl.add(false);
      onSpeakEnd?.call();
      // No fallback here; fallback is only for unreachable after retry above
    }
  }

  void _fallbackSpeak(String text) {
    debugPrint('Falling back to browser TTS');
    onSpeakStart?.call(text); // Notify for fallback too
    final synth = web.window.speechSynthesis;
    final utterance = web.SpeechSynthesisUtterance(text);
    utterance.volume = _volume;
    utterance.rate = 1.0;
    utterance.pitch = 1.0;
    utterance.onend = ((web.Event e) {
      _speakingCtl.add(false);
      onSpeakEnd?.call();
    }).toJS;
    _speakingCtl.add(true);
    synth.speak(utterance);
  }

  @override
  Future<void> stop() async {
    if (_audioElement != null) {
      _audioElement!.pause();
      _audioElement!.currentTime = 0;
      _audioElement = null;
    }
    web.window.speechSynthesis.cancel();
    _speakingCtl.add(false);
    onSpeakEnd?.call();
  }

  @override
  Stream<bool> get speaking => _speakingCtl.stream;
}

TtsService createTtsServiceImpl() => _WebTts();
