import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// State of the real-time voice session
enum VoiceSessionState {
  disconnected,
  connecting,
  connected,
  listening,
  processing,
  speaking,
  error,
}

/// Configuration for real-time voice session
class RealtimeVoiceConfig {
  final String userId;
  final String voice;
  final String systemPrompt;
  final String baseUrl;

  const RealtimeVoiceConfig({
    required this.userId,
    this.voice = 'Aoede',
    this.systemPrompt = '',
    this.baseUrl = 'ws://127.0.0.1:8000',
  });
}

/// Real-time voice service using Gemini Live API via WebSocket
/// 
/// This provides low-latency bidirectional voice conversation with:
/// - Automatic voice activity detection (no self-listening)
/// - Native audio input/output
/// - Real-time transcription
class RealtimeVoiceService {
  WebSocketChannel? _channel;
  VoiceSessionState _state = VoiceSessionState.disconnected;
  RealtimeVoiceConfig? _config;
  
  // Stream controllers
  final _stateController = StreamController<VoiceSessionState>.broadcast();
  final _audioController = StreamController<Uint8List>.broadcast();
  final _textController = StreamController<String>.broadcast();
  final _transcriptController = StreamController<TranscriptEvent>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  
  // Ping timer for keepalive
  Timer? _pingTimer;
  
  /// Current session state
  VoiceSessionState get state => _state;
  
  /// Current configuration (null if not connected)
  RealtimeVoiceConfig? get config => _config;
  
  /// Stream of state changes
  Stream<VoiceSessionState> get stateStream => _stateController.stream;
  
  /// Stream of audio output (PCM 16-bit, 24kHz)
  Stream<Uint8List> get audioStream => _audioController.stream;
  
  /// Stream of text responses
  Stream<String> get textStream => _textController.stream;
  
  /// Stream of transcription events
  Stream<TranscriptEvent> get transcriptStream => _transcriptController.stream;
  
  /// Stream of errors
  Stream<String> get errorStream => _errorController.stream;
  
  /// Whether the service is connected
  bool get isConnected => _state == VoiceSessionState.connected ||
      _state == VoiceSessionState.listening ||
      _state == VoiceSessionState.processing ||
      _state == VoiceSessionState.speaking;
  
  void _setState(VoiceSessionState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
      debugPrint('[RealtimeVoice] State: ${newState.name}');
    }
  }
  
  /// Connect to the real-time voice service
  Future<bool> connect(RealtimeVoiceConfig config) async {
    if (isConnected) {
      debugPrint('[RealtimeVoice] Already connected');
      return true;
    }
    
    _config = config;
    _setState(VoiceSessionState.connecting);
    
    try {
      // Build WebSocket URL
      final wsUrl = Uri.parse('${config.baseUrl}/ws/voice').replace(
        queryParameters: {
          'user_id': config.userId,
          'voice': config.voice,
          if (config.systemPrompt.isNotEmpty) 'system_prompt': config.systemPrompt,
        },
      );
      
      debugPrint('[RealtimeVoice] Connecting to $wsUrl');
      
      _channel = WebSocketChannel.connect(wsUrl);
      
      // Listen for messages
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDone,
      );
      
      // Start ping timer for keepalive
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (isConnected) {
          _send({'type': 'ping'});
        }
      });
      
      // Wait a bit for connection to establish
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (_state == VoiceSessionState.connecting) {
        _setState(VoiceSessionState.connected);
      }
      
      return true;
    } catch (e) {
      debugPrint('[RealtimeVoice] Connection error: $e');
      _setState(VoiceSessionState.error);
      _errorController.add('Connection failed: $e');
      return false;
    }
  }
  
  /// Disconnect from the service
  Future<void> disconnect() async {
    _pingTimer?.cancel();
    _pingTimer = null;
    
    if (_channel != null) {
      await _channel!.sink.close();
      _channel = null;
    }
    
    _setState(VoiceSessionState.disconnected);
    debugPrint('[RealtimeVoice] Disconnected');
  }
  
  /// Send audio data to the model
  /// 
  /// Audio should be PCM 16-bit, 16kHz, mono
  void sendAudio(Uint8List audioData) {
    if (!isConnected) {
      debugPrint('[RealtimeVoice] Cannot send audio: not connected');
      return;
    }
    
    _send({
      'type': 'audio',
      'data': base64Encode(audioData),
    });
    
    if (_state == VoiceSessionState.connected) {
      _setState(VoiceSessionState.listening);
    }
  }
  
  /// Send text message to the model
  void sendText(String text) {
    if (!isConnected) {
      debugPrint('[RealtimeVoice] Cannot send text: not connected');
      return;
    }
    
    _send({
      'type': 'text',
      'data': text,
    });
    
    _setState(VoiceSessionState.processing);
  }
  
  void _send(Map<String, dynamic> message) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(message));
    }
  }
  
  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final type = data['type'] as String?;
      
      switch (type) {
        case 'audio':
          final audioData = base64Decode(data['data'] as String);
          _audioController.add(Uint8List.fromList(audioData));
          break;
          
        case 'text':
          final text = data['data'] as String;
          _textController.add(text);
          break;
          
        case 'transcript':
          final text = data['data'] as String;
          final isFinal = data['is_final'] as bool? ?? true;
          _transcriptController.add(TranscriptEvent(text: text, isFinal: isFinal));
          break;
          
        case 'state':
          final stateStr = data['state'] as String;
          final newState = VoiceSessionState.values.firstWhere(
            (s) => s.name == stateStr,
            orElse: () => VoiceSessionState.connected,
          );
          _setState(newState);
          break;
          
        case 'error':
          final errorMsg = data['message'] as String? ?? 'Unknown error';
          _errorController.add(errorMsg);
          debugPrint('[RealtimeVoice] Error: $errorMsg');
          break;
          
        case 'pong':
          // Keepalive response, ignore
          break;
          
        default:
          debugPrint('[RealtimeVoice] Unknown message type: $type');
      }
    } catch (e) {
      debugPrint('[RealtimeVoice] Error parsing message: $e');
    }
  }
  
  void _handleError(dynamic error) {
    debugPrint('[RealtimeVoice] WebSocket error: $error');
    _setState(VoiceSessionState.error);
    _errorController.add('WebSocket error: $error');
  }
  
  void _handleDone() {
    debugPrint('[RealtimeVoice] WebSocket closed');
    _setState(VoiceSessionState.disconnected);
  }
  
  /// Dispose of resources
  void dispose() {
    disconnect();
    _stateController.close();
    _audioController.close();
    _textController.close();
    _transcriptController.close();
    _errorController.close();
  }
}

/// Transcript event from the voice service
class TranscriptEvent {
  final String text;
  final bool isFinal;
  
  const TranscriptEvent({
    required this.text,
    required this.isFinal,
  });
}
