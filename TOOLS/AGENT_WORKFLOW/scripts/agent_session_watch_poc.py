"""Compatibility import; implementation lives in AGENT_SUPERVISOR."""
import sys
from pathlib import Path
if str(Path(__file__).resolve().parents[3]) not in sys.path:
    sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
from TOOLS.AGENT_SUPERVISOR.scripts import session_watcher as _implementation
if __name__ == "__main__":
    raise SystemExit(_implementation.main())
sys.modules[__name__] = _implementation
