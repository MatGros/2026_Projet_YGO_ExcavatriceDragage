(* =======================================================================
   ⚙️ FB_Cycle — Séquenceur du cycle automatique (Grafcet de dragage)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Automate de cycle automatique de dragage (X0 à X13 + STABILIZING)
   🔒 Sécurité : Gating par mode et homme-mort, repli STABILIZING sur défaut
   🔌 Interface : Demandes de mouvements (treuils, translation, benne)
   📄 Doc métier : DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.3.md
   ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_Cycle
VAR_INPUT
    // === COMMANDES & AUTORISATIONS ===
    Enable                  : BOOL;         // --> [CMD] Activation generale du sequenceur
    Reset                   : BOOL;         // --> [CMD] Acquittement defaut (front)
    PowerContactorEngaged   : BOOL;         // --> [SAFE] Chaine de securite OK
    EncoderFaultPresent     : BOOL;         // --> [SAFE] Defaut codeur agrege (cycle non autorise)
    Mode                    : E_Mode;       // --> [CMD] Mode arbitre (SEMI_AUTO pour instance cycle)
    JoystickDeflected       : BOOL;         // --> [CMD] Manche deflecte (non centre)
    DeadmanArmed            : BOOL;         // --> [CMD] Appui homme-mort (fenetre 3 s)
    HeartbeatIhmOk          : BOOL;         // --> [SAFE] IHM<->PLC valide

    // === COMMANDES OPERATEUR ===
    StartCycle              : BOOL;         // --> [CMD] Demande lancement / reprise (IHM)
    AbortCycle              : BOOL;         // --> [CMD] Demande abandon (IHM)

    // === CIBLES ET CONFIGURATION ===
    SelTarget               : INT;          // --> [CFG] Cible selectionnee (1=Tremie, 2=P2, 3=P1, 4=Maintenance)
    SetDepthM               : REAL;         // --> [CFG] Profondeur de consigne (negative)
    SetOffsetM              : REAL;         // --> [CFG] Ecart de fermeture benne cible

    // === FEEDBACKS CAPTEURS & MATERIEL ===
    KoboldContactFond       : BOOL;         // --> [HW] Retour dedie Kobold : TRUE = contact fond
    LimitLegalReached       : BOOL;         // --> [SAFE] Limite legale atteinte (descente interdite)
    LimitLegalDepthM        : REAL;         // --> [CFG] Profondeur legale minimale autorisee
    WinchSyncError          : BOOL;         // --> [SAFE] Desynchronisme bloquant M1/M2
    WinchSyncDeltaM         : REAL;         // --> [HW] Ecart codeurs M1/M2 pour diagnostic
    M1_CablePosM            : REAL;         // --> [HW] Position cable treuil M1 (recalee)
    M2_CablePosM            : REAL;         // --> [HW] Position cable treuil M2 (recalee)
    M1_MeasuredSpeedMps     : REAL;         // --> [HW] Vitesse lineaire mesuree M1 (m/s)
    M2_MeasuredSpeedMps     : REAL;         // --> [HW] Vitesse lineaire mesuree M2 (m/s)
    SpeedMismatchThresholdMps : REAL;       // --> [CFG] Seuil ecart vitesse ; 0 = controle desactive
    SpeedMismatchTimeout    : TIME;         // --> [CFG] Duree de confirmation ; 0 = controle desactive
    CableLimitM1AscentM     : REAL;         // --> [CFG] Limite haute d'exploitation M1

    // === FEEDBACKS TRANSLATION M3 ===
    Translation_At_P1           : BOOL;     // --> [HW] Capteur position P1 (arret travail)
    Translation_At_Tremie       : BOOL;     // --> [HW] Capteur fin de course tremie
    Translation_At_Maintenance : BOOL;     // --> [HW] Capteur fin de course maintenance
    Translation_Busy            : BOOL;     // --> [HW] Mouvement translation en cours
    Translation_Done            : BOOL;     // --> [HW] Cible translation atteinte

    // === FEEDBACKS BENNE ===
    Benne_Busy              : BOOL;         // --> [HW] Mouvement machoires benne en cours
    Benne_Done              : BOOL;         // --> [HW] Mouvement ouverture/fermeture termine
    Benne_IsOpen            : BOOL;         // --> [HW] Benne mecaniquement ouverte memorisee
    Benne_IsClosed          : BOOL;         // --> [HW] Benne mecaniquement fermee memorisee
    Benne_IsRoughlyClosed   : BOOL;         // --> [HW] Benne a peu pres fermee (tolerance matiere)

    // === REFERENCEMENT CODEURS ===
    HomedM1                 : BOOL;         // --> [HW] Codeur M1 reference
    HomedM2                 : BOOL;         // --> [HW] Codeur M2 reference
    TopPositionSensor       : BOOL;         // --> [HW] Capteur position haute (referencement)
    HomingRequest           : BOOL;         // --> [CMD] Demande de referencement (front)

    // === CONFIG & COMMANDES CYCLE (IHM) ===
    CfgDrainTime           : TIME;         // --> [CFG] Duree d'egouttage X9 configurable IHM (<= 0 -> defaut interne)
    SkipDrainRequest       : BOOL;         // --> [CMD] Bouton IHM : passer l'etape d'egouttage X9 (front)
END_VAR
VAR_OUTPUT
    // === ETATS IEC & DEFECTUOSITES ===
    Ready                   : BOOL;         // <-- [STAT] Sequenceur disponible
    Fault                   : ST_Fault;     // <-- [SAFE] Socle defaut transverse (live + latche)
    Lifecycle               : ST_Lifecycle; // <-- [STAT] Cycle de vie (Busy, Done, Waiting)
    SpeedMismatchMps        : REAL;         // <-- [DIAG] Ecart absolu vitesse M1/M2 (m/s)
    SpeedMismatchActive     : BOOL;         // <-- [DIAG] Seuil vitesse depasse sur cycle courant
    SpeedMismatchConfirmed  : BOOL;         // <-- [DIAG] Ecart vitesse confirme pendant timeout

    // === ORDRES ACTIONNEURS (COMMANDES STRUCTUREES) ===
    // Types de contrat inter-PRG uniques (ST_Program*Request) : FB_Cycle produit
    // directement les demandes consommées par PRG_04/05/07 — plus de DUT
    // ST_fbCycle_*CmdDemand redondants ni de re-mapping champ-à-champ (NC-090).
    WinchM1Cmd              : ST_ProgramWinchRequest;        // <-- [ACT] Demande treuil M1
    WinchM2Cmd              : ST_ProgramWinchRequest;        // <-- [ACT] Demande treuil M2
    TranslationCmd          : ST_ProgramTranslationRequest;  // <-- [ACT] Demande translation M3
    BucketCmd               : ST_ProgramBucketRequest;       // <-- [ACT] Demande benne

    // === METADONNEES & SYNOPTIQUE ===
    CycleStep               : E_CycleStep;          // <-- [STAT] Etape active du Grafcet
    CycleStateStr           : STRING(80);           // <-- [STAT] Libelle en clair de l'etape
    CycleStepAtError        : E_CycleStep;          // <-- [DIAG] Etape specifique au moment du defaut
    OperatorActionId        : WORD;                 // <-- [DIAG] ID action operateur requise
    OperatorAction          : STRING(120);          // <-- [DIAG] Message explicatif pour l'IHM
    ExpectedAxis            : E_OperatorAxis;       // <-- [STAT] Organe joystick/bouton attendu
    ExpectedDirection       : INT;                  // <-- [STAT] Sens attendu (-1, 0, +1)
    WaitingForOperator      : BOOL;                 // <-- [STAT] En attente d'une action operateur
    WaitingForProcess       : BOOL;                 // <-- [STAT] En attente d'une condition procede
    RequestActive           : BOOL;                 // <-- [STAT] Demande de mouvement active
    CurrentCycleElapsed     : TIME;                 // <-- [DIAG] Duree ecoulee du cycle en cours (chronometre sur Lifecycle.Busy)
    LastCycleDuration       : TIME;                 // <-- [DIAG] Duree du dernier cycle acheve (figee a X13, persiste au cycle suivant)
END_VAR
VAR_IN_OUT
    // === STRUCTURES PARTAGEES & COMPTEURS ===
    SampleCount             : INT;          // <-> [BUS] Compteur de prelevements (RETAIN)
END_VAR
VAR
    // === DETECTEURS DE FRONTS ===
    ResetEdge               : R_TRIG;       // . [LOC] Detecteur front montant Reset
    StartEdge               : R_TRIG;       // . [LOC] Detecteur front montant StartCycle
    DeadmanArmedEdge        : R_TRIG;       // . [LOC] Detecteur front montant DeadmanArmed (demarrage joystick)
    AbortEdge               : R_TRIG;       // . [LOC] Detecteur front montant AbortCycle
    ErrorEdge               : R_TRIG;       // . [LOC] Detecteur front montant Error

    // === GATE CONTINU HOMME-MORT ===
    CycleMotionPermit       : BOOL; // . [LOC] Permis de mouvement cycle = JoystickDeflected AND DeadmanArmed (manche deflechi + homme-mort arme) ; gate commun a toutes les commandes d'actionneur du sequenceur. Le sens du mouvement reste porte par ReqAscent/ReqDescend de chaque etape.

    // === COMPTEUR PRELEVEMENTS (garde de front) ===
    SampleCountDone         : BOOL := FALSE; // . [LOC] F2: front de comptage SampleCount (1 seul increment par cycle)

    // === ETATS INTERNES ===
    State                   : E_CycleStep := E_CycleStep.X0_PREPARATION; // . [LOC] Etape courante machine d'etat
    SavedState              : E_CycleStep := E_CycleStep.X0_PREPARATION; // . [LOC] Etape memorisee
    PausedState             : E_CycleStep := E_CycleStep.X0_PREPARATION; // . [LOC] Etape en pause lors de la bascule hors auto
    WaitingResume           : BOOL := FALSE;                             // . [LOC] En attente de validation consciente pour reprendre

    // === MEMORISATIONS & REGISTRES INTERNES ===
    TouchPositionM          : REAL;         // . [LOC] Position M1 memorisee lors du contact fond
    RaiseTargetM            : REAL;         // . [LOC] Profondeur de remontee memorisee
    SelectedWorkTarget      : INT;          // . [LOC] Cible de travail memorisee
    StepMaxPrevState        : E_CycleStep;  // . [LOC] Etape du scan precedent (rearmement StepMaxTimer au changement d'etape)

    // === TEMPORISATEURS INTERNES ===
    DrainingTimer           : TON;          // . [LOC] Temporisateur de vidage (egouttage), PT = DrainTimeEff
    CycleRunTimer           : TON;          // . [LOC] Chronometre du cycle en cours (IN = Lifecycle.Busy) ; .ET = duree
    SkipDrainEdge           : R_TRIG;       // . [LOC] Front bouton IHM "passer egouttage"
    DrainTimeEff            : TIME;         // . [LOC] Duree d'egouttage effective (CfgDrainTime bornee au defaut interne)
    StabilizationTimer      : TON;          // . [LOC] Temporisation maximale de remontee lente
    SpeedMismatchTimer      : TON;          // . [LOC] Confirmation temporelle ecart de vitesse
    StepMaxTimer            : TON;          // . [LOC] Tempo max d'etape

    // === CONSTANTES & CONFIGURATIONS INTERNES ===
    CtrlAscentDistM         : REAL := 2.0;      // . [LOC] Distance de remontee lente de controle
    CtrlAscentToleranceM    : REAL := 0.25;     // . [LOC] Ecart maximal admis entre codeurs
    CtrlAscentTimeout       : TIME := T#30s;    // . [LOC] Temps max pour zone de stabilisation
    DrainingTime            : TIME := T#5s;     // . [LOC] Temps d'egouttage par defaut
    StepMaxTimeout          : TIME := T#60s;    // . [LOC] Tempo max d'etape

    // === SOCLE DEFAUT TRANSVERSE ===
    instFault               : FB_FaultCore;                  // * [INST] Socle defaut transverse
    instCauses              : ARRAY[0..15] OF ST_FaultCause; // . [LOC] Table des causes de defaut
END_VAR
VAR CONSTANT
    // Paliers de vitesse treuil par etape (StepTgt des demandes WinchMxCmd, 1..5 ; 0 = arret).
    CST_StepSlow   : INT := 1;   // Palier lent : referencement X1, remontee X5, controle X7, vidage X11
    CST_StepDive   : INT := 3;   // Palier plongee Kobold X4 : debit mini requis pour la mesure de fond
    CST_StepLoaded : INT := 4;   // Palier montee en charge X8 (bridage strict <= 4, jamais palier 5)
    // Backstop anti-telescopage : ecart de position M1/M2 max tolere pendant les phases
    // reellement couplees hors X7 (qui a deja son propre controle a 0,25 m). Aligne sur
    // CfgSyncCriticalToleranceM = 0,50 m (AF-04 §5). FB_SyncDeviation (PRG_04) reste la
    // surveillance primaire ; ceci est un garde-fou local au sequenceur.
    CST_CoupledPosBacklashM : REAL := 0.5;
END_VAR

// === IMPLEMENTATION ===

{region "§1 Causes & Socle Défaut"}
// 🔑 1. FRONTS ET CAUSES
ResetEdge(CLK := Reset);
StartEdge(CLK := StartCycle);
DeadmanArmedEdge(CLK := DeadmanArmed);
AbortEdge(CLK := AbortCycle);
SkipDrainEdge(CLK := SkipDrainRequest);

// ⏱️ Chronomètre du cycle : compte tant que le séquenceur est actif (Lifecycle.Busy).
// .ET = durée écoulée du cycle en cours ; figée dans LastCycleDuration à l'achèvement (X13).
CycleRunTimer(IN := Lifecycle.Busy, PT := T#12h);
CurrentCycleElapsed := CycleRunTimer.ET;

// Durée d'égouttage effective : config IHM si valide, sinon défaut interne.
DrainTimeEff := SEL(CfgDrainTime <= T#0s, CfgDrainTime, DrainingTime);

// ⏱️ Surveillance indépendante de la remontée lente
// X7_CTRL_ASCENT -> X8_ASCENT_LOADED : TON de stabilisation palier 1.
StabilizationTimer(IN := (State = E_CycleStep.X7_CTRL_ASCENT), PT := CtrlAscentTimeout);

// 📏 Comparaison vitesse réelle M1/M2
SpeedMismatchMps := ABS(M1_MeasuredSpeedMps - M2_MeasuredSpeedMps);
SpeedMismatchActive := (State = E_CycleStep.X7_CTRL_ASCENT)
                       AND JoystickDeflected
                       AND (SpeedMismatchThresholdMps > 0.0)
                       AND (SpeedMismatchTimeout > T#0ms)
                       AND (SpeedMismatchMps > SpeedMismatchThresholdMps);
// X7_CTRL_ASCENT -> STABILIZING : TON confirmation écart vitesse.
SpeedMismatchTimer(IN := SpeedMismatchActive, PT := SpeedMismatchTimeout);
SpeedMismatchConfirmed := SpeedMismatchTimer.Q;

// Tempo max d'étape (R5) — backstop durée d'état, lancé SEULEMENT si pilotage joystick actif.
// Xi -> STABILIZING sur dépassement. Réarmé à CHAQUE changement d'étape (IN=FALSE 1 scan) :
// chaque étape dispose de sa propre fenêtre StepMaxTimeout, la tempo n'est PAS cumulative
// sur l'ensemble du cycle (un cycle réel long ne tombe plus en STABILIZING intempestif).
StepMaxTimer(IN := (State = StepMaxPrevState)
                  AND JoystickDeflected
                  AND (State <> E_CycleStep.X0_PREPARATION)
                  AND (State <> E_CycleStep.X13_DONE_SYNC)
                  AND (State <> E_CycleStep.STABILIZING),
             PT := StepMaxTimeout);
StepMaxPrevState := State;

// Egouttage X9 : TON gaté sur l'étape (remis à 0 hors X9). Remplace l'ancien IN:=TRUE câblé
// qui pouvait laisser Q déjà vrai à l'entrée en X9 (temps d'égouttage non respecté).
DrainingTimer(IN := (State = E_CycleStep.X9_DRAIN_PAUSE), PT := DrainTimeEff);

// Table des causes de défaut
instCauses[0].Active   := LimitLegalReached AND (State = E_CycleStep.X4_DESCEND_OPEN);
instCauses[0].Latching := TRUE;
instCauses[0].Texte    := 'Limite legale de profondeur atteinte pendant descente';

instCauses[1].Active   := WinchSyncError AND (State <> E_CycleStep.X0_PREPARATION) AND (State <> E_CycleStep.STABILIZING);
instCauses[1].Latching := TRUE;
instCauses[1].Texte    := 'Desynchronisme treuils M1/M2 bloquant';

instCauses[2].Active   := SpeedMismatchConfirmed AND (State <> E_CycleStep.X0_PREPARATION) AND (State <> E_CycleStep.STABILIZING);
instCauses[2].Latching := TRUE;
instCauses[2].Texte    := 'Ecart de vitesse M1/M2 confirme en montee';

instCauses[3].Active   := NOT HeartbeatIhmOk AND (State <> E_CycleStep.X0_PREPARATION) AND (State <> E_CycleStep.STABILIZING);
instCauses[3].Latching := TRUE;
instCauses[3].Texte    := 'Perte communication IHM pendant cycle';

instCauses[4].Active   := StepMaxTimer.Q AND (State <> E_CycleStep.STABILIZING);
instCauses[4].Latching := TRUE;
instCauses[4].Texte    := 'Depassement tempo maximale d etape (blocage mouvement)';

instCauses[5].Active   := (StabilizationTimer.Q OR (ABS(M1_CablePosM - M2_CablePosM) > CtrlAscentToleranceM))
                          AND (State = E_CycleStep.X7_CTRL_ASCENT);
instCauses[5].Latching := TRUE;
instCauses[5].Texte    := 'Defaut de stabilisation / tolerance ecart codeurs en remontee controle';

// Backstop anti-telescopage : ecart de position M1/M2 excessif pendant une phase
// reellement couplee (X4 plongee, X5 remontee, X8 montee en charge). X7 a deja son
// propre controle (instCauses[5]). Seuil grossier (0,50 m) : filet local si
// FB_SyncDeviation (PRG_04) ne coupe pas.
instCauses[6].Active   := (ABS(M1_CablePosM - M2_CablePosM) > CST_CoupledPosBacklashM)
                          AND JoystickDeflected
                          AND ((State = E_CycleStep.X4_DESCEND_OPEN)
                            OR (State = E_CycleStep.X5_BOTTOM_CONFIRMED)
                            OR (State = E_CycleStep.X8_ASCENT_LOADED));
instCauses[6].Latching := TRUE;
instCauses[6].Texte    := 'Ecart de position M1/M2 excessif en phase couplee (anti-telescopage)';

// Appel du socle de défaut
instFault(Enable := Enable, Reset := Reset, Causes := instCauses);
Fault := instFault.Fault;
ErrorEdge(CLK := Fault.Error);
{endregion}

{region "§2 Gate securite & Bascule Mode"}
// 🛑 2. GATES DE SÉCURITÉ ET NEUTRALISATION
// Le mode SEMI_AUTO peut être sélectionné sous AU/défaut (FB_Modes), mais le cycle
// ne tourne JAMAIS sans puissance (PowerContactorEngaged) ni avec un codeur défaillant
// (EncoderFaultPresent) — les données de position invalides rendraient le Grafcet erroné.
IF NOT Enable OR NOT PowerContactorEngaged OR EncoderFaultPresent THEN
    WinchM1Cmd.RunRequest     := FALSE;
    WinchM1Cmd.ReqAscent      := FALSE;
    WinchM1Cmd.ReqDescend     := FALSE;
    WinchM1Cmd.StepTgt        := 0;

    WinchM2Cmd.RunRequest     := FALSE;
    WinchM2Cmd.ReqAscent      := FALSE;
    WinchM2Cmd.ReqDescend     := FALSE;
    WinchM2Cmd.StepTgt        := 0;

    TranslationCmd.ReqStart   := FALSE;
    TranslationCmd.PositionTgt  := 0;

    BucketCmd.ReqOpen         := FALSE;
    BucketCmd.ReqClose        := FALSE;
    BucketCmd.ReqKoboldMeasureEnable := FALSE;

    // Si on quitte le semi-auto alors qu'un cycle était en cours, on mémorise l'étape pour la pause
    IF (State <> E_CycleStep.X0_PREPARATION) AND (State <> E_CycleStep.X13_DONE_SYNC) AND (State <> E_CycleStep.STABILIZING) THEN
        PausedState := State;
        WaitingResume := TRUE;
    END_IF;

    CycleStep            := State;
    CycleStateStr        := 'Cycle desactive : securite/codeur/mode';
    Ready                := FALSE;
    Lifecycle.Busy       := FALSE;
    Lifecycle.Done       := FALSE;
    SpeedMismatchTimer(IN := FALSE, PT := SpeedMismatchTimeout);
    SpeedMismatchMps := 0.0;
    SpeedMismatchActive := FALSE;
    SpeedMismatchConfirmed := FALSE;
    OperatorActionId := 0;
    IF EncoderFaultPresent THEN
        OperatorAction := 'Cycle non autorise : defaut codeur present. Reinitialiser le defaut codeur.';
    ELSE
        OperatorAction := 'Passer en mode Semi-Auto et engager la securite pour activer le cycle.';
    END_IF;
    ExpectedAxis := E_OperatorAxis.NONE;
    ExpectedDirection := 0;
    WaitingForOperator := FALSE;
    WaitingForProcess := FALSE;
    RequestActive := FALSE;
    RETURN;
END_IF;

Ready := Enable AND NOT Fault.Latched;

// 🛡️ Gate continu homme-mort : le mouvement n'est autorisé que si le manche est
// défléchi (JoystickDeflected) ET l'homme-mort est armé (DeadmanArmed). Chaque
// commande de mouvement est gatée par ce permis à chaque scan (pas seulement au
// démarrage). Le séquenceur (transitions X0→X13) reste piloté par JoystickDeflected.
CycleMotionPermit := JoystickDeflected AND DeadmanArmed;

// Au retour en Semi-Auto, si une étape était en cours, on exige une reprise consciente
IF WaitingResume THEN
    // 🔒 Sécurité anti-redémarrage automatique (AF-04 §4.1) : le cycle ne reprend
    // PAS sur manche + homme-mort seuls. Il reste en attente d'un geste conscient
    // (StartCycle) avant de restaurer l'étape mémorisée.
    IF StartEdge.Q THEN
        State := PausedState;   // reprise consciente : restaure l'étape mémorisée
        WaitingResume := FALSE;
    ELSE
        // Hold : neutralise toute demande de mouvement et affiche l'attente.
        WinchM1Cmd.RunRequest := FALSE; WinchM1Cmd.ReqAscent := FALSE; WinchM1Cmd.ReqDescend := FALSE; WinchM1Cmd.StepTgt := 0;
        WinchM2Cmd.RunRequest := FALSE; WinchM2Cmd.ReqAscent := FALSE; WinchM2Cmd.ReqDescend := FALSE; WinchM2Cmd.StepTgt := 0;
        TranslationCmd.ReqStart := FALSE; TranslationCmd.PositionTgt := 0;
        BucketCmd.ReqOpen := FALSE; BucketCmd.ReqClose := FALSE; BucketCmd.ReqKoboldMeasureEnable := FALSE;
        CycleStep := PausedState;
        CycleStateStr := 'Cycle en pause : reprise consciente requise (StartCycle)';
        Lifecycle.Busy := FALSE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.BUTTON;
        ExpectedDirection := 0;
        WaitingForOperator := TRUE;
        WaitingForProcess := FALSE;
        OperatorActionId := 16#0400;
        OperatorAction := 'Reprendre le cycle : appuyer sur StartCycle (geste conscient).';
        RequestActive := FALSE;
    END_IF;
END_IF;

// 🧊 R9 — capture l'étape spécifique AVANT la bascule vers STABILIZING
IF ErrorEdge.Q THEN
    CycleStepAtError := State;
    State := E_CycleStep.STABILIZING;
    WaitingResume := FALSE;   // un défaut abroge la reprise consciente : repli STABILIZING
END_IF;

IF ResetEdge.Q THEN
    SavedState := E_CycleStep.X0_PREPARATION;
    IF State = E_CycleStep.STABILIZING THEN
        State := E_CycleStep.X0_PREPARATION;
    END_IF;
END_IF;

// Gestion de l'Abandon explicite
IF AbortEdge.Q THEN
    State := E_CycleStep.X0_PREPARATION;
    WaitingResume := FALSE;
    PausedState := E_CycleStep.X0_PREPARATION;
END_IF;

// SEMI_AUTO : FB_Cycle est le SEUL producteur des demandes benne. Les champs
// assistants (DiveSearch/ExtractionAssist) sont inactifs en cycle automatique
// -> valeurs neutres déterministes (identiques à la branche SEMI_AUTO de PRG_03).
BucketCmd.DescendPermitDiveBucketOpen := TRUE;
BucketCmd.ExtractionControlActive := FALSE;
BucketCmd.MinStepDown := 0;
{endregion}

{region "§3 Machine etat cycle automatique"}
// 🔁 2. LOGIQUE DU SÉQUENCEUR (Machine d'état) — CASE sur enum unique (R1)
// Pendant une reprise consciente (WaitingResume), le séquenceur est gelé :
// l'étape mémorisée ne s'exécute pas tant que StartCycle n'a pas été appuyé.
IF NOT WaitingResume THEN
CASE State OF

    E_CycleStep.X0_PREPARATION:
        CycleStep := E_CycleStep.X0_PREPARATION;
        CycleStateStr := 'X0 - Verification coherence systeme';
        WinchM1Cmd.RunRequest := FALSE; WinchM1Cmd.ReqAscent := FALSE; WinchM1Cmd.ReqDescend := FALSE; WinchM1Cmd.StepTgt := 0;
        WinchM2Cmd.RunRequest := FALSE; WinchM2Cmd.ReqAscent := FALSE; WinchM2Cmd.ReqDescend := FALSE; WinchM2Cmd.StepTgt := 0;
        TranslationCmd.ReqStart := FALSE; TranslationCmd.PositionTgt := 0;
        BucketCmd.ReqOpen := FALSE; BucketCmd.ReqClose := FALSE; BucketCmd.ReqKoboldMeasureEnable := FALSE;
        Lifecycle.Busy := FALSE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.BUTTON;
        ExpectedDirection := 0;
        WaitingForOperator := TRUE;
        WaitingForProcess := FALSE;
        OperatorActionId := 16#0400;
        OperatorAction := 'Demander le demarrage du cycle (Bouton IHM ou armement Homme-Mort).';
        SampleCountDone := FALSE;   // F2: réarmement du front de comptage à chaque entrée en X0

        // Transition si système sain et réarmé (front reset ou démarrage).
        // 🔫 D2 : démarrage par bouton IHM (StartEdge) OU armement homme-mort joystick
        IF (StartEdge.Q OR DeadmanArmedEdge.Q) AND NOT Fault.Latched THEN
            WaitingResume := FALSE;
            State := E_CycleStep.X1_HOMING;
        END_IF;

    E_CycleStep.X1_HOMING:
        CycleStep := E_CycleStep.X1_HOMING;
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedDirection := 0;

        // 🎯 Le referencement machine (datum M1/M2 + etat benne) est la responsabilite
        // EXCLUSIVE de FB_MachineHomingCycle. SEMI_AUTO n'est cense etre accessible que si
        // MachineHomed (gate FB_Modes). X1 ne fait donc QUE verifier la condition : elle
        // n'emet AUCUN ordre de mouvement et ne contient aucun referencement.
        IF HomedM1 AND HomedM2 THEN
            CycleStateStr := 'X1 - Codeurs references : position validee';
            ExpectedAxis := E_OperatorAxis.NONE;
            WaitingForOperator := FALSE;
            WaitingForProcess := TRUE;
            OperatorActionId := 0;
            OperatorAction := '';
            State := E_CycleStep.X2_WORK_POS_SELECT;   // franchie sans mouvement
        ELSE
            CycleStateStr := 'X1 - Machine non referencee';
            ExpectedAxis := E_OperatorAxis.BUTTON;
            WaitingForOperator := TRUE;
            WaitingForProcess := FALSE;
            OperatorActionId := 16#0401;
            OperatorAction := 'Machine non referencee : passer en maintenance pour le referencement.';
        END_IF;

    E_CycleStep.X2_WORK_POS_SELECT:
        CycleStep := E_CycleStep.X2_WORK_POS_SELECT;
        CycleStateStr := 'X2 - Selection position travail';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_X;
        ExpectedDirection := 0;
        WaitingForOperator := (SelTarget = 0) OR NOT JoystickDeflected;
        WaitingForProcess := (SelTarget <> 0) AND JoystickDeflected;
        OperatorActionId := 16#0402;
        OperatorAction := 'Selectionner la cible et maintenir la translation vers la position de travail.';

        IF (SelTarget = 1) OR (SelTarget = 3) OR (SelTarget = 4) THEN
            SelectedWorkTarget := SelTarget;
            TranslationCmd.PositionTgt := SelTarget;
            TranslationCmd.ReqStart := CycleMotionPermit;
            // Arrivée à la cible (Trémie/P1/Maintenance)
            IF JoystickDeflected AND (
                (SelTarget = 1 AND Translation_At_Tremie) OR
                (SelTarget = 3 AND Translation_At_P1) OR
                (SelTarget = 4 AND Translation_At_Maintenance)) THEN
                TranslationCmd.ReqStart := FALSE;
                State := E_CycleStep.X3_OPEN_BUCKET;
            END_IF;
        END_IF;

    E_CycleStep.X3_OPEN_BUCKET:
        CycleStep := E_CycleStep.X3_OPEN_BUCKET;
        CycleStateStr := 'X3 - Ouverture benne';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_Y;
        ExpectedDirection := 0;
        WaitingForOperator := NOT JoystickDeflected;
        WaitingForProcess := JoystickDeflected;
        OperatorActionId := 16#0403;
        OperatorAction := 'Maintenir le joystick : ouverture complete de la benne.';

        IF Benne_IsOpen THEN
            State := E_CycleStep.X4_DESCEND_OPEN;
        ELSE
            BucketCmd.ReqOpen := CycleMotionPermit;
            IF JoystickDeflected AND Benne_Done AND Benne_IsOpen THEN
                BucketCmd.ReqOpen := FALSE;
                State := E_CycleStep.X4_DESCEND_OPEN;
            END_IF;
        END_IF;

    E_CycleStep.X4_DESCEND_OPEN:
        CycleStep := E_CycleStep.X4_DESCEND_OPEN;
        CycleStateStr := 'X4 - Plongee benne ouverte (synchro)';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_Y;
        ExpectedDirection := -1;
        WaitingForOperator := NOT JoystickDeflected;
        WaitingForProcess := JoystickDeflected;
        OperatorActionId := 16#0404;
        OperatorAction := 'Maintenir la descente : plongee synchro et detection fond Kobold.';

        // M1 et M2 descendent ensemble (synchro gérée en aval)
        WinchM1Cmd.RunRequest := CycleMotionPermit;
        WinchM1Cmd.ReqAscent := FALSE; WinchM1Cmd.ReqDescend := TRUE;
        WinchM1Cmd.StepTgt  := CST_StepDive;
        WinchM2Cmd.RunRequest := CycleMotionPermit;
        WinchM2Cmd.ReqAscent := FALSE; WinchM2Cmd.ReqDescend := TRUE;
        WinchM2Cmd.StepTgt  := CST_StepDive;
        BucketCmd.ReqKoboldMeasureEnable := CycleMotionPermit;

        // Transition uniquement sur le retour dédié Kobold.
        IF JoystickDeflected AND KoboldContactFond THEN
            WinchM1Cmd.RunRequest := FALSE;
            WinchM2Cmd.RunRequest := FALSE;
            BucketCmd.ReqKoboldMeasureEnable := FALSE;
            TouchPositionM := M1_CablePosM;
            IF LimitLegalDepthM < -0.01 THEN
                RaiseTargetM := MAX(TouchPositionM + 0.5, LimitLegalDepthM + 0.5);
            ELSE
                RaiseTargetM := TouchPositionM + 0.5;
            END_IF;
            State := E_CycleStep.X5_BOTTOM_CONFIRMED;
        END_IF;

    E_CycleStep.X5_BOTTOM_CONFIRMED:
        CycleStep := E_CycleStep.X5_BOTTOM_CONFIRMED;
        CycleStateStr := 'X5 - Fond confirme : remontee securisee';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_Y;
        ExpectedDirection := 1;
        WaitingForOperator := NOT JoystickDeflected;
        WaitingForProcess := JoystickDeflected;
        OperatorActionId := 16#0405;
        OperatorAction := 'Fond confirme : maintenir la montee jusqu a la hauteur de fermeture.';

        WinchM1Cmd.RunRequest := CycleMotionPermit;
        WinchM1Cmd.ReqAscent := TRUE; WinchM1Cmd.ReqDescend := FALSE;
        WinchM1Cmd.StepTgt := CST_StepSlow;
        WinchM2Cmd.RunRequest := CycleMotionPermit;
        WinchM2Cmd.ReqAscent := TRUE; WinchM2Cmd.ReqDescend := FALSE;
        WinchM2Cmd.StepTgt := CST_StepSlow;

        IF JoystickDeflected AND (M1_CablePosM >= RaiseTargetM) AND (M2_CablePosM >= RaiseTargetM) THEN
            WinchM1Cmd.RunRequest := FALSE;
            WinchM2Cmd.RunRequest := FALSE;
            State := E_CycleStep.X6_CLOSE_BUCKET;
        END_IF;

    E_CycleStep.X6_CLOSE_BUCKET:
        CycleStep := E_CycleStep.X6_CLOSE_BUCKET;
        CycleStateStr := 'X6 - Fermeture benne (tolerance a peu pres ferme)';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_Y;
        ExpectedDirection := 1;
        WaitingForOperator := NOT JoystickDeflected;
        WaitingForProcess := JoystickDeflected;
        OperatorActionId := 16#0406;
        OperatorAction := 'Maintenir la commande : fermeture de la benne.';

        // X6 = étape benne seule : les DEUX treuils explicitement neutralisés
        // (pas de résidu ReqAscent/StepTgt hérité de X5 — config treuil unique par étape).
        WinchM1Cmd.RunRequest := FALSE; WinchM1Cmd.ReqAscent := FALSE; WinchM1Cmd.ReqDescend := FALSE; WinchM1Cmd.StepTgt := 0;
        WinchM2Cmd.RunRequest := FALSE; WinchM2Cmd.ReqAscent := FALSE; WinchM2Cmd.ReqDescend := FALSE; WinchM2Cmd.StepTgt := 0;
        // L'ordre benne reste soumis au même homme-mort que le cycle : aucune
        // commande d'actionneur ne doit survivre à la perte du permis opérateur.
        BucketCmd.ReqClose := CycleMotionPermit;

        IF JoystickDeflected AND (Benne_Done AND (Benne_IsClosed OR Benne_IsRoughlyClosed)) THEN
            BucketCmd.ReqClose := FALSE;
            State := E_CycleStep.X7_CTRL_ASCENT;
        END_IF;

    E_CycleStep.X7_CTRL_ASCENT:
        CycleStep := E_CycleStep.X7_CTRL_ASCENT;
        CycleStateStr := 'X7 - Remontee lente de controle';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_Y;
        ExpectedDirection := 1;
        WaitingForOperator := NOT JoystickDeflected;
        WaitingForProcess := JoystickDeflected;
        OperatorActionId := 16#0407;
        OperatorAction := 'Maintenir la montee lente : palier de controle et synchronisme.';

        WinchM1Cmd.RunRequest := CycleMotionPermit;
        WinchM1Cmd.ReqAscent := TRUE; WinchM1Cmd.ReqDescend := FALSE;
        WinchM1Cmd.StepTgt  := CST_StepSlow;
        WinchM2Cmd.RunRequest := CycleMotionPermit;
        WinchM2Cmd.ReqAscent := TRUE; WinchM2Cmd.ReqDescend := FALSE;
        WinchM2Cmd.StepTgt  := CST_StepSlow;

        IF JoystickDeflected
           AND (M1_CablePosM >= (TouchPositionM + CtrlAscentDistM))
           AND (M2_CablePosM >= (TouchPositionM + CtrlAscentDistM))
           AND (ABS(M1_CablePosM - M2_CablePosM) <= CtrlAscentToleranceM) THEN
            State := E_CycleStep.X8_ASCENT_LOADED;
        END_IF;

    E_CycleStep.X8_ASCENT_LOADED:
        CycleStep := E_CycleStep.X8_ASCENT_LOADED;
        CycleStateStr := 'X8 - Remontee en charge';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_Y;
        ExpectedDirection := 1;
        WaitingForOperator := NOT JoystickDeflected;
        WaitingForProcess := JoystickDeflected;
        OperatorActionId := 16#0408;
        OperatorAction := 'Maintenir la montee en charge jusqu a la limite haute.';

        WinchM1Cmd.RunRequest := CycleMotionPermit;
        WinchM1Cmd.ReqAscent := TRUE; WinchM1Cmd.ReqDescend := FALSE;
        WinchM1Cmd.StepTgt  := CST_StepLoaded;
        WinchM2Cmd.RunRequest := CycleMotionPermit;
        WinchM2Cmd.ReqAscent := TRUE; WinchM2Cmd.ReqDescend := FALSE;
        WinchM2Cmd.StepTgt  := CST_StepLoaded;

        IF JoystickDeflected AND M1_CablePosM >= CableLimitM1AscentM THEN
            WinchM1Cmd.RunRequest := FALSE;
            WinchM2Cmd.RunRequest := FALSE;
            State := E_CycleStep.X9_DRAIN_PAUSE;
        END_IF;

    E_CycleStep.X9_DRAIN_PAUSE:
        CycleStep := E_CycleStep.X9_DRAIN_PAUSE;
        CycleStateStr := 'X9 - Egouttage du godet en cours';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.NONE;
        ExpectedDirection := 0;
        WaitingForOperator := FALSE;
        WaitingForProcess := TRUE;
        OperatorActionId := 16#0409;
        OperatorAction := 'Egouttage : attendre la tempo ou appuyer sur "passer egouttage".';
        WinchM1Cmd.RunRequest := FALSE;
        WinchM2Cmd.RunRequest := FALSE;

        // Tempo d'egouttage armee/remise a zero en §1 (gate sur State = X9, PT = DrainTimeEff).
        // Passage a X10 : fin de tempo OU appui operateur "passer l'egouttage" (SkipDrainEdge).
        IF JoystickDeflected AND (DrainingTimer.Q OR SkipDrainEdge.Q) THEN
            State := E_CycleStep.X10_TRANSLATE_DUMP;
        END_IF;

    E_CycleStep.X10_TRANSLATE_DUMP:
        CycleStep := E_CycleStep.X10_TRANSLATE_DUMP;
        CycleStateStr := 'X10 - Deplacement vers tremie (grille/crible libres)';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_X;
        ExpectedDirection := -1;
        WaitingForOperator := NOT JoystickDeflected;
        WaitingForProcess := JoystickDeflected;
        OperatorActionId := 16#040A;
        OperatorAction := 'Maintenir la translation vers la tremie de dechargement.';

        TranslationCmd.PositionTgt := 1; // Trémie
        TranslationCmd.ReqStart := CycleMotionPermit;

        IF JoystickDeflected AND Translation_At_Tremie THEN
            TranslationCmd.ReqStart := FALSE;
            State := E_CycleStep.X11_OPEN_DUMP;
        END_IF;

    E_CycleStep.X11_OPEN_DUMP:
        CycleStep := E_CycleStep.X11_OPEN_DUMP;
        CycleStateStr := 'X11 - Vidange / ouverture du godet (montee possible, descente ouvre)';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_Y;
        ExpectedDirection := -1;
        WaitingForOperator := NOT JoystickDeflected;
        WaitingForProcess := JoystickDeflected;
        OperatorActionId := 16#040B;
        OperatorAction := 'Deflechir vers le bas pour ouvrir la benne et vider la charge.';

        // X11 est une ouverture par déflexion vers le bas : la direction doit
        // être écrite avant d'être évaluée (ne jamais tester la valeur du scan
        // précédent). Les deux treuils restent synchrones et sous homme-mort.
        WinchM1Cmd.ReqAscent := FALSE; WinchM1Cmd.ReqDescend := TRUE;
        WinchM1Cmd.RunRequest := CycleMotionPermit;
        WinchM1Cmd.StepTgt  := CST_StepSlow;
        WinchM2Cmd.ReqAscent := FALSE; WinchM2Cmd.ReqDescend := TRUE;
        WinchM2Cmd.RunRequest := CycleMotionPermit;
        WinchM2Cmd.StepTgt  := CST_StepSlow;

        BucketCmd.ReqOpen := CycleMotionPermit AND WinchM1Cmd.ReqDescend;

        IF JoystickDeflected AND Benne_Done AND Benne_IsOpen THEN
            BucketCmd.ReqOpen := FALSE;
            State := E_CycleStep.X13_DONE_SYNC;
        END_IF;

    E_CycleStep.X13_DONE_SYNC:
        CycleStep := E_CycleStep.X13_DONE_SYNC;
        CycleStateStr := 'X13 - Cycle automatique complete - pret';
        WinchM1Cmd.RunRequest := FALSE;
        WinchM2Cmd.RunRequest := FALSE;
        TranslationCmd.ReqStart := FALSE;
        Lifecycle.Done := TRUE;
        Lifecycle.Busy := FALSE;
        ExpectedAxis := E_OperatorAxis.BUTTON;
        ExpectedDirection := 0;
        WaitingForOperator := TRUE;
        WaitingForProcess := FALSE;
        OperatorActionId := 16#040D;
        OperatorAction := 'Cycle termine avec succes. Relancer un nouveau cycle.';

        // Compteur de prélèvements (RETAIN) + durée du cycle — F2: cadré par front (1 seul par cycle)
        IF NOT SampleCountDone THEN
            SampleCount := SampleCount + 1;
            LastCycleDuration := CurrentCycleElapsed;   // fige la durée du cycle qui vient de s'achever
            SampleCountDone := TRUE;
        END_IF;

        IF StartEdge.Q THEN
            SampleCountDone := FALSE;
            Lifecycle.Done := FALSE;
            State := E_CycleStep.X0_PREPARATION;
        END_IF;

    E_CycleStep.STABILIZING:
        CycleStep := E_CycleStep.STABILIZING;
        CycleStateStr := 'X14 - Cycle en attente / stabilisation (STAB)';
        WinchM1Cmd.RunRequest := FALSE; WinchM1Cmd.ReqAscent := FALSE; WinchM1Cmd.ReqDescend := FALSE;
        WinchM2Cmd.RunRequest := FALSE; WinchM2Cmd.ReqAscent := FALSE; WinchM2Cmd.ReqDescend := FALSE;
        TranslationCmd.ReqStart := FALSE;
        BucketCmd.ReqOpen := FALSE;
        BucketCmd.ReqClose := FALSE;
        BucketCmd.ReqKoboldMeasureEnable := FALSE;   // Coupure contacteur Kobold au repli defaut (0 ordre residuel)
        Lifecycle.Busy := FALSE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.BUTTON;
        ExpectedDirection := 0;
        WaitingForOperator := TRUE;
        WaitingForProcess := FALSE;
        OperatorActionId := 16#0480;
        OperatorAction := 'Cycle stabilise sur anomalie : acquitter le defaut pour reinitialiser.';

END_CASE;
END_IF;
{endregion}

{region "§4 Repli homme mort & Syntheses"}
// 🛑 Relâchement du manche (retour au centre) OU de l'homme-mort : neutralisation
// des demandes actives. Gate continu : aucune commande d'actionneur ne survit à la
// perte du permis opérateur (manche défléchi ET homme-mort armé).
IF Lifecycle.Busy AND NOT CycleMotionPermit THEN
    WinchM1Cmd.RunRequest := FALSE;
    WinchM2Cmd.RunRequest := FALSE;
    TranslationCmd.ReqStart := FALSE;
    BucketCmd.ReqOpen := FALSE;
    BucketCmd.ReqClose := FALSE;
    BucketCmd.ReqKoboldMeasureEnable := FALSE;
END_IF;

RequestActive := WinchM1Cmd.RunRequest OR WinchM2Cmd.RunRequest OR TranslationCmd.ReqStart OR BucketCmd.ReqOpen OR BucketCmd.ReqClose OR BucketCmd.ReqKoboldMeasureEnable; // Somme logique complete des demandes (contacteur Kobold inclus)
{endregion}

END_FUNCTION_BLOCK
