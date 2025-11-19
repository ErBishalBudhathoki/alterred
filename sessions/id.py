import uuid


def generate_session_id(prefix: str = "sess_") -> str:
    return prefix + uuid.uuid4().hex