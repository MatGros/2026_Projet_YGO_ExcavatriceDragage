"""Compatibility import; implementation lives in AGENT_SUPERVISOR."""
import sys
from TOOLS.AGENT_SUPERVISOR.scripts import supervisor_service as _implementation
sys.modules[__name__] = _implementation
