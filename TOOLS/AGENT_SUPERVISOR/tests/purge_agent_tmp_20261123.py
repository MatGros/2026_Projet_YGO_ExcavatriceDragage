"""Purge unique (decision exploitant 2026-11-23) : applique la politique de retention
aux bacs existants de TOOLS/AGENT_WORKFLOW/.tmp.

Politique : logs de compilation conserves pour toujours (logs_compile/), 3 dossiers
complets max par famille (codesys_compile_*, g390_freshness_*), reliquat d'enquete
t417_* retire (obsolete — scripts parques dans T_TEMP A TRIER).
Chaque retrait est affiche.
Usage : python TOOLS/AGENT_SUPERVISOR/tests/purge_agent_tmp_20261123.py [--dry]
"""
from __future__ import annotations

import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
TMP = ROOT / 'TOOLS' / 'AGENT_WORKFLOW' / '.tmp'
KEEP_FULL = 3


def run(dry: bool) -> None:
    total_freed = 0
    families = ('codesys_compile_', 'g390_freshness_')
    logs_root = TMP / 'logs_compile'
    for prefix in families:
        runs = sorted((item for item in TMP.iterdir()
                       if item.is_dir() and item.name.startswith(prefix)),
                      key=lambda item: item.stat().st_mtime, reverse=True)
        for old in runs[KEEP_FULL:]:
            size = sum(f.stat().st_size for f in old.rglob('*') if f.is_file())
            kept_logs = []
            if prefix == 'codesys_compile_':
                for name in ('build_result.log', 'build_result.log.trace'):
                    source = old / name
                    if source.exists():
                        if not dry:
                            (logs_root / old.name).mkdir(parents=True, exist_ok=True)
                            shutil.copy2(source, logs_root / old.name / name)
                        kept_logs.append(name)
            if not dry:
                shutil.rmtree(old)
            total_freed += size
            note = f" (logs gardes : {', '.join(kept_logs)})" if kept_logs else ''
            print(f"reitre: {old.name} — {size / 1_048_576:.1f} Mo{note}")
    obsolete = sorted(item for item in TMP.iterdir()
                      if item.is_dir() and item.name.startswith('t417'))
    for old in obsolete:
        size = sum(f.stat().st_size for f in old.rglob('*') if f.is_file())
        if not dry:
            shutil.rmtree(old)
        total_freed += size
        print(f"reitre (enquete T417 obsolete): {old.name} — {size / 1_048_576:.1f} Mo")
    print(f"== {total_freed / 1024 ** 3:.2f} Go liberes" + (' [DRY]' if dry else ''))


if __name__ == '__main__':
    run(dry='--dry' in sys.argv)
