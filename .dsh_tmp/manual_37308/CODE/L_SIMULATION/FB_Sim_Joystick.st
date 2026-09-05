(* ═══════════════════════════════════════════════════════════════
   🧪 FB_Sim_Joystick — Simulation des entrées brutes joystick (bus CAN hors ligne)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF/AF_Partie-13_Fonction_Simulation_v2.5.md
   🧩 Brique réduite (Partie3 §1bis) : outil de banc, pas du métier machine.
   🎯 Rôle : remplace l'ancien bypass homme-mort codé en dur dans `FB_Joystick`
      (`GVL_DEBUG.DBG_DeadmanBypass_TEST`, qui forçait `DeadmanArmed` en
      permanence — un vrai contournement de sécurité). Ici, on simule les
      ENTRÉES BRUTES du capteur (`RawX`/`RawY`/`RawButton`) : le homme-mort réel
      de `FB_Joystick` reste pleinement actif et doit toujours être "actionné"
      (forcer `RawButton` en instance CODESYS) pour armer — comportement
      métier testé pour de vrai, pas contourné.
   🕹️ Comportement dynamique (conception validée) :
      - Ascending : bouton actif → `RawX`/`RawY` monte de `NeutralRaw` vers la cible
        (0 ou `MaxRaw`) en `RiseTimeS`, avec un bruit pseudo-aléatoire léger.
      - Dépassement (`OvershootActive`) : la cible de montée DÉPASSE la butée
        (MaxRaw+AMT ou 0−AMT) → déclenche le défaut capteur hors plage.
      - Retombée : bouton relâché → descente LINÉAIRE en `FallTimeMs` vers le neutre.
      - Bagotement (`BagotementActive`) : au retour, petit balancement de quelques %
        autour du neutre avant de se stabiliser.
   📥 Enable        : simulation active (SimulationModeActive AND NOT BusJoystickSignalIsReal)
   📥 NeutralRaw    : valeur brute simulée au repos (voir GVL_Simulation.TstJoystickForceNeutralRaw)
   📥 MaxRaw        : valeur brute simulée à fond (voir GVL_Simulation.TstJoystickForceMaxRaw)
   📥 Btn*          : boutons directionnels (1 seul impose une butée d'axe ; 0 ou ≥2 = neutre)
   📥 OvershootActive : bagotement au retour (test mouvement parasite)
   📥 RiseTimeS / FallTimeMs / CycleTimeS : dynamique temporelle (pattern FB_Sim_Encoder)
   📤 RawX/RawY     : valeurs brutes dynamiques (neutre = NeutralRaw)
   📤 RawButton     : homme-mort brut = un bouton directionnel actif
   💡 Note d'application : en vue instance CODESYS, forcer `RawX`/`RawY` à `MaxRaw` (ou une
      valeur intermédiaire) pour simuler un débattement, et `RawButton` à `TRUE` pour simuler
      l'appui homme-mort — exactement comme on forcerait le vrai capteur.
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du POU FB_Sim_Joystick) ===

FUNCTION_BLOCK PUBLIC FB_Sim_Joystick
VAR_INPUT
    Enable              : BOOL;   (* --> [CMD] Active la simulation *)
    NeutralRaw          : INT := 5000;   (* --> [CFG] Valeur brute au repos (neutre) *)
    MaxRaw              : INT := 10000;   (* --> [CFG] Valeur brute à fond *)
    BtnLeft_Rev_TREMIE  : BOOL;   (* --> [TST] Bouton gauche : X→0, Y→neutre *)
    BtnRight_Fwd_MAINT  : BOOL;   (* --> [TST] Bouton droite : X→MaxRaw, Y→neutre *)
    BtnFwd_Up_Close     : BOOL;   (* --> [TST] Bouton avant : X→neutre, Y→MaxRaw *)
    BtnRev_Down_Open    : BOOL;   (* --> [TST] Bouton arrière : X→neutre, Y→0 *)
    OvershootActive     : BOOL;   (* --> [TST] Dépassement de montée au-delà de 100% (défaut capteur hors plage) *)
    BagotementActive    : BOOL;   (* --> [TST] Bagotement au relâchement (petit balancement autour du neutre) *)
    RiseTimeS           : REAL := 1.5;   (* --> [CFG] Temps de montée 0→100% (s) *)
    FallTimeMs          : TIME := T#200MS;   (* --> [CFG] Temps de retombée 100%→0 *)
    CycleTimeS          : REAL := 0.010;   (* --> [CFG] Période tâche PLC (s) — 10 ms *)
END_VAR
VAR_OUTPUT
    RawX        : INT;   (* <-- [DIAG] Valeur brute axe X (dynamique, neutre = NeutralRaw) *)
    RawY        : INT;   (* <-- [DIAG] Valeur brute axe Y (dynamique, neutre = NeutralRaw) *)
    RawButton   : BOOL;  (* <-- [DIAG] Homme-mort brut = un bouton directionnel actif *)
    ReturningActive : BOOL;  (* <-- [STAT] TRUE si retour dynamique en cours (FALL/OVERSHOOT) — FB_SimBench émet le modèle *)
END_VAR
VAR
    FirstCycle  : BOOL := TRUE;   (* . [LOC] Initialisation au neutre *)
    State       : INT := 0;   (* . [LOC] 0=IDLE, 1=RISE, 2=FALL, 3=OVERSHOOT *)
    TargetX     : INT;   (* . [LOC] Cible brute axe X *)
    TargetY     : INT;   (* . [LOC] Cible brute axe Y *)
    ActiveAxis  : INT;   (* . [LOC] 0=aucun, 1=X, 2=Y (axe en retour) *)
    RiseStep    : REAL;   (* . [LOC] Pas de montée par cycle (points) *)
    FallStep    : REAL;   (* . [LOC] Pas de retombée par cycle (points) *)
    RandCnt     : INT := 0;   (* . [LOC] Compteur pseudo-aléatoire (bruit de montée) *)
    Noise       : INT;   (* . [LOC] Bruit ±25 points (≈ ±0.5% de la course) *)
    BtnCount    : INT;   (* . [LOC] Nombre de boutons directionnels actifs (0..4) *)
    OscDev      : REAL;   (* . [LOC] Écart au neutre de l'oscillateur de bagotement *)
    OscVel      : REAL;   (* . [LOC] Vitesse de l'oscillateur (points/cycle) *)
    OscAcc      : REAL;   (* . [LOC] Accélération de l'oscillateur *)
END_VAR
VAR CONSTANT
    CST_ST_IDLE      : INT := 0;   (* . [CFG] État : au neutre *)
    CST_ST_RISE      : INT := 1;   (* . [CFG] État : montée vers la cible *)
    CST_ST_FALL      : INT := 2;   (* . [CFG] État : retombée linéaire *)
    CST_ST_OVERSHOOT : INT := 3;   (* . [CFG] État : bagotement (oscillations amorties) *)
    CST_OSC_K        : REAL := 0.01;   (* . [CFG] Raideur oscillateur (fréquence bagotement) *)
    CST_OSC_C        : REAL := 0.05;   (* . [CFG] Amortissement (2-3 oscillations visibles) *)
    CST_OVERSHOOT_AMT : INT := 600;   (* . [CFG] Dépassement de montée au-delà de MaxRaw (déclenche défaut capteur hors plage) *)
    CST_BAGOT_AMT     : INT := 500;   (* . [CFG] Amplitude du bagotement au relâchement (~5% autour du neutre) *)
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_Sim_Joystick) ===

{region "§1 Gate"}
// 🔑 Initialise au neutre au premier cycle uniquement ; ensuite RawX/RawY sont pilotés
// dynamiquement par les boutons. Quand la simulation est coupée, on revient au neutre.
IF NOT Enable THEN
    FirstCycle := TRUE;
    State      := CST_ST_IDLE;
    RawX       := NeutralRaw;
    RawY       := NeutralRaw;
    RawButton  := FALSE;
    ReturningActive := FALSE; // 📊 Neutralisation : simulation inactive hors Enable
    RETURN;
END_IF;
{endregion}

{region "§2 Initialisation neutre"}
IF FirstCycle THEN
    RawX       := NeutralRaw;
    RawY       := NeutralRaw;
    RawButton  := FALSE;
    State      := CST_ST_IDLE;
    FirstCycle := FALSE;
END_IF;
{endregion}

{region "§3 Pseudo-aléatoire (bruit de montée)"}
// 🎲 Compteur qui repasse à zéro, multiplié pour rester dans la plage (méthode validée).
// Le bruit s'ajoute à la rampe de montée uniquement (pas à la retombée, linéaire propre).
RandCnt := (RandCnt + 1) MOD 1000;
Noise   := (RandCnt MOD 50) - 25;   // ±25 points (≈ ±0.5% de la course)
{endregion}

{region "§4 Cibles & transitions"}
// 🎯 Un SEUL bouton impose une butée d'axe ; 0 ou ≥2 boutons = neutre (pas de diagonale implicite).
// Si OvershootActive : la cible de montée DÉPASSE la butée (MaxRaw+AMT ou 0−AMT) pour
// déclencher le défaut capteur hors plage (RawOutOfRange) — test du dépassement de valeur.
BtnCount := BOOL_TO_INT(BtnLeft_Rev_TREMIE) + BOOL_TO_INT(BtnRight_Fwd_MAINT)
          + BOOL_TO_INT(BtnFwd_Up_Close) + BOOL_TO_INT(BtnRev_Down_Open);
IF BtnCount = 1 THEN
    IF BtnLeft_Rev_TREMIE THEN
        IF OvershootActive THEN TargetX := 0 - CST_OVERSHOOT_AMT; ELSE TargetX := 0; END_IF;
        TargetY := NeutralRaw; ActiveAxis := 1;
    ELSIF BtnRight_Fwd_MAINT THEN
        IF OvershootActive THEN TargetX := MaxRaw + CST_OVERSHOOT_AMT; ELSE TargetX := MaxRaw; END_IF;
        TargetY := NeutralRaw; ActiveAxis := 1;
    ELSIF BtnFwd_Up_Close THEN
        TargetX := NeutralRaw;
        IF OvershootActive THEN TargetY := MaxRaw + CST_OVERSHOOT_AMT; ELSE TargetY := MaxRaw; END_IF;
        ActiveAxis := 2;
    ELSE
        TargetX := NeutralRaw;
        IF OvershootActive THEN TargetY := 0 - CST_OVERSHOOT_AMT; ELSE TargetY := 0; END_IF;
        ActiveAxis := 2;
    END_IF;
    State := CST_ST_RISE;
ELSE
    // 0 ou ≥2 boutons : retour au neutre.
    TargetX := NeutralRaw;
    TargetY := NeutralRaw;
    IF State = CST_ST_RISE THEN
        // Front de relâchement : retour au neutre. D'abord retombée linéaire (FALL),
        // puis petit bagotement de quelques % autour du neutre si OvershootActive (voir §6).
        State := CST_ST_FALL;
    END_IF;
END_IF;
{endregion}

{region "§5 Ascending (rampe + bruit)"}
IF State = CST_ST_RISE THEN
    // Pas de montée : pleine course (MaxRaw−NeutralRaw) en RiseTimeS.
    RiseStep := INT_TO_REAL(MaxRaw - NeutralRaw) / (RiseTimeS / CycleTimeS);
    // Axe X
    IF RawX < TargetX THEN
        RawX := MIN(RawX + REAL_TO_INT(RiseStep) + Noise, TargetX);
    ELSIF RawX > TargetX THEN
        RawX := MAX(RawX - REAL_TO_INT(RiseStep) - Noise, TargetX);
    END_IF;
    // Axe Y
    IF RawY < TargetY THEN
        RawY := MIN(RawY + REAL_TO_INT(RiseStep) + Noise, TargetY);
    ELSIF RawY > TargetY THEN
        RawY := MAX(RawY - REAL_TO_INT(RiseStep) - Noise, TargetY);
    END_IF;
END_IF;
{endregion}

{region "§6 Retombée linéaire (sans bagotement)"}
IF State = CST_ST_FALL THEN
    // Pas de retombée : pleine course en FallTimeMs (TIME_TO_REAL → ms, /1000 → s).
    FallStep := INT_TO_REAL(MaxRaw - NeutralRaw) / (TIME_TO_REAL(FallTimeMs) / 1000.0 / CycleTimeS);
    IF RawX < NeutralRaw THEN
        RawX := MIN(RawX + REAL_TO_INT(FallStep), NeutralRaw);
    ELSIF RawX > NeutralRaw THEN
        RawX := MAX(RawX - REAL_TO_INT(FallStep), NeutralRaw);
    END_IF;
    IF RawY < NeutralRaw THEN
        RawY := MIN(RawY + REAL_TO_INT(FallStep), NeutralRaw);
    ELSIF RawY > NeutralRaw THEN
        RawY := MAX(RawY - REAL_TO_INT(FallStep), NeutralRaw);
    END_IF;
    IF RawX = NeutralRaw AND RawY = NeutralRaw THEN
        // Arrivée au neutre : si bagotement demandé, lance un petit balancement de quelques %.
        IF BagotementActive THEN
            State := CST_ST_OVERSHOOT;
            IF ActiveAxis = 1 THEN
                OscDev := INT_TO_REAL(CST_BAGOT_AMT);
            ELSE
                OscDev := INT_TO_REAL(CST_BAGOT_AMT);
            END_IF;
            OscVel := 0.0;
        ELSE
            State := CST_ST_IDLE;
        END_IF;
    END_IF;
END_IF;
{endregion}

{region "§7 Bagotement (dépassement + oscillations amorties)"}
IF State = CST_ST_OVERSHOOT THEN
    // 🎢 Oscillateur harmonique amorti discret (semi-implicite) autour du neutre :
    // le joystick dépasse le centre (~12% de l'écart initial) puis oscille 1-2 fois
    // avant de se stabiliser — comportement d'un opérateur qui relâche et balance.
    OscAcc := -CST_OSC_K * OscDev - CST_OSC_C * OscVel;
    OscVel := OscVel + OscAcc;
    OscDev := OscDev + OscVel;
    IF ActiveAxis = 1 THEN
        RawX := NeutralRaw + REAL_TO_INT(OscDev);
    ELSE
        RawY := NeutralRaw + REAL_TO_INT(OscDev);
    END_IF;
    // Stabilisé : revient exactement au centre.
    IF ABS(OscDev) < 1.0 AND ABS(OscVel) < 1.0 THEN
        State := CST_ST_IDLE;
        IF ActiveAxis = 1 THEN
            RawX := NeutralRaw;
        ELSE
            RawY := NeutralRaw;
        END_IF;
    END_IF;
END_IF;
{endregion}

{region "§8 Homme-mort brut + drapeau retour"}
RawButton := BtnLeft_Rev_TREMIE OR BtnRight_Fwd_MAINT OR BtnFwd_Up_Close OR BtnRev_Down_Open;
// Drapeau "retour dynamique en cours" : TRUE si l'état est FALL ou OVERSHOOT (retombée/bagotement).
// Permet à FB_SimBench d'émettre la sortie du modèle même après relâchement du bouton.
ReturningActive := (State = CST_ST_FALL) OR (State = CST_ST_OVERSHOOT);
{endregion}

END_FUNCTION_BLOCK
