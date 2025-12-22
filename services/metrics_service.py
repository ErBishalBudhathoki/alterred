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
from typing import Dict, Any, Optional, List
from datetime import datetime

from services.firebase_client import get_client


def _metrics_doc(user_id: str, date_key: str):
    return get_client().collection("users").document(user_id).collection("metrics").document(date_key)


def _date_key():
    return datetime.now().date().isoformat()


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
        "timestamp": datetime.now().isoformat(),
    })


def record_decision_resolution(duration_seconds: int) -> None:
    uid = os.getenv("USER") or "terminal_user"
    dk = _date_key()
    _metrics_doc(uid, dk).collection("events").add({
        "kind": "decision_resolution",
        "duration_seconds": duration_seconds,
        "timestamp": datetime.now().isoformat(),
    })


def record_hyperfocus_interrupt() -> None:
    uid = os.getenv("USER") or "terminal_user"
    dk = _date_key()
    _metrics_doc(uid, dk).collection("events").add({
        "kind": "hyperfocus_interrupt",
        "timestamp": datetime.now().isoformat(),
    })


def record_agent_latency(ms: int) -> None:
    uid = os.getenv("USER") or "terminal_user"
    dk = _date_key()
    _metrics_doc(uid, dk).collection("events").add({
        "kind": "agent_latency",
        "ms": ms,
        "timestamp": datetime.now().isoformat(),
    })


def record_model_usage(
    model_name: str,
    latency_ms: int,
    tokens_input: int = 0,
    tokens_output: int = 0,
    status: str = "success",
    error: str = None
) -> None:
    """Log model usage metrics."""
    uid = os.getenv("USER") or "terminal_user"
    dk = _date_key()
    data = {
        "kind": "model_usage",
        "model": model_name,
        "latency_ms": latency_ms,
        "tokens_input": tokens_input,
        "tokens_output": tokens_output,
        "status": status,
        "timestamp": datetime.now().isoformat(),
    }
    if error:
        data["error"] = error
        
    _metrics_doc(uid, dk).collection("events").add(data)


def record_stress_level(level: int, context: Optional[str] = None) -> None:
    """
    Log a user's reported stress/energy level (1-10).
    Level 1 = Low Energy/High Stress (Bad)
    Level 10 = High Energy/Flow (Good)
    """
    uid = os.getenv("USER") or "terminal_user"
    dk = _date_key()
    data = {
        "kind": "stress_level",
        "level": level,
        "timestamp": datetime.now().isoformat(),
    }
    if context:
        data["context"] = context
    _metrics_doc(uid, dk).collection("events").add(data)


def record_strategy_effectiveness(strategy_name: str, successful: bool) -> None:
    """
    Log the outcome of a specific strategy (e.g., 'body_double', 'timer').
    """
    uid = os.getenv("USER") or "terminal_user"
    dk = _date_key()
    data = {
        "kind": "strategy_effectiveness",
        "strategy": strategy_name,
        "successful": successful,
        "timestamp": datetime.now().isoformat(),
    }
    _metrics_doc(uid, dk).collection("events").add(data)


def compute_daily_overview(user_id: str, date_key: str) -> Dict[str, Any]:
    doc = _metrics_doc(user_id, date_key)
    evs = doc.collection("events").stream()
    tasks = []
    decisions = []
    latencies = []
    interrupts = 0
    stress_levels = []
    strategies: Dict[str, List[bool]] = {}

    for e in evs:
        d = e.to_dict()
        kind = d.get("kind")
        
        if kind == "task_completion":
            tasks.append(d)
        elif kind == "decision_resolution":
            decisions.append(d)
        elif kind == "agent_latency":
            latencies.append(d.get("ms", 0))
        elif kind == "hyperfocus_interrupt":
            interrupts += 1
        elif kind == "stress_level":
            val = d.get("level")
            if val is not None:
                stress_levels.append(int(val))
        elif kind == "strategy_effectiveness":
            strat = d.get("strategy", "unknown")
            success = d.get("successful", False)
            if strat not in strategies:
                strategies[strat] = []
            strategies[strat].append(success)

    accs = [t.get("accuracy", 1.0) for t in tasks]
    avg_acc = (sum(accs) / len(accs)) if accs else 0.0
    avg_latency = (sum(latencies) / len(latencies)) if latencies else 0.0
    avg_decision_time = (sum([d.get("duration_seconds", 0) for d in decisions]) / len(decisions)) if decisions else 0.0
    
    avg_stress = (sum(stress_levels) / len(stress_levels)) if stress_levels else 0.0
    
    strategy_stats = {}
    for strat, outcomes in strategies.items():
        success_rate = (sum(1 for x in outcomes if x) / len(outcomes)) * 100
        strategy_stats[strat] = {
            "count": len(outcomes),
            "success_rate": success_rate
        }

    return {
        "tasks_completed": len(tasks),
        "avg_time_accuracy": avg_acc,
        "avg_agent_latency_ms": avg_latency,
        "avg_decision_resolution_seconds": avg_decision_time,
        "hyperfocus_interrupts": interrupts,
        "avg_stress_level": avg_stress,
        "stress_history": stress_levels, # Return raw list for charting
        "strategy_stats": strategy_stats
    }


def record_api_access(endpoint: str, status: str, latency_ms: int, error: Optional[str] = None) -> None:
    """
    Record an API access event for monitoring.

    Args:
        endpoint (str): Endpoint path (e.g., "/mcp/calendar/v1/status").
        status (str): "success" or "error".
        latency_ms (int): Latency in milliseconds.
        error (str | None): Optional error message.

    Side Effects:
        Writes an event document under the user's metrics collection in Firestore.
    """
    uid = os.getenv("USER") or "terminal_user"
    dk = _date_key()
    data = {
        "kind": "api_access",
        "endpoint": endpoint,
        "status": status,
        "latency_ms": latency_ms,
        "timestamp": datetime.now().isoformat(),
    }
    if error:
        data["error"] = error
    _metrics_doc(uid, dk).collection("events").add(data)


def record_security_event(kind: str, metadata: Optional[Dict[str, Any]] = None) -> None:
    """
    Record a security-related event (e.g., api_key_saved, api_key_deleted, api_key_rotated, api_key_access).
    """
    uid = os.getenv("USER") or "terminal_user"
    dk = _date_key()
    data = {
        "kind": kind,
        "timestamp": datetime.now().isoformat(),
    }
    if metadata:
        data.update({f"meta_{k}": v for k, v in metadata.items()})
    _metrics_doc(uid, dk).collection("events").add(data)


def enforce_rate_limit(user_id: str, limit_per_minute: int = None) -> bool:
    """
    Naive Firestore-backed rate limit: track per-minute counters.
    Returns True if allowed, False if over limit.
    """
    try:
        db = get_client()
        if not db:
            return True
        limit = int(os.getenv("API_RATE_LIMIT_PER_MINUTE", "60")) if limit_per_minute is None else limit_per_minute
        now = datetime.now()
        minute_key = now.strftime("%Y%m%d%H%M")
        doc_ref = db.collection("users").document(user_id).collection("metrics").document("rate_limits").collection("minutes").document(minute_key)
        snap = doc_ref.get()
        if snap.exists:
            data = snap.to_dict() or {}
            count = int(data.get("count", 0)) + 1
            if count > limit:
                _metrics_doc(user_id, _date_key()).collection("events").add({
                    "kind": "rate_limit_violation",
                    "limit": limit,
                    "timestamp": now.isoformat(),
                })
                return False
            doc_ref.set({"count": count, "timestamp": now.isoformat()}, merge=True)
            return True
        else:
            doc_ref.set({"count": 1, "timestamp": now.isoformat()})
            return True
    except Exception:
        return True
