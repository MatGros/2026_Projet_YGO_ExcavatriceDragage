(* =======================================================================
   🛡️ FB_Safety_EmergencyManagement — Gestion de la réd'urgence AU
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Machine d'état, fronts Reset/Arm, autotest redondance A/B,
      réarmement contacteur, interlock Cause brute, projection fail-safe
      et latch défaut via le socle FB_FaultCore.
   🔒 Sécurité : fronts Reset/Arm (jamais de redémarrage auto), interlock
      sur Cause brute (jamais sur l'Ack), fail-safe Enable=FALSE.
   📤 Sorties structurées (2 DUT) : Status (ST_Safety_Emergency_Status) +
      Cmd (ST_Safety_Emergency_Cmd).
   📄 Doc métier : DOC/AF/AF_Partie-01_Analyse_Fonctionnelle_v2.1.md
   ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_Safety_EmergencyManagement
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
    // === SORTIES STRUCTUREES (2 DUT) ===
    Status                  : ST_Safety_Emergency_Status; // <-- [STAT] État/diagnostic (Ready/Done + State + Diag + Fault + message) — PRG_07/IHM/Troubleshooting
    Cmd                     : ST_Safety_Emergency_Cmd;    // <-- [ACT]  Commandes de pilotage (MaintainA/B_Cmd + ArmPulse_Cmd) — PRG_06
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
    StartupFail             : BOOL; // . [LOC] Autotest demarrage echoue (cause bit3, latchee via socle)

    // === CAUSE & ACK DEFAUT REDONDANCE ===
    RedundancyTestFailedCause : BOOL;         // . [LOC] Cause brute : canal colle detecte a l'auto-test
    RedundancyTestFailedAck   : BOOL := TRUE; // . [LOC] Accuse operateur (TRUE = pas d'alarme a afficher)

    // === CAUSE & ACK DEFAUT REARMEMENT ===
    EmergencyArmingFailedCause : BOOL;         // . [LOC] Cause brute : contacteur non confirme sous 2s
    EmergencyArmingFailedAck   : BOOL := TRUE; // . [LOC] Accuse operateur (TRUE = pas d'alarme a afficher)

    // === ETAT INTERNE SEQUENCE ===
    ArmingSeqStep             : INT;  // . [LOC] Etape sequence (0=IDLE..6=Confirm)
    EmergencyArmingLockoutActive : BOOL; // . [LOC] Verrouillage temporel 5s entre essais
    RedundancyTestFailed      : BOOL; // . [LOC] Defaut auto-test affiche (Cause lissee OR NOT Ack)
    EmergencyArmingFailed     : BOOL; // . [LOC] Defaut rearmement affiche (Cause lissee OR NOT Ack)
    Armable                   : BOOL; // . [LOC] Rearmement possible actuellement (source unique, aligne IHM/armement)
    ArmingBusy                : BOOL; // . [LOC] Sequence ou lockout en cours
    LastAbortStep             : INT;  // . [LOC] Etape sequence lors du dernier abandon (0 a 6)
    LastAbortCause            : WORD; // . [LOC] Bitfield cause abandon (voir constantes CST_ABORT_*)

    // === CONDITIONS DECOMPOSEES (lisibilite §2quater) ===
    Armable_ChainOk           : BOOL; // . [LOC] Boucle fermee + pas de coupure IHM/metier
    Armable_Idle              : BOOL; // . [LOC] Sequence au repos
    Armable_NoBlock           : BOOL; // . [LOC] Pas de lockout, contacteur au repos
    Maintain_ChainOk          : BOOL; // . [LOC] Boucle fermee OU sequence en cours (maintien A/B)
    Maintain_NoCutOff         : BOOL; // . [LOC] Pas de coupure metier ni IHM (maintien A/B)
    MaintainA_NoFault         : BOOL; // . [LOC] Pas de forcage A ni cause redondance
    MaintainB_NoFault         : BOOL; // . [LOC] Pas de forcage B ni cause redondance
    MaintainA_NoBlock         : BOOL; // . [LOC] Maintien A autorise (pas de coupure ni defaut)
    MaintainB_NoBlock         : BOOL; // . [LOC] Maintien B autorise (pas de coupure ni defaut)

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

    // === SOCLE DEFAUT STANDARD (FB_FaultCore) ===
    instFault               : FB_FaultCore;                  // * [INST] Socle defaut (liste de causes -> ST_Fault)
    instCauses              : ARRAY[0..15] OF ST_FaultCause; // . [LOC] Liste des causes en clair pour le socle
END_VAR
VAR CONSTANT
    // === TEMPORISATIONS NORMATIVES DE SECURITE (FIXES) ===
    CST_TestDuration         : TIME := T#200ms; // Duree auto-test canal A ou B
    CST_ArmingPulseDuration  : TIME := T#1s;    // Duree impulsion rearmement contacteur
    CST_ArmingConfirmTimeout : TIME := T#2s;    // Timeout confirmation engagement contacteur
    CST_ArmingLockout        : TIME := T#5s;    // Duree verrouillage anti-reessai apres echec
    CST_FaultDisplayDebounce : TIME := T#200ms; // Anti-clignotement affichage IHM uniquement

    // === ETAPES SEQUENCE & CAUSES D'ABANDON ===
    // ⚠️ CST_STEP_* (0..6) et CST_ABORT_* (bitfield) sont déclarées en
    //    VAR_GLOBAL CONSTANT dans GVL_Safety_Emergency (conformité IEC :
    //    CODESYS refuse les constantes locales d'un FUNCTION_BLOCK comme étiquettes
    //    de CASE — erreur C0218). Références symboliques inchangées ci-dessous.
END_VAR

// === IMPLEMENTATION ===

{region "§1 Fronts de commande"}
// 🔄 Fronts
EnableRising(CLK := Enable);
ResetEdge(CLK := Reset);
ArmReqEdge(CLK := ArmRequest);
{endregion}

{region "§2 Gate Enable (neutralisation fail-safe)"}
// 🛑 GATE — neutralisation si désactivé : réinitialise l'état interne de la séquence.
// Les sorties physiques sont forcées à FALSE par la projection fail-safe (§10) ; le socle
// défaut reste appelé (§9) pour maintenir le latch non acquitté.
IF NOT Enable THEN
    ArmingSeqStep := CST_STEP_IDLE;
    ForceTestA := FALSE;
    ForceTestB := FALSE;
    StartupFail := FALSE;
    StartupCheckDone := FALSE;
    StartupCheckOK := FALSE;
    RedundancyTestFailed := FALSE;
    EmergencyArmingFailed := FALSE;
    EmergencyArmingLockoutActive := FALSE;
    Armable := FALSE;
    ArmingBusy := FALSE;
    LastAbortStep := CST_STEP_IDLE;
    LastAbortCause := INT_TO_WORD(CST_ABORT_NONE);
    // Neutralisation = coupure surveillance, pas un defaut : Cause et Ack repartent propres
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
END_IF;
{endregion}

{region "§3 Autotest demarrage"}
// 🏁 AUTOTEST DÉMARRAGE (§5.4 AF01) — vérifications synchrones 1 cycle au 1er Enable=TRUE
IF Enable THEN
    IF EnableRising.Q THEN
        StartupCheckDone := FALSE;
    END_IF;

    IF NOT StartupCheckDone THEN
        // Exécute les 4 contrôles en 1 cycle
        StartupCheckOK := EmergencyChainClosed          // 1. Boucle AU fermée
                          AND NOT PowerContactorEngaged // 2. Contacteur au repos
                          AND (ArmingSeqStep = CST_STEP_IDLE); // 4. Pas de séquence résiduelle
        StartupCheckDone := TRUE;
        StartupFail := NOT StartupCheckOK;
        // StartupFail est laté via le socle FB_FaultCore (§9) : il reste jusqu'au front Reset.
    END_IF;
END_IF;
{endregion}

{region "§4 Acquittement defauts"}
// 🔍 ACQUITTEMENT DES DÉFAUTS (pattern Cause/Ack — §3.4bis AF01, §9 STD)
// ⚠️ Reset acquitte l'affichage (Ack:=TRUE). La cause de redondance reste verrouillée
// jusqu'au prochain test physique. L'échec d'armement précédent est réinitialisé pour autoriser un réessai.
IF Enable THEN
    IF ResetEdge.Q THEN
        RedundancyTestFailedAck := TRUE;
        EmergencyArmingFailedCause := FALSE;
        EmergencyArmingFailedAck := TRUE;
        EmergencyArmingLockoutActive := FALSE;
        StartupFail := FALSE;
    END_IF;
END_IF;
{endregion}

{region "§5 Sequence rearmement AU"}
IF Enable THEN
    // 🛑 Coupure immédiate de toute séquence en cours
    IF ArmingSeqStep <> CST_STEP_IDLE THEN
        IF BtnEmergencyCutOff THEN
            // Avortement volontaire : pas d'alarme d'échec
            LastAbortStep := ArmingSeqStep;
            LastAbortCause := INT_TO_WORD(CST_ABORT_CUT_IHM);
            ArmingSeqStep := CST_STEP_IDLE;
        ELSIF PowerCutOffRequest THEN
            // Avortement sécurité d'urgence : coupure métier (PAS un défaut d'armement).
            // Lockout 5s + interlock (Armable/Maintain* bloqués par PowerCutOffRequest).
            // Ne pose PAS EmergencyArmingFailedCause : pas de fausse alarme "échec armement".
            EmergencyArmingLockoutActive := TRUE;
            LastAbortStep := ArmingSeqStep;
            LastAbortCause := INT_TO_WORD(CST_ABORT_POWER_CUTOFF);
            ArmingSeqStep := CST_STEP_IDLE;
        ELSIF (ArmingSeqStep = CST_STEP_PULSE OR ArmingSeqStep = CST_STEP_CONFIRM) AND NOT EmergencyChainClosed THEN
            // Chute boucle matérielle : alarme d'échec + verrouillage 5s
            EmergencyArmingFailedCause := TRUE;
            EmergencyArmingLockoutActive := TRUE;
            LastAbortStep := ArmingSeqStep;
            LastAbortCause := INT_TO_WORD(CST_ABORT_CHAIN_DROP);
            ArmingSeqStep := CST_STEP_IDLE;
        END_IF;
    END_IF;

    // 🚦 DÉCLENCHEMENT DE LA SÉQUENCE DE SÉCURITÉ
    // Une nouvelle tentative repart d'une Cause propre : si le problème persiste, il sera
    // re-latché dès le prochain échec (RedundancyCauseEdge/ArmingFailedCauseEdge -> Ack remis à FALSE).
    // 🚦 PRÉCONDITIONS D'ARMEMENT — source unique (Armable = State.Armable).
    // ⚠️ Armable_NoBlock SANS `NOT RedundancyTestFailedCause` : la cause de redondance est
    //    latée mais la séquence d'armement la re-teste (§5 étape 1/3) : l'armement reste donc
    //    réellement possible (et sûr) tant que les autres préconditions sont réunies. Afficher
    //    le bouton « Armable » sur cette cause seule bloquait le réarmement après acquittement
    //    (Reset ne purge pas la Cause, cf. §4) alors que l'armement était permis.
    Armable_ChainOk := EmergencyChainClosed AND NOT BtnEmergencyCutOff AND NOT PowerCutOffRequest;
    Armable_Idle := (ArmingSeqStep = CST_STEP_IDLE);
    Armable_NoBlock := NOT EmergencyArmingLockoutActive AND NOT PowerContactorEngaged;
    Armable := Armable_ChainOk AND Armable_Idle AND Armable_NoBlock;
    IF ArmReqEdge.Q AND Armable THEN
        ArmingSeqStep := CST_STEP_TEST_A;
        RedundancyTestFailedCause := FALSE;
        EmergencyArmingFailedCause := FALSE;
    END_IF;

    // ⏱️ Étape 1 : Coupe canal A seul, vérifie que la boucle tombe
    TonTestA(IN := (ArmingSeqStep = CST_STEP_TEST_A), PT := CST_TestDuration);
    IF ArmingSeqStep = CST_STEP_TEST_A THEN
        ForceTestA := TRUE;
        IF TonTestA.Q THEN
            ForceTestA := FALSE;
            IF EmergencyChainClosed THEN
                RedundancyTestFailedCause := TRUE;
                LastAbortStep := CST_STEP_TEST_A;
                LastAbortCause := INT_TO_WORD(CST_ABORT_REDUNDANCY_A);
                ArmingSeqStep := CST_STEP_IDLE;
            ELSE
                ArmingSeqStep := CST_STEP_RESTORE_A;
            END_IF;
        END_IF;
    ELSE
        ForceTestA := FALSE;
    END_IF;

    // ⏱️ Étape 2 : Restaure A, attend le retour sain de la boucle amont
    TonRestoreA(IN := (ArmingSeqStep = CST_STEP_RESTORE_A), PT := CST_TestDuration);
    IF (ArmingSeqStep = CST_STEP_RESTORE_A) AND TonRestoreA.Q THEN
        IF EmergencyChainClosed THEN
            ArmingSeqStep := CST_STEP_TEST_B;
        ELSE
            LastAbortStep := CST_STEP_RESTORE_A;
            LastAbortCause := INT_TO_WORD(CST_ABORT_TIMEOUT_RESTORE_A);
            ArmingSeqStep := CST_STEP_IDLE;
        END_IF;
    END_IF;

    // ⏱️ Étape 3 : Coupe canal B seul, vérifie que la boucle tombe
    TonTestB(IN := (ArmingSeqStep = CST_STEP_TEST_B), PT := CST_TestDuration);
    IF ArmingSeqStep = CST_STEP_TEST_B THEN
        ForceTestB := TRUE;
        IF TonTestB.Q THEN
            ForceTestB := FALSE;
            IF EmergencyChainClosed THEN
                RedundancyTestFailedCause := TRUE;
                LastAbortStep := CST_STEP_TEST_B;
                LastAbortCause := INT_TO_WORD(CST_ABORT_REDUNDANCY_B);
                ArmingSeqStep := CST_STEP_IDLE;
            ELSE
                ArmingSeqStep := CST_STEP_RESTORE_B;
            END_IF;
        END_IF;
    ELSE
        ForceTestB := FALSE;
    END_IF;

    // ⏱️ Étape 4 : Restaure B, attend le retour sain de la boucle amont
    TonRestoreB(IN := (ArmingSeqStep = CST_STEP_RESTORE_B), PT := CST_TestDuration);
    IF (ArmingSeqStep = CST_STEP_RESTORE_B) AND TonRestoreB.Q THEN
        IF EmergencyChainClosed THEN
            ArmingSeqStep := CST_STEP_PULSE;
        ELSE
            LastAbortStep := CST_STEP_RESTORE_B;
            LastAbortCause := INT_TO_WORD(CST_ABORT_TIMEOUT_RESTORE_B);
            ArmingSeqStep := CST_STEP_IDLE;
        END_IF;
    END_IF;

    // ⏱️ Étape 5 : Les 2 canaux validés -> impulsion réarmement physique (1s)
    TonArmingPulse(IN := (ArmingSeqStep = CST_STEP_PULSE), PT := CST_ArmingPulseDuration);
    IF (ArmingSeqStep = CST_STEP_PULSE) AND TonArmingPulse.Q THEN
        ArmingSeqStep := CST_STEP_CONFIRM;
    END_IF;

    // ⏱️ Étape 6 : Attente confirmation contacteur principal (2s max)
    TonArmingConfirm(IN := (ArmingSeqStep = CST_STEP_CONFIRM), PT := CST_ArmingConfirmTimeout);
    IF ArmingSeqStep = CST_STEP_CONFIRM THEN
        IF PowerContactorEngaged THEN
            ArmingSeqStep := CST_STEP_IDLE;
            EmergencyArmingLockoutActive := FALSE;
        ELSIF TonArmingConfirm.Q THEN
            EmergencyArmingFailedCause := TRUE;
            EmergencyArmingLockoutActive := TRUE;
            LastAbortStep := CST_STEP_CONFIRM;
            LastAbortCause := INT_TO_WORD(CST_ABORT_TIMEOUT_CONTACTOR);
            ArmingSeqStep := CST_STEP_IDLE;
        END_IF;
    END_IF;

    // ⏱️ Séquence de verrouillage temporel (5s)
    TonArmingLockout(IN := EmergencyArmingLockoutActive, PT := CST_ArmingLockout);
    IF TonArmingLockout.Q THEN
        EmergencyArmingLockoutActive := FALSE;
    END_IF;
END_IF;
{endregion}

{region "§6 Gestion cause et acquittement"}
// PATTERN CAUSE/ACK — détection ré-apparition + acquittement (§3.4bis AF01, §9 STD)
// L'interlock sécurité (ci-dessous, arbitrage Cmd/Armable) utilise TOUJOURS la Cause brute,
// jamais l'Ack : l'acquittement opérateur n'ouvre jamais un interlock de sécurité.
IF Enable THEN
    RedundancyCauseEdge(CLK := RedundancyTestFailedCause);
    IF RedundancyCauseEdge.Q THEN
        RedundancyTestFailedAck := FALSE; // nouvelle occurrence -> ré-alarme, ré-acquittement requis
    END_IF;

    ArmingFailedCauseEdge(CLK := EmergencyArmingFailedCause);
    IF ArmingFailedCauseEdge.Q THEN
        EmergencyArmingFailedAck := FALSE;
    END_IF;
END_IF;
{endregion}

{region "§7 Etats publics (interlock sur Cause brute)"}
// 🚦 ÉTATS PUBLICS — interlock sur Cause brute (jamais sur l'Ack)
IF Enable THEN
    ArmingBusy := (ArmingSeqStep <> CST_STEP_IDLE) OR EmergencyArmingLockoutActive;
END_IF;
{endregion}

{region "§8 Affichage defauts IHM"}
// 📤 AFFICHAGE IHM — debounce anti-clignotement (Cause lissée) OR NOT Ack (§9 STD)
// ⚠️ Uniquement pour l'affichage : l'action de sécurité ci-dessus (§5/§6) reste instantanée
// sur la Cause brute, jamais retardée par ce debounce.
IF Enable THEN
    TonRedundancyDisplay(IN := RedundancyTestFailedCause, PT := CST_FaultDisplayDebounce);
    RedundancyTestFailed := TonRedundancyDisplay.Q OR NOT RedundancyTestFailedAck;

    TonArmingFailedDisplay(IN := EmergencyArmingFailedCause, PT := CST_FaultDisplayDebounce);
    EmergencyArmingFailed := TonArmingFailedDisplay.Q OR NOT EmergencyArmingFailedAck;
END_IF;
{endregion}

{region "§9 Synthese defaut via socle FB_FaultCore"}
// 📤 SYNTHÈSE DES ERREURS — socle standard FB_FaultCore (vue live + vue latchée).
//    Chaque cause est exprimée EN CLAIR (ST_FaultCause) ; le socle en déduit ST_Fault.
//    StartupFail est une cause indépendante (index 3, Latching=TRUE) : latée jusqu'au front Reset.
//    Mapping bits (préservé pour FB_Hmi_BannerFormatter / PRG_07) :
//      bit0 = RedundancyTestFailed, bit1 = EmergencyArmingFailed, bit3 = StartupFail.
instCauses[0].Active := RedundancyTestFailed; instCauses[0].Latching := TRUE;
instCauses[0].Texte := 'Defaut redondance contacteurs AU';
instCauses[1].Active := EmergencyArmingFailed; instCauses[1].Latching := TRUE;
instCauses[1].Texte := 'Echec rearmement contacteur AU (timeout)';
instCauses[2].Active := FALSE; instCauses[2].Latching := FALSE;
instCauses[2].Texte := '';
instCauses[3].Active := StartupFail; instCauses[3].Latching := TRUE;
instCauses[3].Texte := 'Echec autotest demarrage AU';

// Appel du socle TOUJOURS (même Enable=FALSE) : le Reset reste effectif et le latch non
// acquitté reste publié (fail-safe, pas d'effacement silencieux sur bascule Enable OFF→ON).
instFault(Enable := Enable, Reset := Reset, Causes := instCauses);
Status.Fault := instFault.Fault; // source de verite = socle
{endregion}

{region "§10 Projection sorties physiques et bus"}
// ⚡ Sorties physiques — Enable gate fail-safe + interlock Cause brute.
// 🛡️ Maintien conditionné sur (chaîne fermée OU séquence en cours) : hors séquence, une
// boucle AU ouverte (coup-de-poing) coupe le maintien (fail-safe). Pendant la séquence, la
// chaîne est volontairement ouverte par ForceTestA/B -> le maintien reste autorisé (restauration).
Maintain_ChainOk := (EmergencyChainClosed OR (ArmingSeqStep <> CST_STEP_IDLE));
Maintain_NoCutOff := NOT PowerCutOffRequest AND NOT BtnEmergencyCutOff;
MaintainA_NoFault := NOT ForceTestA AND NOT RedundancyTestFailedCause;
MaintainB_NoFault := NOT ForceTestB AND NOT RedundancyTestFailedCause;
MaintainA_NoBlock := Maintain_NoCutOff AND MaintainA_NoFault;
MaintainB_NoBlock := Maintain_NoCutOff AND MaintainB_NoFault;
Cmd.MaintainA_Cmd := Enable AND Maintain_ChainOk AND MaintainA_NoBlock;
Cmd.MaintainB_Cmd := Enable AND Maintain_ChainOk AND MaintainB_NoBlock;
Cmd.ArmPulse_Cmd  := Enable AND (ArmingSeqStep = CST_STEP_PULSE) AND NOT BtnEmergencyCutOff AND NOT PowerCutOffRequest;

// 🚦 Bus d'état public
Status.State.ChainOk     := Enable AND EmergencyChainClosed;
Status.State.ContactorOk := Enable AND PowerContactorEngaged;
Status.State.Step        := ArmingSeqStep;
Status.State.Armable     := Armable;
Status.State.ArmingBusy  := ArmingBusy;

// 🛡️ Bus diagnostic public (vue live du socle)
Status.Diag.Error                := Status.Fault.Error;
Status.Diag.ErrorId              := Status.Fault.ErrorId;
Status.Diag.RedundancyTestFailed := RedundancyTestFailed;
Status.Diag.ArmFailed            := EmergencyArmingFailed;
Status.Diag.LockoutActive        := EmergencyArmingLockoutActive;
Status.Diag.LastAbortStep        := LastAbortStep;
Status.Diag.LastAbortCause       := LastAbortCause;
{endregion}

{region "§11 Etats publics IEC + message operateur"}
// 📤 ÉTATS PUBLICS IEC
Status.Ready := Enable AND NOT StartupFail;
Status.Done  := PowerContactorEngaged;

// 💬 MESSAGE OPÉRATEUR — un message explicite par état et par problème de la chaîne AU.
// Priorité : problème de sécurité > état de séquence. Fusionné côté IHM dans les messages
// opérateurs (FB_Hmi_BannerFormatter lit Diag.ErrorId / scalaires).
IF NOT Enable THEN
    Status.OperatorMessage := 'AU neutralisee (Enable=FALSE)';
ELSIF StartupFail THEN
    Status.OperatorMessage := 'AU: autotest demarrage echoue - verifier boucle/contacteur puis Reset';
ELSIF RedundancyTestFailed THEN
    Status.OperatorMessage := 'AU: defaut redondance contacteurs - verifier puis Reset';
ELSIF EmergencyArmingFailed THEN
    Status.OperatorMessage := 'AU: echec rearmement contacteur (timeout) - verifier puis rearmer';
ELSIF PowerCutOffRequest THEN
    Status.OperatorMessage := 'AU: coupure securite metier active - lever la cause puis rearmer';
ELSIF BtnEmergencyCutOff THEN
    Status.OperatorMessage := 'AU: coupure urgence IHM active - relacher puis rearmer';
ELSIF NOT EmergencyChainClosed THEN
    Status.OperatorMessage := 'AU: boucle urgence ouverte - verifier coup-de-poing';
ELSIF EmergencyArmingLockoutActive THEN
    Status.OperatorMessage := 'AU: verrouillage 5s actif - attendre puis rearmer';
ELSE
    CASE ArmingSeqStep OF
        CST_STEP_IDLE:      Status.OperatorMessage := 'AU: repos - pret a rearmer';
        CST_STEP_TEST_A:    Status.OperatorMessage := 'AU: autotest canal A en cours';
        CST_STEP_RESTORE_A: Status.OperatorMessage := 'AU: restauration canal A';
        CST_STEP_TEST_B:    Status.OperatorMessage := 'AU: autotest canal B en cours';
        CST_STEP_RESTORE_B: Status.OperatorMessage := 'AU: restauration canal B';
        CST_STEP_PULSE:     Status.OperatorMessage := 'AU: impulsion rearmement contacteur';
        CST_STEP_CONFIRM:   Status.OperatorMessage := 'AU: attente confirmation contacteur';
    END_CASE;
END_IF;
{endregion}

END_FUNCTION_BLOCK
