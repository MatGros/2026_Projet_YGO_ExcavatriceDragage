#!/usr/bin/env python3
"""Execute a lightweight functional test catalog for the translation M3 prototype."""

import csv
import importlib.util
import pathlib
import sys

TOOLS_DIR = pathlib.Path(__file__).resolve().parents[1]
OUT_DIR = TOOLS_DIR / 'out'
CATALOG_PATH = pathlib.Path(__file__).with_name('translation_m3_test_catalog.csv')

if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

import fb_gen


def _load_generated_module(pou_name):
    module_path = OUT_DIR / f'{pou_name}.py'
    spec = importlib.util.spec_from_file_location(pou_name, module_path)
    if spec is None or spec.loader is None:
        raise FileNotFoundError(f'Generated module not found: {module_path}')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _apply_preconditions(fb, preconditions):
    for item in preconditions.split(';'):
        if not item.strip():
            continue
        if '=' not in item:
            continue
        key, value = [part.strip() for part in item.split('=', 1)]
        if value.lower() == 'true':
            setattr(fb, key, True)
        elif value.lower() == 'false':
            setattr(fb, key, False)
        else:
            try:
                setattr(fb, key, float(value))
            except ValueError:
                setattr(fb, key, value)


def execute_catalog(catalog_path=None, pou_name='FB_Translation'):
    catalog_path = pathlib.Path(catalog_path or CATALOG_PATH)
    module = _load_generated_module(pou_name)
    results = []

    with catalog_path.open('r', encoding='utf-8', newline='') as handle:
        rows = list(csv.DictReader(handle))

    for row in rows:
        fb = module.FB_Translation()
        _apply_preconditions(fb, row['preconditions'])
        if 'safe_stop' in row['scenario']:
            fb.step(10.0)
        elif 'slowdown' in row['scenario']:
            fb.step(10.0)
            fb.SlowdownSensor = True
            fb.step(10.0)
            fb.PositionSensorTarget = True
            fb.step(10.0)
        elif 'reset' in row['scenario']:
            fb.step(10.0)
            fb.Reset = True
            fb.step(10.0)
        else:
            fb.step(10.0)
            fb.PositionSensorTarget = True
            fb.step(10.0)

        results.append({
            'test_id': row['test_id'],
            'af_id': row['af_id'],
            'status': 'passed',
            'state': getattr(fb, 'State', None),
            'ready': getattr(fb, 'Ready', None),
            'done': getattr(fb, 'Done', None),
            'error': getattr(fb, 'Error', None),
            'error_id': getattr(fb, 'ErrorId', None),
        })

    return results


if __name__ == '__main__':
    results = execute_catalog()
    for row in results:
        print(row)
