import os
import shutil
import logging
import requests
from typing import List, Dict, Optional

logger = logging.getLogger(__name__)

class VoiceManager:
    _base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    _models_dir = os.path.join(_base_dir, "voice_models")
    
    # Curated list of voices (simplified for now, ideally fetched from a remote JSON)
    # standard Piper voices
    """
    Manages voice models for Piper TTS.

    Handles listing available voices, mapping voice keys to metadata,
    and downloading ONNX models from HuggingFace on demand.
    """
    _available_voices = {
        "en_US-lessac": {
            "key": "en_US-lessac",
            "name": "Lessac",
            "language": "English (US)",
            "qualities": ["low", "medium", "high"],
            "default_quality": "medium"
        },
        "en_US-amy": {
            "key": "en_US-amy",
            "name": "Amy",
            "language": "English (US)",
            "qualities": ["low", "medium"],
            "default_quality": "medium"
        },
        "en_US-arctic": {
            "key": "en_US-arctic",
            "name": "Arctic",
            "language": "English (US)",
            "qualities": ["medium"],
            "default_quality": "medium"
        },
        "en_US-danny": {
            "key": "en_US-danny",
            "name": "Danny",
            "language": "English (US)",
            "qualities": ["low"],
            "default_quality": "low"
        },
        "en_US-hfc_female": {
            "key": "en_US-hfc_female",
            "name": "HFC Female",
            "language": "English (US)",
            "qualities": ["medium"],
            "default_quality": "medium"
        },
        "en_US-ryan": {
            "key": "en_US-ryan",
            "name": "Ryan",
            "language": "English (US)",
            "qualities": ["low", "medium", "high"],
            "default_quality": "medium"
        },
         "en_GB-alan": {
            "key": "en_GB-alan",
            "name": "Alan",
            "language": "English (GB)",
            "qualities": ["low", "medium"],
            "default_quality": "medium"
        },
         "en_GB-southern_english_female": {
            "key": "en_GB-southern_english_female",
            "name": "Southern Female",
            "language": "English (GB)",
            "qualities": ["low"],
            "default_quality": "low"
        },
        "en_GB-cori": {
            "key": "en_GB-cori",
            "name": "Cori",
            "language": "English (GB)",
            "qualities": ["medium", "high"],
            "default_quality": "high"
        },
        "en_GB-jenny_dioco": {
            "key": "en_GB-jenny_dioco",
            "name": "Jenny",
            "language": "English (GB)",
            "qualities": ["medium"],
            "default_quality": "medium",
            "provider": "piper"
        },
        # Google Cloud Voices
        "google-en-US-Journey-F": {
            "key": "en-US-Journey-F",
            "name": "Google Journey (F)",
            "language": "English (US)",
            "qualities": ["standard"],
            "default_quality": "standard",
            "provider": "google"
        },
        "google-en-US-Journey-D": {
            "key": "en-US-Journey-D",
            "name": "Google Journey (M)",
            "language": "English (US)",
            "qualities": ["standard"],
            "default_quality": "standard",
            "provider": "google"
        },
         "google-en-US-Neural2-C": {
            "key": "en-US-Neural2-C",
            "name": "Google Neural (F)",
            "language": "English (US)",
            "qualities": ["standard"],
            "default_quality": "standard",
            "provider": "google"
        },
         "google-en-US-Neural2-D": {
            "key": "en-US-Neural2-D",
            "name": "Google Neural (M)",
            "language": "English (US)",
            "qualities": ["standard"],
            "default_quality": "standard",
            "provider": "google"
        },
         "google-en-GB-Neural2-A": {
            "key": "en-GB-Neural2-A",
            "name": "Google Neural (GB-F)",
            "language": "English (GB)",
            "qualities": ["standard"],
            "default_quality": "standard",
            "provider": "google"
        },
         "google-en-GB-Neural2-B": {
            "key": "en-GB-Neural2-B",
            "name": "Google Neural (GB-M)",
            "language": "English (GB)",
            "qualities": ["standard"],
            "default_quality": "standard",
            "provider": "google"
        }
    }

    @classmethod
    def list_voices(cls) -> List[Dict]:
        """
        Returns a list of all available voice configurations.
        
        Ensures each voice entry has a 'provider' field (defaults to 'piper').
        """
        # Ensure provider is set for older entries
        voices = []
        for v in cls._available_voices.values():
            if "provider" not in v:
                v["provider"] = "piper"
            voices.append(v)
        return voices

    @classmethod
    def get_voice_info(cls, voice_key: str) -> Optional[Dict]:
        """
        Retrieves metadata for a specific voice by its key.
        
        Args:
            voice_key (str): The unique identifier for the voice (e.g., 'en_US-lessac').
            
        Returns:
            Optional[Dict]: Voice metadata dictionary or None if not found.
        """
        # Try exact match first
        if voice_key in cls._available_voices:
            return cls._available_voices[voice_key]
        
        # Check if key is just the internal name (e.g. en-US-Neural2-C) and map back?
        # For now, keys in config match keys in dict.
        # But wait, google keys in dict are like "google-en-US-Neural2-C" to avoid collision?
        # Actually Google voice names are unique (en-US-Neural2-C). Piper names are like en_US-lessac.
        # So we can just use the name as key.
        
        # Let's support looking up by the "key" field value if the dict key is different
        for k, v in cls._available_voices.items():
            if v["key"] == voice_key:
                return v
                
        return None

    @classmethod
    def get_model_path(cls, voice_key: str, quality: str = "medium") -> Optional[str]:
        """
        Resolves the local filesystem path to the requested voice model (ONNX).
        
        If the model or its config JSON is missing, it attempts to download them
        automatically from HuggingFace.
        
        Args:
            voice_key (str): The voice identifier.
            quality (str): Desired quality ('low', 'medium', 'high'). Defaults to 'medium'.
            
        Returns:
            Optional[str]: Absolute path to the .onnx file, or None if unavailable/download failed.
        """
        if voice_key not in cls._available_voices:
            logger.warning(f"Unknown voice: {voice_key}")
            return None

        voice_info = cls._available_voices[voice_key]
        if quality not in voice_info["qualities"]:
            logger.warning(f"Quality {quality} not available for {voice_key}, falling back to {voice_info['default_quality']}")
            from typing import cast
            quality = cast(str, voice_info["default_quality"])

        model_name = f"{voice_key}-{quality}"
        onnx_filename = f"{model_name}.onnx"
        json_filename = f"{model_name}.onnx.json"
        
        onnx_path = os.path.join(cls._models_dir, onnx_filename)
        json_path = os.path.join(cls._models_dir, json_filename)

        if not os.path.exists(onnx_path) or not os.path.exists(json_path):
            logger.info(f"Downloading model {model_name}...")
            if not cls._download_model(voice_key, quality, onnx_path, json_path):
                return None
        
        return onnx_path

    @classmethod
    def _download_model(cls, voice_key: str, quality: str, onnx_path: str, json_path: str) -> bool:
        try:
            if not os.path.exists(cls._models_dir):
                os.makedirs(cls._models_dir)
            
            # Piper voices URL structure
            # https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/lessac/low/en_US-lessac-low.onnx
            # We need to map key to path segments. This is tricky without the full index.
            # For now, we'll use a simplified mapping or hardcoded structure for the curated list.
            
            # Parsing locale and name from key e.g., en_US-lessac
            parts = voice_key.split('-')
            if len(parts) < 2:
                return False
            
            locale = f"{parts[0]}_{parts[1]}" # en_US
            lang = parts[0] # en
            name = parts[2] if len(parts) > 2 else parts[1] # lessac (if en_US-lessac) or lessac (if en_US-lessac)
            # Wait, split en_US-lessac -> ['en_US', 'lessac']
            # split en_GB-southern_english_female -> ['en_GB', 'southern_english_female']
            
            # Re-parsing:
            locale = voice_key.split('-')[0] # en_US (assuming underscores in locale part of key?)
            # Actually keys are usually like en_US-lessac. 
            # Let's assume standard Piper naming: en_US-lessac
            
            # Correct URL construction requires exact folder structure on HF.
            # Easier approach: Use the standard URL pattern which seems to be:
            # lang_short/locale/name/quality/filename
            
            # Example: en/en_US/lessac/low/en_US-lessac-low.onnx
            
            locale_parts = voice_key.split('-')
            lang_code = locale_parts[0][:2] # en
            locale_code = locale_parts[0] # en_US
            
            # name is the rest
            name = '-'.join(locale_parts[1:])
            
            filename_base = f"{voice_key}-{quality}"
            
            base_url = f"https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/{lang_code}/{locale_code}/{name}/{quality}"
            onnx_url = f"{base_url}/{filename_base}.onnx"
            json_url = f"{base_url}/{filename_base}.onnx.json"
            
            logger.info(f"Downloading from {onnx_url}")
            
            # Download ONNX
            r = requests.get(onnx_url, stream=True)
            r.raise_for_status()
            with open(onnx_path, 'wb') as f:
                for chunk in r.iter_content(chunk_size=8192):
                    f.write(chunk)
            
            # Download JSON
            r = requests.get(json_url, stream=True)
            r.raise_for_status()
            with open(json_path, 'wb') as f:
                for chunk in r.iter_content(chunk_size=8192):
                    f.write(chunk)
            
            return True
        except Exception as e:
            logger.error(f"Failed to download voice model: {e}")
            # Clean up partial files
            if os.path.exists(onnx_path):
                os.remove(onnx_path)
            if os.path.exists(json_path):
                os.remove(json_path)
            return False
