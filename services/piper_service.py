import os
import subprocess
import logging
import time
import shutil
from typing import Optional

logger = logging.getLogger(__name__)

from services.voice_manager import VoiceManager

class PiperService:
    _piper_bin = None

    @classmethod
    def initialize(cls, model_name="en_US-lessac-low"):
        """
        Initializes the Piper TTS engine.
        """
        base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        
        # Check for system piper (from piper-tts package)
        system_piper = shutil.which("piper")
        
        # Check for local binary
        local_piper = os.path.join(base_dir, "bin", "piper", "piper")

        if system_piper:
            cls._piper_bin = system_piper
            logger.info(f"Using system Piper binary at {system_piper}")
        elif os.path.exists(local_piper):
            cls._piper_bin = local_piper
            logger.info(f"Using local Piper binary at {local_piper}")
        else:
            logger.warning(f"Piper binary not found. Install via 'pip install piper-tts' or run scripts/setup_voice.py")
            return

    @classmethod
    def synthesize(cls, text: str, speed: float = 1.0, voice: str = "en_US-lessac", quality: str = "low", noise_scale: float = 0.667, noise_w: float = 0.8) -> Optional[bytes]:
        """
        Synthesizes text to audio (WAV format) using the Piper binary.
        
        Args:
            text: The text to speak.
            speed: Speaking rate (default 1.0).
            voice: The voice key (default en_US-lessac).
            quality: The quality level (default low).
            noise_scale: Generator noise (default 0.667).
            noise_w: Phoneme width noise (default 0.8).
            
        Returns:
            bytes: WAV audio data, or None if synthesis failed.
        """
        if cls._piper_bin is None:
            cls.initialize()
            if cls._piper_bin is None:
                return None

        model_path = VoiceManager.get_model_path(voice, quality)
        if not model_path:
            # Fallback to default if specific requested voice/quality fails
            logger.warning(f"Requested voice {voice}-{quality} failed, falling back to default.")
            model_path = VoiceManager.get_model_path("en_US-lessac", "low")
            if not model_path:
                return None

        try:
            start_time = time.time()
            # Use a temporary file for output to avoid pipe buffer deadlocks
            import tempfile
            with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp_wav:
                tmp_wav_path = tmp_wav.name

            cmd = [
                cls._piper_bin,
                "--model", model_path,
                "--output_file", tmp_wav_path,
                "--length_scale", str(1.0 / speed),
                "--noise_scale", str(noise_scale),
                "--noise_w", str(noise_w)
            ]
            
            # Log the command for debugging
            logger.info(f"Running Piper: {' '.join(cmd)}")
            
            process = subprocess.Popen(
                cmd,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )
            
            # Send input text
            stdout, stderr = process.communicate(input=text.encode("utf-8"))
            
            duration = time.time() - start_time
            logger.info(f"Piper synthesis took {duration:.2f}s for {len(text)} chars")
            
            if process.returncode != 0:
                logger.error(f"Piper failed (code {process.returncode}): {stderr.decode()}")
                if os.path.exists(tmp_wav_path):
                    os.remove(tmp_wav_path)
                return None
            
            # Read the generated WAV file
            with open(tmp_wav_path, "rb") as f:
                wav_data = f.read()
            
            # Clean up
            os.remove(tmp_wav_path)
            
            return wav_data
        except Exception as e:
            logger.error(f"Synthesis failed: {e}")
            return None
