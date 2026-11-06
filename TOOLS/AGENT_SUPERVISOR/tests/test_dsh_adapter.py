import json
from pathlib import Path
import shutil
import subprocess

import pytest

from TOOLS.AGENT_SUPERVISOR.scripts.dsh_session_watcher import DshJsonlAppendWatcher
from TOOLS.AGENT_SUPERVISOR.scripts.session_watcher import resolve_jsonl_source
from TOOLS.AGENT_SUPERVISOR.scripts.supervisor_service import normalize


pytestmark = pytest.mark.skipif(shutil.which("node") is None, reason="DSH Zstandard adapter needs Node.js")


def append_frame(path: Path, text: str):
    node_script = """
const fs=require('node:fs');const z=require('node:zlib');const c=z.constants;
const body=Buffer.from(process.argv[2]);
fs.appendFileSync(process.argv[1],z.zstdCompressSync(body,{params:{[c.ZSTD_c_checksumFlag]:1}}));
"""
    subprocess.run([shutil.which("node"), "-e", node_script, str(path), text], check=True)


def event(seq, kind, content):
    return json.dumps({"seq": seq, "type": kind, "data": {"content": content}}, ensure_ascii=False) + "\n"


def make_dsh_log(root, session_id):
    session = root / "--workspace--" / session_id
    session.mkdir(parents=True)
    path = session / "session.jsonl.zstd"
    header = {"type": "session", "version": 1, "id": session_id, "createdAt": 1, "delegationDepth": 0}
    append_frame(path, json.dumps(header) + "\n")
    append_frame(path, event(0, "user/message", "avant rattachement"))
    return path


def test_dsh_resolves_only_exact_session_and_reads_new_frames(tmp_path):
    sid = "session-12345678-1234-1234-1234-123456789abc"
    path = make_dsh_log(tmp_path, sid)
    resolved = resolve_jsonl_source(tmp_path, sid, platform="dsh")
    assert resolved.state == "ready"
    assert resolved.path == path

    watcher = DshJsonlAppendWatcher(path, sid)
    assert watcher.poll().events == []
    append_frame(path, event(1, "assistant/message", [{"type": "text", "text": "nouvelle réponse"}]))
    result = watcher.poll()
    assert result.state == "active"
    assert [item["seq"] for item in result.events] == [1]
    assert normalize("dsh", result.events[0]) == ("assistant", "nouvelle réponse")


def test_dsh_rewrite_breaks_prefix_integrity(tmp_path):
    sid = "session-12345678-1234-1234-1234-123456789abc"
    path = make_dsh_log(tmp_path, sid)
    watcher = DshJsonlAppendWatcher(path, sid)
    raw = bytearray(path.read_bytes())
    raw[8] ^= 1
    path.write_bytes(raw)
    assert watcher.poll().state == "source_reset"


def test_dsh_requires_matching_header_and_native_id(tmp_path):
    sid = "session-12345678-1234-1234-1234-123456789abc"
    path = make_dsh_log(tmp_path, sid)
    assert resolve_jsonl_source(tmp_path, "session-aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", platform="dsh").state == "source_missing"
    watcher = DshJsonlAppendWatcher(path, "session-aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")
    assert watcher.poll().state == "source_error"
