# -*- coding: utf-8 -*-
"""J2 : table de correspondance deterministe. Entrees : inventaire courant, liste snapshot, snapshots CSV."""
import csv, glob, os, re, sys, collections
from pathlib import Path
sys.stdout.reconfigure(encoding="utf-8")
T = Path(r"C:\Users\ZEDVICTUS\.claude\jobs\ebe3ca88\tmp"); O = T / "j2"
REPO = Path(r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage")
ETAPES = {1: "Bilan", 2: "Entrees brutes", 3: "Mesures traitees", 4: "Mode et interdictions", 5: "Demande", 6: "Securite axe", 7: "Permis", 8: "Barriere finale", 9: "Sorties", 10: "Retour physique"}
PRE = "GVL_Troubleshooting."
s = lambda c: c.replace(PRE, "")
inv = {s(r["chemin"]): r for r in csv.DictReader(open(T / "troubleshooting_inventory.csv", encoding="utf-8-sig"), delimiter=";")}
listed = [s(x) for x in (REPO / "TOOLS/PLC_CSV_SNAPSHOT/variable_lists/troubleshooting_variables.txt").read_text(encoding="utf-8").split()]
ALL = list(dict.fromkeys(listed + list(inv)))
COMMUN = ("M1M2_TopPositionFree_DI", "M1_M2_M3_BrakeThermalOk_DI", "M1_M2_KoboldBottomTouch_DI")
RETOUR = r"BrakeIsOpen|ContactorsReleased|ActualFrequency|BrakeApplied|DriveActualFreq"


def axis(n):
    if "COD1" in n: return "M1"
    if "COD2" in n: return "M2"
    a = [x for x in ("M1", "M2", "M3") if x in n]
    return a[0] if len(a) == 1 else ""


def io(n):
    if re.search(RETOUR, n): return 10
    if re.search(r"_DI$|Raw|_ANA|DeviceState|PosValue|SpdValue|StatusWord|Alarm|Warning", n): return 2
    return 3


def chain(n):
    """blocs N/O/P et Q/R/S"""
    if re.match(r"Step\d|AllConditionsMet$|BlockReason|FinalPermitBlocked", n): return 1
    if n.startswith("HwIn_"): return 2
    if n in ("RequestedDirection", "RequestedSpeedPct"): return 5
    if re.search(r"^Relay|SpeedContactor|Cmd_", n): return 9
    if re.search(r"SafeStop|PowerCutOff", n): return 6
    if re.search(r"HeightInterlock", n): return 4
    if n == "DriveOperational": return 2
    if re.search(r"FinalInterlock|Inhibited|StepNumber", n): return 8
    if re.search(r"Permit|ProcessBlock", n): return 7
    raise SystemExit("chain? " + n)


def place(p):
    h = p.split("."); g = h[0]; n = h[-1]; L = g[0]
    if p.startswith("PRG_06_Outputs.instSafety"): return "GENERAL.Puissance", 0
    if "instWinchOutputInterlockM1" in p: return "AXE.M1", 8
    if "instWinchOutputInterlockM2" in p: return "AXE.M2", 8
    if p == "PRG_06_Outputs.Data.M1AscentStartReady": return "AXE.M1", 8
    if p == "PRG_06_Outputs.Data.ContactorMismatch": return "GENERAL.Puissance", 0
    if p.startswith("PRG_04"): return "AXE." + axis(p), 8
    if L == "A": return "GENERAL.Contexte", 0
    if L == "C": return "GENERAL.Puissance", 0
    if L == "D": return "GENERAL.Operateur", 0
    if g in ("E_HomingM1", "F_HomingM2"): return "FONCTION.Referencement", 0
    if L == "G": return "FONCTION.Cycle", 0
    if L == "H": return "FONCTION.Couplage", 0
    if L == "K": return "FONCTION.Benne", 0
    if L == "B":
        if n in COMMUN: return "GENERAL.CapteursCommuns", 0
        if ".Machine." in p: return "GENERAL.Puissance", 0
        if ".Operator." in p: return "GENERAL.Operateur", 0
        if ".Translation." in p: return "AXE.M3", io(n)
        return "AXE." + axis(n), io(n)
    if L in "NOP": return "AXE.M" + str("NOP".index(L) + 1), chain(n)
    if L in "QRS": return "AXE.M" + str("QRS".index(L) + 1), chain(n)
    if L == "T":
        if n == "ArmingPermit": return "GENERAL.Operateur", 0
        if re.search(r"Both", n): return "FONCTION.Couplage", 0
        if re.search(r"Bucket|Extraction", n): return "FONCTION.Benne", 0
        if n == "DiveDescendPermit": return "FONCTION.Benne", 0
        return "AXE." + axis(n), 7
    if L in "IJL":
        ax = {"I": "M1", "J": "M2", "L": "M3"}[L]; z = h[1]
        if z.startswith("Demandes"): return "AXE." + ax, 4 if re.search(r"Mode|Bypass", n) else 5
        if z.startswith("Inputs"):
            if re.match(r"Idx10[1-5]_Pos", n): return "AXE." + ax, 3
            return "AXE." + ax, io(n)
        if z.startswith("Safety"):
            if re.search(r"EffectivePermitM3", n): return "AXE." + ax, 7
            return "AXE." + ax, 4 if re.search(r"Height|Interlock.*Ok|Bypass", n) else 6
        if z.startswith("Control"): return "AXE." + ax, 8
        if z.startswith("Outputs"): return "AXE." + ax, 9
    raise SystemExit("place? " + p)


def rank(p):
    L = p[0]
    sub = next((i for i, z in enumerate(("Inputs_100", "Outputs_500", "Demandes_200", "Safety_300", "Control_400")) if z in p), 9)
    return ({"B": 0, "A": 1, "D": 2, "I": 3, "J": 3, "L": 3, "T": 4, "C": 5, "Q": 6, "R": 6, "S": 6, "N": 7, "O": 7, "P": 7, "K": 8, "G": 9}.get(L, 10), sub, len(p), p)


# Faits communs a plusieurs axes sans variable generale : l'ancre change de zone (regle R3)
OVER = {"Idx210_CoupledUserRequestDirection": ("FONCTION.Couplage", 0), "Idx211_CoupledUserRequestActive": ("FONCTION.Couplage", 0),
        "Idx305_TopSensorBypassActive": ("GENERAL.Contexte", 0), "Idx308_SlackCableBypassActive": ("GENERAL.Contexte", 0),
        "Idx326_BypassTopLimitSoftCommun": ("GENERAL.Contexte", 0), "Idx328_BypassTopLimitSwitchCommun": ("GENERAL.Contexte", 0),
        "Idx330_BypassGlobalCommun": ("GENERAL.Contexte", 0), "Idx321_CfgTopLimitM": ("GENERAL.Contexte", 0),
        "TopPositionSensorActive": ("GENERAL.CapteursCommuns", 0)}


EXEMPT = re.compile(r"\.Step\d|\.AllConditionsMet$")
ALIAS = {}
_seen = collections.Counter()
for l in (REPO / "CODE/M_MAIN/PRG_07_Supervision.st").read_text(encoding="utf-8", errors="replace").splitlines():
    m = re.match(r"\s*(GVL_IHM\.[\w.]+)\s*:=\s*([A-Za-z_][\w.]*)\s*;", l)
    any_ = re.match(r"\s*(GVL_IHM\.[\w.]+)\s*:=", l)
    if any_: _seen[any_.group(1)] += 1
    if m and m.group(2) not in ("TRUE", "FALSE"): ALIAS[m.group(1)] = m.group(2)
ALIAS = {k: v for k, v in ALIAS.items() if _seen[k] == 1}


def canon(x):
    for _ in range(4):
        if x not in ALIAS: break
        x = ALIAS[x]
    return x


groups = collections.defaultdict(list); neg = collections.defaultdict(list)
for p, i in inv.items():
    if i["dans_troubleshooting_variables"] == "non": continue
    if i["classe_expression"] == "COPIE" and i["source_amont"]: groups[canon(i["source_amont"])].append(p)
    if i["classe_expression"] == "NEGATION": neg[i["source_amont"]].append(p)
groups = {k: v for k, v in groups.items() if len(v) > 1}

# preuve par groupe sur tous les snapshots
base = str(REPO / "TOOLS/PLC_CSV_SNAPSHOT/RESULTS/snapshot")
files = glob.glob(base + r"\*.csv") + glob.glob(base + r"\archive\*.csv")


def norm(v):
    v = v.strip(); m = re.fullmatch(r"(?:[A-Z]+#)(.+)", v)
    return m.group(1) if m and not v.startswith(("TIME#", "T#")) else v


proof = collections.defaultdict(lambda: [0, 0])
snaps = []
for f in files:
    pos, val = {}, {}
    for i, l in enumerate(open(f, encoding="utf-8-sig", errors="replace").read().splitlines()[1:]):
        if ";" in l:
            k, v = l.split(";", 1); k = s(k); pos[k] = i // 100; val[k] = norm(v)
    snaps.append((pos, val))
for src, v in groups.items():
    for pos, val in snaps:
        o = [c for c in v if c in val]
        for i in range(len(o)):
            for j in range(i + 1, len(o)):
                if pos[o[i]] == pos[o[j]]:
                    proof[src][0] += 1; proof[src][1] += val[o[i]] != val[o[j]]

dec = {}


def setd(p, d, regle, garde="", raison=""):
    dec[p] = dict(decision=d, regle=regle, garde=garde, raison=raison)


mixed = []
refused = []
for src, v in groups.items():
    core = [p for p in v if not EXEMPT.search(p)]
    if len(core) < 2: continue
    tp = [p for p in core if p.startswith("T_")]
    keep = min(tp or core, key=rank)
    n, d = proof[src]
    if d and src not in ("PRG_06_Outputs.Data.M2RelayRev", "PRG_02_Acquisition.HwIn.Operator.JoyYRaw_ANA2"):
        refused.append((src, n, d, core)); continue
    axes = {place(p)[0] for p in core if place(p)[0].startswith("AXE")}
    if len(axes) > 1 and not place(keep)[0].startswith("GENERAL") and keep.rsplit(".", 1)[-1] not in OVER: mixed.append((keep, core))
    for p in core:
        if p != keep:
            pv = "%d paires meme lot, %d ecart" % (n, d) if n else "aucune paire meme lot, preuve par le code seul"
            setd(p, "RETRAIT_COPIE", "R1", keep, "Aucune panne propre : meme source %s, meme scan. Preuve : %s." % (src, pv))
NEG = {"I_LevageUnitaireM1.Inputs_100.Idx104_BrakeApplied": "B_Inputs.Winch.M1_BrakeIsOpen_DI",
       "J_LevageUnitaireM2.Inputs_100.Idx104_BrakeApplied": "B_Inputs.Winch.M2_BrakeIsOpen_DI",
       "I_LevageUnitaireM1.Safety_300.Idx307_SlackCablePhysical_DI": "J_LevageUnitaireM2.Safety_300.Idx307_SlackCablePhysical_DI"}
for p, k in NEG.items():
    setd(p, "RETRAIT_NEGATION", "R2", k, "Aucune panne propre : meme fait, polarite inverse ou meme capteur unique M2.")
for p in ("H_LevageSynchroniseM1M2.Idx201_JoyYRaw_Pct", "H_LevageSynchroniseM1M2.Idx203_ArbitratedSpeed_Pct", "H_LevageSynchroniseM1M2.Idx402_M1_SetpointSpeed_Pct", "H_LevageSynchroniseM1M2.Idx403_M2_SetpointSpeed_Pct"):
    setd(p, "RETRAIT_NON_ECRITE", "R5", "", "Jamais ecrite par la vue : valeur par defaut trompeuse. Equivalent lisible sur les fiches d'axe.")
setd("H_LevageSynchroniseM1M2.Idx401_SyncMotionAllowed", "RETRAIT_NON_ECRITE", "R5", "PRG_04_Treuils_Benne.SyncOperationPermit", "Jamais ecrite : valeur par defaut trompeuse. Remplacee par SyncOperationPermit, lu directement.")
setd("A_ContexteMachineGlobal.Idx203_BypassSensorsGlobal", "A_VALIDER", "R6", "", "Constante FALSE, TBD : affiche 'pas de bypass' sans le mesurer. Cabler ou retirer.")
setd("P_MotionM3.SpeedContactor1Active", "RETRAIT_NON_APPLICABLE", "R6", "", "Constante FALSE : M3 n'a pas de contacteur de vitesse (commentaire code).")
setd("P_MotionM3.Step3_NotBusyOtherTask", "GARDER", "R4", "", "Constante TRUE conservee : garde l'alignement des 8 maillons sur les 3 axes.")
for p in ("T_Permits.AppliedPermitM1_Ascent", "T_Permits.AppliedPermitM1_Descend"):
    dec.pop(p, None)
    setd(p, "GARDER", "R4", "", "Sur M1 egal a Effective ; garde car distinct sur M2 : meme fiche sur les 2 treuils.")
for p in ("P_MotionM3.Step8_InterlockState", "P_MotionM3.Step8_InterlockReason"):
    setd(p, "A_VALIDER", "R6", "", "Valeurs de l'enum treuil recalculees pour M3 : pas de vraie barriere M3. Renommer ou retirer a J4.")
for p, i in inv.items():
    if i["dans_troubleshooting_variables"] == "non":
        setd(p, "AJOUT_J3", "R7", "", "Declaree, absente de la liste. Texte de cycle prevu au jalon J3.")
for p in ALL:
    if p not in dec:
        r = "R4" if EXEMPT.search(p) else ("R3" if place(p)[0].startswith("GENERAL") else "R0")
        setd(p, "GARDER", r, "", "Maillon de chaine lu sans saut." if r == "R4" else "")


# === Corrections apres juge natif, verifiees a la source ===
def F(suf):
    m = [p for p in ALL if p.endswith(suf)]
    if len(m) != 1: raise SystemExit("ambigu %s %s" % (suf, m[:4]))
    return m[0]


JUGE = "Juge natif 2026-11-07, verifie a la source."
EXTRA = []
for ax, I in (("1", "I_LevageUnitaireM1"), ("2", "J_LevageUnitaireM2")):
    Q = {"1": "Q_TraceWinchM1", "2": "R_TraceWinchM2"}[ax]; N = {"1": "N_MotionM1", "2": "O_MotionM2"}[ax]
    setd(I + ".Control_400.Idx404_BrakeReleaseAuthorized", "GARDER", "R8", "", "Demande frein cote treuil, scan N-1. Differente de la sortie reelle PRG_06.")
    setd(N + ".Cmd_BrakeRelease", "RETRAIT_COPIE", "R1", I + ".Control_400.Idx404_BrakeReleaseAuthorized", "Aucune panne propre : meme State.BrakeCmd. " + JUGE)
    setd(I + ".Outputs_500.Idx505_CmdBrakeRelease_RQ", "CABLER_J4", "R8", "", "Lit State.BrakeCmd, pas la sortie : PRG_06 recalcule le frein et ajoute le forcage N2. Rebrancher sur PRG_06_Outputs.Data.M%sBrakeCmd." % ax)
    setd(I + ".Control_400.Idx403_SpeedRamp_Pct", "RETRAIT_COPIE", "R1", I + ".Demandes_200.Idx208_ArbitratedSpeed_Pct", "Aucune panne propre : FB_WinchStateProjection copie LogicRequestSpeedCmd_Pct. " + JUGE)
    setd(N + ".RequestedSpeedPct", "RETRAIT_COPIE", "R1", I + ".Demandes_200.Idx208_ArbitratedSpeed_Pct", "Aucune panne propre : meme valeur. " + JUGE)
    setd(I + ".Control_400.Idx408_BrakeCommandOpenConfirmed", "RETRAIT_COPIE", "R1", "B_Inputs.Winch.M%s_BrakeIsOpen_DI" % ax, "Aucune panne propre : State recopie le DI. " + JUGE)
    for d, n in (("Ascent", "306_AscentPermitEffective"), ("Descend", "309_DescendPermitEffective")):
        setd(I + ".Safety_300.Idx" + n, "RETRAIT_COPIE", "R1", "T_Permits.EffectivePermitM%s_%s" % (ax, d), "Aucune panne propre : meme permis effectif. " + JUGE)
        setd("T_Permits.M%sSafety%sPermit" % (ax, d), "CABLER_J4", "R8", "", "Nom faux : lit le permis Effective. Le vrai permis Safety est PRG_04_Treuils_Benne.SafetyPermitM%s_%s." % (ax, d))
    setd(Q + ".SafeStopActive", "RETRAIT_COPIE", "R1", I + ".Safety_300.Idx302_SafeStopActive", "Aucune panne propre : meme SafeStopMx_Active. " + JUGE)
    setd(Q + ".PowerCutOffActive", "RETRAIT_COPIE", "R1", I + ".Safety_300.Idx303_PowerCutOffActive", "Aucune panne propre. " + JUGE)
    setd(Q + ".StepNumber", "RETRAIT_COPIE", "R1", I + ".Control_400.Idx402_SpeedStepCalculated", "Aucune panne propre. " + JUGE)
    setd(Q + ".FinalInterlockReason", "RETRAIT_COPIE", "R1", I + ".Control_400.Idx406_FinalInterlockReason", "Aucune panne propre. " + JUGE)
    setd("G_CycleSemiAuto.Idx30%d_M%sSpeedStepApplied" % (6 + int(ax), ax), "RETRAIT_COPIE", "R1", I + ".Control_400.Idx402_SpeedStepCalculated", "Aucune panne propre : meme StepNumber, nom 'Applied' trompeur. " + JUGE)
    setd(I + ".Demandes_200.Idx211_CoupledUserRequestActive", "RETRAIT_COPIE", "R1", "T_Permits.BothActive", "Aucune panne propre. " + JUGE)
    setd("H_LevageSynchroniseM1M2.Idx30%d_M%s_AscentPermit" % (2 + int(ax), ax), "RETRAIT_COPIE", "R1", "T_Permits.EffectivePermitM%s_Ascent" % ax, "Aucune panne propre. " + JUGE)
    EXTRA.append(("GVL_IHM.IoHw.Out.M%s_BrakeRelease_RQ" % ax, "AXE.M" + ax, 9, "Image de la sortie frein physique, forcage N2 inclus."))
    for c in (2, 3):
        EXTRA.append(("GVL_IHM.IoHw.Out.M%s_SpeedContactor_%d_DQ" % (ax, c), "AXE.M" + ax, 9, "Contacteur de palier absent de la fiche."))
    for d in ("Ascent", "Descend"):
        EXTRA.append(("PRG_04_Treuils_Benne.SafetyPermitM%s_%s" % (ax, d), "AXE.M" + ax, 7, "Vrai permis Safety avant Process."))
    EXTRA.append(("PRG_02_Acquisition.Data.EncoderM%s.HomedAndReliable" % ax, "AXE.M" + ax, 3, "Codeur disponible, reference et coherent."))
L = "L_TranslationPontM3."
for n, b in (("Idx101_PosTremie_DI", "M3_PosTremie_DI"), ("Idx102_PosPV_DI", "M3_PosPV_DI"), ("Idx103_PosP2_DI", "M3_PosPVP2_DI"), ("Idx104_PosP1_DI", "M3_PosP1_DI"), ("Idx105_PosMaintenance_DI", "M3_PosMaintenance_DI")):
    setd(L + "Inputs_100." + n, "RETRAIT_COPIE", "R1", "B_Inputs.Translation." + b, "Aucune panne propre : passthrough PRG_05:115-119 et decodeur:94-98. " + JUGE)
setd(F("L_TranslationPontM3.Inputs_100.Idx109_DriveThermalOk"), "RETRAIT_COPIE", "R1", F("B_Inputs.Translation.M3_ThermalOK_DI"), "Aucune panne propre. " + JUGE)
setd(L + "Inputs_100.Idx108_BrakeApplied", "RETRAIT_NEGATION", "R2", "B_Inputs.Translation.M3_BrakeIsOpen_DI", "Aucune panne propre : negation du DI, PRG_05:742. " + JUGE)
setd(L + "Control_400.Idx403_DriveControlWord", "GARDER", "R8", "", "Mot demande, avant barriere finale M3.")
setd("P_MotionM3.Cmd_BrakeRelease", "GARDER", "R8", "", "Demande frein M3, avant barriere finale.")
setd(L + "Outputs_500.Idx501_CmdDriveControlWord", "CABLER_J4", "R8", "", "Lit la demande, pas la sortie. Rebrancher sur PRG_06_Outputs.M3_CommandWord.")
setd(L + "Outputs_500.Idx503_CmdBrakeRelease_RQ", "CABLER_J4", "R8", "", "Lit la demande, pas la sortie. Rebrancher sur PRG_06_Outputs.Data.TranslationBrakeCmd.")
EXTRA += [("GVL_IHM.IoHw.Out.M3_CommandWord", "AXE.M3", 9, "Image du mot de commande variateur physique."),
          ("GVL_IHM.IoHw.Out.M3_BrakeRelease_RQ", "AXE.M3", 9, "Image de la sortie frein M3 physique."),
          ("PRG_06_Outputs.instSafetyEmergencyManagement.BypassPowerCutOff", "GENERAL.Puissance", 0, "Bypass MES : le PLC ne fait jamais chuter l'AU."),
          ("PRG_06_Outputs.instSafetyEmergencyManagement.BypassRedundancyTest", "GENERAL.Puissance", 0, "Bypass de l'auto-test A/B complet."),
          ("PRG_04_Treuils_Benne.WinchBothFinalRequestsCoherent", "FONCTION.Couplage", 0, "Demandes physiques M1 et M2 coherentes."),
          ("PRG_04_Treuils_Benne.SyncOperationPermit", "FONCTION.Couplage", 0, "Gate canonique de la synchro ; remplace Idx401 jamais ecrite."),
          ("PRG_04_Treuils_Benne.ManualBucketJogActive", "FONCTION.Benne", 0, "Jog benne unitaire M2 en maintenance."),
          ("PRG_04_Treuils_Benne.M2_LimitShift", "FONCTION.Benne", 0, "Decalage benne applique aux limites M2."),
          ("PRG_06_Outputs.M3_TremieHardStopActive", "AXE.M3", 8, "Coupure M3 aujourd'hui invisible.")]
setd(F(".Idx308_HeightInterlockBlocking") if any(p.endswith(".Idx308_HeightInterlockBlocking") for p in ALL) else [p for p in ALL if p.startswith(L + "Safety_300.Idx308")][0], "RETRAIT_COPIE", "R1", "S_TraceTranslation.HeightInterlockBlocking", "Aucune panne propre. " + JUGE)
K = "K_BenneOuvertureFermeture."
for prefix, anchor in (("Idx206", "T_Permits.BucketCloseRequestActive"), ("Idx207", "T_Permits.BucketOpenRequestActive"), ("Idx208", "T_Permits.BucketMotionBlocked")):
    setd([p for p in ALL if p.startswith(K + prefix)][0], "RETRAIT_COPIE", "R1", anchor, "Aucune panne propre. " + JUGE)
setd([p for p in ALL if p.startswith("A_ContexteMachineGlobal.Idx103")][0], "RETRAIT_COPIE", "R1", "D_Joystick.Step2_JoystickOperational", "Aucune panne propre. " + JUGE)
setd("C_Safety.PowerCutOffRequest", "RETRAIT_COPIE", "R1", "C_Safety.PowerCutOffActive", "Aucune panne propre : PRG_06 fixe les deux depuis PowerCutOffReq. " + JUGE)
for n, anchor in (("Status.State.Step", "C_Safety.ArmingStep"), ("Status.Diag.Error", "C_Safety.SafetyError"), ("Status.Diag.LastAbortStep", "C_Safety.LastAbortStep"), ("Status.Diag.LastAbortCause", "C_Safety.LastAbortCause")):
    setd("PRG_06_Outputs.instSafetyEmergencyManagement." + n, "RETRAIT_COPIE", "R1", anchor, "Aucune panne propre. " + JUGE)
setd("S_TraceTranslation.SafeStopActive", "RETRAIT_COPIE", "R1", [p for p in ALL if p.startswith(L + "Safety_300.Idx302")][0], "Aucune panne propre : meme SafeStop M3. " + JUGE)
setd("S_TraceTranslation.PowerCutOffActive", "RETRAIT_COPIE", "R1", [p for p in ALL if p.startswith(L + "Safety_300.Idx303")][0], "Aucune panne propre. " + JUGE)
setd(L + "Safety_300.Idx318_EffectivePermitM3_Tremie", "RETRAIT_COPIE", "R1", "T_Permits.EffectivePermitM3_Tremie", "Aucune panne propre : PRG_05:820-821,840-842. " + JUGE)
setd(L + "Safety_300.Idx319_EffectivePermitM3_Maintenance", "RETRAIT_COPIE", "R1", "T_Permits.EffectivePermitM3_Maintenance", "Aucune panne propre : PRG_05:820-821,840-842. " + JUGE)
TF = "B_Inputs.Winch.M1M2_TopPositionFree_DI"
setd("E_HomingM1.TopPositionSensorActive", "RETRAIT_NEGATION", "R2", TF, "Aucune panne propre : negation du DI, PRG_07:419. " + JUGE)
setd("F_HomingM2.TopPositionSensorActive", "RETRAIT_NEGATION", "R2", TF, "Aucune panne propre : negation du DI. " + JUGE)
TC = "B_Inputs.Winch.M2_TensionedCable_DI"
setd("J_LevageUnitaireM2.Safety_300.Idx307_SlackCablePhysical_DI", "RETRAIT_NEGATION", "R2", TC, "Aucune panne propre : negation du DI. " + JUGE)
setd("I_LevageUnitaireM1.Safety_300.Idx307_SlackCablePhysical_DI", "RETRAIT_NEGATION", "R2", TC, "Aucune panne propre : capteur unique M2, negation du DI. " + JUGE)
ZONE = {TC: ("GENERAL.CapteursCommuns", 0), F("B_Inputs.Machine.TremieFull_OR_GateRaised_DI"): ("AXE.M3", 2),
        "PRG_06_Outputs.Data.ContactorMismatch": ("FONCTION.Couplage", 0), "P_MotionM3.RelayFwdActive": ("AXE.M3", 5), "P_MotionM3.RelayRevActive": ("AXE.M3", 5),
        L + "Control_400.Idx402_SetpointFreq_Hz": ("AXE.M3", 5), L + "Control_400.Idx403_DriveControlWord": ("AXE.M3", 5), "P_MotionM3.Cmd_BrakeRelease": ("AXE.M3", 5),
        L + "Control_400.Idx401_MotionAllowed": ("AXE.M3", 6), "I_LevageUnitaireM1.Control_400.Idx401_MotionAllowed": ("AXE.M1", 6), "J_LevageUnitaireM2.Control_400.Idx401_MotionAllowed": ("AXE.M2", 6),
        "I_LevageUnitaireM1.Control_400.Idx402_SpeedStepCalculated": ("AXE.M1", 5), "J_LevageUnitaireM2.Control_400.Idx402_SpeedStepCalculated": ("AXE.M2", 5)}
for p in ALL:
    if p.startswith(("I_LevageUnitaireM1.Control_400.Idx41", "J_LevageUnitaireM2.Control_400.Idx41")) and re.search(r"Idx41[234]_", p):
        ZONE[p] = ("AXE.M" + ("1" if p[0] == "I" else "2"), 3)
    if p.startswith(K) and re.match(r"Idx11[34579]_|Idx116_|Idx120_", p.split(".")[-1]):
        ZONE[p] = ("FONCTION.Referencement", 0)

ZONE[L + "Inputs_100.Idx106_DriveActualFreq_Hz"] = ("AXE.M3", 3)
ZONE[[p for p in ALL if p.startswith(L + "Safety_300.Idx307")][0]] = ("AXE.M3", 3)
CONS = collections.defaultdict(list)
for f in sorted((REPO / "TOOLS/PLC_CSV_SNAPSHOT/variable_lists").glob("*.txt")):
    if f.name.startswith("troubleshooting_variables"): continue
    for x in f.read_text(encoding="utf-8", errors="replace").split():
        CONS[s(x)].append(f.stem)

rows = []
ORD = {"GENERAL.Contexte": 0, "GENERAL.Puissance": 1, "GENERAL.Operateur": 2, "GENERAL.CapteursCommuns": 3, "AXE.M1": 4, "AXE.M2": 5, "AXE.M3": 6, "FONCTION.Referencement": 7, "FONCTION.Couplage": 8, "FONCTION.Benne": 9, "FONCTION.Cycle": 10}
for p in ALL:
    z, e = place(p); d = dec[p]; i = inv.get(p, {})
    if p.rsplit(".", 1)[-1] in OVER and d["decision"] == "GARDER": z, e = OVER[p.rsplit(".", 1)[-1]]
    if p in ZONE: z, e = ZONE[p]
    rows.append(dict(chemin_actuel=p, zone=z, etape=e, etape_nom=ETAPES.get(e, ""), decision=d["decision"], regle=d["regle"], variable_conservee=d["garde"], raison=d["raison"], classe=i.get("classe_expression", "HORS_GVL"), source=i.get("source_amont", p), nb_traces=i.get("nb_fichiers_trace", ""), listes_trace=len(CONS.get(p, [])), dans_liste="oui" if p in listed else "non"))
for p, z, e, why in EXTRA:
    rows.append(dict(chemin_actuel=p, zone=z, etape=e, etape_nom=ETAPES.get(e, ""), decision="AJOUT_J3", regle="R8", variable_conservee="", raison=why, classe="HORS_GVL", source=p, nb_traces="", listes_trace=0, dans_liste="non"))
ALL = ALL + [x[0] for x in EXTRA]
rows.sort(key=lambda r: (ORD[r["zone"]], r["etape"], ALL.index(r["chemin_actuel"])))
with open(O / "TABLE_CORRESPONDANCE.csv", "w", newline="", encoding="utf-8-sig") as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0].keys()), delimiter=";"); w.writeheader(); w.writerows(rows)

C = collections.Counter
print("total", len(rows), C(r["decision"] for r in rows).most_common())
print("regles", C(r["regle"] for r in rows).most_common())
kept = [r for r in rows if not r["decision"].startswith("RETRAIT")]
print("conservees", len(kept), C(r["zone"] for r in kept).most_common())
for z in ("AXE.M1", "AXE.M2", "AXE.M3"):
    print(z, [(e, sum(1 for r in kept if r["zone"] == z and r["etape"] == e)) for e in range(1, 11)])
print("axes mixtes sans home general:", [(a, b[:4]) for a, b in mixed])
print("retraits avec consommateur trace:", [(r["chemin_actuel"], r["listes_trace"]) for r in rows if r["decision"].startswith("RETRAIT") and (r["nb_traces"] not in ("", "0") or r["listes_trace"])][:60])
print("retraits dont groupe a un ecart:", C(r["raison"].split("Preuve : ")[-1] for r in rows if r["decision"] == "RETRAIT_COPIE" and "paires" in r["raison"] and " 0 ecart" not in r["raison"]).most_common(6))
print("groupes refuses (ecart inexplique):", refused)
print("retraits sans preuve snapshot:", sum(1 for r in rows if "preuve par le code seul" in r["raison"]))
ln = lambda L: sum(len(PRE) * (not r["chemin_actuel"].startswith("PRG")) + len(r["chemin_actuel"]) + 7 for r in L)
print("octets", ln(rows), "->", ln(kept))
print("--- retraits copie (conservee <- retiree)")
g = collections.defaultdict(list)
for r in rows:
    if r["decision"] == "RETRAIT_COPIE": g[r["variable_conservee"]].append(r["chemin_actuel"].split(".", 1)[0][:3] + "." + r["chemin_actuel"].rsplit(".", 1)[-1])
for k, v in g.items(): print(k, "<-", v)
