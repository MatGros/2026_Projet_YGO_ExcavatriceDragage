#!/usr/bin/env python3
"""G488 - Garde-fou T333 : chaque capteur de l'estimateur M3 a un R_TRIG ET un F_TRIG consommes.

Classe de bug couverte (T333, 2026-09-20) : `FB_Translation_PositionEstimator` ne recalait la
position que sur les fronts MONTANTS (`R_TRIG`). Or les 5 capteurs forment un mot thermometre
CUMULATIF (`FB_Translation_PositionDecoder` : bit_X = TRUE ssi position <= cote_X) : chaque
capteur bascule a SA cote dans les deux sens. Ne consommer que le front montant laissait donc
toute la trajectoire vers la Maintenance sans recalage — l'ARRIVEE en Maintenance (mot 00000)
etant justement le front DESCENDANT de son capteur. L'erreur odometrique s'accumulait puis etait
rattrapee d'un coup au premier front montant.

Regle verrouillee ici, pour les 5 capteurs :
  R1  un `R_TRIG` ET un `F_TRIG` declares, chacun appele avec `CLK := <capteur>` ;
  R2  la branche de recalage de la cote du capteur (`PositionEstimatedM := PosXxxM` suivi de
      `Recalibrated := TRUE`) consomme DANS SA CONDITION les DEUX `.Q` (montant et descendant) ;
  R3  aucune instance d'edge declaree et non appelee (CODE_QUALITY_STANDARDS §4) ;
  R4  les 5 cotes ont chacune exactement une branche de recalage (aucun capteur oublie, aucun
      doublon).

Le gate ECHOUE si l'on retire la consommation du front descendant : c'est son role.

Usage :
    python TOOLS/AGENT_WORKFLOW/scripts/G488_check_estimator_sensor_edges.py [root]
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

TARGET = Path("CODE/I_TRANSLATION/FB_Translation_PositionEstimator.st")

# (capteur VAR_INPUT, cote calibree, identifiant RecalibratedSensorId)
SENSORS = [
    ("SensorMaintenance", "PosMaintenanceM", 0),
    ("SensorP1", "PosP1M", 1),
    ("SensorP2", "PosP2M", 2),
    ("SensorPV", "PosPVM", 3),
    ("SensorTremie", "PosTremieM", 4),
]

DECL_RE = re.compile(r"^\s*(?P<name>\w+)\s*:\s*(?P<type>R_TRIG|F_TRIG)\s*;")
CLK_RE = re.compile(r"(?P<inst>\w+)\s*\(\s*CLK\s*:=\s*(?P<sensor>\w+)\s*\)")
COND_RE = re.compile(r"^\s*(?:IF|ELSIF)\b(?P<body>.*)$")
ASSIGN_RE = re.compile(r"PositionEstimatedM\s*:=\s*(?P<cote>Pos\w+M)\s*;")
RECAL_RE = re.compile(r"Recalibrated\s*:=\s*TRUE\s*;")


def _strip_comments(lines: list[str]) -> list[str]:
    """Neutralise commentaires // et (* *) en conservant la numerotation des lignes.

    Sans cela, un `.Q` cite dans un commentaire satisferait la regle R2 alors que la
    consommation reelle a disparu (regression non detectee).
    """
    out: list[str] = []
    in_block = False
    for line in lines:
        chunks: list[str] = []
        i = 0
        while i < len(line):
            if in_block:
                end = line.find("*)", i)
                if end == -1:
                    i = len(line)
                else:
                    in_block = False
                    i = end + 2
                continue
            block = line.find("(*", i)
            slash = line.find("//", i)
            if slash != -1 and (block == -1 or slash < block):
                chunks.append(line[i:slash])
                i = len(line)
            elif block == -1:
                chunks.append(line[i:])
                i = len(line)
            else:
                chunks.append(line[i:block])
                in_block = True
                i = block + 2
        out.append("".join(chunks))
    return out


def _conditions(lines: list[str]) -> list[tuple[int, str]]:
    """Retourne [(ligne, texte de la condition)] pour chaque IF/ELSIF ... THEN."""
    found: list[tuple[int, str]] = []
    current: list[str] = []
    current_line = 0
    for idx, line in enumerate(lines, start=1):
        if current:
            current.append(line.strip())
            if re.search(r"\bTHEN\b", line, re.IGNORECASE):
                found.append((current_line, " ".join(current)))
                current = []
            continue
        match = COND_RE.match(line)
        if match:
            body = match.group("body").strip()
            if re.search(r"\bTHEN\b", body, re.IGNORECASE):
                found.append((idx, body))
            else:
                current = [body]
                current_line = idx
    return found


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("root", nargs="?", default=".", help="Racine du projet")
    args = parser.parse_args()

    target = Path(args.root) / TARGET
    if not target.is_file():
        print(f"G488 FAIL: fichier absent: {target}", file=sys.stderr)
        return 1

    text = target.read_text(encoding="utf-8", errors="replace")
    lines = _strip_comments(text.splitlines())
    errors = 0

    # --- Inventaire des instances d'edges et de leur capteur -------------------------------
    declared: dict[str, str] = {}       # instance -> R_TRIG | F_TRIG
    for line in lines:
        match = DECL_RE.match(line)
        if match:
            declared[match.group("name")] = match.group("type")

    bound: dict[str, str] = {}          # instance -> capteur (via CLK := ...)
    for line in lines:
        for match in CLK_RE.finditer(line):
            bound[match.group("inst")] = match.group("sensor")

    edge_instances = {name: kind for name, kind in declared.items() if kind in ("R_TRIG", "F_TRIG")}
    if not edge_instances:
        print("G488 FAIL: aucune instance R_TRIG/F_TRIG detectee (nommage du FB change ?)", file=sys.stderr)
        return 1

    # R3 - aucune instance declaree non appelee (et inversement, un edge appele est declare).
    for name, kind in sorted(edge_instances.items()):
        if name not in bound:
            print(
                f"G488 FAIL: {TARGET}: instance {name} ({kind}) declaree mais jamais appelee "
                f"avec `CLK := <capteur>` (CODE_QUALITY_STANDARDS §4, code mort).",
                file=sys.stderr,
            )
            errors += 1
    for name in sorted(bound):
        if name not in edge_instances:
            print(
                f"G488 FAIL: {TARGET}: `{name}` est appele comme edge mais n'est pas declare "
                f"R_TRIG/F_TRIG.",
                file=sys.stderr,
            )
            errors += 1

    # --- Branches de recalage : cote -> (ligne, condition) ---------------------------------
    conditions = _conditions(lines)
    branches: dict[str, tuple[int, str]] = {}
    for idx, line in enumerate(lines, start=1):
        if not RECAL_RE.search(line):
            continue
        cote = ""
        cote_line = idx
        # affectation sur la meme ligne (style "IF ... THEN PositionEstimatedM := PosXxxM;")
        # ou sur l'une des 2 lignes precedentes (style en bloc, utilise par le FB).
        for back in (0, 1, 2):
            pos = idx - back - 1
            if pos < 0:
                continue
            match = ASSIGN_RE.search(lines[pos])
            if match:
                cote = match.group("cote")
                cote_line = pos + 1
                break
        if not cote:
            print(
                f"G488 FAIL: {TARGET}:{idx}: `Recalibrated := TRUE` sans affectation "
                f"`PositionEstimatedM := PosXxxM` associee (branche de recalage non identifiable).",
                file=sys.stderr,
            )
            errors += 1
            continue
        if cote in branches:
            print(
                f"G488 FAIL: {TARGET}:{cote_line}: cote {cote} recalee par plusieurs branches "
                f"(deja vue ligne {branches[cote][0]}).",
                file=sys.stderr,
            )
            errors += 1
            continue
        cond_text = ""
        for cond_line, text_cond in reversed(conditions):
            if cond_line < cote_line:
                cond_text = text_cond
                break
        branches[cote] = (cote_line, cond_text)

    # --- R1 / R2 / R4 : un couple montant+descendant consomme par capteur ------------------
    for sensor, cote, sensor_id in SENSORS:
        rising = sorted(n for n, k in edge_instances.items() if k == "R_TRIG" and bound.get(n) == sensor)
        falling = sorted(n for n, k in edge_instances.items() if k == "F_TRIG" and bound.get(n) == sensor)
        if not rising:
            print(
                f"G488 FAIL: {TARGET}: capteur {sensor} sans R_TRIG (front montant non detecte).",
                file=sys.stderr,
            )
            errors += 1
        if not falling:
            print(
                f"G488 FAIL: {TARGET}: capteur {sensor} sans F_TRIG (front descendant non detecte) "
                f"— c'est exactement le defaut T333 : le trajet vers la Maintenance n'est plus recale.",
                file=sys.stderr,
            )
            errors += 1
        if sensor not in text:
            print(f"G488 FAIL: {TARGET}: capteur {sensor} absent du FB.", file=sys.stderr)
            errors += 1
        if not rising or not falling:
            continue

        if cote not in branches:
            print(
                f"G488 FAIL: {TARGET}: cote {cote} jamais recalee (branche "
                f"`PositionEstimatedM := {cote}` + `Recalibrated := TRUE` absente).",
                file=sys.stderr,
            )
            errors += 1
            continue

        cote_line, cond_text = branches[cote]
        # Toutes les instances d'edge du capteur doivent etre consommees par SA branche de
        # recalage : une instance appelee mais jamais lue est un edge mort (regression muette).
        missing = [
            f"{inst}.Q" for inst in (rising + falling) if f"{inst}.Q" not in cond_text
        ]
        if missing:
            print(
                f"G488 FAIL: {TARGET}:{cote_line}: la branche de recalage de {cote} "
                f"({sensor}, id {sensor_id}) ne consomme pas {', '.join(missing)}. "
                f"Condition lue : {cond_text or '<aucune>'} — les deux fronts doivent recaler "
                f"le capteur a SA cote (mot thermometre cumulatif).",
                file=sys.stderr,
            )
            errors += 1

    expected_cotes = {cote for _, cote, _ in SENSORS}
    for cote in sorted(set(branches) - expected_cotes):
        print(
            f"G488 FAIL: {TARGET}:{branches[cote][0]}: cote inconnue {cote} recalee "
            f"(hors des 5 capteurs de position).",
            file=sys.stderr,
        )
        errors += 1

    print(
        f"G488 estimator sensor edges check: {'FAIL' if errors else 'PASS'} "
        f"({errors} error(s), {len(edge_instances)} instance(s) d'edge, {len(branches)} branche(s) de recalage)"
    )
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
