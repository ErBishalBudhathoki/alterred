from typing import Dict, Any, List
from collections import defaultdict
from datetime import datetime

from services.firebase_client import get_client
from services.memory_bank_service import update_peak_hours, update_energy_depletion_patterns

def _parse_ts(ts: str) -> datetime:
    try:
        return datetime.fromisoformat(ts.replace("Z", "+00:00"))
    except Exception:
        return datetime.now()

def compute_peak_hours_from_logs(logs: List[Dict[str, Any]]) -> List[str]:
    buckets: Dict[int, List[int]] = defaultdict(list)
    for entry in logs:
        ts = _parse_ts(entry.get("timestamp", datetime.now().isoformat()))
        lvl = int(entry.get("level", 0))
        buckets[ts.hour].append(lvl)
    averages: List[tuple[int, float]] = []
    for h, vals in buckets.items():
        if vals:
            averages.append((h, sum(vals) / len(vals)))
    averages.sort(key=lambda x: x[1], reverse=True)
    top = [h for h, _ in averages[:4]]
    def _fmt(hr: int) -> str:
        h = hr % 24
        ampm = "am" if h < 12 else "pm"
        h12 = h if 1 <= h <= 12 else (h - 12 if h > 12 else 12)
        nxt = (h + 1) % 24
        ampm2 = "am" if nxt < 12 else "pm"
        h12n = nxt if 1 <= nxt <= 12 else (nxt - 12 if nxt > 12 else 12)
        return f"{h12}-{h12n}{ampm if ampm==ampm2 else ampm}" if ampm==ampm2 else f"{h12}{ampm}-{h12n}{ampm2}"
    return [_fmt(h) for h in sorted(top)]

def compute_depletion_from_logs(logs: List[Dict[str, Any]]) -> Dict[str, Any]:
    by_day: Dict[str, List[tuple[datetime, int]]] = defaultdict(list)
    for entry in logs:
        ts = _parse_ts(entry.get("timestamp", datetime.now().isoformat()))
        lvl = int(entry.get("level", 0))
        by_day[ts.date().isoformat()].append((ts, lvl))
    windows: Dict[str, float] = defaultdict(float)
    counts: Dict[str, int] = defaultdict(int)
    for _, items in by_day.items():
        items.sort(key=lambda x: x[0])
        for i in range(1, len(items)):
            prev, lv0 = items[i-1]
            curr, lv1 = items[i]
            diff = lv1 - lv0
            wkey = f"{prev.hour:02d}-{curr.hour:02d}"
            windows[wkey] += diff
            counts[wkey] += 1
    avg_windows = []
    for k, s in windows.items():
        c = counts.get(k, 1)
        avg_windows.append((k, s / c))
    avg_windows.sort(key=lambda x: x[1])
    slump = [k for k, v in avg_windows if v < -0.5][:5]
    return {"depletion_windows": slump}

def _fetch_energy_logs(user_id: str) -> List[Dict[str, Any]]:
    db = get_client()
    ref = db.collection("users").document(user_id)
    root = ref.collection("energy").stream()
    logs: List[Dict[str, Any]] = []
    for day_doc in root:
        day = day_doc.id
        levels = ref.collection("energy").document(day).collection("levels").order_by("timestamp").stream()
        for level_doc in levels:
            logs.append(level_doc.to_dict())
    return logs

def recompute_patterns(user_id: str) -> Dict[str, Any]:
    logs = _fetch_energy_logs(user_id)
    peaks = compute_peak_hours_from_logs(logs)
    depletion = compute_depletion_from_logs(logs)
    update_peak_hours(user_id, [int(e.get("level", 0)) for e in logs])
    update_energy_depletion_patterns(user_id, depletion)
    return {"peaks": peaks, **depletion}
