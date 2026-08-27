#!/usr/bin/env python3
"""Client CLI pour que les agents signalent une edition de tache au Task Manager."""
from __future__ import annotations

import argparse
import json
from urllib.request import Request, urlopen

BASE = "http://127.0.0.1:8081"


def post(path: str, data: dict) -> dict:
    request = Request(BASE + path, data=json.dumps(data).encode("utf-8"), headers={"Content-Type": "application/json"})
    with urlopen(request, timeout=5) as response:
        return json.loads(response.read().decode("utf-8"))


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("action", choices=("lock", "unlock", "edit-begin", "edit-end"))
parser.add_argument("--id", help="ID de la tache (lock/unlock)")
parser.add_argument("--actor", required=True, help="Identite de l'agent ou HUM")
parser.add_argument("--token", help="Jeton retourne par lock (unlock)")
args = parser.parse_args()

if args.action == "lock":
    if not args.id:
        parser.error("--id obligatoire pour lock")
    result = post("/api/task/work-lock/acquire", {"id": args.id, "actor": args.actor})
elif args.action == "unlock":
    if not args.id or not args.token:
        parser.error("--id et --token obligatoires pour unlock")
    result = post("/api/task/work-lock/release", {"id": args.id, "actor": args.actor, "token": args.token})
elif args.action == "edit-begin":
    if not args.id:
        parser.error("--id obligatoire pour edit-begin")
    result = post("/api/task/edit-flag/acquire", {"id": args.id, "actor": args.actor})
else:
    if not args.id or not args.token:
        parser.error("--id et --token obligatoires pour edit-end")
    result = post("/api/task/edit-flag/release", {"id": args.id, "actor": args.actor, "token": args.token})
print(json.dumps(result, ensure_ascii=False))
