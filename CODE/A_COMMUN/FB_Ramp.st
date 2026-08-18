(* =======================================================================
   ⚙️ FB_Ramp — Rampe d'accélération et décélération asymétrique
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Limitation de variation anti-à-coups (%/s) sur signal analogique
   🔒 Polarité : Distingue l'éloignement de zéro (Accel) et le retour à zéro (Decel)
   📄 Doc métier : DOC/AF/AF_Partie-08_Fonction_Joystick_v2.0.md §2
   ======================================================================= *)
FUNCTION_BLOCK FB_Ramp
VAR_INPUT
    // === CONSIGNES ET TAUX DE RAMPE ===
    Target                  : REAL;               // --> [CMD] Valeur cible visee (-100.0..+100.0 %)
    AccelRate               : REAL;               // --> [CFG] Taux d'acceleration (%/s)
    DecelRate               : REAL;               // --> [CFG] Taux de deceleration (%/s)
    CycleTimeS              : REAL;               // --> [CFG] Temps de cycle reel en secondes (dt)
END_VAR
VAR_OUTPUT
    // === VALEUR RAMPEE ===
    Current                 : REAL;               // <-- [STAT] Valeur courante amortie (-100.0..+100.0 %)
END_VAR
VAR
    // === CALCULS INTERNES ===
    StepX                   : REAL;               // . [LOC] Pas de variation pour le cycle courant
    TargetLimited           : REAL;               // . [LOC] Cible bornee a [-100.0, +100.0]
END_VAR

// Détection du comportement (Accélération vs Décélération)
// 🔧 CORRECTIF : classification par CÔTÉ DE ZÉRO + sens de déplacement, plus par signe brut
// de Target seul (l'ancienne version se trompait lors d'une traversée de zéro rapide).
// 🛡️ Garde-fou : la rampe ne sort jamais de la plage normalisée ±100 %.
TargetLimited := LIMIT(-100.0, Target, 100.0);
Current := LIMIT(-100.0, Current, 100.0);

IF (Current >= 0.0 AND TargetLimited >= Current) OR (Current <= 0.0 AND TargetLimited <= Current) THEN
    StepX := AccelRate * CycleTimeS; // S'éloigne du zéro (reste du même côté, va plus loin)
ELSE
    StepX := DecelRate * CycleTimeS; // Retourne vers zéro, ou le traverse vers l'autre signe
END_IF;

// Application de la rampe
IF Current < TargetLimited THEN
    Current := Current + StepX;
    IF Current > TargetLimited THEN Current := TargetLimited; END_IF;
ELSIF Current > TargetLimited THEN
    Current := Current - StepX;
    IF Current < TargetLimited THEN Current := TargetLimited; END_IF;
END_IF;

// 🛡️ Limitation finale : même une valeur d'état déjà corrompue reste bornée.
Current := LIMIT(-100.0, Current, 100.0);
