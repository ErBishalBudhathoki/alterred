"""
Metrics Service
===============
Tracks and aggregates various performance and behavioral metrics for the user and the agent.
Supports task completion tracking, decision resolution times, hyperfocus interrupts, and agent latency.

Implementation Details:
- Uses `firebase_client` to store metrics in Firestore under `users/{uid}/metrics/{date}`.
- Stores individual events in an `events` subcollection for granular analysis.
- Aggregates daily stats on demand via `compute_daily_overview`.

Design Decisions:
- Segregates metrics by date (`YYYY-MM-DD`) for easy daily reporting.
- Stores raw events to allow future re-aggregation or detailed analysis.
- Computes aggregates (averages, counts) at read time rather than write time for simplicity.

Behavioral Specifications:
- `record_task_completion`: Logs a completed task with estimated vs. actual time.
- `record_decision_resolution`: Logs the time taken to resolve a decision.
- `record_hyperfocus_interrupt`: Logs an interrupt event.
- `record_agent_latency`: Logs the system's response time.
- `compute_daily_overview`: Returns a summary dictionary for a specific date.
"""
import os
from typing import Dict, Any
from datetime import datetime

from services.firebase_client import get_client


def _metrics_doc(user_id: str, date_key: str):
    return get_client().collection("users").document(user_id).collection("metrics").document(date_key)


def _date_key():
    return datetime.utcnow().date().isoformat()


def record_task_completion(task_id: str, estimated_minutes: int, actual_minutes: int) -> None:
    uid = os.getenv("USER") or "terminal_user"
    dk = _date_key()
    doc = _metrics_doc(uid, dk)
    acc = (estimated_minutes / actual_minutes) if actual_minutes > 0 else 1.0
    doc.set({"tasks": []}, merge=True)
    # simple: append-like write
    doc.collection("events").add({
        "kind": "task_completion",
        "task_id": task_id,
        "estimated": estimated_minutes,
        "actual": actual_minutes,
        "accuracy": acc,
        "timestamp": datetime.utcnow().isoformat(),
    })


def record_decision_resolution(duration_seconds: int) -> None:
    uid = os.getenv("USER") or "terminal_user"
    dk = _date_key()
    _metrics_doc(uid, dk).collection("events").add({
        "kind": "decision_resolution",
        "duration_seconds": duration_seconds,
        "timestamp": datetime.utcnow().isoformat(),
    })


def record_hyperfocus_interrupt() -> None:
    uid = os.getenv("USER") or "terminal_user"
    dk = _date_key()
    _metrics_doc(uid, dk).collection("events").add({
        "kind": "hyperfocus_interrupt",
        "timestamp": datetime.utcnow().isoformat(),
    })


def record_agent_latency(ms: int) -> None:
    uid = os.getenv("USER") or "terminal_user"
    dk = _date_key()
    _metrics_doc(uid, dk).collection("events").add({
        "kind": "agent_latency",
        "ms": ms,
        "timestamp": datetime.utcnow().isoformat(),
    })


def compute_daily_overview(user_id: str, date_key: str) -> Dict[str, Any]:
    doc = _metrics_doc(user_id, date_key)
    evs = doc.collection("events").stream()
    tasks = []
    decisions = []
    latencies = []
    interrupts = 0
    for e in evs:
        d = e.to_dict()
        if d.get("kind") == "task_completion":
            tasks.append(d)
        elif d.get("kind") == "decision_resolution":
            decisions.append(d)
        elif d.get("kind") == "agent_latency":
            latencies.append(d.get("ms", 0))
        elif d.get("kind") == "hyperfocus_interrupt":
            interrupts += 1
    accs = [t.get("accuracy", 1.0) for t in tasks]
    avg_acc = (sum(accs) / len(accs)) if accs else None
    avg_latency = (sum(latencies) / len(latencies)) if latencies else None
    avg_decision_time = (sum([d.get("duration_seconds", 0) for d in decisions]) / len(decisions)) if decisions else None
    return {
        "tasks_completed": len(tasks),
        "avg_time_accuracy": avg_acc,
        "avg_agent_latency_ms": avg_latency,
        "avg_decision_resolution_seconds": avg_decision_time,
        "hyperfocus_interrupts": interrupts,
    }