"""Platform-specific transcript parsing behind the Veilleur poll contract."""
from __future__ import annotations

try:
    from .session_watcher import JsonlAppendWatcher
    from .dsh_session_watcher import DshJsonlAppendWatcher
except ImportError:
    from session_watcher import JsonlAppendWatcher
    from dsh_session_watcher import DshJsonlAppendWatcher


def text_content(value):
    if isinstance(value, str):
        return value
    if isinstance(value, list):
        return "\n".join(part.get("text", "") for part in value
                         if isinstance(part, dict) and isinstance(part.get("text"), str) and part.get("type") in ("text", "input_text", "output_text"))
    return ""


def normalize(platform, event):
    """Return one canonical (role, text) pair or None for irrelevant events."""
    if platform == "claude" and event.get("type") in ("user", "assistant"):
        message = event.get("message", {})
        if isinstance(message, dict):
            return event["type"], text_content(message.get("content", ""))
    if platform == "codex" and event.get("type") == "response_item":
        message = event.get("payload", {})
        if isinstance(message, dict) and message.get("type") == "message" and message.get("role") in ("user", "assistant"):
            return message["role"], text_content(message.get("content", ""))
    if platform == "agy" and event.get("type") in ("USER_INPUT", "PLANNER_RESPONSE"):
        return ("user" if event["type"] == "USER_INPUT" else "assistant"), text_content(event.get("content", ""))
    if platform == "dsh" and event.get("type") in ("user/message", "assistant/message"):
        data = event.get("data", {})
        if isinstance(data, dict):
            message = data.get("message", data) if event["type"] == "assistant/message" else data
            if isinstance(message, dict):
                return ("user" if event["type"] == "user/message" else "assistant"), text_content(message.get("content", ""))
    return None


def watcher_for(platform, source, native_id):
    """Select a platform-specific reader behind the shared poll contract."""
    if platform == "dsh" and str(source).endswith(".zstd"):
        return DshJsonlAppendWatcher(source, native_id)
    return JsonlAppendWatcher(source)


__all__ = ["text_content", "normalize", "watcher_for"]
