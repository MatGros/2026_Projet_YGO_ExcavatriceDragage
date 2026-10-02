from __future__ import annotations

import os
import sys
from dataclasses import dataclass
from pathlib import Path

from build_fmu import STATE_DIR, build_fmu, find_omc


STEP_S = 0.01
LONG_HORIZON_S = 1_000_000_000.0


def _load_omsimulator():
    om_root = find_omc().parents[1]
    package_root = om_root / "lib" / "omc"
    if str(package_root) not in sys.path:
        sys.path.insert(0, str(package_root))
    # Ne pas ajouter OpenModelica/bin au PATH : il contient ses propres DLL Qt6,
    # incompatibles avec celles de PySide6. Le binding OMSimulator ouvre déjà
    # temporairement son répertoire DLL avec os.add_dll_directory().
    import OMSimulator  # type: ignore

    return OMSimulator


@dataclass(frozen=True)
class M3Snapshot:
    time_s: float
    scan_counter: int
    direction_cmd: float
    frequency_request_hz: float
    brake_release_cmd: bool
    frequency_cmd_hz: float
    frequency_act_hz: float
    velocity_mps: float
    position_m: float
    brake_is_open: bool
    sensors_word: int
    drive_status_word: int
    tremie: bool
    pv: bool
    p2: bool
    p1: bool
    maintenance: bool
    hard_stop_tremie: bool
    hard_stop_maintenance: bool


class M3FmuEngine:
    def __init__(self, step_s: float = STEP_S, start_time_s: float = 0.0) -> None:
        self.oms = _load_omsimulator()
        self.fmu_path = build_fmu()
        self._step_s = float(step_s)
        self._start_time_s = float(start_time_s)
        if self._step_s <= 0:
            raise ValueError("step_s doit être positif")
        self._generation = 0
        self.model = None
        self.plant = None
        self.reset()

    def reset(self) -> None:
        if self.model is not None:
            try:
                self.model.terminate()
            except Exception:
                pass
            try:
                self.model.delete()
            except Exception:
                pass

        self._generation += 1
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        temp_dir = STATE_DIR / f"Runtime_{os.getpid()}_{self._generation}"
        temp_dir.mkdir(parents=True, exist_ok=True)
        self.oms.setTempDirectory(str(temp_dir))
        self.oms.setWorkingDirectory(str(temp_dir))
        self.oms.setLoggingLevel(0)

        name = f"M3Live{self._generation}"
        self.model = self.oms.newModel(name)
        root = self.model.addSystem("root", self.oms.Types.System.WC)
        self.plant = root.addSubModel("plant", str(self.fmu_path))
        self.model.startTime = self._start_time_s
        # 31,7 ans : précision IEEE-754 très supérieure au pas de 10 ms.
        # Le POC reste arrêtable explicitement, sans échéance cachée à 24 h.
        self.model.stopTime = max(LONG_HORIZON_S, self._start_time_s + 3600.0)
        self.model.fixedStepSize = self._step_s
        self.model.resultFile = str(temp_dir / "M3_Live_result.mat")
        self.model.instantiate()
        self._write_inputs(0.0, 0.0, False)
        self.model.initialize()

    def _write_inputs(self, direction: float, frequency_hz: float, brake_release: bool) -> None:
        assert self.plant is not None
        self.plant.setReal("directionCmd", max(-1.0, min(1.0, float(direction))))
        self.plant.setReal("frequencyCmd_Hz", max(0.0, min(50.0, float(frequency_hz))))
        self.plant.setBoolean("brakeReleaseCmd", bool(brake_release))

    def step(self, direction: float, frequency_hz: float, brake_release: bool) -> M3Snapshot:
        assert self.model is not None
        self._write_inputs(direction, frequency_hz, brake_release)
        self.model.doStep()
        return self.snapshot(direction, frequency_hz, brake_release)

    def snapshot(self, direction: float = 0.0, frequency_hz: float = 0.0,
                 brake_release: bool = False) -> M3Snapshot:
        assert self.model is not None and self.plant is not None
        return M3Snapshot(
            time_s=self.model.time,
            scan_counter=self.plant.getInteger("scanCounter"),
            direction_cmd=float(direction),
            frequency_request_hz=float(frequency_hz),
            brake_release_cmd=bool(brake_release),
            frequency_cmd_hz=self.plant.getReal("frequencyCmdApplied_Hz"),
            frequency_act_hz=self.plant.getReal("frequencyAct_Hz"),
            velocity_mps=self.plant.getReal("velocityAct_Mps"),
            position_m=self.plant.getReal("positionAct_M"),
            brake_is_open=self.plant.getBoolean("brakeIsOpen"),
            sensors_word=self.plant.getInteger("sensorsWord"),
            drive_status_word=self.plant.getInteger("driveStatusWord"),
            tremie=self.plant.getBoolean("tremiePositionIsActive"),
            pv=self.plant.getBoolean("pvPositionIsActive"),
            p2=self.plant.getBoolean("p2PositionIsActive"),
            p1=self.plant.getBoolean("p1PositionIsActive"),
            maintenance=self.plant.getBoolean("maintenancePositionIsActive"),
            hard_stop_tremie=self.plant.getBoolean("hardStopTremieActive"),
            hard_stop_maintenance=self.plant.getBoolean("hardStopMaintenanceActive"),
        )

    def close(self) -> None:
        if self.model is None:
            return
        try:
            self.model.terminate()
        finally:
            try:
                self.model.delete()
            finally:
                self.model = None
                self.plant = None
