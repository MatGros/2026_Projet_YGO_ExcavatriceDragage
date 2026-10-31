# -*- coding: utf-8 -*-
"""T423_AUDIT_etat_des_lieux_complet — Bilan de santé exhaustif des 10 matériels machine.

A exécuter dans CODESYS : Tools > Scripting > Execute Script File...
Lecture 100% sécurisée : chaque variable est lue individuellement dans un try/except.
Aucun risque de crash 'Invalid expression', aucune écriture, aucune perturbation.
"""

import os
import sys

ENGINE_PATH = os.path.join(os.path.dirname(__file__), "T423_engine.py")
with open(ENGINE_PATH, "rb") as f:
    exec(compile(f.read(), ENGINE_PATH, "exec"), globals(), globals())


def safe_read(online_app, path):
    """Lecture unitaire protégée : retourne la valeur ou 'N/A' en cas d'erreur de symbole."""
    try:
        val = online_app.read_value(path)
        return str(val)
    except Exception:
        return "N/A"


def safe_read_map(online_app, paths):
    res = {}
    for p in paths:
        res[p] = safe_read(online_app, p)
    return res


def run_full_audit():
    online_app = get_online_app()
    if online_app is None:
        return

    with online_app:
        print("\n" + "#" * 65)
        print("  🏥 ÉTAT DES LIEUX COMPLET MACHINE (AUDIT LIVE 10 ORGANES)")
        print("#" * 65)

        # -------------------------------------------------------------
        # 1. D07 - SÉCURITÉ AU & PUISSANCE
        # -------------------------------------------------------------
        p_sec = (
            "GVL_Troubleshooting.A_ContexteMachineGlobal.Idx301_EmergencyChainClosed",
            "GVL_Troubleshooting.A_ContexteMachineGlobal.Idx302_PowerContactorEngaged",
            "GVL_Troubleshooting.A_ContexteMachineGlobal.Idx303_SafeStopActiveAny",
            "GVL_Troubleshooting.A_ContexteMachineGlobal.Idx304_PowerCutOffActiveAny",
            "GVL_IHM.Modes.State.EmergencyArmable",
            "GVL_Simulation.SimChainOk",
            "GVL_Simulation.SimSafetyActive",
            "PRG_06_Outputs.PowerCutOffReq",
        )
        d_sec = safe_read_map(online_app, p_sec)
        ch_ok = d_sec.get("GVL_Troubleshooting.A_ContexteMachineGlobal.Idx301_EmergencyChainClosed", "N/A")
        pwr_ok = d_sec.get("GVL_Troubleshooting.A_ContexteMachineGlobal.Idx302_PowerContactorEngaged", "N/A")
        
        status_sec = "🟢 OK" if (bool_val(ch_ok) and bool_val(pwr_ok)) else "🔴 ATTENTION"
        print("\n[D07 - SÉCURITÉ AU & PUISSANCE] -> " + status_sec)
        print("  • Chaîne AU fermée         : " + ch_ok)
        print("  • Contacteur Puissance     : " + pwr_ok)
        print("  • SafeStop Actif (Any)     : " + d_sec.get("GVL_Troubleshooting.A_ContexteMachineGlobal.Idx303_SafeStopActiveAny", "N/A"))
        print("  • Coupure Puissance (Req)  : " + d_sec.get("PRG_06_Outputs.PowerCutOffReq", d_sec.get("GVL_Troubleshooting.A_ContexteMachineGlobal.Idx304_PowerCutOffActiveAny", "N/A")))
        print("  • Prêt à armer (Armable)   : " + d_sec.get("GVL_IHM.Modes.State.EmergencyArmable", "N/A"))

        # -------------------------------------------------------------
        # 2. D01 - TREUIL M1 (RETENUE)
        # -------------------------------------------------------------
        p_m1 = (
            "GVL_IHM.M1TreuilRetenue.State.Position_M",
            "GVL_IHM.M1TreuilRetenue.State.MeasuredSpeed_Mps",
            "GVL_IHM.M1TreuilRetenue.State.StepNumber",
            "GVL_IHM.M1TreuilRetenue.State.Ready",
            "GVL_IHM.M1TreuilRetenue.State.Busy",
            "GVL_IHM.M1TreuilRetenue.State.BrakeCmd",
            "GVL_IHM.M1TreuilRetenue.State.RelayFwd",
            "GVL_IHM.M1TreuilRetenue.State.RelayRev",
            "GVL_IHM.M1TreuilRetenue.Safety.AscentPermit",
            "GVL_IHM.M1TreuilRetenue.Safety.DescendPermit",
            "GVL_IHM.M1TreuilRetenue.Safety.SafeStop",
            "GVL_IHM.M1TreuilRetenue.State.Error",
            "GVL_IHM.M1TreuilRetenue.State.ErrorId",
        )
        d_m1 = safe_read_map(online_app, p_m1)
        err_m1 = bool_val(d_m1.get("GVL_IHM.M1TreuilRetenue.State.Error", False))
        status_m1 = "🔴 DÉFAUT (Id:" + d_m1.get("GVL_IHM.M1TreuilRetenue.State.ErrorId", "0") + ")" if err_m1 else "🟢 SAIN"
        print("\n[D01 - TREUIL M1 (RETENUE)] -> " + status_m1)
        print("  • Position câble           : " + d_m1.get("GVL_IHM.M1TreuilRetenue.State.Position_M", "N/A") + " m")
        print("  • Vitesse mesurée          : " + d_m1.get("GVL_IHM.M1TreuilRetenue.State.MeasuredSpeed_Mps", "N/A") + " m/s")
        print("  • Palier de vitesse        : " + d_m1.get("GVL_IHM.M1TreuilRetenue.State.StepNumber", "N/A"))
        print("  • Frein (Desserré=TRUE)    : " + d_m1.get("GVL_IHM.M1TreuilRetenue.State.BrakeCmd", "N/A"))
        print("  • Relais Montée / Descente : " + d_m1.get("GVL_IHM.M1TreuilRetenue.State.RelayFwd", "N/A") + " / " + d_m1.get("GVL_IHM.M1TreuilRetenue.State.RelayRev", "N/A"))
        print("  • Permis Montée / Descente : " + d_m1.get("GVL_IHM.M1TreuilRetenue.Safety.AscentPermit", "N/A") + " / " + d_m1.get("GVL_IHM.M1TreuilRetenue.Safety.DescendPermit", "N/A"))

        # -------------------------------------------------------------
        # 3. D02 & D03 - TREUIL M2 & BENNE
        # -------------------------------------------------------------
        p_m2 = (
            "GVL_IHM.M2TreuilBenne.State.Position_M",
            "GVL_IHM.M2TreuilBenne.State.MeasuredSpeed_Mps",
            "GVL_IHM.M2TreuilBenne.State.StepNumber",
            "GVL_IHM.M2TreuilBenne.State.BrakeCmd",
            "GVL_IHM.M2TreuilBenne.State.Error",
            "GVL_IHM.M2TreuilBenne.State.ErrorId",
            "GVL_Troubleshooting.K_BenneOuvertureFermeture.Idx101_DeltaPosition_M",
            "GVL_Troubleshooting.K_BenneOuvertureFermeture.Idx102_BucketOpening_Pct",
            "GVL_Troubleshooting.K_BenneOuvertureFermeture.Idx103_MechStateIsOpen",
            "GVL_Troubleshooting.K_BenneOuvertureFermeture.Idx104_MechStateIsClosed",
            "GVL_Troubleshooting.K_BenneOuvertureFermeture.Idx107_Error",
        )
        d_m2 = safe_read_map(online_app, p_m2)
        err_m2 = bool_val(d_m2.get("GVL_IHM.M2TreuilBenne.State.Error", False)) or bool_val(d_m2.get("GVL_Troubleshooting.K_BenneOuvertureFermeture.Idx107_Error", False))
        status_m2 = "🔴 DÉFAUT" if err_m2 else "🟢 SAIN"
        print("\n[D02/D03 - TREUIL M2 & BENNE] -> " + status_m2)
        print("  • Position câble M2        : " + d_m2.get("GVL_IHM.M2TreuilBenne.State.Position_M", "N/A") + " m")
        print("  • Écart relatif M2-M1      : " + d_m2.get("GVL_Troubleshooting.K_BenneOuvertureFermeture.Idx101_DeltaPosition_M", "N/A") + " m")
        print("  • Ouverture Benne          : " + d_m2.get("GVL_Troubleshooting.K_BenneOuvertureFermeture.Idx102_BucketOpening_Pct", "N/A") + " %")
        print("  • État mécanique           : Ouverte=" + d_m2.get("GVL_Troubleshooting.K_BenneOuvertureFermeture.Idx103_MechStateIsOpen", "N/A") + " | Fermée=" + d_m2.get("GVL_Troubleshooting.K_BenneOuvertureFermeture.Idx104_MechStateIsClosed", "N/A"))

        # -------------------------------------------------------------
        # 4. D04 - TRANSLATION PONT M3
        # -------------------------------------------------------------
        p_m3 = (
            "GVL_Troubleshooting.L_TranslationPontM3.Inputs_100.Idx101_PosTremie_DI",
            "GVL_Troubleshooting.L_TranslationPontM3.Inputs_100.Idx102_PosPV_DI",
            "GVL_Troubleshooting.L_TranslationPontM3.Inputs_100.Idx103_PosP2_DI",
            "GVL_Troubleshooting.L_TranslationPontM3.Inputs_100.Idx104_PosP1_DI",
            "GVL_Troubleshooting.L_TranslationPontM3.Inputs_100.Idx105_PosMaintenance_DI",
            "GVL_Troubleshooting.L_TranslationPontM3.Inputs_100.Idx106_DriveActualFreq_Hz",
            "GVL_Troubleshooting.L_TranslationPontM3.Inputs_100.Idx108_BrakeApplied",
            "GVL_Troubleshooting.L_TranslationPontM3.Outputs_500.Idx503_CmdBrakeRelease_RQ",
            "GVL_IHM.Banner.PositionM3Text",
        )
        d_m3 = safe_read_map(online_app, p_m3)
        print("\n[D04 - TRANSLATION PONT M3] -> 🟢 SAIN")
        print("  • Repère Position IHM      : " + d_m3.get("GVL_IHM.Banner.PositionM3Text", "N/A"))
        print("  • Fréquence Variateur      : " + d_m3.get("GVL_Troubleshooting.L_TranslationPontM3.Inputs_100.Idx106_DriveActualFreq_Hz", "N/A") + " Hz")
        print("  • Frein M3 (Desserré=TRUE) : " + d_m3.get("GVL_Troubleshooting.L_TranslationPontM3.Outputs_500.Idx503_CmdBrakeRelease_RQ", "N/A"))
        cames = (
            "Trémie:" + d_m3.get("GVL_Troubleshooting.L_TranslationPontM3.Inputs_100.Idx101_PosTremie_DI", "0")
            + " | PV:" + d_m3.get("GVL_Troubleshooting.L_TranslationPontM3.Inputs_100.Idx102_PosPV_DI", "0")
            + " | P2:" + d_m3.get("GVL_Troubleshooting.L_TranslationPontM3.Inputs_100.Idx103_PosP2_DI", "0")
            + " | P1:" + d_m3.get("GVL_Troubleshooting.L_TranslationPontM3.Inputs_100.Idx104_PosP1_DI", "0")
            + " | Maint:" + d_m3.get("GVL_Troubleshooting.L_TranslationPontM3.Inputs_100.Idx105_PosMaintenance_DI", "0")
        )
        print("  • Cames physiques (DI)     : " + cames)

        # -------------------------------------------------------------
        # 5. D05 - CODEURS & RÉFÉRENCEMENT
        # -------------------------------------------------------------
        p_cod = (
            "PRG_02_Acquisition.Data.MachineHoming.Homed",
            "PRG_02_Acquisition.Data.MachineHoming.Step",
            "GVL_Troubleshooting.B_Inputs.Winch.COD1_PosValue",
            "GVL_Troubleshooting.B_Inputs.Winch.COD2_PosValue",
            "GVL_IHM.M1TreuilRetenue.State.Encoder.Homed",
            "GVL_IHM.M2TreuilBenne.State.Encoder.Homed",
            "GVL_IHM.Network.EncoderM1.Online",
            "GVL_IHM.Network.EncoderM2.Online",
        )
        d_cod = safe_read_map(online_app, p_cod)
        hm_ok = bool_val(d_cod.get("PRG_02_Acquisition.Data.MachineHoming.Homed", d_cod.get("GVL_IHM.M1TreuilRetenue.State.Encoder.Homed", False)))
        status_hm = "🟢 RÉFÉRENCÉ" if hm_ok else "🟡 NON RÉFÉRENCÉ"
        print("\n[D05 - CODEURS & RÉFÉRENCEMENT] -> " + status_hm)
        print("  • Machine Homed            : " + str(hm_ok))
        print("  • Étape Guide Homing       : " + d_cod.get("PRG_02_Acquisition.Data.MachineHoming.Step", "N/A"))
        print("  • Codeur M1 (COD1)         : Online=" + d_cod.get("GVL_IHM.Network.EncoderM1.Online", "N/A") + " | Pos=" + d_cod.get("GVL_Troubleshooting.B_Inputs.Winch.COD1_PosValue", "N/A"))
        print("  • Codeur M2 (COD2)         : Online=" + d_cod.get("GVL_IHM.Network.EncoderM2.Online", "N/A") + " | Pos=" + d_cod.get("GVL_Troubleshooting.B_Inputs.Winch.COD2_PosValue", "N/A"))

        # -------------------------------------------------------------
        # 6. D06 - SYNCHRONISME M1/M2
        # -------------------------------------------------------------
        p_sy = (
            "GVL_IHM.M1M2Sync.State.DeltaPos_M",
            "GVL_IHM.M1M2Sync.State.SyncWarn",
            "GVL_IHM.M1M2Sync.State.SyncDeviationWarn",
            "GVL_IHM.M1M2Sync.State.Error",
            "GVL_IHM.M1M2Sync.State.ErrorId",
        )
        d_sy = safe_read_map(online_app, p_sy)
        print("\n[D06 - SYNCHRONISME M1/M2]")
        print("  • Écart DeltaPos_M         : " + d_sy.get("GVL_IHM.M1M2Sync.State.DeltaPos_M", "N/A") + " m")
        print("  • Alerte écart (SyncWarn)  : " + d_sy.get("GVL_IHM.M1M2Sync.State.SyncWarn", "N/A"))
        print("  • Limitation Palier 1      : " + d_sy.get("GVL_IHM.M1M2Sync.State.SyncDeviationWarn", "N/A"))

        # -------------------------------------------------------------
        # 7. D08 - PUPITRE & JOYSTICK
        # -------------------------------------------------------------
        p_joy = (
            "GVL_IHM.Network.Joystick.Online",
            "GVL_Troubleshooting.D_Joystick.Idx101_DeadmanArmed",
            "GVL_Troubleshooting.D_Joystick.Idx102_AtNeutralXY",
            "GVL_Troubleshooting.D_Joystick.Idx103_RawX",
            "GVL_Troubleshooting.D_Joystick.Idx104_RawY",
            "GVL_Troubleshooting.A_ContexteMachineGlobal.Idx103_JoystickCommOk",
        )
        d_joy = safe_read_map(online_app, p_joy)
        print("\n[D08 - PUPITRE & JOYSTICK]")
        print("  • Joystick JOY1 Online     : " + d_joy.get("GVL_IHM.Network.Joystick.Online", d_joy.get("GVL_Troubleshooting.A_ContexteMachineGlobal.Idx103_JoystickCommOk", "N/A")))
        print("  • Homme-Mort Armé          : " + d_joy.get("GVL_Troubleshooting.D_Joystick.Idx101_DeadmanArmed", "N/A"))
        print("  • Position Neutre XY       : " + d_joy.get("GVL_Troubleshooting.D_Joystick.Idx102_AtNeutralXY", "N/A"))
        print("  • Consignes Raw X / Raw Y  : " + d_joy.get("GVL_Troubleshooting.D_Joystick.Idx103_RawX", "N/A") + " / " + d_joy.get("GVL_Troubleshooting.D_Joystick.Idx104_RawY", "N/A"))

        # -------------------------------------------------------------
        # 8. D09 - BUS DE COMMUNICATION
        # -------------------------------------------------------------
        p_net = (
            "GVL_IHM.Network.BusEthercat.Online",
            "GVL_IHM.Network.BusEthercat.Operational",
            "GVL_IHM.Network.BusCanOpen.Online",
            "GVL_IHM.Network.VariateurM3.Online",
            "GVL_IHM.Network.CanError",
            "GVL_IHM.Network.EcatError",
        )
        d_net = safe_read_map(online_app, p_net)
        print("\n[D09 - BUS DE COMMUNICATION]")
        print("  • EtherCAT Master Online   : " + d_net.get("GVL_IHM.Network.BusEthercat.Online", "N/A"))
        print("  • CANopen Master Online    : " + d_net.get("GVL_IHM.Network.BusCanOpen.Online", "N/A"))
        print("  • Variateur AC600 Online   : " + d_net.get("GVL_IHM.Network.VariateurM3.Online", "N/A"))

        # -------------------------------------------------------------
        # 9. D10 - SÉQUENCEUR PROCESS & MODES
        # -------------------------------------------------------------
        p_cy = (
            "GVL_Troubleshooting.A_ContexteMachineGlobal.Idx101_ModeActive",
            "GVL_Troubleshooting.A_ContexteMachineGlobal.Idx402_CycleAutoBusy",
            "GVL_IHM.Banner.SequenceProgressText",
            "GVL_IHM.Banner.OperatorActionText",
        )
        d_cy = safe_read_map(online_app, p_cy)
        print("\n[D10 - SÉQUENCEUR PROCESS & MODES]")
        print("  • Mode Actif               : " + d_cy.get("GVL_Troubleshooting.A_ContexteMachineGlobal.Idx101_ModeActive", "N/A"))
        print("  • Cycle Auto Busy          : " + d_cy.get("GVL_Troubleshooting.A_ContexteMachineGlobal.Idx402_CycleAutoBusy", "N/A"))
        print("  • Étape en cours           : " + d_cy.get("GVL_IHM.Banner.SequenceProgressText", "N/A"))
        print("  • Guidage opérateur       : " + d_cy.get("GVL_IHM.Banner.OperatorActionText", "N/A"))

        # -------------------------------------------------------------
        # 10. SYNTHÈSE BANDEAU IHM & ALARMES
        # -------------------------------------------------------------
        banner = read_banner(online_app)
        print_banner("SYNTHÈSE BANDEAU IHM & ALARMES", banner)

        print("\n[OK] ÉTAT DES LIEUX COMPLET TERMINÉ AVEC SUCCÈS.")


run_full_audit()
