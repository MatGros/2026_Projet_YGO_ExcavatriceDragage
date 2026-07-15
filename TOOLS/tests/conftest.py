import sys
from pathlib import Path

TOOLING_ROOT = Path(__file__).resolve().parent.parent
if str(TOOLING_ROOT) not in sys.path:
    sys.path.insert(0, str(TOOLING_ROOT))

REPO_ROOT = TOOLING_ROOT.parent
CODE_DIR = REPO_ROOT / "CODE"
SAMPLES_DIR = TOOLING_ROOT / "samples_reference_codesys"
