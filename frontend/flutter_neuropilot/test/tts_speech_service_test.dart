import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_neuropilot/core/tts_service_stub.dart' as tts_stub;
import 'package:flutter_neuropilot/core/speech_service_stub.dart' as stt_stub;
// Flutter test binding imported via flutter_test

// Unit tests for speech/TTS stub implementations.
// These avoid platform channels and verify clamping and stream presence.
void main() {
  test('TTS service clamps volume to [0,1]', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final tts = tts_stub.createTtsServiceImpl();
    tts.volume = 2.0;
    expect(tts.volume, 1.0);
    tts.volume = -1.0;
    expect(tts.volume, 0.0);
    await tts.stop();
  });

  test('Speech service streams exist and startOnce returns String? or null',
      () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final s = stt_stub.createSpeechServiceImpl();
    final once = await s.startOnce();
    expect(once, isNull);
    expect(s.partialUpdates, isA<Stream<String>>());
    expect(s.levelUpdates, isA<Stream<double>>());
    await s.stop();
  });
}
