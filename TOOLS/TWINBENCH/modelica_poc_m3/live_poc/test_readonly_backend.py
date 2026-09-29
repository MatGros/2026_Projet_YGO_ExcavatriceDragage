"""Régression BLOCK-1 : la lecture PLC démarre sans bouton Démarrer."""
from __future__ import annotations

import socket
import sys
import time
from pathlib import Path

from PySide6.QtGui import QGuiApplication

HERE = Path(__file__).resolve().parent
LINK = HERE.parents[2] / "udp_m3_link"
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(LINK))

from app import LiveBackend  # noqa: E402
from m3_binary_protocol import pack_plant  # noqa: E402


def main() -> int:
    application = QGuiApplication([])
    backend = LiveBackend("plc-readonly")
    assert backend.running, "PLC lecture doit démarrer sans start()"
    sender = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sender.sendto(pack_plant(1, 1, 40.0, 20.0, -0.4, 12.345, True, 128,
                                 (False, False, True, True, True), False),
                      ("127.0.0.1", 29072))
        for _ in range(20):
            application.processEvents()
            time.sleep(0.01)
        assert not backend.stale
        assert abs(backend.position - 12.345) < 0.001
        assert backend.sensorsWord == 7
        # La minuterie UI tourne à 10 ms, mais elle ne doit pas inventer de
        # points de mesure entre deux trames UDP réellement reçues.
        assert len(backend.tracePoints) == 2
        sender.sendto(pack_plant(2, 2, 40.0, 22.0, -0.44, 12.301, True, 128,
                                 (False, False, True, True, True), False),
                      ("127.0.0.1", 29072))
        for _ in range(10):
            application.processEvents()
            time.sleep(0.01)
        assert len(backend.tracePoints) == 3
        assert backend.tracePoints[-1][0] > backend.tracePoints[-2][0]
        print("[PASS] BLOCK-1: PLC lecture automatique et trace sans points inventes")
    finally:
        sender.close()
        backend.close()
        application.quit()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
