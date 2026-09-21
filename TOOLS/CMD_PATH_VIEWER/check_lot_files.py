#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
T353 — GARDE-FOU DE PROPRETE DES FICHIERS DU LOT (CMD_PATH_VIEWER).

Pourquoi ce garde-fou existe : `.gitattributes` porte un REX daté 2026-08-19 —
« le hook partagé portait un BOM UTF-8 et des fins de ligne CRLF … Le BOM se glisse AVANT le `#!` …
dans les deux cas le shebang devient invalide ». Pendant ce lot, un BOM UTF-8 a effectivement été
introduit par accident sur `smoke_test_ui.js` (via un `Set-Content -Encoding UTF8`), rendant
`node smoke_test_ui.js` NON EXÉCUTABLE. Le fichier a été réécrit sans BOM, mais **rien ne détectait
la classe de bug** : c'est le rôle de ce script.

Contrôles (chacun BLOQUANT, code de sortie 1) :
  1. AUCUN BOM UTF-8 (EF BB BF) dans un fichier du lot — un BOM devant un shebang casse l'exécution.
  2. AUCUNE fin de ligne CRLF dans les sources du lot (.js .html .css .md .py .bat) : LF exigé.
  3. AUCUNE ressource distante (`http://` / `https://` / `//cdn`) dans le front : le mode statique
     doit fonctionner en file:// sans aucune requête réseau.
  4. Les LIVRABLES attendus existent (index.html, app.js, style.css, git-blob-sha1.js, README.md,
     PREUVE_T353.md, parse_cartographies.py, verify_anchors.py, smoke_test_ui.js,
     OPEN_CMD_PATH_VIEWER.bat, data/graph.json, data/freshness.json).
  5. Les scripts à shebang sont exécutables tels quels (le `#!` est bien sur la PREMIÈRE ligne).

Usage : python check_lot_files.py      (code de sortie 0 = lot propre)
Périmètre : TOOLS/CMD_PATH_VIEWER/ uniquement. Lecture seule, aucune écriture.
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path

ICI = Path(__file__).resolve().parent
EXT_SOURCE = {".js", ".html", ".css", ".md", ".py", ".bat", ".json"}
LIVRABLES = [
    "index.html", "app.js", "style.css", "git-blob-sha1.js", "README.md", "PREUVE_T353.md",
    "parse_cartographies.py", "verify_anchors.py", "smoke_test_ui.js", "OPEN_CMD_PATH_VIEWER.bat",
    "data/graph.json", "data/freshness.json",
]
# Les seules URL tolérées : locales (127.0.0.1) ou dans un commentaire qui interdit les CDN.
RE_URL = re.compile(r"https?://[^\s\"'<>)]+|//cdn\.[a-z0-9.-]+", re.I)


def scanner() -> dict:
    fichiers, anomalies = [], []
    a_bom, a_crlf, a_url, a_shebang = [], [], [], []
    for root, dirs, files in os.walk(ICI):
        dirs[:] = [d for d in dirs if d not in ("__pycache__", ".git")]
        for nom in sorted(files):
            p = Path(root) / nom
            rel = p.relative_to(ICI).as_posix()
            octets = p.read_bytes()
            ext = p.suffix.lower()
            bom = octets.startswith(b"\xef\xbb\xbf")
            crlf = octets.count(b"\r\n")
            fichiers.append({"fichier": rel, "octets": len(octets), "bom": bom, "crlf": crlf})
            if bom:
                a_bom.append(rel)
            if crlf and ext in EXT_SOURCE:
                a_crlf.append({"fichier": rel, "crlf": crlf})
            if ext in {".js", ".html", ".css"}:
                texte = octets.decode("utf-8", errors="replace")
                for m in RE_URL.finditer(texte):
                    url = m.group(0)
                    if "127.0.0.1" in url or "localhost" in url:
                        continue
                    # une URL citée dans un commentaire qui dit « AUCUN CDN » est une MENTION, pas une
                    # dépendance : on la signale en information, jamais en violation.
                    ligne = texte[:m.start()].count("\n") + 1
                    ligne_txt = texte.splitlines()[ligne - 1] if ligne <= len(texte.splitlines()) else ""
                    a_url.append({"fichier": rel, "ligne": ligne, "url": url,
                                  "commentaire_documentaire": ("AUCUN CDN" in ligne_txt or "aucun CDN" in ligne_txt)})
            if ext in {".js", ".py"} and octets.startswith(b"#!"):
                premier = octets.split(b"\n", 1)[0]
                if not premier.startswith(b"#!") or premier.endswith(b"\r"):
                    a_shebang.append({"fichier": rel, "premiere_ligne": premier[:40].decode("utf-8", "replace")})
    manquants = [f for f in LIVRABLES if not (ICI / f).exists()]
    # Un livrable DÉCLARÉ mais absent, ou réduit à une coquille, est exactement la classe d'erreur
    # « déclaré au catalogue, absent du disque » : on impose une taille minimale non triviale.
    trop_petits = [{"fichier": f, "octets": (ICI / f).stat().st_size}
                   for f in LIVRABLES if (ICI / f).exists() and (ICI / f).stat().st_size < 1024]
    for a in a_bom:
        anomalies.append({"controle": "BOM_UTF8", "fichier": a})
    for a in a_crlf:
        anomalies.append({"controle": "CRLF_DANS_SOURCE", "fichier": a["fichier"], "crlf": a["crlf"]})
    for a in a_url:
        if not a["commentaire_documentaire"]:
            anomalies.append({"controle": "RESSOURCE_DISTANTE", **a})
    for a in a_shebang:
        anomalies.append({"controle": "SHEBANG_INVALIDE", **a})
    for f in manquants:
        anomalies.append({"controle": "LIVRABLE_MANQUANT", "fichier": f})
    for t in trop_petits:
        anomalies.append({"controle": "LIVRABLE_TRIVIAL (< 1 Ko)", **t})
    return {"fichiers_scannes": len(fichiers), "detail": fichiers, "anomalies": anomalies,
            "urls_informatives": [a for a in a_url if a["commentaire_documentaire"]],
            "manquants": manquants, "trop_petits": trop_petits}


def main() -> int:
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass
    r = scanner()
    print("=" * 100)
    print("GARDE-FOU DE PROPRETÉ DES FICHIERS — T353 / CMD_PATH_VIEWER")
    print("=" * 100)
    print("  contrôles : 1) aucun BOM UTF-8  2) aucune fin de ligne CRLF dans les sources")
    print("              3) aucune ressource distante dans le front  4) livrables présents ET non triviaux")
    print("              5) shebang sur la première ligne")
    print()
    print(f"  {'fichier':44} {'octets':>9}  {'BOM':4} {'CRLF':>6}")
    for f in r["detail"]:
        print(f"  {f['fichier']:44} {f['octets']:>9}  {'OUI' if f['bom'] else 'non':4} {f['crlf']:>6}")
    print()
    for u in r["urls_informatives"]:
        print(f"  [info] {u['fichier']}:{u['ligne']} cite `{u['url']}` dans un commentaire documentaire "
              f"(« AUCUN CDN ») — mention, pas dépendance")
    if r["anomalies"]:
        print(f"  ⛔ {len(r['anomalies'])} ANOMALIE(S) :")
        for a in r["anomalies"]:
            print(f"     - {a['controle']} : {a.get('fichier')} {a.get('crlf', '')}")
        print("  verdict : FAIL")
        return 1
    print(f"  fichiers scannés : {r['fichiers_scannes']} · livrables vérifiés : {len(LIVRABLES)}"
          f" (présents et non triviaux) · anomalies : 0")
    print("  verdict : PASS — aucun BOM, aucune CRLF dans les sources, aucune ressource distante, "
          "tous les livrables présents ET non triviaux")
    return 0


if __name__ == "__main__":
    sys.exit(main())
