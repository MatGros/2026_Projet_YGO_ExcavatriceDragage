(* ═══════════════════════════════════════════════════════════════
   📤 PRG_10_Outputs — Écriture des SORTIES physiques (PROGRAMME)
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF_Partie-06_IO_Conditioning_v1.6.md §5
   ⚙️ Exécuté par la tâche PLC en position 10.
   ✅ Reçoit ses commandes en VAR_INPUT (écrites par le reste du code).
   🔧 REX 2026-07-19 : suppression définitive du mode IHM_MANU (override direct des sorties,
      mise en service urgence 2026-07-09) — voir ARCHIVES/Doc/IHM_MANU_Journal_Modifications.md pour
      l'historique complet. Le pilotage manuel passe désormais EXCLUSIVEMENT par MAINT_N1/N2
      + joystick homme-mort (PRG_06_WinchControl/PRG_07_TranslationControl), sous supervision
      réelle des sécurités métier (SafeStop/ForbidAscent/ForbidDescent/PowerCutOff toujours
      actifs, plus aucun bypass conditionnel).
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_10_Outputs
VAR_INPUT
    // ── 🪝 TREUIL M1 ─────────────────────────────────────────────────────────────────────
    M1RelayFwd        : BOOL;  // ⬆️ Relais MONTÉE M1 (NO) : TRUE=bobine ON, moteur monte | FALSE=arrêt ✅
    M1RelayRev        : BOOL;  // ⬇️ Relais DESCENTE M1 (NO) : TRUE=bobine ON, moteur descend | FALSE=arrêt ✅
    M1SpeedContactor1 : BOOL;  // 🐢 Contacteur vitesse 1 M1 — palier 1 lent (résistance max)
    M1SpeedContactor2 : BOOL;  // 🐇 Contacteur vitesse 2 M1 — palier 2
    M1SpeedContactor3 : BOOL;  // 🐇🐇 Contacteur vitesse 3 M1 — palier 3
    M1SpeedContactor4 : BOOL;  // 🚀 Contacteur vitesse 4 M1 — palier 4 pleine puissance
    M1BrakeCmd        : BOOL;  // 🔓 Frein M1 ⚠️INVERSÉ : TRUE=desserré/mouvement | FALSE=SERRÉ sécurité ✅

    // ── 🪝 TREUIL M2 (même logique que M1) ──────────────────────────────────────────────
    M2RelayFwd        : BOOL;  // ⬆️ Relais MONTÉE M2 (NO) : TRUE=bobine ON, moteur monte | FALSE=arrêt ✅
    M2RelayRev        : BOOL;  // ⬇️ Relais DESCENTE M2 (NO) : TRUE=bobine ON, moteur descend | FALSE=arrêt ✅
    M2SpeedContactor1 : BOOL;  // 🐢 Contacteur vitesse 1 M2 — palier 1 lent
    M2SpeedContactor2 : BOOL;  // 🐇 Contacteur vitesse 2 M2 — palier 2
    M2SpeedContactor3 : BOOL;  // 🐇🐇 Contacteur vitesse 3 M2 — palier 3
    M2SpeedContactor4 : BOOL;  // 🚀 Contacteur vitesse 4 M2 — palier 4 pleine puissance
    M2BrakeCmd        : BOOL;  // 🔓 Frein M2 ⚠️INVERSÉ : TRUE=desserré/mouvement | FALSE=SERRÉ sécurité ✅

    // ── ↔️ TRANSLATION M3 (sens/vitesse via variateur EtherCAT, TOR=frein uniquement) ────────
    TranslationBrakeCmd   : BOOL;  // 🔓 Frein M3 ⚠️INVERSÉ : TRUE=desserré/mouvement | FALSE=SERRÉ sécurité ✅
    KoboldContactorCmd    : BOOL;  // 🪨 Commande contacteur puissance Kobold
END_VAR
VAR_OUTPUT
    // 🔧 REX 2026-07-07 — état séquence réarmement AU, exposé pour affichage IHM (PRG_09_Supervision)
    EmergencyArmingPulseActive   : BOOL; // Pulse 1s en cours
    EmergencyArmingLockoutActive: BOOL; // Verrouillage 5s après pulse (mécanisme à ressort)
    ArmingSeqStep                : INT;  // 0=IDLE,1=TestA,2=RestoreA,3=TestB,4=RestoreB,5=Pulse,6=Confirm
    RedundancyTestFailed         : BOOL; // Canal A ou B non fonctionnel détecté à l'auto-test — bloque le réarmement
    EmergencyArmingFailed        : BOOL; // Impulsion envoyée mais contacteur puissance jamais confirmé
END_VAR
VAR
    // Instances de sortie
    instM1RelayFwd        : FB_Output;
    instM1RelayRev        : FB_Output;
    instM1SpeedContactor1 : FB_Output;
    instM1SpeedContactor2 : FB_Output;
    instM1SpeedContactor3 : FB_Output;
    instM1SpeedContactor4 : FB_Output;
    instM1BrakeCmd        : FB_Output;

    instM2RelayFwd        : FB_Output;
    instM2RelayRev        : FB_Output;
    instM2SpeedContactor1 : FB_Output;
    instM2SpeedContactor2 : FB_Output;
    instM2SpeedContactor3 : FB_Output;
    instM2SpeedContactor4 : FB_Output;
    instM2BrakeCmd        : FB_Output;

    instTranslationBrakeCmd   : FB_Output;
    instSafetyEmergencyManagement  : FB_Safety_EmergencyManagement;
    PowerCutOffReq            : BOOL;
END_VAR

// === IMPLEMENTATION (corps du PROGRAM PRG_10_Outputs) ===

// 🪝 ─── WINCH M1 — lit les VAR_INPUT de PRG_10_Outputs, écrit les I/O réels ────
instM1RelayFwd(Command := M1RelayFwd);
M1_RelayFwd_DQ := instM1RelayFwd.State;

instM1RelayRev(Command := M1RelayRev);
M1_RelayRev_DQ := instM1RelayRev.State;

instM1SpeedContactor1(Command := M1SpeedContactor1);
M1_SpeedContactor_1_DQ := instM1SpeedContactor1.State;

instM1SpeedContactor2(Command := M1SpeedContactor2);
M1_SpeedContactor_2_DQ := instM1SpeedContactor2.State;

instM1SpeedContactor3(Command := M1SpeedContactor3);
M1_SpeedContactor_3_DQ := instM1SpeedContactor3.State;

instM1SpeedContactor4(Command := M1SpeedContactor4);
M1_SpeedContactor_4_DQ := instM1SpeedContactor4.State;

instM1BrakeCmd(Command := M1BrakeCmd);
M1_BrakeCmd_RQ := instM1BrakeCmd.State;

// 🪝 ─── WINCH M2 ──────────────────────────────────────────────────────────
instM2RelayFwd(Command := M2RelayFwd);
M2_RelayFwd_DQ := instM2RelayFwd.State;

instM2RelayRev(Command := M2RelayRev);
M2_RelayRev_DQ := instM2RelayRev.State;

instM2SpeedContactor1(Command := M2SpeedContactor1);
M2_SpeedContactor_1_DQ := instM2SpeedContactor1.State;

instM2SpeedContactor2(Command := M2SpeedContactor2);
M2_SpeedContactor_2_DQ := instM2SpeedContactor2.State;

instM2SpeedContactor3(Command := M2SpeedContactor3);
M2_SpeedContactor_3_DQ := instM2SpeedContactor3.State;

instM2SpeedContactor4(Command := M2SpeedContactor4);
M2_SpeedContactor_4_DQ := instM2SpeedContactor4.State;

instM2BrakeCmd(Command := M2BrakeCmd);
M2_BrakeCmd_RQ := instM2BrakeCmd.State;

// ↔️ ─── TRANSLATION M3 ────────────────────────────────────────────────────────
instTranslationBrakeCmd(Command := TranslationBrakeCmd);
M3_BrakeCmd_RQ := instTranslationBrakeCmd.State;

// 🪨 Adresse terrain : KoboldContactor_DQ = %QX0.6.
// Coupure prioritaire si la puissance ou la chaîne AU n'est plus validée.
KoboldContactor_DQ := KoboldContactorCmd
                      AND PRG_00_Inputs.EmergencyStopOk
                      AND PRG_00_Inputs.EmergencyChain;

// ── Translation M3 — variateur EtherCAT AC600, mot de commande direct (PAS de relais) ──
M3_CommandWord         := PRG_07_TranslationControl.instTranslationM3.DriveControlWord;
M3_SetpointFrequencyHz := REAL_TO_UINT(PRG_07_TranslationControl.instTranslationM3.DriveFreqRefHz * 100.0);
// 🔧 DriveActualFreqHz / DriveCommReady / DrivePowerReady : écrits une seule fois, en
// PRG_09_Supervision (GVL_IHM.TranslationM3), valables dans tous les modes.

// Relais de direction M3 obsolètes forcés à FALSE
M3_RelayFwd_DQ := FALSE;
M3_RelayRev_DQ := FALSE;

// ─── 🧨 COUPURE PUISSANCE AMONT REDONDANTE (Série physique, commande parallèle) ────────
// 🔧 REX 2026-07-19 : suppression IHM_MANU — plus de bypass conditionnel, PowerCutOffReq
// reflète TOUJOURS directement les 3 blocs safety métier, quel que soit le mode.
PowerCutOffReq := PRG_03_Safety.instSafetyWinchM1.PowerCutOff
                  OR PRG_03_Safety.instSafetyWinchM2.PowerCutOff
                  OR PRG_03_Safety.instSafetyTranslationM3.PowerCutOff;

// Appel du bloc Safety global pour la boucle d'urgence
instSafetyEmergencyManagement(
    Enable := TRUE,
    Reset := PRG_09_Supervision.FaultMachineReset_IHM,
    ArmRequest := GVL_IHM.Modes.Cmd.BtnEmergencyArming,
    EmergencyChain := PRG_00_Inputs.EmergencyChain,
    EmergencyStopOk := PRG_00_Inputs.EmergencyStopOk,
    PowerCutOffRequest := PowerCutOffReq,
    BtnEmergencyCutOff := GVL_IHM.Modes.Cmd.BtnEmergencyCutOff
);

// Affectation des sorties physiques et logiques de coupure/réarmement
PowerCutOff_A_RQ := instSafetyEmergencyManagement.PowerCutOff_A_RQ;
PowerCutOff_B_RQ := instSafetyEmergencyManagement.PowerCutOff_B_RQ;
EmergencyArming_RQ := instSafetyEmergencyManagement.EmergencyArming_RQ;

// Copie des états de diagnostic vers la supervision IHM
EmergencyArmingPulseActive   := instSafetyEmergencyManagement.EmergencyArming_RQ;
EmergencyArmingLockoutActive := instSafetyEmergencyManagement.EmergencyArmingLockoutActive;
ArmingSeqStep                := instSafetyEmergencyManagement.ArmingSeqStep;
RedundancyTestFailed         := instSafetyEmergencyManagement.RedundancyTestFailed;
EmergencyArmingFailed        := instSafetyEmergencyManagement.EmergencyArmingFailed;
