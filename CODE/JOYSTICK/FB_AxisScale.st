(* ═══════════════════════════════════════════════════════════════
   📐 FB_AxisScale — Mise à l'échelle d'un axe joystick Hall
   ───────────────────────────────────────────────────────────────
   📄 Extrait depuis le projet CODESYS (Device.export, JOYSTICK/)
   🎯 Normalise une valeur brute (0..10000) par rapport au neutre calibré
      et applique une zone morte en %.
   Sortie : OutPct ∈ [-100.0 .. +100.0] (0.0 si dans la deadband)
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK FB_AxisScale
VAR_INPUT
    /// Valeur brute (0..10000)
    RawIn   : INT;
    /// Point milieu calibré
    Neutral : INT;
    /// Zone morte en %
    Deadband : REAL;
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

IF ABS(OutPct) <= Deadband THEN
    OutPct := 0.0;
END_IF;
