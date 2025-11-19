from typing import List, Dict, Any

_tracks = [
    {"name": "white_noise", "url": "https://example.com/white"},
    {"name": "brown_noise", "url": "https://example.com/brown"},
    {"name": "focus_music", "url": "https://example.com/focus"},
]


def list_tracks() -> List[Dict[str, Any]]:
    return _tracks


def start_track(name: str) -> Dict[str, Any]:
    for t in _tracks:
        if t["name"] == name:
            return {"ok": True, "track": t}
    return {"ok": False, "error": "track_not_found"}