"""
A2A (Agent-to-Agent) Service
============================
Manages connections and updates between agents (or "partners").
Allows agents to discover and communicate with each other via Firestore.

Implementation Details:
- Uses `firebase_client` to interact with Firestore.
- Stores connections in `users/{uid}/a2a/{partner_id}`.
- Logs updates in a subcollection `updates`.
- Maintains an audit log in `users/{uid}/a2a_audit_logs`.

Design Decisions:
- Simple document structure for connections: status, timestamp.
- Updates are append-only in a subcollection to maintain history.
- Defaults to `os.getenv("USER")` or "terminal_user" for the current user ID.
- Partner IDs are validated for format and existence before connection.

Behavioral Specifications:
- `connect_partner`: Establishes a connection with another agent (validates ID, checks self-connect).
- `post_update`: Sends an update payload to a connected partner.
- `_log_audit`: Records critical actions for security and debugging.
"""
import os
from typing import Dict, Any, List, Optional, Union
import time
import hmac
import hashlib
import secrets
import re
from datetime import datetime
import asyncio
import logging
from enum import Enum

from services.firebase_client import get_client

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class MessageStatus(Enum):
    QUEUED = "queuing"
    SENT = "sent"
    DELIVERED = "delivered"
    FAILED = "failed"
    RETRYING = "retrying"

class MessagePriority(Enum):
    HIGH = "high"
    NORMAL = "normal"
    LOW = "low"

def _validate_partner_id_format(partner_id: str) -> bool:
    """
    Validates the format of a partner ID.
    Format: PART-{6 chars}-{rest} (alphanumeric uppercase)
    """
    if not partner_id:
        return False
    # The generator uses "ABCDEFGHIJKLMNOPQRSTUVWXYZ2345670123456789"
    # Example: PART-A1B2C3-D4E5F6
    pattern = r"^PART-[A-Z0-9]{6}-[A-Z0-9]+$"
    return bool(re.match(pattern, partner_id))


def _log_audit(uid: str, action: str, details: Dict[str, Any]):
    """
    Logs A2A operations for audit purposes.
    """
    try:
        db = get_client()
        db.collection("users").document(uid).collection("a2a_audit_logs").add({
            "action": action,
            "details": details,
            "timestamp": datetime.now().isoformat(),
            "uid": uid
        })
    except Exception:
        pass  # Audit logging should not fail the operation


async def send_message(partner_id: str, message: Dict[str, Any], priority: MessagePriority = MessagePriority.NORMAL, sync: bool = False) -> Dict[str, Any]:
    """
    Sends a message to a connected partner.
    Supports synchronous and asynchronous modes, retry logic, and prioritization.
    """
    uid = os.getenv("USER") or "terminal_user"
    db = get_client()
    
    # Access Control: Verify connection
    ref = db.collection("users").document(uid).collection("a2a").document(partner_id)
    if not ref.get().exists:
        return {"ok": False, "error": "not_connected", "message": "Not connected to this partner"}

    # Orchestration Agent Check (Simplified: Assuming 'orchestrator' is a reserved ID or role)
    # Ideally, we'd check a role field in the partner document.
    
    message_id = secrets.token_hex(8)
    timestamp = datetime.now().isoformat()
    
    msg_data = {
        "id": message_id,
        "content": message,
        "priority": priority.value,
        "timestamp": timestamp,
        "status": MessageStatus.QUEUED.value,
        "sender_uid": uid,
        "recipient_pid": partner_id
    }

    try:
        # Message Queuing (using Firestore as a persistent queue)
        queue_ref = db.collection("users").document(uid).collection("a2a").document(partner_id).collection("message_queue")
        queue_ref.document(message_id).set(msg_data)
        
        if sync:
            # Synchronous: Wait for delivery/response (simulated here)
            # In a real system, we might poll or use a callback
            return await _process_message_sync(uid, partner_id, message_id, msg_data)
        else:
            # Asynchronous: Trigger background processing
            asyncio.create_task(_process_message_async(uid, partner_id, message_id, msg_data))
            return {"ok": True, "message_id": message_id, "status": "queued"}
            
    except Exception as e:
        logger.error(f"Failed to queue message {message_id}: {e}")
        return {"ok": False, "error": str(e)}

async def _process_message_sync(uid: str, partner_id: str, message_id: str, msg_data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Processes a message synchronously, waiting for a result.
    """
    # Simulate processing time or network call
    try:
        # In a real implementation, this would make a direct API call to the partner agent
        # For now, we simulate success and update status
        await _update_message_status(uid, partner_id, message_id, MessageStatus.SENT)
        
        # Simulate delivery
        await _update_message_status(uid, partner_id, message_id, MessageStatus.DELIVERED)
        
        return {"ok": True, "message_id": message_id, "status": "delivered"}
    except Exception as e:
        await _update_message_status(uid, partner_id, message_id, MessageStatus.FAILED, error=str(e))
        return {"ok": False, "error": str(e)}

async def _process_message_async(uid: str, partner_id: str, message_id: str, msg_data: Dict[str, Any]):
    """
    Processes a message asynchronously with retry logic.
    """
    max_retries = 3
    retry_delay = 1 # seconds
    
    for attempt in range(max_retries):
        try:
            await _update_message_status(uid, partner_id, message_id, MessageStatus.SENT)
            # Simulate async delivery
            # await asyncio.sleep(0.5) 
            await _update_message_status(uid, partner_id, message_id, MessageStatus.DELIVERED)
            return
        except Exception as e:
            logger.warning(f"Attempt {attempt + 1} failed for message {message_id}: {e}")
            await _update_message_status(uid, partner_id, message_id, MessageStatus.RETRYING, error=str(e))
            if attempt < max_retries - 1:
                await asyncio.sleep(retry_delay * (2 ** attempt)) # Exponential backoff
            else:
                await _update_message_status(uid, partner_id, message_id, MessageStatus.FAILED, error="Max retries exceeded")

async def _update_message_status(uid: str, partner_id: str, message_id: str, status: MessageStatus, error: Optional[str] = None):
    """
    Updates the status of a message in the queue.
    """
    try:
        db = get_client()
        ref = db.collection("users").document(uid).collection("a2a").document(partner_id).collection("message_queue").document(message_id)
        update_data = {"status": status.value, "updated_at": datetime.now().isoformat()}
        if error:
            update_data["error"] = error
        ref.update(update_data)
        
        # Log metrics/monitoring
        _log_audit(uid, "message_status_update", {"message_id": message_id, "status": status.value, "partner_id": partner_id})
        
    except Exception as e:
        logger.error(f"Failed to update status for message {message_id}: {e}")

def get_agent_health(partner_id: str) -> Dict[str, Any]:
    """
    Checks the health status of a connected agent.
    """
    # This is a placeholder. In a real system, this would ping the agent's health endpoint.
    return {"ok": True, "partner_id": partner_id, "status": "healthy", "latency_ms": 15}

def connect_partner(partner_id: str) -> Dict[str, Any]:

    uid = os.getenv("USER") or "terminal_user"
    
    if not _validate_partner_id_format(partner_id):
        return {"ok": False, "error": "invalid_format", "message": "Invalid partner ID format"}

    # Check if connecting to self
    own_res = get_or_create_partner_id()
    if own_res.get("ok") and own_res.get("partner_id") == partner_id:
        return {"ok": False, "error": "cannot_connect_to_self", "message": "Cannot connect to your own partner ID"}

    db = get_client()
    
    # Verify partner exists in global index
    idx = db.collection("partner_ids").document(partner_id).get()
    if not idx.exists:
         return {"ok": False, "error": "partner_not_found", "message": "Partner ID does not exist"}

    # Write connection on current user's side
    ref = db.collection("users").document(uid).collection("a2a").document(partner_id)
    
    # Check if already connected
    curr = ref.get()
    if curr.exists and curr.to_dict().get("status") == "connected":
        return {"ok": True, "partner_id": partner_id, "message": "Already connected"}

    ref.set({
        "partner_id": partner_id,
        "status": "connected",
        "connected_at": datetime.now().isoformat(),
    })
    
    _log_audit(uid, "connect_partner", {"partner_id": partner_id, "status": "success"})

    # Symmetric write on peer user's side so they see inbound connection in real time
    try:
        # Resolve own PID and peer UID
        meta = db.collection("users").document(uid).collection("a2a").document("meta")
        own_doc = meta.get()
        own_pid = None
        if hasattr(own_doc, "exists") and own_doc.exists:
            data = own_doc.to_dict() if hasattr(own_doc, "to_dict") else {}
            own_pid = (data or {}).get("partner_id")
        
        peer_uid = None
        if hasattr(idx, "exists") and idx.exists:
            id_data = idx.to_dict() if hasattr(idx, "to_dict") else {}
            peer_uid = (id_data or {}).get("uid")
            
        if own_pid and peer_uid:
            db.collection("users").document(peer_uid).collection("a2a").document(own_pid).set({
                "partner_id": own_pid,
                "status": "connected",
                "connected_at": datetime.now().isoformat(),
            }, merge=True)
            # Audit on peer side too? Maybe not necessary or possible given permissions context
    except Exception:
        # Best-effort symmetric write; ignore failures
        pass
    return {"ok": True, "partner_id": partner_id}


def post_update(partner_id: str, update: Dict[str, Any]) -> Dict[str, Any]:
    uid = os.getenv("USER") or "terminal_user"
    db = get_client()
    # Verify connection exists
    ref = db.collection("users").document(uid).collection("a2a").document(partner_id)
    if not ref.get().exists:
        return {"ok": False, "error": "not_connected", "message": "Not connected to this partner"}

    db.collection("users").document(uid).collection("a2a").document(partner_id).collection("updates").add({
        "update": update,
        "timestamp": datetime.now().isoformat(),
    })
    _log_audit(uid, "post_update", {"partner_id": partner_id, "update_keys": list(update.keys())})
    return {"ok": True}


def list_updates(partner_id: str, limit: int = 20) -> Dict[str, Any]:
    uid = os.getenv("USER") or "terminal_user"
    db = get_client()
    col = db.collection("users").document(uid).collection("a2a").document(partner_id).collection("updates")
    try:
        stream = col.stream()
        items = []
        for d in stream:
            try:
                dd = d.to_dict() if hasattr(d, "to_dict") else d
            except Exception:
                dd = d
            u = dd.get("update") if isinstance(dd, dict) else None
            ts = dd.get("timestamp") if isinstance(dd, dict) else None
            items.append({"update": u, "timestamp": ts})
        return {"ok": True, "updates": items[-limit:]}
    except Exception:
        return {"ok": False, "updates": []}


def disconnect_partner(partner_id: str) -> Dict[str, Any]:
    uid = os.getenv("USER") or "terminal_user"
    db = get_client()
    ref = db.collection("users").document(uid).collection("a2a").document(partner_id)
    try:
        ref.set({
            "partner_id": partner_id,
            "status": "disconnected",
            "disconnected_at": datetime.now().isoformat(),
        })
        _log_audit(uid, "disconnect_partner", {"partner_id": partner_id})
        # Symmetric write on peer user's side: mark their doc for our PID as disconnected
        try:
            meta = db.collection("users").document(uid).collection("a2a").document("meta")
            own_doc = meta.get()
            own_pid = None
            if hasattr(own_doc, "exists") and own_doc.exists:
                data = own_doc.to_dict() if hasattr(own_doc, "to_dict") else {}
                own_pid = (data or {}).get("partner_id")
            idx = db.collection("partner_ids").document(partner_id).get()
            peer_uid = None
            if hasattr(idx, "exists") and idx.exists:
                id_data = idx.to_dict() if hasattr(idx, "to_dict") else {}
                peer_uid = (id_data or {}).get("uid")
            if own_pid and peer_uid:
                db.collection("users").document(peer_uid).collection("a2a").document(own_pid).set({
                    "partner_id": own_pid,
                    "status": "disconnected",
                    "disconnected_at": datetime.now().isoformat(),
                }, merge=True)
        except Exception:
            pass
        return {"ok": True}
    except Exception:
        return {"ok": False}


def list_partners() -> Dict[str, Any]:
    uid = os.getenv("USER") or "terminal_user"
    db = get_client()
    col = db.collection("users").document(uid).collection("a2a")
    # Attempt to read own partner_id from meta for filtering
    own_pid = None
    try:
        meta_doc = col.document("meta").get()
        if hasattr(meta_doc, "exists") and meta_doc.exists:
            data = meta_doc.to_dict() if hasattr(meta_doc, "to_dict") else {}
            own_pid = (data or {}).get("partner_id")
    except Exception:
        pass
    try:
        partners = []
        for d in col.stream():
            doc_id = getattr(d, "id", None)
            if doc_id == "meta":
                continue
            if hasattr(d, "to_dict"):
                data = d.to_dict()
            else:
                data = d
            pid = None
            if isinstance(data, dict):
                pid = data.get("partner_id")
            if not pid:
                pid = doc_id
            if not pid:
                continue
            if own_pid and pid == own_pid:
                continue
            partners.append({
                "partner_id": pid,
                "status": (data or {}).get("status"),
            })
        return {"ok": True, "partners": partners}
    except Exception:
        return {"ok": False, "partners": []}


def _format_partner_id(token: bytes) -> str:
    alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ2345670123456789"
    h = hashlib.sha256(token).digest()
    n = int.from_bytes(h, "big")
    chars = []
    for _ in range(10):
        chars.append(alphabet[n % len(alphabet)])
        n //= len(alphabet)
    s = "".join(chars)
    return f"PART-{s[:6]}-{s[6:]}"


def get_or_create_partner_id() -> Dict[str, Any]:
    uid = os.getenv("USER") or "terminal_user"
    db = get_client()
    meta = db.collection("users").document(uid).collection("a2a").document("meta")
    try:
        doc = meta.get()
        if hasattr(doc, "exists") and doc.exists:
            data = doc.to_dict() if hasattr(doc, "to_dict") else {}
            pid = (data or {}).get("partner_id")
            if pid:
                return {"ok": True, "partner_id": pid}
    except Exception:
        pass
    salt = secrets.token_bytes(16)
    ts = int(time.time() * 1000)
    nonce = secrets.token_bytes(8)
    msg = f"altered:{ts}:{len(uid)}".encode()
    digest = hmac.new(salt, msg + nonce, hashlib.sha256).digest()
    pid = _format_partner_id(digest)
    idx = db.collection("partner_ids").document(pid)
    try:
        exists = idx.get()
        if hasattr(exists, "exists") and exists.exists:
            return get_or_create_partner_id()
    except Exception:
        pass
    meta.set({"partner_id": pid, "created_at": ts})
    idx.set({"uid": uid, "created_at": ts})
    _log_audit(uid, "create_partner_id", {"partner_id": pid})
    return {"ok": True, "partner_id": pid}


def set_selected_partner(partner_id: str) -> Dict[str, Any]:
    uid = os.getenv("USER") or "terminal_user"
    db = get_client()
    meta = db.collection("users").document(uid).collection("a2a").document("meta")
    try:
        meta.set({"last_selected_partner": partner_id}, merge=True)
        _log_audit(uid, "set_selected_partner", {"partner_id": partner_id})
        return {"ok": True}
    except Exception:
        try:
            meta.set({"last_selected_partner": partner_id})
            _log_audit(uid, "set_selected_partner", {"partner_id": partner_id})
            return {"ok": True}
        except Exception:
            return {"ok": False}


def get_selected_partner() -> Dict[str, Any]:
    uid = os.getenv("USER") or "terminal_user"
    db = get_client()
    meta = db.collection("users").document(uid).collection("a2a").document("meta")
    try:
        doc = meta.get()
        if hasattr(doc, "exists") and doc.exists:
            data = doc.to_dict() if hasattr(doc, "to_dict") else {}
            return {"ok": True, "partner_id": (data or {}).get("last_selected_partner")}
        return {"ok": True, "partner_id": None}
    except Exception:
        return {"ok": False, "partner_id": None}


def set_default_partner(partner_id: str) -> Dict[str, Any]:
    uid = os.getenv("USER") or "terminal_user"
    db = get_client()
    meta = db.collection("users").document(uid).collection("a2a").document("meta")
    try:
        if partner_id:
            meta.set({"default_partner_id": partner_id}, merge=True)
        else:
            meta.set({"default_partner_id": ""}, merge=True)
        _log_audit(uid, "set_default_partner", {"partner_id": partner_id})
        return {"ok": True}
    except Exception:
        try:
            meta.set({"default_partner_id": partner_id or ""})
            _log_audit(uid, "set_default_partner", {"partner_id": partner_id})
            return {"ok": True}
        except Exception:
            return {"ok": False}


def get_default_partner() -> Dict[str, Any]:
    uid = os.getenv("USER") or "terminal_user"
    db = get_client()
    meta = db.collection("users").document(uid).collection("a2a").document("meta")
    try:
        doc = meta.get()
        if hasattr(doc, "exists") and doc.exists:
            data = doc.to_dict() if hasattr(doc, "to_dict") else {}
            return {"ok": True, "partner_id": (data or {}).get("default_partner_id")}
        return {"ok": True, "partner_id": None}
    except Exception:
        return {"ok": False, "partner_id": None}
