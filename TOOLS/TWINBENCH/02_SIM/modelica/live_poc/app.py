from __future__ import annotations

import sys
import time
from collections import deque
from pathlib import Path

from PySide6.QtCore import QObject, Property, QTimer, Qt, Signal, Slot
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuickControls2 import QQuickStyle

UDP_LINK = Path(__file__).parents[3] / "90_PROTOTYPES" / "m3_link"
if str(UDP_LINK) not in sys.path:
    sys.path.insert(0, str(UDP_LINK))
from engine import M3FmuEngine, M3Snapshot, STEP_S
from auto_cycle import AutoCycleController
from plc_readonly_adapter import UdpPlantReadOnlyAdapter

LIVE_WINDOW_S = 20.0               # fenêtre live : un trajet complet de ralentissement
LIVE_WINDOW_POINTS = 2001          # 20 s à 10 ms
LIVE_DRAW_POINTS = 600             # points tracés au maximum (décimation d'affichage)
SENSOR_BITS = ((4, "Trémie"), (3, "PV"), (2, "P2"), (1, "P1"), (0, "Maint"))


class LiveBackend(QObject):
    stateChanged = Signal()
    traceChanged = Signal()
    captureChanged = Signal()
    errorChanged = Signal()

    def __init__(self, source_mode: str = "fmu", telemetry_port: int = 29072) -> None:
        super().__init__()
        self._source_mode = source_mode
        self._engine = M3FmuEngine() if source_mode == "fmu" else None
        self._readonly = UdpPlantReadOnlyAdapter(port=telemetry_port) if source_mode in ("plc-readonly", "gateway-readonly") else None
        # En lecture PLC, la télémétrie doit être consommée sans action opérateur.
        # Le bouton Démarrer reste réservé à la simulation FMU.
        self._running = source_mode in ("plc-readonly", "gateway-readonly")
        self._direction = 0.0
        self._frequency_request = 40.0
        self._auto_cycle_active = False
        self._auto_cycle = AutoCycleController(dwell_s=1.0)
        self._snapshot = self._engine.snapshot() if self._engine is not None else M3Snapshot(
            0.0, 0, 0.0, 0.0, False, 0.0, 0.0, 0.0, 0.0, False, 0, 0,
            False, False, False, False, False, False, False)
        self._error = ""
        self._trace: deque[dict[str, float]] = deque(maxlen=LIVE_WINDOW_POINTS)
        self._frozen_trace: list[dict[str, float]] = []
        self._capture_trigger_time: float | None = None
        self._capture_trigger_index = 0
        self._capture_index = 0
        self._capture_collecting = False
        self._capture_label = ""
        self._previous_hard_stop = self._snapshot.hard_stop_tremie or self._snapshot.hard_stop_maintenance
        self._tick_count = 0
        self._last_plc_sequence: int | None = None
        self._plc_trace_origin_s: float | None = None
        self._started_wall = time.perf_counter()
        self._started_sim = 0.0

        self._timer = QTimer(self)
        self._timer.setTimerType(Qt.TimerType.PreciseTimer)
        self._timer.setInterval(round(STEP_S * 1000))
        self._timer.timeout.connect(self._step)
        self._timer.start()
        if self._engine is not None:
            self._append_trace(self._snapshot)

    @Slot()
    def start(self) -> None:
        if not self._running:
            self._running = True
            self._started_wall = time.perf_counter()
            self._started_sim = self._snapshot.time_s
            self.stateChanged.emit()

    @Slot()
    def pause(self) -> None:
        if self._running:
            self._running = False
            self._direction = 0.0
            self._auto_cycle_active = False
            self._auto_cycle.stop()
            self.stateChanged.emit()

    @Slot()
    def reset(self) -> None:
        self._running = False
        self._direction = 0.0
        self._auto_cycle_active = False
        self._auto_cycle.reset()
        try:
            if self._engine is not None:
                self._engine.reset()
                self._snapshot = self._engine.snapshot()
            self._trace.clear()
            self._frozen_trace.clear()
            self._capture_trigger_time = None
            self._capture_trigger_index = 0
            self._capture_index = 0
            self._capture_collecting = False
            self._capture_label = ""
            self._previous_hard_stop = self._snapshot.hard_stop_tremie or self._snapshot.hard_stop_maintenance
            self._append_trace(self._snapshot)
            self._error = ""
            self._tick_count = 0
        except Exception as exc:
            self._error = str(exc)
            self.errorChanged.emit()
        self.stateChanged.emit()
        self.traceChanged.emit()

    @Slot()
    def close(self) -> None:
        self._timer.stop()
        if self._engine is not None:
            self._engine.close()
        if self._readonly is not None:
            self._readonly.close()

    def _step(self) -> None:
        if not self._running or self._error:
            return
        try:
            if self._engine is not None:
                if self._auto_cycle_active:
                    self._direction, brake_release = self._auto_cycle.command(
                        self._snapshot.time_s, self._snapshot.position_m,
                        self._snapshot.velocity_mps, self._snapshot.brake_is_open)
                    self._auto_cycle_active = self._auto_cycle.active
                else:
                    brake_release = abs(self._direction) > 0.05
                self._snapshot = self._engine.step(
                    self._direction, self._frequency_request, brake_release
                )
            elif self._readonly is not None:
                state = self._readonly.poll()
                if self._last_plc_sequence != state.sequence and not state.stale:
                    self._last_plc_sequence = state.sequence
                    if self._plc_trace_origin_s is None:
                        self._plc_trace_origin_s = state.received_monotonic_s
                    self._snapshot = M3Snapshot(
                        state.received_monotonic_s - self._plc_trace_origin_s,
                        state.sequence,
                        0.0, state.requested_frequency_hz, False,
                        state.requested_frequency_hz, state.measured_frequency_hz,
                        state.velocity_mps, state.position_m, state.brake_open,
                        sum((int(v) << shift) for shift, v in zip((4, 3, 2, 1, 0), state.sensors)),
                        state.status_word, *state.sensors,
                        state.hard_stop and state.position_m <= -0.299,
                        state.hard_stop and state.position_m >= 30.299)
                    self._append_trace(self._snapshot)
            if self._engine is not None:
                self._append_trace(self._snapshot)
            self._tick_count += 1
            if self._tick_count % 5 == 0:
                self.stateChanged.emit()
                self.traceChanged.emit()
        except Exception as exc:
            self._running = False
            self._direction = 0.0
            self._error = str(exc)
            self.errorChanged.emit()
            self.stateChanged.emit()

    def _append_trace(self, snapshot: M3Snapshot) -> None:
        hard_stop = snapshot.hard_stop_tremie or snapshot.hard_stop_maintenance
        point = {
            "t": snapshot.time_s,
            "cmd": snapshot.frequency_cmd_hz,
            "act": snapshot.frequency_act_hz,
            "velocity": snapshot.velocity_mps,
            "position": snapshot.position_m,
            "brake_open": float(snapshot.brake_is_open),
            "sensors": float(snapshot.sensors_word),
            "hard_stop": float(hard_stop),
            "status_word": float(snapshot.drive_status_word),
        }
        self._trace.append(point)

        # Capture 1 s before and 1 s after a rising edge of a mechanical stop.
        # The ring buffer remains live; the frozen snapshot survives afterward.
        if hard_stop and not self._previous_hard_stop:
            self._capture_label = "BUTÉE TRÉMIE" if snapshot.hard_stop_tremie else "BUTÉE MAINTENANCE"
            self._capture_trigger_time = snapshot.time_s
            self._frozen_trace = [
                dict(sample) for sample in self._trace
                if sample["t"] >= snapshot.time_s - 1.0
            ]
            self._capture_trigger_index = len(self._frozen_trace) - 1
            self._capture_index = self._capture_trigger_index
            self._capture_collecting = True
            self.captureChanged.emit()
        elif self._capture_collecting:
            self._frozen_trace.append(dict(point))
            if (self._capture_trigger_time is not None and
                    snapshot.time_s - self._capture_trigger_time >= 1.0):
                self._capture_collecting = False
                self._capture_index = self._capture_trigger_index
                self.captureChanged.emit()

        self._previous_hard_stop = hard_stop

    def _approach_target(self) -> tuple[str, float]:
        position = self._snapshot.position_m
        movement = self._snapshot.velocity_mps
        if abs(movement) < 0.005:
            movement = self._direction
        landmarks = [
            ("BUTÉE TRÉMIE", -0.30),
            ("CAPTEUR TRÉMIE", 0.0),
            ("CAPTEUR PV", 5.0),
            ("CAPTEUR P2", 15.0),
            ("CAPTEUR P1", 20.0),
            ("CAPTEUR MAINTENANCE", 30.0),
            ("BUTÉE MAINTENANCE", 30.30),
        ]
        if movement < -0.005:
            upcoming = [item for item in landmarks if item[1] < position - 0.001]
            if upcoming:
                return max(upcoming, key=lambda item: item[1])
        elif movement > 0.005:
            upcoming = [item for item in landmarks if item[1] > position + 0.001]
            if upcoming:
                return min(upcoming, key=lambda item: item[1])
        return min(landmarks, key=lambda item: abs(item[1] - position))

    @Property(bool, notify=stateChanged)
    def running(self) -> bool:
        return self._running

    @Property(float, notify=stateChanged)
    def direction(self) -> float:
        return self._direction

    @direction.setter
    def direction(self, value: float) -> None:
        value = max(-1.0, min(1.0, float(value)))
        if self._auto_cycle_active:
            self._auto_cycle_active = False
            self._auto_cycle.stop()
        if abs(value - self._direction) > 0.001:
            self._direction = value
            self.stateChanged.emit()

    @Slot(float)
    def manualJoystick(self, value: float) -> None:
        """Priorité opérateur : tout geste joystick arrête l'AUTO-CYCLE."""
        self.direction = value

    @Slot()
    def toggleAutoCycle(self) -> None:
        if self._engine is None:
            return
        if self._auto_cycle_active:
            self._auto_cycle_active = False
            self._auto_cycle.stop()
            self._direction = 0.0
        else:
            self._auto_cycle_active = True
            self._auto_cycle.start()
            self._running = True
            self._started_wall = time.perf_counter()
            self._started_sim = self._snapshot.time_s
        self.stateChanged.emit()

    @Property(float, notify=stateChanged)
    def frequencyRequest(self) -> float:
        return self._frequency_request

    @frequencyRequest.setter
    def frequencyRequest(self, value: float) -> None:
        value = max(0.0, min(50.0, float(value)))
        if abs(value - self._frequency_request) > 0.001:
            self._frequency_request = value
            self.stateChanged.emit()

    @Property(bool, notify=stateChanged)
    def autoCycleActive(self) -> bool:
        return self._auto_cycle_active

    @Property(int, notify=stateChanged)
    def autoCycleCount(self) -> int:
        return self._auto_cycle.completed_cycles

    @Property(str, notify=stateChanged)
    def autoCyclePhaseText(self) -> str:
        return self._auto_cycle.phase

    @Property(float, notify=stateChanged)
    def simulationTime(self) -> float:
        return self._snapshot.time_s

    @Property(int, notify=stateChanged)
    def scanCounter(self) -> int:
        return self._snapshot.scan_counter

    @Property(float, notify=stateChanged)
    def frequencyCommand(self) -> float:
        return self._snapshot.frequency_cmd_hz

    @Property(float, notify=stateChanged)
    def frequencyActual(self) -> float:
        return self._snapshot.frequency_act_hz

    @Property(float, notify=stateChanged)
    def velocity(self) -> float:
        return self._snapshot.velocity_mps

    @Property(float, notify=stateChanged)
    def position(self) -> float:
        return self._snapshot.position_m

    @Property(bool, notify=stateChanged)
    def dataAvailable(self) -> bool:
        return self._engine is not None or bool(self._readonly is not None and self._readonly.has_data and not self._readonly.state().stale)

    @Property(bool, notify=stateChanged)
    def hasLastData(self) -> bool:
        return bool(self._readonly is not None and self._readonly.has_data)

    @Property(str, notify=stateChanged)
    def positionText(self) -> str:
        if self._readonly is not None and not self._readonly.has_data:
            return "N/D"
        return f"{self._snapshot.position_m:.3f}"

    @Property(bool, notify=stateChanged)
    def plcEchoAvailable(self) -> bool:
        if self._readonly is None:
            return False
        echo, _stale = self._readonly.plc_echo()
        return echo is not None

    @Property("QVariantList", notify=stateChanged)
    def plcEchoRows(self) -> list:
        """Lignes [libellé, valeur, alerte] de l'état PLC renvoyé dans les trames (lecture seule)."""
        if self._readonly is None:
            return []
        echo, stale = self._readonly.plc_echo()
        if echo is None:
            return [["État PLC", "aucun écho reçu", True]]
        last_point = next((label for key, label in (("at_tremie", "Trémie"), ("at_pv", "PV"), ("at_p2", "P2"),
                                                    ("at_p1", "P1"), ("at_maintenance", "Maintenance"))
                           if echo[key]), "—")
        sens = "Trémie" if echo["active_tremie"] else ("Maintenance" if echo["active_maintenance"] else "arrêt")
        fdc = " + ".join(label for key, label in (("limit_tremie", "Trémie"), ("limit_maintenance", "Maint./P1"))
                         if echo[key]) or "libres"
        acces = "OUI" if echo["maint_target_enable"] else ("NON (bouton=1, mode non MAINT)"
                                                           if echo["maint_zone_access"] else "NON (bouton=0)")
        rows = [
            ["Mode", echo["mode"], False],
            ["Accès zone Maintenance", acces, not echo["maint_target_enable"]],
            ["État FB translation", echo["fb_state"], echo["fb_state"] == "ERROR"],
            ["Cause de blocage", echo["block_reason"], echo["block_reason"] != "NONE"],
            ["Sens commandé", sens, False],
            ["Dernier point franchi", last_point, False],
            ["Fins de course", fdc, fdc != "libres"],
            ["Position estimée PLC", f"{echo['estimated_pos_m']:.2f} m", False],
            ["SafeStop / Coupure", f"{int(echo['safe_stop'])} / {int(echo['power_cutoff'])}",
             echo["safe_stop"] or echo["power_cutoff"]],
            ["Défauts safety M3", f"0x{echo['safety_error_id']:02X}", echo["safety_error_id"] != 0],
            ["Lien vu par le PLC", "OK" if echo["link_ready"] else "PERDU", not echo["link_ready"]],
        ]
        if stale:
            rows.insert(0, ["État PLC", "PÉRIMÉ (plus de trame)", True])
        return rows

    @Property(str, notify=stateChanged)
    def telemetryStatus(self) -> str:
        if self._readonly is None:
            return "SIMULATION LOCALE"
        if not self._readonly.has_data:
            return "EN ATTENTE DE LA PREMIÈRE TRAME"
        if self._readonly.state().stale:
            return "DONNÉES PERDUES · DERNIÈRE POSITION CONNUE"
        return "FMU ACTIVE · COMMANDÉE PAR PLC" if self._source_mode == "gateway-readonly" else "PLC · LECTURE SEULE"

    @Property(bool, notify=stateChanged)
    def brakeOpen(self) -> bool:
        return self._snapshot.brake_is_open

    @Property(bool, notify=stateChanged)
    def brakeRequest(self) -> bool:
        return self._snapshot.brake_release_cmd

    @Property(str, notify=stateChanged)
    def brakeRequestText(self) -> str:
        if self._source_mode != "fmu":
            return "N/D"
        return "DESSERRER" if self._snapshot.brake_release_cmd else "SERRER"

    @Property(int, notify=stateChanged)
    def sensorsWord(self) -> int:
        return self._snapshot.sensors_word

    @Property(int, notify=stateChanged)
    def driveStatusWord(self) -> int:
        return self._snapshot.drive_status_word

    @Property(bool, notify=stateChanged)
    def tremie(self) -> bool:
        return self._snapshot.tremie

    @Property(bool, notify=stateChanged)
    def pv(self) -> bool:
        return self._snapshot.pv

    @Property(bool, notify=stateChanged)
    def p2(self) -> bool:
        return self._snapshot.p2

    @Property(bool, notify=stateChanged)
    def p1(self) -> bool:
        return self._snapshot.p1

    @Property(bool, notify=stateChanged)
    def maintenance(self) -> bool:
        return self._snapshot.maintenance

    @Property(bool, notify=stateChanged)
    def hardStop(self) -> bool:
        return self._snapshot.hard_stop_tremie or self._snapshot.hard_stop_maintenance

    @Property(bool, notify=stateChanged)
    def hardStopTremie(self) -> bool:
        return self._snapshot.hard_stop_tremie

    @Property(bool, notify=stateChanged)
    def hardStopMaintenance(self) -> bool:
        return self._snapshot.hard_stop_maintenance

    @Property(float, notify=stateChanged)
    def realTimeRatio(self) -> float:
        wall_elapsed = time.perf_counter() - self._started_wall
        if not self._running or wall_elapsed <= 0:
            return 0.0
        return (self._snapshot.time_s - self._started_sim) / wall_elapsed

    @Property("QVariantList", notify=traceChanged)
    def tracePoints(self):
        # Décimation d'affichage seulement : le tampon garde tous les échantillons à 10 ms.
        points = list(self._trace)
        step = max(1, -(-len(points) // LIVE_DRAW_POINTS))   # arrondi supérieur : jamais plus de LIVE_DRAW_POINTS
        return [self._point_values(point) for point in points[::step]]

    @Property("QVariantList", notify=traceChanged)
    def traceMarkers(self):
        """Fronts capteurs de la fenêtre live : [t, libellé] (ex. « P1↓ »)."""
        return self._sensor_edges(list(self._trace))

    @Property(float, constant=True)
    def liveWindowSeconds(self) -> float:
        return LIVE_WINDOW_S

    @staticmethod
    def _sensor_edges(samples: list[dict[str, float]]) -> list[list]:
        edges = []
        for previous, current in zip(samples, samples[1:]):
            changed = int(previous["sensors"]) ^ int(current["sensors"])
            for bit, name in SENSOR_BITS:
                if changed >> bit & 1:
                    arrow = "↑" if int(current["sensors"]) >> bit & 1 else "↓"
                    edges.append([current["t"], f"{name}{arrow}"])
        return edges

    @staticmethod
    def _point_values(point: dict[str, float]) -> list[float]:
        return [point[key] for key in
                ("t", "cmd", "act", "velocity", "position", "brake_open", "sensors", "hard_stop", "status_word")]

    @Property("QVariantList", notify=captureChanged)
    def frozenTracePoints(self):
        return [self._point_values(point) for point in self._frozen_trace]

    @Property(bool, notify=captureChanged)
    def captureAvailable(self) -> bool:
        return bool(self._frozen_trace)

    @Property(bool, notify=captureChanged)
    def captureComplete(self) -> bool:
        return bool(self._frozen_trace) and not self._capture_collecting

    @Property(str, notify=captureChanged)
    def captureStatus(self) -> str:
        if not self._frozen_trace:
            return "AUCUNE CAPTURE"
        if self._capture_collecting:
            return "CAPTURE EN COURS · 1 s après contact"
        return "FIGÉE · " + self._capture_label

    @Property(int, notify=captureChanged)
    def capturePointIndex(self) -> int:
        return self._capture_index

    @Property(float, notify=captureChanged)
    def captureTriggerTime(self) -> float:
        return self._capture_trigger_time if self._capture_trigger_time is not None else 0.0

    @Property(str, notify=captureChanged)
    def captureReadout(self) -> str:
        if not self._frozen_trace or self._capture_trigger_time is None:
            return "En attente d'un contact de butée mécanique."
        index = max(0, min(self._capture_index, len(self._frozen_trace) - 1))
        point = self._frozen_trace[index]
        sensors = int(point["sensors"])
        brake = "OUVERT" if point["brake_open"] else "APPLIQUÉ"
        return ("t={:.3f} s · Δbutée={:+.3f} s · position={:.3f} m · vitesse={:.3f} m/s · "
                "Hz consigne/mesure={:.2f}/{:.2f} · frein {} · capteurs {:05b} · état WORD#{:02X}").format(
                    point["t"], point["t"] - self._capture_trigger_time,
                    point["position"], point["velocity"], point["cmd"], point["act"],
                    brake, sensors, int(point["status_word"]))

    @Slot(int)
    def selectCapturePoint(self, index: int) -> None:
        if not self._frozen_trace:
            return
        selected = max(0, min(int(index), len(self._frozen_trace) - 1))
        if selected != self._capture_index:
            self._capture_index = selected
            self.captureChanged.emit()

    @Property(str, notify=stateChanged)
    def approachTargetLabel(self) -> str:
        return self._approach_target()[0]

    @Property(float, notify=stateChanged)
    def approachTargetPosition(self) -> float:
        return self._approach_target()[1]

    @Property(float, notify=stateChanged)
    def approachDistance(self) -> float:
        return abs(self._approach_target()[1] - self._snapshot.position_m)

    @Property(float, notify=stateChanged)
    def approachBrakingDistance(self) -> float:
        return self._snapshot.velocity_mps ** 2 / (2.0 * 0.5)

    @Property(float, notify=stateChanged)
    def approachSecondaryPosition(self) -> float:
        label, target = self._approach_target()
        if "TRÉMIE" in label:
            return 0.0 if target < 0.0 else -0.30
        if "MAINTENANCE" in label:
            return 30.30 if target < 30.0 else 30.0
        return -999.0

    @Property(str, notify=stateChanged)
    def approachSecondaryLabel(self) -> str:
        label, target = self._approach_target()
        if "TRÉMIE" in label:
            return "CAPTEUR TRÉMIE" if target < 0.0 else "BUTÉE TRÉMIE"
        if "MAINTENANCE" in label:
            return "BUTÉE MAINTENANCE" if target < 30.0 else "CAPTEUR MAINTENANCE"
        return ""

    @Property(str, notify=errorChanged)
    def errorText(self) -> str:
        return self._error

    @Property(str, notify=stateChanged)
    def source(self) -> str:
        if self._source_mode == "fmu":
            return "SIMULATION"
        return "FMU · PLC" if self._source_mode == "gateway-readonly" else "PLC LECTURE"

    @Property(str, notify=stateChanged)
    def sampleCounterLabel(self) -> str:
        return "SCAN" if self._source_mode == "fmu" else "TRAME"

    @Property(str, notify=stateChanged)
    def sampleCounterUnit(self) -> str:
        return "×10 ms" if self._source_mode == "fmu" else "UDP"

    @Property(str, notify=stateChanged)
    def tracePointLabel(self) -> str:
        return "  • = 10 ms" if self._source_mode == "fmu" else "  • = trame reçue"

    @Property(bool, notify=stateChanged)
    def stale(self) -> bool:
        return bool(self._readonly is not None and self._readonly.has_data and self._readonly.state().stale)

    @Property(bool, notify=stateChanged)
    def telemetryHasData(self) -> bool:
        return bool(self._readonly is not None and self._readonly.has_data)


def main() -> int:
    smoke_test = "--smoke-test" in sys.argv
    screenshot_path = None
    if "--screenshot" in sys.argv:
        screenshot_index = sys.argv.index("--screenshot")
        if screenshot_index + 1 >= len(sys.argv):
            raise SystemExit("--screenshot exige un chemin de sortie")
        screenshot_path = sys.argv[screenshot_index + 1]
    qt_args = []
    skip_next = False
    telemetry_port = 29072
    for argument in sys.argv:
        if skip_next:
            if skip_next == "telemetry-port":
                telemetry_port = int(argument)
            skip_next = False
            continue
        if argument == "--telemetry-port":
            skip_next = "telemetry-port"
            continue
        if argument == "--screenshot":
            skip_next = True
            continue
        if argument in ("--plc-readonly", "--gateway-readonly"):
            continue
        if argument != "--smoke-test":
            qt_args.append(argument)
    application = QGuiApplication(qt_args)
    application.setApplicationName("TwinBench M3 Live")
    # Style Fusion : le style natif Windows ignore les fonds personnalisés des contrôles
    # (avertissements « does not support customization » à chaque lancement).
    QQuickStyle.setStyle("Fusion")
    source_mode = ("gateway-readonly" if "--gateway-readonly" in sys.argv else
                   ("plc-readonly" if "--plc-readonly" in sys.argv else "fmu"))
    backend = LiveBackend(source_mode, telemetry_port=telemetry_port)
    application.aboutToQuit.connect(backend.close)

    qml_engine = QQmlApplicationEngine()
    qml_engine.rootContext().setContextProperty("backend", backend)
    qml_engine.load(Path(__file__).with_name("Main.qml"))
    if not qml_engine.rootObjects():
        backend.close()
        return 2
    if screenshot_path:
        backend.direction = 1.0
        backend.start()

        def save_screenshot() -> None:
            window = qml_engine.rootObjects()[0]
            image = window.screen().grabWindow(window.winId())
            if not image.save(screenshot_path):
                print(f"Capture impossible : {screenshot_path}", file=sys.stderr)
            application.quit()

        QTimer.singleShot(1500, save_screenshot)
    elif smoke_test:
        backend.start()
        QTimer.singleShot(1200, application.quit)
    return application.exec()


if __name__ == "__main__":
    raise SystemExit(main())
