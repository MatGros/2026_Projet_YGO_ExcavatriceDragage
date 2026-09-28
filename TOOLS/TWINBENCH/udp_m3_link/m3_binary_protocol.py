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
