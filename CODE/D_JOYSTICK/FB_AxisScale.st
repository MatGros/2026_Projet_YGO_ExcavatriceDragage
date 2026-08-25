(* =======================================================================
   ⚙️ FB_AxisScale — Normalisation et zone morte d'un axe joystick
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Normalise une valeur brute (0..10000) selon le neutre calibré
             et applique une zone morte en unités brutes (compte ADC).
   🛡️ Garde-fou : Saturation stricte de la consigne à +/-100.0 %.
   📄 Doc métier : DOC/AF/AF_Partie-08_Fonction_Joystick_v2.3.md (F08.02)
   ======================================================================= *)

FUNCTION_BLOCK FB_AxisScale
VAR_INPUT
    // === ENTRÉES MESURÉES & CONFIGURATION ===
    RawIn       : INT;  // --> [HW]  Valeur brute potentiometre/Hall (0..10000)
    Neutral     : INT;  // --> [CFG] Point milieu calibre (compte brut ADC)
    DeadbandRaw : INT;  // --> [CFG] Zone morte en unites brutes ADC (ex: 300)
END_VAR
VAR_OUTPUT
    // === CONSIGNES CALCULÉES ===
    OutPct      : REAL; // <-- [STAT] Consigne d'axe mise a l'echelle (-100.0..+100.0 %)
END_VAR
VAR
    // === VARIABLES LOCALES INTERNES ===
    Delta       : REAL; // . [LOC]  Amplitude utile de la demi-plage d'axe
END_VAR

IF RawIn >= Neutral THEN
    Delta := INT_TO_REAL(10000 - Neutral);
    IF Delta > 0.0 THEN
        OutPct := (INT_TO_REAL(RawIn - Neutral) / Delta) * 100.0;
    ELSE
        OutPct := 0.0;
    END_IF;
ELSE
    Delta := INT_TO_REAL(Neutral);
    IF Delta > 0.0 THEN
        OutPct := (INT_TO_REAL(RawIn - Neutral) / Delta) * 100.0;
    ELSE
        OutPct := 0.0;
    END_IF;
END_IF;

IF ABS(RawIn - Neutral) <= DeadbandRaw THEN
    OutPct := 0.0;
END_IF;

// 🛡️ Limitation de plage : une valeur brute hors plage nominale ne doit jamais
// produire une consigne supérieure à ±100 %. Ce garde-fou protège les
// consommateurs en aval, notamment la translation M3.
OutPct := LIMIT(-100.0, OutPct, 100.0);
