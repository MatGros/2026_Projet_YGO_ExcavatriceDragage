(* ═══════════════════════════════════════════════════════════════
   📐 FB_AxisScale — Mise à l'échelle d'un axe joystick Hall
   ───────────────────────────────────────────────────────────────
   📄 Extrait depuis le projet CODESYS (Device.export, JOYSTICK/)
   🎯 Normalise une valeur brute (0..10000) par rapport au neutre calibré
      et applique une zone morte en unités brutes (compte ADC, pas en %).
   Sortie : OutPct ∈ [-100.0 .. +100.0] (0.0 si dans la deadband)
   🔧 2026-08-07 (demande client) : Deadband (REAL, %) → DeadbandRaw (INT, compte brut 0..10000).
      Raison : plus simple à régler directement depuis le bruit mesuré au neutre (ex: ±200 sur le
      terrain → DeadbandRaw=300 avec marge), sans recalculer un % à chaque calibration.
   ═══════════════════════════════════════════════════════════════
   📄 Docs : DOC/AF/AF_Partie-08_Fonction_Joystick_v2.0.md
*)

FUNCTION_BLOCK FB_AxisScale
VAR_INPUT
    /// Valeur brute (0..10000)
    RawIn   : INT;
    /// Point milieu calibré
    Neutral : INT;
    /// Zone morte en unités brutes (compte ADC, ex: 300 sur plage 0..10000)
    DeadbandRaw : INT;
END_VAR
VAR_OUTPUT
    /// Valeur finale (-100.0..100.0)
    OutPct : REAL;
END_VAR
VAR
    Delta : REAL;
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
