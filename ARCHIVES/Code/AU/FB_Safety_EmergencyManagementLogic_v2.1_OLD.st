(* =======================================================================
   🛡️ FB_Safety_EmergencyManagementLogic — Décision & Séquencement AU
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Machine d'état, fronts Reset/Arm, calcul ErrorId & consignes logiques
   🔒 Pattern Cause/Ack : Reset non conditionné, interlock sur Cause brute, debounce IHM + Ack
   📄 Doc métier : DOC/AF/AF_Partie-01_Analyse_Fonctionnelle_v2.1.md
   ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_Safety_EmergencyManagementLogic
VAR_INPUT
    // === COMMANDES & CONSIGNES ===
    Enable                  : BOOL; // --> [CMD]  Active la surveillance (TRUE = autorise)
    Reset                   : BOOL; // --> [CMD]  Front acquittement defauts
    ArmRequest              : BOOL; // --> [CMD]  Demande de rearmement (BtnEmergencyArming)
    PowerCutOffRequest      : BOOL; // --> [SAFE] Requete de coupure logique issue des metiers
    BtnEmergencyCutOff      : BOOL; // --> [CMD]  Commande d'ouverture d'urgence depuis l'IHM

    // === RETOURS MATERIELS (HW) ===
    EmergencyChainClosed    : BOOL; // --> [HW]   Retour physique boucle d'urgence amont contacteur
    PowerContactorEngaged   : BOOL; // --> [HW]   Confirmation contacteur de puissance principal
END_VAR
VAR_OUTPUT
    // === ERREURS & CONSIGNES LOGIQUES ===
    Error                   : BOOL; // <-- [DIAG] Synthese defaut actif
    ErrorId                 : WORD; // <-- [DIAG] Bitfield erreurs (bit0:Redundancy, bit1:Arming, bit3:Startup)
    Cmd                     : ST_Safety_Emergency_InternalCmd; // <-- [STAT] Structure de commande logique produite

    // === DIAGNOSTICS & RETOURS D'ETAT ===
    ArmingSeqStep                : INT;  // <-- [DIAG] Etape sequence (0=IDLE, 1=TestA, 2=RestoreA, 3=TestB, 4=RestoreB, 5=Pulse, 6=Confirm)
    RedundancyTestFailed         : BOOL; // <-- [DIAG] Defaut auto-test redondance (Cause lissee OR NOT Ack)
    EmergencyArmingFailed        : BOOL; // <-- [DIAG] Defaut rearmement contacteur (Cause lissee OR NOT Ack)
    EmergencyArmingLockoutActive : BOOL; // <-- [DIAG] Verrouillage temporel 5s entre essais
    Armable                      : BOOL; // <-- [STAT] Rearmement possible actuellement
    ArmingBusy                   : BOOL; // <-- [STAT] Sequence ou lockout en cours
    StartupFail                  : BOOL; // <-- [DIAG] Autotest demarrage echoue
    LastAbortStep                : INT;  // <-- [DIAG] Etape sequence lors du dernier abandon (0 a 6)
    LastAbortCause               : WORD; // <-- [DIAG] Bitfield cause abandon (16#0001=Cut, 16#0002=Chute chaine pulse/confirm, 16#0004=Timeout A, 16#0008=Timeout B, 16#0010=PowerCutOff, 16#0020=Redondance A, 16#0040=Redondance B, 16#0080=Timeout contacteur)
END_VAR
VAR
    // === DETECTEURS DE FRONT INTERNES ===
    ResetEdge               : R_TRIG; // . [LOC] Detecteur front montant Reset
    ArmReqEdge              : R_TRIG; // . [LOC] Detecteur front montant ArmRequest
    EnableRising            : R_TRIG; // . [LOC] Detecteur front montant Enable
    RedundancyCauseEdge     : R_TRIG; // . [LOC] Detecteur nouvelle occurrence cause redondance
    ArmingFailedCauseEdge   : R_TRIG; // . [LOC] Detecteur nouvelle occurrence cause rearmement

    // === DRAPEAUX & FORCAGES LOGIQUES ===
    ForceTestA              : BOOL; // . [LOC] Forcage coupure canal A pendant test
    ForceTestB              : BOOL; // . [LOC] Forcage coupure canal B pendant test
    StartupCheckDone        : BOOL; // . [LOC] Autotest demarrage effectue
    StartupCheckOK          : BOOL; // . [LOC] Resultat autotest demarrage (latche)

    // === CAUSE & ACK DEFAUT REDONDANCE ===
    RedundancyTestFailedCause : BOOL;         // . [LOC] Cause brute : canal colle detecte a l'auto-test
    RedundancyTestFailedAck   : BOOL := TRUE; // . [LOC] Accuse operateur (TRUE = pas d'alarme a afficher)

    // === CAUSE & ACK DEFAUT REARMEMENT ===
    EmergencyArmingFailedCause : BOOL;         // . [LOC] Cause brute : contacteur non confirme sous 2s
    EmergencyArmingFailedAck   : BOOL := TRUE; // . [LOC] Accuse operateur (TRUE = pas d'alarme a afficher)

    // === TEMPORISATEURS LOGIQUES ===
    TonTestA                : TON; // . [LOC] Timer auto-test canal A
    TonRestoreA             : TON; // . [LOC] Timer restauration canal A
    TonTestB                : TON; // . [LOC] Timer auto-test canal B
    TonRestoreB             : TON; // . [LOC] Timer restauration canal B
    TonArmingPulse          : TON; // . [LOC] Timer impulsion rearmement
    TonArmingConfirm        : TON; // . [LOC] Timer attente confirmation contacteur
    TonArmingLockout        : TON; // . [LOC] Timer lockout anti-reessai
    TonRedundancyDisplay    : TON; // . [LOC] Timer debounce affichage IHM redondance
    TonArmingFailedDisplay  : TON; // . [LOC] Timer debounce affichage IHM rearmement
END_VAR
VAR CONSTANT
    // === TEMPORISATIONS NORMATIVES DE SECURITE (FIXES) ===
    CST_TestDuration         : TIME := T#200ms; // Duree auto-test canal A ou B
    CST_ArmingPulseDuration  : TIME := T#1s;    // Duree impulsion rearmement contacteur
    CST_ArmingConfirmTimeout : TIME := T#2s;    // Timeout confirmation engagement contacteur
    CST_ArmingLockout        : TIME := T#5s;    // Duree verrouillage anti-reessai apres echec
    CST_FaultDisplayDebounce : TIME := T#200ms; // Anti-clignotement affichage IHM uniquement
END_VAR

// === IMPLEMENTATION ===

{region "§1 Fronts de commande"}
// 🔄 Fronts
EnableRising(CLK := Enable);
ResetEdge(CLK := Reset);
ArmReqEdge(CLK := ArmRequest);

{endregion}

{region "§2 Gate neutralisation"}
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

{endregion}

{region "§3 Autotest demarrage"}
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

{endregion}

{region "§4 Acquittement defauts"}
// 🔍 3. ACQUITTEMENT DES DÉFAUTS (pattern Cause/Ack — §3.4bis AF01, §9 STD)
// ⚠️ Reset acquitte l'affichage (Ack:=TRUE). La cause de redondance reste verrouillée
// jusqu'au prochain test physique. L'échec d'armement précédent est réinitialisé pour autoriser un réessai.
IF ResetEdge.Q THEN
    RedundancyTestFailedAck := TRUE;
    EmergencyArmingFailedCause := FALSE;
    EmergencyArmingFailedAck := TRUE;
    EmergencyArmingLockoutActive := FALSE;
    StartupFail := FALSE;
    ErrorId := 16#0000;
END_IF;

{endregion}

{region "§5 Sequence rearmement AU"}
// 🛑 Coupure immédiate de toute séquence en cours
IF ArmingSeqStep <> 0 THEN
    IF BtnEmergencyCutOff THEN
        // Avortement volontaire : pas d'alarme d'échec
        LastAbortStep := ArmingSeqStep;
        LastAbortCause := 16#0001; // Bit0: Demande coupure manuelle IHM
        ArmingSeqStep := 0;
    ELSIF PowerCutOffRequest THEN
        // Avortement sécurité d'urgence : coupure métier (PAS un défaut d'armement).
        // Sécurité conservée : lockout 5s + interlock (Armable/Cmd.Maintain* bloqués par
        // PowerCutOffRequest). Ne pose PAS EmergencyArmingFailedCause -> pas de fausse
        // alarme "échec armement" pour une coupure métier voulue (D2 option c).
        EmergencyArmingLockoutActive := TRUE;
        LastAbortStep := ArmingSeqStep;
        LastAbortCause := 16#0010; // Bit4: Coupure sécurité métier active (PowerCutOff)
        ArmingSeqStep := 0;
    ELSIF (ArmingSeqStep = 5 OR ArmingSeqStep = 6) AND NOT EmergencyChainClosed THEN
        // Chute boucle matérielle : alarme d'échec + verrouillage 5s
        EmergencyArmingFailedCause := TRUE;
        EmergencyArmingLockoutActive := TRUE;
        LastAbortStep := ArmingSeqStep;
        LastAbortCause := 16#0002; // Bit1: Chute boucle AU pendant impulsion/confirmation
        ArmingSeqStep := 0;
    END_IF;
END_IF;

// 🚦 4. DÉCLENCHEMENT DE LA SÉQUENCE DE SÉCURITÉ
// 🩹 Une nouvelle tentative repart d'une Cause propre : si le probleme persiste, il sera
// re-latche des le prochain echec (RedundancyCauseEdge/ArmingFailedCauseEdge -> Ack remis a FALSE,
// TC-P01-009). Ceci prouve par le run reel que la cause a disparu, pas juste un Reset optimiste.
IF ArmReqEdge.Q AND (ArmingSeqStep = 0) AND EmergencyChainClosed 
   AND NOT BtnEmergencyCutOff
   AND NOT PowerCutOffRequest
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
            LastAbortStep := 1;
            LastAbortCause := 16#0020; // Defaut redondance canal A
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
        LastAbortStep := 2;
        LastAbortCause := 16#0004; // Bit2: Timeout restauration canal A (chaine non remontee en 200ms)
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
            LastAbortStep := 3;
            LastAbortCause := 16#0040; // Defaut redondance canal B
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
        LastAbortStep := 4;
        LastAbortCause := 16#0008; // Bit3: Timeout restauration canal B (chaine non remontee en 200ms)
        ArmingSeqStep := 0;
    END_IF;
END_IF;

// ⏱️ Étape 5 : Les 2 canaux validés -> impulsion réarmement physique (1s)
TonArmingPulse(IN := (ArmingSeqStep = 5), PT := CST_ArmingPulseDuration);
Cmd.ArmPulse_Cmd := (ArmingSeqStep = 5) AND NOT BtnEmergencyCutOff AND NOT PowerCutOffRequest;
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
        EmergencyArmingLockoutActive := TRUE;
        LastAbortStep := 6;
        LastAbortCause := 16#0080; // Defaut confirmation contacteur
        ArmingSeqStep := 0;
    END_IF;
END_IF;

// ⏱️ Séquence de verrouillage temporel (5s)
TonArmingLockout(IN := EmergencyArmingLockoutActive, PT := CST_ArmingLockout);
IF TonArmingLockout.Q THEN
    EmergencyArmingLockoutActive := FALSE;
END_IF;

{endregion}

{region "§6 Gestion cause et acquittement"}
// 3bis. PATTERN CAUSE/ACK — détection ré-apparition + acquittement (§3.4bis AF01, §9 STD)
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

{endregion}

{region "§7 Commandes et etats publics"}
// 📤 5. GÉNÉRATION DES CONSIGNES LOGIQUES — basées sur la Cause brute (jamais sur l'Ack)
Cmd.MaintainA_Cmd := NOT PowerCutOffRequest AND NOT ForceTestA AND NOT BtnEmergencyCutOff AND NOT RedundancyTestFailedCause;
Cmd.MaintainB_Cmd := NOT PowerCutOffRequest AND NOT ForceTestB AND NOT BtnEmergencyCutOff AND NOT RedundancyTestFailedCause;
// ArmPulse_Cmd déjà positionné à l'étape 5 ci-dessus (garder FALSE hors étape 5)
IF ArmingSeqStep <> 5 THEN
    Cmd.ArmPulse_Cmd := FALSE;
END_IF;

// 🚦 6. ÉTATS PUBLICS (repris par le composite dans State/Diag) — interlock sur Cause brute
Armable := EmergencyChainClosed
           AND NOT BtnEmergencyCutOff
           AND NOT PowerCutOffRequest
           AND (ArmingSeqStep = 0)
           AND NOT EmergencyArmingLockoutActive
           AND NOT RedundancyTestFailedCause
           AND NOT PowerContactorEngaged;

ArmingBusy := (ArmingSeqStep <> 0) OR EmergencyArmingLockoutActive;

{endregion}

{region "§8 Affichage defauts IHM"}
// 📤 7. AFFICHAGE IHM — debounce anti-clignotement (Cause lissée) OR NOT Ack (§9 STD)
// ⚠️ Uniquement pour l'affichage : l'action de sécurité ci-dessus (§5/§6) reste instantanée
// sur la Cause brute, jamais retardée par ce debounce.
TonRedundancyDisplay(IN := RedundancyTestFailedCause, PT := CST_FaultDisplayDebounce);
RedundancyTestFailed := TonRedundancyDisplay.Q OR NOT RedundancyTestFailedAck;

TonArmingFailedDisplay(IN := EmergencyArmingFailedCause, PT := CST_FaultDisplayDebounce);
EmergencyArmingFailed := TonArmingFailedDisplay.Q OR NOT EmergencyArmingFailedAck;

{endregion}

{region "§9 Synthese ErrorId"}
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

{endregion}
