"""Supervision HTTP isolation from the existing Task Manager mutation API."""
from http.client import HTTPConnection
import json
import threading
from contextlib import contextmanager
from http.server import ThreadingHTTPServer

from TOOLS.TASK_MANAGER.task_server import Handler


class FakeSupervisor:
    def __init__(self):
        self.commands = []
    def snapshot(self):
        return {"running": False, "sessions": []}
    def command(self, payload):
        self.commands.append(payload)
        if payload.get("action") == "invalid":
            raise ValueError("invalid action")


@contextmanager
def server():
    http = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    http.supervision = FakeSupervisor()
    http.supervision_token = "test-token"
    thread = threading.Thread(target=http.serve_forever, daemon=True)
    thread.start()
    try:
        yield http
    finally:
        http.shutdown()
        http.server_close()
        thread.join(timeout=2)


def request(http, method="GET", headers=None, body=None, path="/api/supervision"):
    connection = HTTPConnection("127.0.0.1", http.server_port)
    connection.request(method, path, body=json.dumps(body) if body else None, headers=headers or {})
    response = connection.getresponse()
    result = response.status, dict(response.getheaders()), json.loads(response.read())
    connection.close()
    return result


def test_read_has_token_without_cross_origin_access():
    with server() as http:
        status, headers, body = request(http)
        assert status == 200 and body["token"] == "test-token"
        assert "Access-Control-Allow-Origin" not in headers
        assert headers["Cache-Control"] == "no-store"
        assert request(http, headers={"Origin": "https://example.org"})[0] == 403
        assert request(http, headers={"Host": f"other.test:{http.server_port}"})[0] == 403


def test_mutation_requires_token_and_local_origin():
    with server() as http:
        assert request(http, "POST", body={"action": "start"})[0] == 403
        assert not http.supervision.commands
        headers = {"X-Supervision-Token": "test-token", "Origin": f"http://127.0.0.1:{http.server_port}"}
        assert request(http, "POST", headers, {"action": "start"})[0] == 200
        assert http.supervision.commands == [{"action": "start"}]
        assert request(http, "POST", headers, {"action": "invalid"})[0] == 400


def test_json_body_must_be_an_object():
    with server() as http:
        assert request(http, "POST", {"X-Supervision-Token": "test-token"}, ["start"])[0] == 400


def test_header_summary_exposes_no_chat_text_or_token():
    with server() as http:
        http.supervision.snapshot = lambda: {"running": True, "chat": {"messages": [{"text": "PRIVATE"}]}, "sessions": [{"alerts": [{"disposition": "new", "evidence": "PRIVATE"}, {"disposition": "seen"}]}]}
        status, headers, body = request(http, path="/api/supervision?summary=1")
        assert status == 200
        assert body == {"running": True, "unread_count": 1}
        assert "PRIVATE" not in json.dumps(body)


def test_real_service_through_http_has_chat_alert_ack_and_pause(tmp_path):
    import time
    from TOOLS.AGENT_WORKFLOW.scripts.agent_supervisor_service import Supervisor
    source = tmp_path / "session-http.jsonl"
    source.touch()
    supervisor = Supervisor(tmp_path / "state.json", roots={"claude": [tmp_path]},
        poll_interval=.02, judge=lambda m, messages: {"alert": True, "severity": "warning", "reason": "Demande de preuve", "evidence": "VALIDATION SANS PREUVE"},
        chat=lambda m, messages: "Analyse consultative de la session choisie")
    def wait_for(predicate):
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline:
            if predicate(): return
            time.sleep(.01)
        assert predicate()
    with server() as http:
        http.supervision = supervisor
        headers = {"X-Supervision-Token": "test-token"}
        def post(body):
            status, _, data = request(http, "POST", headers, body)
            assert status == 200, data
            return data
        try:
            post({"action": "start"})
            data = post({"action": "add", "platform": "claude", "native_id": "session-http", "alias": "Test HTTP", "mission": "Verifier les preuves avant validation"})
            sid = data["sessions"][0]["id"]
            wait_for(lambda: supervisor.snapshot()["sessions"][0]["state"] == "active")
            with source.open("a") as f:
                f.write(json.dumps({"type": "assistant", "message": {"content": [{"type": "text", "text": "VALIDATION SANS PREUVE"}]}}) + "\n")
            wait_for(lambda: bool(supervisor.snapshot()["sessions"][0]["alerts"]))
            assert request(http, path="/api/supervision?summary=1")[2]["unread_count"] == 1
            alert = supervisor.snapshot()["sessions"][0]["alerts"][0]
            post({"action": "acknowledge", "id": sid, "alert_id": alert["id"], "disposition": "seen"})
            assert request(http, path="/api/supervision?summary=1")[2]["unread_count"] == 0
            post({"action": "chat", "session_id": sid, "text": "Explique le constat"})
            wait_for(lambda: any(x["role"] == "assistant" for x in supervisor.snapshot()["chat"]["messages"]))
            post({"action": "reset_chat"})
            assert supervisor.snapshot()["chat"]["messages"] == []
            post({"action": "pause", "id": sid})
            assert supervisor.snapshot()["sessions"][0]["state"] == "paused"
            post({"action": "remove", "id": sid})
            assert supervisor.snapshot()["sessions"] == []
        finally:
            assert supervisor.close()
