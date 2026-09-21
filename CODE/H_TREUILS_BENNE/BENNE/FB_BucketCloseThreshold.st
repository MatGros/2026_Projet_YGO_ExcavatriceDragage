(* ═══════════════════════════════════════════════════════════════
   🎛️ FB_BucketCloseThreshold — Seuil d'ouverture benne déclarant la fermeture atteinte
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : dériver d'un pourcentage d'ouverture benne restante une DISTANCE de
             fermeture équivalente (m) et le signal `Reached` qui autorise
             l'anticipation de la fin de fermeture de benne.
   📄 Traçabilité : DOC/WFLOW/ (contrat et plan de la phase de câblage du seuil).

   🔬 Conversion pourcentage -> mètres :
             Distance_M = (ThresholdPct / 100) x (OffsetCloseM - OffsetOpenM)
             La plage est la géométrie VIVANTE persistée (jamais 15,0 m en dur : les
             valeurs OffsetOpenM / OffsetCloseM sont réglables à l'IHM et sauvegardées).
             Convention identique à FB_Bucket.BucketOpening_Pct : 0 % = benne fermée
             (Delta = OffsetCloseM), 100 % = benne ouverte.

   🛡️ Nature de la branche — ADDITIVE, JAMAIS SUBSTITUTIVE :
             Ce FB ne remplace ni la tolérance matière de 2,0 m du programme
             principal, ni l'anticipation de fermeture CloseAnticipationM de
             FB_Bucket. Ces deux expressions restent la condition de référence ;
             `Reached` est une DISJONCTION ajoutée à chacune.
             ⇒ Le réglage ne peut jamais RESSERRER le critère existant : il ne
             peut que l'avancer.

   🔒 Réglage à 0 : la branche est INACTIVE par CONSTRUCTION (Active = FALSE),
             donc `Reached` reste FALSE en toutes circonstances et les deux sites
             consommateurs retrouvent leur comportement d'origine.

   ⚠️ Plage utile : le plancher historique de 1,2 m reste le terme contraignant
             jusqu'à 8 % ; l'effet du réglage commence à 9 %. Information destinée
             à l'IHM : un réglage inférieur à 8 % ne produit aucun changement.

   🧩 Dépendances : AUCUNE (FB PUR : sans état, sans timer, sans GVL).
             Il ne lit ni GVL_IHM, ni FB_Bucket, ni le cycle : la configuration lui
             est transmise par l'appelant (PRG_04), producteur unique.
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK FB_BucketCloseThreshold
VAR_INPUT
    // === RÉGLAGE OPÉRATEUR (source : GVL_IHM.CycleSemiAuto.Cfg.ExtractionStartOpening_Pct) ===
    ThresholdPct        : INT;   // 🎛️ Ouverture benne restante (%) déclarant la fermeture atteinte ; 0 = branche INACTIVE

    // === GÉOMÉTRIE BENNE (source : _BucketCfgPersist.Config — plage VIVANTE) ===
    OffsetOpenM         : REAL;  // 📐 Référence benne OUVERTE (m) — Delta = OffsetOpenM à 100 % d'ouverture
    OffsetCloseM        : REAL;  // 📐 Référence benne FERMÉE (m) — Delta = OffsetCloseM à 0 % d'ouverture

    // === MESURE ET QUALIFICATION ===
    DeltaPosition_M     : REAL;  // 📏 Écart mesuré M2 - M1 (m) — MESURE brute de FB_Bucket
    MeasureValid        : BOOL;  // 🛡️ instBucket.ActiveOffsetValid : géométrie, références, puissance, absence de défaut
    IsIntermediate      : BOOL;  // 🛡️ _BucketState.IsIntermediate : mesure dans la bande plausible (hors sur-ouverture/sur-fermeture)
END_VAR

VAR_OUTPUT
    // === DÉCISION ===
    Reached             : BOOL;  // 🚦 Seuil ATTEINT sur mesure qualifiée ce scan — consommé par FB_Bucket ET PRG_04 (même signal, aucun duplicata)

    // === DIAGNOSTIC / IHM ===
    Active              : BOOL;  // 🎛️ Branche seuil ARMÉE ce scan (réglage > 0 ET mesure qualifiée) — FALSE à 0 %
    Distance_M          : REAL;  // 📐 Distance de fermeture équivalente au réglage (m) — 0,0 si réglage nul ou géométrie inexploitable
END_VAR

VAR CONSTANT
    // === BORNES DU RÉGLAGE ===
    // ⚠️ La borne haute est IDENTIQUE à celle du bornage aval de PRG_07_Supervision.
    //    Elle est RÉPÉTÉE ici en défense en profondeur (ce FB est appelé dans la tâche
    //    rapide ; il ne fait jamais confiance au seul bornage amont, qui pourrait être
    //    contourné par un forçage ou un download partiel). Le garde-fou G515 vérifie que
    //    les DEUX bornes restent égales : toute divergence fait échouer le gate.
    CST_MaxThresholdPct : INT  := 50;     // 🎛️ Borne haute du réglage (%)
    CST_MinSpan_M       : REAL := 0.001;  // 📐 Débattement minimal exploitable (m) — MÊME prédicat que FB_Bucket §4a
    CST_PctToRatio      : REAL := 0.01;   // 📐 Conversion pourcentage -> rapport (1 % = 0,01)
END_VAR

VAR
    // === INTERNES (aucune mémoire : le FB est PUR) ===
    ThresholdEffPct     : INT;   // . [LOC] Réglage borné 0..CST_MaxThresholdPct
    Span_M              : REAL;  // . [LOC] Débattement benne = OffsetCloseM - OffsetOpenM (m)
END_VAR


{region "🎛️ T262-B SEUIL DE FERMETURE BENNE"}
// Sorties remises à l'état neutre AVANT toute décision : à 0 %, le FB ne peut
// RIEN autoriser, quel que soit l'état de ses entrées (AC2).
Reached    := FALSE;
Active     := FALSE;
Distance_M := 0.0;

// ─── Garde de géométrie (AC5) ──────────────────────────────────────────────────────
// Prédicat IDENTIQUE à celui de FB_Bucket.st §4a (`(Config.OffsetCloseM - Config.OffsetOpenM) > 0.001`).
// Justification : quand la géométrie est inexploitable, FB_Bucket REPLIE son ouverture
// affichée à 0,0 % (FB_Bucket.st:676-681) — ce zéro est un ARTEFACT de repli, il ne
// constitue JAMAIS une preuve de fermeture (PLAN_T262 lignes 120-122). Sans cette
// garde, un seuil lu sur une configuration invalide autoriserait un transfert.
Span_M := OffsetCloseM - OffsetOpenM;
IF Span_M > CST_MinSpan_M THEN

    // Bornage en défense en profondeur, identique au bornage aval.
    ThresholdEffPct := LIMIT(0, ThresholdPct, CST_MaxThresholdPct);

    // ─── Branche ADDITIVE : inactive à 0 % par construction (AC2) ──────────────────
    IF ThresholdEffPct > 0 THEN
        Distance_M := INT_TO_REAL(ThresholdEffPct) * Span_M * CST_PctToRatio;

        // Qualification de la mesure (AC5) : la branche ne peut jamais s'appuyer sur
        // une mesure non fiable, une puissance absente, un défaut, ou une position
        // hors de la bande plausible (sur-ouverture / sur-fermeture).
        IF MeasureValid AND IsIntermediate THEN
            Active  := TRUE;
            // Égalité INCLUSE : « atteindre le pourcentage » (contrat parent AC3).
            Reached := DeltaPosition_M >= (OffsetCloseM - Distance_M);
        END_IF;
    END_IF;

END_IF;
{endregion}
END_FUNCTION_BLOCK
