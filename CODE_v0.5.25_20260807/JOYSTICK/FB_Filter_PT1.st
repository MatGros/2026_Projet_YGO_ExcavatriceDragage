(* ═══════════════════════════════════════════════════════════════
   🔁 FB_Filter_PT1 — Filtre passe-bas premier ordre (PT1 numérique)
   ───────────────────────────────────────────────────────────────
   📄 Extrait depuis le projet CODESYS (Device.export, JOYSTICK/)
   🎯 Filtre exponentiel discret : y[k] = α·x[k] + (1-α)·y[k-1]
      où α = CycleTimeS / (T + CycleTimeS), T = TimeConst en secondes.
   ⚠️ Si TimeConst = 0 ou CycleTimeS = 0, sortie = entrée (pass-through).
   ═══════════════════════════════════════════════════════════════
   📄 Docs : DOC/AF_Partie-08_Fonction_Joystick_v2.0.md
*)

FUNCTION_BLOCK FB_Filter_PT1
VAR_INPUT
    /// Consigne brute entrée
    ValueIn    : REAL;
    /// Constante de temps du filtre
    TimeConst  : TIME;
    /// Temps de cycle réel en secondes
    CycleTimeS : REAL;
END_VAR
VAR_OUTPUT
    /// Consigne filtrée sortie
    ValueOut : REAL;
END_VAR
VAR
    T     : REAL;
    Alpha : REAL;
END_VAR

T := TIME_TO_REAL(TimeConst) / 1000.0; // ms → s

IF T <= 0.0 OR CycleTimeS <= 0.0 THEN
    ValueOut := ValueIn;
ELSE
    Alpha    := CycleTimeS / (T + CycleTimeS);
    ValueOut := Alpha * ValueIn + (1.0 - Alpha) * ValueOut;
END_IF;
