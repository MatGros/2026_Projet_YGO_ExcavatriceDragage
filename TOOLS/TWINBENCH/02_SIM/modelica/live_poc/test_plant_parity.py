"""Garde-fou parité : la FMU M3 reproduit le chemin nominal de FB_Sim_Translation.

Référence = transposition Python ligne à ligne du ST (CODE/L_SIMULATION :
FB_Sim_Translation, FB_Sim_TranslationDrive, FB_Sim_TranslationBrake,
FB_Sim_PositionSensor), sans charge suspendue, bruit ni intermittence.
Scénario piloté comme le PLC : Maintenance (40 Hz puis 20 Hz après P1, arrêt au
capteur), pause, Trémie (40 Hz puis 20 Hz après PV, arrêt au capteur), inversion.
"""
from __future__ import annotations

import sys

from engine import M3FmuEngine

TS = 0.01
THRESHOLDS = (0.05, 5.0, 15.0, 20.0, 29.95)  # Trémie, PV, P2, P1, Maintenance


class StReference:
    def __init__(self) -> None:
        self.f_cmd = self.f_el = self.f_act = 0.0
        self.travel = self.vel = 0.0
        self.pos = 20.0
        self.brake_mech = self.brake_contact = False
        self.brake_t = self.contact_t = 0.0
        self.hard_stop = False
        self.raw = [self.pos <= t for t in THRESHOLDS]
        self.out = list(self.raw)
        self.sensor_t = [0.0] * 5

    def step(self, direction: int, hz: float, brake_cmd: bool) -> None:
        alpha = TS / (0.15 + TS)
        target = min(max(hz, 0.0), 50.0) if direction else 0.0
        delta = target - self.f_cmd
        step = (20.0 if delta >= 0 else 20.0) * TS
        self.f_cmd += min(max(delta, -step), step)
        self.f_el += alpha * (self.f_cmd - self.f_el)
        self.f_act = 0.0 if self.f_el < 0.005 else self.f_el
        if brake_cmd:
            if not self.brake_mech:
                self.brake_t += TS
                if self.brake_t >= 0.10 - 1e-6:
                    self.brake_mech, self.brake_t = True, 0.0
            else:
                self.brake_t = 0.0
        elif self.f_act <= 0.5:
            if self.brake_mech:
                self.brake_t += TS
                if self.brake_t >= 0.09 - 1e-6:
                    self.brake_mech, self.brake_t = False, 0.0
            else:
                self.brake_t = 0.0
        else:
            self.brake_t = 0.0
        if self.brake_mech != self.brake_contact:
            self.contact_t += TS
            if self.contact_t >= 0.01 - 1e-6:
                self.brake_contact, self.contact_t = self.brake_mech, 0.0
        else:
            self.contact_t = 0.0
        if direction:
            self.travel = float(direction)
        elif self.f_act <= 0.5:
            self.travel = 0.0
        v_target = self.travel * 0.02 * self.f_act if self.brake_mech else 0.0
        self.vel += alpha * (v_target - self.vel)
        if not self.brake_mech:
            self.vel = 0.0
        candidate = self.pos + self.vel * TS
        self.hard_stop = candidate < 0.0 or candidate > 30.0
        if self.hard_stop:
            self.pos, self.vel = min(max(candidate, 0.0), 30.0), 0.0
        else:
            self.pos = candidate
        for i, threshold in enumerate(THRESHOLDS):
            self.raw[i] = self.pos <= threshold + (0.02 if self.raw[i] else -0.02)
            if self.out[i] != self.raw[i]:
                self.sensor_t[i] += TS
                if self.sensor_t[i] >= 0.01 - 1e-6:
                    self.out[i], self.sensor_t[i] = self.raw[i], 0.0
            else:
                self.sensor_t[i] = 0.0

    @property
    def word(self) -> int:
        return sum(int(v) << s for s, v in zip((4, 3, 2, 1, 0), self.out))


class PlcLikeDriver:
    """Stimuli seulement (pas de logique PLC) : séquence d'ordres type accostage."""

    def __init__(self) -> None:
        self.phase = 0
        self.wait = 0

    def command(self, word: int) -> tuple[int, float, bool]:
        tremie, pv, p1, maint = word & 16, word & 8, word & 2, word & 1
        if self.phase == 0:                      # repos initial
            self.wait += 1
            if self.wait >= 50:
                self.phase, self.wait = 1, 0
            return 0, 0.0, False
        if self.phase == 1:                      # vers Maintenance
            if not maint:
                self.phase = 2
                return 0, 0.0, False
            return 1, (40.0 if p1 else 20.0), True
        if self.phase == 2:                      # pause
            self.wait += 1
            if self.wait >= 300:
                self.phase, self.wait = 3, 0
            return 0, 0.0, False
        if self.phase == 3:                      # vers Trémie
            if tremie:
                self.phase = 4
                return 0, 0.0, False
            return -1, (20.0 if pv else 40.0), True
        if self.phase == 4:                      # pause puis inversion en marche
            self.wait += 1
            if self.wait >= 300:
                self.phase, self.wait = 5, 0
            return 0, 0.0, False
        self.wait += 1                           # 5 : aller 3 s puis inversion brutale
        if self.wait < 300:
            return 1, 40.0, True
        return -1, 40.0, True


def main() -> int:
    engine = M3FmuEngine()
    reference = StReference()
    driver = PlcLikeDriver()
    worst = {"pos": 0.0, "hz": 0.0}
    mismatches: list[str] = []
    brake_drop_hz: list[float] = []
    previous_brake = False
    snap = engine.snapshot()
    try:
        for k in range(12000):
            direction, hz, brake = driver.command(snap.sensors_word)
            snap = engine.step(float(direction), hz, brake)
            reference.step(direction, hz, brake)
            worst["pos"] = max(worst["pos"], abs(snap.position_m - reference.pos))
            worst["hz"] = max(worst["hz"], abs(snap.frequency_act_hz - reference.f_act))
            discrete = (snap.brake_is_open, snap.sensors_word,
                        snap.drive_status_word, snap.hard_stop_tremie or snap.hard_stop_maintenance)
            expected = (reference.brake_contact, reference.word,
                        0x87 if reference.f_act > 0.5 else 0x80, reference.hard_stop)
            if discrete != expected and len(mismatches) < 5:
                mismatches.append(f"t={k * TS:.2f}s FMU={discrete} ST={expected}")
            if previous_brake and not snap.brake_is_open:
                brake_drop_hz.append(snap.frequency_act_hz)
            previous_brake = snap.brake_is_open
        print(f"[INFO] phase finale={driver.phase} pos={snap.position_m:.3f} m "
              f"écart max pos={worst['pos']:.2e} m hz={worst['hz']:.2e} Hz "
              f"frein retombé à {[round(v, 2) for v in brake_drop_hz]} Hz")
        errors = list(mismatches)
        if worst["pos"] > 1e-6 or worst["hz"] > 1e-6:
            errors.append(f"écart analogique {worst}")
        if driver.phase != 5:
            errors.append(f"scénario incomplet (phase {driver.phase})")
        if any(v > 0.5 for v in brake_drop_hz):
            errors.append(f"frein retombé variateur en marche : {brake_drop_hz}")
        if errors:
            for error in errors:
                print(f"[FAIL] {error}")
            return 1
        print("[PASS] Parité FMU / FB_Sim_Translation nominal sur 120 s (accostages + inversion)")
        return 0
    finally:
        engine.close()


if __name__ == "__main__":
    sys.exit(main())
