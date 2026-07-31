"""Catalogue fonctionnel translation M3 : le CSV EST le test (REX 2026-08).

Avant : `functional_tests/run_translation_m3_catalog.py` executait le catalogue puis
ecrivait `'status': 'passed'` EN DUR, sans jamais comparer a `expected_result`. Un FB
completement casse aurait affiche 4 lignes vertes. Le script n'etait dans aucun gate,
dans aucune suite pytest, et absent de TEST_REGISTRY.md : rien ne cassait s'il regressait.

Maintenant : chaque ligne du CSV devient un cas pytest parametre, et les colonnes
`expect_*` sont reellement comparees a l'etat du FB apres scenario. Ajouter un cas
fonctionnel = ajouter une ligne au CSV, sans toucher au Python -- c'est l'interet
d'un catalogue, et il est desormais adosse a une vraie assertion.
"""

from __future__ import annotations

import csv
import importlib.util
import pathlib
import sys
import tempfile

import pytest

TOOLS_DIR = pathlib.Path(__file__).resolve().parents[2]
if str(TOOLS_DIR / 'core') not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR / 'core'))

import fb_gen

REPO_ROOT = pathlib.Path(__file__).resolve().parents[4]
BUNDLE_PATH = REPO_ROOT / 'CODE' / 'CODE_Bundle.xml'
CATALOG_PATH = pathlib.Path(__file__).parent.parent / 'catalogs' / 'translation_m3_test_catalog.csv'


def _load_catalog() -> list[dict]:
    with CATALOG_PATH.open('r', encoding='utf-8', newline='') as handle:
        return list(csv.DictReader(handle))


def _load_generated_module(pou_name: str):
    # Temp systeme : un test n'ecrit jamais dans RESULTS/ (arborescence de resultats).
    tmp_dir = pathlib.Path(tempfile.mkdtemp(prefix='st2py-test-'))
    module_path, _, _ = fb_gen.generate_module_and_test(
        pou_name, str(tmp_dir), bundle_path=str(BUNDLE_PATH))
    spec = importlib.util.spec_from_file_location(pou_name, module_path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _coerce(value: str):
    text = value.strip()
    if text.lower() == 'true':
        return True
    if text.lower() == 'false':
        return False
    try:
        return float(text)
    except ValueError:
        return text


def _apply_preconditions(fb, preconditions: str) -> None:
    for item in preconditions.split(';'):
        if '=' not in item:
            continue
        key, value = (part.strip() for part in item.split('=', 1))
        setattr(fb, key, _coerce(value))


def _run_scenario(fb, scenario: str) -> None:
    """Deroule le scenario nomme. Un scenario inconnu echoue plutot que de passer
    silencieusement dans une branche par defaut (piege du runner precedent)."""
    if scenario == 'safe_stop_fault':
        fb.step(10.0)
    elif scenario == 'slowdown_then_target':
        fb.step(10.0)
        fb.SlowdownSensor = True
        fb.step(10.0)
        fb.PositionSensorTarget = True
        fb.step(10.0)
    elif scenario == 'reset_recover':
        fb.step(10.0)              # entree en defaut (SafeStop actif)
        fb.SafeStop = False        # la cause disparait...
        fb.Reset = True            # ... puis appui conscient (Reset sur front)
        fb.step(10.0)
    elif scenario == 'nominal_start_then_target':
        fb.step(10.0)
        fb.PositionSensorTarget = True
        fb.step(10.0)
    else:
        raise AssertionError(f'scenario inconnu dans le catalogue : {scenario!r}')


@pytest.mark.parametrize('row', _load_catalog(), ids=lambda r: r['test_id'])
def test_translation_m3_catalog(row):
    """Chaque ligne du catalogue CSV est verifiee contre l'etat reel du FB."""
    module = _load_generated_module(row['pou'])
    fb = getattr(module, row['pou'])()
    _apply_preconditions(fb, row['preconditions'])
    _run_scenario(fb, row['scenario'])

    expected = {
        'State': row['expect_state'],
        'Ready': _coerce(row['expect_ready']),
        'Done': _coerce(row['expect_done']),
        'Error': _coerce(row['expect_error']),
        'ErrorId': int(float(row['expect_error_id'])),
    }
    actual = {
        'State': getattr(fb, 'State', None),
        'Ready': getattr(fb, 'Ready', None),
        'Done': getattr(fb, 'Done', None),
        'Error': getattr(fb, 'Error', None),
        'ErrorId': getattr(fb, 'ErrorId', None),
    }
    assert actual == expected, (
        f"{row['test_id']} ({row['title']}) : attendu {expected}, obtenu {actual}"
    )
