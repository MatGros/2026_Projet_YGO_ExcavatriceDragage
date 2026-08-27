"""Garde-fou API Task Manager : verrous, conflits et RAZ sans ecriture metier."""
from __future__ import annotations

import json
import subprocess
import sys
import time
import unittest
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[2]
PORT = 8093
BASE = f"http://127.0.0.1:{PORT}"


def request(path: str, payload: dict | None = None):
    data = json.dumps(payload, ensure_ascii=False).encode("utf-8") if payload is not None else None
    req = Request(BASE + path, data=data, headers={"Content-Type": "application/json"} if data else {})
    with urlopen(req, timeout=5) as response:
        return response.status, json.loads(response.read().decode("utf-8"))


class TaskManagerApiTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = subprocess.Popen([sys.executable, "TOOLS/TASK_MANAGER/task_server.py", str(PORT)], cwd=ROOT)
        for _ in range(30):
            try:
                request("/api/status")
                return
            except OSError:
                time.sleep(0.1)
        raise RuntimeError("serveur Task Manager non demarre")

    @classmethod
    def tearDownClass(cls):
        cls.server.terminate()
        cls.server.wait(timeout=5)

    def test_lock_conflict_revision_and_global_reset(self):
        _, values = request("/api/tasks/json")
        task = next(value for value in values if value["id"] == "T162")
        revision = task.pop("revision")
        task.pop("edit_flag")
        task.pop("work_lock")
        _, locked = request("/api/task/edit-flag/acquire", {"id": "T162", "actor": "TEST-A"})
        token = locked["edit_flag"]["token"]
        with self.assertRaises(HTTPError) as locked_by_other:
            request("/api/task/edit-flag/acquire", {"id": "T162", "actor": "TEST-B"})
        self.assertEqual(locked_by_other.exception.code, 423)
        locked_by_other.exception.close()
        with self.assertRaises(HTTPError) as obsolete:
            request("/api/task/save", {"actor": "TEST-A", "token": token, "expected_revision": "obsolete", "task": task})
        self.assertEqual(obsolete.exception.code, 409)
        obsolete.exception.close()
        _, reset = request("/api/tasks/unlock-all", {"actor": "TEST-HUM", "confirm_all": True})
        self.assertGreaterEqual(reset["cleared"], 1)
        _, after = request("/api/tasks/json")
        self.assertEqual(revision, next(value for value in after if value["id"] == "T162")["revision"])


if __name__ == "__main__":
    unittest.main()
