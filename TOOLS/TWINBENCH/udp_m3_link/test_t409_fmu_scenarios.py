"""Deterministic SIL checks for the M3 FMU model, without PLC/CODESYS."""
from __future__ import annotations

import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
LIVE = HERE.parent / "modelica_poc_m3" / "live_poc"
if str(LIVE) not in sys.path:
    sys.path.insert(0, str(LIVE))
from engine import M3FmuEngine  # noqa: E402


def run() -> dict:
    engine = M3FmuEngine()
    samples = []
    try:
        # Frein applique : une consigne ne doit produire aucun déplacement.
        start = engine.snapshot()
        for _ in range(100):
            samples.append(engine.step(1.0, 40.0, False))
        brake_closed = all(not s.brake_is_open for s in samples) and all(
            abs(s.velocity_mps) < 1e-9 for s in samples
        ) and abs(samples[-1].position_m - start.position_m) < 1e-9

        # Desserrage puis marche vers Maintenance : position croissante et capteurs admissibles.
        forward = []
        for _ in range(4000):  # 40 s, traverse P1 -> Maintenance et butee.
            forward.append(engine.step(1.0, 40.0, True))
        positions = [s.position_m for s in forward]
        words = [s.sensors_word for s in forward]
        allowed_words = {31, 15, 7, 3, 1, 0}
        forward_motion = positions[-1] > positions[0] + 0.5
        sensors_valid = all(w in allowed_words for w in words)
        no_overspeed = all(abs(s.velocity_mps) <= 1.01 for s in forward)

        # Inversion : retour vers Trémie, position décroissante.
        reverse = []
        for _ in range(4000):  # 40 s, retour jusqu'a la butee Tremie.
            reverse.append(engine.step(-1.0, 40.0, True))
        reverse_motion = reverse[-1].position_m < reverse[0].position_m - 0.5
        reverse_valid = all(s.sensors_word in allowed_words for s in reverse)

        result = {
            "brake_closed_no_motion": brake_closed,
            "forward_motion_monotonic_region": forward_motion,
            "reverse_motion": reverse_motion,
            "sensor_words_admissible": sensors_valid and reverse_valid,
            "velocity_bounded_1mps": no_overspeed,
            "start_position_m": start.position_m,
            "forward_end_position_m": forward[-1].position_m,
            "reverse_end_position_m": reverse[-1].position_m,
            "forward_words_seen": sorted(set(words)),
            "reverse_words_seen": sorted(set(s.sensors_word for s in reverse)),
        }
        result["pass"] = all(result[k] for k in (
            "brake_closed_no_motion", "forward_motion_monotonic_region",
            "reverse_motion", "sensor_words_admissible", "velocity_bounded_1mps"))
        return result
    finally:
        engine.close()


if __name__ == "__main__":
    result = run()
    print(json.dumps(result, indent=2, sort_keys=True))
    raise SystemExit(0 if result["pass"] else 1)
