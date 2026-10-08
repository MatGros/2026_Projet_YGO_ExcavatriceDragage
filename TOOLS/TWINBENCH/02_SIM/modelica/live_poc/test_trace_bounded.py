"""Preuve structurelle : la trace UI reste bornée, quel que soit le temps simulé."""
from __future__ import annotations

from PySide6.QtGui import QGuiApplication

from app import LIVE_DRAW_POINTS, LIVE_WINDOW_POINTS, LiveBackend


def main() -> int:
    application = QGuiApplication([])
    backend = LiveBackend("fmu")
    try:
        backend._timer.stop()
        backend.start()
        for _ in range(LIVE_WINDOW_POINTS + 1000):
            backend._step()
        assert backend._trace.maxlen == LIVE_WINDOW_POINTS
        assert len(backend._trace) == LIVE_WINDOW_POINTS
        assert len(backend.tracePoints) <= LIVE_DRAW_POINTS
        print(f"[PASS] Trace UI bornée : tampon {LIVE_WINDOW_POINTS} points, "
              f"tracé {len(backend.tracePoints)} <= {LIVE_DRAW_POINTS} points")
        return 0
    finally:
        backend.close()
        application.quit()


if __name__ == "__main__":
    raise SystemExit(main())
