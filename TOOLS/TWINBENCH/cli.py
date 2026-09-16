#!/usr/bin/env python3
"""TwinBench — interface ligne de commande (POC phase 1).

  python TOOLS/TWINBENCH/cli.py run --scenario nominal
  python TOOLS/TWINBENCH/cli.py run --scenario capteur_hs --fault S5_Maintenance=stuck_low
  python TOOLS/TWINBENCH/cli.py run --seed 4172        # rejeu a l'identique
"""

from __future__ import annotations

import argparse
import json
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "engine"))
from twinbench import Simulation  # noqa: E402

ROOT = Path(__file__).resolve().parent
MODEL = ROOT / "PROJECTS" / "excavatrice_dragage" / "machine.twin.yaml"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    sub = ap.add_subparsers(dest="cmd", required=True)

    run = sub.add_parser("run")
    run.add_argument("--scenario", default="nominal")
    run.add_argument("--seed", type=int, default=None)
    run.add_argument("--fault", action="append", default=[],
                     help="INSTANCE=mode, ex. S5_Maintenance=stuck_low")
    run.add_argument("--out", default=None)

    args = ap.parse_args()
    seed = args.seed if args.seed is not None else random.randrange(1, 10_000)
    faults = dict(f.split("=", 1) for f in args.fault)

    sim = Simulation(MODEL, seed=seed)
    result = sim.run(args.scenario, faults=faults)

    out = Path(args.out) if args.out else ROOT / "out" / f"trace_{args.scenario}.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, indent=1), encoding="utf-8")

    m = result["meta"]
    print(f"scenario         : {m['scenario']}")
    print(f"graine           : {m['seed']}   (rejeu : --seed {m['seed']})")
    print(f"jitter scan      : {m['sampling_jitter_ms']} ms")
    print(f"niveau CALCULE   : {m['level_computed']}  (provenances)")
    print(f"non verifies     : {len(m['unverified_params'])} parametre(s)")
    print(f"frames           : {len(result['frames'])}")
    if result["events"]:
        print("EVENEMENTS :")
        for e in result["events"]:
            print(f"  [{e['t_ms']:>6} ms] {e['kind']} {e['instance']} "
                  f"depassement {e['overshoot_m']} m a {e['speed_mps']} m/s "
                  f"({e['kinetic_energy_J']} J)")
    else:
        print("evenements       : aucun")
    try:
        shown = out.relative_to(ROOT.parents[1])
    except ValueError:
        shown = out
    print(f"position finale  : {result['frames'][-1]['actuators']['M3']['position_m']} m")
    print(f"-> {shown}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
