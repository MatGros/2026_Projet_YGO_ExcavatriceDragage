"""Read-only T418 proof: preserve commissioned joystick/homing/cycle behavior.

Explicit lot audit, not a permanent prohibition against future approved T377.
Uses versioned ST at the commissioning Git tag; never reads Device.export.
"""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[3]
REF = 'MES_FIN_20260923'
FILES = [
    'CODE/D_JOYSTICK/FB_Joystick.st',
    'CODE/G_CYCLE/FB_CycleMachineHoming.st',
    'CODE/G_CYCLE/FB_CycleSemiAuto.st',
    'CODE/M_MAIN/PRG_04_Treuils_Benne.st',
    'CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st',
]


def historical(path):
    return subprocess.check_output(['git', 'show', f'{REF}:{path}'], cwd=ROOT).replace(b'\r\n', b'\n')


def main():
    commit = subprocess.check_output(['git', 'rev-parse', REF + '^{}'], cwd=ROOT, text=True).strip()
    print(f'Commissioning reference: {REF} -> {commit}')
    errors = []
    for name in FILES:
        if historical(name) != (ROOT / name).read_bytes().replace(b'\r\n', b'\n'):
            errors.append(name)
        else:
            print(f'IDENTICAL: {name}')
    name = 'CODE/M_MAIN/PRG_02_Acquisition.st'
    marker = '{region "§3 Traitement joystick"}'.encode('utf-8')
    old, current = historical(name), (ROOT / name).read_bytes().replace(b'\r\n', b'\n')
    if marker not in old or marker not in current or old.split(marker, 1)[1] != current.split(marker, 1)[1]:
        errors.append(name + ' commissioned joystick/encoder/homing processing')
    else:
        print('IDENTICAL: PRG_02 joystick, encoder and homing processing (section 3 through end)')
    for error in errors:
        print(f'FAIL: {error}')
    print(f'T418 commissioning audit: {"FAIL" if errors else "PASS"}')
    return bool(errors)


if __name__ == '__main__':
    raise SystemExit(main())
