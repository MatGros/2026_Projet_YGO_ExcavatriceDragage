(* ═══════════════════════════════════════════════════════════════
   📤 FB_OutputsMachine — Conditionnement SORTIES réelles de toute la machine (1 instance)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie6_IO_Conditioning_v1.2.md §5 (historique détaillé : AUDIT
      D52/D60/D63/D65)
   🧭 Interface RÉDUITE (Partie3 §1bis) : compose FB_Output (_COMMON) pour TOUTES les sorties
      TOR réelles (Winch M1/Winch M2/Chariot M3). Ce FB N'A NI `VAR_INPUT` NI `VAR_OUTPUT` :
      il LIT `GVL_OUT.Xxx` (écrit par `PRG_MAIN` juste après `FB_Winch`/`FB_Chariot`) et
      ÉCRIT DIRECTEMENT les I/O réels (`_DQ`/`_RQ`) en interne — appelé SANS PARAMÈTRE
      (`instOutputsMachine();`). `InvertLogic` de chaque sous-instance reste à son défaut
      (FALSE) — à FORCER DIRECTEMENT sur la sous-instance en vue CODESYS pour inverser NO/NC
      en mise en service. Prévu pour être implémenté en LD (Ladder) — code ci-dessous =
      référence ST.
   🔴 Portée limitée au conditionnement bas niveau (InvertLogic par voie) : `UseFeedback`
      reste FALSE partout — la double-vérification contacteur (FB_Winch/FB_Chariot, écrite à
      la main) n'est PAS dupliquée/remplacée ici (choix d'architecture Partie6 §0 non tranché).
   🔴 Chariot M3 : seul `M3_BrakeCmd_RQ` est réellement câblé — `M3_RelayFwd/Rev/RelaySpeedGv`
      restent STUB logiciel (`GVL_Chariot_M3_Stub`, pas de matériel réel encore).
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du POU FB_OutputsMachine) ===

FUNCTION_BLOCK PUBLIC FB_OutputsMachine
VAR
    // 🪝 Winch M1
    instM1RelayFwd        : FB_Output;
    instM1RelayRev        : FB_Output;
    instM1SpeedContactor1 : FB_Output;
    instM1SpeedContactor2 : FB_Output;
    instM1SpeedContactor3 : FB_Output;
    instM1SpeedContactor4 : FB_Output;
    instM1BrakeCmd        : FB_Output;

    // 🪝 Winch M2
    instM2RelayFwd        : FB_Output;
    instM2RelayRev        : FB_Output;
    instM2SpeedContactor1 : FB_Output;
    instM2SpeedContactor2 : FB_Output;
    instM2SpeedContactor3 : FB_Output;
    instM2SpeedContactor4 : FB_Output;
    instM2BrakeCmd        : FB_Output;

    // ↔️ Chariot M3
    instChariotBrakeCmd   : FB_Output;
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_OutputsMachine) ===

// 🪝 ─── WINCH M1 — lit GVL_OUT, écrit DIRECTEMENT les I/O réels (_DQ/_RQ) ────
instM1RelayFwd(Command := GVL_OUT.M1RelayFwd);
M1_RelayFwd_DQ := instM1RelayFwd.State;

instM1RelayRev(Command := GVL_OUT.M1RelayRev);
M1_RelayRev_DQ := instM1RelayRev.State;

instM1SpeedContactor1(Command := GVL_OUT.M1SpeedContactor1);
M1_SpeedContactor_1_DQ := instM1SpeedContactor1.State;

instM1SpeedContactor2(Command := GVL_OUT.M1SpeedContactor2);
M1_SpeedContactor_2_DQ := instM1SpeedContactor2.State;

instM1SpeedContactor3(Command := GVL_OUT.M1SpeedContactor3);
M1_SpeedContactor_3_DQ := instM1SpeedContactor3.State;

instM1SpeedContactor4(Command := GVL_OUT.M1SpeedContactor4);
M1_SpeedContactor_4_DQ := instM1SpeedContactor4.State;

instM1BrakeCmd(Command := GVL_OUT.M1BrakeCmd);
M1_BrakeCmd_RQ := instM1BrakeCmd.State;

// 🪝 ─── WINCH M2 ──────────────────────────────────────────────────────────
instM2RelayFwd(Command := GVL_OUT.M2RelayFwd);
M2_RelayFwd_DQ := instM2RelayFwd.State;

instM2RelayRev(Command := GVL_OUT.M2RelayRev);
M2_RelayRev_DQ := instM2RelayRev.State;

instM2SpeedContactor1(Command := GVL_OUT.M2SpeedContactor1);
M2_SpeedContactor_1_DQ := instM2SpeedContactor1.State;

instM2SpeedContactor2(Command := GVL_OUT.M2SpeedContactor2);
M2_SpeedContactor_2_DQ := instM2SpeedContactor2.State;

instM2SpeedContactor3(Command := GVL_OUT.M2SpeedContactor3);
M2_SpeedContactor_3_DQ := instM2SpeedContactor3.State;

instM2SpeedContactor4(Command := GVL_OUT.M2SpeedContactor4);
M2_SpeedContactor_4_DQ := instM2SpeedContactor4.State;

instM2BrakeCmd(Command := GVL_OUT.M2BrakeCmd);
M2_BrakeCmd_RQ := instM2BrakeCmd.State;

// ↔️ ─── CHARIOT M3 — seul BrakeCmd est réel ──────────────────────────────
instChariotBrakeCmd(Command := GVL_OUT.ChariotBrakeCmd);
M3_BrakeCmd_RQ := instChariotBrakeCmd.State;
