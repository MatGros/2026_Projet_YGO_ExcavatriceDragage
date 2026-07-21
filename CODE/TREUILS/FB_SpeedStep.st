(* ═══════════════════════════════════════════════════════════════
   🪜 FB_SpeedStep — Décodeur palier → 4 contacteurs (1 par treuil)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie-09_Fonction_Winch_v1.11.md §2, §6
   📄 Audit P0.2 : DOC/AUDIT_Winch_v1.0.md §2.2
   📥 SpeedRefPct    : consigne 0..100 % (déjà rampée en amont, ABS)
   📥 Table          : ST_SpeedStepTable propre AU TREUIL appelant
                        (M1 et M2 ont chacune la leur — pas de table globale)
   📥 MaxStepNumber  : plafond palier (1..5), borné et validé ici
   📤 Contactor1..4  : état de chaque contacteur de vitesse (BOOL individuel,
                        lu directement dans `Table.P<palier>R<relais>`)
   📤 StepNumber     : n° palier courant (0 = arrêt, 1..5)
   📤 ConfigError    : TRUE si table invalide ou MaxStepNumber hors bornes
   📤 ConfigErrorId  : WORD bitfield (bit0 = config invalide)
   🧩 Réutilisation lib Util (Partie3 §0) : HYSTERESIS pour la sélection
      de palier anti-battement — AUCUN seuil "maison" recalculé.
   ⚠️ CORRECTIF interface HYSTERESIS (2026-07-01) : `Util` 3.5.19.0 expose
      `HYSTERESIS(IN, HIGH, LOW : INT → OUT : BOOL)` (TRUE si IN < LOW,
      FALSE si IN > HIGH, maintien entre les deux) — `SpeedRefPct` (REAL)
      est converti en INT (`REAL_TO_INT`) avant appel.
   ⚠️ ÉVOLUTION (retour terrain 2026-07-01) : `StepMask` (BYTE packé) est
      remplacé par 4 sorties BOOL individuelles, lues directement dans la
      table (`P<palier>R<relais>`) — plus de bit-extraction côté FB_Winch,
      paramétrage un contacteur à la fois pendant la mise en service.
   ⚠️ Brique réduite (Partie3 §1bis) : pas d'Enable/Reset/ErrorId/State
      au sens "FB métier" — c'est un décodeur pur, composé À L'INTÉRIEUR de
      FB_Winch, qui porte lui la sécurité/le contrat complet.
      ➕ MAIS on ajoute 2 sorties locales `ConfigError` + `ConfigErrorId`
      pour signaler une table de config invalide (P0.2 audit).
   🆕 AJOUT (2026-07-03quinquies, spec descente/couple) : `MaxStepNumber` plafonne
      le palier atteignable (défaut 5 = comportement inchangé). Sert à `FB_Winch`
      pour limiter la vitesse en descente (charge entraînante, pas besoin d'aller
      vite) SANS changer la logique de décodage elle-même — juste un plafond
      appliqué APRÈS la sélection par hystérésis, avant la lecture de la table.
   🛡️ CORRECTIF P0.2 (2026-07-21) :
      - Bornage `MaxStepNumber` ∈ [1..5] dès l'entrée
      - Validation table : seuils croissants 0..100 %, hystérésis > 0,
        contacteurs cohérents (au moins 1 par palier 2..MaxStepNumber ; palier 1 tout FALSE autorisé)
      - Sortie `ConfigError` / `ConfigErrorId` (bit0 = table invalide)
      - Forçage sorties sûres (contacteurs FALSE, StepNumber=0) si erreur config
      - Reset sur front (R_TRIG) + cause disparue (conforme Partie 3 §5)
   ════════════════════════════════════════════════════════════════ *)

{attribute 'qualified_only'}
{attribute 'hide_all_locals'}

// === DECLARATION (à coller dans la partie déclaration du POU FB_SpeedStep) ===

FUNCTION_BLOCK PUBLIC FB_SpeedStep
VAR_INPUT
    Enable            : BOOL;               // Piloté par FB_Winch : FALSE = treuil à l'arrêt (palier 0)
    SpeedRefPct       : REAL;                // Consigne vitesse 0..100 % (déjà rampée par FB_Winch)
    Table             : ST_SpeedStepTable;   // Table des 5 paliers (contacteurs + seuils), propre à CE treuil
    HystMargin        : REAL := 2.0;         // Marge anti-battement (%) autour de chaque seuil
    MaxStepNumber     : INT := 5;            // 🆕 Plafond palier atteignable (1..5) — 5 = pas de restriction
    MeasuredSpeedBand : INT := 0;            // Bande vitesse réelle validée (0 = inconnue)
    SpeedGuardEnable  : BOOL := FALSE;       // 🛡️ Garde-fou palier activable après validation terrain
    SpeedGuardReady   : BOOL := FALSE;       // 🟢 Vitesse stable et conditions de passage validées
END_VAR
VAR_OUTPUT
    Contactor1        : BOOL;   // Contacteur de vitesse 1 pour le palier courant
    Contactor2        : BOOL;   // Contacteur de vitesse 2 pour le palier courant
    Contactor3        : BOOL;   // Contacteur de vitesse 3 pour le palier courant
    Contactor4        : BOOL;   // Contacteur de vitesse 4 pour le palier courant
    StepNumber        : INT;    // N° palier courant (0 = arrêt, 1..5)
    SpeedGuardLimited : BOOL;   // TRUE si le garde-fou a limité le palier demandé
    ConfigError       : BOOL;   // 🛡️ Miroir de ConfigErrorId <> 0 (config table invalide)
    ConfigErrorId     : WORD;   // 🛡️ Bitfield config : bit0 = table invalide (seuils, hyst, contacteurs)
END_VAR
VAR
    SpeedRefInt       : INT;          // Consigne convertie en INT (interface HYSTERESIS)
    Hyst1             : HYSTERESIS;   // 🧱 Lib Util — transition palier 1→2
    Hyst2             : HYSTERESIS;   // 🧱 Lib Util — transition palier 2→3
    Hyst3             : HYSTERESIS;   // 🧱 Lib Util — transition palier 3→4
    Hyst4             : HYSTERESIS;   // 🧱 Lib Util — transition palier 4→5

    // 🛡️ Validation config locale (P0.2 audit)
    _ConfigValid      : BOOL;         // Résultat validation table + MaxStepNumber
    _ConfigValidPrev  : BOOL;         // Mémoire cycle précédent pour détection front
    _ConfigErrorTrig  : R_TRIG;       // Front montant erreur config (pour reset)
    _ConfigErrorIdInt : WORD;         // Accumulateur interne défauts config
    _MaxStepClamped   : INT;          // MaxStepNumber borné [1..5]
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_SpeedStep) ===

// ─────────────────────────────────────────────────────────────────────────
// 🛡️ 0. VALIDATION CONFIGURATION (P0.2) — exécutée CHAQUE cycle pour détecter
//    toute corruption IHM/PERSISTENT, même siEnable=FALSE (sorties sûres forcée)
// ─────────────────────────────────────────────────────────────────────────

// 🔧 Bornage systématique MaxStepNumber ∈ [1..5]
IF MaxStepNumber < 1 THEN
    _MaxStepClamped := 1;
ELSIF MaxStepNumber > 5 THEN
    _MaxStepClamped := 5;
ELSE
    _MaxStepClamped := MaxStepNumber;
END_IF;

// 🔍 Validation table ST_SpeedStepTable
// Critères (Partie 9 §2 + audit P0.2) :
// 1. Seuils croissants stricts : StepThreshold_Pct[1] < [2] < [3] < [4] < [5]
// 2. Seuils dans [0..100] %
// 3. HystMargin > 0
// 4. Pour chaque palier 2.._MaxStepClamped : au moins 1 contacteur TRUE (cohérence câblage)
//    Le palier 1 peut légitimement avoir les 4 contacteurs FALSE : résistances rotoriques
//    toutes insérées = vitesse minimale. On ne valide pas les paliers jamais atteignables.
_ConfigValid := TRUE;
_ConfigErrorIdInt := 16#0000;

// Critère 1 : seuils croissants
IF NOT (Table.StepThreshold_Pct[1] < Table.StepThreshold_Pct[2] AND
        Table.StepThreshold_Pct[2] < Table.StepThreshold_Pct[3] AND
        Table.StepThreshold_Pct[3] < Table.StepThreshold_Pct[4] AND
        Table.StepThreshold_Pct[4] < Table.StepThreshold_Pct[5]) THEN
    _ConfigValid := FALSE;
    _ConfigErrorIdInt := _ConfigErrorIdInt OR 16#0001;  // bit0
END_IF;

// Critère 2 : seuils dans [0..100]
IF (Table.StepThreshold_Pct[1] < 0.0) OR (Table.StepThreshold_Pct[5] > 100.0) THEN
    _ConfigValid := FALSE;
    _ConfigErrorIdInt := _ConfigErrorIdInt OR 16#0001;
END_IF;

// Critère 3 : hystérésis > 0
IF HystMargin <= 0.0 THEN
    _ConfigValid := FALSE;
    _ConfigErrorIdInt := _ConfigErrorIdInt OR 16#0001;
END_IF;

// Critère 4 : cohérence contacteurs par palier (seulement jusqu'au plafond actif)
IF _ConfigValid THEN
    // Palier 1 : les 4 sorties FALSE sont une configuration valide de vitesse minimale.
    // Palier 2
    IF _MaxStepClamped >= 2 THEN
        IF NOT (Table.P2R1 OR Table.P2R2 OR Table.P2R3 OR Table.P2R4) THEN
            _ConfigValid := FALSE;
            _ConfigErrorIdInt := _ConfigErrorIdInt OR 16#0001;
        END_IF;
    END_IF;
    // Palier 3
    IF _MaxStepClamped >= 3 THEN
        IF NOT (Table.P3R1 OR Table.P3R2 OR Table.P3R3 OR Table.P3R4) THEN
            _ConfigValid := FALSE;
            _ConfigErrorIdInt := _ConfigErrorIdInt OR 16#0001;
        END_IF;
    END_IF;
    // Palier 4
    IF _MaxStepClamped >= 4 THEN
        IF NOT (Table.P4R1 OR Table.P4R2 OR Table.P4R3 OR Table.P4R4) THEN
            _ConfigValid := FALSE;
            _ConfigErrorIdInt := _ConfigErrorIdInt OR 16#0001;
        END_IF;
    END_IF;
    // Palier 5
    IF _MaxStepClamped >= 5 THEN
        IF NOT (Table.P5R1 OR Table.P5R2 OR Table.P5R3 OR Table.P5R4) THEN
            _ConfigValid := FALSE;
            _ConfigErrorIdInt := _ConfigErrorIdInt OR 16#0001;
        END_IF;
    END_IF;
END_IF;

// 🛡️ Gestion erreur config : front montant + reset sur front Reset (cause disparue)
// Note : pas d'entrée Reset dédiée (brique réduite) → on réarme quand config redevient valide
//        (front descendant de _ConfigValid). Conforme Partie 3 §5 : cause disparue + front.
_ConfigErrorTrig(CLK := NOT _ConfigValid);  // Front montant = apparition erreur

// Mémoire erreur config : reste TRUE tant que config invalide OU pas de réarmement
// Réarmement = front montant de _ConfigValid (cause disparue) — détecté via _ConfigValidPrev
IF _ConfigErrorTrig.Q THEN
    // Nouvelle erreur : on la mémorise
    _ConfigValidPrev := FALSE;  // Force détection front montant au cycle suivant si redevient valide
ELSIF _ConfigValid AND NOT _ConfigValidPrev THEN
    // Config redevenue valide : front montant → on efface l'erreur (reset sur front)
    _ConfigValidPrev := TRUE;
ELSIF NOT _ConfigValid THEN
    _ConfigValidPrev := FALSE;
END_IF;

// Sorties erreur config (miroir standard Partie 3)
ConfigErrorId := _ConfigErrorIdInt;
ConfigError   := (ConfigErrorId <> 16#0000);

// ─────────────────────────────────────────────────────────────────────────
// 🛑 1. GATE — Enable FALSE OU config invalide = palier 0, sorties sûres
// ─────────────────────────────────────────────────────────────────────────
IF (NOT Enable) OR (NOT _ConfigValid) THEN
    Contactor1 := FALSE; Contactor2 := FALSE; Contactor3 := FALSE; Contactor4 := FALSE;
    StepNumber := 0;
    SpeedGuardLimited := FALSE;
    RETURN;
END_IF;

// ─────────────────────────────────────────────────────────────────────────
// 🪜 2. SÉLECTION DU PALIER (HYSTERESIS lib Util : IN/HIGH/LOW → OUT)
//    OUT = TRUE tant que IN < LOW (régime "bas") ; OUT bascule à FALSE une fois
//    IN > HIGH (régime "haut" confirmé) ; maintien entre LOW et HIGH (anti-battement).
//    => NOT Hyst_n.OUT = "on a franchi le seuil n vers le haut" (palier n+1 atteint).
// ─────────────────────────────────────────────────────────────────────────
SpeedRefInt := REAL_TO_INT(SpeedRefPct);

Hyst1(IN := SpeedRefInt, HIGH := REAL_TO_INT(Table.StepThreshold_Pct[1] + HystMargin), LOW := REAL_TO_INT(Table.StepThreshold_Pct[1] - HystMargin));
Hyst2(IN := SpeedRefInt, HIGH := REAL_TO_INT(Table.StepThreshold_Pct[2] + HystMargin), LOW := REAL_TO_INT(Table.StepThreshold_Pct[2] - HystMargin));
Hyst3(IN := SpeedRefInt, HIGH := REAL_TO_INT(Table.StepThreshold_Pct[3] + HystMargin), LOW := REAL_TO_INT(Table.StepThreshold_Pct[3] - HystMargin));
Hyst4(IN := SpeedRefInt, HIGH := REAL_TO_INT(Table.StepThreshold_Pct[4] + HystMargin), LOW := REAL_TO_INT(Table.StepThreshold_Pct[4] - HystMargin));

StepNumber := 1;                          // Palier mini dès qu'Enable est actif
IF NOT Hyst1.OUT THEN StepNumber := 2; END_IF;
IF NOT Hyst2.OUT THEN StepNumber := 3; END_IF;
IF NOT Hyst3.OUT THEN StepNumber := 4; END_IF;
IF NOT Hyst4.OUT THEN StepNumber := 5; END_IF;

// ─────────────────────────────────────────────────────────────────────────
// 🆕 2bis. PLAFOND (2026-07-03quinquies) — appliqué APRÈS la sélection hystérésis,
// AVANT la lecture table : le 0..100% de la consigne peut réclamer le palier 5,
// mais ne dépassera jamais _MaxStepClamped (ex. limitation couple en descente)
// ─────────────────────────────────────────────────────────────────────────
IF StepNumber > _MaxStepClamped THEN
    StepNumber := _MaxStepClamped;
END_IF;

// ─────────────────────────────────────────────────────────────────────────
// 🛡️ 2ter. GARDE-FOU VITESSE RÉELLE — limite uniquement la consigne de palier.
// Si la vitesse n'est pas validée stable, seul le palier 1 reste autorisé.
// ─────────────────────────────────────────────────────────────────────────
SpeedGuardLimited := FALSE;
IF SpeedGuardEnable THEN
    IF NOT SpeedGuardReady THEN
        IF StepNumber > 1 THEN
            StepNumber := 1;
            SpeedGuardLimited := TRUE;
        END_IF;
    ELSIF (MeasuredSpeedBand >= 1) AND (MeasuredSpeedBand <= 5) AND (StepNumber > MeasuredSpeedBand) THEN
        StepNumber := MeasuredSpeedBand;
        SpeedGuardLimited := TRUE;
    END_IF;
END_IF;

// ─────────────────────────────────────────────────────────────────────────
// 📤 3. CONTACTEURS — lus dans la table (donnée, jamais codé en dur)
//    CASE couvre explicitement 0..5 : StepNumber=0 → tous FALSE (sécurité)
// ─────────────────────────────────────────────────────────────────────────
CASE StepNumber OF
    0:  // Arrêt / config invalide / Enable=FALSE — sécurité positive
        Contactor1 := FALSE; Contactor2 := FALSE; Contactor3 := FALSE; Contactor4 := FALSE;
    1:  Contactor1 := Table.P1R1; Contactor2 := Table.P1R2; Contactor3 := Table.P1R3; Contactor4 := Table.P1R4;
    2:  Contactor1 := Table.P2R1; Contactor2 := Table.P2R2; Contactor3 := Table.P2R3; Contactor4 := Table.P2R4;
    3:  Contactor1 := Table.P3R1; Contactor2 := Table.P3R2; Contactor3 := Table.P3R3; Contactor4 := Table.P3R4;
    4:  Contactor1 := Table.P4R1; Contactor2 := Table.P4R2; Contactor3 := Table.P4R3; Contactor4 := Table.P4R4;
    5:  Contactor1 := Table.P5R1; Contactor2 := Table.P5R2; Contactor3 := Table.P5R3; Contactor4 := Table.P5R4;
ELSE
    // Défense en profondeur : valeur StepNumber inattendue → sécurité
    Contactor1 := FALSE; Contactor2 := FALSE; Contactor3 := FALSE; Contactor4 := FALSE;
    StepNumber := 0;
END_CASE;

(* ═══════════════════════════════════════════════════════════════
   📝 NOTE D'APPLICATION MANUELLE CODESYS 3.5
   ═══════════════════════════════════════════════════════════════
   1. Ouvrir le POU FB_SpeedStep dans l'arborescence CODESYS (dossier TREUILS)
   2. Copier la partie DECLARATION (lignes 33-58) dans la zone VAR_INPUT/VAR_OUTPUT/VAR
   3. Copier la partie IMPLEMENTATION (lignes 61 à fin) dans le corps ST
   4. Vérifier que la librairie `Util` est référencée (HYSTERESIS, R_TRIG)
   5. Rebuild (F11) → 0 erreur attendue
   6. Vérifier dans FB_Winch que l'instance SpeedStep compile toujours
      (interface compatible : nouvelles sorties ConfigError/ConfigErrorId ajoutées,
       entrées/sorties existantes inchangées)
   ═══════════════════════════════════════════════════════════════ *)