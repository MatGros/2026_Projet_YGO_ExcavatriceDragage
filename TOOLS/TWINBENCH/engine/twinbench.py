#!/usr/bin/env python3
"""TwinBench — moteur de simulation, profil hote.

Topologie reelle de l'axe de translation : variateur -> moteur -> frein ->
axe mecanique -> chaine de cames. Quatre equipements distincts, pas un.

Regles de SPEC_01 appliquees et verifiables ici :
  §3.1  aucun ecretage silencieux : franchir la course emet un evenement.
  §3.2  tout run porte une graine ; meme graine => trace identique.
  §2.3  provenance et verification par parametre, defaut pessimiste.
  §2.2  le niveau est CALCULE depuis les provenances, jamais declare.

Les valeurs absentes du code source sont des placeholders assumes. Le moteur
ne les invente pas : il les lit, et signale ce qui reste UNKNOWN.
"""

from __future__ import annotations

import random
from dataclasses import dataclass, field
from pathlib import Path

import yaml

LEVEL_BY_SOURCE = {
    "measured": "L2", "nameplate": "L2", "manufacturer_doc": "L2",
    "standard": "L2", "code_source": "L2",
    "estimated": "L1", "web_search": "L1", "inherited_from_project": "L1",
    "guessed": "L1",
}


def param(raw, default=None):
    """Normalise un parametre. Defaut PESSIMISTE : guessed + unverified."""
    if raw is None:
        raw = {"value": default}
    if not isinstance(raw, dict) or "value" not in raw:
        raw = {"value": raw}
    prov, veri = raw.get("provenance") or {}, raw.get("verification") or {}
    val = raw["value"]
    return {
        "value": default if val is None else val,
        "declared": val,
        "source": prov.get("source", "guessed"),
        "reference": prov.get("reference", ""),
        "verified": veri.get("status", "unverified"),
        "blocks": raw.get("blocks", []),
    }


@dataclass
class Vfd:
    """Variateur : rampe la frequence vers sa consigne. Ne decide rien d'autre."""
    freq_max: float
    accel_s: float
    decel_s: float
    stop_hz: float
    freq: float = 0.0
    running: bool = False

    def step(self, dt: float, setpoint_hz: float, run: bool):
        tgt = setpoint_hz if run else 0.0
        rate = (self.freq_max / self.accel_s) if tgt > self.freq \
            else (self.freq_max / self.decel_s)
        d = rate * dt
        self.freq += max(-d, min(d, tgt - self.freq))
        if self.freq < 0.01:
            self.freq = 0.0
        self.running = abs(self.freq) > self.stop_hz

    @property
    def status_word(self) -> int:
        w = 1                                   # bit0 ready
        if self.running:            w |= 1 << 1
        if self.freq >= self.freq_max * .99: w |= 1 << 2
        w |= 1 << 6                             # bus DC ok
        return w


@dataclass
class Brake:
    """Frein a manque de courant : desserrage et serrage TEMPORISES, asymetriques."""
    release_ms: float
    engage_ms: float
    timer: float = 0.0
    released: bool = False

    def step(self, dt: float, release_cmd: bool):
        ms = dt * 1000.0
        if release_cmd:
            self.timer = min(self.timer + ms, self.release_ms)
            self.released = self.timer >= self.release_ms
        else:
            self.timer = max(self.timer - ms * (self.release_ms / max(self.engage_ms, 1)), 0.0)
            self.released = self.timer >= self.release_ms


@dataclass
class Axis:
    """Axe lineaire. N'ECRETE JAMAIS sa position : il constate et il trace."""
    lo: float
    hi: float
    m_per_hz_s: float
    pos: float
    vel: float = 0.0
    overtravel: bool = False

    def step(self, dt, freq_hz, direction, brake_released, t_ms, events, mass):
        self.vel = (freq_hz * self.m_per_hz_s * direction) if brake_released else 0.0
        self.pos += self.vel * dt
        if not self.overtravel and (self.pos > self.hi or self.pos < self.lo):
            over = self.pos - self.hi if self.pos > self.hi else self.lo - self.pos
            events.append({
                "t_ms": t_ms, "kind": "overtravel", "instance": "M3_Axis",
                "limit": "travel_m.upper" if self.pos > self.hi else "travel_m.lower",
                "speed_mps": round(self.vel, 3),
                "overshoot_m": round(over, 3),
                "kinetic_energy_J": None if mass is None
                    else round(.5 * mass * self.vel ** 2, 1),
                "energy_note": "moving_mass_kg UNKNOWN — energie non calculable"
                    if mass is None else "",
            })
            self.overtravel = True


@dataclass
class CamChain:
    """Chaine de cames a progression monotone. Produit un MOT, pas N bits libres."""
    cams: list
    valid_words: list
    length_m: float = 0.40
    faults: dict = field(default_factory=dict)
    state: dict = field(default_factory=dict)

    def step(self, pos: float):
        word = 0
        for c in self.cams:
            # Progression monotone : la came reste active tant qu'on ne l'a pas depassee.
            on = pos <= c["position_m"] + self.length_m / 2
            f = self.faults.get(c["name"], "none")
            if f == "stuck_low":
                on = False
            elif f == "stuck_high":
                on = True
            self.state[c["name"]] = on
            if on:
                word |= 1 << c["bit"]
        self.word = word
        self.incoherent = word not in self.valid_words
        self.at_low = word == 0b11111
        self.at_high = word == 0b00000
        return word


@dataclass
class Joystick:
    """Retour au neutre non instantane : source classique de bugs de phase."""
    spring_ms: float
    value: float = 0.0

    def step(self, dt: float, intent: float):
        if intent != 0.0:
            self.value = intent
        elif self.value != 0.0:
            d = dt * 1000.0 / self.spring_ms
            self.value = 0.0 if abs(self.value) <= d else \
                self.value - (d if self.value > 0 else -d)


class Simulation:
    """Assemble les instances du modele et les fait avancer scan par scan."""

    def __init__(self, model_path: Path, seed: int):
        self.model = yaml.safe_load(model_path.read_text(encoding="utf-8"))
        self.seed, self.rng = seed, random.Random(seed)
        self.scan_ms = self.model.get("scan_ms", 20)
        self.events: list = []
        self._build()

    def _build(self):
        I = self.model["instances"]
        self.P = {}

        def P(inst, key, default=None):
            p = param((I[inst].get("params") or {}).get(key), default)
            self.P[f"{inst}.{key}"] = p
            return p["value"]

        self.vfd = Vfd(freq_max=P("AC600", "freq_max_hz", 50.0),
                       accel_s=P("AC600", "accel_time_s", 2.0),
                       decel_s=P("AC600", "decel_time_s", 2.0),
                       stop_hz=P("AC600", "freq_stop_threshold_hz", 0.5))
        self.brake = Brake(release_ms=P("M3_Brake", "release_time_ms", 120),
                           engage_ms=P("M3_Brake", "engage_time_ms", 80))
        lo, hi = P("M3_Axis", "travel_m", [0.0, 30.0])
        self.mass = P("M3_Axis", "moving_mass_kg", None)
        self.axis = Axis(lo=lo, hi=hi, m_per_hz_s=0.008333, pos=20.0)  # depart P1
        cams = P("M3_Cams", "cams", [])
        self.cams = CamChain(cams=cams, valid_words=P("M3_Cams", "valid_words", []))
        self.cam_len_known = self.P["M3_Cams.cam_length_m"]["declared"] is not None \
            if "M3_Cams.cam_length_m" in self.P else False
        P("M3_Cams", "cam_length_m", None)
        self.joy = Joystick(spring_ms=P("Joystick", "spring_return_ms", 60))

        # Niveau CALCULE, et inventaire de ce qui empeche de conclure.
        srcs = [p["source"] for p in self.P.values()]
        self.level = "L2" if all(LEVEL_BY_SOURCE.get(s) == "L2" for s in srcs) else "L1"
        self.unverified = [k for k, p in self.P.items() if p["verified"] != "verified"]
        self.unknowns = {k: v.get("unknowns", []) for k, v in I.items() if v.get("unknowns")}
        self.blocked = sorted({b for p in self.P.values() for b in p["blocks"]})

    def run(self, scenario="nominal", faults=None, n_scans=2200, hold_until=2100):
        faults = faults or {}
        self.cams.faults = {k.split(".")[-1]: v for k, v in faults.items()}
        dt = self.scan_ms / 1000.0
        jitter = self.rng.uniform(0.0, dt)
        frames = []

        for i in range(n_scans):
            t_ms = int(i * self.scan_ms + jitter * 1000.0)
            self.joy.step(dt, 1.0 if i < hold_until else 0.0)
            deadman = self.joy.value != 0.0

            word = self.cams.step(self.axis.pos)

            # ── FRONTIERE : ce qui suit n'est PAS le modele de machine ──────
            # Le plant model ne decide jamais d'un arret : c'est l'automate qui
            # decide. Ce bouchon tient sa place le temps du POC et sera remplace
            # soit par le ST compile, soit par le pilotage interactif.
            # Il est ISOLE ici pour qu'on voie ou passe la frontiere.
            plc_permit = not self.cams.at_high
            # ────────────────────────────────────────────────────────────────

            run = deadman and self.joy.value > 0.05 and plc_permit
            setpoint = abs(self.joy.value) * self.vfd.freq_max

            self.vfd.step(dt, setpoint, run)
            self.brake.step(dt, run)
            self.axis.step(dt, self.vfd.freq, +1, self.brake.released,
                           t_ms, self.events, self.mass)

            frames.append({
                "t_ms": t_ms,
                "AC600": {"freq_setpoint_hz": round(setpoint, 2),
                          "actual_freq_hz": round(self.vfd.freq, 2),
                          "status_word": self.vfd.status_word,
                          "running": self.vfd.running},
                "M3_Brake": {"is_released": self.brake.released},
                "M3_Axis": {"position_m": round(self.axis.pos, 3),
                            "speed_mps": round(self.axis.vel, 4),
                            "overtravel": self.axis.overtravel},
                "M3_Cams": {"word": word,
                            "cams": {c["name"]: self.cams.state[c["name"]]
                                     for c in self.cams.cams},
                            "incoherent": self.cams.incoherent,
                            "at_low": self.cams.at_low, "at_high": self.cams.at_high},
                "Joystick": {"intent": round(self.joy.value, 3), "deadman": deadman},
            })

        return {
            "meta": {"tool": "TwinBench", "phase": "POC-1", "scenario": scenario,
                     "seed": self.seed, "scan_ms": self.scan_ms,
                     "sampling_jitter_ms": round(jitter * 1000.0, 3),
                     "level_computed": self.level,
                     "unverified_params": self.unverified,
                     "blocked_invariants": self.blocked,
                     "unknowns": self.unknowns,
                     "faults": faults},
            "params": self.P,
            "views": self.model.get("views", {}),
            "frames": frames,
            "events": self.events,
        }
