(* ═══════════════════════════════════════════════════════════════
   📈 FB_Ramp — Rampe accel/décel anti-à-coups (retour zéro plus rapide)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie8_Fonction_Joystick_v1.1.md §2 (usage),
                   DOC/AF_Partie9_Fonction_Winch_v1.0.md (correctif ci-dessous)
   🧩 Instancié 3 fois dans le projet : RampX/RampY (FB_Joystick, cible
      SIGNÉE -100..+100 %) et SpeedRamp (FB_Winch, cible TOUJOURS >= 0,
      jamais concernée par ce bug — voir analyse d'impact ci-dessous).

   ⚠️ CORRECTIF (retour terrain 2026-07-02) : le choix accel/décel
   comparait `Target`/`Current` AVEC LEUR SIGNE, pas leur magnitude.
   Conséquence : lors d'une inversion RAPIDE du joystick (Current très
   négatif, Target qui redevient positif), la condition
   `(Target > 0.0 AND Target > Current)` devenait vraie dès que `Target`
   passait légèrement positif — alors que `Current` était encore très
   loin de zéro côté négatif — et sélectionnait à tort `AccelRate` (lent,
   "s'éloigne du zéro") au lieu de `DecelRate` (rapide, "retourne vers le
   zéro") pour toute la portion du trajet qui ramène réellement vers
   zéro. Résultat observé : lors d'un flick rapide du joystick, `Current`
   mettait ~3× plus longtemps que prévu à repasser par zéro, ce qui
   retardait en cascade `AxisCmdY.Direction`/`SpeedRef`, puis l'interlock
   de sens de `FB_Winch` (`CommandedDirection` bloqué sur l'ancien sens
   plus longtemps que nécessaire).
   🔬 Analyse d'impact (avant correctif) : `FB_Ramp` n'est instancié que
   dans `FB_Joystick` (`RampX`/`RampY`, cible signée → CONCERNÉ) et dans
   `FB_Winch` (`SpeedRamp`, cible = `RampTargetPct` toujours >= 0 → JAMAIS
   de traversée de signe possible → NON concerné, comportement inchangé).
   ✅ Correction : classification basée sur le CÔTÉ de zéro où se trouve
   `Current` et le sens de déplacement (pas le signe brut de `Target`),
   vérifiée sur les 8 cas (Current>0/<0/=0 × s'éloigne/retourne/traverse).
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du POU FB_Ramp) ===

FUNCTION_BLOCK FB_Ramp
VAR_INPUT
    Target      : REAL;       // Cible visée
    AccelRate   : REAL;       // Taux d'accélération (%/s)
    DecelRate   : REAL;       // Taux de décélération (%/s)
    CycleTimeS  : REAL;       // Temps de cycle réel en secondes
END_VAR
VAR_OUTPUT
    Current     : REAL;       // Valeur courante amortie
END_VAR
VAR
    StepX       : REAL;
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_Ramp) ===

// Détection du comportement (Accélération vs Décélération)
// 🔧 CORRECTIF : classification par CÔTÉ DE ZÉRO + sens de déplacement, plus par signe brut
// de Target seul (l'ancienne version se trompait lors d'une traversée de zéro rapide).
IF (Current >= 0.0 AND Target >= Current) OR (Current <= 0.0 AND Target <= Current) THEN
    StepX := AccelRate * CycleTimeS; // S'éloigne du zéro (reste du même côté, va plus loin)
ELSE
    StepX := DecelRate * CycleTimeS; // Retourne vers zéro, ou le traverse vers l'autre signe
END_IF;

// Application de la rampe
IF Current < Target THEN
    Current := Current + StepX;
    IF Current > Target THEN Current := Target; END_IF;
ELSIF Current > Target THEN
    Current := Current - StepX;
    IF Current < Target THEN Current := Target; END_IF;
END_IF;
