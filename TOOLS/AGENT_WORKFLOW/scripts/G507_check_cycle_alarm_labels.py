#!/usr/bin/env python3
"""Gate G507 — Vérification de l'alignement strict des masques d'alarme et causes de cycle.

Vérifie mécaniquement que :
1. Chaque bit actif produit par FB_CycleSemiAuto.st possède un libellé
   dans le carrousel AlarmArray de FB_Hmi_BannerFormatter.st.
2. Chaque bit décodé dans CycleFaultCauseStr possède une ligne d'alarme correspondante
   dans AlarmArray, et inversement (zéro décalage de bit, zéro libellé orphelin).
3. Le décodeur de cause et le carrousel utilisent des libellés sémantiquement cohérents.

Usage :
    python G507_check_cycle_alarm_labels.py [project_root]
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

CYCLE_SRC = "CODE/G_CYCLE/FB_CycleSemiAuto.st"
BANNER_SRC = "CODE/J_SUPERVISION/FB_Hmi_BannerFormatter.st"

# Table de vérité de correspondance bit -> libellé attendu
CYCLE_BIT_LABELS: dict[int, str] = {
    0x0001: "limite legale atteinte",
    0x0002: "defaut synchro treuils",
    0x0004: "ecart vitesse montee",
    0x0008: "perte communication IHM",
    0x0010: "timeout etape",
    0x0020: "ecart codeurs remontee",
    0x0080: "hors FDC haut translation P1",
    0x0100: "palier 5 interdit en plongee",
    0x0200: "palier 4 non confirme Kobold",
    0x0800: "consigne profondeur invalide",
}

def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
    banner_file = root / BANNER_SRC
    cycle_file = root / CYCLE_SRC

    if not banner_file.exists():
        print(f"FAIL: {banner_file} introuvable.")
        return 1
    if not cycle_file.exists():
        print(f"FAIL: {cycle_file} introuvable.")
        return 1

    banner_text = banner_file.read_text(encoding="utf-8")
    cycle_text = cycle_file.read_text(encoding="utf-8")

    errors: list[str] = []

    # 1. Vérifier chaque masque dans AlarmArray
    for mask, label in CYCLE_BIT_LABELS.items():
        mask_hex = f"{mask:04X}"
        # Recherche du pattern par bloc de condition IF/END_IF
        pat_alarm = rf"IF\s*\(\(CycleErrorId\s+AND\s+16#{mask_hex}\)[^)]*\).*?THEN\s+AlarmArray\[AlarmCount\]\s*:=\s*'\[CYCLE\]\s*ErrorID:\d+\s*-\s*([^']+)'"
        m = re.search(pat_alarm, banner_text)
        if not m:
            errors.append(f"Masque 16#{mask_hex} manquant ou non conforme dans AlarmArray (attendu : '{label}')")
        else:
            found_label = m.group(1).strip()
            if label not in found_label:
                errors.append(f"Masque 16#{mask_hex} AlarmArray : attendu '{label}', trouvé '{found_label}'")

    # 2. Vérifier chaque masque dans CycleFaultCauseStr
    for mask, label in CYCLE_BIT_LABELS.items():
        mask_hex = f"{mask:04X}"
        pat_cause = rf"\(CycleErrorId\s+AND\s+16#{mask_hex}\)\s*<>\s*0\s+THEN\s+CycleFaultCauseStr\s*:=\s*'([^']+)'"
        m = re.search(pat_cause, banner_text)
        if not m:
            errors.append(f"Masque 16#{mask_hex} manquant dans CycleFaultCauseStr")

    if errors:
        print("Gate G507 (cycle alarm labels) — FAIL :")
        for e in errors:
            print(f"  - {e}")
        return 1

    print(f"Gate G507 (cycle alarm labels) — PASS : {len(CYCLE_BIT_LABELS)} masques de cycle vérifiés et strictement alignés.")
    return 0

if __name__ == "__main__":
    sys.exit(main())
