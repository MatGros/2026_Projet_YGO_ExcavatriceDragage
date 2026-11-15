"""Matrice quantitative Plan A / Plan B / Plan C pour T417-C (lecture seule CODE/)."""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import explore_m3_hypotheses as sim


def main() -> None:
    cases = [
        # 1. Baseline simulateur actuel (GVL_Simulation defaut)
        (
            "BASE-5Hz (simu actuel: k=0.02, frein 0.09s/2.0, came infinie)",
            dict(freq_hz=5.0, gain_m_per_hz_s=0.02, brake_close_delay_s=0.09, brake_decel_mps2=2.0),
        ),
        (
            "BASE-10Hz (simu actuel: k=0.02, frein 0.09s/2.0, trou came 4cm)",
            dict(freq_hz=10.0, gain_m_per_hz_s=0.02, brake_close_delay_s=0.09, brake_decel_mps2=2.0, cam_dropout_width_m=0.04),
        ),
        # 2. Plan A1 : H1 came finie + ordre maintenu/repris sans latch vs avec latch
        (
            "PLAN-A1-BUG (10Hz, came finie 4cm, frein 0.25s/0.8, sans latch)",
            dict(freq_hz=10.0, gain_m_per_hz_s=0.02, brake_close_delay_s=0.25, brake_decel_mps2=0.8, inertia_decoupled_on_stop=True, finite_cam_length_m=0.04, holds_cmd_after_trip=True, has_hardstop_latch=False),
        ),
        (
            "PLAN-A1-FIX (10Hz, came finie 4cm, frein 0.25s/0.8, AVEC LATCH)",
            dict(freq_hz=10.0, gain_m_per_hz_s=0.02, brake_close_delay_s=0.25, brake_decel_mps2=0.8, inertia_decoupled_on_stop=True, finite_cam_length_m=0.04, holds_cmd_after_trip=True, has_hardstop_latch=True),
        ),
        # 3. Plan A2 : H3/H6 Maintenance sans HardStop vs avec HardStop
        (
            "PLAN-A2-BUG (5Hz, Maintenance sans HardStop PRG_06:441)",
            dict(freq_hz=5.0, gain_m_per_hz_s=0.02, hardstop_enabled=False),
        ),
        (
            "PLAN-A2-FIX (5Hz, Maintenance AVEC HardStop + Latch)",
            dict(freq_hz=5.0, gain_m_per_hz_s=0.02, hardstop_enabled=True, has_hardstop_latch=True),
        ),
        # 4. Plan B1 : Trace 27 (Cmd=0 des contact, decel variateur ~16 Hz/s -> 618ms) + gain audit 0.0551
        (
            "PLAN-B1-NOMINAL (10Hz, Trace27 Cmd=0, k=0.0551, frein 0.09s/2.0)",
            dict(freq_hz=10.0, gain_m_per_hz_s=0.0551, decel_rate_hz_s=16.2, brake_close_delay_s=0.09, brake_decel_mps2=2.0, inertia_decoupled_on_stop=True, holds_cmd_after_trip=False),
        ),
        (
            "PLAN-B1-DEGRADE (10Hz, Trace27 Cmd=0, k=0.0551, frein 0.30s/0.35)",
            dict(freq_hz=10.0, gain_m_per_hz_s=0.0551, decel_rate_hz_s=16.2, brake_close_delay_s=0.30, brake_decel_mps2=0.35, inertia_decoupled_on_stop=True, holds_cmd_after_trip=False),
        ),
        # 5. Plan B2 : Reduction vitesse d'approche PV 10Hz -> 5Hz avant Tremie (meme frein degrade!)
        (
            "PLAN-B2-FIX (5Hz PV reduit, k=0.0551, frein 0.30s/0.35)",
            dict(freq_hz=5.0, gain_m_per_hz_s=0.0551, decel_rate_hz_s=16.2, brake_close_delay_s=0.30, brake_decel_mps2=0.35, inertia_decoupled_on_stop=True, holds_cmd_after_trip=False),
        ),
    ]
    for label, kwargs in cases:
        res = sim.run_case(**kwargs)
        print(f"{label:68s} -> {res}")


if __name__ == "__main__":
    main()
