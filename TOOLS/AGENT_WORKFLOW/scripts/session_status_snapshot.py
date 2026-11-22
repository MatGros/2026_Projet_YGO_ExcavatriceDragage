"""Expose les mêmes données de statut à tous les CLI, sans écrire le titre terminal.

Usage : python session_status_snapshot.py --session-id <UUID> [--cli codex] [--json]
La collecte réutilise le lecteur Superviseur et les indicateurs projet existants.
"""
import argparse
import json
import re

import session_statusline as status


ANSI = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")


def plain(value):
    return ANSI.sub("", value)


def collect(session_id, cli):
    summary, error = status.fetch_supervisor_summary()
    summary, error, stale = status.resolve_summary(session_id, summary, error)
    data = status.build_status_snapshot(session_id, cli, summary, error, stale)
    data["supervisor"]["text"] = plain(data["supervisor"]["text"])
    data["workflow"] = plain(data["workflow"])
    data["git"] = plain(data["git"])
    return data


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--session-id", required=True)
    parser.add_argument("--cli", choices=("claude", "codex", "agy"), default="codex")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    if not re.fullmatch(r"[a-zA-Z0-9_-]{1,128}", args.session_id):
        parser.error("Identifiant de session invalide")
    data = collect(args.session_id, args.cli)
    if args.json:
        print(json.dumps(data, ensure_ascii=False))
    else:
        stale = " (dernier connu)" if data["supervisor"]["stale"] else ""
        print(f"{data['title'] or data['session_id']} | {data['supervisor']['text']}{stale}")
        print(f"{data['workflow']} | {data['git']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
