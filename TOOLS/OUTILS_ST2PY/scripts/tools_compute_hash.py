#!/usr/bin/env python
import sys
import os
import json
import hashlib
from datetime import datetime

# For robustness in this environment, use ElementTree fallback only (xsdata/plcopen parsing can be
# fragile because of namespace differences between generated dataclasses and the actual XML export).
use_xsdata = False

ST2PY_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
sys.path.insert(0, ST2PY_DIR)

BUNDLE = os.path.abspath(os.path.join(ST2PY_DIR, '..', '..', 'CODE', 'CODE_Bundle.xml'))
POU_NAME = 'FB_Translation_PositionDecoder'
CACHE_PATH = os.path.join(ST2PY_DIR, '.st2py_cache.json')
OUT_META = os.path.join(ST2PY_DIR, 'out', 'modules', f'{POU_NAME}.meta.json')

if len(sys.argv) > 1:
    BUNDLE = sys.argv[1]

if not os.path.exists(BUNDLE):
    print('Bundle XML introuvable:', BUNDLE)
    sys.exit(2)

# If xsdata+plcopen are available, prefer that (more structured). Otherwise fallback to ElementTree.
if use_xsdata:
    parser = XsXmlParser()
    with open(BUNDLE, 'rb') as f:
        proj = parser.from_bytes(f.read(), PlcopenProject)
    # Attempt to find the POU in the parsed project
    pous = []
    if getattr(proj, 'types', None) and getattr(proj.types, 'pous', None):
        pous = proj.types.pous
    found = None
    for pou in pous:
        if getattr(pou, 'name', None) == POU_NAME:
            found = pou
            break
    if found is None:
        print(f'POU {POU_NAME} non trouvé via xsdata/plcopen dans {BUNDLE}')
        sys.exit(3)
    serializer = XsXmlSerializer()
    canonical = serializer.render(found).encode('utf-8')
from canonicalize import canonicalize_pou_bytes

canonical = canonicalize_pou_bytes(BUNDLE, POU_NAME)

# compute sha256 from canonical bytes
sha = hashlib.sha256(canonical).hexdigest()
print('SHA256 canonical pour', POU_NAME, '=', sha)

# Load or create cache
if os.path.exists(CACHE_PATH):
    try:
        with open(CACHE_PATH, 'r', encoding='utf-8') as f:
            cache = json.load(f)
    except Exception:
        cache = {}
else:
    cache = {}

cache[POU_NAME] = {
    'hash': sha,
    'generated_at': datetime.now().astimezone().isoformat(),
    'callers': cache.get(POU_NAME, {}).get('callers', [])
}

with open(CACHE_PATH, 'w', encoding='utf-8') as f:
    json.dump(cache, f, indent=2, ensure_ascii=False)
print('Cache mis à jour:', CACHE_PATH)

# Write meta
meta = {
    'pou': POU_NAME,
    'source': os.path.abspath(BUNDLE),
    'hash': sha,
    'generated_at': datetime.now().astimezone().isoformat()
}

os.makedirs(os.path.dirname(OUT_META), exist_ok=True)
with open(OUT_META, 'w', encoding='utf-8') as f:
    json.dump(meta, f, indent=2, ensure_ascii=False)
print('Fichier méta écrit:', OUT_META)
