(* ═══════════════════════════════════════════════════════════════
   📐 FB_DriftGuard — Détection de dérive de position pendant armement
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie9_Fonction_Winch_v1.6.md §4quinquies (Méca A/C)
   🧩 Brique réduite (Partie3 §1bis) — factorise la logique commune à Méca A et
      Méca C de FB_Safety_Winch (armement + capture position référence + calcul
      dérive), suite audit REX 2026-07-08 : ~15 lignes identiques dans les 2 cas.
   📂 REX 2026-07-08 (2) : placé dans CODE/WINCH/ (pas COMMUN) — son seul
      consommateur réel est FB_Safety_Winch (2 instances, Méca A et C, dans le
      MÊME FB). COMMUN est réservé aux briques à usage cross-domaine AVÉRÉ
      (ex. FB_Brake, réutilisé par Winch ET Translation aujourd'hui) — pas à un
      usage hypothétique futur. À remonter en COMMUN le jour où un autre
      domaine (ex. FB_Safety_Translation) l'utilise réellement.
   🎯 Rôle : tant que Arm=TRUE, mémorise la position au moment du premier cycle
      armé (RefPosM), puis calcule en continu la dérive absolue par rapport à
      cette référence. Violation si la dérive dépasse ToleranceM.
   ⚠️ Ne fait AUCUNE vérification de vitesse (Méca A ajoute son propre check
      vitesse en plus, câblé en OR par l'appelant — hors périmètre de cette
      brique, qui ne gère QUE la dérive de position).
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du POU FB_DriftGuard) ===

FUNCTION_BLOCK PUBLIC FB_DriftGuard
VAR_INPUT
    Arm         : BOOL;   // Condition d'armement (calculée par l'appelant, ex. FwdRevSpeedFeedbackOff AND BrakeFeedback)
    PositionM   : REAL;   // Position courante à surveiller
    ToleranceM  : REAL;   // Tolérance de dérive (m) au-delà de laquelle Violation se déclenche
END_VAR
VAR_OUTPUT
    RefPosM     : REAL;   // Position de référence capturée à l'armement (diagnostic/IHM)
    DriftM      : REAL;   // Dérive absolue courante (m), 0.0 si non armé
    Violation   : BOOL;   // TRUE si DriftM > ToleranceM pendant que Arm=TRUE
END_VAR
VAR
    WasArmed    : BOOL;   // Détecte le passage FALSE→TRUE de Arm (1er cycle armé)
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_DriftGuard) ===

IF Arm THEN
    IF NOT WasArmed THEN
        RefPosM := PositionM;   // Capture au 1er cycle armé uniquement
        WasArmed := TRUE;
    END_IF;
    DriftM := ABS(PositionM - RefPosM);
    Violation := DriftM > ToleranceM;
ELSE
    WasArmed := FALSE;
    DriftM := 0.0;
    Violation := FALSE;
END_IF;
