"""Capture figée autour du contact butée, curseur et historique live borné."""
from __future__ import annotations

from collections import deque

from PySide6.QtCore import QObject

from app import LiveBackend
from engine import M3Snapshot


def make_snapshot(time_s: float, hard_stop: bool = False) -> M3Snapshot:
    at_maintenance_stop = hard_stop
    return M3Snapshot(
        time_s, round(time_s * 100), 1.0, 40.0, True, 40.0, 39.5,
        0.0 if hard_stop else 0.2,
        30.3 if at_maintenance_stop else 20.0,
        not hard_stop,
        0 if at_maintenance_stop else 3,
        128,
        False, False, False, not at_maintenance_stop, not at_maintenance_stop,
        False, at_maintenance_stop,
    )


def make_backend() -> LiveBackend:
    backend = LiveBackend.__new__(LiveBackend)
    QObject.__init__(backend)
    backend._trace = deque(maxlen=201)
    backend._frozen_trace = []
    backend._capture_trigger_time = None
    backend._capture_trigger_index = 0
    backend._capture_index = 0
    backend._capture_collecting = False
    backend._capture_label = ""
    backend._previous_hard_stop = False
    return backend


def main() -> int:
    backend = make_backend()
    for index in range(200):
        backend._append_trace(make_snapshot(index / 100.0))

    trigger_time = 2.0
    backend._append_trace(make_snapshot(trigger_time, hard_stop=True))
    assert backend.captureAvailable
    assert not backend.captureComplete
    assert backend.captureStatus.startswith("CAPTURE EN COURS")
    assert abs(backend.frozenTracePoints[0][0] - 1.0) < 1e-9
    assert abs(backend.frozenTracePoints[-1][0] - trigger_time) < 1e-9

    for index in range(1, 101):
        backend._append_trace(make_snapshot(trigger_time + index / 100.0, hard_stop=True))

    assert backend.captureComplete
    assert backend.captureStatus == "FIGÉE · BUTÉE MAINTENANCE"
    assert len(backend.frozenTracePoints) == 201
    assert abs(backend.frozenTracePoints[-1][0] - 3.0) < 1e-9
    assert abs(backend.frozenTracePoints[backend.capturePointIndex][0] - trigger_time) < 1e-9
    assert "Δbutée=+0.000 s" in backend.captureReadout
    assert "position=30.300 m" in backend.captureReadout
    assert "capteurs 00000" in backend.captureReadout

    frozen_copy = backend.frozenTracePoints
    backend.selectCapturePoint(0)
    assert "t=1.000 s" in backend.captureReadout
    backend._append_trace(make_snapshot(3.01, hard_stop=True))
    assert backend.frozenTracePoints == frozen_copy
    assert len(backend.tracePoints) == 201
    print("[PASS] Capture butée : 1 s avant/après, curseur synchronisé, gel conservé, live borné")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
