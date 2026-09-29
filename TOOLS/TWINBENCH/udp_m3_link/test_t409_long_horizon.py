"""Vérifie que la FMU peut démarrer et avancer après l'ancien horizon de 24 h."""
from __future__ import annotations

import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
LIVE = HERE.parent / "modelica_poc_m3" / "live_poc"
sys.path.insert(0, str(LIVE))

from engine import LONG_HORIZON_S, M3FmuEngine  # noqa: E402


def main() -> int:
    old_horizon_s = 86400.0
    engine = M3FmuEngine(start_time_s=old_horizon_s + 1.0)
    try:
        before = engine.snapshot()
        after = engine.step(1.0, 40.0, True)
        ok = (before.time_s > old_horizon_s and after.time_s > before.time_s
              and engine.model.stopTime > LONG_HORIZON_S - 1.0)
        print("[PASS] T409 horizon FMU : démarrage après 24 h et horizon {:.0f} s".format(
            engine.model.stopTime) if ok else "[FAIL] T409 horizon FMU")
        return 0 if ok else 1
    finally:
        engine.close()


if __name__ == "__main__":
    raise SystemExit(main())
