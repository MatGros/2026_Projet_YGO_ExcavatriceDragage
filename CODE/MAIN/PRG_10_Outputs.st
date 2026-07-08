(* ═══════════════════════════════════════════════════════════════
   📤 PRG_10_Outputs — Écriture des SORTIES physiques (PROGRAMME)
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF_Partie6_IO_Conditioning_v1.2.md §5
   ⚙️ Exécuté par la tâche PLC en position 10.
   ✅ Reçoit ses commandes en VAR_INPUT (écrites par le reste du code).
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

    // ── ↔️ CHARIOT M3 (sens/vitesse via variateur EtherCAT, TOR=frein uniquement) ────────
    ChariotBrakeCmd   : BOOL;  // 🔓 Frein M3 ⚠️INVERSÉ : TRUE=desserré/mouvement | FALSE=SERRÉ sécurité ✅
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

    instChariotBrakeCmd   : FB_Output;

    // 🔧 REX 2026-07-07 — séquence réarmement AU + auto-test redondance A/B (voir §🚨 en bas de fichier)
    ArmReqEdge            : R_TRIG;
    ResetEdge             : R_TRIG;
    ForceTestA            : BOOL; // force PowerCutOff_A_RQ bas pendant l'auto-test canal A
    ForceTestB            : BOOL; // force PowerCutOff_B_RQ bas pendant l'auto-test canal B
    TonTestA              : TON;  // 200ms — coupe A seul, vérifie EmergencyChain tombe
    TonRestoreA           : TON;  // 200ms — restaure A, attend le retour de la boucle
    TonTestB              : TON;  // 200ms — coupe B seul, vérifie EmergencyChain tombe
    TonRestoreB           : TON;  // 200ms — restaure B, attend le retour de la boucle
    TonArmingPulse        : TON;  // 1s — durée de l'impulsion réarmement (mécanisme à ressort)
    TonArmingConfirm      : TON;  // 2s — attente confirmation contacteur après le pulse
    TonArmingLockout      : TON;  // 5s — verrouillage avant nouvelle tentative possible
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

// ↔️ ─── CHARIOT M3 ────────────────────────────────────────────────────────
instChariotBrakeCmd(Command := ChariotBrakeCmd);
M3_BrakeCmd_RQ := instChariotBrakeCmd.State;


// ─── 🧨 COUPURE PUISSANCE AMONT REDONDANTE (Série physique, commande parallèle) ────────
// 🔴🔧 REX 2026-07-07 : ARCHITECTURE À COMMANDE MAINTENUE (fail-safe) — retour terrain.
// PowerCutOff_A_RQ/B_RQ doivent être MAINTENUS à TRUE tant que tout va bien ; le circuit AU
// s'ouvre (coupe le contacteur de puissance) dès que le PLC ARRÊTE de les maintenir — que ce
// soit volontairement (défaut Méca A/B/C détecté) OU accidentellement (PLC tombe/coupure
// automate). Polarité INVERSÉE par rapport à la 1ère version (qui mettait TRUE = "coupe",
// erreur de conception : en cas de défaut réel, ça aurait MAINTENU la puissance au lieu de
// la couper — pire cas de figure).
// 🔧 REX 2026-07-07 (2) : ForceTestA/ForceTestB permettent à l'auto-test de redondance
// (ci-dessous) de forcer UN SEUL canal bas à la fois, sans dépendre d'un vrai défaut Méca A/B/C.
PowerCutOff_A_RQ := NOT (PRG_03_Safety.instSafetyWinchM1.PowerCutOff
                         OR PRG_03_Safety.instSafetyWinchM2.PowerCutOff
                         OR PRG_03_Safety.instSafetyChariotM3.PowerCutOff)
                    AND NOT ForceTestA
                    AND NOT GVL_IHM.Modes.CmdEmergencyCutOff;

PowerCutOff_B_RQ := NOT (PRG_03_Safety.instSafetyWinchM1.PowerCutOff
                         OR PRG_03_Safety.instSafetyWinchM2.PowerCutOff
                         OR PRG_03_Safety.instSafetyChariotM3.PowerCutOff)
                    AND NOT ForceTestB
                    AND NOT GVL_IHM.Modes.CmdEmergencyCutOff;

// ─── 🚨 SÉQUENCE RÉARMEMENT CONTACTEUR PUISSANCE (REX 2026-07-07) ──────────────────────
// Commande IHM (front, PAS de réarmement automatique) →
//   1) auto-test canal A seul (200ms, coupe A/vérifie EmergencyChain tombe) puis restaure (200ms)
//   2) auto-test canal B seul (200ms) puis restaure (200ms)
//   3) si les 2 canaux sont validés : impulsion 1s sur EmergencyArming_RQ (mécanisme à ressort)
//   4) attente confirmation contacteur (EmergencyStopOk) sous 2s
//   5) verrouillage 5s avant nouvelle tentative possible, succès ou échec
// Si un canal échoue l'auto-test → RedundancyTestFailed, tout est bloqué (on ne peut pas démarrer
// avec un seul contact de sécurité réellement fonctionnel).
ResetEdge(CLK := PRG_09_Supervision.FaultMachineReset_IHM);

ArmReqEdge(CLK := GVL_IHM.Modes.CmdEmergencyArming);
IF ArmReqEdge.Q AND (ArmingSeqStep = 0) AND PRG_00_Inputs.EmergencyChain
   AND NOT EmergencyArmingLockoutActive
   AND NOT PRG_00_Inputs.EmergencyStopOk THEN // 🆕 REX 2026-07-08 : Ignoré si déjà armé pour éviter une coupure intempestive lors de l'auto-test
    ArmingSeqStep := 1;
END_IF;

// Étape 1 : coupe canal A seul, vérifie que la boucle tombe
TonTestA(IN := (ArmingSeqStep = 1), PT := T#200MS);
IF ArmingSeqStep = 1 THEN
    ForceTestA := TRUE;
    IF TonTestA.Q THEN
        ForceTestA := FALSE;
        IF PRG_00_Inputs.EmergencyChain THEN
            // La boucle n'est PAS tombée alors qu'on a coupé A seul → canal A shunté/défaillant
            RedundancyTestFailed := TRUE;
            ArmingSeqStep := 0;
        ELSE
            ArmingSeqStep := 2;
        END_IF;
    END_IF;
ELSE
    ForceTestA := FALSE;
END_IF;

// Étape 2 : restaure A, attend le retour de la boucle
TonRestoreA(IN := (ArmingSeqStep = 2), PT := T#200MS);
IF (ArmingSeqStep = 2) AND TonRestoreA.Q THEN
    IF PRG_00_Inputs.EmergencyChain THEN
        ArmingSeqStep := 3;
    ELSE
        ArmingSeqStep := 0; // boucle pas revenue saine (AU pressé entre-temps ?) — pas d'alarme dédiée, l'opérateur relance
    END_IF;
END_IF;

// Étape 3 : coupe canal B seul, vérifie que la boucle tombe
TonTestB(IN := (ArmingSeqStep = 3), PT := T#200MS);
IF ArmingSeqStep = 3 THEN
    ForceTestB := TRUE;
    IF TonTestB.Q THEN
        ForceTestB := FALSE;
        IF PRG_00_Inputs.EmergencyChain THEN
            RedundancyTestFailed := TRUE;
            ArmingSeqStep := 0;
        ELSE
            ArmingSeqStep := 4;
        END_IF;
    END_IF;
ELSE
    ForceTestB := FALSE;
END_IF;

// Étape 4 : restaure B, attend le retour de la boucle
TonRestoreB(IN := (ArmingSeqStep = 4), PT := T#200MS);
IF (ArmingSeqStep = 4) AND TonRestoreB.Q THEN
    IF PRG_00_Inputs.EmergencyChain THEN
        ArmingSeqStep := 5;
    ELSE
        ArmingSeqStep := 0;
    END_IF;
END_IF;

// Étape 5 : les 2 canaux validés → impulsion réarmement 1s
EmergencyArmingPulseActive := (ArmingSeqStep = 5);
TonArmingPulse(IN := (ArmingSeqStep = 5), PT := T#1S);
IF (ArmingSeqStep = 5) AND TonArmingPulse.Q THEN
    ArmingSeqStep := 6;
END_IF;

// Étape 6 : attente confirmation contacteur (2s max)
TonArmingConfirm(IN := (ArmingSeqStep = 6), PT := T#2S);
IF ArmingSeqStep = 6 THEN
    IF PRG_00_Inputs.EmergencyStopOk THEN
        ArmingSeqStep := 0;
        EmergencyArmingLockoutActive := TRUE;
    ELSIF TonArmingConfirm.Q THEN
        EmergencyArmingFailed := TRUE;
        ArmingSeqStep := 0;
        EmergencyArmingLockoutActive := TRUE;
    END_IF;
END_IF;

TonArmingLockout(IN := EmergencyArmingLockoutActive, PT := T#5S);
IF TonArmingLockout.Q THEN
    EmergencyArmingLockoutActive := FALSE;
END_IF;

EmergencyArming_RQ := EmergencyArmingPulseActive;

IF ResetEdge.Q THEN
    RedundancyTestFailed := FALSE; // défaut câblage : pas de "cause disparue" détectable, front seul suffit
    IF PRG_00_Inputs.EmergencyStopOk THEN
        EmergencyArmingFailed := FALSE; // cause disparue (contacteur confirmé) + front reset
    END_IF;
END_IF;
