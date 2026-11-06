"""Read-only incremental adapter for DSH's append-only JSONL/Zstandard logs."""
from __future__ import annotations

import base64
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

try:
    from .session_watcher import PollResult
except ImportError:
    from session_watcher import PollResult


DECODER = Path(__file__).with_name("dsh_zstd_decode.mjs")


def decode(path: Path, session_id: str, offset: int | str):
    node = shutil.which("node")
    if not node:
        raise OSError("node_unavailable")
    result = subprocess.run([node, str(DECODER), str(path), session_id, str(offset)],
                            capture_output=True, check=False, timeout=15)
    if result.returncode:
        raise ValueError(result.stderr.decode("utf-8", "replace")[:160])
    try:
        return json.loads(result.stdout.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ValueError("dsh_decoder_invalid_response") from exc


class DshJsonlAppendWatcher:
    """Check exact compressed prefix integrity and consume only newly appended frames."""

    def __init__(self, path: Path, session_id: str, *, start_at_end: bool = True):
        self.path = Path(path)
        self.session_id = session_id
        self._suspended = False
        self._pending = b""
        self._parse_error = None
        self._attach_error = None
        self.offset = 0
        self._identity = None
        self.last_stamp = None
        self._prefix_digest = hashlib.sha256().digest()
        try:
            before = self.path.stat()
            decoded = decode(self.path, self.session_id, "tail" if start_at_end else 0)
            after = self.path.stat()
            if (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns) != (after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns):
                raise OSError("source_changed_during_attachment")
            if decoded["header"].get("id") != session_id:
                raise ValueError("session_id_mismatch")
            self.offset = decoded["complete_end"] if start_at_end else 0
            self._identity = (after.st_dev, after.st_ino)
            self._prefix_digest = self._digest_prefix(self.offset)
            self.last_stamp = (after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns, after.st_ctime_ns)
            if not start_at_end:
                self._pending = base64.b64decode(decoded["payload"], validate=True)
        except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as exc:
            self._attach_error = str(exc)[:160] or type(exc).__name__

    def _digest_prefix(self, size):
        digest = hashlib.sha256()
        with self.path.open("rb") as stream:
            remaining = size
            while remaining:
                data = stream.read(min(remaining, 65536))
                if not data:
                    raise OSError("source_changed_during_read")
                digest.update(data)
                remaining -= len(data)
        return digest.digest()

    def reattach(self, *, start_at_end=True):
        self.__init__(self.path, self.session_id, start_at_end=start_at_end)

    def poll(self):
        if self._attach_error:
            return PollResult("source_error", [], self._attach_error)
        if self._parse_error:
            return PollResult("parse_error", [], self._parse_error)
        if self._suspended:
            return PollResult("source_reset", [])
        try:
            before = self.path.stat()
        except FileNotFoundError:
            return PollResult("source_missing", [])
        except OSError as exc:
            return PollResult("source_error", [], type(exc).__name__)
        identity = (before.st_dev, before.st_ino)
        if identity != self._identity or before.st_size < self.offset:
            self._suspended = True
            return PollResult("source_reset", [])
        try:
            if self._digest_prefix(self.offset) != self._prefix_digest:
                self._suspended = True
                return PollResult("source_reset", [])
            decoded = decode(self.path, self.session_id, self.offset)
            after = self.path.stat()
            if (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns) != (after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns):
                return PollResult("source_error", [], "source_changed_during_read")
            if decoded["header"].get("id") != self.session_id:
                self._suspended = True
                return PollResult("source_reset", [])
            new_offset = decoded["complete_end"]
            if new_offset < self.offset:
                self._suspended = True
                return PollResult("source_reset", [])
            chunk = base64.b64decode(decoded["payload"], validate=True)
            self.offset = new_offset
            self._prefix_digest = self._digest_prefix(self.offset)
            self.last_stamp = (after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns, after.st_ctime_ns)
        except FileNotFoundError:
            return PollResult("source_missing", [])
        except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as exc:
            return PollResult("source_error", [], str(exc)[:160] or type(exc).__name__)

        rows = (self._pending + chunk).split(b"\n")
        self._pending = rows.pop()
        events = []
        for row in rows:
            if not row.strip():
                continue
            try:
                value = json.loads(row.decode("utf-8"))
            except (UnicodeDecodeError, json.JSONDecodeError) as exc:
                self._parse_error = type(exc).__name__
                return PollResult("parse_error", events, self._parse_error)
            if not isinstance(value, dict):
                self._parse_error = "record_not_object"
                return PollResult("parse_error", events, self._parse_error)
            events.append(value)
        return PollResult("active", events)


def read_events(path: Path, session_id: str, *, max_file_bytes: int = 2 * 1024 * 1024):
    """Read a bounded DSH history on explicit UI request, never as live replay."""
    path = Path(path)
    before = path.stat()
    if before.st_size > max_file_bytes:
        raise ValueError("Historique DSH trop volumineux pour la lecture bornée")
    decoded = decode(path, session_id, "all")
    after = path.stat()
    if (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns) != (after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns):
        raise OSError("Source modifiée pendant la lecture")
    if decoded["header"].get("id") != session_id:
        raise ValueError("Identifiant DSH différent de la session demandée")
    raw = base64.b64decode(decoded["payload"], validate=True)
    truncated = len(raw) > 512 * 1024
    if truncated:
        raw = raw[-512 * 1024:]
        raw = raw[raw.find(b"\n") + 1:] if b"\n" in raw else b""
    events = []
    for row in raw.splitlines():
        if not row.strip():
            continue
        item = json.loads(row.decode("utf-8"))
        if not isinstance(item, dict):
            raise ValueError("Contenu DSH invalide")
        events.append(item)
    return events, truncated
