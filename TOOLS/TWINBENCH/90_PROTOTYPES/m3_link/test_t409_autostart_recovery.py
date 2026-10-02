"""Guards for one-action startup and automatic FMU bridge recovery."""
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
DECL = (HERE / "PRG_T409_M3_FmuBridge_DECLARATION.st").read_text(encoding="utf-8")
IMPL = (HERE / "PRG_T409_M3_FmuBridge_IMPLEMENTATION.st").read_text(encoding="utf-8")
RUNNER = (HERE / "Start_T409_M3_Integration.ps1").read_text(encoding="utf-8")
LIVE_DIR = HERE.parents[1] / "02_SIM" / "modelica" / "live_poc"
LIVE = (LIVE_DIR / "Start_M3_Live.ps1").read_text(encoding="utf-8")
APP = (LIVE_DIR / "app.py").read_text(encoding="utf-8")

assert re.search(r"\bEnable\s*:\s*BOOL\s*:=\s*TRUE\s*;", DECL)
assert "GVL_Simulation.SimM3OpenModelicaActive :=" in IMPL
assert "GVL_Simulation.SimulationModeActive AND Enable AND NOT Stop" in IMPL
assert "IF Timeout OR NOT LinkReady THEN" in IMPL
assert "LastRxAgeCycles := LastRxAgeCycles + 1" in IMPL
assert "Start_T409_FmuGateway.ps1" in RUNNER
assert "-ResetPlant" in RUNNER and "ResetPlant" in (HERE / "Start_T409_FmuGateway.ps1").read_text(encoding="utf-8")
GATEWAY_PS = (HERE / "Start_T409_FmuGateway.ps1").read_text(encoding="utf-8")
assert "OwningProcess" in GATEWAY_PS and "IndexOf($script" in GATEWAY_PS
assert "ExecutablePath" in GATEWAY_PS and "expectedPython" in GATEWAY_PS
assert "$verifiedOwners += $ownerPid" in GATEWAY_PS
assert "$legacyDefaultPort = $owner.CommandLine -notmatch '--listen-port(?:\\s+|=)'" in GATEWAY_PS
assert "Aucun processus n'a ete arrete" in GATEWAY_PS
assert "Start_M3_Live.ps1" in RUNNER and "-FmuViaPlc" in RUNNER
assert 'source_mode in ("plc-readonly", "gateway-readonly")' in APP
assert "if ($FmuViaPlc) { $AppArgs += '--gateway-readonly' }" in LIVE
print("[PASS] one-action launcher; master bit alone activates the POC; automatic link recovery guarded")
