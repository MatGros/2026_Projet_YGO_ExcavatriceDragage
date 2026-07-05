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
PowerCutOff_A_RQ := PRG_03_Safety.instSafetyWinchM1.PowerCutOff 
                    OR PRG_03_Safety.instSafetyWinchM2.PowerCutOff 
                    OR PRG_03_Safety.instSafetyChariotM3.PowerCutOff;

PowerCutOff_B_RQ := PowerCutOff_A_RQ;
