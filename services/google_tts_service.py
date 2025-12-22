import os
import logging
import base64
from google.cloud import texttospeech
from google.oauth2 import service_account
from typing import Optional

logger = logging.getLogger(__name__)

class GoogleTtsService:
    _client = None

    @classmethod
    def get_client(cls):
        if cls._client:
            return cls._client
        
        # Try to authenticate using the same method as other Google services
        # 1. Check for GOOGLE_APPLICATION_CREDENTIALS env var
        # 2. Check for user credentials file (if created by oauth flow) - handled by default credentials usually?
        # The api_server setup seems to use Application Default Credentials (ADC) or a key file.
        
        try:
            cls._client = texttospeech.TextToSpeechClient()
            logger.info("Google TTS Client initialized with default credentials")
        except Exception as e:
            logger.error(f"Failed to initialize Google TTS Client: {e}")
            cls._client = None
        
        return cls._client

    @classmethod
    def synthesize(cls, text: str, voice_name: str, language_code: str = "en-US", speaking_rate: float = 1.0) -> Optional[bytes]:
        """
        Synthesizes text using Google Cloud TTS.
        """
        client = cls.get_client()
        if not client:
            return None

        try:
            synthesis_input = texttospeech.SynthesisInput(text=text)

            # Build the voice request
            # Note: voice_name is full name like "en-US-Neural2-A"
            voice = texttospeech.VoiceSelectionParams(
                language_code=language_code,
                name=voice_name
            )

            # Select the type of audio file you want returned
            audio_config = texttospeech.AudioConfig(
                audio_encoding=texttospeech.AudioEncoding.LINEAR16, # WAV
                speaking_rate=speaking_rate
            )

            response = client.synthesize_speech(
                input=synthesis_input, voice=voice, audio_config=audio_config
            )

            return response.audio_content
        except Exception as e:
            logger.error(f"Google TTS synthesis failed: {e}")
            return None
