"""Régression BLOCK-1 : la lecture PLC démarre sans bouton Démarrer."""
from __future__ import annotations

import socket
import sys
import time
from pathlib import Path

from PySide6.QtGui import QGuiApplication

HERE = Path(__file__).resolve().parent
LINK = HERE.parents[2] / "90_PROTOTYPES" / "m3_link"
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(LINK))

from app import LiveBackend  # noqa: E402
from m3_binary_protocol import pack_plant  # noqa: E402


def main() -> int:
    application = QGuiApplication([])
    probe = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    probe.bind(("127.0.0.1", 0))
    test_port = probe.getsockname()[1]
    probe.close()
    backend = LiveBackend("gateway-readonly", telemetry_port=test_port)
    assert backend.running, "PLC lecture doit démarrer sans start()"
    assert not backend.dataAvailable and not backend.hasLastData
    assert backend.positionText == "N/D"
    assert not backend.stale and "ATTENTE" in backend.telemetryStatus
    assert len(backend.tracePoints) == 0, "aucune position fictive dans la trace initiale"
    assert "ATTENTE" in backend.telemetryStatus
    sender = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sender.sendto(pack_plant(1, 1, 40.0, 20.0, -0.4, 12.345, True, 128,
                                 (False, False, True, True, True), False),
                      ("127.0.0.1", test_port))
        for _ in range(20):
            application.processEvents()
            time.sleep(0.01)
        assert not backend.stale
        assert backend.dataAvailable and backend.hasLastData
        assert "FMU ACTIVE" in backend.telemetryStatus
        assert abs(backend.position - 12.345) < 0.001
        assert backend.sensorsWord == 7
        # La minuterie UI tourne à 10 ms, mais elle ne doit pas inventer de
        # points de mesure entre deux trames UDP réellement reçues.
        assert len(backend.tracePoints) == 1
        sender.sendto(pack_plant(2, 2, 40.0, 22.0, -0.44, 12.301, True, 128,
                                 (False, False, True, True, True), False),
                      ("127.0.0.1", test_port))
        for _ in range(10):
            application.processEvents()
            time.sleep(0.01)
        assert len(backend.tracePoints) == 2
        assert backend.tracePoints[-1][0] > backend.tracePoints[-2][0]
        time.sleep(0.30)
        application.processEvents()
        assert backend.stale and not backend.dataAvailable
        assert backend.hasLastData and "DONNÉES PERDUES" in backend.telemetryStatus
        sender.sendto(pack_plant(3, 3, 40.0, 23.0, -0.46, 12.250, True, 128,
                                 (False, False, True, True, True), False),
                      ("127.0.0.1", test_port))
        for _ in range(10):
            application.processEvents()
            time.sleep(0.01)
        assert not backend.stale and backend.dataAvailable
        assert abs(backend.position - 12.250) < 0.001
        print("[PASS] T409 UI: attente sans position fictive, télémétrie, perte et reprise")
    finally:
        sender.close()
        backend.close()
        application.quit()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
