"""Preuve structurelle : la trace UI reste bornée, quel que soit le temps simulé."""
from __future__ import annotations

from PySide6.QtGui import QGuiApplication

from app import LiveBackend


def main() -> int:
    application = QGuiApplication([])
    backend = LiveBackend("fmu")
    try:
        backend._timer.stop()
        backend.start()
        for _ in range(1000):
            backend._step()
        assert backend._trace.maxlen == 201
        assert len(backend.tracePoints) == 201
        print("[PASS] Trace UI bornée : 201 points après 1000 pas")
        return 0
    finally:
        backend.close()
        application.quit()


if __name__ == "__main__":
    raise SystemExit(main())
