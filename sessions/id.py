"""
Session ID Utilities
====================
Provides helpers to generate unique session identifiers.

Implementation Details:
- Uses `uuid.uuid4().hex` for 32-character hexadecimal IDs.
- Allows an optional prefix to namespace IDs by context.

Behavioral Specifications:
- Returns a string suitable for use in Firestore document IDs.
"""
import uuid


def generate_session_id(prefix: str = "sess_") -> str:
    """
    Generates a unique session id with an optional prefix.

    Args:
        prefix (str): A string to prepend to the UUID hex.

    Returns:
        str: The generated session id.
    """
    return prefix + uuid.uuid4().hex
