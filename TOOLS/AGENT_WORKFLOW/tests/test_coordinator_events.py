import sys
from pathlib import Path
import json
import os
import subprocess

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import coordinator_events as events


def test_change_survives_restart_without_duplicate_and_is_session_scoped(tmp_path):
    source = tmp_path / "result.md"
    source.write_text("running")
    path = tmp_path / "events.sqlite3"
    with events.connect(path) as db:
        events.add_watch(db, "session-one", source)
        assert events.poll(db, "session-one") == []
    source.write_text("complete")
    with events.connect(path) as db:
        found = events.poll(db, "session-one")
        assert len(found) == 1
        assert found[0]["kind"] == "file_changed"
        assert events.poll(db, "session-one") == found
        assert events.poll(db, "session-other") == []
        assert db.execute("SELECT COUNT(*) FROM events").fetchone()[0] == 1


def test_deadline_fires_once_without_file_change(tmp_path):
    with events.connect(tmp_path / "events.sqlite3") as db:
        events.add_watch(db, "session-one", tmp_path / "future.md", deadline=100)
        assert events.poll(db, "session-one", now=99) == []
        assert events.poll(db, "session-one", now=100)[0]["kind"] == "deadline"
        events.poll(db, "session-one", now=101)
        assert db.execute("SELECT COUNT(*) FROM events").fetchone()[0] == 1


def test_deleted_then_recreated_source_is_reported(tmp_path):
    source = tmp_path / "result.md"
    source.write_text("first")
    with events.connect(tmp_path / "events.sqlite3") as db:
        events.add_watch(db, "session-one", source)
        source.unlink()
        assert events.poll(db, "session-one")[-1]["kind"] == "source_missing"
        source.write_text("second")
        assert events.poll(db, "session-one")[-1]["kind"] == "file_changed"


def test_real_cli_wait_wakes_on_deadline_and_keeps_event_until_ack(tmp_path):
    """Vrai processus en attente, pas une simulation du temps dans le moteur."""
    script = Path(events.__file__)
    env = dict(os.environ, LOCALAPPDATA=str(tmp_path), PYTHONIOENCODING="utf-8")
    base = [sys.executable, str(script), "--session", "isolated-native-session-001"]

    def invoke(*args):
        result = subprocess.run(base + list(args), env=env, capture_output=True,
                                encoding="utf-8", timeout=8)
        assert result.returncode == 0, result.stderr
        return json.loads(result.stdout)

    invoke("add", str(tmp_path / "expected-proof.md"), "--deadline-seconds", "0.2")
    found = invoke("wait", "--duration", "2", "--interval", "0.05")
    assert len(found) == 1
    assert found[0]["kind"] == "deadline"
    assert invoke("poll") == found
    assert invoke("ack", str(found[0]["id"])) == {"acknowledged": True}
    assert invoke("poll") == []
