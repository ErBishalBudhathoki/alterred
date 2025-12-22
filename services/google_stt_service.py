import logging
import wave
import io
from google.cloud import speech
from typing import Optional, Any, Dict

try:
    from google.api_core import exceptions as gexc
except Exception:
    gexc = None

logger = logging.getLogger(__name__)

class GoogleSttService:
    _client = None

    @classmethod
    def get_client(cls):
        if cls._client:
            return cls._client
        try:
            cls._client = speech.SpeechClient()
            logger.info("Google STT Client initialized")
        except Exception as e:
            logger.error(f"Failed to initialize Google STT Client: {e}")
            cls._client = None
        return cls._client

    @classmethod
    def transcribe_with_diagnostics(
        cls,
        audio_content: bytes,
        language_code: str = "en-US",
        mime_type: Optional[str] = None,
    ) -> Dict[str, Any]:
        client = cls.get_client()
        if not client:
            return {
                "transcript": None,
                "error": "client_unavailable",
                "details": None,
                "used_fallback": False,
                "encoding": None,
                "sample_rate_hz": None,
                "channel_count": None,
                "results_count": 0,
            }

        if not audio_content:
            return {
                "transcript": None,
                "error": "empty_audio",
                "details": None,
                "used_fallback": False,
                "encoding": None,
                "sample_rate_hz": None,
                "channel_count": None,
                "results_count": 0,
            }

        mt = (mime_type or "").lower()
        encoding: Optional[speech.RecognitionConfig.AudioEncoding] = None
        encoding_label: Optional[str] = None
        sample_rate_hz: Optional[int] = None
        channel_count: Optional[int] = None

        if "wav" in mt or audio_content[:4] == b"RIFF":
            try:
                with wave.open(io.BytesIO(audio_content), "rb") as wf:
                    sample_rate_hz = int(wf.getframerate())
                    channel_count = int(wf.getnchannels())
                encoding = speech.RecognitionConfig.AudioEncoding.LINEAR16
                encoding_label = "LINEAR16"
            except Exception as e:
                logger.warning(f"Failed to parse WAV header: {e}")
        elif "ogg" in mt or audio_content[:4] == b"OggS":
            encoding = speech.RecognitionConfig.AudioEncoding.OGG_OPUS
            encoding_label = "OGG_OPUS"
        elif "webm" in mt or audio_content[:4] == b"\x1aE\xdf\xa3":
            encoding = speech.RecognitionConfig.AudioEncoding.WEBM_OPUS
            encoding_label = "WEBM_OPUS"

        def _build_config() -> speech.RecognitionConfig:
            kwargs: Dict[str, Any] = {
                "language_code": language_code,
                "enable_automatic_punctuation": True,
            }
            if encoding is not None:
                kwargs["encoding"] = encoding
            if sample_rate_hz is not None:
                kwargs["sample_rate_hertz"] = sample_rate_hz
            if channel_count is not None:
                kwargs["audio_channel_count"] = channel_count
            return speech.RecognitionConfig(**kwargs)

        def _classify_exception(e: Exception) -> str:
            if gexc is not None:
                try:
                    if isinstance(e, gexc.InvalidArgument):
                        return "invalid_argument"
                    if isinstance(e, gexc.BadRequest):
                        return "bad_request"
                    if isinstance(e, gexc.PermissionDenied):
                        return "permission_denied"
                    if isinstance(e, gexc.Unauthenticated):
                        return "unauthenticated"
                    if isinstance(e, gexc.ResourceExhausted):
                        return "rate_limited"
                    if isinstance(e, gexc.DeadlineExceeded):
                        return "deadline_exceeded"
                    if isinstance(e, gexc.GoogleAPICallError):
                        return "google_api_error"
                except Exception:
                    pass
            msg = str(e).lower()
            if "invalid" in msg and "argument" in msg:
                return "invalid_argument"
            if "permission" in msg or "forbidden" in msg:
                return "permission_denied"
            if "unauth" in msg:
                return "unauthenticated"
            if "deadline" in msg or "timed out" in msg or "timeout" in msg:
                return "deadline_exceeded"
            if "exceed" in msg and "limit" in msg:
                return "rate_limited"
            return "transcription_failed"

        audio = speech.RecognitionAudio(content=audio_content)

        try:
            config = _build_config()
            response = client.recognize(config=config, audio=audio)
            results_count = len(response.results)
            if not response.results:
                return {
                    "transcript": None,
                    "error": "no_speech",
                    "details": None,
                    "used_fallback": False,
                    "encoding": encoding_label,
                    "sample_rate_hz": sample_rate_hz,
                    "channel_count": channel_count,
                    "results_count": results_count,
                }

            transcript_parts = []
            for result in response.results:
                if result.alternatives:
                    transcript_parts.append(result.alternatives[0].transcript)

            transcript = " ".join([t for t in transcript_parts if t]).strip()
            return {
                "transcript": transcript if transcript else None,
                "error": "no_speech" if not transcript else None,
                "details": None,
                "used_fallback": False,
                "encoding": encoding_label,
                "sample_rate_hz": sample_rate_hz,
                "channel_count": channel_count,
                "results_count": results_count,
            }
        except Exception as e:
            code = _classify_exception(e)
            logger.error(f"Google STT transcription failed: {e}", exc_info=True)
            try:
                config = speech.RecognitionConfig(
                    language_code=language_code,
                    enable_automatic_punctuation=True,
                )
                response = client.recognize(config=config, audio=audio)
                results_count = len(response.results)
                if not response.results:
                    return {
                        "transcript": None,
                        "error": "no_speech",
                        "details": None,
                        "used_fallback": True,
                        "encoding": None,
                        "sample_rate_hz": None,
                        "channel_count": None,
                        "results_count": results_count,
                    }
                transcript_parts = []
                for result in response.results:
                    if result.alternatives:
                        transcript_parts.append(result.alternatives[0].transcript)
                transcript = " ".join([t for t in transcript_parts if t]).strip()
                return {
                    "transcript": transcript if transcript else None,
                    "error": None,
                    "details": None,
                    "used_fallback": True,
                    "encoding": None,
                    "sample_rate_hz": None,
                    "channel_count": None,
                    "results_count": results_count,
                }
            except Exception as e2:
                code2 = _classify_exception(e2)
                logger.error(f"Google STT fallback failed: {e2}", exc_info=True)
                return {
                    "transcript": None,
                    "error": code2 or code,
                    "details": str(e2) if str(e2) else str(e),
                    "used_fallback": True,
                    "encoding": encoding_label,
                    "sample_rate_hz": sample_rate_hz,
                    "channel_count": channel_count,
                    "results_count": 0,
                }

    @classmethod
    def transcribe(cls, audio_content: bytes, language_code: str = "en-US", mime_type: Optional[str] = None) -> Optional[str]:
        """
        Transcribes audio content using Google Cloud Speech-to-Text.
        """
        r = cls.transcribe_with_diagnostics(audio_content, language_code, mime_type)
        return r.get("transcript")
