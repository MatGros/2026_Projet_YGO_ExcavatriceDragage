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
   🔴 TBD — SURVEILLANCE DE COHÉRENCE MOUVEMENT (retour terrain 2026-07-02,
      idée capturée, NON conçue en détail, NON implémentée — détail complet
      dans DOC/AF_Partie9 §4bis). 4 cas DISTINCTS (1 bit ErrorId chacun,
      pas un bit générique) :
      - Cas A — Sens opposé : sens joystick BRUT (avant traitement) ≠ sens
        réel constaté (contacteur et/ou signe vitesse codeur), persistant.
        → câblage inversé / contacteur collé mauvais sens / codeur mal orienté.
      - Cas B — Mouvement non commandé (roue libre) : codeur bouge alors
        qu'AUCUN contacteur de sens n'est engagé. → charge qui tombe, frein
        qui ne tient pas. GRAVITÉ TRÈS ÉLEVÉE, priorité dès codeur dispo.
      - Cas C — Absence de mouvement malgré commande : sens+palier+frein
        relâché confirmés, mais codeur immobile après délai. → blocage
        mécanique / accouplement rompu / défaut invisible à ST_ContactorCheck.
      - Cas D — Fenêtre de tolérance (règle transverse, pas un défaut) :
        ne jamais déclencher pendant le temps normal de rampe+interlock.
      Sources manquantes aujourd'hui : sens joystick brut (RawX/RawY non
      remontés ici), vitesse/signe codeur (Partie10), RelayFwd/RelayRev/
      BrakeCmd de FB_Winch (existent en sortie, pas encore câblés ici).
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
    ThermalFeedback     : BOOL;        // Retour TOR thermique CE moteur (NC) — TRUE = surchauffe (NOT PRG_0_Inputs.M1/M2ThermalFeedback)
    SlackCableDetected  : BOOL;        // Mou câble sur tambour M2 (NC, câblé sur les 2 instances) : TRUE=mou détecté → SafeStop sauf si OverrideSync
    PhaseRotationOk     : BOOL;        // PRG_0_Inputs.PhaseRotationOk (commun) — TRUE = rotation phases correcte
    TopPositionSensor   : BOOL;        // Capteur position haute (NC commun) — TRUE=libre, FALSE=butée atteinte
    InReferencingMode   : BOOL;        // TRUE si treuil en cours de homing (référencement)
    CablePosM           : REAL;        // Position actuelle câble en mètres (scalée)
    CableLimitDescentM  : REAL;        // Limite basse physique descente en mètres (valeur négative)
END_VAR
VAR_OUTPUT
    Ready               : BOOL;
    Busy                : BOOL;
    Done                : BOOL;
    Error               : BOOL;
    ErrorId             : WORD;        // bit0:joystick/CAN perdu ; bit1:codeur perdu ; bit2:surchauffe ; bit3:mou câble M2 (SafeStop ou ForbidAscent si OverrideSync) ; bit4:phases élec. ; bit5:fin course haut ; bit6:longueur max câble
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
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_Safety_Winch) ===

// 🛑 1. GATE — sécurité par défaut : pas de surveillance active = arrêt forcé du domaine
IF NOT Enable OR NOT EmergencyStopOk THEN
    Ready := FALSE;
    SafeStop := TRUE;              // Fail-safe : tant que la surveillance n'est pas garantie, on arrête
    ForbidDescent := TRUE;         // Fail-safe : cohérent avec SafeStop (descente a fortiori interdite)
    PowerCutOff := FALSE;
    State := E_State.DISABLED;
    RETURN;
END_IF;

Ready := TRUE;
State := E_State.READY;

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

// 📤 4. ARBITRAGE DES SORTIES MAÎTRESSES
Error := (ErrorId <> 16#0000);       // 🧭 Partie3 §4 : miroir de TOUT le domaine, y compris mou de câble (visible IHM)
ErrorEdge(CLK := Error);
IF ErrorEdge.Q THEN
    StateAtError := State;
END_IF;

// 🟧 SafeStop : bits 0/1/2/3/4 (joystick, codeur, thermique, MOU CÂBLE, phases)
// ⚠️ bit3 (mou câble) est EXCLU du SafeStop si OverrideSync=TRUE (procédure récupération manuelle)
IF OverrideSync THEN
    SafeStop := (ErrorId AND 16#0017) <> 16#0000;   // bit3 exclu → SafeStop normal sans mou câble
ELSE
    SafeStop := (ErrorId AND 16#001F) <> 16#0000;   // bit3 inclus → SafeStop complet avec mou câble
END_IF;

// ⬇️ ForbidDescent : bit6 uniquement (limite basse câble). Le mou câble → SafeStop (pas ForbidDescent)
ForbidDescent := (ErrorId AND 16#0040) <> 16#0000;

// ⬆️ ForbidAscent : bit5 (fin course haut) OU bit3+OverrideSync (récupération mou câble : montée interdite même en récup)
ForbidAscent := (ErrorId AND 16#0020) <> 16#0000
             OR ((ErrorId AND 16#0008) <> 16#0000 AND OverrideSync);

PowerCutOff := FALSE;       // 🧨 TBD — pas de ST_ContactorCheck de puissance câblé dans ce lot

// Busy, Done non utilisés mais présents pour conformité (comme FB_DiagCanOpen)
Busy := FALSE;
Done := FALSE;
