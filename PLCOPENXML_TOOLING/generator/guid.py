from __future__ import annotations

import uuid

# Fixed namespace for this tool, derived once via uuid5(NAMESPACE_URL, <project url>)
# and hardcoded here so every run (and every machine) produces the same GUIDs for
# the same (kind, name) pair. CODESYS's PLCopenXML import matches objects by name
# (ObjectId carries handleUnknown="discard"), so a deterministic-but-arbitrary GUID
# is functionally equivalent to a fresh uuid4() while staying reproducible.
NAMESPACE = uuid.UUID("d324621e-aec2-5068-901d-dec6f6f42f5a")


def object_guid(kind: str, name: str) -> str:
    return str(uuid.uuid5(NAMESPACE, f"{kind}:{name}"))
