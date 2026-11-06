"""POC Codex queue: creates its own synthetic sessions; never uses existing IDs.

Run: python TOOLS/AGENT_SUPERVISOR/poc/routage/codex_probe.py
Each run saves raw output under a fresh system-temp folder and prints its location.
This deliberately leaves sessions and evidence in place, with no automatic cleanup.
"""
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import uuid


def parse_codex_response(stdout, expected_thread):
    """Require the expected thread and an actual completed agent message."""
    threads = []
    messages = []
    for line in stdout.splitlines():
        try:
            event = json.loads(line)
        except (ValueError, TypeError):
            continue
        if not isinstance(event, dict):
            continue
        if event.get('type') == 'thread.started':
            threads.append(event.get('thread_id'))
        item = event.get('item')
        if event.get('type') == 'item.completed' and isinstance(item, dict) and item.get('type') == 'agent_message':
            messages.append(item.get('text'))
    if threads != [expected_thread] or not messages or not isinstance(messages[-1], str):
        raise ValueError('thread inattendu ou message assistant absent')
    return messages[-1].strip()


def main():
    root = Path(tempfile.mkdtemp(prefix="veilleur-routage-codex-"))
    exe = "codex.exe" if os.name == "nt" else "codex"
    marker = "POC_ALERTE_" + uuid.uuid4().hex[:12].upper()
    evidence = {"marker": marker, "platform": "codex", "stages": []}

    def invoke(name, arguments):
        try:
            p = subprocess.run([exe, *arguments], cwd=root, stdin=subprocess.DEVNULL,
                               capture_output=True, text=True, encoding="utf-8",
                               errors="replace", timeout=150)
            record = {"stage": name, "args": arguments, "exit_code": p.returncode,
                      "stdout": p.stdout, "stderr": p.stderr}
        except subprocess.TimeoutExpired as exc:
            record = {"stage": name, "args": arguments, "exit_code": None,
                      "stdout": str(exc.stdout or ""), "stderr": "timeout 150s"}
        evidence["stages"].append(record)
        (root / "evidence.json").write_text(json.dumps(evidence, ensure_ascii=False, indent=2), encoding="utf-8")
        print(name, "exit=", record["exit_code"], flush=True)
        return record

    def create(name):
        p = invoke(name, ["exec", "--skip-git-repo-check", "-s", "read-only", "--json",
                          "POC synthétique : réponds uniquement PRET. Aucun outil."])
        match = re.search(r'"type"\s*:\s*"thread.started"\s*,\s*"thread_id"\s*:\s*"([0-9a-f-]+)"', p["stdout"])
        if p["exit_code"] != 0 or not match:
            raise RuntimeError("Session synthétique non créée ; arrêt sans envoi")
        return match.group(1)

    try:
        first = create("create_A")
        second = create("create_B")
        assert first != second
        queued = invoke("queue_A", ["queue", "--thread", first, "--message", marker])
        if queued["exit_code"] != 0:
            raise RuntimeError("Mise en file échouée ; aucune preuve de réception")
        prompt = "Si une alerte POC est présente, cite son identifiant exact ; sinon réponds AUCUNE. Aucun outil."
        def resume(name, thread):
            return invoke(name, ["exec", "--skip-git-repo-check", "-s", "read-only", "--json",
                                 "resume", thread, prompt])
        a = resume("resume_A", first)
        b = resume("resume_B", second)
        answer_a = parse_codex_response(a['stdout'], first)
        answer_b = parse_codex_response(b['stdout'], second)
        evidence['parsed_answers'] = {'A': answer_a, 'B': answer_b}
        evidence["verdict"] = {"distinct_sessions": first != second,
                               "A_exact": answer_a == marker,
                               "B_absent": answer_b == 'AUCUNE',
                               "resumes_exit_zero": a["exit_code"] == b["exit_code"] == 0}
        (root / "evidence.json").write_text(json.dumps(evidence, ensure_ascii=False, indent=2), encoding="utf-8")
        print(json.dumps(evidence["verdict"], ensure_ascii=False), flush=True)
        if not (evidence["verdict"]["A_exact"] and evidence["verdict"]["B_absent"] and evidence["verdict"]["resumes_exit_zero"]):
            raise RuntimeError("Réception ou isolation non démontrée")
    finally:
        print("EVIDENCE:", root / "evidence.json", flush=True)


if __name__ == "__main__":
    main()
