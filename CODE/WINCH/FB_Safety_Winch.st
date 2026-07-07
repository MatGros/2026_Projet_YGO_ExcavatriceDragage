(* ═══════════════════════════════════════════════════════════════
   🔌 FB_Safety_Winch — Bloc safety MÉTIER du domaine Treuils (M1/M2)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie9_Fonction_Winch_v1.1.md,
                   DOC/AF_Partie10_Fonction_Encoder_Homing_v1.6.md §7
                   (contrat : DOC/AF_Partie3_Template_FB_Commun_v1.2.md §1/§7bis)
   🛡️ Interface STANDARD COMPLÈTE (Partie3 §1) : FB_Safety_<Metier> est
      un FB métier à part entière (pas une brique réduite).
   📤 Sortie maîtresse SafeStop : consommée en entrée par le FB_Winch
      DU MÊME TREUIL (instSafetyWinchM1→instWinchM1, idem M2).
   ⚠️ ÉVOLUTION (lot Codeur, 2026-07-02) : `FB_Safety_Winch` reste UN
      SEUL type FB — le "split M1/M2" acté en Partie10 §7 s'obtient par
      DEUX INSTANCES (`instSafetyWinchM1`/`instSafetyWinchM2`), chacune
      câblée sur l'`EncoderAvailable` de SON treuil (pas deux FB
      distincts — composition, pas duplication de code).
      - ✅ Détecte la perte joystick/CAN (sans commande valide, un
        treuil ne doit pas pouvoir bouger).
      - ✅ Détecte la perte codeur DE CE TREUIL (`EncoderAvailable`,
        sortie `FB_Encoder_Abs` — désormais câblée, ErrorId bit1).
      - 🔴 TBD (non simulé) : perte bus EtherCAT spécifique (au-delà de
        ce que `EncoderAvailable` reflète déjà, si besoin d'un signal
        distinct plus tard).
      - `PowerCutOff` : FALSE pour ce lot (pas encore de
        ST_ContactorCheck de puissance câblé — FB_Output
        transverse hors périmètre de ce lot, voir Partie6).
   🆕 AJOUT (2026-07-02, retour terrain — nouvel export Device.export avec
      I/O réel `M1_ThermalFeedback`/`M2_ThermalFeedback` et
      `M1_M2_SlackCableSwitch`, demande utilisateur) — Partie9 §4ter :
      - ✅ `ThermalFeedback` (par instance, retour thermique CE moteur) :
        défaut → bit2 ErrorId → `SafeStop` (arrêt total, protection moteur,
        comme les autres défauts du domaine).
      - ✅ `SlackCableDetected` (COMMUN aux 2 treuils, même capteur — même
        principe que `M1_M2_TopPositionSensor`, câblé IDENTIQUEMENT sur
        les 2 instances) : mou de câble détecté (descente non arrêtée à
        temps) → bit3 ErrorId (visible IHM, reset front requis dès que la
        cause disparaît) → sortie **`ForbidDescent`** DÉDIÉE, DISTINCTE de
        `SafeStop` — bloque UNIQUEMENT la descente (`FB_Winch.RelayRev`),
        la remontée (`RelayFwd`) reste libre pour permettre à l'opérateur
        d'aller vérifier le câblage. Nouveau pattern (pas un simple
        `SafeStop`, qui aurait arrêté les 2 sens) — voir Partie9 §4ter
        pour la justification complète.
   🔴🔧 REX 2026-07-07 — IMPLÉMENTATION DU CAS B (roue libre) + 2 NOUVEAUX GARDE-FOUS
      (demande utilisateur, suite à la consolidation du feedback contacteur unique) :
      - **Bit7 — Méca A "mouvement non commandé général"** : arme une surveillance
        position/vitesse dès que `FwdRevSpeedFeedbackOff AND BrakeFeedback` (tout
        confirmé physiquement coupé). Si pendant que c'est armé, la vitesse mesurée
        codeur dépasse `UncommandedSpeedThresholdMps` (0.02 m/s, théorique — à
        ajuster sur site) OU la position dérive de plus de `UncommandedDriftToleranceM`
        (2.0 m) par rapport à la référence prise à l'armement → défaut → `SafeStop`
        ET `PowerCutOff` (les contacteurs sont déjà confirmés coupés, `SafeStop` seul
        ne suffit pas — c'est le rôle de `PowerCutOff`).
      - **Bit8 — Méca B "pilotage actif malgré absence de commande opérateur"** :
        indépendant de la logique interne FB_Winch (défense en profondeur — reste
        valable même si l'arbitrage FB_Winch est en défaut). Si (perte CAN joystick,
        bit0 déjà existant) OU (joystick au neutre, `JoystickYNeutral`) ET que
        `FwdRevSpeedFeedbackOff` ne repasse PAS à `TRUE` dans `PostRampTimeout` (3s,
        théorique) → défaut → `SafeStop` ET `PowerCutOff`.
      - **Bit9 — Méca C "glissement M1 pendant mouvement Grappin" (escalade)** :
        armé UNIQUEMENT si `GrappinHoldStillActive=TRUE` (câblé sur `instGrappin.Busy`
        pour l'instance M1 SEULEMENT — toujours `FALSE` côté M2, qui doit bouger
        pendant le grappin). Référence position prise à l'armement ; si dérive
        `GrappinSlipToleranceM` (2.0 m, > à la tolérance 1.0 m déjà surveillée côté
        `FB_Grappin` lui-même) dépassée → la couche Grappin (`SafeStop` M1 seul, 1m)
        n'a pas suffi → escalade `PowerCutOff` (dernier recours).
      Cas A (sens opposé) et Cas C original (absence de mouvement malgré commande)
      restent TBD, non implémentés (sources encore manquantes : sens joystick brut).
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du POU FB_Safety_Winch) ===

FUNCTION_BLOCK PUBLIC FB_Safety_Winch
VAR_INPUT
    Enable              : BOOL;        // Active la surveillance
    Reset               : BOOL;        // Front acquittement défauts
    EmergencyStopOk     : BOOL;        // Chaîne AU réarmée + conditions globales OK (info de contexte)
    Mode                : E_Mode;      // Mode courant (autorisations)
    OverrideSync        : BOOL;        // 🆕 OverrideSync actif (MAINT N1/N2) → désactive synchro ET lève SafeStop mou câble (procédure récupération manuelle)
    JoystickOnline      : BOOL;        // instDiagCanOpen.Joystick.Online
    JoystickOperational : BOOL;        // instDiagCanOpen.Joystick.Operational
    EncoderAvailable    : BOOL;        // Sortie FB_Encoder_Abs DU TREUIL concerné par cette instance
    ThermalFeedback     : BOOL;        // Retour TOR thermique CE moteur (NC) — TRUE = surchauffe (NOT PRG_00_Inputs.M1/M2ThermalFeedback)
    SlackCableDetected  : BOOL;        // Mou câble sur tambour M2 (NC, câblé sur les 2 instances) : TRUE=mou détecté → SafeStop sauf si OverrideSync
    PhaseRotationOk     : BOOL;        // PRG_00_Inputs.PhaseRotationOk (commun) — TRUE = rotation phases correcte
    TopPositionSensor   : BOOL;        // Capteur position haute (NC commun) — TRUE=libre, FALSE=butée atteinte
    InReferencingMode   : BOOL;        // TRUE si treuil en cours de homing (référencement)
    CablePosM           : REAL;        // Position actuelle câble en mètres (scalée)
    CableLimitDescentM  : REAL;        // Limite basse physique descente en mètres (valeur négative)

    // 🔧 REX 2026-07-07 — Méca A/B/C (voir bandeau en-tête)
    FwdRevSpeedFeedbackOff  : BOOL;         // Retour unique "tous contacteurs sens+vitesse retombés" CE treuil
    BrakeFeedback           : BOOL;         // Retour frein CE treuil (TRUE = serré/collé)
    JoystickYNeutral        : BOOL;         // TRUE = joystick axe Y au neutre (magnitude ~0), précalculé en amont
    GrappinHoldStillActive  : BOOL;         // TRUE seulement pour l'instance M1 pendant que le grappin bouge M2 seul (instGrappin.Busy) — toujours FALSE côté M2
    UncommandedSpeedThresholdMps : REAL := 0.02; // 🔧 Méca A — théorique, à ajuster sur site
    UncommandedDriftToleranceM   : REAL := 2.0;  // 🔧 Méca A — théorique, à ajuster sur site
    PostRampTimeout              : TIME := T#3S; // 🔧 Méca B — théorique, à ajuster sur site
    GrappinSlipToleranceM        : REAL := 2.0;  // 🔧 Méca C — escalade safety (> 1.0 m déjà surveillé côté FB_Grappin)
END_VAR
VAR_OUTPUT
    Ready               : BOOL;
    Busy                : BOOL;
    Done                : BOOL;
    Error               : BOOL;
    ErrorId             : WORD;        // bit0:joystick/CAN perdu ; bit1:codeur perdu ; bit2:surchauffe ; bit3:mou câble M2 (SafeStop ou ForbidAscent si OverrideSync) ; bit4:phases élec. ; bit5:fin course haut ; bit6:longueur max câble ; bit7:Méca A mouvement non commandé ; bit8:Méca B pilotage sans commande opérateur ; bit9:Méca C glissement M1/grappin (escalade)
    State               : E_State;
    StateAtError        : E_State;
    SafeStop            : BOOL;        // 🟧 Arrêt rapide 2 sens (Enable maintenu) — bits 0/1/2/3/4 (mou câble inclus SAUF si OverrideSync)
    ForbidDescent       : BOOL;        // ⬇️ Interdit descente uniquement — bit6 (limite basse câble)
    ForbidAscent        : BOOL;        // ⬆️ Interdit montée uniquement — bit5 (fin course haut) OU bit3+OverrideSync (récupération mou câble)
    PowerCutOff         : BOOL;        // 🧨 Coupure puissance amont (FALSE, TBD ce lot)
END_VAR
VAR
    ResetEdge           : R_TRIG;
    ErrorEdge           : R_TRIG;

    // 🔧 REX 2026-07-07 — Méca A (bit7)
    CycleTimeCalc       : FB_CycleTime;
    LastCablePosM       : REAL;
    MeasuredSpeedMps    : REAL;
    MecaA_Armed         : BOOL;
    MecaA_RefPosM       : REAL;

    // 🔧 REX 2026-07-07 — Méca B (bit8)
    MecaB_NoOperatorCmd : BOOL;         // (perte CAN joystick) OU (joystick au neutre)
    TonMecaB            : TON;

    // 🔧 REX 2026-07-07 — Méca C (bit9, escalade)
    MecaC_Armed         : BOOL;
    MecaC_RefPosM       : REAL;
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_Safety_Winch) ===

// 🛑 1. GATE — sécurité par défaut : pas de surveillance active = arrêt forcé du domaine
IF NOT Enable OR NOT EmergencyStopOk THEN
    Ready := FALSE;
    SafeStop := TRUE;              // Fail-safe : tant que la surveillance n'est pas garantie, on arrête
    ForbidDescent := TRUE;         // Fail-safe : cohérent avec SafeStop (descente a fortiori interdite)
    PowerCutOff := FALSE;
    State := E_State.DISABLED;
    MecaA_Armed := FALSE;          // 🔧 REX 2026-07-07 : désarme, repart propre à la prochaine activation
    MecaC_Armed := FALSE;
    RETURN;
END_IF;

Ready := TRUE;
State := E_State.READY;
CycleTimeCalc(DefaultValueS := 0.010); // 🔧 REX 2026-07-07 — Méca A

// 🔑 2. RESET FRONT — efface le bit dont la cause a disparu
ResetEdge(CLK := Reset);

// 🔍 3. DIAGNOSTIC DU DOMAINE TREUIL
IF NOT JoystickOnline OR NOT JoystickOperational THEN
    ErrorId := ErrorId OR 16#0001;       // Perte joystick/CAN : pas de commande opérateur valide
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFFE;
END_IF;

// 🔍 3bis. PERTE CODEUR DE CE TREUIL (câblé — lot Codeur 2026-07-02)
IF NOT EncoderAvailable THEN
    ErrorId := ErrorId OR 16#0002;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFFD;
END_IF;

// 🔍 3ter. SURCHAUFFE MOTEUR (câblé — I/O réel 2026-07-02) — bit2, participe au SafeStop total
IF ThermalFeedback THEN
    ErrorId := ErrorId OR 16#0004;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFFB;
END_IF;

// 🔍 3quater. MOU DE CÂBLE (physiquement sur tambour M2, câblé sur les 2 instances Safety)
// Mode NORMAL (OverrideSync=FALSE) → SafeStop M1+M2 (bit3 inclus dans SafeStop)
// Mode RÉCUPÉRATION (OverrideSync=TRUE) → ForbidAscent uniquement (montée interdite, descente OK)
IF SlackCableDetected THEN
    ErrorId := ErrorId OR 16#0008;
ELSIF ResetEdge.Q AND NOT SlackCableDetected THEN
    ErrorId := ErrorId AND 16#FFF7;
END_IF;

// 🔍 3quinquies. ROTATION DE PHASE (câblé — I/O réel, commun M1/M2, 2026-07-03octodecies) —
// bit4, participe au SafeStop total (sens moteur potentiellement inversé, danger 2 sens).
IF NOT PhaseRotationOk THEN
    ErrorId := ErrorId OR 16#0010;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFEF;
END_IF;

// 🔍 3sexties. FIN DE COURSE HAUT / CAPTEUR DE POSITION HAUTE (anti-débordement) — bit5
// ⚠️ Convention NAMING_CONVENTION.md : TopPositionSensor TRUE = sain/non atteint (NF), FALSE =
// position haute réellement atteinte (contact ouvert). Si la position haute EST atteinte
// (TopPositionSensor=FALSE) ET qu'on n'est pas en phase de référencement (homing), alors on lève
// le défaut pour interdire uniquement la montée. 🔧 CORRIGÉ 2026-07-04 : polarité inversée
// (testait TopPositionSensor au lieu de NOT TopPositionSensor), bloquait la montée en permanence
// en fonctionnement normal au lieu de la bloquer au fin de course haut.
IF NOT TopPositionSensor AND NOT InReferencingMode THEN
    ErrorId := ErrorId OR 16#0020;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFDF;
END_IF;

// 🔍 3septies. LONGUEUR MAX DE CÂBLE (profondeur max autorisée) — bit6
// Sécurité active tout le temps. Si la position de câble descend sous la limite basse physique (CablePosM <= CableLimitDescentM),
// alors on interdit uniquement la descente.
IF (CableLimitDescentM < 0.0) AND (CablePosM <= CableLimitDescentM) THEN
    ErrorId := ErrorId OR 16#0040;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFBF;
END_IF;

// 🔍 3octies. MÉCA A — MOUVEMENT NON COMMANDÉ GÉNÉRAL (REX 2026-07-07) — bit7
// Armé quand tout est physiquement confirmé coupé (contacteurs + frein). Si dérive ou vitesse
// détectée pendant que c'est armé → roue libre / frein insuffisant.
MeasuredSpeedMps := ABS(CablePosM - LastCablePosM) / CycleTimeCalc.CycleTimeS;
LastCablePosM := CablePosM;

IF FwdRevSpeedFeedbackOff AND BrakeFeedback THEN
    IF NOT MecaA_Armed THEN
        MecaA_Armed := TRUE;
        MecaA_RefPosM := CablePosM;   // Référence prise au moment de l'armement
    END_IF;
ELSE
    MecaA_Armed := FALSE;
END_IF;

IF MecaA_Armed AND ((MeasuredSpeedMps > UncommandedSpeedThresholdMps)
                     OR (ABS(CablePosM - MecaA_RefPosM) > UncommandedDriftToleranceM)) THEN
    ErrorId := ErrorId OR 16#0080;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FF7F;
END_IF;

// 🔍 3nonies. MÉCA B — PILOTAGE ACTIF SANS COMMANDE OPÉRATEUR (REX 2026-07-07) — bit8
// Indépendant de FB_Winch (défense en profondeur). Perte CAN (bit0) OU joystick au neutre ;
// si les contacteurs ne confirment pas être retombés dans PostRampTimeout, défaut.
MecaB_NoOperatorCmd := (NOT JoystickOnline) OR (NOT JoystickOperational) OR JoystickYNeutral;
TonMecaB(IN := MecaB_NoOperatorCmd AND NOT FwdRevSpeedFeedbackOff, PT := PostRampTimeout);
IF TonMecaB.Q THEN
    ErrorId := ErrorId OR 16#0100;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FEFF;
END_IF;

// 🔍 3decies. MÉCA C — GLISSEMENT M1 PENDANT GRAPPIN, ESCALADE (REX 2026-07-07) — bit9
// Armé UNIQUEMENT pour l'instance M1 (GrappinHoldStillActive câblé sur instGrappin.Busy côté M1
// seulement, toujours FALSE côté M2). Tolérance plus large que celle de FB_Grappin (1.0 m) —
// n'intervient que si la couche Grappin (SafeStop M1 seul) n'a pas suffi.
IF GrappinHoldStillActive THEN
    IF NOT MecaC_Armed THEN
        MecaC_Armed := TRUE;
        MecaC_RefPosM := CablePosM;
    END_IF;
ELSE
    MecaC_Armed := FALSE;
END_IF;

IF MecaC_Armed AND (ABS(CablePosM - MecaC_RefPosM) > GrappinSlipToleranceM) THEN
    ErrorId := ErrorId OR 16#0200;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FDFF;
END_IF;

// 📤 4. ARBITRAGE DES SORTIES MAÎTRESSES
Error := (ErrorId <> 16#0000);       // 🧭 Partie3 §4 : miroir de TOUT le domaine, y compris mou de câble (visible IHM)
ErrorEdge(CLK := Error);
IF ErrorEdge.Q THEN
    StateAtError := State;
END_IF;

// 🟧 SafeStop : bits 0/1/2/3/4 (joystick, codeur, thermique, MOU CÂBLE, phases) + 7/8/9 (REX
// 2026-07-07 — Méca A/B/C, jamais exclus par OverrideSync, sans rapport avec la récupération mou câble)
// ⚠️ bit3 (mou câble) est EXCLU du SafeStop si OverrideSync=TRUE (procédure récupération manuelle)
IF OverrideSync THEN
    SafeStop := (ErrorId AND 16#0397) <> 16#0000;   // bit3 exclu → SafeStop normal sans mou câble
ELSE
    SafeStop := (ErrorId AND 16#039F) <> 16#0000;   // bit3 inclus → SafeStop complet avec mou câble
END_IF;

// ⬇️ ForbidDescent : bit6 uniquement (limite basse câble). Le mou câble → SafeStop (pas ForbidDescent)
ForbidDescent := (ErrorId AND 16#0040) <> 16#0000;

// ⬆️ ForbidAscent : bit5 (fin course haut) OU bit3+OverrideSync (récupération mou câble : montée interdite même en récup)
ForbidAscent := (ErrorId AND 16#0020) <> 16#0000
             OR ((ErrorId AND 16#0008) <> 16#0000 AND OverrideSync);

// 🧨 REX 2026-07-07 : PowerCutOff enfin réel — bits 7/8/9 (Méca A/B/C, voir bandeau en-tête).
// Coupure puissance amont : les contacteurs locaux sont déjà confirmés coupés/insuffisants,
// SafeStop seul ne sert à rien dans ces 3 cas précis.
PowerCutOff := (ErrorId AND 16#0380) <> 16#0000;

// Busy, Done non utilisés mais présents pour conformité (comme FB_DiagCanOpen)
Busy := FALSE;
Done := FALSE;
