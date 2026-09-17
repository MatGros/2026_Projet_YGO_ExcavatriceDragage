"""Atelier local M1/M2/M3. FMU OpenModelica, aucune liaison avec le PLC réel."""
from __future__ import annotations

from collections import deque
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import math
from pathlib import Path
import subprocess
import threading
import time
import webbrowser
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from dredge_runtime import M3ShadowEngine, WinchShadowEngine, STEP_S

HERE = Path(__file__).resolve().parent


class Bench:
    def __init__(self):
        self.lock = threading.RLock()
        self.m3 = None
        self.winches = None
        self.ready = False
        self.error = ""
        self.running = False
        self.controls = dict(m3=0, m1=0, m2=0, speed=70, held=False)
        self.last_input = 0.0
        self.frames = deque(maxlen=30000)
        self.seq = 0
        self.epoch = 0
        self.scenario = "manual"
        self.scenario_start = 0.0
        self.config = dict(travelM=30.0, fullTravelTimeS=8.0,
                           minSpeedMps=1.0, maxSpeedMps=2.0,
                           bucketClosedDeltaM=15.0)

    def start(self):
        try:
            self.m3 = M3ShadowEngine()
            self.winches = WinchShadowEngine()
            self.ready = True
        except Exception as exc:
            self.error = str(exc)
            return
        due = time.perf_counter()
        while True:
            with self.lock:
                try:
                    if self.running:
                        command = self.controls.copy()
                        if self.scenario == "grab":
                            elapsed = self.m3.t - self.scenario_start
                            # La plante provisoire valide la fermeture à 5 % d'ouverture
                            # (delta proche de 14.25 m avec le mouflage actuel).
                            command.update(m3=0, m1=0, m2=1 if 1 <= elapsed < 14.5 else 0,
                                           held=True, speed=70)
                            if elapsed >= 13.5:
                                # Démonstration de séquence sur retour simulé, pas interlock PLC.
                                closed = self.frames[-1]["bucketClosedDI"] > .5 if self.frames else False
                                command.update(m1=-1 if closed and elapsed < 18 else 0,
                                               m2=-1 if closed and elapsed < 18 else 0)
                            if elapsed >= 20:
                                self.scenario = "manual"
                                command.update(m1=0, m2=0)
                                self.controls.update(m1=0, m2=0, held=False)
                        elif time.monotonic() - self.last_input > .35:
                            command.update(m1=0, m2=0, m3=0, held=False)
                        if not command["held"]:
                            command.update(m1=0, m2=0, m3=0)
                        m3 = command["m3"]
                        m3_frame = self.m3.step(req_tremie=float(m3 < 0), req_maintenance=float(m3 > 0),
                            speed_cmd_pct=command["speed"] if m3 else 0,
                            brake_release_cmd=float(bool(m3)))
                        winch_input = {}
                        for key in ("m1", "m2"):
                            direction = command[key]
                            winch_input[key + "RelayFwd"] = float(direction > 0)
                            winch_input[key + "RelayRev"] = float(direction < 0)
                            winch_input[key + "BrakeReleaseCmd"] = float(bool(direction))
                            winch_input[key + "StepNumber"] = 3 if direction else 0
                        winch_frame = self.winches.step(winch_input)
                        self.seq += 1
                        self.frames.append(dict(seq=self.seq, t=self.m3.t, **command,
                            **{k:v for k,v in m3_frame.items() if k not in ("timestampS",)},
                            **{k:v for k,v in winch_frame.items() if k not in ("timestampS",)}))
                    else:
                        due = time.perf_counter()
                except Exception as exc:
                    self.error = str(exc)
                    self.running = False
            due += STEP_S
            delay = due - time.perf_counter()
            if delay < -.2:
                due = time.perf_counter()
                delay = 0
            time.sleep(max(0, delay))

    def command(self, value):
        if not self.ready or self.error:
            raise ValueError(self.error or "Compilation des FMU en cours")
        action = value.get("action")
        if action == "input":
            if self.scenario != "manual":
                return
            directions = {k: int(value.get(k, 0)) for k in ("m3", "m1", "m2")}
            speed = float(value.get("speed", 70))
            if any(d not in (-1, 0, 1) for d in directions.values()) or not math.isfinite(speed) or not 0 <= speed <= 100:
                raise ValueError("Commande hors plage")
            self.controls.update(directions, speed=speed, held=value.get("held") is True)
            self.last_input = time.monotonic()
        elif action == "play":
            self.running = True
        elif action == "pause":
            self.running = False
            self.controls.update(m1=0, m2=0, m3=0, held=False)
        elif action == "reset":
            self.running = False
            self.controls.update(m1=0, m2=0, m3=0, held=False)
            self.scenario = "manual"
            self.m3.reset({k: self.config[k] for k in ("travelM", "fullTravelTimeS")})
            self.winches.reset({k: self.config[k] for k in ("minSpeedMps", "maxSpeedMps", "bucketClosedDeltaM")})
            self.frames.clear()
            self.seq = 0
            self.epoch += 1
        elif action == "config":
            allowed = tuple(self.config)
            candidate = self.config.copy()
            for key in allowed:
                if key in value:
                    candidate[key] = float(value[key])
            if not (1 <= candidate["travelM"] <= 100 and .2 <= candidate["fullTravelTimeS"] <= 60 and
                    .05 <= candidate["minSpeedMps"] <= 10 and .05 <= candidate["maxSpeedMps"] <= 10 and
                    .1 <= candidate["bucketClosedDeltaM"] <= 100 and candidate["maxSpeedMps"] >= candidate["minSpeedMps"]):
                raise ValueError("Configuration physique hors plage")
            self.running = False
            self.controls.update(m1=0, m2=0, m3=0, held=False)
            self.config = candidate
            self.m3.reset({k: candidate[k] for k in ("travelM", "fullTravelTimeS")})
            self.winches.reset({k: candidate[k] for k in ("minSpeedMps", "maxSpeedMps", "bucketClosedDeltaM")})
            self.frames.clear()
            self.seq = 0
            self.epoch += 1
        elif action == "open_omedit":
            model = HERE.parent / "Dredge.mo"
            candidates = [Path(r"C:\Program Files\OpenModelica1.27.1-64bit\bin\OMEdit.exe"),
                          Path(r"C:\Program Files\OpenModelica\bin\OMEdit.exe")]
            executable = next((p for p in candidates if p.exists()), None)
            if executable is None:
                raise ValueError("OMEdit.exe introuvable")
            subprocess.Popen([str(executable), str(model)], close_fds=True)
        elif action == "reload_model":
            self.running = False
            self.controls.update(m1=0, m2=0, m3=0, held=False)
            self.m3.close()
            self.winches.close()
            self.m3 = M3ShadowEngine()
            self.winches = WinchShadowEngine()
            self.frames.clear()
            self.seq = 0
            self.epoch += 1
            self.error = ""
        elif action == "scenario" and value.get("name") == "grab":
            self.m3.reset({k: self.config[k] for k in ("travelM", "fullTravelTimeS")})
            self.winches.reset({k: self.config[k] for k in ("minSpeedMps", "maxSpeedMps", "bucketClosedDeltaM")})
            self.frames.clear()
            self.seq = 0
            self.epoch += 1
            self.scenario = "grab"
            self.scenario_start = 0
            self.running = True
        else:
            raise ValueError("Action inconnue")


BENCH = Bench()


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def send(self, value, kind="application/json", status=200):
        body = value if isinstance(value, bytes) else value.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", kind + "; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        from urllib.parse import urlparse, parse_qs
        url = urlparse(self.path)
        if url.path in ("/", "/interactive.js", "/interactive.css"):
            filename = {"/":"interactive.html", "/interactive.js":"interactive.js", "/interactive.css":"interactive.css"}[url.path]
            mime = {"/":"text/html", "/interactive.js":"text/javascript", "/interactive.css":"text/css"}[url.path]
            return self.send((HERE / filename).read_bytes(), mime)
        if url.path == "/state":
            try:
                after = max(0, int(parse_qs(url.query).get("after", [0])[0]))
            except ValueError:
                return self.send("{}", status=400)
            with BENCH.lock:
                return self.send(json.dumps(dict(ready=BENCH.ready, error=BENCH.error,
                    running=BENCH.running, scenario=BENCH.scenario, epoch=BENCH.epoch,
                    frames=[f for f in BENCH.frames if f["seq"] > after],
                    config=BENCH.config,
                    last=BENCH.frames[-1] if BENCH.frames else {})))
        return self.send("{}", status=404)

    def do_POST(self):
        origin = self.headers.get("Origin")
        if origin and origin != f'http://{self.headers.get("Host")}':
            return self.send("{}", status=403)
        if self.path != "/command":
            return self.send("{}", status=404)
        try:
            size = int(self.headers.get("Content-Length", "0"))
            if not 0 < size <= 1024:
                raise ValueError("Commande trop grande")
            payload = json.loads(self.rfile.read(size))
            with BENCH.lock:
                BENCH.command(payload)
            self.send('{"ok":true}')
        except (ValueError, TypeError, KeyError) as exc:
            self.send(json.dumps({"error":str(exc)}), status=400)


if __name__ == "__main__":
    server = ThreadingHTTPServer(("127.0.0.1", 8777), Handler)
    threading.Thread(target=BENCH.start, daemon=True).start()
    print("Atelier interactif : http://127.0.0.1:8777", flush=True)
    webbrowser.open("http://127.0.0.1:8777")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        BENCH.running = False
        server.server_close()
