"""Guardrail for the CODESYS read-only telemetry mirror."""
from pathlib import Path

path = Path(__file__).parents[2] / "PLC_CSV_SNAPSHOT" / "codesys_console" / "codesys_m3_telemetry_mirror.py"
text = path.read_text(encoding="utf-8")
bridge = (Path(__file__).resolve().parent / "PRG_T409_M3_FmuBridge_IMPLEMENTATION.st").read_text(encoding="utf-8")
forbidden = (
    "write_values", "write_value", "set_value", "force_value", "download",
    "set_prepared_value", "write_prepared_values", "force_prepared_values",
    "unforce", "write", "force",
)
found = [token for token in forbidden if token in text]
assert not found, "write API present: {}".format(found)
assert "sock.sendto" in text
assert 'HOST = "127.0.0.1"' in text
assert "PORT = 29072" in text
assert "29062" not in text
assert "SysSockCreateUdp(29061, 29062" in bridge
assert "PORT = 29072" in text
assert "finally:" in text and "sock.close()" in text
print("[PASS] T412 mirror: lecture seule, loopback et fermeture socket")
