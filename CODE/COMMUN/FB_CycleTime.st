(* ═══════════════════════════════════════════════════════════════
   ⏱️ FB_CycleTime — Mesure du temps de cycle réel de la tâche
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie-08_Fonction_Joystick_v1.3.md §2
      (base de temps utilisée par FB_FilterPT1, composé dans FB_Joystick)
   ═══════════════════════════════════════════════════════════════ *)
FUNCTION_BLOCK FB_CycleTime
VAR_INPUT
    DefaultValueS : REAL := 0.004; (* Valeur de secours par défaut (ex. 4ms) *)
END_VAR
VAR_OUTPUT
    CycleTimeS    : REAL;          (* Temps écoulé réel calculé (secondes) *)
END_VAR
VAR
    TimeCurrent   : TIME;          (* Temps système actuel *)
    TimeLast      : TIME;          (* Empreinte de temps du cycle précédent *)
    DeltaTimeMs   : UDINT;         (* Écart brut calculé (ms) *)
    InitDone      : BOOL;          (* Drapeau d'initialisation du premier cycle *)
END_VAR

// 1. ACQUISITION DU TEMPS SYSTÈME
TimeCurrent := TIME();

// 2. INITIALISATION UNIQUE AU PREMIER CYCLE
IF NOT InitDone THEN
    TimeLast := TimeCurrent;
    InitDone := TRUE;
    CycleTimeS := DefaultValueS;
    RETURN;
END_IF;

// 3. CALCUL DU DELTA EN MILLISECONDES
DeltaTimeMs := TIME_TO_UDINT(TimeCurrent - TimeLast);

// 4. CONVERSION ET CHARGE DE SECOURS
IF DeltaTimeMs > 0 THEN
    CycleTimeS := UDINT_TO_REAL(DeltaTimeMs) / 1000.0;
ELSE
    CycleTimeS := DefaultValueS;
END_IF;

// 5. ARCHIVAGE POUR LE PROCHAIN CYCLE
TimeLast := TimeCurrent;
