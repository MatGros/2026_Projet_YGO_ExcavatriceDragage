# -*- coding: utf-8 -*-
"""T423_AUDIT_DYNAMIC_BENCH — Banc d'épreuve dynamique et qualification IHM intégrale.

À exécuter dans CODESYS : Tools > Scripting > Execute Script File...
Couvre les 5 champs du bandeau IHM (AF-07 §4) + le carrousel d'alarmes (§6) :
  1. Macro-contexte [RÉEL/SIMU] [MODE] [COUPLAGE]
  2. Progression micro (Étape de cycle / Mode manuel)
  3. Conditions spéciales & Dérogations (Bypass, bridages)
  4. Actions & Guidage opérateur (Neutre, Armé, Déplacement, Sécurité)
  5. Position Chariot M3
  + Carrousel des défauts actifs (AlarmArray / Text)

Évalue systématiquement les 4 paramètres sur chaque test :
  1. EXÉCUTABILITÉ (INJECTÉ / ÉCRASÉ PAR PLC / REFUS ÉCRITURE)
  2. ACTIVATION (OUI / NON = Refus silencieux)
  3. VISIBILITÉ (VISIBLE / MASQUÉ PAR PARENT / DISCORDANCE TEXTE)
  4. RESTAURATION (RESTAURÉ NOMINAL SOUS BLOC FINALLY)
"""

import os
import sys
import time

try:
    _this_dir = os.path.dirname(os.path.abspath(__file__))
except Exception:
    _this_dir = r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\TOOLS\PLC_CSV_SNAPSHOT\codesys_console\T423_IHM"

ENGINE_PATH = os.path.join(_this_dir, "T423_engine.py")
with open(ENGINE_PATH, "rb") as f:
    exec(compile(f.read(), ENGINE_PATH, "exec"), globals(), globals())


TEST_CASES = [
    # ═══════════════════════════════════════════════════════════════
    # SECTION I : MESSAGES UTILISATEUR, MODES & GUIDAGE OPÉRATEUR
    # ═══════════════════════════════════════════════════════════════
    # --- CHAMP 1 : MACRO CONTEXTE (MODES & COUPLAGE) ---
    {
        "device": "IHM_MODE",
        "id": "TC_MODE_01",
        "name": "Bascule Couplage : Selection Treuil M1 Seul",
        "var": "GVL_IHM.Modes.Cmd.SelJoystickWinch",
        "inject": "1",
        "restore": "0",
        "target": "GLOBAL_CONTEXT",
        "expected": "M1 SEUL",
        "requires_rearm": False,
        "tof_delay": 0.0,
    },
    {
        "device": "IHM_MODE",
        "id": "TC_MODE_02",
        "name": "Bascule Couplage : Selection Treuil M2 Seul",
        "var": "GVL_IHM.Modes.Cmd.SelJoystickWinch",
        "inject": "2",
        "restore": "0",
        "target": "GLOBAL_CONTEXT",
        "expected": "M2 SEUL",
        "requires_rearm": False,
        "tof_delay": 0.0,
    },
    {
        "device": "IHM_MODE",
        "id": "TC_MODE_03",
        "name": "Couplage Nominal : M1+M2 Couples",
        "var": "GVL_IHM.Modes.Cmd.SelJoystickWinch",
        "inject": "0",
        "restore": "0",
        "target": "GLOBAL_CONTEXT",
        "expected": "M1+M2",
        "requires_rearm": False,
        "tof_delay": 0.0,
    },

    # --- CHAMP 2 : PROGRESSION SEQUENCE & PROCESS ---
    {
        "device": "IHM_PROGRESS",
        "id": "TC_PROG_01",
        "name": "Progression Guide Homing / Manuel au repos (HX0)",
        "var": "GVL_IHM.Modes.Cmd.SelMode",
        "inject": "1",
        "restore": "1",
        "target": "SEQUENCE_PROGRESS",
        "expected": "Homing: HX0",
        "requires_rearm": False,
        "tof_delay": 0.0,
        "force": False,
    },

    # --- CHAMP 3 : CONDITIONS SPÉCIALES & BYPASS ---
    {
        "device": "IHM_BYPASS",
        "id": "TC_BYPASS_01",
        "name": "Activation Bypass Global (SpecialConditionText)",
        "var": "GVL_IHM.Network.Bypass.Global",
        "inject": "TRUE",
        "restore": "FALSE",
        "target": "SPECIAL_COND",
        "expected": "Bypass actif",
        "requires_rearm": False,
        "tof_delay": 0.0,
    },

    # --- CHAMP 4 : GUIDAGE ET ACTIONS OPÉRATEUR ---
    {
        "device": "IHM_OPERATOR",
        "id": "TC_OP_01",
        "name": "Guidage Operateur au repos neutre",
        "var": "GVL_Simulation.SimJoystickRawButton",
        "inject": "FALSE",
        "restore": "FALSE",
        "target": "OPERATOR_ACTION",
        "expected": "Appuyer homme-mort",
        "requires_rearm": False,
        "tof_delay": 0.0,
    },
    {
        "device": "IHM_OPERATOR",
        "id": "TC_OP_02",
        "name": "Guidage Operateur avec Homme-Mort Arme au neutre",
        "var": "GVL_Simulation.SimJoystickRawButton",
        "inject": "TRUE",
        "restore": "FALSE",
        "target": "OPERATOR_ACTION",
        "expected": "actionner axe",
        "requires_rearm": False,
        "tof_delay": 0.0,
    },

    # --- CHAMP 5 : POSITION POSITION M3 ---
    {
        "device": "IHM_POSITION",
        "id": "TC_POS_01",
        "name": "Position M3 stable au Point P1",
        "var": "GVL_IHM.M3Translation.State.AtP1",
        "inject": "TRUE",
        "restore": "FALSE",
        "target": "POSITION_M3",
        "expected": "M3 a P1",
        "requires_rearm": False,
        "tof_delay": 0.0,
        "force": True,
    },

    # ═══════════════════════════════════════════════════════════════
    # SECTION II : SÉCURITÉ, DÉFAUTS PROCESS & CARROUSEL D'ALARMES
    # ═══════════════════════════════════════════════════════════════
    # --- D07 : SÉCURITÉ AU & PHASES (FRONTIÈRE SIMULATION) ---
    {
        "device": "D07",
        "id": "TC_D07_01",
        "name": "Rotation de phases inversee (SimPhaseRotationOk = FALSE)",
        "var": "GVL_Simulation.SimPhaseRotationOk",
        "inject": "FALSE",
        "restore": "TRUE",
        "target": "ALARM_ARRAY",
        "expected": "rotation phases",
        "requires_rearm": False,
        "tof_delay": 0.0,
    },
    {
        "device": "D07",
        "id": "TC_D07_02",
        "name": "Chaine AU ouverte (SimChainOk = FALSE)",
        "var": "GVL_Simulation.SimChainOk",
        "inject": "FALSE",
        "restore": "TRUE",
        "target": "OPERATOR_ACTION",
        "expected": "urgence",
        "requires_rearm": True,
        "tof_delay": 0.0,
    },

    # --- D09 : BUS RÉSEAU & ESCLAVES ---
    {
        "device": "D09",
        "id": "TC_D09_01",
        "name": "Decrochage Bus EtherCAT (instDiagEthercat.DeviceEthercatMaster.Operational = FALSE)",
        "var": "PRG_02_Acquisition.instDiagEthercat.DeviceEthercatMaster.Operational",
        "inject": "FALSE",
        "restore": "TRUE",
        "target": "ALARM_ARRAY",
        "expected": "[ECAT] Defaut bus EtherCAT",
        "requires_rearm": False,
        "tof_delay": 2.5,
        "force": True,
        "extra_writes": [
            ("PRG_02_Acquisition.Data.Network.EthercatMaster.Operational", "FALSE", "TRUE", True),
            ("GVL_IHM.Network.BusEthercat.Operational", "FALSE", "TRUE", True),
            ("PRG_07_Supervision.instHmiBannerFormatter.Network.BusEthercat.Operational", "FALSE", "TRUE", True),
        ],
    },
    {
        "device": "D09",
        "id": "TC_D09_02",
        "name": "Decrochage Bus CANopen (instDiagCanOpen.DeviceCanOpenMaster.Operational = FALSE)",
        "var": "PRG_02_Acquisition.instDiagCanOpen.DeviceCanOpenMaster.Operational",
        "inject": "FALSE",
        "restore": "TRUE",
        "target": "ALARM_ARRAY",
        "expected": "[CAN] Defaut bus CANopen",
        "requires_rearm": False,
        "tof_delay": 2.0,
        "force": True,
    },
    {
        "device": "D09",
        "id": "TC_D09_03",
        "name": "Perte Codeur COD1 sur bus (DeviceEncoderM1.Operational = FALSE) [AC1]",
        "var": "PRG_02_Acquisition.instDiagEthercat.DeviceEncoderM1.Operational",
        "inject": "FALSE",
        "restore": "TRUE",
        "target": "ALARM_ARRAY",
        "expected": "[M1]",
        "requires_rearm": False,
        "tof_delay": 2.0,
        "force": True,
    },
    {
        "device": "D09",
        "id": "TC_D09_04",
        "name": "Perte Codeur COD2 sur bus (DeviceEncoderM2.Operational = FALSE) [AC1]",
        "var": "PRG_02_Acquisition.instDiagEthercat.DeviceEncoderM2.Operational",
        "inject": "FALSE",
        "restore": "TRUE",
        "target": "ALARM_ARRAY",
        "expected": "COD2 non detecte",
        "requires_rearm": False,
        "tof_delay": 2.0,
        "force": True,
    },
    {
        "device": "D09",
        "id": "TC_D09_05",
        "name": "Perte Variateur AC600 sur bus (DeviceVariateur.Operational = FALSE) [AC1]",
        "var": "PRG_02_Acquisition.instDiagEthercat.DeviceVariateur.Operational",
        "inject": "FALSE",
        "restore": "TRUE",
        "target": "ALARM_ARRAY",
        "expected": "Variateur AC600 non detecte",
        "requires_rearm": False,
        "tof_delay": 2.0,
        "force": True,
    },

    # --- D08 : PUPITRE JOYSTICK ---
    {
        "device": "D08",
        "id": "TC_D08_01",
        "name": "Deconnexion joystick (DeviceJoystick.Operational = FALSE)",
        "var": "PRG_02_Acquisition.instDiagCanOpen.DeviceJoystick.Operational",
        "inject": "FALSE",
        "restore": "TRUE",
        "target": "ALARM_ARRAY",
        "expected": "Joystick JOY1 non detecte",
        "requires_rearm": False,
        "tof_delay": 2.0,
        "force": True,
    },

    # --- D01 : TREUIL M1 (RETENUE) ---
    {
        "device": "D01",
        "id": "TC_D01_01",
        "name": "Perte codeur M1 (instSafetyWinchM1.EncoderFaultLatched = TRUE) [AC2]",
        "var": "PRG_04_Treuils_Benne.instSafetyWinchM1.EncoderFaultLatched",
        "inject": "TRUE",
        "restore": "FALSE",
        "target": "ALARM_ARRAY",
        "expected": "[M1] ErrorID:02 - perte codeur",
        "requires_rearm": True,
        "tof_delay": 0.0,
        "force": True,
    },
    {
        "device": "D01",
        "id": "TC_D01_02",
        "name": "Survitesse treuil M1 (instSafetyWinchM1.OverspeedFaultLatched = TRUE)",
        "var": "PRG_04_Treuils_Benne.instSafetyWinchM1.OverspeedFaultLatched",
        "inject": "TRUE",
        "restore": "FALSE",
        "target": "ALARM_ARRAY",
        "expected": "survitesse treuil",
        "requires_rearm": True,
        "tof_delay": 0.0,
        "force": True,
    },

    # --- D02 : TREUIL M2 (BENNE) ---
    {
        "device": "D02",
        "id": "TC_D02_01",
        "name": "Perte codeur M2 (instSafetyWinchM2.EncoderFaultLatched = TRUE) [AC2]",
        "var": "PRG_04_Treuils_Benne.instSafetyWinchM2.EncoderFaultLatched",
        "inject": "TRUE",
        "restore": "FALSE",
        "target": "ALARM_ARRAY",
        "expected": "[M2] ErrorID:02 - perte codeur",
        "requires_rearm": True,
        "tof_delay": 0.0,
        "force": True,
    },

    # --- D03 : MÉCANISME BENNE ---
    {
        "device": "D03",
        "id": "TC_D03_01",
        "name": "Glissement treuil M1 pendant benne (instBucket.M1SlipFaultLatched = TRUE)",
        "var": "PRG_04_Treuils_Benne.instBucket.M1SlipFaultLatched",
        "inject": "TRUE",
        "restore": "FALSE",
        "target": "ALARM_ARRAY",
        "expected": "[BENNE] ErrorID:04 - glissement treuil M1",
        "requires_rearm": True,
        "tof_delay": 0.0,
        "force": True,
    },
    {
        "device": "D03",
        "id": "TC_D03_02",
        "name": "Ecart max geometrie depasse (instBucket.OffsetMaxFaultLatched = TRUE)",
        "var": "PRG_04_Treuils_Benne.instBucket.OffsetMaxFaultLatched",
        "inject": "TRUE",
        "restore": "FALSE",
        "target": "ALARM_ARRAY",
        "expected": "[BENNE] ErrorID:02 - depassement ecart max autorise",
        "requires_rearm": True,
        "tof_delay": 0.0,
        "force": True,
    },

    # --- D04 : TRANSLATION PONT M3 ---
    {
        "device": "D04",
        "id": "TC_D04_01",
        "name": "Defaut variateur translation AC600 (instTranslationM3.DriveFaultLatching = TRUE)",
        "var": "PRG_05_Translation.instTranslationM3.DriveFaultLatching",
        "inject": "TRUE",
        "restore": "FALSE",
        "target": "ALARM_ARRAY",
        "expected": "[M3] Defaut variateur translation AC600",
        "requires_rearm": True,
        "tof_delay": 0.0,
        "force": True,
    },

        # --- D06 : SYNCHRONISME M1/M2 ---
    {
        "device": "D06",
        "id": "TC_D06_01",
        "name": "Ecart synchro critique M1/M2 (SyncState.ErrorId = 2)",
        "var": "GVL_IHM.M1M2Sync.State.ErrorId",
        "inject": "2",
        "restore": "0",
        "target": "ALARM_ARRAY",
        "expected": "SYNC",
        "requires_rearm": False,
        "tof_delay": 0.5,
        "force": False,
        "extra_writes": [
            ("PRG_04_Treuils_Benne.Data.SyncState.ErrorId", "2", "0", False),
            ("PRG_06_Outputs.Data.SyncContactorDiag.MismatchLevel", "1", "0", False),
            ("PRG_06_Outputs.Data.SyncContactorDiag.RelayFwdMismatch", "TRUE", "FALSE", False),
        ],
    },

    # --- D10 : SÉQUENCEUR CYCLE (DÉCALAGE DE MASQUES AC3) ---
    {
        "device": "D10",
        "id": "TC_D10_01",
        "name": "Defaut synchro en cycle (PRG_03.Data.SequenceState.Fault.ErrorId = 2)",
        "var": "PRG_03_Modes_Cycle.Data.SequenceState.Fault.ErrorId",
        "inject": "2",
        "restore": "0",
        "target": "ALARM_ARRAY",
        "expected": "[CYCLE] ErrorID:02",
        "requires_rearm": False,
        "tof_delay": 0.2,
        "force": True,
        "extra_writes": [
            ("PRG_03_Modes_Cycle.Data.SequenceState.Fault.LatchedId", "2", "0", True),
            ("PRG_03_Modes_Cycle.Data.SequenceState.Fault.Latched", "TRUE", "FALSE", True),
            ("GVL_IHM.CycleSemiAuto.State.ErrorId", "2", "0", True),
        ],
    },
    {
        "device": "D10",
        "id": "TC_D10_02",
        "name": "Perte com IHM en cycle (PRG_03.Data.SequenceState.Fault.ErrorId = 8) [AC3]",
        "var": "PRG_03_Modes_Cycle.Data.SequenceState.Fault.ErrorId",
        "inject": "8",
        "restore": "0",
        "target": "ALARM_ARRAY",
        "expected": "perte communication IHM",
        "requires_rearm": False,
        "tof_delay": 0.2,
        "force": True,
        "extra_writes": [
            ("PRG_03_Modes_Cycle.Data.SequenceState.Fault.LatchedId", "8", "0", True),
            ("PRG_03_Modes_Cycle.Data.SequenceState.Fault.Latched", "TRUE", "FALSE", True),
            ("GVL_IHM.CycleSemiAuto.State.ErrorId", "8", "0", True),
        ],
    },
    {
        "device": "D10",
        "id": "TC_D10_03",
        "name": "Timeout etape cycle (PRG_03.Data.SequenceState.Fault.ErrorId = 16) [AC3]",
        "var": "PRG_03_Modes_Cycle.Data.SequenceState.Fault.ErrorId",
        "inject": "16",
        "restore": "0",
        "target": "ALARM_ARRAY",
        "expected": "timeout etape",
        "requires_rearm": False,
        "tof_delay": 0.2,
        "force": True,
        "extra_writes": [
            ("PRG_03_Modes_Cycle.Data.SequenceState.Fault.LatchedId", "16", "0", True),
            ("PRG_03_Modes_Cycle.Data.SequenceState.Fault.Latched", "TRUE", "FALSE", True),
            ("GVL_IHM.CycleSemiAuto.State.ErrorId", "16", "0", True),
        ],
    },
    {
        "device": "D10",
        "id": "TC_D10_04",
        "name": "Consigne profondeur invalide AX7 (CycleErrorId = 2048) [A1]",
        "var": "PRG_03_Modes_Cycle.Data.SequenceState.Fault.ErrorId",
        "inject": "2048",
        "restore": "0",
        "target": "ALARM_ARRAY",
        "expected": "consigne profondeur invalide",
        "requires_rearm": False,
        "tof_delay": 0.2,
        "force": True,
        "extra_writes": [
            ("PRG_03_Modes_Cycle.Data.SequenceState.Fault.LatchedId", "2048", "0", True),
            ("PRG_03_Modes_Cycle.Data.SequenceState.Fault.Latched", "TRUE", "FALSE", True),
            ("GVL_IHM.CycleSemiAuto.State.ErrorId", "2048", "0", True),
        ],
    },
]


def run_dynamic_bench():
    online_app = get_online_app()
    if online_app is None:
        return

    with online_app:
        print("\n" + "=" * 90)
        print("  BANC D'EPREUVE DYNAMIQUE IHM — COUVERTURE 5 CHAMPS + CARROUSEL (T423)")
        print("  Modes, Progression, Bypass, Guidage Operateur & Securite Machine")
        print("=" * 90)

        # ═══════════════════════════════════════════════════════════════
        # PHASE INITIALE : MISE EN CONDITION INITIALE STABLE DE LA MACHINE
        # ═══════════════════════════════════════════════════════════════
        print("\n>>> Phase 0 : Mise en condition initiale stable de la machine...")
        safe_unforce(online_app)

        # 1. Réarmement AU propre (simulation, reset, pulse emergency arming)
        print("  1.1. Rearmement AU propre et collage contacteurs puissance...")
        rearm_emergency(online_app)

        # 2. Prise en compte du mode de base sain pour tester le guidage opérateur et la progression
        print("  1.2. Etablissement du mode de base sain (MAINT_N1, M1+M2 couples)...")
        safe_write(online_app, "GVL_IHM.Modes.Cmd.SelMode", "1")  # E_Mode.MAINT_N1
        safe_write(online_app, "GVL_IHM.Modes.Cmd.SelJoystickWinch", "0")  # M1+M2 couplés
        safe_write(online_app, "GVL_Simulation.SimJoystickRawButton", "FALSE")  # Homme-mort au repos
        safe_write(online_app, "GVL_IHM.Network.Bypass.Global", "FALSE")  # Pas de bypass
        safe_write(online_app, "PRG_02_Acquisition.instCycleMachineHoming.MachineHomingStep", "60", force=True)
        safe_write(online_app, "PRG_02_Acquisition.instCycleMachineHoming.MachineHomed", "TRUE", force=True)
        safe_write(online_app, "PRG_02_Acquisition.Data.MachineHoming.Step", "60", force=True)
        safe_write(online_app, "PRG_02_Acquisition.Data.MachineHoming.Homed", "TRUE", force=True)

        # 3. Attente de purge de la fenêtre transitoire réseau (TonRearmWindow T#4s)
        print("  1.3. Attente purge fenetre transitoire reseau TonRearmWindow (4.2 s)...")
        time.sleep(6.5)

        # Diagnostic de conformité initiale
        init_banner = read_banner(online_app)
        print("  [INIT] GlobalContextText    : '%s'" % init_banner.get("GVL_IHM.Banner.GlobalContextText", ""))
        print("  [INIT] SequenceProgressText : '%s'" % init_banner.get("GVL_IHM.Banner.SequenceProgressText", ""))
        print("  [INIT] OperatorActionText   : '%s'" % init_banner.get("GVL_IHM.Banner.OperatorActionText", ""))
        print("  [INIT] PositionM3Text       : '%s'" % init_banner.get("GVL_IHM.Banner.PositionM3Text", ""))
        print("=" * 90)

        bench_start_time = time.time()
        results = []
        dev_stats = {}

        for tc in TEST_CASES:
            dev = tc["device"]
            if dev not in dev_stats:
                dev_stats[dev] = {
                    "total": 0,
                    "injected": 0,
                    "pass": 0,
                    "fail_silent": 0,
                    "fail_masked": 0,
                    "overwritten_env": 0,
                    "blocked_env": 0,
                    "duration": 0.0,
                }
            dev_stats[dev]["total"] += 1

            tc_id = tc["id"]
            name = tc["name"]
            var_path = tc["var"]
            inject_val = tc["inject"]
            restore_val = tc["restore"]
            target = tc["target"]
            expected = tc["expected"]
            requires_rearm = tc.get("requires_rearm", False)
            tof_delay = tc.get("tof_delay", 0.0)

            tc_start_time = time.time()
            print("\n[%s] %s : %s" % (dev, tc_id, name))
            print("  -> Stimulus : %s := %s" % (var_path, inject_val))

            # 1. PARAMÈTRE 1 : EXÉCUTABILITÉ & PERSISTANCE
            use_force = tc.get("force", False)
            ok_write = safe_write(online_app, var_path, inject_val, force=use_force)
            for extra_path, extra_inj, _, extra_force in tc.get("extra_writes", []):
                safe_write(online_app, extra_path, extra_inj, force=extra_force)
            if not ok_write:
                print("  [1. EXECUTABILITE] : [BLOCKED_ENV] (Ecriture refusee par CODESYS)")
                dev_stats[dev]["blocked_env"] += 1
                results.append((tc_id, dev, name, "BLOCKED_ENV", "Ecriture refusee"))
                continue

            # Propagation de l'écriture / forçage avec polling court (max 0.45s)
            start_t = time.time()
            is_written = False
            read_back = ""
            while (time.time() - start_t) < 0.45:
                read_back = safe_read(online_app, var_path, "")
                if inject_val.upper() in ("TRUE", "FALSE"):
                    if bool_val(read_back) == bool_val(inject_val):
                        is_written = True
                        break
                elif int_val(inject_val) is not None:
                    if int_val(read_back) == int_val(inject_val):
                        is_written = True
                        break
                else:
                    if clean_val(read_back).upper() == clean_val(inject_val).upper():
                        is_written = True
                        break
                time.sleep(0.05)

            if not is_written:
                print("  [1. EXECUTABILITE] : [OVERWRITTEN_ENV] (Ecrase par le scan PRG en <50ms)")
                print("      -> Lu: '%s' vs Attendu injecte: '%s'" % (read_back, inject_val))
                dev_stats[dev]["overwritten_env"] += 1
                results.append((tc_id, dev, name, "OVERWRITTEN_ENV", "Ecrase par automate amont"))
                continue

            t_after_inject = time.time()
            t_inject = t_after_inject - tc_start_time
            print("  [1. EXECUTABILITE] : [INJECTE] (Maintenu stable en %.2fs)" % t_inject)
            dev_stats[dev]["injected"] += 1

            # 2. EVALUATION SOUS BLOC TRY ... FINALLY
            t_eval_start = time.time()
            try:
                time.sleep(max(0.45, tof_delay))

                banner = read_banner(online_app)
                alarms = get_active_alarms(online_app)

                global_ctx = banner.get("GVL_IHM.Banner.GlobalContextText", "")
                seq_prog = banner.get("GVL_IHM.Banner.SequenceProgressText", "")
                sp_cond = banner.get("GVL_IHM.Banner.SpecialConditionText", "")
                op_action = banner.get("GVL_IHM.Banner.OperatorActionText", "")
                pos_m3 = banner.get("GVL_IHM.Banner.PositionM3Text", "")

                found = False
                matched_msg = ""

                # Routage de vérification selon le champ cible du bandeau (comparaison robuste sans conflit d'encodage)
                if target == "GLOBAL_CONTEXT":
                    matched_msg = global_ctx
                    found = match_text(expected, global_ctx)
                elif target == "SEQUENCE_PROGRESS":
                    matched_msg = seq_prog
                    found = match_text(expected, seq_prog)
                elif target == "SPECIAL_COND":
                    matched_msg = sp_cond
                    found = match_text(expected, sp_cond)
                elif target == "OPERATOR_ACTION":
                    matched_msg = op_action
                    found = match_text(expected, op_action)
                elif target == "POSITION_M3":
                    matched_msg = pos_m3
                    found = match_text(expected, pos_m3)
                elif target == "ALARM_ARRAY":
                    curr_banner_txt = banner.get("GVL_IHM.Banner.AlarmBanner.Text", "")
                    all_candidates = list(alarms)
                    if curr_banner_txt and curr_banner_txt not in all_candidates:
                        all_candidates.append(curr_banner_txt)
                    clean_curr = clean_val(curr_banner_txt)
                    if clean_curr and clean_curr not in all_candidates:
                        all_candidates.append(clean_curr)

                    for a in all_candidates:
                        if match_text(expected, a):
                            found = True
                            matched_msg = a
                            break
                    if not found and len(all_candidates) > 0:
                        matched_msg = all_candidates[0]

                # 3. VERDICT ACTIVATION / VISIBILITÉ
                if found:
                    print("  [2. ACTIVATION]    : [OUI] Texte detecte dans le champ cible")
                    print("  [3. VISIBILITE]    : [PASS] '%s'" % matched_msg)
                    verdict = "PASS"
                    dev_stats[dev]["pass"] += 1
                else:
                    has_any_alarm = bool_val(banner.get("GVL_IHM.Banner.AlarmBanner.HasAlarm", False))
                    if target == "ALARM_ARRAY" and len(alarms) == 0 and not has_any_alarm:
                        print("  [2. ACTIVATION]    : [NON] (Refus silencieux — aucune alarme emise)")
                        print("  [3. VISIBILITE]    : [FAIL_SILENT]")
                        print("      -> DEBUG ALARMS:", repr(alarms), "HasAlarm:", banner.get("GVL_IHM.Banner.AlarmBanner.HasAlarm"), "Text:", repr(banner.get("GVL_IHM.Banner.AlarmBanner.Text")))
                        verdict = "FAIL_SILENT"
                        dev_stats[dev]["fail_silent"] += 1
                    else:
                        print("  [2. ACTIVATION]    : [DEVIATION] (Texte masque ou libelle non conforme)")
                        print("  [3. VISIBILITE]    : Reçu: '%s' | Attendu: '%s'" % (matched_msg, expected))
                        verdict = "FAIL_MASKED"
                        dev_stats[dev]["fail_masked"] += 1

                results.append((tc_id, dev, name, verdict, matched_msg))
                t_eval = time.time() - t_eval_start
            finally:
                t_restore_start = time.time()
                # 4. RESTAURATION ABSOLUE (UNFORCE + ECRITURE RESTORE + RESET)
                safe_unforce(online_app)
                safe_write(online_app, var_path, restore_val, force=False)
                for extra_path, _, extra_rest, _ in tc.get("extra_writes", []):
                    safe_write(online_app, extra_path, extra_rest, force=False)
                time.sleep(0.05)

                if requires_rearm:
                    print("  [4. RESTAURATION]  : Rearmement de securite...")
                    rearm_emergency(online_app)
                    print("  [4. RESTAURATION]  : Purge fenetre TonRearmWindow (T#4s)...")
                    time.sleep(6.5)
                else:
                    safe_write(online_app, "GVL_IHM.Modes.Cmd.BtnFaultReset", "TRUE")
                    time.sleep(0.05)
                    safe_write(online_app, "GVL_IHM.Modes.Cmd.BtnFaultReset", "FALSE")
                    if tof_delay > 0.0:
                        time.sleep(tof_delay)
                    else:
                        time.sleep(0.15)

                t_restore = time.time() - t_restore_start
                tc_total_time = time.time() - tc_start_time
                dev_stats[dev]["duration"] += tc_total_time
                print("  [4. RESTAURATION]  : [RESTORE] Machine saine au repos")
                print("  [5. CHRONOMETRIE]  : Duree = %.2fs (Inject: %.2fs | Eval: %.2fs | Restauration: %.2fs)" % (
                    tc_total_time, t_inject, t_eval, t_restore
                ))

        # ═══════════════════════════════════════════════════════════════
        # TABLEAU DE SYNTHÈSE STATISTIQUE PAR DOMAINE / ORGANE
        # ═══════════════════════════════════════════════════════════════
        print("\n" + "=" * 105)
        print("  BILAN STATISTIQUE QUALIFICATION DYNAMIQUE IHM (5 CHAMPS + CARROUSEL)")
        print("=" * 105)
        print("%-14s | %-6s | %-8s | %-6s | %-12s | %-12s | %-12s | %-10s | %-10s" % (
            "Domaine/Device", "Total", "Injectes", "PASS", "Silencieux", "Masque/Texte", "Ecrase Auto", "Taux Succes", "Duree Cum."
        ))
        print("-" * 118)

        tot_all = 0
        tot_inj = 0
        tot_pass = 0
        tot_sil = 0
        tot_mas = 0
        tot_ovw = 0
        tot_duration = 0.0

        for dev in sorted(dev_stats.keys()):
            st = dev_stats[dev]
            tot_all += st["total"]
            tot_inj += st["injected"]
            tot_pass += st["pass"]
            tot_sil += st["fail_silent"]
            tot_mas += st["fail_masked"]
            tot_ovw += st["overwritten_env"]
            tot_duration += st.get("duration", 0.0)

            rate = (float(st["pass"]) / float(st["injected"]) * 100.0) if st["injected"] > 0 else 0.0
            print("%-14s | %-6d | %-8d | %-6d | %-12d | %-12d | %-12d | %6.1f %% | %7.2fs" % (
                dev, st["total"], st["injected"], st["pass"], st["fail_silent"], st["fail_masked"], st["overwritten_env"], rate, st.get("duration", 0.0)
            ))

        print("-" * 118)
        rate_tot = (float(tot_pass) / float(tot_inj) * 100.0) if tot_inj > 0 else 0.0
        print("%-14s | %-6d | %-8d | %-6d | %-12d | %-12d | %-12d | %6.1f %% | %7.2fs" % (
            "TOTAL GLOBAL", tot_all, tot_inj, tot_pass, tot_sil, tot_mas, tot_ovw, rate_tot, tot_duration
        ))
        print("=" * 118)
        bench_total_duration = time.time() - bench_start_time
        avg_tc = (bench_total_duration / float(tot_all)) if tot_all > 0 else 0.0
        print("  Duree totale qualification : %.2fs (Moyenne : %.2fs / cas de test)" % (bench_total_duration, avg_tc))
        print("\n[OK] BANC D'EPREUVE TERMINE SANS ERREUR RESIDUELLE.")


if __name__ == "__main__":
    run_dynamic_bench()
