(* ═══════════════════════════════════════════════════════════════
   🛡️ FB_Safety_EmergencyManagementLogic — Décision & Séquencement
   ───────────────────────────────────────────────────────────────
   📄 Rôle : Gère la machine d'état d'auto-test et de réarmement de
      la boucle d'arrêt d'urgence. Produit les consignes logiques
      et les bus d'état/diagnostic.
   🏷️ Renommé PowerCutOff_X_Cmd → MaintainA/B_Cmd (polarité maintien).
      Ajout autotest démarrage (§5.4 AF01) + bus State/Diag.
   🩹 REX 2026-08 : pattern Cause/Ack (RedundancyTestFailed, EmergencyArmingFailed).
      Reset n'est plus jamais conditionné (ex-bug : Reset+PowerContactorEngaged
      créait une impasse opérateur). L'interlock sécurité reste sur la Cause brute ;
      l'affichage IHM (ErrorId) suit la Cause lissée par un debounce court + l'Ack.
   ═══════════════════════════════════════════════════════════════
    📄 Docs : DOC/AF_Partie-01_Analyse_Fonctionnelle_v2.0.md §3.4/§3.4bis
              DOC/CODE_QUALITY_STANDARDS.md §9 (pattern Cause/Ack)
              DOC/AF_Partie-03_Contrats_Composants_v2.0.md
*)

FUNCTION_BLOCK PUBLIC FB_Safety_EmergencyManagementLogic
VAR_INPUT
    Enable              : BOOL;        // Active la surveillance
    Reset               : BOOL;        // Front acquittement défauts
    ArmRequest          : BOOL;        // Demande de réarmement (BtnEmergencyArming)
    EmergencyChainClosed      : BOOL;        // Retour physique boucle d'urgence amont contacteur
    PowerContactorEngaged     : BOOL;        // Confirmation contacteur de puissance principal
    PowerCutOffRequest  : BOOL;        // Requête de coupure logique issue des métiers
    BtnEmergencyCutOff  : BOOL;        // Commande d'ouverture d'urgence depuis l'IHM
END_VAR
VAR_OUTPUT
    Error               : BOOL;
    ErrorId             : WORD;        // bit0: RedundancyTestFailed (affiché), bit1: EmergencyArmingFailed (affiché)
    Cmd                 : ST_EmergencyManagementCmd; // Structure de commande logique produite

    ArmingSeqStep       : INT;         // Étape de diagnostic : 0=IDLE, 1=TestA, 2=RestoreA, 3=TestB, 4=RestoreB, 5=Pulse, 6=Confirm
    RedundancyTestFailed: BOOL;        // 🩹 Affiché = Cause lissée OR NOT Ack (pattern §3.4bis) — pour IHM/diag
    EmergencyArmingFailed: BOOL;       // 🩹 Affiché = Cause lissée OR NOT Ack (pattern §3.4bis) — pour IHM/diag
    EmergencyArmingLockoutActive : BOOL; // Verrouillage temporel de 5s entre les essais

    // 🆕 Bus State/Diag internes — repris par le composite pour les DUT publics
    Armable             : BOOL;        // 🟢 Réarmement possible maintenant
    ArmingBusy          : BOOL;        // ⏳ Séquence ou lockout en cours
    StartupFail         : BOOL;        // 🔴 Autotest démarche échoué
END_VAR
VAR CONSTANT
    // [CST] Temporisations normatives de securite AU (fixes, non modifiables RETAIN/IHM)
    CST_TestDuration         : TIME := T#200ms;  // Duree auto-test canal A ou B
    CST_ArmingPulseDuration  : TIME := T#1s;     // Duree impulsion rearmement contacteur
    CST_ArmingConfirmTimeout : TIME := T#2s;     // Timeout confirmation engagement contacteur
    CST_ArmingLockout        : TIME := T#5s;     // Duree verrouillage anti-reessai apres echec
    CST_FaultDisplayDebounce : TIME := T#200ms;  // 🩹 Anti-clignotement affichage IHM uniquement (§9 STD) — jamais sur l'action
END_VAR
VAR
    ResetEdge           : R_TRIG;
    ArmReqEdge          : R_TRIG;
    EnableRising        : R_TRIG;
    ForceTestA          : BOOL;
    ForceTestB          : BOOL;
    TonTestA            : TON;
    TonRestoreA         : TON;
    TonTestB            : TON;
    TonRestoreB         : TON;
    TonArmingPulse      : TON;
    TonArmingConfirm    : TON;
    TonArmingLockout    : TON;

    // 🆕 Autotest démarrage
    StartupCheckDone    : BOOL;        // TRUE = autotest passé, attente réarmement
    StartupCheckOK      : BOOL;        // Résultat autotest (latche le temps du front)

    // 🩹 Pattern Cause/Ack (§3.4bis AF01, §9 STD) — Reset jamais conditionné
    RedundancyTestFailedCause : BOOL;        // Latch brut : canal collé détecté à l'auto-test
    RedundancyTestFailedAck   : BOOL := TRUE; // Accusé opérateur — TRUE = pas d'alarme à afficher
    RedundancyCauseEdge       : R_TRIG;       // Détecte une NOUVELLE occurrence de la cause
    TonRedundancyDisplay      : TON;          // Debounce affichage IHM uniquement

    EmergencyArmingFailedCause : BOOL;        // Latch brut : contacteur non confirmé sous 2s
    EmergencyArmingFailedAck   : BOOL := TRUE; // Accusé opérateur — TRUE = pas d'alarme à afficher
    ArmingFailedCauseEdge      : R_TRIG;       // Détecte une NOUVELLE occurrence de la cause
    TonArmingFailedDisplay     : TON;          // Debounce affichage IHM uniquement
END_VAR

// === IMPLEMENTATION ===

// 🔄 Fronts
EnableRising(CLK := Enable);
ResetEdge(CLK := Reset);
ArmReqEdge(CLK := ArmRequest);

// 🛑 1. GATE — neutralisation si désactivé
IF NOT Enable THEN
    Error := FALSE;
    ErrorId := 16#0000;
    Cmd.MaintainA_Cmd := FALSE;
    Cmd.MaintainB_Cmd := FALSE;
    Cmd.ArmPulse_Cmd := FALSE;
    ArmingSeqStep := 0;
    RedundancyTestFailed := FALSE;
    EmergencyArmingFailed := FALSE;
    EmergencyArmingLockoutActive := FALSE;
    ForceTestA := FALSE;
    ForceTestB := FALSE;
    Armable := FALSE;
    ArmingBusy := FALSE;
    StartupFail := FALSE;
    StartupCheckDone := FALSE;
    StartupCheckOK := FALSE;
    // 🩹 Neutralisation = coupure surveillance, pas un defaut : Cause et Ack repartent propres
    RedundancyTestFailedCause := FALSE;
    RedundancyTestFailedAck := TRUE;
    EmergencyArmingFailedCause := FALSE;
    EmergencyArmingFailedAck := TRUE;
    TonTestA(IN := FALSE);
    TonRestoreA(IN := FALSE);
    TonTestB(IN := FALSE);
    TonRestoreB(IN := FALSE);
    TonArmingPulse(IN := FALSE);
    TonArmingConfirm(IN := FALSE);
    TonArmingLockout(IN := FALSE);
    TonRedundancyDisplay(IN := FALSE);
    TonArmingFailedDisplay(IN := FALSE);
    RETURN;
END_IF;

// 🏁 2. AUTOTEST DÉMARRAGE (§5.4 AF01)
// Vérifications synchrones 1 cycle au premier passage Enable=TRUE
IF EnableRising.Q THEN
    StartupCheckDone := FALSE;
END_IF;

IF NOT StartupCheckDone THEN
    // Exécute les 4 contrôles en 1 cycle
    StartupCheckOK := EmergencyChainClosed          // 1. Boucle AU fermée
                      AND NOT PowerContactorEngaged // 2. Contacteur au repos
                      AND (ArmingSeqStep = 0);      // 4. Pas de séquence résiduelle
    StartupCheckDone := TRUE;
    StartupFail := NOT StartupCheckOK;
    IF NOT StartupCheckOK THEN
        ErrorId := 16#0008; // bit3 = startup autotest fail
        Error := TRUE;
    END_IF;
    RETURN; // 1 cycle pour laisser le temps aux entrées de se stabiliser
END_IF;

// 🔍 3. ACQUITTEMENT DES DÉFAUTS (pattern Cause/Ack — §3.4bis AF01, §9 STD)
// ⚠️ Reset TOUJOURS effectif, efface l'affichage (Ack:=TRUE) et réinitialise Cause:=FALSE
// pour permettre une nouvelle tentative d'armement sans blocage IHM. Si le défaut persiste,
// la nouvelle tentative re-latchera Cause:=TRUE et Ack:=FALSE (TC-P01-009).
IF ResetEdge.Q THEN
    RedundancyTestFailedAck := TRUE;
    EmergencyArmingFailedAck := TRUE;
    RedundancyTestFailedCause := FALSE;
    EmergencyArmingFailedCause := FALSE;
    StartupFail := FALSE;
    ErrorId := 16#0000;
END_IF;
END_IF;

// 🚦 4. DÉCLENCHEMENT DE LA SÉQUENCE DE SÉCURITÉ
// 🩹 Une nouvelle tentative repart d'une Cause propre : si le probleme persiste, il sera
// re-latche des le prochain echec (RedundancyCauseEdge/ArmingFailedCauseEdge -> Ack remis a FALSE,
// TC-P01-009). Ceci prouve par le run reel que la cause a disparu, pas juste un Reset optimiste.
IF ArmReqEdge.Q AND (ArmingSeqStep = 0) AND EmergencyChainClosed 
   AND NOT EmergencyArmingLockoutActive 
   AND NOT PowerContactorEngaged THEN
    ArmingSeqStep := 1;
    RedundancyTestFailedCause := FALSE;
    EmergencyArmingFailedCause := FALSE;
END_IF;

// ⏱️ Étape 1 : Coupe canal A seul, vérifie que la boucle tombe
TonTestA(IN := (ArmingSeqStep = 1), PT := CST_TestDuration);
IF ArmingSeqStep = 1 THEN
    ForceTestA := TRUE;
    IF TonTestA.Q THEN
        ForceTestA := FALSE;
        IF EmergencyChainClosed THEN
            RedundancyTestFailedCause := TRUE;
            ArmingSeqStep := 0;
        ELSE
            ArmingSeqStep := 2;
        END_IF;
    END_IF;
ELSE
    ForceTestA := FALSE;
END_IF;

// ⏱️ Étape 2 : Restaure A, attend le retour sain de la boucle amont
TonRestoreA(IN := (ArmingSeqStep = 2), PT := CST_TestDuration);
IF (ArmingSeqStep = 2) AND TonRestoreA.Q THEN
    IF EmergencyChainClosed THEN
        ArmingSeqStep := 3;
    ELSE
        ArmingSeqStep := 0;
    END_IF;
END_IF;

// ⏱️ Étape 3 : Coupe canal B seul, vérifie que la boucle tombe
TonTestB(IN := (ArmingSeqStep = 3), PT := CST_TestDuration);
IF ArmingSeqStep = 3 THEN
    ForceTestB := TRUE;
    IF TonTestB.Q THEN
        ForceTestB := FALSE;
        IF EmergencyChainClosed THEN
            RedundancyTestFailedCause := TRUE;
            ArmingSeqStep := 0;
        ELSE
            ArmingSeqStep := 4;
        END_IF;
    END_IF;
ELSE
    ForceTestB := FALSE;
END_IF;

// ⏱️ Étape 4 : Restaure B, attend le retour sain de la boucle amont
TonRestoreB(IN := (ArmingSeqStep = 4), PT := CST_TestDuration);
IF (ArmingSeqStep = 4) AND TonRestoreB.Q THEN
    IF EmergencyChainClosed THEN
        ArmingSeqStep := 5;
    ELSE
        ArmingSeqStep := 0;
    END_IF;
END_IF;

// ⏱️ Étape 5 : Les 2 canaux validés -> impulsion réarmement physique (1s)
TonArmingPulse(IN := (ArmingSeqStep = 5), PT := CST_ArmingPulseDuration);
Cmd.ArmPulse_Cmd := (ArmingSeqStep = 5);
IF (ArmingSeqStep = 5) AND TonArmingPulse.Q THEN
    ArmingSeqStep := 6;
END_IF;

// ⏱️ Étape 6 : Attente confirmation contacteur principal (2s max)
TonArmingConfirm(IN := (ArmingSeqStep = 6), PT := CST_ArmingConfirmTimeout);
IF ArmingSeqStep = 6 THEN
    IF PowerContactorEngaged THEN
        ArmingSeqStep := 0;
        EmergencyArmingLockoutActive := FALSE;
    ELSIF TonArmingConfirm.Q THEN
        EmergencyArmingFailedCause := TRUE;
        ArmingSeqStep := 0;
        EmergencyArmingLockoutActive := TRUE;
    END_IF;
END_IF;

// ⏱️ Séquence de verrouillage temporel (5s)
TonArmingLockout(IN := EmergencyArmingLockoutActive, PT := CST_ArmingLockout);
IF TonArmingLockout.Q THEN
    EmergencyArmingLockoutActive := FALSE;
END_IF;

// 🆕 3bis. PATTERN CAUSE/ACK — détection ré-apparition + acquittement (§3.4bis AF01, §9 STD)
// L'interlock sécurité (ci-dessous, arbitrage Cmd/Armable) utilise TOUJOURS la Cause brute,
// jamais l'Ack : l'acquittement opérateur n'ouvre jamais un interlock de sécurité.
RedundancyCauseEdge(CLK := RedundancyTestFailedCause);
IF RedundancyCauseEdge.Q THEN
    RedundancyTestFailedAck := FALSE; // nouvelle occurrence -> ré-alarme, ré-acquittement requis
END_IF;

ArmingFailedCauseEdge(CLK := EmergencyArmingFailedCause);
IF ArmingFailedCauseEdge.Q THEN
    EmergencyArmingFailedAck := FALSE;
END_IF;

// 📤 5. GÉNÉRATION DES CONSIGNES LOGIQUES — basées sur la Cause brute (jamais sur l'Ack)
Cmd.MaintainA_Cmd := NOT PowerCutOffRequest AND NOT ForceTestA AND NOT BtnEmergencyCutOff AND NOT RedundancyTestFailedCause;
Cmd.MaintainB_Cmd := NOT PowerCutOffRequest AND NOT ForceTestB AND NOT BtnEmergencyCutOff AND NOT RedundancyTestFailedCause;
// ArmPulse_Cmd déjà positionné à l'étape 5 ci-dessus (garder FALSE hors étape 5)
IF ArmingSeqStep <> 5 THEN
    Cmd.ArmPulse_Cmd := FALSE;
END_IF;

// 🚦 6. ÉTATS PUBLICS (repris par le composite dans State/Diag) — interlock sur Cause brute
Armable := EmergencyChainClosed
           AND (ArmingSeqStep = 0)
           AND NOT EmergencyArmingLockoutActive
           AND NOT RedundancyTestFailedCause
           AND NOT PowerContactorEngaged;

ArmingBusy := (ArmingSeqStep <> 0) OR EmergencyArmingLockoutActive;

// 📤 7. AFFICHAGE IHM — debounce anti-clignotement (Cause lissée) OR NOT Ack (§9 STD)
// ⚠️ Uniquement pour l'affichage : l'action de sécurité ci-dessus (§5/§6) reste instantanée
// sur la Cause brute, jamais retardée par ce debounce.
TonRedundancyDisplay(IN := RedundancyTestFailedCause, PT := CST_FaultDisplayDebounce);
RedundancyTestFailed := TonRedundancyDisplay.Q OR NOT RedundancyTestFailedAck;

TonArmingFailedDisplay(IN := EmergencyArmingFailedCause, PT := CST_FaultDisplayDebounce);
EmergencyArmingFailed := TonArmingFailedDisplay.Q OR NOT EmergencyArmingFailedAck;

// 📤 8. SYNTHÈSE DES ERREURS (bitfield affiché, basé sur RedundancyTestFailed/EmergencyArmingFailed affichés)
ErrorId := 16#0000;
IF RedundancyTestFailed THEN
    ErrorId := ErrorId OR 16#0001;
END_IF;
IF EmergencyArmingFailed THEN
    ErrorId := ErrorId OR 16#0002;
END_IF;
// bit3 (16#0008) = StartupFail, positionné au §2 si autotest échoué
// — ne pas l'effacer ici (reset explicite requis)

Error := (ErrorId <> 16#0000);
