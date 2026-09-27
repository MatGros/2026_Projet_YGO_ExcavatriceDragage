"""TwinBench native M3 simulator.

Offline equipment twin matching the PLC boundary in CODE/:
- command word + frequency setpoint x100 + brake release request
- status word + actual frequency x100 + brake feedback
- five cumulative position sensors Tremie/PV/P2/P1/Maintenance

This module deliberately contains NO PLC safety/interlock logic. The PLC's final
outputs (PRG_06) are inputs to this equipment model.
"""
from __future__ import annotations

from dataclasses import dataclass
import math


@dataclass
class M3Config:
    # Positions are simulation geometry parameters. Defaults follow the current
    # SimBench trace geometry; they are editable and are not claimed metrology.
    x_tremie_m: float = 0.0
    x_pv_m: float = 5.0
    x_p2_m: float = 15.0
    x_p1_m: float = 25.0
    x_maintenance_m: float = 35.0
    max_frequency_hz: float = 50.0
    max_speed_m_s: float = 1.0
    drive_time_constant_s: float = 0.35
    brake_open_delay_s: float = 0.20
    brake_close_delay_s: float = 0.12
    brake_decel_m_s2: float = 2.5
    sensor_hysteresis_m: float = 0.02


@dataclass
class M3Inputs:
    command_word: int = 0
    setpoint_frequency_x100: int = 0
    brake_release_request: bool = False
    thermal_ok: bool = True
    device_running: bool = True


@dataclass
class M3Outputs:
    status_word: int = 0
    actual_frequency_x100: int = 0
    brake_is_open: bool = False
    thermal_ok: bool = True
    pos_tremie: bool = False
    pos_pv: bool = False
    pos_p2: bool = False
    pos_p1: bool = False
    pos_maintenance: bool = False
    sensors_word: int = 0
    sensor_incoherent: bool = False
    position_m: float = 0.0
    velocity_m_s: float = 0.0


class M3NativePlant:
    """Small deterministic native equipment model for the translation axis.

    CommandWord contract follows current CODE usage: 1=Tremie, 2=Maintenance,
    0=stop. Frequency values use the PLC x100 convention.
    """

    CMD_STOP = 0
    CMD_TREMIE = 1
    CMD_MAINTENANCE = 2

    # TwinBench-owned diagnostic status bits (not a claim about undocumented
    # AC600 bit allocation). The raw word is exposed for UI/testing only.
    ST_READY = 1 << 0
    ST_RUNNING = 1 << 1
    ST_DIRECTION_MAINT = 1 << 2
    ST_BRAKE_OPEN = 1 << 3
    ST_FAULT = 1 << 7

    VALID_SENSOR_WORDS = {0b11111, 0b01111, 0b00111, 0b00011, 0b00001, 0b00000}

    def __init__(self, cfg: M3Config | None = None, initial_position_m: float | None = None):
        self.cfg = cfg or M3Config()
        self.position_m = self.cfg.x_p1_m if initial_position_m is None else initial_position_m
        self.velocity_m_s = 0.0
        self.actual_frequency_hz = 0.0
        self.brake_is_open = False
        self._brake_timer_s = 0.0

    def reset(self, position_m: float | None = None) -> M3Outputs:
        self.position_m = self.cfg.x_p1_m if position_m is None else position_m
        self.velocity_m_s = 0.0
        self.actual_frequency_hz = 0.0
        self.brake_is_open = False
        self._brake_timer_s = 0.0
        return self.outputs(M3Inputs())

    def _update_brake(self, dt: float, request: bool) -> None:
        if request == self.brake_is_open:
            self._brake_timer_s = 0.0
            return
        self._brake_timer_s += dt
        delay = self.cfg.brake_open_delay_s if request else self.cfg.brake_close_delay_s
        if self._brake_timer_s >= delay:
            self.brake_is_open = request
            self._brake_timer_s = 0.0

    def _direction(self, command_word: int) -> float:
        if command_word == self.CMD_TREMIE:
            return -1.0
        if command_word == self.CMD_MAINTENANCE:
            return 1.0
        return 0.0

    def step(self, dt: float, inputs: M3Inputs) -> M3Outputs:
        if dt <= 0.0:
            return self.outputs(inputs)

        fault = (not inputs.thermal_ok) or (not inputs.device_running)
        brake_request = inputs.brake_release_request and not fault
        self._update_brake(dt, brake_request)

        direction = self._direction(inputs.command_word)
        set_hz = max(0.0, min(self.cfg.max_frequency_hz, inputs.setpoint_frequency_x100 / 100.0))
        target_hz = set_hz if (direction != 0.0 and self.brake_is_open and not fault) else 0.0

        tau = max(self.cfg.drive_time_constant_s, 1e-6)
        alpha = 1.0 - math.exp(-dt / tau)
        self.actual_frequency_hz += (target_hz - self.actual_frequency_hz) * alpha
        if self.actual_frequency_hz < 0.005:
            self.actual_frequency_hz = 0.0

        target_v = direction * self.cfg.max_speed_m_s * (self.actual_frequency_hz / max(self.cfg.max_frequency_hz, 1e-6))
        if not self.brake_is_open or fault or direction == 0.0:
            dv = self.cfg.brake_decel_m_s2 * dt
            if abs(self.velocity_m_s) <= dv:
                self.velocity_m_s = 0.0
            else:
                self.velocity_m_s -= math.copysign(dv, self.velocity_m_s)
        else:
            self.velocity_m_s = target_v

        self.position_m += self.velocity_m_s * dt
        if self.position_m <= self.cfg.x_tremie_m:
            self.position_m = self.cfg.x_tremie_m
            self.velocity_m_s = max(0.0, self.velocity_m_s)
        elif self.position_m >= self.cfg.x_maintenance_m:
            self.position_m = self.cfg.x_maintenance_m
            self.velocity_m_s = min(0.0, self.velocity_m_s)

        return self.outputs(inputs)

    def _sensor_levels(self) -> tuple[bool, bool, bool, bool, bool]:
        # CODE expects a cumulative thermometer word from 11111 at Tremie to
        # 00000 at Maintenance. Thresholds are crossed in that exact order.
        x = self.position_m
        eps = self.cfg.sensor_hysteresis_m
        tremie = x <= self.cfg.x_tremie_m + eps
        pv = x < self.cfg.x_pv_m
        p2 = x < self.cfg.x_p2_m
        p1 = x < self.cfg.x_p1_m
        maintenance = x < self.cfg.x_maintenance_m - eps
        return tremie, pv, p2, p1, maintenance

    def outputs(self, inputs: M3Inputs) -> M3Outputs:
        t, pv, p2, p1, m = self._sensor_levels()
        word = (16 if t else 0) | (8 if pv else 0) | (4 if p2 else 0) | (2 if p1 else 0) | (1 if m else 0)
        fault = (not inputs.thermal_ok) or (not inputs.device_running)
        status = 0
        if not fault:
            status |= self.ST_READY
        if self.actual_frequency_hz > 0.05:
            status |= self.ST_RUNNING
        if inputs.command_word == self.CMD_MAINTENANCE:
            status |= self.ST_DIRECTION_MAINT
        if self.brake_is_open:
            status |= self.ST_BRAKE_OPEN
        if fault:
            status |= self.ST_FAULT
        return M3Outputs(
            status_word=status,
            actual_frequency_x100=int(round(self.actual_frequency_hz * 100.0)),
            brake_is_open=self.brake_is_open,
            thermal_ok=inputs.thermal_ok,
            pos_tremie=t,
            pos_pv=pv,
            pos_p2=p2,
            pos_p1=p1,
            pos_maintenance=m,
            sensors_word=word,
            sensor_incoherent=word not in self.VALID_SENSOR_WORDS,
            position_m=self.position_m,
            velocity_m_s=self.velocity_m_s,
        )
