#!/usr/bin/env python3
"""Assemble la vue autonome : index.html + traces.json -> out/twinbench.html.

Le fichier produit est un HTML unique, ouvrable directement dans un navigateur,
sans serveur. Il n'embarque QUE des donnees issues du moteur.
"""

from pathlib import Path

UI = Path(__file__).resolve().parent
OUT = UI.parents[0] / "out" / "twinbench.html"

html = (UI / "index.html").read_text(encoding="utf-8")
traces = (UI / "traces.json").read_text(encoding="utf-8")

if "__TRACES__" not in html:
    raise SystemExit("index.html : marqueur __TRACES__ absent")

OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(html.replace("__TRACES__", traces), encoding="utf-8")
print(f"[OK] VUE ASSEMBLEE : {OUT.relative_to(UI.parents[2])}  "
      f"({OUT.stat().st_size / 1024:.0f} Ko)")
print("     ouvrir ce fichier dans un navigateur")
