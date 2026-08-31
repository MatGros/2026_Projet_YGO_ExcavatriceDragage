(* =======================================================================
   🛡️ FB_Safety_EmergencyManagement — Gestion de la réd'urgence AU (FB fusionné)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Machine d'état, fronts Reset/Arm, autotest redondance A/B, réarmement
      contacteur, interlock Cause brute, projection fail-safe et latch défaut.
      Fusionne les 3 FB historiques (Composite + Logic + Output) en UN seul FB.
   🔒 Sécurité :
      - fronts Reset/Arm (jamais de redémarrage auto après défaut)
      - interlock TOUJOURS sur la Cause brute (jamais sur l'Ack)
      - fail-safe Enable=FALSE → commandes à FALSE, Ready/Busy à FALSE
      - latch défaut via le socle standard FB_FaultCore (corrige le bug bit3
        StartupFail effacé par la re-synthèse ErrorId := 0)
   🧬 Sorties structurées (2 DUT) : Status : ST_Safety_Emergency_Status
      (Ready/Busy/Done + State + Diag + Fault + OperatorMessage) + Cmd :
      ST_Safety_Emergency_Cmd (MaintainA/B_Cmd + ArmPulse_Cmd).
   📄 Doc métier : DOC/AF/AF_Partie-01_Analyse_Fonctionnelle_v2.1.md
   ======================================================================= *)

FUNCTION_BLOCK FB_Safety_EmergencyManagement
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
    Status                  : ST_Safety_Emergency_Status; // <-- [STAT] État/diagnostic (Ready/Busy/Done + State + Diag + Fault + message) — PRG_07/IHM/Troubleshooting
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
    Armable                   : BOOL; // . [LOC] Rearmement possible actuellement
    ArmingBusy                : BOOL; // . [LOC] Sequence ou lockout en cours
    LastAbortStep             : INT;  // . [LOC] Etape sequence lors du dernier abandon (0 a 6)
    LastAbortCause            : WORD; // . [LOC] Bitfield cause abandon (16#0001=Cut, 16#0002=Chute chaine, 16#0004=Timeout A, 16#0008=Timeout B, 16#0010=PowerCutOff, 16#0020=Redondance A, 16#0040=Redondance B, 16#0080=Timeout contacteur)

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
END_VAR

// === IMPLEMENTATION ===


// 🔄 Fronts
EnableRising(CLK := Enable);
ResetEdge(CLK := Reset);
ArmReqEdge(CLK := ArmRequest);



// 🛑 1. GATE — neutralisation si désactivé. Les sorties physiques sont forcées à FALSE
// (fail-safe) ; le socle défaut reste appelé (§9) pour maintenir le latch non acquitté.
IF NOT Enable THEN
    ArmingSeqStep := 0;
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
    LastAbortStep := 0;
    LastAbortCause := 16#0000;
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
ELSE
    
    // 🏁 2. AUTOTEST DÉMARRAGE (§5.4 AF01) — vérifications synchrones 1 cycle au 1er Enable=TRUE
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
        // bit3 (StartupFail) est laté via le socle FB_FaultCore (§9) — jamais effacé par
        // la re-synthèse ErrorId (correction du bug bit3).
    END_IF;
    

    
    // 🔍 3. ACQUITTEMENT DES DÉFAUTS (pattern Cause/Ack — §3.4bis AF01, §9 STD)
    // ⚠️ Reset acquitte l'affichage (Ack:=TRUE). La cause de redondance reste verrouillée
    // jusqu'au prochain test physique. L'échec d'armement précédent est réinitialisé pour autoriser un réessai.
    // Le latch du socle (§9) est effacé par le front Reset (jamais conditionné).
    IF ResetEdge.Q THEN
        RedundancyTestFailedAck := TRUE;
        EmergencyArmingFailedCause := FALSE;
        EmergencyArmingFailedAck := TRUE;
        EmergencyArmingLockoutActive := FALSE;
        StartupFail := FALSE;
    END_IF;
    

    
    // 🛑 Coupure immédiate de toute séquence en cours
    IF ArmingSeqStep <> 0 THEN
        IF BtnEmergencyCutOff THEN
            // Avortement volontaire : pas d'alarme d'échec
            LastAbortStep := ArmingSeqStep;
            LastAbortCause := 16#0001; // Bit0: Demande coupure manuelle IHM
            ArmingSeqStep := 0;
        ELSIF PowerCutOffRequest THEN
            // Avortement sécurité d'urgence : coupure métier (PAS un défaut d'armement).
            // Sécurité conservée : lockout 5s + interlock (Armable/Maintain* bloqués par
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
    

    
    // 🚦 5. ÉTATS PUBLICS — interlock sur Cause brute (jamais sur l'Ack)
    Armable := EmergencyChainClosed
               AND NOT BtnEmergencyCutOff
               AND NOT PowerCutOffRequest
               AND (ArmingSeqStep = 0)
               AND NOT EmergencyArmingLockoutActive
               AND NOT RedundancyTestFailedCause
               AND NOT PowerContactorEngaged;

    ArmingBusy := (ArmingSeqStep <> 0) OR EmergencyArmingLockoutActive;
    

    
    // 📤 6. AFFICHAGE IHM — debounce anti-clignotement (Cause lissée) OR NOT Ack (§9 STD)
    // ⚠️ Uniquement pour l'affichage : l'action de sécurité ci-dessus (§5/§6) reste instantanée
    // sur la Cause brute, jamais retardée par ce debounce.
    TonRedundancyDisplay(IN := RedundancyTestFailedCause, PT := CST_FaultDisplayDebounce);
    RedundancyTestFailed := TonRedundancyDisplay.Q OR NOT RedundancyTestFailedAck;

    TonArmingFailedDisplay(IN := EmergencyArmingFailedCause, PT := CST_FaultDisplayDebounce);
    EmergencyArmingFailed := TonArmingFailedDisplay.Q OR NOT EmergencyArmingFailedAck;
    
END_IF;



// 📤 7. SYNTHÈSE DES ERREURS — socle standard FB_FaultCore (vue live + vue latchée).
//    Chaque cause est exprimée EN CLAIR (ST_FaultCause) ; le socle en déduit ST_Fault.
//    🔒 Correction du bug bit3 : StartupFail est une cause indépendante (index 3, Latching=TRUE).
//    Le socle ne réinitialise JAMAIS ErrorId := 0 (contrairement à l'ancienne synthèse) : le bit3
//    StartupFail reste laté jusqu'au front Reset, même si bit0/bit1 sont recalculés.
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



// ⚡ Sorties physiques — Enable gate fail-safe + interlock Cause brute.
// 🛡️ Maintien conditionné sur (chaîne fermée OU séquence en cours) : hors séquence, une
// boucle AU ouverte (coup-de-poing) coupe le maintien (fail-safe). Pendant la séquence, la
// chaîne est volontairement ouverte par ForceTestA/B -> le maintien reste autorisé (restauration).
Cmd.MaintainA_Cmd := Enable AND (EmergencyChainClosed OR (ArmingSeqStep <> 0))
                     AND NOT PowerCutOffRequest AND NOT ForceTestA AND NOT BtnEmergencyCutOff AND NOT RedundancyTestFailedCause;
Cmd.MaintainB_Cmd := Enable AND (EmergencyChainClosed OR (ArmingSeqStep <> 0))
                     AND NOT PowerCutOffRequest AND NOT ForceTestB AND NOT BtnEmergencyCutOff AND NOT RedundancyTestFailedCause;
Cmd.ArmPulse_Cmd  := Enable AND (ArmingSeqStep = 5) AND NOT BtnEmergencyCutOff AND NOT PowerCutOffRequest;

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



// 📤 8. ÉTATS PUBLICS IEC
Status.Ready := Enable AND NOT StartupFail;
Status.Busy  := (ArmingSeqStep <> 0) OR EmergencyArmingLockoutActive;
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
        0: Status.OperatorMessage := 'AU: repos - pret a rearmer';
        1: Status.OperatorMessage := 'AU: autotest canal A en cours';
        2: Status.OperatorMessage := 'AU: restauration canal A';
        3: Status.OperatorMessage := 'AU: autotest canal B en cours';
        4: Status.OperatorMessage := 'AU: restauration canal B';
        5: Status.OperatorMessage := 'AU: impulsion rearmement contacteur';
        6: Status.OperatorMessage := 'AU: attente confirmation contacteur';
    END_CASE;
END_IF;


END_FUNCTION_BLOCK
