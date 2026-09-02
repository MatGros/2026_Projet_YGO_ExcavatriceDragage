(* =======================================================================
   🛡️ FB_Safety_EmergencyManagement — Spec composant (v1.2)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Répond au besoin fonctionnel F01.01-F01.08 (AF01 §1, Table des fonctions) : gère la coupure de puissance amont (canaux PLC redondants fail-safe) et la séquence explicite de réarmement du contacteur général, avec auto-test A/B.
   🔒 Sécurité : fronts Reset/Arm (jamais de redémarrage auto), interlock
      sur Cause brute (jamais sur l'Ack), fail-safe Enable=FALSE.
   📤 Sorties structurées (2 DUT) : Status (ST_Safety_Emergency_Status) +
      Cmd (ST_Safety_Emergency_Cmd).
   📄 Doc métier : DOC/AF/AF_Partie-01_Analyse_Fonctionnelle/FB_Safety_EmergencyManagement_v1.2.md (F01.01-F01.08)
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

    // === BYPASS INGENIERIE MES (jamais IHM, jamais production) ===
    // Outils de TRACE mise en service : observer le vrai timing chaine/contacteur sans le
    // shunt materiel des sorties PowerKeepAlive. ⛔ NON SECURISE tant qu'actif.
    BypassArmingPreconditions : BOOL := FALSE; // --> [TST] Arme sans les preconditions (chaine fermee, contacteur au repos, lockout, coupure metier/IHM)
    BypassRedundancyTest      : BOOL := FALSE; // --> [TST] Saute l'auto-test A/B : IDLE -> PULSE directement
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
    WasArmed                  : BOOL; // . [LOC] AU armee au moins une fois (contacteur confirme) ; maintien PowerKeepAlive a travers un appui AU pur — retombe sur raison metier
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
    TonArmPulseInhibit      : TON; // . [LOC] Garde DURE : intervalle mini entre 2 impulsions contacteur (anti-chatter, inconditionnel)
    TonRedundancyDisplay    : TON; // . [LOC] Timer debounce affichage IHM redondance
    TonArmingFailedDisplay  : TON; // . [LOC] Timer debounce affichage IHM rearmement
    SeqRunStartEdge         : R_TRIG; // . [LOC] Front montant "sequence en cours" (arme la garde anti-chatter)
    ArmPulseInhibitActive   : BOOL;   // . [LOC] Garde anti-chatter : aucune nouvelle tentative d'armement (test A/B ou impulsion)

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
// ⚠️ Reset acquitte l'affichage (Ack:=TRUE) ET vide la cause d'auto-test redondance figée.
// Conforme AF-01 §7.4 (« échec auto-test voies → diagnostiquer, puis ACQUITTER, puis réarmer » :
// acquitter est une action distincte du réarmement) et §9 STD (le Reset n'est jamais conditionné).
// Le réarmement réel de la chaîne AU se fait par bouton matériel externe, hors PLC ; la redondance
// électrique reste un étage hardware indépendant (Partie 01). Si l'auto-test PLC rejoue plus tard
// et qu'une voie est réellement collée, il re-détecte et re-latch la cause.
IF Enable THEN
    IF ResetEdge.Q THEN
        RedundancyTestFailedCause := FALSE;
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

    // 🚦 PRÉCONDITIONS D'ARMEMENT — source unique (Armable = State.Armable).
    // ⚠️ Armable_NoBlock SANS `NOT RedundancyTestFailedCause` : la cause de redondance est
    //    latée mais la séquence d'armement la re-teste (§5 étape 1/3) : l'armement reste donc
    //    réellement possible (et sûr) tant que les autres préconditions sont réunies. Afficher
    //    le bouton « Armable » sur cette cause seule bloquait le réarmement après acquittement
    //    (Reset ne purge pas la Cause, cf. §4) alors que l'armement était permis.
    // Armable ne dépend PAS de EmergencyChainClosed : c'est la séquence d'armement qui
    //   referme la chaîne (PowerKeepAlive en série dans la boucle). Un armement gaté sur
    //   « chaîne fermée » serait impossible chaîne ouverte alors que c'est exactement l'état
    //   à récupérer. NOT BtnEmergencyCutOff / NOT PowerCutOffRequest couvrent les cas où la
    //   chaîne est ouverte pour une vraie raison (coup-de-poing, coupure métier).
    Armable_ChainOk := NOT BtnEmergencyCutOff AND NOT PowerCutOffRequest;
    Armable_Idle := (ArmingSeqStep = CST_STEP_IDLE);
    Armable_NoBlock := NOT EmergencyArmingLockoutActive AND NOT PowerContactorEngaged;
    // 🛠️ BypassArmingPreconditions (MES trace) : lève ChainOk + NoBlock ; la séquence doit
    //    toujours partir du repos (Armable_Idle conservé). ⛔ NON SECURISE.
    Armable := (BypassArmingPreconditions OR (Armable_ChainOk AND Armable_NoBlock)) AND Armable_Idle;
    // CASE à étiquettes littérales : 0..6 = CST_STEP_* (GVL_Safety_Emergency).
    // La CI STruCpp exige ces littéraux pour les étiquettes CASE.
    CASE ArmingSeqStep OF
        0: // CST_STEP_IDLE
            ForceTestA := FALSE;
            ForceTestB := FALSE;
            TonTestA(IN := FALSE, PT := CST_TestDuration);
            TonRestoreA(IN := FALSE, PT := CST_TestDuration);
            TonTestB(IN := FALSE, PT := CST_TestDuration);
            TonRestoreB(IN := FALSE, PT := CST_TestDuration);
            TonArmingPulse(IN := FALSE, PT := CST_ArmingPulseDuration);
            TonArmingConfirm(IN := FALSE, PT := CST_ArmingConfirmTimeout);

            IF ArmReqEdge.Q AND Armable AND NOT ArmPulseInhibitActive THEN
                RedundancyTestFailedCause := FALSE;
                EmergencyArmingFailedCause := FALSE;
                // 🛠️ BypassRedundancyTest (MES trace) : saute TEST_A..RESTORE_B, va au pulse.
                IF BypassRedundancyTest THEN
                    ArmingSeqStep := CST_STEP_PULSE;
                ELSE
                    ArmingSeqStep := CST_STEP_TEST_A;
                END_IF;
            END_IF;

        1: // CST_STEP_TEST_A
            ForceTestA := TRUE;
            ForceTestB := FALSE;
            TonTestA(IN := TRUE, PT := CST_TestDuration);

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

        2: // CST_STEP_RESTORE_A
            ForceTestA := FALSE;
            ForceTestB := FALSE;
            TonRestoreA(IN := TRUE, PT := CST_TestDuration);

            IF TonRestoreA.Q THEN
                IF EmergencyChainClosed THEN
                    ArmingSeqStep := CST_STEP_TEST_B;
                ELSE
                    LastAbortStep := CST_STEP_RESTORE_A;
                    LastAbortCause := INT_TO_WORD(CST_ABORT_TIMEOUT_RESTORE_A);
                    ArmingSeqStep := CST_STEP_IDLE;
                END_IF;
            END_IF;

        3: // CST_STEP_TEST_B
            ForceTestA := FALSE;
            ForceTestB := TRUE;
            TonTestB(IN := TRUE, PT := CST_TestDuration);

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

        4: // CST_STEP_RESTORE_B
            ForceTestA := FALSE;
            ForceTestB := FALSE;
            TonRestoreB(IN := TRUE, PT := CST_TestDuration);

            IF TonRestoreB.Q THEN
                IF EmergencyChainClosed THEN
                    ArmingSeqStep := CST_STEP_PULSE;
                ELSE
                    LastAbortStep := CST_STEP_RESTORE_B;
                    LastAbortCause := INT_TO_WORD(CST_ABORT_TIMEOUT_RESTORE_B);
                    ArmingSeqStep := CST_STEP_IDLE;
                END_IF;
            END_IF;

        5: // CST_STEP_PULSE
            ForceTestA := FALSE;
            ForceTestB := FALSE;
            TonArmingPulse(IN := TRUE, PT := CST_ArmingPulseDuration);

            IF TonArmingPulse.Q THEN
                ArmingSeqStep := CST_STEP_CONFIRM;
            END_IF;

        6: // CST_STEP_CONFIRM
            ForceTestA := FALSE;
            ForceTestB := FALSE;
            TonArmingConfirm(IN := TRUE, PT := CST_ArmingConfirmTimeout);

            // 🛠️ BypassArmingPreconditions (MES trace) : pas de contacteur réel au banc →
            //    on considère la confirmation acquise, sans alarme ni lockout. ⛔ NON SECURISE.
            IF PowerContactorEngaged OR BypassArmingPreconditions THEN
                EmergencyArmingLockoutActive := FALSE;
                WasArmed := TRUE; // séquence aboutie -> maintien PowerKeepAlive (même sans retour contacteur, cas bypass MES)
                ArmingSeqStep := CST_STEP_IDLE;
            ELSIF TonArmingConfirm.Q THEN
                EmergencyArmingFailedCause := TRUE;
                EmergencyArmingLockoutActive := TRUE;
                LastAbortStep := CST_STEP_CONFIRM;
                LastAbortCause := INT_TO_WORD(CST_ABORT_TIMEOUT_CONTACTOR);
                ArmingSeqStep := CST_STEP_IDLE;
            END_IF;

        ELSE
            ForceTestA := FALSE;
            ForceTestB := FALSE;
            EmergencyArmingFailedCause := TRUE;
            EmergencyArmingLockoutActive := TRUE;
            LastAbortStep := ArmingSeqStep;
            LastAbortCause := INT_TO_WORD(CST_ABORT_INVALID_STEP);
            ArmingSeqStep := CST_STEP_IDLE;
    END_CASE;

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
// Latch « AU armée » : PowerKeepAlive maintenu à travers un appui AU pur (chaîne
//   physiquement ouverte par le coup-de-poing) tant qu'aucune raison MÉTIER ne demande la
//   coupure. Relâchement AU → chaîne se referme instantanément (contacts PLC restés fermés),
//   pas de réarmement. Retombe sur : coupure métier, coupure IHM, Enable OFF, défaut
//   redondance. Non RETAIN : démarrage à froid = non armé.
IF EnableRising.Q THEN
    WasArmed := FALSE;
END_IF;
IF PowerContactorEngaged THEN
    WasArmed := TRUE;
END_IF;
IF PowerCutOffRequest OR BtnEmergencyCutOff OR NOT Enable OR RedundancyTestFailedCause THEN
    WasArmed := FALSE;
END_IF;

Maintain_ChainOk := (EmergencyChainClosed OR (ArmingSeqStep <> CST_STEP_IDLE) OR WasArmed);
Maintain_NoCutOff := NOT PowerCutOffRequest AND NOT BtnEmergencyCutOff;
MaintainA_NoFault := NOT ForceTestA AND NOT RedundancyTestFailedCause;
MaintainB_NoFault := NOT ForceTestB AND NOT RedundancyTestFailedCause;
MaintainA_NoBlock := Maintain_NoCutOff AND MaintainA_NoFault;
MaintainB_NoBlock := Maintain_NoCutOff AND MaintainB_NoFault;
Cmd.MaintainA_Cmd := Enable AND Maintain_ChainOk AND MaintainA_NoBlock;
Cmd.MaintainB_Cmd := Enable AND Maintain_ChainOk AND MaintainB_NoBlock;
// 🛡️ Garde DURE anti-chatter : dès qu'une séquence d'armement DÉMARRE (IDLE -> non-IDLE),
//    aucune nouvelle tentative avant CST_ArmingLockout. Bloque aussi bien le test redondance
//    (ForceTestA/B ouvre PowerKeepAlive A puis B) que l'impulsion contacteur. Inconditionnel :
//    succès, échec, bypass ingénierie MES. Un cyclage rapide du contacteur casse le matériel.
SeqRunStartEdge(CLK := (ArmingSeqStep <> CST_STEP_IDLE));
IF SeqRunStartEdge.Q THEN
    ArmPulseInhibitActive := TRUE;
END_IF;
IF NOT Enable OR EnableRising.Q THEN
    ArmPulseInhibitActive := FALSE;
END_IF;
TonArmPulseInhibit(IN := ArmPulseInhibitActive, PT := CST_ArmingLockout);
IF TonArmPulseInhibit.Q THEN
    ArmPulseInhibitActive := FALSE;
END_IF;

Cmd.ArmPulse_Cmd  := Enable AND (ArmingSeqStep = CST_STEP_PULSE)
                     AND NOT BtnEmergencyCutOff AND NOT PowerCutOffRequest
                     AND NOT ArmPulseInhibitActive;
// 🧪 TestCutActive : signale à la simulation qu'un canal est coupé pour le test de
// redondance A/B (ForceTestA/B). La simulation ouvre alors la boucle AU (SimChainOk=FALSE)
// pour que le test valide la chute de chaîne — sans dépendre de PowerCutOff_A/B (cercle cassé).
Cmd.TestCutActive := Enable AND (ForceTestA OR ForceTestB);

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
Status.Diag.WasArmed             := WasArmed;
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
ELSIF (BypassArmingPreconditions OR BypassRedundancyTest) THEN
    Status.OperatorMessage := 'AU: BYPASS INGENIERIE MES ACTIF - controles/auto-test desactives - NON SECURISE';
ELSIF StartupFail THEN
    Status.OperatorMessage := 'AU: autotest demarrage echoue - verifier boucle/contacteur puis Reset';
ELSIF RedundancyTestFailed THEN
    Status.OperatorMessage := 'AU: defaut redondance contacteurs - verifier puis Reset';
ELSIF EmergencyArmingFailed THEN
    // Échec d'armement — non bloquant (alarme seule). Message court décodé sur LastAbortCause.
    IF LastAbortCause = INT_TO_WORD(CST_ABORT_TIMEOUT_CONTACTOR) THEN
        Status.OperatorMessage := 'AU echec: contacteur non confirme';
    ELSIF LastAbortCause = INT_TO_WORD(CST_ABORT_REDUNDANCY_A) THEN
        Status.OperatorMessage := 'AU echec: voie A collee';
    ELSIF LastAbortCause = INT_TO_WORD(CST_ABORT_REDUNDANCY_B) THEN
        Status.OperatorMessage := 'AU echec: voie B collee';
    ELSIF LastAbortCause = INT_TO_WORD(CST_ABORT_TIMEOUT_RESTORE_A) THEN
        Status.OperatorMessage := 'AU echec: chaine non refermee (voie A)';
    ELSIF LastAbortCause = INT_TO_WORD(CST_ABORT_TIMEOUT_RESTORE_B) THEN
        Status.OperatorMessage := 'AU echec: chaine non refermee (voie B)';
    ELSIF LastAbortCause = INT_TO_WORD(CST_ABORT_CHAIN_DROP) THEN
        Status.OperatorMessage := 'AU echec: chaine ouverte pendant pulse';
    ELSIF LastAbortCause = INT_TO_WORD(CST_ABORT_POWER_CUTOFF) THEN
        Status.OperatorMessage := 'AU echec: coupure metier en sequence';
    ELSIF LastAbortCause = INT_TO_WORD(CST_ABORT_CUT_IHM) THEN
        Status.OperatorMessage := 'AU echec: coupure IHM en sequence';
    ELSIF LastAbortCause = INT_TO_WORD(CST_ABORT_INVALID_STEP) THEN
        Status.OperatorMessage := 'AU echec: etape invalide - Reset';
    ELSE
        Status.OperatorMessage := 'AU echec armement - relancer';
    END_IF;
ELSIF PowerCutOffRequest THEN
    Status.OperatorMessage := 'AU: coupure securite metier active - lever la cause puis rearmer';
ELSIF BtnEmergencyCutOff THEN
    Status.OperatorMessage := 'AU: coupure urgence IHM active - relacher puis rearmer';
ELSIF NOT EmergencyChainClosed THEN
    Status.OperatorMessage := 'AU: boucle urgence ouverte - verifier coup-de-poing';
ELSIF EmergencyArmingLockoutActive THEN
    Status.OperatorMessage := 'AU: verrouillage 5s actif - attendre puis rearmer';
ELSE
    // 📌 Étiquettes en LITTÉRAUX numériques (pattern PresetSeqStep / FB_Encoder_Abs) :
    //    le jumeau CI STruCpp ne génère pas d'étiquettes CASE constexpr depuis des constantes
    //    GVL (IECVar non-constexpr) ; CODESYS accepte les deux formes. La correspondance
    //    symbolique vit ici : 0..6 = CST_STEP_* (GVL_Safety_Emergency).
    CASE ArmingSeqStep OF
        0: // IDLE (= CST_STEP_IDLE)
            Status.OperatorMessage := 'AU: repos - pret a rearmer';
        1: // TEST_A (= CST_STEP_TEST_A)
            Status.OperatorMessage := 'AU: autotest canal A en cours';
        2: // RESTORE_A (= CST_STEP_RESTORE_A)
            Status.OperatorMessage := 'AU: restauration canal A';
        3: // TEST_B (= CST_STEP_TEST_B)
            Status.OperatorMessage := 'AU: autotest canal B en cours';
        4: // RESTORE_B (= CST_STEP_RESTORE_B)
            Status.OperatorMessage := 'AU: restauration canal B';
        5: // PULSE (= CST_STEP_PULSE)
            Status.OperatorMessage := 'AU: impulsion rearmement contacteur';
        6: // CONFIRM (= CST_STEP_CONFIRM)
            Status.OperatorMessage := 'AU: attente confirmation contacteur';
    END_CASE;
END_IF;
{endregion}

END_FUNCTION_BLOCK
