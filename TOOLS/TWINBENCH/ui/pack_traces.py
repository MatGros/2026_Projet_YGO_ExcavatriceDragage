#!/usr/bin/env python3
"""Compacte les traces du moteur en colonnes, pour embarquement dans la vue.

Ne recalcule RIEN : il transpose. Toute valeur affichee par la vue vient
d'ici, donc du moteur. C'est ce qui rend la regle du pur rendu verifiable.
"""

import json
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "out"
STEP = 2   # sous-echantillonnage d'affichage (le moteur, lui, garde tout)


def pack(path: Path) -> dict:
    d = json.loads(path.read_text(encoding="utf-8"))
    fr = d["frames"][::STEP]
    names = list(fr[0]["sensors"].keys())
    return {
        "meta": d["meta"],
        "params": d["params"],
        "views": d["views"],
        "events": d["events"],
        "n": len(fr),
        "t": [f["t_ms"] for f in fr],
        "pos": [f["actuators"]["M3"]["position_m"] for f in fr],
        "vel": [f["actuators"]["M3"]["speed_mps"] for f in fr],
        "brake": [int(f["actuators"]["M3"]["brake_released"]) for f in fr],
        "fwd": [int(f["actuators"]["M3"]["relay_fwd"]) for f in fr],
        "rev": [int(f["actuators"]["M3"]["relay_rev"]) for f in fr],
        "phase": [f["actuators"]["M3"]["phase"] for f in fr],
        "joy": [f["operator"]["joystick"] for f in fr],
        "deadman": [int(f["operator"]["deadman"]) for f in fr],
        "sensorNames": names,
        "sensors": {n: {
            "det": [int(f["sensors"][n]["detected"]) for f in fr],
            "dist": [f["sensors"][n]["distance_m"] for f in fr],
            "fault": fr[0]["sensors"][n]["fault"],
            "trigger": None,
        } for n in names},
    }


bundle = {s: pack(OUT / f"trace_{s}.json") for s in ("nominal", "capteur_hs")}
dest = Path(__file__).resolve().parent / "traces.json"
dest.write_text(json.dumps(bundle, separators=(",", ":")), encoding="utf-8")
print(f"{dest.name} : {dest.stat().st_size / 1024:.0f} Ko · "
      f"{bundle['nominal']['n']} points/scenario")
