"""Régression interface : AUTO-CYCLE FMU et priorité du joystick."""
from __future__ import annotations

from PySide6.QtGui import QGuiApplication

from app import LiveBackend


def main() -> int:
    application = QGuiApplication([])
    fmu = LiveBackend("fmu")
    plc = None
    try:
        fmu.toggleAutoCycle()
        assert fmu.autoCycleActive and fmu.autoCyclePhaseText == "VERS TRÉMIE"
        fmu.manualJoystick(0.25)
        assert not fmu.autoCycleActive and abs(fmu.direction - 0.25) < 0.001
        fmu.close()
        plc = LiveBackend("plc-readonly")
        plc.toggleAutoCycle()
        assert not plc.autoCycleActive
        print("[PASS] AUTO-CYCLE : simulation seule et joystick prioritaire")
        return 0
    finally:
        fmu.close()
        if plc is not None:
            plc.close()
        application.quit()


if __name__ == "__main__":
    raise SystemExit(main())
