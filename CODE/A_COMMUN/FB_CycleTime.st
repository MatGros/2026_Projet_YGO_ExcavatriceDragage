(* =======================================================================
   ⚙️ FB_CycleTime — Mesure du temps de cycle réel de la tâche
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Calcul du dt réel entre deux exécutions successives
   ⚙️ Calcul : Delta horloge système TIME() converti en secondes
   📄 Doc métier : DOC/AF/AF_Partie-03_Contrats_Composants_v2.3.md
   ======================================================================= *)
FUNCTION_BLOCK FB_CycleTime
VAR_INPUT
    // === REGLAGES DE SECOURS ===
    DefaultValueS           : REAL := 0.004;      // --> [CFG] Valeur de secours par defaut (ex: 4ms = 0.004s)
END_VAR
VAR_OUTPUT
    // === MESURE ET DIAGNOSTIC ===
    CycleTimeS              : REAL;               // <-- [DIAG] Temps ecoule reel calcule (secondes)
END_VAR
VAR
    // === HORLOGE ET MEMOIRE TEMPORELLE ===
    TimeCurrent             : TIME;               // . [LOC] Temps systeme actuel
    TimeLast                : TIME;               // . [LOC] Empreinte de temps du cycle precedent
    DeltaTimeMs             : UDINT;              // . [LOC] Ecart brut calcule (ms)
    InitDone                : BOOL;               // . [LOC] Drapeau d'initialisation du premier cycle
END_VAR

{region "§1 Acquisition temps"}
// 1. ACQUISITION DU TEMPS SYSTÈME
TimeCurrent := TIME();
{endregion}

{region "§2 Initialisation"}
// 2. INITIALISATION UNIQUE AU PREMIER CYCLE
IF NOT InitDone THEN
    TimeLast := TimeCurrent;
    InitDone := TRUE;
    CycleTimeS := DefaultValueS;
    RETURN;
END_IF;
{endregion}

{region "§3 Calcul delta"}
// 3. CALCUL DU DELTA EN MILLISECONDES
DeltaTimeMs := TIME_TO_UDINT(TimeCurrent - TimeLast);
{endregion}

{region "§4 Conversion et secours"}
// 4. CONVERSION ET CHARGE DE SECOURS
IF DeltaTimeMs > 0 THEN
    CycleTimeS := UDINT_TO_REAL(DeltaTimeMs) / 1000.0;
ELSE
    CycleTimeS := DefaultValueS;
END_IF;
{endregion}

{region "§5 Archivage"}
// 5. ARCHIVAGE POUR LE PROCHAIN CYCLE
TimeLast := TimeCurrent;
{endregion}
