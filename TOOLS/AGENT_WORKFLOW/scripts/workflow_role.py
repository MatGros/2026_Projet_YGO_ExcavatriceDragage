"""Lance un rôle projet dans la session native explicite, quel que soit le CLI."""
import argparse
import os
import re
import sys

import workflow_state


def native_session(explicit=None):
    if explicit:
        candidates = {explicit.strip()}
    else:
        candidates = {os.environ[name].strip() for name in (
            "CLAUDE_CODE_SESSION_ID", "CODEX_THREAD_ID", "CODEX_SESSION_ID",
            "GEMINI_SESSION_ID", "AGY_SESSION_ID", "DSH_SESSION_ID")
            if os.environ.get(name, "").strip()}
    if len(candidates) != 1:
        raise ValueError("Session absente ou ambiguë : fournir --session <ID natif exact>")
    session = candidates.pop()
    if not re.fullmatch(r"[A-Za-z0-9_-]{8,80}", session):
        raise ValueError("Identifiant natif invalide")
    return session


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("role", choices=("orchestrator", "coordinator"))
    parser.add_argument("--session")
    args = parser.parse_args(argv)
    try:
        session = native_session(args.session)
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        return 2
    previous_source = workflow_state.SOURCE
    try:
        workflow_state.SOURCE = "slash"
        return workflow_state.main([
            "voie", "1" if args.role == "orchestrator" else "2",
            "--session", session,
        ])
    finally:
        workflow_state.SOURCE = previous_source


if __name__ == "__main__":
    raise SystemExit(main())
