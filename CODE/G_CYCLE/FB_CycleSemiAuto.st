(* =======================================================================
   ⚙️ FB_CycleSemiAuto — Séquenceur du cycle automatique (Grafcet de dragage)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Automate de cycle automatique de dragage (X0 à X13 + AX_STAB)
   🔒 Sécurité : Gating par mode et homme-mort, repli AX_STAB sur défaut
   🔌 Interface : Demandes de mouvements (treuils, translation, benne)
   📄 Doc métier : DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.3.md
   ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_CycleSemiAuto
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
    SelTarget               : INT;          // --> [CFG] RESERVE (C3.1 : le cycle part toujours de P1, plus de selection de cible). Cable, non consomme.
    SetDepthM               : REAL;         // --> [CFG] Profondeur de consigne (negative)
    SetOffsetM              : REAL;         // --> [CFG] Ecart de fermeture benne cible

    // === FEEDBACKS CAPTEURS & MATERIEL ===
    KoboldContactFond       : BOOL;         // --> [HW] Retour dedie Kobold : TRUE = contact fond (front descendant DI)
    KoboldImmersed          : BOOL;         // --> [HW] Etat brut DI Kobold : TRUE = sonde dans l'eau (fronts AX6/AX7)
    KoboldContactorFeedback : BOOL;         // --> [HW] Retour contacteur Kobold enclenche (verif init AX5)
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
    InitPositionOk          : BOOL;         // --> [HW] Posture de depart OK (treuils/M3 dans la plage, calcul PRG_03) - condition AX1_INIT
    WinchesAtTopWindow      : BOOL;         // --> [HW] Treuils M1 ET M2 dans la fenetre FDC logiciel haut (calcul PRG_03) - surveille en AX2

    // === CONFIG & COMMANDES CYCLE (IHM) ===
    CfgDrainTime           : TIME;         // --> [CFG] Duree d'egouttage AX13 configurable IHM (<= 0 -> defaut interne)
    SkipDrainRequest       : BOOL;         // --> [CMD] Bouton IHM : passer l'etape d'egouttage AX13 (front)
    RepositionRequest      : BOOL;         // --> [CMD] Option IHM (maintenue) : repositionnement couple M1+M2 pendant le vidage tremie (AX15B <-> AX15C)

    // === CONFIG DIVING / EXTRACTION (GEL 2026-09-03) ===
    DiveStartMinM          : REAL;         // --> [CFG] Altimetrie de lancement Kobold (AT4 : AX4 -> AX5), reglable IHM (~3..5 m ; <= 0 -> defaut interne)
    CfgRaiseOffBottomM     : REAL;         // --> [CFG] Decollement du fond en AX8 : RaiseTargetM = TouchPositionM + ce champ (reglable IHM ; <= 0 -> 0,5 m)
    CfgCtrlAscentMaxStep   : INT;          // --> [CFG] Palier max montee controle AX11, borne [1..2] (defaut 1)
    M1_SpeedStepApplied    : INT;          // --> [HW] Palier vitesse effectivement applique M1 (0 = inconnu ; garde palier <> 4 en diving)
    M2_SpeedStepApplied    : INT;          // --> [HW] Palier vitesse effectivement applique M2 (0 = inconnu)
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
    // Types de contrat inter-PRG uniques (ST_Program*Request) : FB_CycleSemiAuto produit
    // directement les demandes consommées par PRG_04/05/07 — plus de DUT
    // ST_fbCycle_*CmdDemand redondants ni de re-mapping champ-à-champ (NC-090).
    WinchM1Cmd              : ST_ProgramWinchRequest;        // <-- [ACT] Demande treuil M1
    WinchM2Cmd              : ST_ProgramWinchRequest;        // <-- [ACT] Demande treuil M2
    TranslationCmd          : ST_ProgramTranslationRequest;  // <-- [ACT] Demande translation M3
    BucketCmd               : ST_ProgramBucketRequest;       // <-- [ACT] Demande benne

    // === METADONNEES & SYNOPTIQUE ===
    CycleStep               : E_AutoCycleStep;          // <-- [STAT] Etape active du Grafcet
    CycleStateStr           : STRING(80);           // <-- [STAT] Libelle en clair de l'etape
    CycleStepAtError        : E_AutoCycleStep;          // <-- [DIAG] Etape specifique au moment du defaut
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
    State                   : E_AutoCycleStep := E_AutoCycleStep.AX0_REPOS; // . [LOC] Etape courante machine d'etat
    SavedState              : E_AutoCycleStep := E_AutoCycleStep.AX0_REPOS; // . [LOC] Etape memorisee
    PausedState             : E_AutoCycleStep := E_AutoCycleStep.AX0_REPOS; // . [LOC] Etape en pause lors de la bascule hors auto
    WaitingResume           : BOOL := FALSE;                             // . [LOC] En attente de validation consciente pour reprendre

    // === MEMORISATIONS & REGISTRES INTERNES ===
    TouchPositionM          : REAL;         // . [LOC] Position M1 memorisee lors du contact fond
    RaiseTargetM            : REAL;         // . [LOC] Profondeur de remontee memorisee
    SelectedWorkTarget      : INT;          // . [LOC] Cible de travail (fige a 3=P1 depuis C3.1) - conserve pour diag/futur
    InitConditionsOk        : BOOL;         // . [LOC] AX1_INIT : toutes les conditions initiales sont remplies
    StepMaxPrevState        : E_AutoCycleStep;  // . [LOC] Etape du scan precedent (rearmement StepMaxTimer au changement d'etape)

    // === FRONTS / TEMPO DIVING ===
    KoboldRiseEdge          : R_TRIG;       // . [LOC] Front DI Kobold 0->1 (entree dans l'eau, AX6)
    KoboldFallEdge          : F_TRIG;       // . [LOC] Front DI Kobold 1->0 (fond, AX7)
    KoboldInitTimer         : TON;          // . [LOC] Fenetre de verif retour contacteur Kobold en AX5
    DivingRetryTrig         : BOOL;         // . [LOC] Synthese GT-dive-retry (erreur Kobold / joystick relache / palier <> 4 en AX5..AX7)
    CtrlAscentMaxStepEff    : INT;          // . [LOC] CfgCtrlAscentMaxStep borne [1..2]
    RaiseOffBottomEff       : REAL;         // . [LOC] CfgRaiseOffBottomM borne (>0, defaut 0,5 m)
    DiveStartMinEff         : REAL;         // . [LOC] DiveStartMinM borne (defaut interne si <= 0)

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
    CST_StepSlow   : INT := 1;   // Palier lent : retente AX9, controle AX11, repositionnement AX15C
    CST_StepDive   : INT := 4;   // Palier plongee Kobold AX4..AX7 : palier 4 MINI ET MAXI impose, palier 5 interdit (GEL Q9)
    CST_StepLoaded : INT := 4;   // Palier montee en charge AX12 (bridage strict <= 4, jamais palier 5)
    CST_KoboldInitTimeout : TIME := T#3s;   // Fenetre max de confirmation retour contacteur Kobold en AX5
    CST_RaiseOffBottomDefaultM : REAL := 0.5;   // Decollement du fond par defaut (AX8) si CfgRaiseOffBottomM <= 0
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
KoboldRiseEdge(CLK := KoboldImmersed);
KoboldFallEdge(CLK := KoboldImmersed);

// Config diving/extraction bornee (repli defaut interne si non reglee cote IHM).
DiveStartMinEff := SEL(DiveStartMinM > 0.0, 4.0, DiveStartMinM);
RaiseOffBottomEff := SEL(CfgRaiseOffBottomM > 0.0, CST_RaiseOffBottomDefaultM, CfgRaiseOffBottomM);
CtrlAscentMaxStepEff := LIMIT(1, CfgCtrlAscentMaxStep, 2);

// ⏱️ Chronomètre du cycle : compte tant que le séquenceur est actif (Lifecycle.Busy).
// .ET = durée écoulée du cycle en cours ; figée dans LastCycleDuration à l'achèvement (X13).
CycleRunTimer(IN := Lifecycle.Busy, PT := T#12h);
CurrentCycleElapsed := CycleRunTimer.ET;

// Durée d'égouttage effective : config IHM si valide, sinon défaut interne.
DrainTimeEff := SEL(CfgDrainTime <= T#0s, CfgDrainTime, DrainingTime);

// ⏱️ Surveillance indépendante de la remontée lente de controle
// AX11_CTRL_ASCENT -> AX12_LOADED_ASCENT : TON de stabilisation palier lent.
StabilizationTimer(IN := (State = E_AutoCycleStep.AX11_CTRL_ASCENT), PT := CtrlAscentTimeout);

// ⏱️ AX5_KOBOLD_INIT : fenetre de confirmation du retour contacteur Kobold.
KoboldInitTimer(IN := (State = E_AutoCycleStep.AX5_KOBOLD_INIT), PT := CST_KoboldInitTimeout);

// 📏 Comparaison vitesse réelle M1/M2
SpeedMismatchMps := ABS(M1_MeasuredSpeedMps - M2_MeasuredSpeedMps);
SpeedMismatchActive := (State = E_AutoCycleStep.AX11_CTRL_ASCENT)
                       AND JoystickDeflected
                       AND (SpeedMismatchThresholdMps > 0.0)
                       AND (SpeedMismatchTimeout > T#0ms)
                       AND (SpeedMismatchMps > SpeedMismatchThresholdMps);
// AX11_CTRL_ASCENT -> AX_STAB : TON confirmation écart vitesse.
SpeedMismatchTimer(IN := SpeedMismatchActive, PT := SpeedMismatchTimeout);
SpeedMismatchConfirmed := SpeedMismatchTimer.Q;

// Tempo max d'étape (R5) — backstop durée d'état, lancé SEULEMENT si pilotage joystick actif.
// Xi -> AX_STAB sur dépassement. Réarmé à CHAQUE changement d'étape (IN=FALSE 1 scan) :
// chaque étape dispose de sa propre fenêtre StepMaxTimeout, la tempo n'est PAS cumulative
// sur l'ensemble du cycle (un cycle réel long ne tombe plus en AX_STAB intempestif).
StepMaxTimer(IN := (State = StepMaxPrevState)
                  AND JoystickDeflected
                  AND (State <> E_AutoCycleStep.AX0_REPOS)
                  AND (State <> E_AutoCycleStep.AX18_DONE_SYNC)
                  AND (State <> E_AutoCycleStep.AX_STAB)
                  AND (State <> E_AutoCycleStep.AX_DIVING_RETRY),
             PT := StepMaxTimeout);
StepMaxPrevState := State;

// Egouttage AX13 : TON gaté sur l'étape (remis à 0 hors AX13). Remplace l'ancien IN:=TRUE câblé
// qui pouvait laisser Q déjà vrai à l'entrée en AX13 (temps d'égouttage non respecté).
DrainingTimer(IN := (State = E_AutoCycleStep.AX13_DRAIN_PAUSE), PT := DrainTimeEff);

// GT-dive-retry (GEL Q11) : en AX5/AX6/AX7, erreur sequence Kobold (retour contacteur
// absent apres CST_KoboldInitTimeout) OU joystick relache OU palier applique <> 4 sur
// M1 ou M2 (feedback si cable) -> reprise AX_DIVING_RETRY (PAS un defaut latche).
DivingRetryTrig := ((State = E_AutoCycleStep.AX5_KOBOLD_INIT)
                     OR (State = E_AutoCycleStep.AX6_SEARCH_IMMERSION)
                     OR (State = E_AutoCycleStep.AX7_SEARCH_BOTTOM))
                   AND ( (KoboldInitTimer.Q AND NOT KoboldContactorFeedback)
                         OR NOT JoystickDeflected
                         OR ((M1_SpeedStepApplied > 0) AND (M1_SpeedStepApplied <> CST_StepDive))
                         OR ((M2_SpeedStepApplied > 0) AND (M2_SpeedStepApplied <> CST_StepDive)) );

// Table des causes de défaut
instCauses[0].Active   := LimitLegalReached
                          AND ((State = E_AutoCycleStep.AX4_DESCEND_DIVING)
                            OR (State = E_AutoCycleStep.AX5_KOBOLD_INIT)
                            OR (State = E_AutoCycleStep.AX6_SEARCH_IMMERSION)
                            OR (State = E_AutoCycleStep.AX7_SEARCH_BOTTOM));
instCauses[0].Latching := TRUE;
instCauses[0].Texte    := 'Limite legale de profondeur atteinte pendant descente';

instCauses[1].Active   := WinchSyncError AND (State <> E_AutoCycleStep.AX0_REPOS) AND (State <> E_AutoCycleStep.AX_STAB);
instCauses[1].Latching := TRUE;
instCauses[1].Texte    := 'Desynchronisme treuils M1/M2 bloquant';

instCauses[2].Active   := SpeedMismatchConfirmed AND (State <> E_AutoCycleStep.AX0_REPOS) AND (State <> E_AutoCycleStep.AX_STAB);
instCauses[2].Latching := TRUE;
instCauses[2].Texte    := 'Ecart de vitesse M1/M2 confirme en montee';

instCauses[3].Active   := NOT HeartbeatIhmOk AND (State <> E_AutoCycleStep.AX0_REPOS) AND (State <> E_AutoCycleStep.AX_STAB);
instCauses[3].Latching := TRUE;
instCauses[3].Texte    := 'Perte communication IHM pendant cycle';

instCauses[4].Active   := StepMaxTimer.Q AND (State <> E_AutoCycleStep.AX_STAB);
instCauses[4].Latching := TRUE;
instCauses[4].Texte    := 'Depassement tempo maximale d etape (blocage mouvement)';

instCauses[5].Active   := (StabilizationTimer.Q OR (ABS(M1_CablePosM - M2_CablePosM) > CtrlAscentToleranceM))
                          AND (State = E_AutoCycleStep.AX11_CTRL_ASCENT);
instCauses[5].Latching := TRUE;
instCauses[5].Texte    := 'Defaut de stabilisation / tolerance ecart codeurs en remontee controle';

// Backstop anti-telescopage : ecart de position M1/M2 excessif pendant une phase
// reellement couplee. AX11 a deja son propre controle (instCauses[5]). Seuil grossier
// (0,50 m) : filet local si FB_SyncDeviation (PRG_04) ne coupe pas.
instCauses[6].Active   := (ABS(M1_CablePosM - M2_CablePosM) > CST_CoupledPosBacklashM)
                          AND JoystickDeflected
                          AND ((State = E_AutoCycleStep.AX4_DESCEND_DIVING)
                            OR (State = E_AutoCycleStep.AX5_KOBOLD_INIT)
                            OR (State = E_AutoCycleStep.AX6_SEARCH_IMMERSION)
                            OR (State = E_AutoCycleStep.AX7_SEARCH_BOTTOM)
                            OR (State = E_AutoCycleStep.AX9_RAISE_OFF_BOTTOM)
                            OR (State = E_AutoCycleStep.AX12_LOADED_ASCENT)
                            OR (State = E_AutoCycleStep.AX15C_DUMP_REPOSITION));
instCauses[6].Latching := TRUE;
instCauses[6].Texte    := 'Ecart de position M1/M2 excessif en phase couplee (anti-telescopage)';

// AX2 : pendant la translation vers P1 les treuils M1/M2 doivent RESTER au FDC
// logiciel haut (WinchesAtTopWindow, calcul PRG_03). S'ils quittent la fenetre
// -> defaut latche, sortie cycle (GEL SEMI_AUTO cause 7 / Q10).
instCauses[7].Active   := NOT WinchesAtTopWindow AND (State = E_AutoCycleStep.AX2_TRANSLATE_P1);
instCauses[7].Latching := TRUE;
instCauses[7].Texte    := 'Treuils M1/M2 hors FDC haut pendant la translation vers P1';

// GEL cause 8 : palier vitesse > 4 (palier 5) applique pendant la plongee. Le FB commande
// toujours CST_StepDive = 4 ; un palier 5 en retour feedback = anomalie aval -> defaut latche.
// (Un palier < 4 en retour est traite en reprise par GT-dive-retry, pas ici.)
instCauses[8].Active   := (((M1_SpeedStepApplied > CST_StepDive) OR (M2_SpeedStepApplied > CST_StepDive)))
                          AND ((State = E_AutoCycleStep.AX4_DESCEND_DIVING)
                            OR (State = E_AutoCycleStep.AX5_KOBOLD_INIT)
                            OR (State = E_AutoCycleStep.AX6_SEARCH_IMMERSION)
                            OR (State = E_AutoCycleStep.AX7_SEARCH_BOTTOM));
instCauses[8].Latching := TRUE;
instCauses[8].Texte    := 'Palier vitesse > 4 (palier 5) pendant la plongee - interdit';

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
    IF (State <> E_AutoCycleStep.AX0_REPOS) AND (State <> E_AutoCycleStep.AX18_DONE_SYNC) AND (State <> E_AutoCycleStep.AX_STAB) THEN
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

// 🧊 R9 — capture l'étape spécifique AVANT la bascule vers AX_STAB
IF ErrorEdge.Q THEN
    CycleStepAtError := State;
    State := E_AutoCycleStep.AX_STAB;
    WaitingResume := FALSE;   // un défaut abroge la reprise consciente : repli AX_STAB
END_IF;

// GT-dive-retry (GEL Q11) : reprise de plongee (PAS un defaut latche). Prioritaire
// apres le repli defaut : une vraie erreur (ErrorEdge) l'emporte.
IF DivingRetryTrig AND (State <> E_AutoCycleStep.AX_STAB) THEN
    State := E_AutoCycleStep.AX_DIVING_RETRY;
END_IF;

IF ResetEdge.Q THEN
    SavedState := E_AutoCycleStep.AX0_REPOS;
    IF State = E_AutoCycleStep.AX_STAB THEN
        State := E_AutoCycleStep.AX0_REPOS;
    END_IF;
END_IF;

// Gestion de l'Abandon explicite
IF AbortEdge.Q THEN
    State := E_AutoCycleStep.AX0_REPOS;
    WaitingResume := FALSE;
    PausedState := E_AutoCycleStep.AX0_REPOS;
END_IF;

// SEMI_AUTO : FB_CycleSemiAuto est le SEUL producteur des demandes benne. Les champs
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

    E_AutoCycleStep.AX0_REPOS:
        CycleStep := E_AutoCycleStep.AX0_REPOS;
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
            State := E_AutoCycleStep.AX1_INIT;
        END_IF;

    E_AutoCycleStep.AX1_INIT:
        CycleStep := E_AutoCycleStep.AX1_INIT;
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedDirection := 0;

        // AX1_INIT : verification des CONDITIONS INITIALES du cycle. AUCUN ordre de
        // mouvement, aucun referencement (datum M1/M2/benne = responsabilite exclusive
        // FB_MachineHomingCycle). Conditions : codeurs M1/M2 references, aucun defaut
        // latche, treuils au FDC logiciel haut (TopPositionSensor), et posture de depart
        // OK (InitPositionOk : chariot M3 PAS a droite de P1 + treuils dans la plage
        // +/- 0,4 m autour du FDC haut, calcul PRG_03 ; positionnement fin P1 = AX2).
        InitConditionsOk := HomedM1 AND HomedM2 AND NOT Fault.Latched
                            AND TopPositionSensor AND InitPositionOk;
        IF InitConditionsOk THEN
            CycleStateStr := 'AX1 - Conditions initiales OK';
            ExpectedAxis := E_OperatorAxis.NONE;
            WaitingForOperator := FALSE;
            WaitingForProcess := TRUE;
            OperatorActionId := 0;
            OperatorAction := '';
            State := E_AutoCycleStep.AX2_TRANSLATE_P1;   // franchie sans mouvement
        ELSIF NOT (HomedM1 AND HomedM2) THEN
            CycleStateStr := 'AX1 - Machine non referencee';
            ExpectedAxis := E_OperatorAxis.BUTTON;
            WaitingForOperator := TRUE;
            WaitingForProcess := FALSE;
            OperatorActionId := 16#0401;
            OperatorAction := 'Machine non referencee : passer en maintenance pour le referencement.';
        ELSE
            CycleStateStr := 'AX1 - Conditions initiales non remplies';
            ExpectedAxis := E_OperatorAxis.BUTTON;
            WaitingForOperator := TRUE;
            WaitingForProcess := FALSE;
            OperatorActionId := 16#0401;
            OperatorAction := 'Amener les treuils au FDC haut.';
        END_IF;

    E_AutoCycleStep.AX2_TRANSLATE_P1:
        CycleStep := E_AutoCycleStep.AX2_TRANSLATE_P1;
        CycleStateStr := 'X2 - Mise en position P1 (translation)';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_X;
        // GEL SEMI_AUTO Q10 : le cycle n'emet AUCUNE commande M3 automatique (pas de
        // selection de cible). L'operateur pousse le joystick VERS LA DROITE et amene M3
        // a P1 ; ralenti PV + arret sur FDC P1 assures par PRG_05/FB_Translation (comme en
        // maintenance). Le cycle SURVEILLE en permanence que les treuils M1/M2 RESTENT au
        // FDC logiciel haut (WinchesAtTopWindow) : sortie sur defaut latche (cause 7) sinon.
        // Le controle "chariot pas a droite de P1" est fait en AX1_INIT, pas ici.
        WinchM1Cmd.RunRequest := FALSE; WinchM1Cmd.ReqAscent := FALSE; WinchM1Cmd.ReqDescend := FALSE; WinchM1Cmd.StepTgt := 0;
        WinchM2Cmd.RunRequest := FALSE; WinchM2Cmd.ReqAscent := FALSE; WinchM2Cmd.ReqDescend := FALSE; WinchM2Cmd.StepTgt := 0;
        TranslationCmd.PositionTgt := 3;          // repere P1 pour PRG_05 (info ; pas de pilotage cycle)

        IF Translation_At_P1 THEN
            ExpectedDirection := 0;
            WaitingForOperator := FALSE;
            WaitingForProcess := TRUE;
            OperatorActionId := 16#0402;
            OperatorAction := 'Position P1 atteinte.';
            TranslationCmd.ReqStart := FALSE;
            State := E_AutoCycleStep.AX3_OPEN_BUCKET;
        ELSE
            // Entre tremie et P1 : l'operateur pousse le joystick VERS LA DROITE (axe
            // Tremie--P2--P1--Maintenance : P1 est a droite de la tremie). Maintien requis ;
            // ralenti PV + arret FDC P1 assures par PRG_05. Transition sur P1 STABILISE.
            ExpectedDirection := 1;
            WaitingForOperator := NOT JoystickDeflected;
            WaitingForProcess := JoystickDeflected;
            OperatorActionId := 16#0402;
            OperatorAction := 'Pousser le joystick vers la droite : arret automatique sur P1.';
            TranslationCmd.ReqStart := CycleMotionPermit;
        END_IF;

    E_AutoCycleStep.AX3_OPEN_BUCKET:
        CycleStep := E_AutoCycleStep.AX3_OPEN_BUCKET;
        CycleStateStr := 'X3 - Ouverture benne';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_Y;
        ExpectedDirection := 0;
        WaitingForOperator := NOT JoystickDeflected;
        WaitingForProcess := JoystickDeflected;
        OperatorActionId := 16#0403;
        OperatorAction := 'Joystick pousse : ouverture benne jusqu au FDC logiciel benne ouverte.';

        // X3 = etape benne seule : treuils explicitement neutralises (config treuil unique par etape).
        WinchM1Cmd.RunRequest := FALSE; WinchM1Cmd.ReqAscent := FALSE; WinchM1Cmd.ReqDescend := FALSE; WinchM1Cmd.StepTgt := 0;
        WinchM2Cmd.RunRequest := FALSE; WinchM2Cmd.ReqAscent := FALSE; WinchM2Cmd.ReqDescend := FALSE; WinchM2Cmd.StepTgt := 0;

        IF Benne_IsOpen THEN
            State := E_AutoCycleStep.AX4_DESCEND_DIVING;
        ELSE
            BucketCmd.ReqOpen := CycleMotionPermit;
            IF JoystickDeflected AND Benne_Done AND Benne_IsOpen THEN
                BucketCmd.ReqOpen := FALSE;
                State := E_AutoCycleStep.AX4_DESCEND_DIVING;
            END_IF;
        END_IF;

    (* ===================== DIVING (AX4..AX8 + AX_DIVING_RETRY) ===================== *)

    E_AutoCycleStep.AX4_DESCEND_DIVING:
        CycleStep := E_AutoCycleStep.AX4_DESCEND_DIVING;
        CycleStateStr := 'AX4 - Plongee couplee palier 4 jusqu a l altimetrie de lancement';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_Y;
        ExpectedDirection := -1;
        WaitingForOperator := NOT JoystickDeflected;
        WaitingForProcess := JoystickDeflected;
        OperatorActionId := 16#0404;
        OperatorAction := 'Maintenir la descente palier 4 (Kobold pas encore enclenche).';

        // Palier 4 MINI ET MAXI (CST_StepDive), palier 5 interdit (cause 8). Tempo
        // sequencement contacteurs conservee en aval (PRG_04 : montee progressive 1->4).
        // Contacteur Kobold PAS enclenche a cette etape.
        WinchM1Cmd.RunRequest := CycleMotionPermit;
        WinchM1Cmd.ReqAscent := FALSE; WinchM1Cmd.ReqDescend := TRUE;
        WinchM1Cmd.StepTgt  := CST_StepDive;
        WinchM2Cmd.RunRequest := CycleMotionPermit;
        WinchM2Cmd.ReqAscent := FALSE; WinchM2Cmd.ReqDescend := TRUE;
        WinchM2Cmd.StepTgt  := CST_StepDive;
        BucketCmd.ReqKoboldMeasureEnable := FALSE;

        // AT4 : altimetrie de lancement atteinte (M1 ET M2 <= DiveStartMinEff).
        IF JoystickDeflected
           AND (M1_CablePosM <= DiveStartMinEff) AND (M2_CablePosM <= DiveStartMinEff) THEN
            State := E_AutoCycleStep.AX5_KOBOLD_INIT;
        END_IF;

    E_AutoCycleStep.AX5_KOBOLD_INIT:
        CycleStep := E_AutoCycleStep.AX5_KOBOLD_INIT;
        CycleStateStr := 'AX5 - Activation contacteur Kobold au vol';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_Y;
        ExpectedDirection := -1;
        WaitingForOperator := NOT JoystickDeflected;
        WaitingForProcess := JoystickDeflected;
        OperatorActionId := 16#0405;
        OperatorAction := 'Maintenir la descente palier 4 : initialisation Kobold en cours.';

        // Descente palier 4 maintenue ; enclenche le contacteur Kobold et attend le retour.
        WinchM1Cmd.RunRequest := CycleMotionPermit;
        WinchM1Cmd.ReqAscent := FALSE; WinchM1Cmd.ReqDescend := TRUE;
        WinchM1Cmd.StepTgt  := CST_StepDive;
        WinchM2Cmd.RunRequest := CycleMotionPermit;
        WinchM2Cmd.ReqAscent := FALSE; WinchM2Cmd.ReqDescend := TRUE;
        WinchM2Cmd.StepTgt  := CST_StepDive;
        BucketCmd.ReqKoboldMeasureEnable := CycleMotionPermit;

        // AT5 : retour contacteur Kobold coherent -> recherche immersion.
        // (echec init / joystick relache / palier <> 4 -> AX_DIVING_RETRY via GT-dive-retry §1)
        IF JoystickDeflected AND KoboldContactorFeedback THEN
            State := E_AutoCycleStep.AX6_SEARCH_IMMERSION;
        END_IF;

    E_AutoCycleStep.AX6_SEARCH_IMMERSION:
        CycleStep := E_AutoCycleStep.AX6_SEARCH_IMMERSION;
        CycleStateStr := 'AX6 - Recherche entree dans l eau (front DI Kobold 0->1)';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_Y;
        ExpectedDirection := -1;
        WaitingForOperator := NOT JoystickDeflected;
        WaitingForProcess := JoystickDeflected;
        OperatorActionId := 16#0406;
        OperatorAction := 'Maintenir la descente palier 4 : entree dans l eau attendue.';

        WinchM1Cmd.RunRequest := CycleMotionPermit;
        WinchM1Cmd.ReqAscent := FALSE; WinchM1Cmd.ReqDescend := TRUE;
        WinchM1Cmd.StepTgt  := CST_StepDive;
        WinchM2Cmd.RunRequest := CycleMotionPermit;
        WinchM2Cmd.ReqAscent := FALSE; WinchM2Cmd.ReqDescend := TRUE;
        WinchM2Cmd.StepTgt  := CST_StepDive;
        BucketCmd.ReqKoboldMeasureEnable := CycleMotionPermit;

        // AT6 : front montant DI Kobold (immersion confirmee) -> recherche du fond.
        IF JoystickDeflected AND KoboldRiseEdge.Q THEN
            State := E_AutoCycleStep.AX7_SEARCH_BOTTOM;
        END_IF;

    E_AutoCycleStep.AX7_SEARCH_BOTTOM:
        CycleStep := E_AutoCycleStep.AX7_SEARCH_BOTTOM;
        CycleStateStr := 'AX7 - Recherche du fond (front DI Kobold 1->0)';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_Y;
        ExpectedDirection := -1;
        WaitingForOperator := NOT JoystickDeflected;
        WaitingForProcess := JoystickDeflected;
        OperatorActionId := 16#0407;
        OperatorAction := 'Maintenir la descente palier 4 sous l eau : detection du fond.';

        WinchM1Cmd.RunRequest := CycleMotionPermit;
        WinchM1Cmd.ReqAscent := FALSE; WinchM1Cmd.ReqDescend := TRUE;
        WinchM1Cmd.StepTgt  := CST_StepDive;
        WinchM2Cmd.RunRequest := CycleMotionPermit;
        WinchM2Cmd.ReqAscent := FALSE; WinchM2Cmd.ReqDescend := TRUE;
        WinchM2Cmd.StepTgt  := CST_StepDive;
        BucketCmd.ReqKoboldMeasureEnable := CycleMotionPermit;

        // AT7 : front descendant DI Kobold (ou retour dedie KoboldContactFond) = fond.
        IF JoystickDeflected AND (KoboldFallEdge.Q OR KoboldContactFond) THEN
            State := E_AutoCycleStep.AX8_BOTTOM_CONFIRMED;
        END_IF;

    E_AutoCycleStep.AX8_BOTTOM_CONFIRMED:
        CycleStep := E_AutoCycleStep.AX8_BOTTOM_CONFIRMED;
        CycleStateStr := 'AX8 - Fond confirme : coupure treuils, memorisation';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.NONE;
        ExpectedDirection := 0;
        WaitingForOperator := FALSE;
        WaitingForProcess := TRUE;
        OperatorActionId := 16#0408;
        OperatorAction := 'Fond touche.';

        // Coupure INSTANTANEE de toutes les commandes treuils (meme scan) + Kobold coupe.
        WinchM1Cmd.RunRequest := FALSE; WinchM1Cmd.ReqAscent := FALSE; WinchM1Cmd.ReqDescend := FALSE; WinchM1Cmd.StepTgt := 0;
        WinchM2Cmd.RunRequest := FALSE; WinchM2Cmd.ReqAscent := FALSE; WinchM2Cmd.ReqDescend := FALSE; WinchM2Cmd.StepTgt := 0;
        BucketCmd.ReqKoboldMeasureEnable := FALSE;

        TouchPositionM := M1_CablePosM;
        IF LimitLegalDepthM < -0.01 THEN
            RaiseTargetM := MAX(TouchPositionM + RaiseOffBottomEff, LimitLegalDepthM + RaiseOffBottomEff);
        ELSE
            RaiseTargetM := TouchPositionM + RaiseOffBottomEff;
        END_IF;
        State := E_AutoCycleStep.AX9_RAISE_OFF_BOTTOM;

    E_AutoCycleStep.AX_DIVING_RETRY:
        CycleStep := E_AutoCycleStep.AX_DIVING_RETRY;
        CycleStateStr := 'AX_DIVING_RETRY - Reprise plongee : remonter au FDC haut';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_Y;
        ExpectedDirection := 1;
        WaitingForOperator := NOT JoystickDeflected;
        WaitingForProcess := JoystickDeflected;
        OperatorActionId := 16#0481;
        OperatorAction := 'Reprise plongee : maintenir la montee jusqu au FDC haut, puis nouvelle tentative.';

        // Remontee assistee palier lent, Kobold coupe.
        WinchM1Cmd.RunRequest := CycleMotionPermit;
        WinchM1Cmd.ReqAscent := TRUE; WinchM1Cmd.ReqDescend := FALSE;
        WinchM1Cmd.StepTgt  := CST_StepSlow;
        WinchM2Cmd.RunRequest := CycleMotionPermit;
        WinchM2Cmd.ReqAscent := TRUE; WinchM2Cmd.ReqDescend := FALSE;
        WinchM2Cmd.StepTgt  := CST_StepSlow;
        BucketCmd.ReqKoboldMeasureEnable := FALSE;

        // AT-retry : treuils revenus au FDC haut -> nouvelle tentative de plongee.
        IF JoystickDeflected AND (WinchesAtTopWindow OR TopPositionSensor) THEN
            WinchM1Cmd.RunRequest := FALSE;
            WinchM2Cmd.RunRequest := FALSE;
            State := E_AutoCycleStep.AX4_DESCEND_DIVING;
        END_IF;

    (* ===================== EXTRACTION (AX9..AX12) ===================== *)

    E_AutoCycleStep.AX9_RAISE_OFF_BOTTOM:
        CycleStep := E_AutoCycleStep.AX9_RAISE_OFF_BOTTOM;
        CycleStateStr := 'AX9 - Retente les cables (palier 1), decollement du fond';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_Y;
        ExpectedDirection := 1;
        WaitingForOperator := NOT JoystickDeflected;
        WaitingForProcess := JoystickDeflected;
        OperatorActionId := 16#0409;
        OperatorAction := 'Maintenir la montee palier 1 : retente des cables, decollement du fond.';

        // Palier 1 (doux). Selecteur couplage BOTH/M1/M2 = garde cote PRG_04 (GEL Q15),
        // le sequenceur commande toujours les deux treuils symetriquement.
        WinchM1Cmd.RunRequest := CycleMotionPermit;
        WinchM1Cmd.ReqAscent := TRUE; WinchM1Cmd.ReqDescend := FALSE;
        WinchM1Cmd.StepTgt := CST_StepSlow;
        WinchM2Cmd.RunRequest := CycleMotionPermit;
        WinchM2Cmd.ReqAscent := TRUE; WinchM2Cmd.ReqDescend := FALSE;
        WinchM2Cmd.StepTgt := CST_StepSlow;

        IF JoystickDeflected AND (M1_CablePosM >= RaiseTargetM) AND (M2_CablePosM >= RaiseTargetM) THEN
            WinchM1Cmd.RunRequest := FALSE;
            WinchM2Cmd.RunRequest := FALSE;
            State := E_AutoCycleStep.AX10_CLOSE_BUCKET;
        END_IF;

    E_AutoCycleStep.AX10_CLOSE_BUCKET:
        CycleStep := E_AutoCycleStep.AX10_CLOSE_BUCKET;
        CycleStateStr := 'AX10 - Fermeture benne (tolerance a peu pres ferme)';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_Y;
        ExpectedDirection := 1;
        WaitingForOperator := NOT JoystickDeflected;
        WaitingForProcess := JoystickDeflected;
        OperatorActionId := 16#040A;
        OperatorAction := 'Maintenir la commande : fermeture de la benne.';

        // Etape benne seule : les DEUX treuils explicitement neutralises.
        WinchM1Cmd.RunRequest := FALSE; WinchM1Cmd.ReqAscent := FALSE; WinchM1Cmd.ReqDescend := FALSE; WinchM1Cmd.StepTgt := 0;
        WinchM2Cmd.RunRequest := FALSE; WinchM2Cmd.ReqAscent := FALSE; WinchM2Cmd.ReqDescend := FALSE; WinchM2Cmd.StepTgt := 0;
        BucketCmd.ReqClose := CycleMotionPermit;

        IF JoystickDeflected AND (Benne_Done AND (Benne_IsClosed OR Benne_IsRoughlyClosed)) THEN
            BucketCmd.ReqClose := FALSE;
            State := E_AutoCycleStep.AX11_CTRL_ASCENT;
        END_IF;

    E_AutoCycleStep.AX11_CTRL_ASCENT:
        CycleStep := E_AutoCycleStep.AX11_CTRL_ASCENT;
        CycleStateStr := 'AX11 - Remontee lente de controle';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_Y;
        ExpectedDirection := 1;
        WaitingForOperator := NOT JoystickDeflected;
        WaitingForProcess := JoystickDeflected;
        OperatorActionId := 16#040B;
        OperatorAction := 'Maintenir la montee de controle : palier et synchronisme.';

        // Palier max reglable IHM, borne [1..2] (defaut 1 / P1 ; P2 possible au besoin).
        WinchM1Cmd.RunRequest := CycleMotionPermit;
        WinchM1Cmd.ReqAscent := TRUE; WinchM1Cmd.ReqDescend := FALSE;
        WinchM1Cmd.StepTgt  := CtrlAscentMaxStepEff;
        WinchM2Cmd.RunRequest := CycleMotionPermit;
        WinchM2Cmd.ReqAscent := TRUE; WinchM2Cmd.ReqDescend := FALSE;
        WinchM2Cmd.StepTgt  := CtrlAscentMaxStepEff;

        IF JoystickDeflected
           AND (M1_CablePosM >= (TouchPositionM + CtrlAscentDistM))
           AND (M2_CablePosM >= (TouchPositionM + CtrlAscentDistM))
           AND (ABS(M1_CablePosM - M2_CablePosM) <= CtrlAscentToleranceM) THEN
            State := E_AutoCycleStep.AX12_LOADED_ASCENT;
        END_IF;

    E_AutoCycleStep.AX12_LOADED_ASCENT:
        CycleStep := E_AutoCycleStep.AX12_LOADED_ASCENT;
        CycleStateStr := 'AX12 - Remontee en charge';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_Y;
        ExpectedDirection := 1;
        WaitingForOperator := NOT JoystickDeflected;
        WaitingForProcess := JoystickDeflected;
        OperatorActionId := 16#040C;
        OperatorAction := 'Maintenir la montee en charge jusqu a la limite haute (pas de ralenti avant le top).';

        // Benne bien fermee -> palier 4 ; benne mal fermee (a peu pres) -> palier 1.
        // Pas de ralentissement 1 m avant la position top (montee franche).
        WinchM1Cmd.RunRequest := CycleMotionPermit;
        WinchM1Cmd.ReqAscent := TRUE; WinchM1Cmd.ReqDescend := FALSE;
        WinchM1Cmd.StepTgt  := SEL(Benne_IsClosed, CST_StepSlow, CST_StepLoaded);
        WinchM2Cmd.RunRequest := CycleMotionPermit;
        WinchM2Cmd.ReqAscent := TRUE; WinchM2Cmd.ReqDescend := FALSE;
        WinchM2Cmd.StepTgt  := SEL(Benne_IsClosed, CST_StepSlow, CST_StepLoaded);

        IF JoystickDeflected AND M1_CablePosM >= CableLimitM1AscentM THEN
            WinchM1Cmd.RunRequest := FALSE;
            WinchM2Cmd.RunRequest := FALSE;
            State := E_AutoCycleStep.AX13_DRAIN_PAUSE;
        END_IF;

    (* ===================== DECHARGE (AX13..AX18) ===================== *)

    E_AutoCycleStep.AX13_DRAIN_PAUSE:
        CycleStep := E_AutoCycleStep.AX13_DRAIN_PAUSE;
        CycleStateStr := 'AX13 - Egouttage du godet en cours';
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

        // Tempo d'egouttage armee/remise a zero en §1 (gate sur State = AX13, PT = DrainTimeEff).
        // Duree reglable IHM (CfgDrainTime) + bypass immediat (SkipDrainEdge).
        IF JoystickDeflected AND (DrainingTimer.Q OR SkipDrainEdge.Q) THEN
            State := E_AutoCycleStep.AX14_TRANSLATE_DUMP;
        END_IF;

    E_AutoCycleStep.AX14_TRANSLATE_DUMP:
        CycleStep := E_AutoCycleStep.AX14_TRANSLATE_DUMP;
        CycleStateStr := 'AX14 - Deplacement vers tremie (grille/crible libres)';
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
            State := E_AutoCycleStep.AX15A_DUMP_ARRIVE;
        END_IF;

    E_AutoCycleStep.AX15A_DUMP_ARRIVE:
        CycleStep := E_AutoCycleStep.AX15A_DUMP_ARRIVE;
        CycleStateStr := 'AX15a - Arrivee tremie : treuils arretes, attente ouverture';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_Y;
        ExpectedDirection := -1;
        WaitingForOperator := NOT JoystickDeflected;
        WaitingForProcess := JoystickDeflected;
        OperatorActionId := 16#040B;
        OperatorAction := 'A la tremie : deflechir vers le bas pour ouvrir la benne et vider.';

        // Config treuil UNIQUE : arret des deux treuils (aucune descente couplee ici).
        WinchM1Cmd.RunRequest := FALSE; WinchM1Cmd.ReqAscent := FALSE; WinchM1Cmd.ReqDescend := FALSE; WinchM1Cmd.StepTgt := 0;
        WinchM2Cmd.RunRequest := FALSE; WinchM2Cmd.ReqAscent := FALSE; WinchM2Cmd.ReqDescend := FALSE; WinchM2Cmd.StepTgt := 0;

        // Geste operateur (manche defleci) -> phase d'ouverture benne.
        IF JoystickDeflected THEN
            State := E_AutoCycleStep.AX15B_DUMP_OPEN;
        END_IF;

    E_AutoCycleStep.AX15B_DUMP_OPEN:
        CycleStep := E_AutoCycleStep.AX15B_DUMP_OPEN;
        CycleStateStr := 'AX15b - Vidage : ouverture benne pour vider le contenu, treuils arretes';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_Y;
        ExpectedDirection := -1;
        WaitingForOperator := NOT JoystickDeflected;
        WaitingForProcess := JoystickDeflected;
        OperatorActionId := 16#040B;
        OperatorAction := 'Maintenir : ouverture complete de la benne, vidage a la tremie.';

        // Config treuil UNIQUE : etape benne seule, les deux treuils neutralises
        // (plus de descente couplee M1+M2 simultanee a l'ouverture benne -> plus
        // d'ecart M1/M2 volontaire ni de faux SafeStop concordance contacteurs).
        WinchM1Cmd.RunRequest := FALSE; WinchM1Cmd.ReqAscent := FALSE; WinchM1Cmd.ReqDescend := FALSE; WinchM1Cmd.StepTgt := 0;
        WinchM2Cmd.RunRequest := FALSE; WinchM2Cmd.ReqAscent := FALSE; WinchM2Cmd.ReqDescend := FALSE; WinchM2Cmd.StepTgt := 0;

        BucketCmd.ReqOpen := CycleMotionPermit;

        // Option operateur (bit IHM) : descendre la benne dans la gueule de tremie
        // pour aider la vidange -> repositionnement couple M1+M2 (AX15C). Prioritaire
        // sur la fin de vidage.
        IF RepositionRequest THEN
            State := E_AutoCycleStep.AX15C_DUMP_REPOSITION;
        ELSIF JoystickDeflected AND Benne_Done AND Benne_IsOpen THEN
            BucketCmd.ReqOpen := FALSE;
            State := E_AutoCycleStep.AX18_DONE_SYNC;
        END_IF;

    E_AutoCycleStep.AX15C_DUMP_REPOSITION:
        CycleStep := E_AutoCycleStep.AX15C_DUMP_REPOSITION;
        CycleStateStr := 'AX15c - Repositionnement couple M1+M2 (aide vidange tremie)';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_Y;
        ExpectedDirection := -1;
        WaitingForOperator := NOT JoystickDeflected;
        WaitingForProcess := JoystickDeflected;
        OperatorActionId := 16#040C;
        OperatorAction := 'Descente couplee M1+M2 ; relacher l option pour reprendre le vidage.';

        // Descente couplee M1+M2, palier lent, sous homme-mort. Commandes SYMETRIQUES
        // (meme sens, meme palier) -> FB_SyncDeviation actif, pas d'ecart volontaire.
        WinchM1Cmd.ReqAscent := FALSE; WinchM1Cmd.ReqDescend := TRUE;
        WinchM1Cmd.RunRequest := CycleMotionPermit;
        WinchM1Cmd.StepTgt := CST_StepSlow;
        WinchM2Cmd.ReqAscent := FALSE; WinchM2Cmd.ReqDescend := TRUE;
        WinchM2Cmd.RunRequest := CycleMotionPermit;
        WinchM2Cmd.StepTgt := CST_StepSlow;

        // La benne reste ouverte pendant le repositionnement (on finit l'ouverture si besoin).
        BucketCmd.ReqOpen := CycleMotionPermit AND NOT Benne_IsOpen;

        // Retour a AX15B des que l'operateur relache l'option de repositionnement.
        IF NOT RepositionRequest THEN
            WinchM1Cmd.RunRequest := FALSE;
            WinchM2Cmd.RunRequest := FALSE;
            State := E_AutoCycleStep.AX15B_DUMP_OPEN;
        END_IF;

    E_AutoCycleStep.AX18_DONE_SYNC:
        CycleStep := E_AutoCycleStep.AX18_DONE_SYNC;
        CycleStateStr := 'AX18 - Passe terminee : aller en P1 pour recommencer';
        WinchM1Cmd.RunRequest := FALSE;
        WinchM2Cmd.RunRequest := FALSE;
        TranslationCmd.ReqStart := FALSE;
        Lifecycle.Done := TRUE;
        Lifecycle.Busy := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_X;
        ExpectedDirection := 1;
        WaitingForOperator := TRUE;
        WaitingForProcess := FALSE;
        OperatorActionId := 16#040D;
        OperatorAction := 'Cycle termine. Aller en P1 (joystick vers la droite) pour recommencer.';

        // Compteur de prélèvements (RETAIN) + durée du cycle — F2: cadré par front (1 seul par cycle)
        IF NOT SampleCountDone THEN
            SampleCount := SampleCount + 1;
            LastCycleDuration := CurrentCycleElapsed;   // fige la durée du cycle qui vient de s'achever
            SampleCountDone := TRUE;
        END_IF;

        // Rebouclage DIRECT sur AX2_TRANSLATE_P1 (GEL Q14) : la machine est deja
        // referencee, la passe suivante enchaine sur la translation P1 (pas de retour AX0).
        IF StartEdge.Q OR JoystickDeflected THEN
            SampleCountDone := FALSE;
            Lifecycle.Done := FALSE;
            State := E_AutoCycleStep.AX2_TRANSLATE_P1;
        END_IF;

    E_AutoCycleStep.AX_STAB:
        CycleStep := E_AutoCycleStep.AX_STAB;
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
