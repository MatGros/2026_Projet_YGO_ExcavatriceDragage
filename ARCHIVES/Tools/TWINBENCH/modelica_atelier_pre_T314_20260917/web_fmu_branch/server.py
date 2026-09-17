"""Atelier local M1/M2/M3 sur FMU OpenModelica, sans liaison au PLC réel."""
from __future__ import annotations

import argparse
from collections import deque
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import math
from pathlib import Path
import subprocess
import threading
import time
from urllib.parse import parse_qs, urlparse
import webbrowser

from dredge_runtime import M3ShadowEngine, WinchShadowEngine, STEP_S, installation

HERE = Path(__file__).resolve().parent
MODEL_FILE = HERE / "Dredge.mo"

SIGNAL_CATALOG = [
    {"key": "m3", "label": "Commande M3", "role": "cmd", "group": "M3", "unit": "-1..1"},
    {"key": "m1", "label": "Commande M1", "role": "cmd", "group": "M1", "unit": "-1..1"},
    {"key": "m2", "label": "Commande M2", "role": "cmd", "group": "M2", "unit": "-1..1"},
    {"key": "speed", "label": "Consigne vitesse", "role": "cmd", "group": "Conduite", "unit": "%"},
    {"key": "held", "label": "Homme-mort", "role": "cmd", "group": "Conduite", "unit": "0/1"},
    {"key": "positionM", "label": "Position chariot", "role": "state", "group": "M3", "unit": "m"},
    {"key": "velocityMps", "label": "Vitesse chariot", "role": "state", "group": "M3", "unit": "m/s"},
    {"key": "actualFrequencyHz", "label": "Fréquence variateur", "role": "output", "group": "M3", "unit": "Hz"},
    {"key": "brakeIsOpenDI", "label": "Frein M3 ouvert", "role": "output", "group": "M3", "unit": "0/1"},
    {"key": "posTremieDI", "label": "Capteur Trémie", "role": "output", "group": "M3", "unit": "0/1"},
    {"key": "posPVDI", "label": "Capteur PV", "role": "output", "group": "M3", "unit": "0/1"},
    {"key": "posP2DI", "label": "Capteur P2", "role": "output", "group": "M3", "unit": "0/1"},
    {"key": "posP1DI", "label": "Capteur P1", "role": "output", "group": "M3", "unit": "0/1"},
    {"key": "posMaintenanceDI", "label": "Capteur Maintenance", "role": "output", "group": "M3", "unit": "0/1"},
    {"key": "commandConflict", "label": "Conflit directions M3", "role": "fault", "group": "M3", "unit": "0/1"},
    {"key": "m1CablePositionM", "label": "Longueur câble M1", "role": "state", "group": "M1", "unit": "m"},
    {"key": "m1VelocityMps", "label": "Vitesse câble M1", "role": "state", "group": "M1", "unit": "m/s"},
    {"key": "m1BrakeIsOpenDI", "label": "Frein M1 ouvert", "role": "output", "group": "M1", "unit": "0/1"},
    {"key": "m1DirectionConflict", "label": "Conflit directions M1", "role": "fault", "group": "M1", "unit": "0/1"},
    {"key": "m2CablePositionM", "label": "Longueur câble M2", "role": "state", "group": "M2", "unit": "m"},
    {"key": "m2VelocityMps", "label": "Vitesse câble M2", "role": "state", "group": "M2", "unit": "m/s"},
    {"key": "m2BrakeIsOpenDI", "label": "Frein M2 ouvert", "role": "output", "group": "M2", "unit": "0/1"},
    {"key": "m2DirectionConflict", "label": "Conflit directions M2", "role": "fault", "group": "M2", "unit": "0/1"},
    {"key": "bucketDeltaM", "label": "Différentiel M2-M1", "role": "state", "group": "Benne", "unit": "m"},
    {"key": "bucketOpeningPct", "label": "Ouverture benne", "role": "output", "group": "Benne", "unit": "%"},
    {"key": "bucketOpenDI", "label": "Benne ouverte", "role": "output", "group": "Benne", "unit": "0/1"},
    {"key": "bucketClosedDI", "label": "Benne fermée", "role": "output", "group": "Benne", "unit": "0/1"},
]


class Bench:
    def __init__(self):
        self.lock = threading.RLock()
        self.m3 = None
        self.winches = None
        self.ready = False
        self.error = ""
        self.running = False
        self.shutdown = False
        self.controls = dict(m3=0, m1=0, m2=0, speed=70.0, held=False)
        self.last_input = 0.0
        self.frames = deque(maxlen=30_000)
        self.events = deque(maxlen=100)
        self.seq = 0
        self.epoch = 0
        self.scenario = "manual"
        self.scenario_start = 0.0
        self.scenario_phase = ""
        self.bucket_closed_since = None
        self.step_ms = 0.0
        self.config = dict(
            travelM=30.0,
            fullTravelTimeS=8.0,
            minSpeedMps=1.0,
            maxSpeedMps=2.0,
            bucketClosedDeltaM=15.0,
        )

    def event(self, message):
        stamp = self.m3.t if self.m3 else 0.0
        self.events.appendleft({"t": round(stamp, 2), "message": message})

    def neutralize(self):
        self.controls.update(m1=0, m2=0, m3=0, held=False)

    def load_engines(self):
        self.ready = False
        self.error = ""
        try:
            if self.m3:
                self.m3.close()
            if self.winches:
                self.winches.close()
            self.m3 = M3ShadowEngine()
            self.winches = WinchShadowEngine()
            self.ready = True
            self.event("Dredge.mo compilé · FMU OpenModelica chargées")
        except Exception as exc:
            self.error = str(exc)
            self.event("Échec OpenModelica : " + self.error)
            raise

    def start(self):
        try:
            self.load_engines()
        except Exception:
            pass
        due = time.perf_counter()
        while not self.shutdown:
            with self.lock:
                try:
                    if self.running and self.ready and not self.error:
                        begin = time.perf_counter()
                        command = self.controls.copy()
                        if self.scenario == "grab":
                            command = self.grab_command(command)
                        elif time.monotonic() - self.last_input > 0.35:
                            if any(command[k] for k in ("m1", "m2", "m3")) or command["held"]:
                                self.event("Heartbeat perdu · commandes neutralisées")
                            self.neutralize()
                            command = self.controls.copy()
                        if not command["held"]:
                            command.update(m1=0, m2=0, m3=0)
                        frame = self.step(command)
                        self.step_ms = (time.perf_counter() - begin) * 1000
                        self.seq += 1
                        frame.update(seq=self.seq, t=self.m3.t, source=self.scenario,
                                     scenarioPhase=self.scenario_phase)
                        self.frames.append(frame)
                    else:
                        due = time.perf_counter()
                except Exception as exc:
                    self.error = str(exc)
                    self.running = False
                    self.neutralize()
                    self.event("Simulation arrêtée : " + self.error)
            due += STEP_S
            delay = due - time.perf_counter()
            if delay < -0.2:
                due = time.perf_counter()
                delay = 0
            time.sleep(max(0, delay))

    def grab_command(self, command):
        elapsed = self.m3.t - self.scenario_start
        command.update(m3=0, m1=0, m2=0, held=True, speed=70.0)
        if elapsed < 1.0:
            self.scenario_phase = "Préparation"
        else:
            closed = bool(self.frames and self.frames[-1].get("bucketClosedDI", 0) > 0.5)
            if not closed:
                self.scenario_phase = "Fermeture benne"
                command["m2"] = 1
            elif self.bucket_closed_since is None:
                self.bucket_closed_since = self.m3.t
                self.scenario_phase = "Validation benne fermée"
                self.event("Benne fermée observée · validation 300 ms")
            elif self.m3.t - self.bucket_closed_since < 0.3:
                self.scenario_phase = "Validation benne fermée"
            elif self.m3.t - self.bucket_closed_since < 5.3:
                self.scenario_phase = "Remontée M1 + M2"
                command.update(m1=-1, m2=-1)
            else:
                self.scenario_phase = "Terminé"
                self.scenario = "manual"
                self.neutralize()
                command.update(m1=0, m2=0, m3=0, held=False)
                self.event("Scénario fermeture puis remontée terminé")
        return command

    def step(self, command):
        m3_direction = command["m3"]
        m3_frame = self.m3.step(
            req_tremie=float(m3_direction < 0),
            req_maintenance=float(m3_direction > 0),
            speed_cmd_pct=command["speed"] if m3_direction else 0,
            brake_release_cmd=float(bool(m3_direction)),
        )
        winch_input = {}
        for key in ("m1", "m2"):
            direction = command[key]
            winch_input[key + "RelayFwd"] = float(direction > 0)
            winch_input[key + "RelayRev"] = float(direction < 0)
            winch_input[key + "BrakeReleaseCmd"] = float(bool(direction))
            winch_input[key + "StepNumber"] = 3 if direction else 0
        winch_frame = self.winches.step(winch_input)
        return dict(
            **command,
            **{k: v for k, v in m3_frame.items() if k != "timestampS"},
            **{k: v for k, v in winch_frame.items() if k != "timestampS"},
        )

    def reset(self):
        self.running = False
        self.scenario = "manual"
        self.scenario_phase = ""
        self.bucket_closed_since = None
        self.neutralize()
        self.m3.reset({k: self.config[k] for k in ("travelM", "fullTravelTimeS")})
        self.winches.reset({k: self.config[k] for k in ("minSpeedMps", "maxSpeedMps", "bucketClosedDeltaM")})
        self.frames.clear()
        self.seq = 0
        self.epoch += 1
        self.event("Simulation réinitialisée")

    def command(self, value):
        action = value.get("action")
        if action == "open_omedit":
            executable = installation() / "bin" / "OMEdit.exe"
            subprocess.Popen([str(executable), str(MODEL_FILE)], close_fds=True)
            self.event("Dredge.mo ouvert dans OMEdit")
            return
        if action == "reload_model":
            self.running = False
            self.neutralize()
            self.load_engines()
            self.frames.clear()
            self.seq = 0
            self.epoch += 1
            self.event("Modèle sauvegardé rechargé depuis Dredge.mo")
            return
        if not self.ready or self.error:
            raise ValueError(self.error or "Compilation des FMU en cours")
        if action == "input":
            if self.scenario != "manual":
                return
            directions = {key: int(value.get(key, 0)) for key in ("m3", "m1", "m2")}
            speed = float(value.get("speed", 70))
            held = value.get("held") is True
            if (any(direction not in (-1, 0, 1) for direction in directions.values())
                    or not math.isfinite(speed) or not 0 <= speed <= 100):
                raise ValueError("Commande hors plage")
            self.controls.update(directions, speed=speed, held=held)
            self.last_input = time.monotonic()
        elif action == "play":
            self.running = True
            self.last_input = time.monotonic()
            self.event("Simulation démarrée")
        elif action == "pause":
            self.running = False
            self.neutralize()
            self.event("Simulation en pause · commandes neutralisées")
        elif action == "reset":
            self.reset()
        elif action == "config":
            candidate = self.config.copy()
            for key in candidate:
                if key in value:
                    candidate[key] = float(value[key])
            if not (1 <= candidate["travelM"] <= 100
                    and 0.2 <= candidate["fullTravelTimeS"] <= 60
                    and 0.05 <= candidate["minSpeedMps"] <= candidate["maxSpeedMps"] <= 10
                    and 0.1 <= candidate["bucketClosedDeltaM"] <= 100):
                raise ValueError("Configuration physique hors plage")
            self.config = candidate
            self.reset()
            self.event("Paramètres Modelica appliqués")
        elif action == "scenario" and value.get("name") == "grab":
            self.reset()
            self.scenario = "grab"
            self.scenario_start = self.m3.t
            self.bucket_closed_since = None
            self.running = True
            self.event("Scénario fermeture benne puis remontée lancé")
        else:
            raise ValueError("Action inconnue")

    def snapshot(self, after):
        return dict(
            ready=self.ready,
            error=self.error,
            running=self.running,
            scenario=self.scenario,
            scenarioPhase=self.scenario_phase,
            epoch=self.epoch,
            frames=[frame for frame in self.frames if frame["seq"] > after],
            config=self.config,
            last=self.frames[-1] if self.frames else {},
            events=list(self.events),
            signalCatalog=SIGNAL_CATALOG,
            stepMs=round(self.step_ms, 3),
            modelFile=str(MODEL_FILE),
            engine="OpenModelica + OMSimulator",
        )

    def close(self):
        self.shutdown = True
        self.running = False
        self.neutralize()
        if self.m3:
            self.m3.close()
        if self.winches:
            self.winches.close()


BENCH = Bench()


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def send(self, value, kind="application/json", status=200, filename=None):
        body = value if isinstance(value, bytes) else value.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", kind + "; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        if filename:
            self.send_header("Content-Disposition", f'attachment; filename="{filename}"')
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        url = urlparse(self.path)
        static = {
            "/": ("index.html", "text/html"),
            "/app.js": ("app.js", "text/javascript"),
            "/style.css": ("style.css", "text/css"),
        }
        if url.path in static:
            filename, mime = static[url.path]
            return self.send((HERE / filename).read_bytes(), mime)
        if url.path == "/state":
            try:
                after = max(0, int(parse_qs(url.query).get("after", [0])[0]))
            except ValueError:
                return self.send('{"error":"after invalide"}', status=400)
            with BENCH.lock:
                return self.send(json.dumps(BENCH.snapshot(after), ensure_ascii=False))
        if url.path == "/model":
            return self.send(MODEL_FILE.read_bytes(), "text/plain", filename="Dredge.mo")
        return self.send('{"error":"route inconnue"}', status=404)

    def do_POST(self):
        origin = self.headers.get("Origin")
        if origin and origin != f'http://{self.headers.get("Host")}':
            return self.send('{"error":"origine refusée"}', status=403)
        if self.path != "/command":
            return self.send('{"error":"route inconnue"}', status=404)
        try:
            size = int(self.headers.get("Content-Length", "0"))
            if not 0 < size <= 8192:
                raise ValueError("Taille de commande invalide")
            payload = json.loads(self.rfile.read(size))
            with BENCH.lock:
                BENCH.command(payload)
            self.send('{"ok":true}')
        except (BrokenPipeError, ConnectionAbortedError, ConnectionResetError):
            return
        except (ValueError, TypeError, KeyError, RuntimeError) as exc:
            self.send(json.dumps({"error": str(exc)}, ensure_ascii=False), status=400)
        except Exception as exc:
            self.send(json.dumps({"error": str(exc)}, ensure_ascii=False), status=500)


def main():
    parser = argparse.ArgumentParser(description="Atelier OpenModelica TwinBench")
    parser.add_argument("--port", type=int, default=8777)
    parser.add_argument("--no-browser", action="store_true")
    args = parser.parse_args()
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    worker = threading.Thread(target=BENCH.start, daemon=True)
    worker.start()
    url = f"http://127.0.0.1:{args.port}"
    print(f"TwinBench OpenModelica : {url} — Ctrl+C pour fermer", flush=True)
    if not args.no_browser:
        webbrowser.open(url)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        BENCH.close()
        server.server_close()


if __name__ == "__main__":
    main()
