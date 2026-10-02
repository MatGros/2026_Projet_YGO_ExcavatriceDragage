"""T407 — protocole UDP loopback M3, volontairement petit et contrôlable.

Ce module ne connaît ni CODESYS ni une adresse réseau hors boucle locale.
Il valide les images avant que le serveur de plante les consomme.
"""

from __future__ import annotations

import json
import time
from dataclasses import dataclass
from typing import Any

HOST = "127.0.0.1"
PORT = 29030
SCHEMA_VERSION = 1
ORIGIN_PLC = "PLC"
ORIGIN_OPENMODELICA = "OpenModelica"
MAX_AGE_S = 0.5


class FrameError(ValueError):
    """Trame sans contrat T406 valide."""


def now_ns() -> int:
    # Horloge partagee avec le ScriptEngine CODESYS (Python 2/3) : la trame
    # porte une date UTC, pas un compteur monotone propre a un processus.
    return time.time_ns()


def encode(frame: dict[str, Any]) -> bytes:
    return json.dumps(frame, separators=(",", ":"), sort_keys=True).encode("utf-8")


def decode(data: bytes) -> dict[str, Any]:
    try:
        frame = json.loads(data.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise FrameError("json_invalide") from exc
    if not isinstance(frame, dict):
        raise FrameError("objet_json_attendu")
    return frame


def _require(frame: dict[str, Any], key: str, expected: type | tuple[type, ...]) -> Any:
    value = frame.get(key)
    if isinstance(value, bool) and expected in (int, float, (int, float)):
        raise FrameError("{}_type".format(key))
    if not isinstance(value, expected):
        raise FrameError("{}_type".format(key))
    return value


def validate_command(frame: dict[str, Any], previous_sequence: int | None = None) -> None:
    if frame.get("kind") != "M3_CommandImage":
        raise FrameError("kind")
    if frame.get("schema") != SCHEMA_VERSION:
        raise FrameError("schema")
    if frame.get("origin") != ORIGIN_PLC:
        raise FrameError("origin")
    sequence = _require(frame, "sequence", int)
    timestamp_ns = _require(frame, "source_timestamp_ns", int)
    if sequence < 0 or (previous_sequence is not None and sequence <= previous_sequence):
        raise FrameError("sequence")
    age_s = (now_ns() - timestamp_ns) / 1_000_000_000.0
    if age_s < -0.1 or age_s > MAX_AGE_S:
        raise FrameError("age")
    _require(frame, "control_word", int)
    frequency_hz = _require(frame, "frequency_hz", (int, float))
    if not 0.0 <= float(frequency_hz) <= 50.0:
        raise FrameError("frequency_hz_range")
    _require(frame, "brake_release_cmd", bool)


def make_plant_image(sequence: int, command: dict[str, Any], snapshot: Any) -> dict[str, Any]:
    """Projette la snapshot FMU vers l'image de plante requise par T406."""
    return {
        "kind": "M3_PlantImage",
        "schema": SCHEMA_VERSION,
        "origin": ORIGIN_OPENMODELICA,
        "sequence": sequence,
        "source_timestamp_ns": now_ns(),
        "command_sequence": command["sequence"],
        "is_valid": True,
        "validity_reason": "ok",
        "frequency_act_hz": float(snapshot.frequency_act_hz),
        "drive_status_word": int(snapshot.drive_status_word),
        "brake_is_open": bool(snapshot.brake_is_open),
        "thermal_ok": True,
        "sensors": {
            "tremie": bool(snapshot.tremie),
            "pv": bool(snapshot.pv),
            "p2": bool(snapshot.p2),
            "p1": bool(snapshot.p1),
            "maintenance": bool(snapshot.maintenance),
        },
        "position_m": float(snapshot.position_m),
        "velocity_mps": float(snapshot.velocity_mps),
        "hard_stop": bool(snapshot.hard_stop_tremie or snapshot.hard_stop_maintenance),
    }


def control_word_to_direction(control_word: int) -> float:
    """Convention PLC prouvée dans FB_Translation : 1=FWD Trémie, 2=REV Maintenance."""
    if control_word == 1:
        return 1.0
    if control_word == 2:
        return -1.0
    return 0.0
