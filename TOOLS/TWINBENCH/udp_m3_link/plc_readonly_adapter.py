"""Lecture seule de télémétrie M3 pour l'interface commune FMU/PLC.

Ce module ne commande rien : il reçoit uniquement des trames T409 déjà produites
par une passerelle autorisée. Il est donc utilisable pour le PLC réel sans écrire
dans l'automate.
"""
from __future__ import annotations

import socket
import time
from dataclasses import dataclass

from m3_binary_protocol import HOST, PLANT, unpack_plant
from sequence_rules import is_acceptable


@dataclass(frozen=True)
class ReadOnlyM3State:
    source: str
    stale: bool
    sequence: int
    requested_frequency_hz: float
    measured_frequency_hz: float
    velocity_mps: float
    position_m: float
    brake_open: bool
    status_word: int
    sensors: tuple[bool, bool, bool, bool, bool]
    hard_stop: bool
    age_ms: int
    received_monotonic_s: float


class UdpPlantReadOnlyAdapter:
    """Récepteur UDP T409 sans émission de datagramme."""

    def __init__(self, port: int = 29072, stale_after_s: float = 0.25) -> None:
        self._socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self._socket.bind((HOST, port))
        self._socket.setblocking(False)
        self._stale_after_s = float(stale_after_s)
        self._last: ReadOnlyM3State | None = None
        self._last_received = 0.0
        self._last_sequence = None

    def poll(self) -> ReadOnlyM3State:
        # Vider le buffer : toujours afficher la dernière trame disponible.
        while True:
            try:
                payload, address = self._socket.recvfrom(128)
            except (BlockingIOError, socket.timeout, OSError):
                break
            if address[0] != HOST or len(payload) != PLANT.size:
                continue
            try:
                fields = unpack_plant(payload)
            except (ValueError, OSError):
                continue
            sensor_word = sum(int(bool(value)) << shift
                              for shift, value in zip((4, 3, 2, 1, 0), fields[10:15]))
            if fields[5] > 5000 or fields[6] > 5000:
                continue
            if sensor_word not in (31, 15, 7, 3, 1, 0):
                continue
            # Un miroir relancé repart à zéro après expiration. Pendant un flux
            # frais, seule la progression UDINT (avec wrap FFFFFFFF -> 0) passe.
            if not is_acceptable(self._last_sequence, int(fields[3]), self.state().stale):
                continue
            sensors = tuple(bool(value) for value in fields[10:15])
            self._last_received = time.monotonic()
            self._last_sequence = int(fields[3])
            self._last = ReadOnlyM3State(
                source="PLC_READONLY",
                stale=False,
                sequence=int(fields[3]),
                requested_frequency_hz=float(fields[5]) / 100.0,
                measured_frequency_hz=float(fields[6]) / 100.0,
                velocity_mps=float(fields[7]) / 1000.0,
                position_m=float(fields[15]) / 1000.0,
                brake_open=bool(fields[8]),
                status_word=int(fields[9]),
                sensors=sensors,
                hard_stop=bool(fields[17]),
                age_ms=0,
                received_monotonic_s=self._last_received,
            )
        return self.state()

    def state(self) -> ReadOnlyM3State:
        if self._last is None:
            return ReadOnlyM3State("PLC_READONLY", True, 0, 0.0, 0.0, 0.0, 0.0,
                                   False, 0, (False, False, False, False, False), False, 0, 0.0)
        age_ms = max(0, int((time.monotonic() - self._last_received) * 1000.0))
        return ReadOnlyM3State(
            source=self._last.source,
            stale=age_ms > self._stale_after_s * 1000.0,
            sequence=self._last.sequence,
            requested_frequency_hz=self._last.requested_frequency_hz,
            measured_frequency_hz=self._last.measured_frequency_hz,
            velocity_mps=self._last.velocity_mps,
            position_m=self._last.position_m,
            brake_open=self._last.brake_open,
            status_word=self._last.status_word,
            sensors=self._last.sensors,
            hard_stop=self._last.hard_stop,
            age_ms=age_ms,
            received_monotonic_s=self._last_received,
        )

    def close(self) -> None:
        self._socket.close()
