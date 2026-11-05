"""Run Veilleur regression tests in a fresh retained project scratch directory."""
from datetime import datetime, timezone
from pathlib import Path
import subprocess
import sys
import uuid

root = Path(__file__).resolve().parents[3]
scratch = root / 'TOOLS' / 'AGENT_WORKFLOW' / '.tmp' / ('veilleur_' + datetime.now(timezone.utc).strftime('%Y%m%d_%H%M%S_') + uuid.uuid4().hex[:8])
command = [sys.executable, '-m', 'pytest', 'TOOLS/AGENT_WORKFLOW/tests/test_agent_supervisor_service.py',
           'TOOLS/AGENT_WORKFLOW/tests/test_agent_supervision_http.py', 'TOOLS/AGENT_SUPERVISOR/tests',
           '-q', '--tb=short', '-p', 'no:cacheprovider', '--basetemp=' + str(scratch),
           '-o', 'tmp_path_retention_policy=all']
print('Scratch conservé :', scratch, flush=True)
sys.exit(subprocess.call(command, cwd=root))
