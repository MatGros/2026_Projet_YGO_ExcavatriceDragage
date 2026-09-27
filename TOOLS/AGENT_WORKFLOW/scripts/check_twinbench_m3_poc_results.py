"""Vérifie les résultats numériques du POC M3 générés par validate_M3_POC.mos."""
from __future__ import annotations

import argparse
import csv
from pathlib import Path
import sys


def load(path: Path) -> list[dict[str, str]]:
    if not path.is_file():
        raise ValueError(f"résultat absent: {path}")
    with path.open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle))
    if not rows:
        raise ValueError(f"résultat vide: {path}")
    return rows


def number(row: dict[str, str], name: str) -> float:
    if name not in row:
        raise ValueError(f"colonne absente: {name}")
    return float(row[name])


def check_loop(rows: list[dict[str, str]], cycles: int, frequency_hz: float) -> list[str]:
    errors: list[str] = []
    final = rows[-1]
    positions = [number(row, "plant.measurements.positionAct_M") for row in rows]
    velocities = [abs(number(row, "plant.measurements.velocityAct_Mps")) for row in rows]
    frequencies = [number(row, "plant.measurements.frequencyAct_Hz") for row in rows]
    if round(number(final, "completedCycles")) != cycles:
        errors.append(f"cycles finaux: attendu={cycles}, lu={final['completedCycles']}")
    if round(number(final, "phaseCode")) != 5:
        errors.append(f"phase finale: attendu=5, lu={final['phaseCode']}")
    if round(number(final, "loopActive")) != 0:
        errors.append(f"boucle encore active: {final['loopActive']}")
    if min(positions) < -0.001 or max(positions) > 30.001:
        errors.append(f"boucle hors capteurs: min={min(positions):.4f}, max={max(positions):.4f}")
    if max(frequencies) > frequency_hz + 0.01:
        errors.append(f"fréquence dépasse {frequency_hz} Hz: {max(frequencies):.4f}")
    if max(velocities) > frequency_hz * 0.02 + 0.001:
        errors.append(f"vitesse incohérente: {max(velocities):.4f} m/s")
    if abs(frequencies[0]) > 1e-9:
        errors.append(f"rampe non nulle à t=0: {frequencies[0]:.4f} Hz")
    for diagnostic in (
        "plant.diagnostics.commandConflict",
        "plant.diagnostics.hardStopMaintenanceActive",
        "plant.diagnostics.hardStopTremieActive",
    ):
        if any(round(number(row, diagnostic)) != 0 for row in rows):
            errors.append(f"diagnostic actif pendant la boucle: {diagnostic}")
    return errors


def check_infinite_loop(rows: list[dict[str, str]]) -> list[str]:
    errors: list[str] = []
    final = rows[-1]
    if round(number(final, "loopActive")) != 1:
        errors.append("boucle cycleCount=0 arrêtée avant le StopTime")
    if round(number(final, "phaseCode")) == 5:
        errors.append("boucle cycleCount=0 passée à la phase terminée")
    if round(number(final, "completedCycles")) < 1:
        errors.append("boucle cycleCount=0 sans cycle complet en 70 s")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("results", type=Path)
    args = parser.parse_args()
    errors: list[str] = []

    scripted = load(args.results / "M3_AllerRetour_res.csv")
    scripted_positions = [number(row, "plant.measurements.positionAct_M") for row in scripted]
    if min(scripted_positions) > -0.299 or max(scripted_positions) < 30.299:
        errors.append(
            "AllerRetour ne rejoint pas les deux butées mécaniques: "
            f"min={min(scripted_positions):.4f}, max={max(scripted_positions):.4f}"
        )

    errors.extend(check_loop(load(args.results / "M3_Boucle40Hz_2Cycles_res.csv"), 2, 40))
    errors.extend(check_loop(load(args.results / "M3_Boucle20Hz_1Cycle_res.csv"), 1, 20))
    errors.extend(check_infinite_loop(load(args.results / "M3_BoucleIllimitee_res.csv")))
    if errors:
        for error in errors:
            print(f"FAIL: {error}")
        return 1
    print("PASS: AllerRetour + boucles bornées 40/20 Hz + boucle illimitée cohérents.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError) as exc:
        print(f"FAIL: {exc}")
        sys.exit(1)
