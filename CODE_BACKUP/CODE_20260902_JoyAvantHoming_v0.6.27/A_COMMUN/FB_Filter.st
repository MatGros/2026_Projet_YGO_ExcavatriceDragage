(* =======================================================================
   ⚙️ FB_Filter — Filtre passe-bas premier ordre (PT1 numérique)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Filtre exponentiel discret y[k] = a*x[k] + (1-a)*y[k-1]
             avec a = CycleTimeS / (T + CycleTimeS). Pass-through si T=0 ou Cycle=0.
   📄 Domaine : CODE/A_COMMUN (fonction de filtrage générale)
   ======================================================================= *)

FUNCTION_BLOCK FB_Filter
VAR_INPUT
    // === CONSIGNES DE PILOTAGE & CONFIGURATION ===
    ValueIn    : REAL;  // --> [CMD] Valeur brute a filtrer
    TimeConst  : TIME;  // --> [CFG] Constante de temps du filtre (ex: T#200ms)
    CycleTimeS : REAL;  // --> [CFG] Temps de cycle reel de la tache en secondes (ex: 0.02)
END_VAR
VAR_OUTPUT
    // === SORTIES LISSÉES ===
    ValueOut   : REAL;  // <-- [STAT] Valeur lissee par filtre PT1
END_VAR
VAR
    // === VARIABLES LOCALES INTERNES ===
    T          : REAL;  // . [LOC]  Constante de temps convertie en secondes
    Alpha      : REAL;  // . [LOC]  Facteur d'attenuation du filtre exponentiel
END_VAR

T := TIME_TO_REAL(TimeConst) / 1000.0; // ms → s

IF T <= 0.0 OR CycleTimeS <= 0.0 THEN
    ValueOut := ValueIn;
ELSE
    Alpha    := CycleTimeS / (T + CycleTimeS);
    ValueOut := Alpha * ValueIn + (1.0 - Alpha) * ValueOut;
END_IF;
