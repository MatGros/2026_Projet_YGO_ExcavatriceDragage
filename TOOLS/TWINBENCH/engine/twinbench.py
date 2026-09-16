#!/usr/bin/env python3
"""TwinBench — moteur de simulation, profil hote. POC phase 1.

Regles de SPEC_01 appliquees ici et verifiables :
  §3.1  aucun ecretage silencieux : franchir une borne emet un evenement
        overtravel horodate portant vitesse et energie cinetique.
  §3.2  tout run porte une graine ; meme graine => trace identique.
  §2.3  chaque parametre porte provenance et verification ; le defaut est
        pessimiste (guessed + unverified).
  §2.2  le niveau atteignable est CALCULE depuis les provenances, jamais cru
        sur declaration.

Le moteur ne decide d'aucune consequence de casse (hors perimetre phase 1) :
il constate et il trace.
"""

from __future__ import annotations

import json
import random
from dataclasses import dataclass, field
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]

# Niveau maximal autorise par la provenance d'un parametre (SPEC_01 §2.2).
LEVEL_BY_SOURCE = {
    "measured": "L2", "nameplate": "L2", "manufacturer_doc": "L2", "standard": "L2",
    "estimated": "L1", "web_search": "L1", "inherited_from_project": "L1",
    "guessed": "L1",
}


def param(raw, default=None):
    """Normalise un parametre. Defaut PESSIMISTE : guessed + unverified."""
    if raw is None:
        raw = {"value": default}
    if not isinstance(raw, dict) or "value" not in raw:
        raw = {"value": raw}
    prov = raw.get("provenance") or {}
    veri = raw.get("verification") or {}
    return {
        "value": raw["value"],
        "source": prov.get("source", "guessed"),
        "reference": prov.get("reference", ""),
        "verified": veri.get("status", "unverified"),
    }


@dataclass
class Axis:
    """Axe lineaire : frein, rampe, roue libre. Ne s'ecrete jamais."""
    name: str
    lo: float
    hi: float
    v_nom: float
    brake_ms: float
    accel: float
    coast: float
    pos: float = 0.0
    vel: float = 0.0
    brake_timer: float = 0.0
    brake_released: bool = False
    phase: str = "IDLE"
    overtravel_emitted: bool = False

    def step(self, dt_s: float, fwd: bool, rev: bool, t_ms: int, events: list):
        cmd = (1 if fwd else 0) - (1 if rev else 0)

        # Frein : desserrage temporise, serrage immediat a la coupure.
        if cmd != 0:
            self.brake_timer += dt_s * 1000.0
            self.brake_released = self.brake_timer >= self.brake_ms
        else:
            self.brake_timer = 0.0
            self.brake_released = False

        if cmd != 0 and self.brake_released:
            target = cmd * self.v_nom
            dv = self.accel * dt_s
            self.vel += max(-dv, min(dv, target - self.vel))
            self.phase = "RAMP" if abs(self.vel) < self.v_nom * 0.98 else "RUN"
        elif cmd != 0:
            self.phase = "BRAKE_RELEASE"
        else:
            # Roue libre : la vitesse retombe par frottement, pas d'arret magique.
            dv = self.coast * dt_s
            if abs(self.vel) <= dv:
                self.vel = 0.0
                self.phase = "IDLE"
            else:
                self.vel -= dv if self.vel > 0 else -dv
                self.phase = "COAST"

        self.pos += self.vel * dt_s

        # SPEC_01 §3.1 : PAS de min/max. On constate et on trace.
        if not self.overtravel_emitted and (self.pos > self.hi or self.pos < self.lo):
            limit = "travel_m.upper" if self.pos > self.hi else "travel_m.lower"
            mass_kg = 180.0  # unknown : masse non renseignee, hypothese affichee
            events.append({
                "t_ms": t_ms, "kind": "overtravel", "instance": self.name,
                "limit": limit, "speed_mps": round(self.vel, 3),
                "kinetic_energy_J": round(0.5 * mass_kg * self.vel ** 2, 1),
                "overshoot_m": round(self.pos - self.hi if self.pos > self.hi
                                     else self.lo - self.pos, 3),
                "note": "masse hypothetique 180 kg (unknown) — energie indicative",
            })
            self.overtravel_emitted = True


@dataclass
class Switch:
    """Detecteur de position, avec hysteresis, retard et modes de panne."""
    name: str
    trigger: float
    window: float
    hyst: float
    response_ms: float
    fault: str = "none"
    raw: bool = False
    out: bool = False
    pend: float = 0.0

    def step(self, dt_s: float, pos: float):
        w = self.window + (self.hyst if self.raw else 0.0)
        physical = abs(pos - self.trigger) <= w
        if self.fault == "stuck_low":
            self.raw, self.out = physical, False
            return
        if self.fault == "stuck_high":
            self.raw, self.out = physical, True
            return
        self.raw = physical
        if physical != self.out:
            self.pend += dt_s * 1000.0
            if self.pend >= self.response_ms:
                self.out = physical
                self.pend = 0.0
        else:
            self.pend = 0.0

    def distance(self, pos: float) -> float:
        return round(pos - self.trigger, 3)


@dataclass
class Joystick:
    """Axe unique avec retour de ressort : le neutre n'est jamais instantane."""
    spring_ms: float
    value: float = 0.0
    held: float = 0.0

    def step(self, dt_s: float, intent: float):
        if intent != 0.0:
            self.value = intent
        elif self.value != 0.0:
            decay = dt_s * 1000.0 / self.spring_ms
            self.value = 0.0 if abs(self.value) <= decay else \
                self.value - (decay if self.value > 0 else -decay)


class Simulation:
    def __init__(self, model_path: Path, seed: int):
        self.model = yaml.safe_load(model_path.read_text(encoding="utf-8"))
        self.seed = seed
        self.rng = random.Random(seed)
        self.scan_ms = self.model.get("scan_ms", 20)
        self.events: list = []
        self._build()

    def _build(self):
        inst = self.model["instances"]
        m3 = inst["M3"]["params"]
        self.p_travel = param(m3.get("travel_m"))
        self.p_speed = param(m3.get("nominal_speed_mps"))
        self.p_brake = param(m3.get("brake_release_ms"), 120)
        self.p_coast = param(m3.get("coast_mps2"), 0.35)

        lo, hi = self.p_travel["value"]
        self.axis = Axis(name="M3", lo=lo, hi=hi, v_nom=self.p_speed["value"],
                         brake_ms=self.p_brake["value"], accel=0.8,
                         coast=self.p_coast["value"], pos=6.20)

        self.switches = []
        for name, node in inst.items():
            if not str(node.get("from", "")).startswith("sensors/"):
                continue
            p = node.get("params", {})
            self.switches.append(Switch(
                name=name, trigger=p["trigger_m"], window=p.get("window_m", 0.25),
                hyst=p.get("hysteresis_m", 0.05), response_ms=p.get("response_ms", 8)))

        self.joy = Joystick(spring_ms=param(
            inst["Joystick"]["params"].get("spring_return_ms"), 60)["value"])

        # Niveau CALCULE depuis les provenances, jamais celui declare.
        sources = [p["source"] for p in
                   (self.p_travel, self.p_speed, self.p_brake, self.p_coast)]
        self.level_computed = "L2" if all(
            LEVEL_BY_SOURCE.get(s) == "L2" for s in sources) else "L1"
        self.unverified = [n for n, p in [
            ("M3.travel_m", self.p_travel), ("M3.nominal_speed_mps", self.p_speed),
            ("M3.brake_release_ms", self.p_brake), ("M3.coast_mps2", self.p_coast),
        ] if p["verified"] != "verified"]

    def run(self, scenario: str, faults: dict | None = None, n_scans: int = 1150):
        for sw in self.switches:
            sw.fault = (faults or {}).get(sw.name, "none")

        dt = self.scan_ms / 1000.0
        # Dispersion de phase monde/scan : tiree sur la graine (SPEC_01 §3.2).
        jitter = self.rng.uniform(0.0, dt)
        frames = []

        for i in range(n_scans):
            t_ms = int(i * self.scan_ms + jitter * 1000.0)

            # Intention operateur : l'operateur maintient vers MAINTENANCE et
            # compte sur l'arret automatique sur detecteur. Il relache tard.
            intent = 1.0 if i < 1050 else 0.0
            self.joy.step(dt, intent)
            deadman = self.joy.value != 0.0

            fwd = deadman and self.joy.value > 0.05
            rev = deadman and self.joy.value < -0.05

            # L'arret sur detecteur : c'est la SEULE protection modelisee ici.
            s5 = next(s for s in self.switches if s.name == "S5_Maintenance")
            if s5.out:
                fwd = False

            self.axis.step(dt, fwd, rev, t_ms, self.events)
            for sw in self.switches:
                sw.step(dt, self.axis.pos)

            frames.append({
                "t_ms": t_ms,
                "actuators": {"M3": {
                    "position_m": round(self.axis.pos, 3),
                    "speed_mps": round(self.axis.vel, 3),
                    "brake_released": self.axis.brake_released,
                    "relay_fwd": fwd, "relay_rev": rev,
                    "phase": self.axis.phase,
                }},
                "sensors": {s.name: {
                    "detected": s.out, "distance_m": s.distance(self.axis.pos),
                    "fault": s.fault,
                } for s in self.switches},
                "operator": {"joystick": round(self.joy.value, 3), "deadman": deadman},
            })

        return {
            "meta": {
                "tool": "TwinBench", "phase": "POC-1", "scenario": scenario,
                "seed": self.seed, "scan_ms": self.scan_ms,
                "sampling_jitter_ms": round(jitter * 1000.0, 3),
                "level_computed": self.level_computed,
                "unverified_params": self.unverified,
                "faults": faults or {},
            },
            "params": {
                "travel_m": self.p_travel, "nominal_speed_mps": self.p_speed,
                "brake_release_ms": self.p_brake, "coast_mps2": self.p_coast,
            },
            "views": self.model.get("views", {}),
            "frames": frames,
            "events": self.events,
        }
