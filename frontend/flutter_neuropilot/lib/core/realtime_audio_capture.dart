import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

/// Audio capture configuration
class AudioCaptureConfig {
  final int sampleRate;
  final int channelCount;
  final bool echoCancellation;
  final bool noiseSuppression;
  final bool autoGainControl;

  const AudioCaptureConfig({
    this.sampleRate = 16000,
    this.channelCount = 1,
    this.echoCancellation = true,
    this.noiseSuppression = true,
    this.autoGainControl = true,
  });
}

/// Realtime audio capture service for streaming audio to WebSocket
/// 
/// Uses the `record` package to capture audio in PCM format and stream
/// it continuously for realtime voice conversations.
class RealtimeAudioCapture {
  final AudioRecorder _recorder = AudioRecorder();
  final _audioController = StreamController<Uint8List>.broadcast();
  final _levelController = StreamController<double>.broadcast();
  
  bool _isCapturing = false;
  StreamSubscription<RecordState>? _stateSubscription;
  StreamSubscription<Uint8List>? _audioSubscription;
  Timer? _levelTimer;
  
  /// Whether audio capture is supported
  Future<bool> get supported async {
    return await _recorder.hasPermission();
  }
  
  /// Whether currently capturing
  bool get isCapturing => _isCapturing;
  
  /// Stream of audio chunks (PCM 16-bit, 16kHz, mono)
  Stream<Uint8List> get audioStream => _audioController.stream;
  
  /// Stream of audio levels (0.0 to 1.0)
  Stream<double> get levelStream => _levelController.stream;
  
  /// Start capturing audio and streaming it
  Future<bool> start([AudioCaptureConfig config = const AudioCaptureConfig()]) async {
    if (_isCapturing) {
      debugPrint('[RealtimeAudioCapture] Already capturing');
      return true;
    }
    
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        debugPrint('[RealtimeAudioCapture] No microphone permission');
        return false;
      }
      
      // Configure for PCM streaming
      // Note: On web, we use opus encoding as PCM streaming isn't well supported
      // The backend will handle the conversion
      final recordConfig = RecordConfig(
        encoder: kIsWeb ? AudioEncoder.opus : AudioEncoder.pcm16bits,
        sampleRate: config.sampleRate,
        numChannels: config.channelCount,
        echoCancel: config.echoCancellation,
        noiseSuppress: config.noiseSuppression,
        autoGain: config.autoGainControl,
      );
      
      debugPrint('[RealtimeAudioCapture] Starting with config: '
          'sampleRate=${config.sampleRate}, '
          'channels=${config.channelCount}, '
          'echoCancellation=${config.echoCancellation}');
      
      // Start streaming audio
      final stream = await _recorder.startStream(recordConfig);
      
      _audioSubscription = stream.listen(
        (data) {
          if (_isCapturing && data.isNotEmpty) {
            _audioController.add(data);
          }
        },
        onError: (error) {
          debugPrint('[RealtimeAudioCapture] Stream error: $error');
        },
        onDone: () {
          debugPrint('[RealtimeAudioCapture] Stream done');
        },
      );
      
      // Start level monitoring
      _levelTimer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
        if (_isCapturing) {
          try {
            final amp = await _recorder.getAmplitude();
            // Convert dB to 0-1 range (assuming -60dB to 0dB range)
            final normalized = ((amp.current + 60) / 60).clamp(0.0, 1.0);
            _levelController.add(normalized);
          } catch (_) {
            // Ignore amplitude errors
          }
        }
      });
      
      _isCapturing = true;
      debugPrint('[RealtimeAudioCapture] Started successfully');
      return true;
      
    } catch (e) {
      debugPrint('[RealtimeAudioCapture] Failed to start: $e');
      return false;
    }
  }
  
  /// Stop capturing audio
  Future<void> stop() async {
    if (!_isCapturing) return;
    
    _isCapturing = false;
    _levelTimer?.cancel();
    _levelTimer = null;
    
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    
    try {
      await _recorder.stop();
    } catch (e) {
      debugPrint('[RealtimeAudioCapture] Error stopping recorder: $e');
    }
    
    debugPrint('[RealtimeAudioCapture] Stopped');
  }
  
  /// Dispose resources
  void dispose() {
    stop();
    _stateSubscription?.cancel();
    _audioController.close();
    _levelController.close();
    _recorder.dispose();
  }
}
