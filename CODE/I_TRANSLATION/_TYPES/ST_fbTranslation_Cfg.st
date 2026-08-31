(* ═══════════════════════════════════════════════════════════════
   ⚙️ ST_fbTranslation_Cfg — Configuration regroupée de FB_Translation
   ───────────────────────────────────────────────────────────────
   📐 NC-110 / G380 : pattern « Cfg : ST_fb<Fb>_Cfg » (comme FB_Winch
      avec Config : ST_fbWinch_Cfg). Regroupe en UN point d'interface les
      ~13 scalaires `[CFG]` qui étaient des VAR_INPUT plates de FB_Translation.
   🎯 Un seul sourcing : PRG_05_Translation assemble ce struct depuis la
      source unique GVL_PERSISTENT (§ source propre documentée ci-dessous).
   📤 Producteur : PRG_05_Translation (câblage).
   📥 Consommateur : FB_Translation (Cfg, lecture seule).
   📄 Doc : DOC/AF/AF_Partie-11_Fonction_Translation_v2.3.md
   ═══════════════════════════════════════════════════════════════ *)

TYPE ST_fbTranslation_Cfg :
STRUCT
    // === RAMPES VITESSE (%/s) ===
    CfgRampAccelRate            : REAL := 20.0;   // --> [CFG] Accélération
    CfgRampDecelNormalRate      : REAL := 40.0;   // --> [CFG] Décélération normale
    CfgRampDecelFastRate        : REAL := 100.0;  // --> [CFG] Décélération RAPIDE (SafeStop)
    DirectionInterlockDelay     : TIME := T#200ms; // --> [CFG] Délai avant changement de sens à l'arrêt

    // === VITESSES RÉDUITES D'APPROCHE (Hz) ===
    ApproachSpeedTremieHz       : REAL := 10.0;   // --> [CFG] Approche Trémie (Direction=1)
    ApproachSpeedMaintenanceHz  : REAL := 10.0;   // --> [CFG] Approche Maintenance (Direction=-1)
    ApproachSpeedP1Hz           : REAL := 10.0;   // --> [CFG] Approche P1 (Direction=-1)

    // === ÉCHELLE VARIATEUR ===
    DriveFreqScaleMaxHz         : REAL := 60.0;   // --> [CFG] Échelle 0..100 % → MaxHz

    // === COMMUN / FREIN ===
    CaptorDebounce              : TIME := T#100ms; // --> [CFG] Filtrage capteur position cible
    BrakeDelayContactClose      : TIME := T#100ms; // --> [CFG] Voir FB_Brake
    BrakeDelayMagnetise         : TIME := T#300ms; // --> [CFG] Voir FB_Brake
    BrakeDelayMotorDecel        : TIME := T#500ms; // --> [CFG] Voir FB_Brake
    BrakeFeedbackTimeout        : TIME := T#300ms; // --> [CFG] Strictement sous watchdog final 500 ms
END_STRUCT
END_TYPE
