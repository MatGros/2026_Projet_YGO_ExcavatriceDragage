"""T409 binary loopback protocol shared by the FMU gateway and Control Win.

The frame is deliberately fixed-width: no JSON parser or dynamic allocation is
needed in the PLC task. Little-endian, 32 bytes per command/response.
"""
from __future__ import annotations
import struct

HOST = "127.0.0.1"
PORT = 29061
MAGIC = b"M3B1"
SCHEMA = 1
COMMAND = struct.Struct("<4sBBIHHBQ9x")
PLANT = struct.Struct("<4sBBIIHHhBB5BiiB3x")

def pack_command(sequence: int, control_word: int, frequency_hz: float, brake_release: bool, timestamp_ns: int) -> bytes:
    return COMMAND.pack(MAGIC, SCHEMA, 1, sequence & 0xFFFFFFFF, int(round(float(frequency_hz) * 100.0)), control_word & 0xFFFF, int(bool(brake_release)), timestamp_ns & 0xFFFFFFFFFFFFFFFF)

def unpack_command(payload: bytes):
    if len(payload) != COMMAND.size:
        raise ValueError("command_size")
    magic, schema, kind, seq, hz, word, brake, ts = COMMAND.unpack(payload)
    if magic != MAGIC or schema != SCHEMA or kind != 1 or not 0 <= hz <= 5000:
        raise ValueError("command_header_or_range")
    return seq, word, hz / 100.0, bool(brake), ts

# Écho de l'état PLC transporté dans les octets libres 23..31 de la trame commande
# (FB_Sim_Translation_ExtLink). Version 0 = PLC sans écho : rien n'est affiché.
ECHO_OFFSET = 23
ECHO = struct.Struct("<BBBBBBhB")          # version, mode, fbstate, blockreason, flagsA, flagsB, pos_cm, safety
ECHO_UI = struct.Struct("<4sI9s")          # datagramme vue : magic, séquence, octets d'écho bruts
ECHO_UI_MAGIC = b"M3E1"
MODE_NAMES = {0: "DISABLE", 1: "MAINT_N1", 2: "MAINT_N2", 3: "SEMI_AUTO"}
STATE_NAMES = {0: "DISABLED", 1: "INIT", 2: "READY", 3: "BUSY", 4: "DONE", 5: "STOPPING", 6: "ERROR"}
BLOCK_NAMES = {0: "NONE", 1: "POWER_CUTOFF", 2: "SAFESTOP", 3: "SAFETY_FAULT", 4: "HEIGHT_INTERLOCK",
               5: "DRIVE_UNAVAILABLE", 6: "FINAL_INTERLOCK", 7: "FAULT"}
FLAGS_A = ("maint_target_enable", "maint_zone_access", "safe_stop", "power_cutoff",
           "limit_tremie", "limit_maintenance", "position_reached", "active_tremie")
FLAGS_B = ("active_maintenance", "at_tremie", "at_pv", "at_p2", "at_p1", "at_maintenance",
           "link_ready", "sensor_incoherent")


def echo_bytes(command_payload: bytes) -> bytes:
    return bytes(command_payload[ECHO_OFFSET:ECHO_OFFSET + ECHO.size])


def decode_plc_echo(raw: bytes) -> dict | None:
    """Décode les 9 octets d'écho ; None si absents (version 0) ou taille invalide."""
    if len(raw) != ECHO.size:
        return None
    version, mode, state, block, flags_a, flags_b, pos_cm, safety = ECHO.unpack(raw)
    if version == 0:
        return None
    echo = {"version": version,
            "mode": MODE_NAMES.get(mode, f"?{mode}"),
            "fb_state": STATE_NAMES.get(state, f"?{state}"),
            "block_reason": BLOCK_NAMES.get(block, f"?{block}"),
            "estimated_pos_m": pos_cm / 100.0,
            "safety_error_id": safety}
    for bit, name in enumerate(FLAGS_A):
        echo[name] = bool(flags_a >> bit & 1)
    for bit, name in enumerate(FLAGS_B):
        echo[name] = bool(flags_b >> bit & 1)
    return echo


def plc_echo_summary(echo: dict | None) -> str:
    """Ligne lisible, en français, pour le journal et la vue."""
    if echo is None:
        return "ECHO PLC ABSENT (code PLC sans écho)"
    at = next((label for key, label in (("at_tremie", "TREMIE"), ("at_pv", "PV"), ("at_p2", "P2"),
                                        ("at_p1", "P1"), ("at_maintenance", "MAINT")) if echo[key]), "-")
    sens = "TREMIE" if echo["active_tremie"] else ("MAINT" if echo["active_maintenance"] else "-")
    fdc = "+".join(label for key, label in (("limit_tremie", "TREMIE"), ("limit_maintenance", "MAINT/P1"))
                   if echo[key]) or "-"
    return (f"mode={echo['mode']} acces_maint={int(echo['maint_target_enable'])}"
            f"(bouton={int(echo['maint_zone_access'])}) etat={echo['fb_state']} blocage={echo['block_reason']}"
            f" sens={sens} dernier_point={at} fdc={fdc} pos_plc={echo['estimated_pos_m']:.2f}m"
            f" safestop={int(echo['safe_stop'])} coupure={int(echo['power_cutoff'])}"
            f" safety=0x{echo['safety_error_id']:02X} lien_plc={int(echo['link_ready'])}")


def pack_plant(sequence: int, command_sequence: int, requested_frequency_hz: float,
               measured_frequency_hz: float, velocity_mps: float, position_m: float,
               brake_open: bool, status_word: int, sensors, hard_stop: bool) -> bytes:
    values = tuple(int(bool(v)) for v in sensors)
    # Bornes du contrat M3 : une anomalie FMU ne doit jamais tuer le gateway.
    requested_scaled = max(0, min(5000, int(round(float(requested_frequency_hz) * 100.0))))
    measured_scaled = max(0, min(5000, int(round(float(measured_frequency_hz) * 100.0))))
    velocity_scaled = max(-32768, min(32767, int(round(float(velocity_mps) * 1000.0))))
    position_scaled = max(-2147483648, min(2147483647, int(round(float(position_m) * 1000.0))))
    return PLANT.pack(MAGIC, SCHEMA, 2, sequence & 0xFFFFFFFF, command_sequence & 0xFFFFFFFF, requested_scaled, measured_scaled, velocity_scaled, int(bool(brake_open)), status_word & 0xFF, *values, position_scaled, measured_scaled, int(bool(hard_stop)))

def unpack_plant(payload: bytes):
    if len(payload) != PLANT.size:
        raise ValueError("plant_size")
    fields = PLANT.unpack(payload)
    if fields[0] != MAGIC or fields[1] != SCHEMA or fields[2] != 2:
        raise ValueError("plant_header")
    return fields
