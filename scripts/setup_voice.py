import os
import requests
import sys
import tarfile
import shutil
import subprocess

# Switching to 'low' quality model for faster synthesis on constrained hardware
VOICE_NAME = "en_US-lessac-low"
VOICE_URL = f"https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/lessac/low/{VOICE_NAME}.onnx"
CONFIG_URL = f"https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/lessac/low/{VOICE_NAME}.onnx.json"

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODELS_DIR = os.path.join(BASE_DIR, "voice_models")

def download_file(url, path):
    print(f"Downloading {url} to {path}...")
    response = requests.get(url, stream=True)
    response.raise_for_status()
    with open(path, "wb") as f:
        for chunk in response.iter_content(chunk_size=8192):
            f.write(chunk)
    print("Done.")

def main():
    if not os.path.exists(MODELS_DIR):
        os.makedirs(MODELS_DIR)

    # 1. Download Voice Model
    onnx_path = os.path.join(MODELS_DIR, f"{VOICE_NAME}.onnx")
    json_path = os.path.join(MODELS_DIR, f"{VOICE_NAME}.onnx.json")

    if not os.path.exists(onnx_path):
        download_file(VOICE_URL, onnx_path)
    else:
        print(f"Voice model {onnx_path} already exists.")

    if not os.path.exists(json_path):
        download_file(CONFIG_URL, json_path)
    else:
        print(f"Voice config {json_path} already exists.")

    # 2. Check for Piper
    if shutil.which("piper"):
        print("✓ Piper TTS is installed and available in PATH.")
        # Verify version or functionality if needed
        try:
            subprocess.run(["piper", "--version"], check=True, capture_output=True)
        except Exception:
            print("Warning: Could not verify piper version.")
    else:
        print("! Piper TTS binary not found in PATH.")
        print("Please install it using pip (requires Python 3.9+):")
        print("  pip install piper-tts")
        print("Or verify your installation.")

if __name__ == "__main__":
    main()
