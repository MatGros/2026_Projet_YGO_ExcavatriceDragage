"""Validation sans ecriture du catalogue YAML, avant restitution d'une edition."""
import argparse
from pathlib import Path

import yaml


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--task-id", help="Verifier aussi les objectifs de la tache editee")
    args = parser.parse_args()
    path = Path(__file__).resolve().parents[3] / "DOC/WFLOW/TASKS.yaml"
    try:
        data = yaml.safe_load(path.read_text(encoding="utf-8-sig"))
        if not isinstance(data, dict) or not isinstance(data.get("tasks"), list):
            raise ValueError("Le catalogue doit contenir une liste tasks")
        if args.task_id:
            matches = [t for t in data["tasks"] if isinstance(t, dict) and t.get("id") == args.task_id]
            if len(matches) != 1:
                raise ValueError("La tache doit exister exactement une fois")
            objectives = matches[0].get("objectifs", [])
            if not isinstance(objectives, list) or not all(isinstance(v, str) for v in objectives):
                raise ValueError("Les objectifs doivent etre une liste de chaines (citer les textes contenant ': ')")
    except (OSError, ValueError, yaml.YAMLError) as exc:
        print(f"FAIL : {exc}")
        return 1
    print("PASS : catalogue YAML lisible" + (f", objectifs {args.task_id} valides" if args.task_id else ""))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
