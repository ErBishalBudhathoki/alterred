import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/realtime_voice_service.dart';

/// Provider for the realtime voice service
final realtimeVoiceServiceProvider = Provider<RealtimeVoiceService>((ref) {
  final service = RealtimeVoiceService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for the current voice session state
final voiceSessionStateProvider = StreamProvider<VoiceSessionState>((ref) {
  final service = ref.watch(realtimeVoiceServiceProvider);
  return service.stateStream;
});

/// Provider for voice transcripts
final voiceTranscriptProvider = StreamProvider<TranscriptEvent>((ref) {
  final service = ref.watch(realtimeVoiceServiceProvider);
  return service.transcriptStream;
});

/// Provider for voice text responses
final voiceTextResponseProvider = StreamProvider<String>((ref) {
  final service = ref.watch(realtimeVoiceServiceProvider);
  return service.textStream;
});

/// Provider for voice audio output
final voiceAudioOutputProvider = StreamProvider<Uint8List>((ref) {
  final service = ref.watch(realtimeVoiceServiceProvider);
  return service.audioStream;
});

/// Provider for voice errors
final voiceErrorProvider = StreamProvider<String>((ref) {
  final service = ref.watch(realtimeVoiceServiceProvider);
  return service.errorStream;
});

/// Notifier for managing realtime voice session
class RealtimeVoiceNotifier extends StateNotifier<RealtimeVoiceState> {
  final RealtimeVoiceService _service;
  StreamSubscription<VoiceSessionState>? _stateSubscription;
  StreamSubscription<String>? _textSubscription;
  StreamSubscription<TranscriptEvent>? _transcriptSubscription;
  
  RealtimeVoiceNotifier(this._service) : super(const RealtimeVoiceState()) {
    _stateSubscription = _service.stateStream.listen((sessionState) {
      state = state.copyWith(sessionState: sessionState);
    });
    
    _textSubscription = _service.textStream.listen((text) {
      state = state.copyWith(
        lastResponse: text,
        responses: [...state.responses, text],
      );
    });
    
    _transcriptSubscription = _service.transcriptStream.listen((event) {
      if (event.isFinal) {
        state = state.copyWith(
          lastTranscript: event.text,
          transcripts: [...state.transcripts, event.text],
        );
      } else {
        state = state.copyWith(partialTranscript: event.text);
      }
    });
  }
  
  Future<bool> connect({
    required String userId,
    String voice = 'Aoede',
    String systemPrompt = '',
    String baseUrl = 'ws://127.0.0.1:8000',
  }) async {
    final config = RealtimeVoiceConfig(
      userId: userId,
      voice: voice,
      systemPrompt: systemPrompt,
      baseUrl: baseUrl,
    );
    return _service.connect(config);
  }
  
  Future<void> disconnect() async {
    await _service.disconnect();
    state = const RealtimeVoiceState();
  }
  
  void sendAudio(Uint8List audioData) {
    _service.sendAudio(audioData);
  }
  
  void sendText(String text) {
    _service.sendText(text);
  }
  
  void clearHistory() {
    state = state.copyWith(
      responses: [],
      transcripts: [],
      lastResponse: null,
      lastTranscript: null,
      partialTranscript: null,
    );
  }
  
  @override
  void dispose() {
    _stateSubscription?.cancel();
    _textSubscription?.cancel();
    _transcriptSubscription?.cancel();
    super.dispose();
  }
}

/// State for realtime voice session
class RealtimeVoiceState {
  final VoiceSessionState sessionState;
  final String? lastResponse;
  final String? lastTranscript;
  final String? partialTranscript;
  final List<String> responses;
  final List<String> transcripts;
  
  const RealtimeVoiceState({
    this.sessionState = VoiceSessionState.disconnected,
    this.lastResponse,
    this.lastTranscript,
    this.partialTranscript,
    this.responses = const [],
    this.transcripts = const [],
  });
  
  RealtimeVoiceState copyWith({
    VoiceSessionState? sessionState,
    String? lastResponse,
    String? lastTranscript,
    String? partialTranscript,
    List<String>? responses,
    List<String>? transcripts,
  }) {
    return RealtimeVoiceState(
      sessionState: sessionState ?? this.sessionState,
      lastResponse: lastResponse ?? this.lastResponse,
      lastTranscript: lastTranscript ?? this.lastTranscript,
      partialTranscript: partialTranscript ?? this.partialTranscript,
      responses: responses ?? this.responses,
      transcripts: transcripts ?? this.transcripts,
    );
  }
  
  bool get isConnected => sessionState == VoiceSessionState.connected ||
      sessionState == VoiceSessionState.listening ||
      sessionState == VoiceSessionState.processing ||
      sessionState == VoiceSessionState.speaking;
}

/// Provider for the realtime voice notifier
final realtimeVoiceNotifierProvider = StateNotifierProvider<RealtimeVoiceNotifier, RealtimeVoiceState>((ref) {
  final service = ref.watch(realtimeVoiceServiceProvider);
  return RealtimeVoiceNotifier(service);
});
