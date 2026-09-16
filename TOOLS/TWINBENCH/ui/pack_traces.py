#!/usr/bin/env python3
"""Compacte les traces du moteur en colonnes, pour embarquement dans la vue.

Ne recalcule RIEN : il transpose. Toute valeur affichee par la vue vient
d'ici, donc du moteur. C'est ce qui rend la regle du pur rendu verifiable.
"""

import json
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "out"
STEP = 3


def pack(path: Path) -> dict:
    d = json.loads(path.read_text(encoding="utf-8"))
    fr = d["frames"][::STEP]
    cams = list(fr[0]["M3_Cams"]["cams"].keys())
    col = lambda f: [f(x) for x in fr]
    return {
        "meta": d["meta"], "params": d["params"], "views": d["views"],
        "events": d["events"], "n": len(fr),
        "t":        col(lambda f: f["t_ms"]),
        "pos":      col(lambda f: f["M3_Axis"]["position_m"]),
        "vel":      col(lambda f: f["M3_Axis"]["speed_mps"]),
        "over":     col(lambda f: int(f["M3_Axis"]["overtravel"])),
        "setpoint": col(lambda f: f["AC600"]["freq_setpoint_hz"]),
        "freq":     col(lambda f: f["AC600"]["actual_freq_hz"]),
        "sw":       col(lambda f: f["AC600"]["status_word"]),
        "brake":    col(lambda f: int(f["M3_Brake"]["is_released"])),
        "word":     col(lambda f: f["M3_Cams"]["word"]),
        "incoh":    col(lambda f: int(f["M3_Cams"]["incoherent"])),
        "atlow":    col(lambda f: int(f["M3_Cams"]["at_low"])),
        "athigh":   col(lambda f: int(f["M3_Cams"]["at_high"])),
        "joy":      col(lambda f: f["Joystick"]["intent"]),
        "deadman":  col(lambda f: int(f["Joystick"]["deadman"])),
        "camNames": cams,
        "cams": {c: col(lambda f, c=c: int(f["M3_Cams"]["cams"][c])) for c in cams},
    }


bundle = {s: pack(OUT / f"trace_{s}.json") for s in ("nominal", "came_hs")}
dest = Path(__file__).resolve().parent / "traces.json"
dest.write_text(json.dumps(bundle, separators=(",", ":")), encoding="utf-8")
print(f"{dest.name} : {dest.stat().st_size / 1024:.0f} Ko · "
      f"{bundle['nominal']['n']} points/scenario")
