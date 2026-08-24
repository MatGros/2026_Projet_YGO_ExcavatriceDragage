import pathlib
import sys

# core/ porte la bibliotheque importable (fb_gen, data_contracts, ...).
# Les suites l'importent par nom de module, pas par chemin de fichier.
ST2PY_DIR = pathlib.Path(__file__).resolve().parents[1]
CORE_DIR = ST2PY_DIR / "core"
REPO_ROOT = ST2PY_DIR.parents[1]
CODE_DIR = REPO_ROOT / "CODE"
SAMPLES_DIR = REPO_ROOT / "TOOLS" / "XML_SAMPLES_CODESYS"

for _p in (str(CORE_DIR), str(ST2PY_DIR)):
    if _p not in sys.path:
        sys.path.insert(0, _p)
