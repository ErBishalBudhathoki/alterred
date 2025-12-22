import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:altered/state/session_state.dart'; // For apiClientProvider
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:record/record.dart';
import 'package:flutter/foundation.dart';

final cloudSttServiceProvider = Provider.autoDispose((ref) {
  final service = CloudSttService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});

class CloudSttService {
  final Ref _ref;
  final AudioRecorder _recorder = AudioRecorder();

  CloudSttService(this._ref);

  void dispose() {
    _recorder.dispose();
  }

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  Future<void> startRecording() async {
    try {
      if (await hasPermission()) {
        // On web, this records to Blob (usually webm/opus)
        // On mobile, we can specify encoder.
        const config = RecordConfig(
          encoder: AudioEncoder.opus, // Efficient, supported by Google STT
        );

        // Start recording to a temporary file (or memory on web)
        // On web path is ignored/auto-handled
        await _recorder.start(config, path: '');
      } else {
        throw Exception('Microphone permission denied');
      }
    } catch (e) {
      debugPrint('CloudSTT startRecording error: $e');
      rethrow;
    }
  }

  Future<double> getAmplitude() async {
    try {
      final amp = await _recorder.getAmplitude();
      return amp.current;
    } catch (_) {
      return -160.0;
    }
  }

  Future<String?> stopAndTranscribe() async {
    try {
      final path = await _recorder.stop();
      if (path == null) return null;

      // Read bytes
      Uint8List bytes;
      String fileName = 'audio.webm'; // Default for web
      String mimeType = 'audio/webm';

      if (kIsWeb) {
        // On web, path is a blob URL. We need to fetch it.
        final response = await http.get(Uri.parse(path));
        bytes = response.bodyBytes;
      } else {
        final file = File(path);
        bytes = await file.readAsBytes();
        fileName = 'audio.opus';
        mimeType = 'audio/ogg'; // Opus usually in Ogg container
      }

      // Upload to backend
      final apiClient = _ref.read(apiClientProvider);

      final baseUrl = apiClient.baseUrl;

      final uri = Uri.parse('$baseUrl/stt/transcribe');
      final request = http.MultipartRequest('POST', uri);

      request.files.add(http.MultipartFile.fromBytes('file', bytes,
          filename: fileName, contentType: MediaType.parse(mimeType)));

      request.fields['language'] = 'en-US'; // Make configurable

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final ok = data['ok'] == true;
        final transcript = data['transcript'] as String?;
        final error = data['error'] as String?;
        final requestId = data['request_id']?.toString();
        if (!ok) {
          debugPrint(
              'STT non-fatal response: error=$error request_id=$requestId');
          return null;
        }
        if (transcript == null || transcript.trim().isEmpty) {
          debugPrint(
              'STT empty transcript response: request_id=$requestId body=${response.body}');
          return null;
        }
        return transcript;
      } else {
        String? requestId;
        String? error;
        String? details;
        try {
          final data = jsonDecode(response.body);
          requestId = data['request_id']?.toString();
          error = data['error']?.toString();
          details = data['details']?.toString();
        } catch (_) {}
        debugPrint(
            'STT Error: status=${response.statusCode} error=$error request_id=$requestId details=$details body=${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('STT Exception: $e');
      return null;
    }
  }
}
