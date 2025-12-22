from typing import Any, Dict, Optional, List
from datetime import datetime

from datetime import timedelta

from .firebase_client import get_client
from .vertex_ai_client import get_vertex_ai_client


_pending_store: Dict[str, Dict[str, Any]] = {}
_calendar_today_store: Dict[str, Any] = {}
_conversations: Dict[str, Dict[str, List[Dict[str, Any]]]] = {}
_summary_cache: Dict[str, Dict[str, str]] = {}


class FirestoreMemoryBank:
    def __init__(self, user_id: str):
        self.user_id = user_id
        self.db = get_client()

    def _user_ref(self):
        return self.db.collection("users").document(self.user_id) if self.db else None

    def ensure_profile(self):
        try:
            ref = self._user_ref()
            if not ref:
                return
            doc = ref.get()
            if not doc.exists:
                ref.set({
                    "time_estimation_factor": 1.8,
                    "peak_hours": ["9-11am", "3-5pm"],
                    "sensory_triggers": [],
                    "hyperfocus_activities": [],
                    "successful_strategies": {}
                })
        except Exception:
            return

    def store_brain_state(self, state: str, context: str):
        try:
            ref = self._user_ref()
            if not ref:
                return
            self.ensure_profile()
            ref.collection("brain_states").add({
                "state": state,
                "context": context,
                "timestamp": datetime.now().isoformat()
            })
        except Exception:
            return

    def store_task_completion(self, task: str, estimated_minutes: int, actual_minutes: int):
        try:
            ref = self._user_ref()
            if not ref:
                return
            self.ensure_profile()
            accuracy = (estimated_minutes / actual_minutes) if actual_minutes > 0 else 1.0
            ref.collection("task_history").add({
                "task": task,
                "estimated_minutes": estimated_minutes,
                "actual_minutes": actual_minutes,
                "accuracy": accuracy,
                "completed_at": datetime.now().isoformat()
            })

            tasks = ref.collection("task_history").order_by("completed_at", direction="DESCENDING").limit(10).stream()
            accs = []
            for t in tasks:
                d = t.to_dict()
                if "accuracy" in d:
                    accs.append(d["accuracy"])
            if accs:
                avg_acc = sum(accs) / len(accs)
                new_factor = 1 / avg_acc if avg_acc > 0 else 1.0
                ref.update({"time_estimation_factor": new_factor})
        except Exception:
            return

    def get_time_estimation_factor(self) -> float:
        try:
            ref = self._user_ref()
            if not ref:
                return 1.8
            doc = ref.get()
            if doc.exists:
                data = doc.to_dict() or {}
                return float(data.get("time_estimation_factor", 1.8))
            return 1.8
        except Exception:
            return 1.8

    def store_strategy_success(self, kind: str, detail: Dict[str, Any]):
        try:
            ref = self._user_ref()
            if not ref:
                return
            self.ensure_profile()
            ref.collection("strategies").add({
                "kind": kind,
                "detail": detail,
                "timestamp": datetime.now().isoformat()
            })
        except Exception:
            return

    def store_calendar_events_today(self, events: Any):
        try:
            ref = self._user_ref()
            if not ref:
                _calendar_today_store[self.user_id] = events
                return
            self.ensure_profile()
            ref.collection("calendar").document("today").set({
                "events": events,
                "timestamp": datetime.now().isoformat()
            })
        except Exception:
            _calendar_today_store[self.user_id] = events

    def get_calendar_events_today(self) -> Any:
        try:
            ref = self._user_ref()
            if not ref:
                return _calendar_today_store.get(self.user_id)
            doc = ref.collection("calendar").document("today").get()
            if doc.exists:
                data = doc.to_dict() or {}
                return data.get("events")
            return _calendar_today_store.get(self.user_id)
        except Exception:
            return _calendar_today_store.get(self.user_id)

    def store_pending_action(self, action: Dict[str, Any]):
        try:
            ref = self._user_ref()
            if not ref:
                _pending_store[self.user_id] = action
                return
            self.ensure_profile()
            ref.collection("pending").document("action").set({
                "action": action,
                "timestamp": datetime.now().isoformat()
            })
        except Exception:
            _pending_store[self.user_id] = action

    def get_pending_action(self) -> Optional[Dict[str, Any]]:
        try:
            ref = self._user_ref()
            if not ref:
                return _pending_store.get(self.user_id)
            doc = ref.collection("pending").document("action").get()
            if doc.exists:
                data = doc.to_dict() or {}
                return data.get("action")
            return _pending_store.get(self.user_id)
        except Exception:
            return _pending_store.get(self.user_id)

    def clear_pending_action(self):
        try:
            ref = self._user_ref()
            if not ref:
                _pending_store.pop(self.user_id, None)
                return
            ref.collection("pending").document("action").delete()
        except Exception:
            _pending_store.pop(self.user_id, None)

    def store_message(self, session_id: str, role: str, text: str, tool_results: Optional[Any] = None):
        try:
            ref = self._user_ref()
            if not ref:
                sess = _conversations.setdefault(self.user_id, {}).setdefault(session_id, [])
                sess.append({
                    "role": role,
                    "text": text,
                    "tool_results": tool_results,
                    "timestamp": datetime.now().isoformat()
                })
                return
            self.ensure_profile()
            ref.collection("conversations").document(session_id).collection("messages").add({
                "role": role,
                "text": text,
                "tool_results": tool_results,
                "timestamp": datetime.now().isoformat()
            })
        except Exception:
            sess = _conversations.setdefault(self.user_id, {}).setdefault(session_id, [])
            sess.append({
                "role": role,
                "text": text,
                "tool_results": tool_results,
                "timestamp": datetime.now().isoformat()
            })

    def get_recent_messages(self, session_id: str, limit: int = 8) -> List[Dict[str, Any]]:
        try:
            ref = self._user_ref()
            if not ref:
                sess = _conversations.get(self.user_id, {}).get(session_id, [])
                return sess[-limit:] if sess else []
            msgs = ref.collection("conversations").document(session_id).collection("messages")\
                .order_by("timestamp", direction="DESCENDING").limit(limit).stream()
            out = []
            for m in msgs:
                out.append(m.to_dict())
            out.reverse()
            
            # Check for summary
            summary = self.get_session_summary(session_id)
            if summary:
                # Prepend summary as a context message
                out.insert(0, {
                    "role": "system",
                    "text": f"PREVIOUS CONVERSATION SUMMARY: {summary}",
                    "timestamp": datetime.now().isoformat(),
                    "type": "summary"
                })
                
            return out
        except Exception:
            sess = _conversations.get(self.user_id, {}).get(session_id, [])
            return sess[-limit:] if sess else []

    def get_message_count(self, session_id: str) -> int:
        try:
            ref = self._user_ref()
            if not ref:
                sess = _conversations.get(self.user_id, {}).get(session_id, [])
                return len(sess or [])
            msgs = ref.collection("conversations").document(session_id).collection("messages").limit(50).stream()
            return sum(1 for _ in msgs)
        except Exception:
            sess = _conversations.get(self.user_id, {}).get(session_id, [])
            return len(sess or [])

    def store_task_event(self, task_id: str, title: str, status: str, session_id: str):
        try:
            ref = self._user_ref()
            if not ref:
                return
            self.ensure_profile()
            from datetime import datetime
            date_key = datetime.now().date().isoformat()
            ref.collection("tasks").document(date_key).collection("logs").add({
                "task_id": task_id,
                "title": title,
                "status": status,
                "session_id": session_id,
                "timestamp": datetime.now().isoformat()
            })
        except Exception:
            return

    def get_tasks_by_date(self, date_key: str) -> List[Dict[str, Any]]:
        try:
            ref = self._user_ref()
            if not ref:
                return []
            logs = ref.collection("tasks").document(date_key).collection("logs").order_by("timestamp").stream()
            res = []
            for entry in logs:
                res.append(entry.to_dict())
            return res
        except Exception:
            return []

    def store_taskflow_event(self, kind: str, payload: Dict[str, Any]):
        try:
            ref = self._user_ref()
            if not ref:
                return
            self.ensure_profile()
            from datetime import datetime
            date_key = datetime.now().date().isoformat()
            ref.collection("taskflow").document(date_key).collection("events").add({
                "kind": kind,
                "payload": payload,
                "timestamp": datetime.now().isoformat()
            })
        except Exception:
            return

    def add_sensory_trigger(self, trigger: str):
        try:
            ref = self._user_ref()
            if not ref:
                return
            doc = ref.get()
            data = doc.to_dict() or {}
            bank = data.get("memory_bank", {})
            triggers = bank.get("sensory_triggers", [])
            if trigger not in triggers:
                triggers.append(trigger)
            bank["sensory_triggers"] = triggers
            ref.update({"memory_bank": bank})
        except Exception:
            return

    def record_energy_level(self, level: int):
        try:
            ref = self._user_ref()
            if not ref:
                return
            from datetime import datetime
            date_key = datetime.now().date().isoformat()
            ref.collection("energy").document(date_key).collection("levels").add({
                "level": level,
                "timestamp": datetime.now().isoformat()
            })
        except Exception:
            return

    def add_successful_strategy(self, category: str, strategy: str):
        try:
            ref = self._user_ref()
            if not ref:
                return
            doc = ref.get()
            data = doc.to_dict() or {}
            bank = data.get("memory_bank", {})
            strategies = bank.get("successful_strategies", {})
            lst = strategies.get(category, [])
            if strategy not in lst:
                lst.append(strategy)
            strategies[category] = lst
            bank["successful_strategies"] = strategies
            ref.update({"memory_bank": bank})
        except Exception:
            return

    def store_decision_event(self, kind: str, payload: Dict[str, Any]):
        try:
            ref = self._user_ref()
            if not ref:
                return
            self.ensure_profile()
            from datetime import datetime
            date_key = datetime.now().date().isoformat()
            ref.collection("decision").document(date_key).collection("events").add({
                "kind": kind,
                "payload": payload,
                "timestamp": datetime.now().isoformat()
            })
        except Exception:
            return

    def find_last_calendar_action(self, session_id: str) -> Optional[Dict[str, Any]]:
        try:
            msgs = self.get_recent_messages(session_id, limit=50)
            for m in reversed(msgs):
                tr = m.get("tool_results")
                if isinstance(tr, list):
                    for item in tr:
                        if isinstance(item, dict):
                            if "calendar_create" in item or "calendar_update" in item or "calendar_delete" in item or "calendar_list_today" in item:
                                return item
                if isinstance(tr, dict):
                    if "calendar_create" in tr or "calendar_update" in tr or "calendar_delete" in tr or "calendar_list_today" in tr:
                        return tr
            return None
        except Exception:
            return None

    def get_session_summary(self, session_id: str) -> Optional[str]:
        try:
            # Check cache first
            if self.user_id in _summary_cache and session_id in _summary_cache[self.user_id]:
                return _summary_cache[self.user_id][session_id]

            ref = self._user_ref()
            if not ref:
                return None
                
            doc = ref.collection("conversations").document(session_id).get()
            if doc.exists:
                data = doc.to_dict() or {}
                summary = data.get("summary")
                if summary:
                    # Update cache
                    if self.user_id not in _summary_cache:
                        _summary_cache[self.user_id] = {}
                    _summary_cache[self.user_id][session_id] = summary
                    return summary
            return None
        except Exception:
            return None

    def summarize_session(self, session_id: str) -> bool:
        try:
            #Get last 20 messages for context
            msgs = self.get_recent_messages(session_id, limit=20)
            if not msgs:
                return False
                
            # Filter out previous summaries to avoid recursion loops in text
            text_parts = []
            for m in msgs:
                if m.get("type") == "summary":
                    continue
                role = m.get("role", "unknown")
                content = m.get("text", "")
                text_parts.append(f"{role}: {content}")
            
            if not text_parts:
                return False
                
            full_text = "\n".join(text_parts)
            
            client = get_vertex_ai_client(self.user_id)
            prompt = f"Summarize the following conversation concisely, capturing key decisions, user preferences, and current context. Ignore trivial chitchat.\n\n{full_text}"
            
            summary = client.generate_content(prompt)
            if not summary:
                return False
                
            ref = self._user_ref()
            if not ref:
                return False
                
            # Store summary on the session document
            ref.collection("conversations").document(session_id).set({
                "summary": summary,
                "last_summarized": datetime.now().isoformat()
            }, merge=True)
            
            # Update cache
            if self.user_id not in _summary_cache:
                _summary_cache[self.user_id] = {}
            _summary_cache[self.user_id][session_id] = summary
            
            return True
        except Exception as e:
            print(f"Error summarizing session: {e}")
            return False

    def cleanup_old_memories(self, retention_days: int = 30):
        """
        Deletes raw messages older than retention_days, keeping summaries.
        """
        try:
            ref = self._user_ref()
            if not ref:
                return
                
            cutoff = datetime.now() - timedelta(days=retention_days)
            cutoff_iso = cutoff.isoformat()
            
            # Iterate through all conversations (this might be slow for many sessions)
            # A better approach for production would be a separate scheduled function
            sessions = ref.collection("conversations").stream()
            
            for sess in sessions:
                # Delete messages older than cutoff
                msgs = sess.reference.collection("messages")\
                    .where("timestamp", "<", cutoff_iso)\
                    .limit(500)\
                    .stream()
                
                batch = self.db.batch()
                count = 0
                for m in msgs:
                    batch.delete(m.reference)
                    count += 1
                
                if count > 0:
                    batch.commit()
                    
        except Exception as e:
            print(f"Error cleaning up old memories: {e}")


