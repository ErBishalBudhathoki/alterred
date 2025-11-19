import os
from typing import Dict, Any

from services.firebase_client import get_client


def _user_doc(user_id: str):
    return get_client().collection("users").document(user_id)


def get_patterns(user_id: str) -> Dict[str, Any]:
    doc = _user_doc(user_id).get()
    data = doc.to_dict() or {}
    return data.get("memory_bank", {})


def update_time_estimation_pattern(user_id: str, accuracy_list: list[float]) -> None:
    if not accuracy_list:
        return
    avg_acc = sum(accuracy_list) / len(accuracy_list)
    factor = 1 / avg_acc if avg_acc > 0 else 1.0
    ref = _user_doc(user_id)
    doc = ref.get()
    data = doc.to_dict() or {}
    bank = data.get("memory_bank", {})
    bank["time_estimation_error_pattern"] = {"avg_accuracy": avg_acc, "correction_factor": factor}
    ref.update({"memory_bank": bank})


def update_peak_hours(user_id: str, energy_logs: list[int]) -> None:
    if not energy_logs:
        return
    # simplistic: choose hours 9-11 and 3-5 if average energy high
    avg = sum(energy_logs) / len(energy_logs)
    peaks = ["9-11am", "3-5pm"] if avg >= 5 else ["10-11am"]
    ref = _user_doc(user_id)
    doc = ref.get()
    data = doc.to_dict() or {}
    bank = data.get("memory_bank", {})
    bank["peak_hours"] = peaks
    ref.update({"memory_bank": bank})