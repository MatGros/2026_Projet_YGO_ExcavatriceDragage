from __future__ import annotations

from engine import M3FmuEngine, STEP_S


def run_steps(engine: M3FmuEngine, count: int, direction: float, frequency_hz: float):
    snapshot = None
    for _ in range(count):
        snapshot = engine.step(direction, frequency_hz, abs(direction) > 0.05)
    assert snapshot is not None
    return snapshot


def main() -> None:
    engine = M3FmuEngine()
    try:
        initial = engine.snapshot()
        assert 19.99 <= initial.position_m <= 20.01, initial

        moving = run_steps(engine, 200, 1.0, 40.0)
        assert abs(moving.time_s - 2.0) < STEP_S / 2, moving
        assert moving.scan_counter >= 200, moving
        assert moving.frequency_act_hz > 30.0, moving
        assert moving.position_m > initial.position_m, moving

        stopped = run_steps(engine, 100, 0.0, 0.0)
        assert abs(stopped.time_s - 3.0) < STEP_S / 2, stopped
        assert stopped.frequency_act_hz < moving.frequency_act_hz, stopped

        reverse = run_steps(engine, 200, -1.0, 20.0)
        assert abs(reverse.time_s - 5.0) < STEP_S / 2, reverse
        assert reverse.velocity_mps < 0.0, reverse
        assert reverse.position_m < stopped.position_m, reverse

        print("PASS T405 HEADLESS")
        print(f"  temps={reverse.time_s:.3f} s, scans={reverse.scan_counter}")
        print(f"  position={reverse.position_m:.3f} m, vitesse={reverse.velocity_mps:.3f} m/s")
        print(f"  fréquence={reverse.frequency_act_hz:.3f} Hz, frein_ouvert={reverse.brake_is_open}")
    finally:
        engine.close()


if __name__ == "__main__":
    main()
