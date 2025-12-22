# Voice Dependencies Update

## Summary

Added Google Cloud voice service dependencies to `requirements.txt` to support the application's voice interaction features.

## Changes Made

### 1. Dependencies Added to `requirements.txt`
- `google-cloud-speech` - Google Cloud Speech-to-Text API client library
- `google-cloud-texttospeech` - Google Cloud Text-to-Speech API client library

### 2. Documentation Updates

#### README.md
- Updated **Required Accounts & Services** section to explicitly list the Google Cloud APIs needed:
  - Gemini API (for AI functionality)
  - Cloud Speech-to-Text API (for voice input)
  - Cloud Text-to-Speech API (for voice output)

#### docs/deployment.md
- Updated **Application Dependencies** section to document the voice service packages
- Updated **Environment Variables** section to include `GOOGLE_APPLICATION_CREDENTIALS` requirement for Cloud Speech/TTS APIs

#### CHANGELOG.md
- Added entry in **[Unreleased]** section documenting the voice service dependencies addition

## Why These Dependencies Are Needed

These packages are essential for the voice features documented throughout the project:

1. **Smart STT (Speech-to-Text)**: Uses `google-cloud-speech` for accurate, punctuation-aware transcription
2. **Hybrid TTS (Text-to-Speech)**: Uses `google-cloud-texttospeech` as the cloud-based high-quality voice option (alongside local Piper TTS)
3. **Voice Mode**: Both packages support the real-time voice interaction features

## Setup Requirements

### Google Cloud Console Setup
Developers need to enable these APIs in their Google Cloud Project:

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Select your project
3. Navigate to **APIs & Services** > **Library**
4. Enable:
   - Cloud Speech-to-Text API
   - Cloud Text-to-Speech API

### Authentication
The application uses Google Cloud service account credentials for authentication:
- Set `GOOGLE_APPLICATION_CREDENTIALS` environment variable pointing to your service account JSON file
- Or use Application Default Credentials (ADC) in Cloud Run

### Installation
```bash
# Install all dependencies including voice services
pip install -r requirements.txt
```

## Impact

### For Developers
- Must enable additional Google Cloud APIs
- May need to configure service account credentials locally
- Voice features will now have proper dependencies installed

### For Deployment
- Docker builds will include these packages
- Cloud Run deployments need proper IAM permissions for Speech/TTS APIs
- No breaking changes to existing functionality

### For Users
- Enhanced voice interaction capabilities
- Better speech recognition accuracy
- Higher quality text-to-speech output

## Related Files

- `requirements.txt` - Main dependency file
- `services/google_stt_service.py` - Uses `google-cloud-speech`
- `services/google_tts_service.py` - Uses `google-cloud-texttospeech`
- `services/voice_manager.py` - Orchestrates voice services

## Testing

To verify the dependencies are working:

```bash
# Test import
python -c "from google.cloud import speech, texttospeech; print('Voice dependencies OK')"

# Test with credentials
export GOOGLE_APPLICATION_CREDENTIALS="path/to/service-account.json"
python -c "from google.cloud import speech; client = speech.SpeechClient(); print('Speech client OK')"
```

## Next Steps

1. ✅ Dependencies added to requirements.txt
2. ✅ Documentation updated
3. ✅ CHANGELOG updated
4. ⏳ Developers should enable APIs in their Google Cloud projects
5. ⏳ Update deployment scripts if needed to verify API access

## References

- [Google Cloud Speech-to-Text Documentation](https://cloud.google.com/speech-to-text/docs)
- [Google Cloud Text-to-Speech Documentation](https://cloud.google.com/text-to-speech/docs)
- [Voice Mode Documentation](REALTIME_VOICE_MODE.md)
- [Voice Setup Guide](VOICE_SETUP.md)
