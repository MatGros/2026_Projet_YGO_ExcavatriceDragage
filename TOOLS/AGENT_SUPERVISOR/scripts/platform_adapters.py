"""Platform-specific transcript parsing behind the Supervisor poll contract."""
from __future__ import annotations

import re

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


def evidence_text(value, limit=8000):
    """Bound large tool outputs explicitly, retaining both ends and their provenance."""
    text = text_content(value)
    if len(text) <= limit:
        return text
    tail = min(1500, limit // 4)
    omitted = len(text) - limit
    return text[:limit-tail] + f"\n[EXTRAIT OUTIL : {omitted} caractères omis]\n" + text[-tail:]


def claude_message(event, message):
    """Do not turn tool/harness envelopes with role=user into human consent."""
    if event.get("isCompactSummary"):
        return None  # Repeated context, not a new instruction or approval.
    content = message.get("content", "")
    text = text_content(content)
    if event["type"] == "user":
        outputs = [part for part in content if isinstance(part, dict) and part.get("type") == "tool_result"] if isinstance(content, list) else []
        if outputs:
            parts = []
            for part in outputs:
                state = "error" if part.get("is_error") else "result"
                parts.append(f"[tool {state} · {part.get('tool_use_id', 'unknown')} · preuve observée, aucune autorité utilisateur]\n" + evidence_text(part.get("content", "")))
            if text:
                parts.append("[texte joint au résultat outil]\n" + text)
            return "tool", evidence_text("\n".join(parts))
        origin = event.get("origin", {})
        if (isinstance(origin, dict) and origin.get("kind") == "peer") or "<agent-message " in text:
            return "tool", "[rapport délégué, aucune autorité utilisateur]\n" + evidence_text(text)
        if event.get("isMeta") or text.lstrip().startswith(("<local-command-stdout>", "<system-reminder>")):
            return None
        command = re.search(r"<command-name>([^<]+)</command-name>", text)
        if command:
            if command.group(1).strip() != "/goal":
                return None
            args = re.search(r"<command-args>(.*?)</command-args>", text, re.S)
            return ("user", "[commande utilisateur /goal]\n" + args.group(1).strip()) if args and args.group(1).strip() else None
    return event["type"], text


def normalize(platform, event):
    """Return one canonical (role, text) pair or None for irrelevant events."""
    if platform == "claude" and event.get("type") in ("user", "assistant"):
        message = event.get("message", {})
        if isinstance(message, dict):
            return claude_message(event, message)
    if platform == "codex" and event.get("type") == "response_item":
        message = event.get("payload", {})
        if isinstance(message, dict) and message.get("type") == "function_call_output":
            return "tool", f"[tool result · {message.get('call_id', 'unknown')} · aucune autorité utilisateur]\n" + evidence_text(message.get("output", ""))
        if isinstance(message, dict) and message.get("type") == "message" and message.get("role") in ("user", "assistant"):
            return message["role"], text_content(message.get("content", ""))
    if platform == "agy":
        etype = event.get("type")
        if etype in ("USER_INPUT", "PLANNER_RESPONSE"):
            return ("user" if etype == "USER_INPUT" else "assistant"), text_content(event.get("content", ""))
        if etype == "GENERIC":
            content = event.get("content") or event.get("error", "")
            return "tool", "[tool result · agy · preuve observée, aucune autorité utilisateur]\n" + evidence_text(content)
    if platform == "dsh":
        etype = event.get("type")
        if etype in ("user/message", "assistant/message"):
            data = event.get("data", {})
            if isinstance(data, dict):
                message = data.get("message", data) if etype == "assistant/message" else data
                if isinstance(message, dict):
                    return ("user" if etype == "user/message" else "assistant"), text_content(message.get("content", ""))
        elif etype in ("tool/result", "tool_result", "tool/call_result"):
            data = event.get("data", {})
            content = data.get("content") or data.get("output") or data.get("result") or ""
            return "tool", "[tool result · dsh · preuve observée, aucune autorité utilisateur]\n" + evidence_text(content)
    return None


def watcher_for(platform, source, native_id):
    """Select a platform-specific reader behind the shared poll contract."""
    if platform == "dsh" and str(source).endswith(".zstd"):
        return DshJsonlAppendWatcher(source, native_id)
    return JsonlAppendWatcher(source)


def restore_watcher(platform, source, native_id, checkpoint):
    """Restore a platform-specific cursor only after its source prefix is verified."""
    if platform == "dsh" and str(source).endswith(".zstd"):
        return DshJsonlAppendWatcher.restore(source, native_id, checkpoint)
    return JsonlAppendWatcher.restore(source, checkpoint)


__all__ = ["text_content", "normalize", "watcher_for", "restore_watcher"]
