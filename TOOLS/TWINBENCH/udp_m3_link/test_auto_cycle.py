"""Endurance FMU accélérée : 50 cycles P1-Tremie-P1-Maintenance-P1."""
from __future__ import annotations

import sys
import ctypes
import os
from pathlib import Path

HERE = Path(__file__).resolve().parent
LIVE = HERE.parent / "modelica_poc_m3" / "live_poc"
sys.path.insert(0, str(LIVE))

from engine import M3FmuEngine  # noqa: E402
from auto_cycle import AutoCycleController  # noqa: E402


def working_set_bytes() -> int:
    if os.name == "nt":
        class ProcessMemoryCounters(ctypes.Structure):
            _fields_ = [("cb", ctypes.c_ulong), ("PageFaultCount", ctypes.c_ulong),
                        ("PeakWorkingSetSize", ctypes.c_size_t), ("WorkingSetSize", ctypes.c_size_t),
                        ("QuotaPeakPagedPoolUsage", ctypes.c_size_t), ("QuotaPagedPoolUsage", ctypes.c_size_t),
                        ("QuotaPeakNonPagedPoolUsage", ctypes.c_size_t), ("QuotaNonPagedPoolUsage", ctypes.c_size_t),
                        ("PagefileUsage", ctypes.c_size_t), ("PeakPagefileUsage", ctypes.c_size_t)]
        counters = ProcessMemoryCounters()
        counters.cb = ctypes.sizeof(counters)
        kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
        psapi = ctypes.WinDLL("psapi", use_last_error=True)
        kernel32.GetCurrentProcess.restype = ctypes.c_void_p
        psapi.GetProcessMemoryInfo.argtypes = [
            ctypes.c_void_p,
            ctypes.POINTER(ProcessMemoryCounters),
            ctypes.c_ulong,
        ]
        psapi.GetProcessMemoryInfo.restype = ctypes.c_int
        handle = kernel32.GetCurrentProcess()
        ok = psapi.GetProcessMemoryInfo(
            handle, ctypes.byref(counters), ctypes.sizeof(counters))
        if not ok:
            raise OSError("GetProcessMemoryInfo a échoué")
        return int(counters.WorkingSetSize)
    import resource
    return int(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss * 1024)


def main() -> int:
    engine = M3FmuEngine(step_s=0.01)
    cycle = AutoCycleController(dwell_s=1.0)
    cycle.start()
    p1_returns: list[float] = []
    words: set[int] = set()
    phases_seen: set[str] = set()
    dwell_started: dict[str, float] = {}
    dwell_durations: list[float] = []
    bounded = True
    try:
        snapshot = engine.snapshot()
        assert snapshot.position_m == 20.0 and snapshot.sensors_word == 3
        rss_start = working_set_bytes()
        for _ in range(500000):
            previous_phase = cycle.phase
            direction, brake_release = cycle.command(snapshot.time_s, snapshot.position_m,
                                                     snapshot.velocity_mps, snapshot.brake_is_open)
            phases_seen.add(cycle.phase)
            if cycle.phase.startswith("PAUSE"):
                assert not snapshot.brake_is_open, (cycle.phase, snapshot)
                assert abs(snapshot.velocity_mps) <= 0.005, (cycle.phase, snapshot)
                expected_sensor_word = 31 if cycle.phase == cycle.DWELL_TREMIE else 3
                assert snapshot.sensors_word == expected_sensor_word, (cycle.phase, snapshot)
                dwell_started.setdefault(cycle.phase, cycle._dwell_started_s)
            if previous_phase.startswith("PAUSE") and cycle.phase != previous_phase:
                dwell_durations.append(snapshot.time_s - dwell_started.pop(previous_phase))
            if cycle.phase in (cycle.BRAKE_TREMIE, cycle.BRAKE_P1_FROM_TREMIE):
                assert abs(snapshot.velocity_mps) <= cycle.stopped_threshold_mps, (cycle.phase, snapshot)
            snapshot = engine.step(direction, 50.0, brake_release)
            words.add(snapshot.sensors_word)
            bounded = bounded and -0.30 <= snapshot.position_m <= 30.30
            if cycle.completed_cycles > len(p1_returns):
                p1_returns.append(snapshot.position_m)
                if cycle.completed_cycles == 50:
                    break
            elif not cycle.active and cycle.completed_cycles < 50:
                cycle.start()
        drift_m = max(p1_returns) - min(p1_returns) if p1_returns else float("inf")
        rss_delta_mib = (working_set_bytes() - rss_start) / (1024.0 * 1024.0)
        required_phases = {cycle.STOP_TREMIE, cycle.BRAKE_TREMIE, cycle.DWELL_TREMIE,
                           cycle.STOP_P1_FROM_TREMIE, cycle.BRAKE_P1_FROM_TREMIE,
                           cycle.DWELL_P1_FROM_TREMIE, cycle.COMPLETE_P1}
        valid = (cycle.completed_cycles == 50 and required_phases <= phases_seen
                 and len(dwell_durations) >= 99 and min(dwell_durations, default=0.0) >= 1.0
                 and all(word in {31, 15, 7, 3, 1, 0} for word in words)
                 and bounded and drift_m <= 0.02 and rss_delta_mib <= 64.0
                 and all(19.97 <= pos <= 20.0 for pos in p1_returns))
        print("[PASS] AUTO-CYCLE FMU réaliste : 50 cycles, arrêt/frein/pause vérifiés, pause min {:.1f} s, dérive {:.4f} m, RSS {:+.2f} MiB".format(
            min(dwell_durations), drift_m, rss_delta_mib) if valid else
              "[FAIL] AUTO-CYCLE FMU : cycles={} phases={} pauses={} min_pause={:.3f}s drift={:.5f}m P1_range=({:.5f},{:.5f}) words={} RSS={:+.2f} MiB".format(
                  cycle.completed_cycles, sorted(phases_seen), len(dwell_durations),
                  min(dwell_durations, default=0.0), drift_m,
                  min(p1_returns, default=float("inf")), max(p1_returns, default=float("-inf")),
                  sorted(words), rss_delta_mib))
        return 0 if valid else 1
    finally:
        engine.close()


if __name__ == "__main__":
    raise SystemExit(main())
