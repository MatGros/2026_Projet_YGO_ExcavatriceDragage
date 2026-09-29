"""Séquence AUTO-CYCLE FMU avec arrêt, frein fermé et pause aux postes."""

from __future__ import annotations


class AutoCycleController:
    MOVE_TREMIE = "VERS TRÉMIE"
    STOP_TREMIE = "ARRÊT TRÉMIE"
    BRAKE_TREMIE = "FREIN TRÉMIE"
    DWELL_TREMIE = "PAUSE TRÉMIE"
    MOVE_P1_FROM_TREMIE = "VERS P1 (TRÉMIE)"
    STOP_P1_FROM_TREMIE = "ARRÊT P1 (TRÉMIE)"
    BRAKE_P1_FROM_TREMIE = "FREIN P1 (TRÉMIE)"
    DWELL_P1_FROM_TREMIE = "PAUSE P1 (TRÉMIE)"
    COMPLETE_P1 = "CYCLE TERMINÉ · ARRÊT P1"

    def __init__(self, dwell_s: float = 1.0, stopped_threshold_mps: float = 0.005,
                 deceleration_mps2: float = 0.5) -> None:
        self.dwell_s = float(dwell_s)
        self.stopped_threshold_mps = float(stopped_threshold_mps)
        self.deceleration_mps2 = float(deceleration_mps2)
        if self.deceleration_mps2 <= 0:
            raise ValueError("deceleration_mps2 doit être strictement positif")
        self.active = False
        self.phase = "ARRÊT"
        self.completed_cycles = 0
        self._dwell_started_s = 0.0
        self._last_command_time_s: float | None = None

    def start(self) -> None:
        self.active = True
        self.phase = self.MOVE_TREMIE
        self._dwell_started_s = 0.0
        self._last_command_time_s = None

    def stop(self) -> None:
        self.active = False
        self.phase = "ARRÊT"

    def reset(self) -> None:
        self.stop()
        self.completed_cycles = 0
        self._dwell_started_s = 0.0
        self._last_command_time_s = None

    def command(self, time_s: float, position_m: float, velocity_mps: float,
                brake_open: bool) -> tuple[float, bool]:
        """Renvoie (direction, desserrer_frein), à appliquer au pas suivant."""
        sample_period_s = (0.0 if self._last_command_time_s is None else
                           max(0.0, time_s - self._last_command_time_s))
        self._last_command_time_s = time_s
        if not self.active:
            return 0.0, False

        moves = {
            # Atterrissage de 5 mm côté actif du capteur, pour garder son
            # retour vrai malgré l'intégration numérique et l'inertie FMU.
            self.MOVE_TREMIE: (-1.0, -0.005, self.STOP_TREMIE),
            self.MOVE_P1_FROM_TREMIE: (1.0, 19.985, self.STOP_P1_FROM_TREMIE),
        }
        if self.phase in moves:
            direction, target, stop_phase = moves[self.phase]
            # Anticipe la rampe de décélération réelle du modèle (25 Hz/s ×
            # 0,02 m/s/Hz = 0,5 m/s²). Sans cette distance de freinage, la
            # position dépasse les postes avant que vitesse nulle soit atteinte.
            distance_to_target_m = (target - position_m) * direction
            stopping_distance_m = ((velocity_mps * velocity_mps) / (2.0 * self.deceleration_mps2)
                                   + abs(velocity_mps) * sample_period_s)
            reached = distance_to_target_m <= stopping_distance_m
            if reached:
                self.phase = stop_phase
                return 0.0, True
            return direction, True

        stops = {
            self.STOP_TREMIE: self.BRAKE_TREMIE,
            self.STOP_P1_FROM_TREMIE: self.BRAKE_P1_FROM_TREMIE,
        }
        if self.phase in stops:
            brake_phase = stops[self.phase]
            if abs(velocity_mps) <= self.stopped_threshold_mps:
                self.phase = brake_phase
                return 0.0, False
            return 0.0, True

        brake_to_dwell = {
            self.BRAKE_TREMIE: self.DWELL_TREMIE,
            self.BRAKE_P1_FROM_TREMIE: self.DWELL_P1_FROM_TREMIE,
        }
        if self.phase in brake_to_dwell:
            if not brake_open:
                self._dwell_started_s = time_s
                self.phase = brake_to_dwell[self.phase]
            return 0.0, False

        if time_s - self._dwell_started_s < self.dwell_s:
            return 0.0, False

        next_phase = {
            self.DWELL_TREMIE: self.MOVE_P1_FROM_TREMIE,
            self.DWELL_P1_FROM_TREMIE: self.COMPLETE_P1,
        }[self.phase]
        if self.phase == self.DWELL_P1_FROM_TREMIE:
            self.completed_cycles += 1
        self.phase = next_phase
        if self.phase == self.COMPLETE_P1:
            self.active = False
        return 0.0, False
