"""Static guardrails for the T409 Control Win POU."""
from pathlib import Path

HERE = Path(__file__).resolve().parent
impl = (HERE / "PRG_T409_M3_FmuBridge_IMPLEMENTATION.st").read_text(encoding="utf-8")
decl = (HERE / "PRG_T409_M3_FmuBridge_DECLARATION.st").read_text(encoding="utf-8")

required = (
    "NOT GVL_Simulation.SimulationModeActive",
    "NOT GVL_Simulation.SimM3OpenModelicaActive",
    "LinkReady := FALSE",
    "Timeout := TRUE",
    "SensorWordIncoherent",
    "FmuPosition_M",
    "FmuVelocity_Mps",
    "FmuFrequency_Hz",
)
missing = [item for item in required if item not in impl]
writes = [line.strip() for line in impl.splitlines()
          if "GVL_Simulation.SimM3OpenModelica." in line and ":=" in line]
bad_writes = [line for line in writes if "GVL_Simulation.SimM3OpenModelica." not in line]
assert "FmuPosition_M" in decl and "FmuAge_ms" in decl
if missing or bad_writes:
    raise SystemExit(f"FAIL missing={missing} bad_writes={bad_writes}")
print(f"[PASS] T409 POU guardrails; SimM3 writes={len(writes)}")
