"""Independent in-memory routing experiment; this is not Veilleur production code."""
import json

REGISTRY = {("codex", "a"): ["chat-A"], ("codex", "b"): ["chat-B"],
            ("agy", "duplicate"): ["chat-C", "chat-D"]}
sent = []
seen = set()

def send(platform, session_id, alert_id):
    targets = REGISTRY.get((platform, session_id), [])
    if len(targets) == 0:
        return "unknown"
    if len(targets) != 1:
        return "ambiguous"
    key = (platform, session_id, alert_id)
    if key in seen:
        return "duplicate"
    seen.add(key)
    sent.append((targets[0], alert_id))
    return "sent"

checks = [
    ("send-A", send("codex", "a", "alert-1"), "sent"),
    ("send-B", send("codex", "b", "alert-2"), "sent"),
    ("unknown", send("codex", "missing", "alert-3"), "unknown"),
    ("ambiguous", send("agy", "duplicate", "alert-4"), "ambiguous"),
    ("repeat", send("codex", "a", "alert-1"), "duplicate"),
]
for name, actual, expected in checks:
    print(json.dumps({"case": name, "actual": actual, "expected": expected}))
    assert actual == expected
assert sent == [("chat-A", "alert-1"), ("chat-B", "alert-2")]
print(json.dumps({"delivered": sent, "status": "simulation_pass"}))
