#!/usr/bin/env python3
"""G491 - Anti-orphelin bypass RETAIN.

Tout champ de CODE/L_SIMULATION/GVL_BypassRetain.st (VAR_GLOBAL RETAIN) doit etre
relaye vers l'IHM dans CODE/M_MAIN/PRG_07_Supervision.st : soit dans un bloc de
restauration boot (`IF <Bypass...> THEN GVL_IHM....`), soit via un miroir
`instMirrorBypass...(RetainVal := <Bypass...>)`. Sans relais, forcer la variable
RETAIN n'a aucun effet (constate 2026-09-01 : BypassNetworkGlobal orphelin -> defaut
module VH_0008ER non bypassable).

REX / regle fix:+guard: DOC/STDS/CODE_QUALITY_STANDARDS.md (section 'Comment ce document vit').

Exceptions : TOOLS/AGENT_WORKFLOW/config/bypass_retain_orphans_allowed.txt
(un nom par ligne, '#' = commentaire ; justification obligatoire en commentaire).
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
RETAIN = ROOT / "CODE" / "L_SIMULATION" / "GVL_BypassRetain.st"
PRG07 = ROOT / "CODE" / "M_MAIN" / "PRG_07_Supervision.st"
ALLOW = ROOT / "TOOLS" / "AGENT_WORKFLOW" / "config" / "bypass_retain_orphans_allowed.txt"


def _strip_comments(text: str) -> str:
    text = re.sub(r"\(\*.*?\*\)", " ", text, flags=re.DOTALL)
    text = re.sub(r"//[^\n]*", " ", text)
    return text


def _retain_fields(text: str) -> list[str]:
    body = _strip_comments(text)
    # champs 'Name : BOOL ...;' apres VAR_GLOBAL RETAIN
    m = re.search(r"VAR_GLOBAL\s+RETAIN(.*?)END_VAR", body, flags=re.DOTALL | re.IGNORECASE)
    scope = m.group(1) if m else body
    return re.findall(r"(\w+)\s*:\s*BOOL", scope)


def _allowlist() -> set[str]:
    if not ALLOW.exists():
        return set()
    out = set()
    for line in ALLOW.read_text(encoding="utf-8").splitlines():
        line = line.split("#", 1)[0].strip()
        if line:
            out.add(line)
    return out


def main() -> int:
    if not RETAIN.exists() or not PRG07.exists():
        print(f"G491 SKIP : fichier absent ({RETAIN.name} / {PRG07.name})")
        return 0

    fields = _retain_fields(RETAIN.read_text(encoding="utf-8"))
    prg07 = _strip_comments(PRG07.read_text(encoding="utf-8"))
    allowed = _allowlist()

    orphans = []
    for name in fields:
        # relaye si le nom apparait ailleurs que dans une simple declaration :
        # 'IF name THEN' ou 'RetainVal := name'
        relayed = re.search(rf"\bIF\s+{re.escape(name)}\b", prg07) or \
                  re.search(rf"RetainVal\s*:=\s*{re.escape(name)}\b", prg07)
        if not relayed and name not in allowed:
            orphans.append(name)

    if orphans:
        print("G491 FAIL : bypass RETAIN orphelin(s) (aucun relais dans PRG_07_Supervision) :")
        for o in orphans:
            print(f"  - {o}")
        print(f"  -> cabler le relais (boot-restore + instMirrorBypass...) ou lister dans {ALLOW.relative_to(ROOT)} avec justification.")
        return 1

    print(f"G491 PASS : {len(fields)} bypass RETAIN, tous relayes ({len(allowed)} exception(s) listee(s)).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
