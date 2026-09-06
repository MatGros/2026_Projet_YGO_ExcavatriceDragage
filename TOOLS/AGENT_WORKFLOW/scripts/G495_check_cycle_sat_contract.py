#!/usr/bin/env python3
"""G495 - Invariants statiques du lot T258 cycle semi-auto SAT.

Ce gate ne prétend pas prouver le comportement physique ni la neutralité maintenance.
Ces preuves appartiennent aux tests STruC++ et au SAT CODESYS.
"""
from pathlib import Path
import sys

ROOT = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parents[3]
CYCLE = (ROOT / "CODE/G_CYCLE/FB_CycleSemiAuto.st").read_text(encoding="utf-8-sig")
PRG03 = (ROOT / "CODE/M_MAIN/PRG_03_Modes_Cycle.st").read_text(encoding="utf-8-sig")
PRG04 = (ROOT / "CODE/M_MAIN/PRG_04_Treuils_Benne.st").read_text(encoding="utf-8-sig")
PRG07 = (ROOT / "CODE/M_MAIN/PRG_07_Supervision.st").read_text(encoding="utf-8-sig")
PRG05 = (ROOT / "CODE/M_MAIN/PRG_05_Translation.st").read_text(encoding="utf-8-sig")
PRG06 = (ROOT / "CODE/M_MAIN/PRG_06_Outputs.st").read_text(encoding="utf-8-sig")
WINCH_SYNC = (ROOT / "CODE/H_TREUILS_BENNE/FB_WinchSync.st").read_text(encoding="utf-8-sig")

required_cycle = {
    "intention montee qualifiee": "JoystickPull",
    "cible fond M1": "TouchPositionM1",
    "cible fond M2": "TouchPositionM2",
    "distance AX11 M1": "M1_CablePosM >= (CtrlAscentStartM1 + CtrlAscentDistEffM)",
    "distance AX11 M2": "M2_CablePosM >= (CtrlAscentStartM2 + CtrlAscentDistEffM)",
    "arret mecanique AX8": "BottomTouchStabTimer.Q AND DiveStartStopped",
    "attente AX3 conserve arret physique": "IF DiveStartStopTimer.Q AND DeadmanArmed AND JoystickPush THEN",
    "timeout AX3 desactive": "DiveStartTimeoutTimer(IN := FALSE, PT := CST_DiveStartStopTimeout)",
    "cause timeout AX3 neutralisee": "instCauses[10].Active   := FALSE",
    "mode essai visible": "CycleChecksInhibited",
    "mode essai borne semi-auto": "CycleChecksInhibited := CfgCycleChecksInhibit AND (Mode = E_Mode.SEMI_AUTO)",
    "fin egouttage autonome": "IF DrainingTimer.Q OR SkipDrainEdge.Q THEN",
    "forcage prepare": "ForceStepPrepared",
    "cible candidate non publiee": "ForceStepCandidate",
    "etape attente 21 explicite": "21: ForceStepCandidate := E_AutoCycleStep.AX3_WAIT_DIVE_START",
    "etape terminale refusee": "(CfgForceStepTarget <> 18) AND (CfgForceStepTarget <> 19)",
    "attente forcage distinguee": "ForceStepWaiting",
}
errors = [name for name, token in required_cycle.items() if token not in CYCLE]

if CYCLE.count("RunRequest := DeadmanArmed AND JoystickPull") < 8:
    errors.append("montees AX9-AX12 non qualifiees Y+")

for forbidden, label in (
    ("KoboldContactorFeedback", "pseudo-feedback contacteur Kobold"),
    ("ABS(M1_CablePosM - M2_CablePosM) <= CtrlAscentToleranceM", "ecart brut AX11"),
    ("CST_CoupledPosBacklashM", "seuil synchro local cycle duplique"),
    ("IF JoystickDeflected AND (DrainingTimer.Q OR SkipDrainEdge.Q) THEN", "geste joystick cache encore requis pour quitter AX13"),
    ("DiveStartTimeoutTimer.Q\n                           AND (State = E_AutoCycleStep.AX3_WAIT_DIVE_START)", "timeout AX3 encore routé vers un défaut"),
):
    if forbidden in CYCLE or forbidden in PRG03:
        errors.append(label)

if "(PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.SEMI_AUTO)" not in PRG04:
    errors.append("barriere atomique non bornee SEMI_AUTO")
for token, label in (
    ("Data.WinchSyncError               := instWinchSync.SyncDeviationFault", "warning synchro encore routé bloquant cycle"),
    ("OR WinchM1Safety.ErrorMecaE", "Meca E M1 absente du signal cycle"),
    ("OR WinchM2Safety.ErrorMecaE", "Meca E M2 absente du signal cycle"),
):
    if token not in PRG04:
        errors.append(label)

# REX terrain 2026-09-06 : AX10/AX11 sont volontairement dissymetriques.
# Le gate doit couper la synchro a la source et FB_WinchSync doit executer ses
# sous-blocs desactives pour purger WarnLatched avant le rearmement en AX12.
for token, label in (
    ("AND NOT (PRG_03_Modes_Cycle.Data.SequenceState.Step = E_AutoCycleStep.AX10_CLOSE_BUCKET)", "surveillance synchro encore active en AX10"),
    ("AND NOT (PRG_03_Modes_Cycle.Data.SequenceState.Step = E_AutoCycleStep.AX11_CTRL_ASCENT)", "surveillance synchro encore active en AX11"),
):
    if token not in PRG04:
        errors.append(label)
for token, label in (
    ("instDeviation(Enable := FALSE, Reset := TRUE);", "sous-bloc deviation non purge gate ferme"),
    ("instContactor(Enable := FALSE, Reset := TRUE);", "sous-bloc contacteurs non purge gate ferme"),
):
    if token not in WINCH_SYNC:
        errors.append(label)
if "JoystickPull            := PRG_02_Acquisition.Data.Joystick.AxisY.DirectionPositive" not in PRG03:
    errors.append("liaison JoystickPull PRG02 vers cycle")
for token, source, label in (
    ("TranslationFinalInterlockRequest.ReqTremieSemantic := M3_ReqTremie_Active", PRG05, "sens Tremie semantique non publie vers PRG06"),
    ("AND PRG_05_Translation.Data.TranslationFinalInterlockRequest.ReqTremieSemantic", PRG06, "FDC Tremie final encore dependant du mot variateur inverse"),
):
    if token not in source:
        errors.append(label)
for token, label in (
    ("BottomTouchConfirmed   := instCycleSemiAuto.BottomTouched", "fond qualifie non publie"),
    ("Data.SequenceState.CycleChecksInhibited   := FALSE", "neutralisation etat essai hors semi-auto"),
    ("Data.SequenceState.ForceStepPrepared      := FALSE", "neutralisation forcage hors semi-auto"),
):
    if token not in PRG03:
        errors.append(label)

# REX terrain AX7 : le basculement AX_STAB fait retomber les causes contextuelles
# dans ErrorId. Le bandeau doit recevoir le bit latche, sinon il affiche "Defaut #0".
for token, label in (
    ("Fault.Error\n                                                       OR PRG_03_Modes_Cycle.Data.SequenceState.Fault.Latched", "IHM cycle ne publie pas le latch"),
    ("SEL(PRG_03_Modes_Cycle.Data.SequenceState.Fault.Latched,", "IHM cycle ne choisit pas LatchedId en AX_STAB"),
    ("CycleErrorId          := GVL_IHM.CycleSemiAuto.State.ErrorId", "bandeau ne consomme pas le code IHM persistant"),
):
    if token not in PRG07:
        errors.append(label)

if errors:
    print("G495 FAIL: " + ", ".join(errors))
    sys.exit(1)
print("G495 PASS - invariants statiques T258 presents; preuves dynamiques encore requises")
