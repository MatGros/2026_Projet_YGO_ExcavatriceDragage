(* =======================================================================
   ⚙️ FB_CycleTime — Mesure du temps de cycle réel de la tâche
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Calcul du dt réel entre deux exécutions successives
   ⚙️ Calcul : Delta horloge système TIME() converti en secondes
   🛡️ Robustesse : dt borné (0 < dt <= CST_MaxCycleDeltaMs) sinon valeur de secours —
      neutralise les artefacts de rebouclage TIME() (49,7 j) et de reprise (online-change, debug)
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
VAR CONSTANT
    // === BORNE HAUTE DU DELTA DE CYCLE ===
    CST_MaxCycleDeltaMs     : UDINT := 1000;      // Plafond physique du dt entre deux scans (ms) : au-dela -> valeur de secours
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

{region "§4 Conversion, secours et bornage"}
// 4. CONVERSION EN SECONDES, AVEC DOUBLE BORNAGE DU DELTA
//
// TIME() est un compteur systeme 32 bits en millisecondes depuis le demarrage de
// l'automate. Il n'est PAS absolu : il reboucle a 0 tous les 2^32 ms (~49,7 jours).
// La soustraction TimeCurrent - TimeLast est modulo 2^32 : au passage du rebouclage,
// tant que l'ecart reel entre deux scans reste < 49,7 j (toujours vrai a 10 ms),
// DeltaTimeMs reste correct. Le rebouclage seul n'est donc pas le risque principal.
//
// Le vrai risque est un DeltaTimeMs REELLEMENT > CST_MaxCycleDeltaMs : reprise apres
// un online-change, sortie d'un point d'arret / pas-a-pas debug, ou fenetre du
// rebouclage TIME(). Le chien de garde tache (200 ms, sensibilite 1) borne deja les
// gels en fonctionnement ; ce plafond couvre les cas hors surveillance.
// Un dt aberrant publie tel quel donnerait un CycleTimeS enorme, propage en un seul
// scan dans les rampes de vitesse et les integrateurs de position/frein -> saut
// physique. Fail-safe : hors de la plage nominale (0 < dt <= plafond), on publie la
// valeur de secours DefaultValueS au lieu de l'artefact. Pas de redemarrage auto.
//
// Borne basse dt = 0 (anti-zero, ex. premier appel du scan) et borne haute
// dt > CST_MaxCycleDeltaMs (anti-artefact) partagent la meme branche de secours.
IF (DeltaTimeMs > 0) AND (DeltaTimeMs <= CST_MaxCycleDeltaMs) THEN
    CycleTimeS := UDINT_TO_REAL(DeltaTimeMs) / 1000.0;
ELSE
    CycleTimeS := DefaultValueS;
END_IF;
{endregion}

{region "§5 Archivage"}
// 5. ARCHIVAGE POUR LE PROCHAIN CYCLE
TimeLast := TimeCurrent;
{endregion}
