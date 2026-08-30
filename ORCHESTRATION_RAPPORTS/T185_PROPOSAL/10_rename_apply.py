#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
T185 — renommage atomique Reference* -> MachineHoming* (famille FB_MachineHomingCycle).

USAGE :
  python ORCHESTRATION_RAPPORTS/T185_PROPOSAL/10_rename_apply.py --dry-run   # defaut : liste les hits, n'ecrit rien
  python ORCHESTRATION_RAPPORTS/T185_PROPOSAL/10_rename_apply.py --apply     # ecrit dans CODE/ + tests + registry (APRES validation humaine)

Ne touche PAS : CODE_XML/ (regenere par le bundle), DOC/AF/*, contrat YAML (revue manuelle).
Ordre des regles : du plus specifique au plus general (evite les collisions de sous-chaines).
"""
import argparse, pathlib, sys

ROOT = pathlib.Path(__file__).resolve().parents[2]

# (ancien, nouveau) — ordre important : traiter les identifiants composes d'abord
RENAMES = [
    ("FB_ReferenceCycle",            "FB_MachineHomingCycle"),
    ("instReferenceCycle",           "instMachineHomingCycle"),
    ("ST_fbRef_AxisHomingStatus",    "ST_fbMachineHomingCycle_AxisHomingStatus"),
    ("ST_fbRef_HomingDemand",        "ST_fbMachineHomingCycle_HomingDemand"),
    ("ST_fbRef_BucketCommit",        "ST_fbMachineHomingCycle_BucketCommit"),
    ("E_MachineReferenceStep",       "E_MachineHomingStep"),
    ("MachineReferenceReady",        "MachineHomed"),
    ("ReferenceCommitOpen",          "MachineHomingCommitOpen"),
    ("ReferenceCommitClose",         "MachineHomingCommitClose"),
    ("ReferenceStepAtError",         "MachineHomingStepAtError"),
    ("ReferenceTransactionActive",   "MachineHomingActive"),
    ("ReferenceLossSafeStop",        "MachineHomingLossSafeStop"),
    ("ReferenceInstruction",         "MachineHomingInstruction"),
    ("ReferenceFailed",              "MachineHomingFailed"),
    ("ReferenceStep",                "MachineHomingStep"),
    ("SemiAutoRefusedReference",     "SemiAutoRefusedMachineHoming"),
    # enum values
    ("BOTH_NOT_REFERENCED",          "BOTH_NOT_HOMED"),
    ("M1_NOT_REFERENCED",            "M1_NOT_HOMED"),
    ("M2_NOT_REFERENCED",            "M2_NOT_HOMED"),
    ("CONFIRM_BUCKET",               "AWAIT_BUCKET_CONFIRM"),
]

# fichiers .st concernes (releve grep 2026-08-30) + registry
TARGETS = [
    "CODE/F_MODES/FB_Modes.st",
    "CODE/G_CYCLE/FB_ReferenceCycle.st",           # sera aussi renomme (fichier) a l'--apply
    "CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st",
    "CODE/J_SUPERVISION/FB_TroubleshootingView.st",
    "CODE/J_SUPERVISION/_TYPES/1_TREUILS_BENNE/ST_BucketHMIState.st",
    "CODE/J_SUPERVISION/_TYPES/1_TREUILS_BENNE/ST_ChainBucket.st",
    "CODE/M_MAIN/PRG_02_Acquisition.st",
    "CODE/M_MAIN/PRG_03_Modes_Cycle.st",
    "CODE/M_MAIN/PRG_04_Treuils_Benne.st",
    "TOOLS/TEST_AUTO_CI/RESULTS/F_MODES/tests/test_fb_modes.st",
    "TOOLS/TEST_AUTO_CI/RESULTS/G_CYCLE/tests/test_fb_referencecycle.st",
    "TOOLS/TEST_AUTO_CI/RESULTS/M_MAIN/FB_Main_EndToEnd.st",
    "TOOLS/TEST_AUTO_CI/RESULTS/M_MAIN/FB_TestHarness_PRG_03.st",
    "TOOLS/TEST_AUTO_CI/registry.yaml",
]

FILE_RENAMES = [
    ("CODE/G_CYCLE/FB_ReferenceCycle.st",
     "CODE/G_CYCLE/FB_MachineHomingCycle.st"),
    ("TOOLS/TEST_AUTO_CI/RESULTS/G_CYCLE/tests/test_fb_referencecycle.st",
     "TOOLS/TEST_AUTO_CI/RESULTS/G_CYCLE/tests/test_fb_machinehomingcycle.st"),
]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="ecrit reellement (defaut : dry-run)")
    args = ap.parse_args()
    dry = not args.apply

    total = 0
    for rel in TARGETS:
        p = ROOT / rel
        if not p.exists():
            print(f"  [SKIP absent] {rel}")
            continue
        txt = p.read_text(encoding="utf-8")
        hits = sum(txt.count(a) for a, _ in RENAMES)
        if not hits:
            continue
        new = txt
        for a, b in RENAMES:
            new = new.replace(a, b)
        total += hits
        print(f"  [{'DRY ' if dry else 'WRITE'}] {rel:70s} {hits:4d} remplacement(s)")
        if not dry:
            p.write_text(new, encoding="utf-8")

    print(f"\n  Total : {total} remplacement(s) sur {len(TARGETS)} cible(s).")
    print("  Renommages de fichiers :")
    for a, b in FILE_RENAMES:
        print(f"    {a}  ->  {b}   {'(a faire manuellement / git mv a l --apply)' if dry else '(git mv requis)'}")
    if dry:
        print("\n  DRY-RUN — rien ecrit. Relancer avec --apply APRES validation humaine du diff.")
    else:
        print("\n  APPLIQUE. Faire les `git mv` ci-dessus, deplacer les 4 fichiers _TYPES, "
              "puis regenerer le bundle + G200 + gates.")


if __name__ == "__main__":
    main()
