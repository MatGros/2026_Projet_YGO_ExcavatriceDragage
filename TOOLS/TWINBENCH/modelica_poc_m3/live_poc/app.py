from __future__ import annotations

import sys
import time
from collections import deque
from pathlib import Path

from PySide6.QtCore import QObject, Property, QTimer, Qt, Signal, Slot
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

from engine import M3FmuEngine, M3Snapshot, STEP_S


class LiveBackend(QObject):
    stateChanged = Signal()
    traceChanged = Signal()
    errorChanged = Signal()

    def __init__(self) -> None:
        super().__init__()
        self._engine = M3FmuEngine()
        self._running = False
        self._direction = 0.0
        self._frequency_request = 40.0
        self._snapshot = self._engine.snapshot()
        self._error = ""
        self._trace: deque[dict[str, float]] = deque(maxlen=201)
        self._tick_count = 0
        self._started_wall = time.perf_counter()
        self._started_sim = 0.0

        self._timer = QTimer(self)
        self._timer.setTimerType(Qt.TimerType.PreciseTimer)
        self._timer.setInterval(round(STEP_S * 1000))
        self._timer.timeout.connect(self._step)
        self._timer.start()
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
            self.stateChanged.emit()

    @Slot()
    def reset(self) -> None:
        self._running = False
        self._direction = 0.0
        try:
            self._engine.reset()
            self._snapshot = self._engine.snapshot()
            self._trace.clear()
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
        self._engine.close()

    def _step(self) -> None:
        if not self._running or self._error:
            return
        try:
            brake_release = abs(self._direction) > 0.05
            self._snapshot = self._engine.step(
                self._direction, self._frequency_request, brake_release
            )
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
        self._trace.append(
            {
                "t": snapshot.time_s,
                "cmd": snapshot.frequency_cmd_hz,
                "act": snapshot.frequency_act_hz,
                "velocity": snapshot.velocity_mps,
            }
        )

    @Property(bool, notify=stateChanged)
    def running(self) -> bool:
        return self._running

    @Property(float, notify=stateChanged)
    def direction(self) -> float:
        return self._direction

    @direction.setter
    def direction(self, value: float) -> None:
        value = max(-1.0, min(1.0, float(value)))
        if abs(value - self._direction) > 0.001:
            self._direction = value
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
    def brakeOpen(self) -> bool:
        return self._snapshot.brake_is_open

    @Property(bool, notify=stateChanged)
    def brakeRequest(self) -> bool:
        return self._snapshot.brake_release_cmd

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

    @Property(float, notify=stateChanged)
    def realTimeRatio(self) -> float:
        wall_elapsed = time.perf_counter() - self._started_wall
        if not self._running or wall_elapsed <= 0:
            return 0.0
        return (self._snapshot.time_s - self._started_sim) / wall_elapsed

    @Property("QVariantList", notify=traceChanged)
    def tracePoints(self):
        return [
            [point["t"], point["cmd"], point["act"], point["velocity"]]
            for point in self._trace
        ]

    @Property(str, notify=errorChanged)
    def errorText(self) -> str:
        return self._error


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
    for argument in sys.argv:
        if skip_next:
            skip_next = False
            continue
        if argument == "--screenshot":
            skip_next = True
            continue
        if argument != "--smoke-test":
            qt_args.append(argument)
    application = QGuiApplication(qt_args)
    application.setApplicationName("TwinBench M3 Live")
    backend = LiveBackend()
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
