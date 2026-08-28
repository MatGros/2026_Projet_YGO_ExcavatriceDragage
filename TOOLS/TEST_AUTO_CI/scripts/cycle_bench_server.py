#!/usr/bin/env python3
"""Serveur du banc de test web interactif FB_Cycle (T173).

Spawn le moteur compilé (cycle_engine.exe) en processus persistant et expose :
  GET  /            -> page HTML du banc
  POST /scan        -> {stimuli:{...}} -> exécute UN scan du binaire, renvoie {outputs:{...}}
  POST /reset       -> relance le moteur (état FB remis à zéro)

Le JS navigateur n'envoie que des stimuli et affiche les sorties — AUCUNE logique
métier en JS. Le binaire compilé (WORKING_COPY) décide.

Usage :
    python TOOLS/TEST_AUTO_CI/scripts/cycle_bench_server.py [--port 8080]
"""

import argparse
import json
import pathlib
import subprocess
import sys
import threading

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

REPO_ROOT = pathlib.Path(__file__).resolve().parents[3]
ENGINE = REPO_ROOT / "TOOLS" / "TEST_AUTO_CI" / "engine" / "cycle_engine.exe"
BENCH_HTML = REPO_ROOT / "TOOLS" / "TEST_AUTO_CI" / "engine" / "cycle_bench.html"

_lock = threading.Lock()
_proc = None


def _start_engine():
    global _proc
    if _proc is not None:
        try:
            _proc.kill()
        except Exception:
            pass
    _proc = subprocess.Popen(
        [str(ENGINE)],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        text=True, encoding="utf-8", bufsize=1,
    )


def _run_scan(stimuli: dict) -> dict:
    """Envoie les stimuli au moteur, lit la ligne de sortie, renvoie {key: value}."""
    global _proc
    with _lock:
        if _proc is None or _proc.poll() is not None:
            _start_engine()
        line = " ".join(f"{k}={v}" for k, v in stimuli.items())
        _proc.stdin.write(line + "\n")
        _proc.stdin.flush()
        out = _proc.stdout.readline()
    if not out:
        raise RuntimeError("moteur sans réponse (processus mort ?)")
    outputs = {}
    for tok in out.strip().split():
        if "=" in tok:
            k, v = tok.split("=", 1)
            outputs[k] = v
    return outputs


def _handle_scan(handler, body: dict):
    stimuli = body.get("stimuli", {})
    try:
        outputs = _run_scan(stimuli)
        _send_json(handler, 200, {"ok": True, "outputs": outputs})
    except Exception as exc:
        _send_json(handler, 500, {"ok": False, "error": str(exc)})


def _handle_reset(handler, body: dict):
    with _lock:
        _start_engine()
    _send_json(handler, 200, {"ok": True})


def _send_json(handler, code: int, obj: dict):
    data = json.dumps(obj, ensure_ascii=False).encode("utf-8")
    handler.send_response(code)
    handler.send_header("Content-Type", "application/json; charset=utf-8")
    handler.send_header("Content-Length", str(len(data)))
    handler.end_headers()
    handler.wfile.write(data)


def _serve(handler):
    from http.server import BaseHTTPRequestHandler

    class H(BaseHTTPRequestHandler):
        def log_message(self, *a):
            pass

        def _read_body(self):
            length = int(self.headers.get("Content-Length", 0))
            if length <= 0:
                return {}
            raw = self.rfile.read(length)
            try:
                return json.loads(raw.decode("utf-8"))
            except Exception:
                return {}

        def do_GET(self):
            if self.path in ("/", "/index.html"):
                html = BENCH_HTML.read_bytes()
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Content-Length", str(len(html)))
                self.end_headers()
                self.wfile.write(html)
            else:
                self.send_response(404)
                self.end_headers()

        def do_POST(self):
            body = self._read_body()
            if self.path == "/scan":
                _handle_scan(self, body)
            elif self.path == "/reset":
                _handle_reset(self, body)
            else:
                self.send_response(404)
                self.end_headers()

    return H


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8080)
    args = parser.parse_args()

    if not ENGINE.exists():
        print(f"[ERREUR] Moteur introuvable : {ENGINE} — lancer build_cycle_engine.py d'abord")
        return 1
    if not BENCH_HTML.exists():
        print(f"[ERREUR] Page banc introuvable : {BENCH_HTML}")
        return 1

    from http.server import ThreadingHTTPServer
    _start_engine()
    # Port bloqué (ex. WinError 10013 sur 8080) ? On tente les suivants et on affiche l'URL réelle.
    httpd = None
    port = args.port
    for attempt in range(20):
        try:
            httpd = ThreadingHTTPServer(("127.0.0.1", port), _serve(None))
            break
        except OSError as exc:
            print(f"[INFO] Port {port} refusé ({exc}) — essai port {port+1}")
            port += 1
    if httpd is None:
        print("[ERREUR] Aucun port libre trouvé (blocage réseau ?)")
        return 1
    print(f"✅ Banc de test web : http://127.0.0.1:{port}")
    print(f"   moteur = {ENGINE.name} (WORKING_COPY/FB_Cycle.st compilé)")
    print("   Ctrl+C pour arrêter")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        with _lock:
            if _proc is not None:
                try:
                    _proc.kill()
                except Exception:
                    pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
