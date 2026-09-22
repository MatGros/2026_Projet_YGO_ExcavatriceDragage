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
    JoystickPush            : BOOL;         // --> [CMD] Intention Y descente qualifiee (axe Y pousse uniquement)
    JoystickPull            : BOOL;         // --> [CMD] Intention Y montee qualifiee (axe Y tire uniquement)
    JoystickRight           : BOOL;         // --> [CMD] Intention X vers P1 qualifiee
    JoystickLeft            : BOOL;         // --> [CMD] Intention X vers tremie qualifiee
    DeadmanArmed            : BOOL;         // --> [CMD] Appui homme-mort (fenetre 3 s)
    HeartbeatIhmOk          : BOOL;         // --> [SAFE] IHM<->PLC valide

    // === COMMANDES OPERATEUR ===
    StartCycle              : BOOL;         // --> [CMD] Demande lancement / reprise (IHM)
    AbortCycle              : BOOL;         // --> [CMD] Demande abandon (IHM)
    ResumeAfterFault        : BOOL;         // --> [CMD] Reprise consciente depuis AX_STAB vers l'etape d'origine

    // === CIBLES ET CONFIGURATION ===
    SelTarget               : INT;          // --> [CFG] RESERVE (C3.1 : le cycle part toujours de P1, plus de selection de cible). Cable, non consomme.
    SetDepthM               : REAL;         // --> [CFG] Profondeur de consigne (negative)
    DepthStopMode           : E_CycleDepthStopMode; // --> [CFG] Source d'arret AX7

    // === FEEDBACKS CAPTEURS & MATERIEL ===
    KoboldImmersed          : BOOL;         // --> [HW] Etat brut DI Kobold : TRUE = sonde dans l'eau (fronts AX6/AX7)
    LimitLegalReached       : BOOL;         // --> [SAFE] Limite legale atteinte (descente interdite)
    LimitLegalDepthM        : REAL;         // --> [CFG] Profondeur legale minimale autorisee
    WinchSyncError          : BOOL;         // --> [SAFE] Desynchronisme bloquant M1/M2
    WinchSyncDeltaM         : REAL;         // --> [HW] Ecart codeurs M1/M2 pour diagnostic
    M1_CablePosM            : REAL;         // --> [HW] Position cable treuil M1 (recalee)
    M2_CablePosM            : REAL;         // --> [HW] Position cable treuil M2 (recalee)
    M1_MeasuredSpeedMps     : REAL;         // --> [HW] Vitesse lineaire mesuree M1 (m/s)
    M2_MeasuredSpeedMps     : REAL;         // --> [HW] Vitesse lineaire mesuree M2 (m/s)
    M1_SpeedValid           : BOOL;         // --> [HW] Mesure vitesse M1 valide
    M2_SpeedValid           : BOOL;         // --> [HW] Mesure vitesse M2 valide
    M1_ContactorsReleased   : BOOL;         // --> [HW] Tous contacteurs M1 retombes
    M2_ContactorsReleased   : BOOL;         // --> [HW] Tous contacteurs M2 retombes
    M1_BrakeApplied         : BOOL;         // --> [HW] Frein M1 mecaniquement serre
    M2_BrakeApplied         : BOOL;         // --> [HW] Frein M2 mecaniquement serre
    SpeedMismatchThresholdMps : REAL;       // --> [CFG] Seuil ecart vitesse ; 0 = controle desactive
    SpeedMismatchTimeout    : TIME;         // --> [CFG] Duree de confirmation ; 0 = controle desactive
    CableLimitM1AscentM     : REAL;         // --> [CFG] Limite haute d'exploitation M1 (compatibilite interface)
    M1TopLimitReached       : BOOL;         // --> [SAFE] FDC haut logiciel effectif M1
    M2TopLimitReached       : BOOL;         // --> [SAFE] FDC haut logiciel effectif M2

    // === FEEDBACKS TRANSLATION M3 ===
    Translation_At_P1           : BOOL;     // --> [HW] Capteur position P1 (arret travail)
    Translation_At_Tremie       : BOOL;     // --> [HW] Capteur fin de course tremie
    Translation_At_Maintenance : BOOL;     // --> [HW] Capteur fin de course maintenance
    Translation_PosP1            : BOOL;     // --> [HW] Etat brut capteur P1 (diagnostic de zone)
    Translation_PosMaintenance   : BOOL;     // --> [HW] Etat brut capteur Maintenance (diagnostic de zone)
    Translation_Busy            : BOOL;     // --> [HW] Mouvement translation en cours
    Translation_Done            : BOOL;     // --> [HW] Cible translation atteinte

    // === FEEDBACKS BENNE ===
    Benne_Busy              : BOOL;         // --> [HW] Mouvement machoires benne en cours
    Benne_Done              : BOOL;         // --> [HW] Mouvement ouverture/fermeture termine
    Benne_CloseReached      : BOOL;         // --> [HW] Fermeture atteinte, maintien AX10B disponible
    Benne_IsOpen            : BOOL;         // --> [HW] Benne mecaniquement ouverte memorisee
    Benne_IsClosed          : BOOL;         // --> [HW] Benne mecaniquement fermee memorisee
    Benne_IsRoughlyClosed   : BOOL;         // --> [HW] Benne a peu pres fermee (tolerance matiere)
    M1FinalAscentStartReady : BOOL;         // --> [HW] M1 pret au demarrage montee (barriere finale purgee)

    // === REFERENCEMENT CODEURS ===
    HomedM1                 : BOOL;         // --> [HW] Codeur M1 reference
    HomedM2                 : BOOL;         // --> [HW] Codeur M2 reference
    HomingRequest           : BOOL;         // --> [CMD] Demande de referencement (front)
    InitPositionOk          : BOOL;         // --> [HW] Posture de depart OK (treuils/M3 dans la plage, calcul PRG_03) - condition AX1_INIT
    WinchesAtTopWindow      : BOOL;         // --> [HW] Treuils M1 ET M2 dans la fenetre FDC logiciel haut (calcul PRG_03) - surveille en AX2

    // === CONFIG & COMMANDES CYCLE (IHM) ===
    CfgDrainTime           : TIME;         // --> [CFG] Duree d'egouttage AX13 configurable IHM (<= 0 -> defaut interne)
    SkipDrainRequest       : BOOL;         // --> [CMD] Bouton IHM : passer l'etape d'egouttage AX13 (front)
    RepositionRequest      : BOOL;         // --> [CMD] Option IHM (maintenue) : repositionnement couple M1+M2 pendant le vidage tremie (AX15B <-> AX15C)
    // 🔧 T358 : la cible de forcage n'est PLUS une configuration persistee ni une
    // impulsion de bouton. Elle est portee par l'argument StepForceTgt ci-dessous
    // (champ IHM non persiste) : une valeur oubliee d'une session precedente ne peut
    // donc plus provoquer de saut d'etape automatique au demarrage.
    CfgCommissioningEnable : BOOL;         // --> [CFG] Case IHM mise en service (reserve : aucun usage interne, cf. note T358)
    CfgCycleChecksInhibit  : BOOL;         // --> [TST] Activation controles procede inhibes en mise en service
    StepForceTgt           : INT := -1;    // --> [CMD] Etape cible du forcage ecrit par l'operateur (IHM) ; -1 = aucune demande (sentinelle CST_StepForceNone). Defaut = sentinelle : un cablage absent ou rompu ne peut JAMAIS produire un forcage

    // === CONFIG DIVING / EXTRACTION (GEL 2026-09-03) ===
    DiveStartMinM          : REAL;         // --> [CFG] Altimetrie de lancement Kobold (AT4 : AX4 -> AX5), reglable IHM (~3..5 m ; <= 0 -> defaut interne)
    CfgRaiseOffBottomM     : REAL;         // --> [CFG] Decollement du fond en AX8 (reglable IHM ; 0 -> passage direct AX10, >0 -> AX9)
    CfgCtrlAscentMaxStep   : INT;          // --> [CFG] Palier max montee controle AX11, borne [1..2] (defaut 1)
    CfgCtrlAscentDistanceM : REAL;         // --> [CFG] Distance controle AX11 depuis son depart (m)
    M1_SpeedStepApplied    : INT;          // --> [HW] Palier vitesse effectivement applique M1 (0 = inconnu ; garde palier <> 4 en diving)
    M2_SpeedStepApplied    : INT;          // --> [HW] Palier vitesse effectivement applique M2 (0 = inconnu)
    CfgAutoDiveM2Step5Trial : BOOL;        // --> [CFG] Essai T291-A : M2 palier 5 en descente auto AX4..AX7, non persistant

    // === COMPTEURS DE PRELEVEMENTS ===
    ResetSampleCountRequest : BOOL;         // --> [CMD] RAZ IHM du compteur JOURNALIER (front montant conscient)
    CfgSampleCountResetMode : E_CycleSampleCountResetMode; // --> [CFG] Mode de RAZ AUTOMATIQUE du journalier (NEVER par defaut = aucune RAZ auto)
    SafetyRearmed            : BOOL;        // --> [SAFE] Chaine AU rearmee (contacteur puissance reengage) — consomme par ON_SAFETY_REARM uniquement
END_VAR
VAR_OUTPUT
    // === ETATS IEC & DEFECTUOSITES ===
    Ready                   : BOOL;         // <-- [STAT] Sequenceur disponible
    Fault                   : ST_Fault;     // <-- [SAFE] Socle defaut transverse (live + latche)
    Lifecycle               : ST_Lifecycle; // <-- [STAT] Cycle de vie (Busy, Done, Waiting)
    SpeedMismatchMps        : REAL;         // <-- [DIAG] Ecart absolu vitesse M1/M2 (m/s)
    SpeedMismatchActive     : BOOL;         // <-- [DIAG] Seuil vitesse depasse sur cycle courant
    SpeedMismatchConfirmed  : BOOL;         // <-- [DIAG] Ecart vitesse confirme pendant timeout
    BottomTouched           : BOOL;         // <-- [STAT] Fond touche (latch AX8, efface a AX0 / AX_STAB / Reset) - variable d'info GEL AX8
    BottomStopByKobold      : BOOL;         // <-- [STAT] AX8 confirme par contact Kobold
    BottomStopBySetpoint    : BOOL;         // <-- [STAT] AX8 confirme par limite de travail/consigne de position
    BottomStopSource        : STRING(24);  // <-- [DIAG] Source arret fond : KOBOLD ou CONSIGNE
    CycleChecksInhibited    : BOOL;         // <-- [STAT] Controles procede inhibes ; protections machine actives
    IgnoredCycleCheckId     : WORD;         // <-- [DIAG] Causes procede actives mais ignorees
    ForceStepAccepted       : BOOL;         // <-- [DIAG] Impulsion : consigne de forcage appliquee (saut d'etape effectif au scan suivant)
    ForceStepRejected       : BOOL;         // <-- [DIAG] Impulsion : consigne ecartee (cible hors plage enum, ou cycle inactif)
    ForceStepResult         : STRING(120);  // <-- [DIAG] Motif de rejet de la derniere consigne (vide apres une consigne appliquee)
    StepForceTgtTaken       : BOOL;         // <-- [STAT] Impulsion : une consigne de forcage etait presente ce scan (appliquee, rejetee ou ecartee) — PRG_03 l'acquitte sur ce signal

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
    M1SpeedStepAtFault      : INT;                      // <-- [DIAG] Palier M1 applique, fige au moment du defaut (0..5)
    M2SpeedStepAtFault      : INT;                      // <-- [DIAG] Palier M2 applique, fige au moment du defaut (0..5)
    ResumeAfterFaultAvailable : BOOL;                   // <-- [STAT] Reprise AX_STAB autorisee
    OperatorActionId        : WORD;                 // <-- [DIAG] ID action operateur requise
    OperatorAction          : STRING(120);          // <-- [DIAG] Message explicatif pour l'IHM
    ExpectedAxis            : E_OperatorAxis;       // <-- [STAT] Organe joystick/bouton attendu
    ExpectedDirection       : INT;                  // <-- [STAT] Sens attendu (-1, 0, +1)
    WaitingForOperator      : BOOL;                 // <-- [STAT] En attente d'une action operateur
    WaitingForProcess       : BOOL;                 // <-- [STAT] En attente d'une condition procede
    RequestActive           : BOOL;                 // <-- [STAT] Demande de mouvement active
    CurrentCycleElapsed_Min : INT;                  // <-- [DIAG] Minutes ecoulees du cycle en cours (chronometre sur Lifecycle.Busy)
    CurrentCycleElapsed_S   : INT;                  // <-- [DIAG] Secondes ecoulees du cycle en cours (0..59)
    LastCycleDuration_Min   : INT;                  // <-- [DIAG] Minutes du dernier cycle acheve (figees a X13, persistent au cycle suivant)
    LastCycleDuration_S     : INT;                  // <-- [DIAG] Secondes du dernier cycle acheve (figees a X13, 0..59)
    DrainTimeRemaining      : TIME;                 // <-- [DIAG] Temps restant en AX13 ; zero hors AX13
    AutoDiveM1Step4M2Step5Active : BOOL;            // <-- [STAT] Profil T291-A actif sur la phase plongee auto
END_VAR
VAR_IN_OUT
    // === STRUCTURES PARTAGEES & COMPTEURS ===
    SampleCount             : INT;          // <-> [BUS] Compteur JOURNALIER de prelevements (RAZ IHM/mode auto possible)
    SampleCountTotal        : UDINT;        // <-> [BUS] TOTALISATEUR de prelevements — JAMAIS remis a zero, ecrit au seul incrément AX18
END_VAR
VAR
    // === DETECTEURS DE FRONTS ===
    ResetEdge               : R_TRIG;       // . [LOC] Detecteur front montant Reset
    StartEdge               : R_TRIG;       // . [LOC] Detecteur front montant StartCycle
    DeadmanArmedEdge        : R_TRIG;       // . [LOC] Detecteur front montant DeadmanArmed (demarrage joystick)
    AbortEdge               : R_TRIG;       // . [LOC] Detecteur front montant AbortCycle
    ResumeAfterFaultEdge    : R_TRIG;       // . [LOC] Detecteur front montant reprise AX_STAB
    ErrorEdge               : R_TRIG;       // . [LOC] Detecteur front montant Error
    JoyDeflectedEdge        : R_TRIG;       // . [LOC] Front montant JoystickDeflected (relance AX18 sur geste franc, pas maintien)
    ResetSampleCountEdge    : R_TRIG;       // . [LOC] Detecteur front montant demande de RAZ IHM du compteur journalier
    SafetyRearmedEdge       : R_TRIG;       // . [LOC] Detecteur front montant rearmement de la chaine AU

    // === GATE CONTINU HOMME-MORT ===
    CycleMotionPermit       : BOOL; // . [LOC] Permis de mouvement cycle = JoystickDeflected AND DeadmanArmed (manche deflechi + homme-mort arme)
    TranslationP1Permit     : BOOL; // . [LOC] Translation vers P1 : axe X droit seul, axe Y au neutre
    TranslationTremiePermit : BOOL; // . [LOC] Translation vers tremie : axe X gauche seul, axe Y au neutre
    JoystickPushOnly        : BOOL; // . [LOC] Geste Y- seul : ouverture benne/plongee, diagonales X+Y refusees
    WinchesAtDiveStep       : BOOL; // . [LOC] M1 ET M2 confirmes au palier 4 (mesure Kobold fiable seulement a vitesse stabilisee)
    AutoDiveM2Step5TrialLatched : BOOL := FALSE; // . [LOC] Capture essai T291-A avant depart plongee, figee jusqu'a sortie AX4..AX7
    DiveM2StepTgt           : INT := 4;  // . [LOC] Palier cible M2 plongee : 4 nominal, 5 essai T291-A

    // === COMPTEUR PRELEVEMENTS (garde de front) ===
    SampleCountDone         : BOOL := FALSE; // . [LOC] F2: front de comptage SampleCount (1 seul increment par cycle)

    // === COMPTEURS PRELEVEMENTS (RAZ journalier) ===
    DayStartResetDone       : BOOL := FALSE; // . [LOC] Mode ON_FIRST_START : un demarrage de cycle a deja ete vu depuis le boot
    SampleCountAutoResetPulse : BOOL;        // . [LOC] Impulsion interne de RAZ automatique issue du mode configure

    // === ETATS INTERNES ===
    State                   : E_AutoCycleStep := E_AutoCycleStep.AX0_REPOS; // . [LOC] Etape courante machine d'etat
    SavedState              : E_AutoCycleStep := E_AutoCycleStep.AX0_REPOS; // . [LOC] Etape memorisee
    PausedState             : E_AutoCycleStep := E_AutoCycleStep.AX0_REPOS; // . [LOC] Etape en pause lors de la bascule hors auto
    ForceStepCandidate      : E_AutoCycleStep := E_AutoCycleStep.AX0_REPOS; // . [LOC] Etape locale issue de la table numero -> etape
    ForceStepCandidateValid : BOOL := FALSE;  // . [LOC] La table a effectivement trouve une etape (anti-trou d'enum : un membre non traite est un refus, jamais un AX0 silencieux)
    StepForceConsigne       : INT;            // . [LOC] Consigne de forcage lue en tete de §2 ; un acquittement (Reset/Abort) du meme scan l'annule
    WaitingResume           : BOOL := FALSE;                             // . [LOC] En attente de validation consciente pour reprendre

    // === MEMORISATIONS & REGISTRES INTERNES ===
    TouchPositionM1         : REAL;         // . [LOC] Position M1 memorisee lors du contact fond
    TouchPositionM2         : REAL;         // . [LOC] Position M2 memorisee lors du contact fond
    StopPositionM1          : REAL;         // . [LOC] Position M1 apres arret mecanique stabilise AX8
    StopPositionM2          : REAL;         // . [LOC] Position M2 apres arret mecanique stabilise AX8
    RaiseTargetM1           : REAL;         // . [LOC] Cible M1 de decollement du fond
    RaiseTargetM2           : REAL;         // . [LOC] Cible M2 de decollement du fond
    CtrlAscentStartM1       : REAL;         // . [LOC] Position de depart AX11 M1
    CtrlAscentStartM2       : REAL;         // . [LOC] Position de depart AX11 M2
    StopPositionCaptured    : BOOL;         // . [LOC] Position stabilisee capturee une seule fois en AX8
    DepthSetpointValid      : BOOL;         // . [LOC] Consigne valide et au-dessus de la limite legale
    DepthSetpointReachedNow : BOOL;         // . [LOC] Les deux treuils ont atteint la consigne hors AX7
    DepthStopBySetpoint     : BOOL;         // . [LOC] Les deux treuils ont atteint la consigne AX7
    SelectedWorkTarget      : INT;          // . [LOC] Cible de travail (fige a 3=P1 depuis C3.1) - conserve pour diag/futur
    InitConditionsOk        : BOOL;         // . [LOC] AX1_INIT : toutes les conditions initiales sont remplies
    StepMaxPrevState        : E_AutoCycleStep;  // . [LOC] Etape du scan precedent (rearmement StepMaxTimer au changement d'etape)
    ExtractionDelayState    : E_AutoCycleStep := E_AutoCycleStep.AX0_REPOS;

    // === FRONTS / TEMPO DIVING ===
    KoboldRiseEdge          : R_TRIG;       // . [LOC] Front DI Kobold 0->1 (entree dans l'eau, AX6)
    KoboldFallEdge          : F_TRIG;       // . [LOC] Front DI Kobold 1->0 (fond, AX7)
    KoboldInitTimer         : TON;          // . [LOC] Fenetre de verif retour contacteur Kobold en AX5
    KoboldStabTimer         : TON;          // . [LOC] Stabilisation feedback Kobold sous tension (500ms en AX6)
    BottomTouchStabTimer    : TON;          // . [LOC] Stabilisation arret fond touche (500ms en AX8)
    RetryJoyReleaseTimer    : TON;          // . [LOC] Anti-rebond relache joystick pendant diving (>= 200 ms avant reprise)
    PalierNot4Timer         : TON;          // . [LOC] Confirmation palier bloque < 4 en plongee (tolere la rampe 1->4)
    KoboldBottomTimer       : TON;          // . [LOC] Confirmation DI Kobold basse apres immersion
    KoboldImmersionQualified: BOOL;         // . [LOC] DI haute stable observee sous alimentation
    DivingRetryTrig         : BOOL;         // . [LOC] Synthese GT-dive-retry (erreur Kobold / joystick relache / palier < 4 confirme en AX5..AX7)
    CtrlAscentMaxStepEff    : INT;          // . [LOC] CfgCtrlAscentMaxStep borne [1..2]
    RaiseOffBottomEff       : REAL;         // . [LOC] CfgRaiseOffBottomM borne (0 = pas d'AX9)
    DiveStartMinEff         : REAL;         // . [LOC] DiveStartMinM borne (defaut interne si <= 0)

    // === TEMPORISATEURS INTERNES ===
    DrainingTimer           : TON;          // . [LOC] Temporisateur de vidage (egouttage), PT = DrainTimeEff
    CycleRunTimer           : TON;          // . [LOC] Chronometre du cycle en cours (IN = Lifecycle.Busy) ; .ET = duree
    CycleElapsedTotal_S     : DINT;         // . [LOC] Duree du cycle en cours en secondes entieres (base de la conversion min/sec T347)
    SkipDrainEdge           : R_TRIG;       // . [LOC] Front bouton IHM "passer egouttage"
    DrainTimeEff            : TIME;         // . [LOC] Duree d'egouttage effective (CfgDrainTime bornee au defaut interne)
    DrainRemaining_S        : INT;          // . [LOC] Temps restant d'egouttage arrondi au superieur (secondes entieres) — porte par CycleStateStr en AX13
    StabilizationTimer      : TON;          // . [LOC] Temporisation maximale de remontee lente
    TranslationStopTimer    : TON;          // . [LOC] Confirmation arret physique M3 sur FDC avant etape benne
    SpeedMismatchTimer      : TON;          // . [LOC] Confirmation temporelle ecart de vitesse
    StepMaxTimer            : TON;          // . [LOC] Tempo max d'etape
    ExtractionStepDelayTimer : TON;
    StateExecutionInhibit   : BOOL;         // . [LOC] Interdit le CASE au scan de forçage
    SeenNeutralAfterArrival : BOOL;         // . [LOC] Neutre XY observe depuis la derniere entree en AX15A

    // === CONSTANTES & CONFIGURATIONS INTERNES ===
    CtrlAscentToleranceM    : REAL := 0.25;     // . [LOC] Ancien seuil local conserve pour compatibilite IHM, non bloquant AX11
    CtrlAscentDistM         : REAL := 2.0;      // . [LOC] Distance minimale AX11 depuis le contact fond
    CtrlAscentDistEffM      : REAL;              // . [LOC] Distance AX11 valide et bornee
    CtrlAscentTimeout       : TIME := T#1s;     // . [LOC] Pause de controle AX11 avant passage AX12
    DrainingTime            : TIME := T#5s;     // . [LOC] Temps d'egouttage par defaut
    StepMaxTimeout          : TIME := T#60s;    // . [LOC] Tempo max d'etape
    DiveStartStopTimer      : TON;              // . [LOC] Confirmation arret mecanique avant depart couple
    AscentStartStopTimer    : TON;              // . [LOC] Confirmation arret mecanique avant depart montee couplee
    Ax10bHandoffWaitTimer   : TON;              // . [LOC] Fenetre bornee d'attente disponibilite M1 pendant maintien M2 P1
    Ax10bFallbackStopActive : BOOL;             // . [LOC] Repli arret historique si M1 ne devient pas disponible
    DiveStartTimeoutTimer   : TON;              // . [LOC] Plafond attente arret mecanique (sanction defaut)
    DiveStartStopped        : BOOL;              // . [LOC] Les deux treuils sont physiquement arretes et mesures valides
    CST_KoboldStabTime      : TIME := T#500ms;  // . [LOC] Stabilisation feedback Kobold
    CST_KoboldPowerUpTime   : TIME := T#500ms;  // . [LOC] Etablissement alimentation capteur Kobold
    CST_KoboldBottomConfirmTime : TIME := T#100ms; // . [LOC] Anti-rebond contact fond
    CST_BottomTouchStabTime : TIME := T#500ms;  // . [LOC] Stabilisation arret apres contact fond
    CST_TranslationStopConfirmTime : TIME := T#500ms; // . [LOC] Confirmation arret physique M3 sur FDC P1/trémie

    // === SOCLE DEFAUT TRANSVERSE ===
    instFault               : FB_FaultCore;                  // * [INST] Socle defaut transverse
    instCauses              : ARRAY[0..15] OF ST_FaultCause; // . [LOC] Table des causes de defaut
END_VAR
VAR CONSTANT
    // Paliers de vitesse treuil par etape (StepTgt des demandes WinchMxCmd, 1..5 ; 0 = arret).
    CST_StepSlow   : INT := 1;   // Palier lent : retente AX9, controle AX11, repositionnement AX15C
    CST_StepDive   : INT := 4;   // Palier plongee Kobold AX4..AX7 : M1 reste palier 4
    CST_StepDiveM2Trial : INT := 5; // Essai T291-A : M2 seul peut viser le palier 5 en AX4..AX7
    CST_StepLoaded : INT := 5;   // Palier montee en charge AX12 (P5, plafonds de securite aval conserves)
    CST_KoboldInitTimeout : TIME := T#3s;   // Fenetre max de confirmation retour contacteur Kobold en AX5
    CST_DiveStartStopConfirmTime : TIME := T#300ms; // Confirmation stable des 6 faits d'arret + validite vitesses
    CST_AscentStartStopConfirmTime : TIME := T#500ms; // Purge redemarrage apres fermeture benne
    CST_Ax10bHandoffWaitTime : TIME := T#2s; // Attente maximale M1 pendant effort M2 P1 avant repli arret sur
    CST_DiveStartStopTimeout : TIME := T#5s; // Plafond anti-blocage ; timeout -> defaut latche, jamais depart
    CST_DiveStartSpeedThresholdMps : REAL := 0.02; // Vitesse quasi nulle, alignee FB_Modes
    CST_ExtractionStepDelay    : TIME := T#1s;
    // 🔧 T358 : forcage de step — sentinelle de consigne et borne haute de plage.
    // CST_StepForceMax = dernier membre de E_AutoCycleStep (AX15D_DUMP_BUCKET_JOG, T383) :
    // toute valeur hors [0..23] est refusee, toute valeur de l'enum est acceptee.
    CST_StepForceNone          : INT := -1;   // Sentinelle : aucune demande de forcage
    CST_StepForceMax           : INT := 23;   // Borne haute de la plage d'enum coercible
END_VAR

// === IMPLEMENTATION ===

{region "§1 Causes & Socle Défaut"}
// 🔑 1. FRONTS ET CAUSES
ResetEdge(CLK := Reset);
StartEdge(CLK := StartCycle);
DeadmanArmedEdge(CLK := DeadmanArmed);
AbortEdge(CLK := AbortCycle);
ResumeAfterFaultEdge(CLK := ResumeAfterFault);
SkipDrainEdge(CLK := SkipDrainRequest);
KoboldRiseEdge(CLK := KoboldImmersed);
KoboldFallEdge(CLK := KoboldImmersed);
JoyDeflectedEdge(CLK := JoystickDeflected);
ResetSampleCountEdge(CLK := ResetSampleCountRequest);
SafetyRearmedEdge(CLK := SafetyRearmed);
StateExecutionInhibit := FALSE;
ForceStepAccepted := FALSE;
ForceStepRejected := FALSE;

DiveStartStopped := M1_SpeedValid AND M2_SpeedValid
                    AND M1_ContactorsReleased AND M2_ContactorsReleased
                    AND M1_BrakeApplied AND M2_BrakeApplied
                    AND (ABS(M1_MeasuredSpeedMps) < CST_DiveStartSpeedThresholdMps)
                    AND (ABS(M2_MeasuredSpeedMps) < CST_DiveStartSpeedThresholdMps);
DiveStartStopTimer(IN := (State = E_AutoCycleStep.AX3_WAIT_DIVE_START) AND DiveStartStopped,
                   PT := CST_DiveStartStopConfirmTime);
AscentStartStopTimer(IN := (State = E_AutoCycleStep.AX10B_RACCORDEMENT_P1) AND Ax10bFallbackStopActive AND DiveStartStopped,
                     PT := CST_AscentStartStopConfirmTime);
Ax10bHandoffWaitTimer(IN := (State = E_AutoCycleStep.AX10B_RACCORDEMENT_P1)
                              AND Benne_CloseReached
                              AND NOT Ax10bFallbackStopActive
                              AND NOT ((M2_SpeedStepApplied = 1) AND M1FinalAscentStartReady),
                         PT := CST_Ax10bHandoffWaitTime);
// AX3_WAIT_DIVE_START est une attente de condition mecanique, sans sanction
// temporelle : l'arret confirme reste obligatoire pour passer en AX4.
DiveStartTimeoutTimer(IN := FALSE, PT := CST_DiveStartStopTimeout);

// Config diving/extraction bornee (repli defaut interne si non reglee / valeur implausible).
// DiveStartMinM = altimetrie de lancement Kobold dans le referentiel M1_CablePosM
// (positif, ~7,5 m au FDC haut, decroissant a la descente). Plage plausible 0,5..8,0 m ;
// hors plage -> repli 4,0 m.
IF (DiveStartMinM >= 0.5) AND (DiveStartMinM <= 8.0) THEN
    DiveStartMinEff := DiveStartMinM;
ELSE
    DiveStartMinEff := 4.0;
END_IF;
RaiseOffBottomEff := SEL(CfgRaiseOffBottomM <= 0.0, 0.0, CfgRaiseOffBottomM);
CtrlAscentMaxStepEff := LIMIT(1, CfgCtrlAscentMaxStep, 2);
CtrlAscentDistEffM := SEL(CfgCtrlAscentDistanceM <= 0.0, CtrlAscentDistM, CfgCtrlAscentDistanceM);

// ⏱️ Chronomètre du cycle : compte tant que le séquenceur est actif (Lifecycle.Busy).
// .ET = durée écoulée du cycle en cours ; figée dans LastCycleDuration_Min/_S à l'achèvement (X13).
// Conversion TIME -> minutes/secondes (T347) : troncature à la seconde, aucun arrondi.
CycleRunTimer(IN := Lifecycle.Busy, PT := T#12h);
CycleElapsedTotal_S := TIME_TO_DINT(CycleRunTimer.ET) / DINT#1000;
CurrentCycleElapsed_Min := DINT_TO_INT(CycleElapsedTotal_S / DINT#60);
CurrentCycleElapsed_S   := DINT_TO_INT(CycleElapsedTotal_S MOD DINT#60);

// Durée d'égouttage effective : config IHM si valide, sinon défaut interne.
DrainTimeEff := SEL(CfgDrainTime <= T#0s, CfgDrainTime, DrainingTime);

// ⏱️ Surveillance indépendante de la remontée lente de controle
// AX11_CTRL_ASCENT -> AX12_LOADED_ASCENT : pause de controle courte.
// Le synchronisme est surveille par FB_WinchSync ; aucune comparaison de
// positions memorisees au fond ne doit bloquer le passage lorsque les mesures
// courantes sont valides.
StabilizationTimer(
    IN := (State = E_AutoCycleStep.AX11_CTRL_ASCENT),
    PT := CtrlAscentTimeout);

// Arrêt M3 confirmé avant de quitter AX14 : le FDC seul ne suffit pas si le
// variateur est encore en décélération. L'homme-mort peut rester armé pour AX15B.
TranslationStopTimer(
    IN := (((State = E_AutoCycleStep.AX2_TRANSLATE_P1) AND Translation_At_P1)
           OR ((State = E_AutoCycleStep.AX14_TRANSLATE_DUMP) AND Translation_At_Tremie))
          AND NOT Translation_Busy,
    PT := CST_TranslationStopConfirmTime);

// AX5 : le contacteur alimente le capteur ; aucun retour auxiliaire n existe.
KoboldInitTimer(IN := (State = E_AutoCycleStep.AX5_KOBOLD_INIT) AND DeadmanArmed AND JoystickPush,
                PT := CST_KoboldPowerUpTime);

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

// Tempo max d'étape (R5) — DÉSACTIVÉE (pour éviter toute coupure/repli AX_STAB intempestif sur durée)
StepMaxTimer(IN := FALSE, PT := StepMaxTimeout);
StepMaxPrevState := State;
ExtractionStepDelayTimer(
    IN := ((State = E_AutoCycleStep.AX9_RAISE_OFF_BOTTOM)
        OR (State = E_AutoCycleStep.AX10_CLOSE_BUCKET))
       AND (State = ExtractionDelayState),
    PT := CST_ExtractionStepDelay);
IF State <> ExtractionDelayState THEN
    ExtractionDelayState := State;
END_IF;

// Egouttage AX13 : TON gaté sur l'étape (remis à 0 hors AX13). Remplace l'ancien IN:=TRUE câblé
// qui pouvait laisser Q déjà vrai à l'entrée en AX13 (temps d'égouttage non respecté).
DrainingTimer(IN := (State = E_AutoCycleStep.AX13_DRAIN_PAUSE), PT := DrainTimeEff);
IF (State = E_AutoCycleStep.AX13_DRAIN_PAUSE) AND NOT DrainingTimer.Q AND NOT SkipDrainEdge.Q THEN
    DrainTimeRemaining := DrainTimeEff - DrainingTimer.ET;
ELSE
    DrainTimeRemaining := T#0s;
END_IF;

// ⏱️ Stabilisation alimentation Kobold (500ms en AX6 avant surveillance fond)
KoboldStabTimer(IN := (State = E_AutoCycleStep.AX6_SEARCH_IMMERSION) AND DeadmanArmed AND JoystickPush AND KoboldImmersed, PT := CST_KoboldStabTime);

// ⏱️ Stabilisation à l'arrêt fond touché (2s en AX8 freins serrés avant montée AX9)
BottomTouchStabTimer(IN := (State = E_AutoCycleStep.AX8_BOTTOM_CONFIRMED) AND DiveStartStopped,
                     PT := CST_BottomTouchStabTime);

// GT-dive-retry (GEL Q11) : en AX5/AX6/AX7, erreur sequence Kobold / joystick relache / palier < 4
RetryJoyReleaseTimer(IN := ((State = E_AutoCycleStep.AX5_KOBOLD_INIT)
                             OR (State = E_AutoCycleStep.AX6_SEARCH_IMMERSION)
                             OR (State = E_AutoCycleStep.AX7_SEARCH_BOTTOM))
                            AND NOT (DeadmanArmed AND JoystickPush),
                     PT := T#200ms);
DiveM2StepTgt := SEL(AutoDiveM2Step5TrialLatched, CST_StepDive, CST_StepDiveM2Trial);
AutoDiveM1Step4M2Step5Active :=
    AutoDiveM2Step5TrialLatched
    AND ((State = E_AutoCycleStep.AX4_DESCEND_DIVING)
      OR (State = E_AutoCycleStep.AX5_KOBOLD_INIT)
      OR (State = E_AutoCycleStep.AX6_SEARCH_IMMERSION)
      OR (State = E_AutoCycleStep.AX7_SEARCH_BOTTOM));

WinchesAtDiveStep := (M1_SpeedStepApplied = CST_StepDive) AND (M2_SpeedStepApplied = DiveM2StepTgt);
PalierNot4Timer(IN := ((State = E_AutoCycleStep.AX6_SEARCH_IMMERSION) OR (State = E_AutoCycleStep.AX7_SEARCH_BOTTOM))
                         AND DeadmanArmed AND JoystickPush AND NOT WinchesAtDiveStep,
                    PT := T#2s);
DivingRetryTrig := FALSE;
KoboldBottomTimer(IN := (State = E_AutoCycleStep.AX7_SEARCH_BOTTOM)
                         AND KoboldImmersionQualified AND NOT KoboldImmersed,
                   PT := CST_KoboldBottomConfirmTime);

// Consigne profondeur : profondeur negative, et jamais au-dela de la limite legale.
DepthSetpointValid := (SetDepthM < 0.0)
                      AND ((LimitLegalDepthM >= -0.01) OR (SetDepthM >= LimitLegalDepthM));
DepthSetpointReachedNow := ((DepthStopMode = E_CycleDepthStopMode.SETPOINT_ONLY)
                            OR (DepthStopMode = E_CycleDepthStopMode.KOBOLD_OR_SETPOINT))
                           AND DepthSetpointValid
                           AND (M1_CablePosM <= SetDepthM)
                           AND (M2_CablePosM <= SetDepthM);
DepthStopBySetpoint := (State = E_AutoCycleStep.AX7_SEARCH_BOTTOM)
                       AND ((DepthStopMode = E_CycleDepthStopMode.SETPOINT_ONLY)
                            OR (DepthStopMode = E_CycleDepthStopMode.KOBOLD_OR_SETPOINT))
                       AND DepthSetpointValid
                       AND (M1_CablePosM <= SetDepthM)
                       AND (M2_CablePosM <= SetDepthM);

// Commande de niveau directement maitrisable depuis l'IHM : OFF retire l'inhibition au scan suivant.
// Le toggle de commissioning ne conditionne pas l'application du réglage cycle.
CycleChecksInhibited := CfgCycleChecksInhibit AND (Mode = E_Mode.SEMI_AUTO);

// Table des causes de défaut
instCauses[0].Active   := LimitLegalReached
                          AND ((State = E_AutoCycleStep.AX4_DESCEND_DIVING)
                            OR (State = E_AutoCycleStep.AX5_KOBOLD_INIT)
                            OR (State = E_AutoCycleStep.AX6_SEARCH_IMMERSION)
                            OR (State = E_AutoCycleStep.AX7_SEARCH_BOTTOM));
instCauses[0].Latching := TRUE;
instCauses[0].Texte    := 'Limite legale de profondeur atteinte pendant descente';

// PRG_04 purge FB_WinchSync pendant AX8..AX11, mais PRG_03 peut encore lire
// le diagnostic du scan precedent a l'entree AX8. Ces phases sont volontairement
// dissymetriques (contact fond, retente, fermeture, controle) : aucun vieux bit
// de synchronisme ne doit provoquer un repli AX_STAB avant la purge.
instCauses[1].Active   := WinchSyncError
                          AND (State <> E_AutoCycleStep.AX0_REPOS)
                          AND (State <> E_AutoCycleStep.AX_STAB)
                          AND (State <> E_AutoCycleStep.AX8_BOTTOM_CONFIRMED)
                          AND (State <> E_AutoCycleStep.AX9_RAISE_OFF_BOTTOM)
                          AND (State <> E_AutoCycleStep.AX10_CLOSE_BUCKET)
                          AND (State <> E_AutoCycleStep.AX11_CTRL_ASCENT)
                          // AX15D (T383) : module benne sur place a la tremie, meme fenetre de vidage
                          // que AX15B — exclusion sync identique a AX10 (decision safety arbitrage 5).
                          AND (State <> E_AutoCycleStep.AX15D_DUMP_BUCKET_JOG);
instCauses[1].Latching := TRUE;
instCauses[1].Texte    := 'Desynchronisme treuils M1/M2 bloquant';

instCauses[2].Active   := SpeedMismatchConfirmed AND (State <> E_AutoCycleStep.AX0_REPOS) AND (State <> E_AutoCycleStep.AX_STAB);
instCauses[2].Latching := TRUE;
instCauses[2].Texte    := 'Ecart de vitesse M1/M2 confirme en montee';

instCauses[3].Active   := NOT HeartbeatIhmOk AND (State <> E_AutoCycleStep.AX0_REPOS) AND (State <> E_AutoCycleStep.AX_STAB);
instCauses[3].Latching := TRUE;
instCauses[3].Texte    := 'Perte communication IHM pendant cycle';

instCauses[4].Active   := StepMaxTimer.Q AND (State <> E_AutoCycleStep.AX_STAB) AND NOT CycleChecksInhibited;
instCauses[4].Latching := TRUE;
instCauses[4].Texte    := 'Depassement tempo maximale d etape (blocage mouvement)';

// Le timer AX11 est une temporisation de passage, pas une cause de défaut.
// Le défaut éventuel reste exclusivement celui de l'écart vitesse confirmé.
instCauses[5].Active   := SpeedMismatchConfirmed
                          AND (State = E_AutoCycleStep.AX11_CTRL_ASCENT);
instCauses[5].Latching := TRUE;
instCauses[5].Texte    := 'Defaut de stabilisation / tolerance ecart codeurs en remontee controle';

// La decision de synchronisme est produite une seule fois dans PRG_04 : FB_WinchSync
// (defaut critique/confirme ou contacteurs) et FB_Safety_Winch (Meca E). Le cycle
// consomme WinchSyncError (cause 1) ; aucun seuil local ne doit contredire ces reglages.
instCauses[6].Active   := FALSE;
instCauses[6].Latching := TRUE;
instCauses[6].Texte    := 'Reserve - synchronisme arbitre exclusivement par PRG_04';

// AX2 : en production, pendant la translation vers P1 les treuils M1/M2 doivent
// RESTER au FDC logiciel haut. En mise en service, ce contrôle de procédé est
// inhibable par TglCycleChecksInhibit ; les protections machine PRG04 restent actives.
instCauses[7].Active   := NOT CycleChecksInhibited
                          AND NOT WinchesAtTopWindow
                          AND (State = E_AutoCycleStep.AX2_TRANSLATE_P1);
instCauses[7].Latching := TRUE;
instCauses[7].Texte    := 'Treuils M1/M2 hors FDC haut pendant la translation vers P1';

// GEL cause 8 : M1 > 4 ou M2 au-dessus de son palier attendu pendant la plongee.
// En nominal, M2 attendu = 4 ; en essai T291-A capture avant AX4, M2 attendu = 5.
// (Un palier < 4 en retour est traite en reprise par GT-dive-retry, pas ici.)
instCauses[8].Active   := (((M1_SpeedStepApplied > CST_StepDive) OR (M2_SpeedStepApplied > DiveM2StepTgt)))
                          AND ((State = E_AutoCycleStep.AX4_DESCEND_DIVING)
                            OR (State = E_AutoCycleStep.AX5_KOBOLD_INIT)
                            OR (State = E_AutoCycleStep.AX6_SEARCH_IMMERSION)
                            OR (State = E_AutoCycleStep.AX7_SEARCH_BOTTOM));
instCauses[8].Latching := TRUE;
instCauses[8].Texte    := 'Palier vitesse > 4 (palier 5) pendant la plongee - interdit';

// GEL cause 9 : mesure Kobold fiable seulement a vitesse de descente stabilisee
// palier 4 sur LES DEUX treuils. Recherche immersion/fond (AX6/AX7) avec un des
// deux hors palier 4 -> defaut latche (pas un blocage silencieux de transition).
instCauses[9].Active   := PalierNot4Timer.Q AND NOT CycleChecksInhibited
                          AND ((State = E_AutoCycleStep.AX6_SEARCH_IMMERSION)
                            OR (State = E_AutoCycleStep.AX7_SEARCH_BOTTOM));
instCauses[9].Latching := TRUE;
instCauses[9].Texte    := 'Palier 4 non confirme sur M1 et/ou M2 pendant la recherche Kobold';

instCauses[10].Active   := FALSE;
instCauses[10].Latching := TRUE;
instCauses[10].Texte    := 'Reserve - attente arret mecanique AX3 sans defaut temporel';

instCauses[11].Active   := (State = E_AutoCycleStep.AX7_SEARCH_BOTTOM)
                           AND (DepthStopMode <> E_CycleDepthStopMode.KOBOLD_ONLY)
                           AND NOT DepthSetpointValid;
instCauses[11].Latching := TRUE;
instCauses[11].Texte    := 'Consigne profondeur invalide ou sous la limite legale';

IgnoredCycleCheckId := 0;
IF CycleChecksInhibited AND StepMaxTimer.Q THEN IgnoredCycleCheckId := IgnoredCycleCheckId OR 16#0010; END_IF;
IF CycleChecksInhibited AND PalierNot4Timer.Q THEN IgnoredCycleCheckId := IgnoredCycleCheckId OR 16#0200; END_IF;

// Reprise AX_STAB autorisee seulement si la cause live a disparu, la machine est
// arretee et le joystick est au neutre. La commande de reprise acquitte sur front.
ResumeAfterFaultAvailable := (State = E_AutoCycleStep.AX_STAB)
                             AND Fault.Latched
                             AND NOT Fault.Error
                             AND PowerContactorEngaged
                             AND DiveStartStopped
                             AND NOT JoystickDeflected
                             AND (CycleStepAtError <> E_AutoCycleStep.AX_STAB);

// Appel du socle de defaut
instFault(Enable := Enable,
          Reset := Reset OR (ResumeAfterFaultEdge.Q AND ResumeAfterFaultAvailable),
          Causes := instCauses);
Fault := instFault.Fault;
ErrorEdge(CLK := Fault.Error);
{endregion}

{region "§1bis Compteurs de prelevements"}
// 🔢 DEUX compteurs DISTINCTS, incrementes au MEME evenement (depose tremie AX18, 1 fois par
// cycle, garde de front SampleCountDone) :
//    - SampleCount      : JOURNALIER — RAZ possible (bouton IHM conscient, ou mode AUTO configurable) ;
//    - SampleCountTotal : TOTALISATEUR — JAMAIS remis a zero, aucun chemin d'ecriture hors l'increment AX18.
// Cette region est volontairement AVANT le gate securite/mode (§2) : le compteur est une donnee
// d'exploitation, pas une commande de mouvement — la RAZ reste donc effective hors SEMI_AUTO
// (ex. remise a zero par le responsable en MAINT_N1). Aucune commande d'actionneur n'est produite ici.
SampleCountAutoResetPulse := FALSE;

// (b) ON_FIRST_START — premier demarrage de cycle depuis la mise sous tension de l'automate.
// ⚠️ L'automate n'embarque AUCUNE horloge calendaire (pas de RTC, pas de bibliotheque temps) :
//    le proxy "jour" retenu est le boot, valable pour une machine arretee entre deux postes.
//    Conditions calquees sur la transition AX0->AX1 (§3) + le gate du FB (§2) : une simple
//    pression de bouton hors conditions normales ne consomme PAS l'armement.
// 🔒 Le drapeau "1er demarrage deja vu" est consomme par TOUT demarrage de cycle, QUEL QUE SOIT
//    le mode en vigueur a cet instant : une bascule de mode en cours de poste n'arme donc
//    JAMAIS une RAZ differee qui effacerait les comptes deja realises.
IF Enable AND PowerContactorEngaged AND NOT EncoderFaultPresent AND NOT Fault.Latched
   AND (State = E_AutoCycleStep.AX0_REPOS)
   AND (StartEdge.Q OR DeadmanArmedEdge.Q) THEN
    IF NOT DayStartResetDone THEN
        DayStartResetDone := TRUE;
        IF CfgSampleCountResetMode = E_CycleSampleCountResetMode.ON_FIRST_START THEN
            SampleCountAutoResetPulse := TRUE;
        END_IF;
    END_IF;
END_IF;

// (c) ON_SAFETY_REARM — rearmement de la chaine AU (contacteur puissance reengage).
IF (CfgSampleCountResetMode = E_CycleSampleCountResetMode.ON_SAFETY_REARM)
   AND SafetyRearmedEdge.Q THEN
    SampleCountAutoResetPulse := TRUE;
END_IF;

// (a) NEVER (defaut) : aucune RAZ automatique — seul le bouton IHM remet le journalier a zero.
// 🔒 La RAZ ci-dessous n'ecrit QUE SampleCount : le totalisateur n'est jamais dans ce chemin.
// ⚠️ Ordre intra-scan : cette region precede le CASE du Grafcet. Si une RAZ tombe sur le scan ou
//    l'etape de fin de cycle s'execute, le journalier finit a 1 (remise a zero puis comptage de
//    la depose en cours) : rien ne se perd.
IF ResetSampleCountEdge.Q OR SampleCountAutoResetPulse THEN
    SampleCount := 0;
END_IF;
{endregion}

{region "§2 Gate securite & Bascule Mode"}
// 🔧 T358 — LECTURE DE LA CONSIGNE DE FORCAGE (une seule fois, en tete de §2).
// La consigne est un ARGUMENT : le FB ne l'ecrit JAMAIS (aucun producteur concurrent
// du champ IHM). Le FB signale seulement qu'une consigne etait PRESENTE ce scan
// (StepForceTgtTaken) : PRG_03 l'acquitte en la ramenant a sa sentinelle, par
// COMPARE-ET-EFFACE (il n'efface que si le champ porte encore la valeur lue ici).
// Sans acquittement, la meme valeur serait rejouee a chaque scan (boucle) ; avec lui,
// la MEME valeur redevient immediatement jouable, et une ecriture d'operateur arrivee
// pendant le corps du FB n'est jamais perdue (elle sera traitee au scan suivant).
StepForceConsigne := StepForceTgt;
StepForceTgtTaken := (StepForceTgt <> CST_StepForceNone);

// 🛑 1bis. ABANDON & RESET EXPLICITES (Priorité absolue, même hors mode ou en pause)
IF AbortEdge.Q THEN
    State := E_AutoCycleStep.AX0_REPOS;
    WaitingResume := FALSE;
    PausedState := E_AutoCycleStep.AX0_REPOS;
    StepForceConsigne := CST_StepForceNone;   // T358 : un abandon neutralise la consigne du meme scan
END_IF;

// 🔧 1ter. FORCAGE DE STEP — DEPLACE APRES LA PORTE DE SECURITE (§2bis, plus bas).
//    T358 : le mecanisme a deux temps (preparation puis confirmation par Start au
//    joystick neutre) et ses six gardes de contexte ont ete RETIRES. La tracabilite
//    complete des gardes retirees et de leur role d'origine est portee par
//    DOC/WFLOW/CONTRACTS/NOTE_APPLICATION_T358_FORCESTEP_SANS_GARDE.md.

IF ResetEdge.Q THEN
    StepForceConsigne := CST_StepForceNone;   // T358 : un acquittement neutralise la consigne du meme scan
    PausedState := E_AutoCycleStep.AX0_REPOS;
    SavedState := E_AutoCycleStep.AX0_REPOS;
    BottomTouched := FALSE;
    BottomStopByKobold := FALSE;
    BottomStopBySetpoint := FALSE;
    BottomStopSource := '';
    StopPositionCaptured := FALSE;
    KoboldImmersionQualified := FALSE;
    AutoDiveM2Step5TrialLatched := FALSE;
    AutoDiveM1Step4M2Step5Active := FALSE;
    IF State = E_AutoCycleStep.AX_STAB THEN
        State := E_AutoCycleStep.AX0_REPOS;
    END_IF;
END_IF;

// 🛑 2. GATES DE SÉCURITÉ ET NEUTRALISATION
// Le mode SEMI_AUTO peut être sélectionné sous AU/défaut (FB_Modes), mais le cycle
// ne tourne JAMAIS sans puissance (PowerContactorEngaged) ni avec un codeur défaillant
// (EncoderFaultPresent) — les données de position invalides rendraient le Grafcet erroné.
// Reprise explicite depuis AX_STAB : les sorties restent neutres jusqu'a un
// nouveau geste operateur, aucune remise en mouvement automatique.
IF ResumeAfterFaultEdge.Q AND ResumeAfterFaultAvailable AND NOT ResetEdge.Q THEN
    PausedState := CycleStepAtError;
    State := CycleStepAtError;
    WaitingResume := TRUE;
END_IF;

IF NOT Enable OR NOT PowerContactorEngaged OR EncoderFaultPresent THEN
    // 🔧 T358 : une consigne de forcage ecrite alors que le cycle est INACTIF est
    //    ECARTEE — motif publie, et la consigne est acquittee par PRG_03 sur
    //    StepForceTgtTaken. Elle n'est JAMAIS honoree plus tard a la reactivation du
    //    cycle : ce serait un saut d'etape sans geste nouveau.
    IF StepForceConsigne <> CST_StepForceNone THEN
        StepForceConsigne := CST_StepForceNone;
        ForceStepRejected := TRUE;
        ForceStepResult := 'Forcage ecarte : cycle inactif (mode, securite ou codeur).';
    END_IF;
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

    // Si on quitte le semi-auto alors qu'un cycle de MOUVEMENT était en cours (AX2 à AX15), on mémorise pour la pause.
    // Les étapes de repos (AX0) et d'initialisation (AX1) ne sont PAS mises en pause -> retour direct à AX0.
    IF (State <> E_AutoCycleStep.AX0_REPOS)
       AND (State <> E_AutoCycleStep.AX1_INIT)
       AND (State <> E_AutoCycleStep.AX18_DONE_SYNC)
       AND (State <> E_AutoCycleStep.AX_STAB) THEN
        PausedState := State;
        WaitingResume := TRUE;
    ELSE
        WaitingResume := FALSE;
        PausedState := E_AutoCycleStep.AX0_REPOS;
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
        OperatorAction := 'Cycle non autorise : defaut codeur a acquitter.';
    ELSE
        OperatorAction := 'Passer en mode Semi-Auto et engager la securite pour activer le cycle.';
    END_IF;
    ExpectedAxis := E_OperatorAxis.NONE;
    ExpectedDirection := 0;
    WaitingForOperator := FALSE;
    WaitingForProcess := FALSE;
    RequestActive := FALSE;
    AutoDiveM1Step4M2Step5Active := FALSE;
    RETURN;
END_IF;

// 🔧 2bis. FORCAGE DE STEP — T358 (mise en service / derogation)
// 🎯 Une consigne, un scan : l'operateur ecrit l'etape ciblee dans StepForceTgt (champ
//    IHM NON persiste, sentinelle -1). Le FB la consomme et remplace l'etape courante ;
//    PRG_03 l'acquitte sur StepForceTgtTaken. La meme valeur est donc immediatement
//    re-jouable, et aucun rejeu en boucle n'est possible.
// ⚠️ PLACE VOLONTAIRE — apres la porte §2 (Enable / AU / codeur) et avant le repli
//    defaut ErrorEdge : un defaut LIVE dont le front tombe sur le meme scan garde la
//    priorite (repli AX_STAB), mais un defaut DEJA LATCHE ne bloque plus le forcage
//    (decision exploitant 2026-09-21, risque assume et trace en note d'application).
// ⚠️ AUCUNE garde de contexte : ni mode, ni joystick, ni arret mecanique des treuils,
//    ni immersion Kobold, ni contexte fond. La SEULE validation restante est la plage
//    des valeurs de E_AutoCycleStep [0..23] ; hors plage = rejet, aucune ecriture d'etape.
// ⚠️ Le scan du forcage n'emet AUCUNE commande : demandes ramenees a zero et CASE
//    inhibe (StateExecutionInhibit) — l'etape ciblee s'execute au scan suivant, soit
//    un cycle de tache (10 ms). Un forcage annule aussi une attente de reprise en
//    cours, sinon le saut resterait gele sans effet.
IF StepForceConsigne <> CST_StepForceNone THEN
    ForceStepCandidateValid := FALSE;
    IF (StepForceConsigne >= 0) AND (StepForceConsigne <= CST_StepForceMax) THEN
        CASE StepForceConsigne OF
            0:  ForceStepCandidate := E_AutoCycleStep.AX0_REPOS;             ForceStepCandidateValid := TRUE;
            1:  ForceStepCandidate := E_AutoCycleStep.AX1_INIT;              ForceStepCandidateValid := TRUE;
            2:  ForceStepCandidate := E_AutoCycleStep.AX2_TRANSLATE_P1;      ForceStepCandidateValid := TRUE;
            3:  ForceStepCandidate := E_AutoCycleStep.AX3_OPEN_BUCKET;       ForceStepCandidateValid := TRUE;
            4:  ForceStepCandidate := E_AutoCycleStep.AX4_DESCEND_DIVING;    ForceStepCandidateValid := TRUE;
            5:  ForceStepCandidate := E_AutoCycleStep.AX5_KOBOLD_INIT;       ForceStepCandidateValid := TRUE;
            6:  ForceStepCandidate := E_AutoCycleStep.AX6_SEARCH_IMMERSION;  ForceStepCandidateValid := TRUE;
            7:  ForceStepCandidate := E_AutoCycleStep.AX7_SEARCH_BOTTOM;     ForceStepCandidateValid := TRUE;
            8:  ForceStepCandidate := E_AutoCycleStep.AX8_BOTTOM_CONFIRMED;  ForceStepCandidateValid := TRUE;
            9:  ForceStepCandidate := E_AutoCycleStep.AX9_RAISE_OFF_BOTTOM;  ForceStepCandidateValid := TRUE;
            10: ForceStepCandidate := E_AutoCycleStep.AX10_CLOSE_BUCKET;     ForceStepCandidateValid := TRUE;
            11: ForceStepCandidate := E_AutoCycleStep.AX11_CTRL_ASCENT;      ForceStepCandidateValid := TRUE;
            12: ForceStepCandidate := E_AutoCycleStep.AX12_LOADED_ASCENT;    ForceStepCandidateValid := TRUE;
            13: ForceStepCandidate := E_AutoCycleStep.AX13_DRAIN_PAUSE;      ForceStepCandidateValid := TRUE;
            14: ForceStepCandidate := E_AutoCycleStep.AX14_TRANSLATE_DUMP;   ForceStepCandidateValid := TRUE;
            15: ForceStepCandidate := E_AutoCycleStep.AX15A_DUMP_ARRIVE;     ForceStepCandidateValid := TRUE;
            16: ForceStepCandidate := E_AutoCycleStep.AX15B_DUMP_OPEN;       ForceStepCandidateValid := TRUE;
            17: ForceStepCandidate := E_AutoCycleStep.AX15C_DUMP_REPOSITION; ForceStepCandidateValid := TRUE;
            18: ForceStepCandidate := E_AutoCycleStep.AX18_DONE_SYNC;        ForceStepCandidateValid := TRUE;
            19: ForceStepCandidate := E_AutoCycleStep.AX_STAB;               ForceStepCandidateValid := TRUE;
            20: ForceStepCandidate := E_AutoCycleStep.AX_DIVING_RETRY;       ForceStepCandidateValid := TRUE;
            21: ForceStepCandidate := E_AutoCycleStep.AX3_WAIT_DIVE_START;   ForceStepCandidateValid := TRUE;
            22: ForceStepCandidate := E_AutoCycleStep.AX10B_RACCORDEMENT_P1; ForceStepCandidateValid := TRUE;
            23: ForceStepCandidate := E_AutoCycleStep.AX15D_DUMP_BUCKET_JOG;  ForceStepCandidateValid := TRUE;
        END_CASE;
    END_IF;

    IF ForceStepCandidateValid THEN
        // T345-L2 : un forcage vers AX15A est une nouvelle entree logique, meme si
        // l'etat courant vaut deja AX15A. Un neutre memorise avant le forcage ne doit
        // jamais autoriser le push deja actif au scan d'execution suivant.
        SeenNeutralAfterArrival := SEL(
            ForceStepCandidate = E_AutoCycleStep.AX15A_DUMP_ARRIVE,
            SeenNeutralAfterArrival,
            FALSE);
        State := ForceStepCandidate;
        StateExecutionInhibit := TRUE;   // CASE non execute sur ce scan : saut effectif au scan suivant
        PausedState := E_AutoCycleStep.AX0_REPOS;
        WaitingResume := FALSE;          // un forcage annule l'attente de reprise (sinon le saut resterait gele)
        CycleStep := ForceStepCandidate; // l'IHM affiche l'etape ciblee des le scan du forcage
        CycleStateStr := 'Forcage de step (mise en service) : etape ciblee chargee';
        // Scan sans commande : aucune demande d'actionneur n'est publiee.
        WinchM1Cmd.RunRequest := FALSE; WinchM1Cmd.ReqAscent := FALSE; WinchM1Cmd.ReqDescend := FALSE; WinchM1Cmd.StepTgt := 0;
        WinchM2Cmd.RunRequest := FALSE; WinchM2Cmd.ReqAscent := FALSE; WinchM2Cmd.ReqDescend := FALSE; WinchM2Cmd.StepTgt := 0;
        TranslationCmd.ReqStart := FALSE; TranslationCmd.PositionTgt := 0;
        BucketCmd.ReqOpen := FALSE; BucketCmd.ReqClose := FALSE; BucketCmd.ReqKoboldMeasureEnable := FALSE;
        ForceStepAccepted := TRUE;
        ForceStepResult := '';           // une consigne appliquee efface le motif de rejet precedent
    ELSE
        ForceStepRejected := TRUE;
        ForceStepResult := 'Forcage refuse : cible hors plage E_AutoCycleStep (0..23).';
    END_IF;
    // La consigne n'est PAS ecrite par le FB : elle est acquittee par PRG_03 sur
    // StepForceTgtTaken (invariant verifie par le gate G517).
END_IF;

Ready := Enable AND NOT Fault.Latched;

// 🛡️ Gate continu homme-mort : le mouvement n'est autorisé que si le manche est
// défléchi (JoystickDeflected) ET l'homme-mort est armé (DeadmanArmed). Chaque
// commande de mouvement est gatée par ce permis à chaque scan (pas seulement au
// démarrage). Le séquenceur (transitions X0→X13) reste piloté par JoystickDeflected.
CycleMotionPermit := JoystickDeflected AND DeadmanArmed;
TranslationP1Permit := DeadmanArmed AND JoystickRight AND NOT JoystickPush AND NOT JoystickPull;
TranslationTremiePermit := DeadmanArmed AND JoystickLeft AND NOT JoystickPush AND NOT JoystickPull;
JoystickPushOnly := JoystickPush AND NOT (JoystickLeft OR JoystickRight);

// Au retour en Semi-Auto, si une étape était en cours, on exige une reprise consciente
// 🔒 T358 : cette attente est INDEPENDANTE du forcage de step. Elle est ecrite par la
//    bascule de mode (§2) et par la reprise apres defaut, et consommee ici : elle est
//    conservee telle quelle (le forcage ne passe plus par ce chemin).
IF WaitingResume AND NOT StateExecutionInhibit THEN
    // 🔒 Sécurité anti-redémarrage automatique (AF-04 §4.1) : reprise sur StartCycle OU Homme-Mort
    IF AbortEdge.Q THEN
        State := E_AutoCycleStep.AX0_REPOS;
        WaitingResume := FALSE;
        PausedState := E_AutoCycleStep.AX0_REPOS;
    ELSIF StartEdge.Q OR DeadmanArmedEdge.Q THEN
        State := PausedState;   // reprise consciente : restaure l'étape mémorisée
        WaitingResume := FALSE;
    ELSE
        // Hold : neutralise toute demande de mouvement et affiche l'attente.
        WinchM1Cmd.RunRequest := FALSE; WinchM1Cmd.ReqAscent := FALSE; WinchM1Cmd.ReqDescend := FALSE; WinchM1Cmd.StepTgt := 0;
        WinchM2Cmd.RunRequest := FALSE; WinchM2Cmd.ReqAscent := FALSE; WinchM2Cmd.ReqDescend := FALSE; WinchM2Cmd.StepTgt := 0;
        TranslationCmd.ReqStart := FALSE; TranslationCmd.PositionTgt := 0;
        BucketCmd.ReqOpen := FALSE; BucketCmd.ReqClose := FALSE; BucketCmd.ReqKoboldMeasureEnable := FALSE;
        CycleStep := PausedState;
        CycleStateStr := 'Cycle en pause : reprise requise (StartCycle ou Homme-Mort)';
        Lifecycle.Busy := FALSE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.BUTTON;
        ExpectedDirection := 0;
        WaitingForOperator := TRUE;
        WaitingForProcess := FALSE;
        OperatorActionId := 16#0400;
        OperatorAction := 'Reprendre (Start) ou Abandonner (Abort).';
        RequestActive := FALSE;
    END_IF;
END_IF;

// 🧊 R9 — capture l'étape spécifique AVANT la bascule vers AX_STAB
IF ErrorEdge.Q THEN
    CycleStepAtError := State;
    M1SpeedStepAtFault := M1_SpeedStepApplied;
    M2SpeedStepAtFault := M2_SpeedStepApplied;
    State := E_AutoCycleStep.AX_STAB;
    WaitingResume := FALSE;   // un défaut abroge la reprise consciente : repli AX_STAB
END_IF;

// GT-dive-retry (GEL Q11) : reprise de plongee (PAS un defaut latche). Prioritaire
// apres le repli defaut : une vraie erreur (ErrorEdge) l'emporte.
IF DivingRetryTrig AND (State <> E_AutoCycleStep.AX_STAB) THEN
    AutoDiveM2Step5TrialLatched := FALSE;
    State := E_AutoCycleStep.AX_DIVING_RETRY;
END_IF;

// SEMI_AUTO : FB_CycleSemiAuto est le SEUL producteur des demandes benne. Les champs

// assistants (DiveSearch/ExtractionAssist) sont inactifs en cycle automatique
// -> valeurs neutres déterministes (identiques à la branche SEMI_AUTO de PRG_03).
BucketCmd.DescendPermitDiveBucketOpen := TRUE;
BucketCmd.ExtractionControlActive := FALSE;
BucketCmd.MinStepDown := 0;
BucketCmd.ReqHoldAscentP1AfterClose := FALSE;
{endregion}

{region "§3 Machine etat cycle automatique"}
// 🔁 2. LOGIQUE DU SÉQUENCEUR (Machine d'état) — CASE sur enum unique (R1)
// Pendant une reprise consciente (WaitingResume), le séquenceur est gelé :
// l'étape mémorisée ne s'exécute pas tant que StartCycle n'a pas été appuyé.
IF NOT WaitingResume AND NOT StateExecutionInhibit THEN
CASE State OF

    E_AutoCycleStep.AX0_REPOS:
        CycleStep := E_AutoCycleStep.AX0_REPOS;
        CycleStateStr := 'AX0 - Verification coherence systeme';
        StopPositionCaptured := FALSE;
        KoboldImmersionQualified := FALSE;
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
        OperatorAction := 'AX0 - Demarrer le cycle (bouton IHM ou homme-mort).';
        SampleCountDone := FALSE;   // F2: réarmement du front de comptage à chaque entrée en X0
        BottomTouched   := FALSE;   // info fond touche effacee au repos
        BottomStopByKobold := FALSE;
        BottomStopBySetpoint := FALSE;
        BottomStopSource := '';
        AutoDiveM2Step5TrialLatched := FALSE;
        AutoDiveM1Step4M2Step5Active := FALSE;

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
        // FB_CycleMachineHoming). Conditions : codeurs M1/M2 references, aucun defaut
        // latche, et posture de depart OK (InitPositionOk : chariot M3 PAS a droite de P1
        // + treuil M1 au FDC logiciel haut + benne qualifiee IsClosed ou IsOpen ; positionnement fin P1 = AX2).
        InitConditionsOk := HomedM1 AND HomedM2 AND NOT Fault.Latched AND InitPositionOk;
        IF InitConditionsOk THEN
            CycleStateStr := 'AX1 - Conditions initiales OK';
            ExpectedAxis := E_OperatorAxis.NONE;
            WaitingForOperator := FALSE;
            WaitingForProcess := TRUE;
            OperatorActionId := 0;
            OperatorAction := '';
            State := E_AutoCycleStep.AX2_TRANSLATE_P1;   // franchie sans mouvement
        ELSIF NOT (HomedM1 AND HomedM2) THEN
            CycleStateStr := 'AX1 - Codeurs M1/M2 non references';
            ExpectedAxis := E_OperatorAxis.BUTTON;
            WaitingForOperator := TRUE;
            WaitingForProcess := FALSE;
            OperatorActionId := 16#0401;
            OperatorAction := 'AX1 - Machine non referencee : referencer codeurs M1/M2 et benne.';
        ELSIF Fault.Latched THEN
            CycleStateStr := 'AX1 - Defaut cycle present';
            ExpectedAxis := E_OperatorAxis.BUTTON;
            WaitingForOperator := TRUE;
            WaitingForProcess := FALSE;
            OperatorActionId := 16#0401;
            OperatorAction := 'AX1 - Defaut cycle actif : acquitter avec Reset.';
        ELSIF NOT InitPositionOk THEN
            CycleStateStr := 'AX1 - Posture depart incorrecte (M3, FDC haut M1 ou benne)';
            ExpectedAxis := E_OperatorAxis.BUTTON;
            WaitingForOperator := TRUE;
            WaitingForProcess := FALSE;
            OperatorActionId := 16#0401;
            OperatorAction := 'AX1 - Amener M1 au FDC haut et qualifier la benne.';
        ELSE
            CycleStateStr := 'AX1 - Conditions initiales non remplies';
            ExpectedAxis := E_OperatorAxis.BUTTON;
            WaitingForOperator := TRUE;
            WaitingForProcess := FALSE;
            OperatorActionId := 16#0401;
            OperatorAction := 'AX1 - Verifier les conditions de depart du cycle.';
        END_IF;

    E_AutoCycleStep.AX2_TRANSLATE_P1:
        CycleStep := E_AutoCycleStep.AX2_TRANSLATE_P1;
        CycleStateStr := 'AX2 - Mise en position P1 (translation)';
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
        TranslationCmd.PositionTgt := 3;          // AX2 : jog bidirectionnel, cible d'arrêt P1

        IF Translation_At_P1 THEN
            // P1 est toujours qualifie par le retour stable M3 et l'arrêt physique.
            // Pas de memorisation qui masquerait une perte capteur : si l'operateur
            // maintient Y- avec homme-mort, il enchaine directement AX3 puis AX4.
            ExpectedAxis := E_OperatorAxis.JOYSTICK_Y;
            ExpectedDirection := -1;
            WaitingForOperator := NOT (DeadmanArmed AND JoystickPushOnly);
            WaitingForProcess := NOT TranslationStopTimer.Q;
            OperatorActionId := 16#0402;
            OperatorAction := 'AX2 - P1 atteint : pousser pour ouvrir la benne.';
            TranslationCmd.ReqStart := FALSE;
            TranslationCmd.PositionTgt := 3;
            IF TranslationStopTimer.Q AND DeadmanArmed AND JoystickPushOnly THEN
                State := E_AutoCycleStep.AX3_OPEN_BUCKET;
            END_IF;
        ELSE
            // AX2 accepte les deux sens ; la cible effective suit le sens du joystick.
            // Si Maintenance=1 et P1=0, cela permet de se dégager d'un dépassement.
            ExpectedDirection := 0;
            WaitingForOperator := NOT JoystickDeflected;
            WaitingForProcess := JoystickDeflected;
            OperatorActionId := 16#0402;
            OperatorAction := 'AX2 - Pousser gauche/droite : arret automatique sur P1.';
            TranslationCmd.PositionTgt := 3;
            TranslationCmd.ReqStart := TranslationTremiePermit OR TranslationP1Permit;
        END_IF;

    E_AutoCycleStep.AX3_OPEN_BUCKET:
        CycleStep := E_AutoCycleStep.AX3_OPEN_BUCKET;
        CycleStateStr := 'AX3 - Ouverture benne';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_Y;
        ExpectedDirection := -1; // Sens principal attendu : pousser pour ouvrir
        WaitingForOperator := NOT (DeadmanArmed AND JoystickPush);
        WaitingForProcess := DeadmanArmed AND JoystickPush;
        OperatorActionId := 16#0403;
        OperatorAction := 'AX3 - Pousser pour ouvrir la benne (tirer pour refermer).';

        // X3 = etape benne seule : treuils explicitement neutralises (config treuil unique par etape).
        WinchM1Cmd.RunRequest := FALSE; WinchM1Cmd.ReqAscent := FALSE; WinchM1Cmd.ReqDescend := FALSE; WinchM1Cmd.StepTgt := 0;
        WinchM2Cmd.RunRequest := FALSE; WinchM2Cmd.ReqAscent := FALSE; WinchM2Cmd.ReqDescend := FALSE; WinchM2Cmd.StepTgt := 0;
        TranslationCmd.ReqStart := FALSE;
        TranslationCmd.PositionTgt := 0;

        // Pilotage benne 2 sens : pousse (Y-) -> ouvre, tire (Y+) -> ferme
        IF DeadmanArmed AND JoystickPush THEN
            BucketCmd.ReqOpen := TRUE; // Piloté via ReqDescend dans FB_Bucket
        ELSE
            BucketCmd.ReqOpen := FALSE;
        END_IF;

        // Benne ouverte atteinte : seul l'etat mecanique IsOpen autorise la transition.
        // Done seul est insuffisant (fin de manoeuvre sans preuve d'ouverture).
        IF Benne_IsOpen AND NOT Benne_Busy THEN
            BucketCmd.ReqOpen := FALSE;
            State := E_AutoCycleStep.AX3_WAIT_DIVE_START;
        END_IF;

    E_AutoCycleStep.AX3_WAIT_DIVE_START:
        CycleStep := E_AutoCycleStep.AX3_WAIT_DIVE_START;
        CycleStateStr := 'AX3 - Arret mecanique avant plongee';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_Y;
        ExpectedDirection := -1;
        WaitingForOperator := NOT (DeadmanArmed AND JoystickPush);
        WaitingForProcess := NOT DiveStartStopTimer.Q;
        OperatorActionId := 16#0403;
        OperatorAction := 'AX3 - Maintenir : attente arret M1/M2 avant plongee.';

        // Separation mecanique stricte : aucune demande pendant la retombee M2.
        WinchM1Cmd.RunRequest := FALSE; WinchM1Cmd.ReqAscent := FALSE; WinchM1Cmd.ReqDescend := FALSE; WinchM1Cmd.StepTgt := 0;
        WinchM2Cmd.RunRequest := FALSE; WinchM2Cmd.ReqAscent := FALSE; WinchM2Cmd.ReqDescend := FALSE; WinchM2Cmd.StepTgt := 0;
        BucketCmd.ReqOpen := FALSE; BucketCmd.ReqClose := FALSE;

        // Continuation normale uniquement si le geste n'a jamais ete interrompu et si
        // l'arret est confirme. Une perte d'homme-mort desarme FB_Joystick et exige son
        // nouveau front physique avant que DeadmanArmed puisse redevenir vrai.
        IF DiveStartStopTimer.Q AND DeadmanArmed AND JoystickPush THEN
            AutoDiveM2Step5TrialLatched := CfgAutoDiveM2Step5Trial;
            State := E_AutoCycleStep.AX4_DESCEND_DIVING;
        END_IF;

    (* ===================== DIVING (AX4..AX8 + AX_DIVING_RETRY) ===================== *)

    E_AutoCycleStep.AX4_DESCEND_DIVING:
        CycleStep := E_AutoCycleStep.AX4_DESCEND_DIVING;
        CycleStateStr := 'AX4 - Plongee couplee palier 4 jusqu a l altimetrie';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_Y;
        ExpectedDirection := -1;
        WaitingForOperator := NOT (DeadmanArmed AND JoystickPush);
        WaitingForProcess := DeadmanArmed AND JoystickPush;
        OperatorActionId := 16#0404;
        OperatorAction := 'AX4 - Maintenir la descente palier 4 (Kobold pas encore enclenche).';

        // M1 reste palier 4. M2 reste palier 4 nominal, ou palier 5 si l'essai
        // T291-A a ete capture avant AX4. Sequencement contacteurs conserve en aval.
        // Contacteur Kobold PAS enclenche a cette etape.
        WinchM1Cmd.RunRequest := DeadmanArmed AND JoystickPush;
        WinchM1Cmd.ReqAscent := FALSE; WinchM1Cmd.ReqDescend := TRUE;
        WinchM1Cmd.StepTgt  := CST_StepDive;
        WinchM2Cmd.RunRequest := DeadmanArmed AND JoystickPush;
        WinchM2Cmd.ReqAscent := FALSE; WinchM2Cmd.ReqDescend := TRUE;
        WinchM2Cmd.StepTgt  := DiveM2StepTgt;
        BucketCmd.ReqKoboldMeasureEnable := FALSE;

        // AT4 : altimetrie de lancement atteinte (M1 <= DiveStartMinEff).
        IF DeadmanArmed AND JoystickPush
           AND (M1_CablePosM <= DiveStartMinEff) THEN
            State := E_AutoCycleStep.AX5_KOBOLD_INIT;
        END_IF;

    E_AutoCycleStep.AX5_KOBOLD_INIT:
        CycleStep := E_AutoCycleStep.AX5_KOBOLD_INIT;
        CycleStateStr := 'AX5 - Activation contacteur Kobold au vol';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_Y;
        ExpectedDirection := -1;
        WaitingForOperator := NOT (DeadmanArmed AND JoystickPush);
        WaitingForProcess := DeadmanArmed AND JoystickPush;
        OperatorActionId := 16#0405;
        OperatorAction := 'AX5 - Maintenir la descente palier 4 : initialisation Kobold en cours.';

        // Descente palier 4 maintenue ; enclenche le contacteur Kobold et attend le retour.
        WinchM1Cmd.RunRequest := DeadmanArmed AND JoystickPush;
        WinchM1Cmd.ReqAscent := FALSE; WinchM1Cmd.ReqDescend := TRUE;
        WinchM1Cmd.StepTgt  := CST_StepDive;
        WinchM2Cmd.RunRequest := DeadmanArmed AND JoystickPush;
        WinchM2Cmd.ReqAscent := FALSE; WinchM2Cmd.ReqDescend := TRUE;
        WinchM2Cmd.StepTgt  := DiveM2StepTgt;
        BucketCmd.ReqKoboldMeasureEnable := (DepthStopMode <> E_CycleDepthStopMode.SETPOINT_ONLY)
                                             AND DeadmanArmed AND JoystickPush;

        // AT5 : alimentation capteur etablie -> recherche immersion.
        // Palier 4 M1/M2 non atteint = cause de defaut (instCauses[9]), pas un blocage
        // silencieux de la transition.
        // (echec init / joystick relache / palier <> 4 -> AX_DIVING_RETRY via GT-dive-retry §1)
        IF DeadmanArmed AND JoystickPush AND KoboldInitTimer.Q THEN
            State := E_AutoCycleStep.AX6_SEARCH_IMMERSION;
        END_IF;

    E_AutoCycleStep.AX6_SEARCH_IMMERSION:
        CycleStep := E_AutoCycleStep.AX6_SEARCH_IMMERSION;
        CycleStateStr := 'AX6 - Stabilisation mesure Kobold et immersion';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_Y;
        ExpectedDirection := -1;
        WaitingForOperator := NOT (DeadmanArmed AND JoystickPush);
        WaitingForProcess := DeadmanArmed AND JoystickPush;
        OperatorActionId := 16#0406;
        OperatorAction := 'AX6 - Maintenir : stabilisation signal Kobold (500ms).';

        WinchM1Cmd.RunRequest := DeadmanArmed AND JoystickPush;
        WinchM1Cmd.ReqAscent := FALSE; WinchM1Cmd.ReqDescend := TRUE;
        WinchM1Cmd.StepTgt  := CST_StepDive;
        WinchM2Cmd.RunRequest := DeadmanArmed AND JoystickPush;
        WinchM2Cmd.ReqAscent := FALSE; WinchM2Cmd.ReqDescend := TRUE;
        WinchM2Cmd.StepTgt  := DiveM2StepTgt;
        BucketCmd.ReqKoboldMeasureEnable := (DepthStopMode <> E_CycleDepthStopMode.SETPOINT_ONLY)
                                             AND DeadmanArmed AND JoystickPush;

        // AT6 : signal Kobold sous tension confirme haut (DI=1) pendant 500ms -> recherche du fond.
        IF DeadmanArmed AND JoystickPush
           AND (KoboldStabTimer.Q OR ((DepthStopMode <> E_CycleDepthStopMode.KOBOLD_ONLY)
                                     AND DepthSetpointReachedNow)) THEN
            IF KoboldStabTimer.Q THEN
                KoboldImmersionQualified := TRUE;
            END_IF;
            State := E_AutoCycleStep.AX7_SEARCH_BOTTOM;
        END_IF;

    E_AutoCycleStep.AX7_SEARCH_BOTTOM:
        CycleStep := E_AutoCycleStep.AX7_SEARCH_BOTTOM;
        CycleStateStr := 'AX7 - Recherche du fond (Kobold ou consigne)';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_Y;
        ExpectedDirection := -1;
        WaitingForOperator := NOT (DeadmanArmed AND JoystickPush);
        WaitingForProcess := DeadmanArmed AND JoystickPush;
        OperatorActionId := 16#0407;
        OperatorAction := 'AX7 - Maintenir la descente palier 4 sous l eau : detection du fond.';

        WinchM1Cmd.RunRequest := DeadmanArmed AND JoystickPush;
        WinchM1Cmd.ReqAscent := FALSE; WinchM1Cmd.ReqDescend := TRUE;
        WinchM1Cmd.StepTgt  := CST_StepDive;
        WinchM2Cmd.RunRequest := DeadmanArmed AND JoystickPush;
        WinchM2Cmd.ReqAscent := FALSE; WinchM2Cmd.ReqDescend := TRUE;
        WinchM2Cmd.StepTgt  := DiveM2StepTgt;
        BucketCmd.ReqKoboldMeasureEnable := (DepthStopMode <> E_CycleDepthStopMode.SETPOINT_ONLY)
                                             AND DeadmanArmed AND JoystickPush;

        // AT7 : DI basse stable apres immersion haute qualifiee = fond touche.
        IF DeadmanArmed AND JoystickPush
           AND ((DepthStopMode = E_CycleDepthStopMode.KOBOLD_ONLY
                 AND KoboldImmersionQualified AND KoboldBottomTimer.Q)
             OR (DepthStopMode = E_CycleDepthStopMode.SETPOINT_ONLY AND DepthStopBySetpoint)
             OR (DepthStopMode = E_CycleDepthStopMode.KOBOLD_OR_SETPOINT
                 AND ((KoboldImmersionQualified AND KoboldBottomTimer.Q) OR DepthStopBySetpoint))) THEN
            TouchPositionM1 := M1_CablePosM;
            TouchPositionM2 := M2_CablePosM;
            BottomTouched  := TRUE;   // variable d'info latchee (GEL AX8) - effacee a AX0 / AX_STAB / Reset
            BottomStopByKobold := KoboldImmersionQualified AND KoboldBottomTimer.Q;
            BottomStopBySetpoint := DepthStopBySetpoint AND NOT BottomStopByKobold;
            IF BottomStopBySetpoint THEN
                BottomStopSource := 'CONSIGNE PROFONDEUR';
            ELSE
                BottomStopSource := 'KOBOLD';
            END_IF;
            StopPositionCaptured := FALSE;
            State := E_AutoCycleStep.AX8_BOTTOM_CONFIRMED;
        END_IF;

    E_AutoCycleStep.AX8_BOTTOM_CONFIRMED:
        CycleStep := E_AutoCycleStep.AX8_BOTTOM_CONFIRMED;
        AutoDiveM2Step5TrialLatched := FALSE;
        CycleStateStr := CONCAT('AX8 - Fond confirme par ', BottomStopSource);
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.NONE;
        ExpectedDirection := 0;
        WaitingForOperator := FALSE;
        WaitingForProcess := TRUE;
        OperatorActionId := 16#0408;
        OperatorAction := CONCAT('AX8 - Fond confirme par ', BottomStopSource);

        // L'inertie peut encore derouler les cables apres le front fond. La position
        // de reference pour AX9 est donc la position MECANIQUEMENT STABILISEE,
        // commune aux chemins Kobold et consigne, et non la position du front.
        IF DiveStartStopped AND NOT StopPositionCaptured THEN
            StopPositionM1 := M1_CablePosM;
            StopPositionM2 := M2_CablePosM;
            IF LimitLegalDepthM < -0.01 THEN
                RaiseTargetM1 := MAX(StopPositionM1 + RaiseOffBottomEff, LimitLegalDepthM + RaiseOffBottomEff);
                RaiseTargetM2 := MAX(StopPositionM2 + RaiseOffBottomEff, LimitLegalDepthM + RaiseOffBottomEff);
            ELSE
                RaiseTargetM1 := StopPositionM1 + RaiseOffBottomEff;
                RaiseTargetM2 := StopPositionM2 + RaiseOffBottomEff;
            END_IF;
            StopPositionCaptured := TRUE;
        END_IF;

        // Coupure INSTANTANEE de toutes les commandes treuils + Kobold coupe.
        WinchM1Cmd.RunRequest := FALSE; WinchM1Cmd.ReqAscent := FALSE; WinchM1Cmd.ReqDescend := FALSE; WinchM1Cmd.StepTgt := 0;
        WinchM2Cmd.RunRequest := FALSE; WinchM2Cmd.ReqAscent := FALSE; WinchM2Cmd.ReqDescend := FALSE; WinchM2Cmd.StepTgt := 0;
        BucketCmd.ReqKoboldMeasureEnable := FALSE;

        // Apres stabilisation a l arret (freins serres), 0 m signifie fermeture benne
        // immediate (AX10). Une valeur > 0 passe par AX9 pour decoller/retendre.
        IF BottomTouchStabTimer.Q AND DiveStartStopped AND StopPositionCaptured THEN
            IF RaiseOffBottomEff <= 0.0 THEN
                State := E_AutoCycleStep.AX10_CLOSE_BUCKET;
            ELSE
                State := E_AutoCycleStep.AX9_RAISE_OFF_BOTTOM;
            END_IF;
        END_IF;

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
        OperatorAction := 'AX retry - Remonter au FDC haut puis relancer la plongee.';

        // Remontee assistee palier lent, Kobold coupe.
        WinchM1Cmd.RunRequest := DeadmanArmed AND JoystickPull;
        WinchM1Cmd.ReqAscent := TRUE; WinchM1Cmd.ReqDescend := FALSE;
        WinchM1Cmd.StepTgt  := CST_StepSlow;
        WinchM2Cmd.RunRequest := DeadmanArmed AND JoystickPull;
        WinchM2Cmd.ReqAscent := TRUE; WinchM2Cmd.ReqDescend := FALSE;
        WinchM2Cmd.StepTgt  := CST_StepSlow;
        BucketCmd.ReqKoboldMeasureEnable := FALSE;

        // AT-retry : treuils revenus au FDC haut -> nouvelle tentative de plongee.
        IF JoystickDeflected AND WinchesAtTopWindow THEN
            WinchM1Cmd.RunRequest := FALSE;
            WinchM2Cmd.RunRequest := FALSE;
            State := E_AutoCycleStep.AX4_DESCEND_DIVING;
        END_IF;

    (* ===================== EXTRACTION (AX9..AX12) ===================== *)

    E_AutoCycleStep.AX9_RAISE_OFF_BOTTOM:
        CycleStep := E_AutoCycleStep.AX9_RAISE_OFF_BOTTOM;
        CycleStateStr := 'AX9 - Montee synchronisee : retendre les cables';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_Y;
        ExpectedDirection := 1;
        WaitingForOperator := NOT JoystickDeflected;
        WaitingForProcess := JoystickDeflected;
        OperatorActionId := 16#0409;
        OperatorAction := 'AX9 - Maintenir la montee synchronisee : retendre les cables.';

        // Palier 1 (doux). Selecteur couplage BOTH/M1/M2 = garde cote PRG_04 (GEL Q15),
        // le sequenceur commande toujours les deux treuils symetriquement.
        WinchM1Cmd.RunRequest := DeadmanArmed AND JoystickPull;
        WinchM1Cmd.ReqAscent := TRUE; WinchM1Cmd.ReqDescend := FALSE;
        WinchM1Cmd.StepTgt := CST_StepSlow;
        WinchM2Cmd.RunRequest := DeadmanArmed AND JoystickPull;
        WinchM2Cmd.ReqAscent := TRUE; WinchM2Cmd.ReqDescend := FALSE;
        WinchM2Cmd.StepTgt := CST_StepSlow;

        IF DeadmanArmed AND JoystickPull AND ExtractionStepDelayTimer.Q AND (M1_CablePosM >= RaiseTargetM1) AND (M2_CablePosM >= RaiseTargetM2) THEN
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
        OperatorAction := 'AX10 - Maintenir la commande : fermeture de la benne.';

        // Etape benne seule : les DEUX treuils explicitement neutralises.
        WinchM1Cmd.RunRequest := FALSE; WinchM1Cmd.ReqAscent := FALSE; WinchM1Cmd.ReqDescend := FALSE; WinchM1Cmd.StepTgt := 0;
        WinchM2Cmd.RunRequest := FALSE; WinchM2Cmd.ReqAscent := FALSE; WinchM2Cmd.ReqDescend := FALSE; WinchM2Cmd.StepTgt := 0;
        // Demande d'ouverture publiee a 0 par l'etape elle-meme : AX10 est atteignable
        // depuis un etat ou l'ouverture etait commandee (repli du vidage) et l'etape ne
        // doit jamais laisser coexister une ouverture et une fermeture benne.
        BucketCmd.ReqOpen := FALSE;
        BucketCmd.ReqClose := DeadmanArmed AND JoystickPull AND ExtractionStepDelayTimer.Q;
        // Arme le maintien avant la fermeture effective : FB_Bucket garde M2 sans trou de commande.
        BucketCmd.ReqHoldAscentP1AfterClose := BucketCmd.ReqClose;
        Ax10bFallbackStopActive := FALSE;

        IF DeadmanArmed AND JoystickPull AND Benne_CloseReached AND (Benne_IsClosed OR Benne_IsRoughlyClosed) THEN
            BucketCmd.ReqClose := FALSE;
            // M2 est deja maintenu a P1 par FB_Bucket ; AX10B prepare le transfert couple.
            State := E_AutoCycleStep.AX10B_RACCORDEMENT_P1;
        END_IF;

    E_AutoCycleStep.AX10B_RACCORDEMENT_P1:
        CycleStep := E_AutoCycleStep.AX10B_RACCORDEMENT_P1;
        CycleStateStr := 'AX10b - Raccordement P1 avant montee controlee';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_Y;
        ExpectedDirection := 1;
        WaitingForOperator := NOT (DeadmanArmed AND JoystickPull);
        WaitingForProcess := NOT ((M2_SpeedStepApplied = 1) AND M1FinalAscentStartReady)
                             AND NOT (Ax10bFallbackStopActive AND AscentStartStopTimer.Q);
        OperatorActionId := 16#040A;
        OperatorAction := 'AX10b - Maintenir le joystick tire : raccordement P1 en cours.';

        // M2 reste pilote par FB_Bucket pendant le raccordement. Aucun Both asymetrique :
        // les deux demandes programme ne sont publiees qu'au scan du transfert P1/P1.
        WinchM1Cmd.RunRequest := FALSE; WinchM1Cmd.ReqAscent := FALSE; WinchM1Cmd.ReqDescend := FALSE; WinchM1Cmd.StepTgt := 0;
        WinchM2Cmd.RunRequest := FALSE; WinchM2Cmd.ReqAscent := FALSE; WinchM2Cmd.ReqDescend := FALSE; WinchM2Cmd.StepTgt := 0;
        BucketCmd.ReqOpen := FALSE; BucketCmd.ReqClose := FALSE;
        BucketCmd.ReqHoldAscentP1AfterClose := DeadmanArmed AND JoystickPull AND NOT Ax10bFallbackStopActive;

        IF NOT Ax10bFallbackStopActive
           AND Ax10bHandoffWaitTimer.Q THEN
            // M1 non disponible dans la fenetre bornee : repli sur l'arret historique.
            Ax10bFallbackStopActive := TRUE;
            BucketCmd.ReqHoldAscentP1AfterClose := FALSE;
        ELSIF NOT Ax10bFallbackStopActive
              AND (M2_SpeedStepApplied = 1)
              AND M1FinalAscentStartReady
              AND DeadmanArmed AND JoystickPull THEN
            // Transfert atomique : M2 est encore tenu par la benne P1 ce scan ; M1/M2
            // recoivent simultanement P1, puis AX11 poursuit avec son plafond commun P1..P2.
            WinchM1Cmd.RunRequest := TRUE; WinchM1Cmd.ReqAscent := TRUE; WinchM1Cmd.ReqDescend := FALSE; WinchM1Cmd.StepTgt := 1;
            WinchM2Cmd.RunRequest := TRUE; WinchM2Cmd.ReqAscent := TRUE; WinchM2Cmd.ReqDescend := FALSE; WinchM2Cmd.StepTgt := 1;
            CtrlAscentStartM1 := M1_CablePosM;
            CtrlAscentStartM2 := M2_CablePosM;
            IF CfgCtrlAscentDistanceM <= 0.0 THEN
                State := E_AutoCycleStep.AX12_LOADED_ASCENT;
            ELSE
                State := E_AutoCycleStep.AX11_CTRL_ASCENT;
            END_IF;
        ELSIF Ax10bFallbackStopActive AND AscentStartStopTimer.Q AND DeadmanArmed AND JoystickPull THEN
            CtrlAscentStartM1 := M1_CablePosM;
            CtrlAscentStartM2 := M2_CablePosM;
            IF CfgCtrlAscentDistanceM <= 0.0 THEN
                State := E_AutoCycleStep.AX12_LOADED_ASCENT;
            ELSE
                State := E_AutoCycleStep.AX11_CTRL_ASCENT;
            END_IF;
        END_IF;

    E_AutoCycleStep.AX11_CTRL_ASCENT:
        CycleStep := E_AutoCycleStep.AX11_CTRL_ASCENT;
        CycleStateStr := 'AX11 - Montee controlee : surveillance visuelle M1/M2';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_Y;
        ExpectedDirection := 1;
        WaitingForOperator := NOT JoystickDeflected;
        WaitingForProcess := JoystickDeflected;
        OperatorActionId := 16#040B;
        OperatorAction := 'AX11 - Maintenir la montee : surveiller M1/M2.';

        // Palier max reglable IHM, borne [1..2] (defaut 1 / P1 ; P2 possible au besoin).
        WinchM1Cmd.RunRequest := DeadmanArmed AND JoystickPull;
        WinchM1Cmd.ReqAscent := TRUE; WinchM1Cmd.ReqDescend := FALSE;
        WinchM1Cmd.StepTgt  := CtrlAscentMaxStepEff;
        WinchM2Cmd.RunRequest := DeadmanArmed AND JoystickPull;
        WinchM2Cmd.ReqAscent := TRUE; WinchM2Cmd.ReqDescend := FALSE;
        WinchM2Cmd.StepTgt  := CtrlAscentMaxStepEff;

        IF (M1_CablePosM >= (CtrlAscentStartM1 + CtrlAscentDistEffM))
           AND (M2_CablePosM >= (CtrlAscentStartM2 + CtrlAscentDistEffM))
           AND NOT WinchSyncError THEN
            // Transition strictement sur la distance CFG (2 m par defaut)
            // et le synchronisme FB_WinchSync. Les commandes AX12 restent
            // protegees par homme-mort + joystick.
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
        OperatorAction := 'AX12 - Maintenir la montee en charge jusqu a la limite haute.';

        // Benne bien fermee -> palier 4 ; benne mal fermee (a peu pres) -> palier 1.
        // Pas de ralentissement 1 m avant la position top (montee franche).
        WinchM1Cmd.RunRequest := DeadmanArmed AND JoystickPull;
        WinchM1Cmd.ReqAscent := TRUE; WinchM1Cmd.ReqDescend := FALSE;
        WinchM1Cmd.StepTgt  := SEL(Benne_IsClosed, CST_StepSlow, CST_StepLoaded);
        WinchM2Cmd.RunRequest := DeadmanArmed AND JoystickPull;
        WinchM2Cmd.ReqAscent := TRUE; WinchM2Cmd.ReqDescend := FALSE;
        WinchM2Cmd.StepTgt  := SEL(Benne_IsClosed, CST_StepSlow, CST_StepLoaded);

        // Arrivee au FDC haut LOGICIEL = evenement procede, jamais une nouvelle
        // action operateur. PRG04 est l'unique producteur du fait de limite
        // (7,5 m nominal, geometrique pour M2) : G7 ne recalcule aucune cote.
        IF M1TopLimitReached OR M2TopLimitReached THEN
            WinchM1Cmd.RunRequest := FALSE;
            WinchM2Cmd.RunRequest := FALSE;
            State := E_AutoCycleStep.AX13_DRAIN_PAUSE;
        END_IF;

    (* ===================== DECHARGE (AX13..AX18) ===================== *)

    E_AutoCycleStep.AX13_DRAIN_PAUSE:
        CycleStep := E_AutoCycleStep.AX13_DRAIN_PAUSE;
        // ⏱️ Le message porte le temps RESTANT d'egouttage. AX13 est une ATTENTE TEMPORISEE :
        // l'operateur doit savoir combien de temps il attend encore (il peut couper court via
        // "passer egouttage", OperatorAction ci-dessous). Aucun chronometre nouveau : DrainTimeRemaining
        // (calcule en §1) est la source unique, deja publiee a l'IHM (DrainTimeElapsed_S, PRG_07:675).
        // Arrondi au SUPERIEUR en secondes, meme conversion que ce tag IHM : l'operateur ne lit jamais
        // 0 s tant que la tempo n'est pas reellement terminee. Le temps ECOULE du cycle n'est PAS
        // duplique ici : il est porte par le bandeau mode (FB_Hmi_BannerFormatter §1).
        // Pire cas : 'AX13 - Egouttage du godet : ' (28) + 4 chiffres (DrainTimeEff borne a 3600 s,
        // PRG_03:66) + 's restantes' (11) = 43 caracteres sur les 70 autorises par G408.
        DrainRemaining_S := DINT_TO_INT((TIME_TO_DINT(DrainTimeRemaining) + DINT#999) / DINT#1000);
        CycleStateStr := CONCAT('AX13 - Egouttage du godet : ',
                                CONCAT(INT_TO_STRING(DrainRemaining_S), 's restantes'));
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.NONE;
        ExpectedDirection := 0;
        WaitingForOperator := FALSE;
        WaitingForProcess := TRUE;
        OperatorActionId := 16#0409;
        OperatorAction := 'AX13 - Attendre la tempo ou appuyer sur "passer egouttage".';
        WinchM1Cmd.RunRequest := FALSE;
        WinchM2Cmd.RunRequest := FALSE;

        // Tempo d'egouttage armee/remise a zero en §1 (gate sur State = AX13, PT = DrainTimeEff).
        // Duree reglable IHM (CfgDrainTime) + bypass immediat (SkipDrainEdge).
        // La fin d'egouttage est une transition procede autonome. AX14 porte
        // ensuite l'attente operateur pour commander M3 vers la tremie.
        // Important aussi apres forcage : aucun geste joystick cache ne doit
        // maintenir AX13 une fois la temporisation terminee.
        IF DrainingTimer.Q OR SkipDrainEdge.Q THEN
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
        OperatorAction := 'AX14 - Maintenir la translation vers la tremie de dechargement.';

        TranslationCmd.PositionTgt := 1; // Trémie
        TranslationCmd.ReqStart := TranslationTremiePermit;

        IF Translation_At_Tremie THEN
            TranslationCmd.ReqStart := FALSE;
            TranslationCmd.PositionTgt := 0;
            WaitingForOperator := JoystickDeflected;
            WaitingForProcess := NOT JoystickDeflected;
            OperatorAction := 'AX14 - Tremie : relacher le joystick avant ouverture.';
            IF TranslationStopTimer.Q THEN
                // T345-L2 : entree normale AX15A = nouveau cycle d'armement du geste benne.
                SeenNeutralAfterArrival := FALSE;
                State := E_AutoCycleStep.AX15A_DUMP_ARRIVE;
            END_IF;
        END_IF;

    E_AutoCycleStep.AX15A_DUMP_ARRIVE:
        CycleStep := E_AutoCycleStep.AX15A_DUMP_ARRIVE;
        CycleStateStr := 'AX15a - Arrivee tremie : treuils arretes, attente ouverture';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_Y;
        ExpectedDirection := -1;
        WaitingForOperator := TRUE;
        WaitingForProcess := FALSE;
        OperatorActionId := 16#040B;
        OperatorAction := 'AX15a - Relacher le joystick avant ouverture.';

        // Config treuil UNIQUE : arret des deux treuils (aucune descente couplee ici).
        WinchM1Cmd.RunRequest := FALSE; WinchM1Cmd.ReqAscent := FALSE; WinchM1Cmd.ReqDescend := FALSE; WinchM1Cmd.StepTgt := 0;
        WinchM2Cmd.RunRequest := FALSE; WinchM2Cmd.ReqAscent := FALSE; WinchM2Cmd.ReqDescend := FALSE; WinchM2Cmd.StepTgt := 0;
        TranslationCmd.ReqStart := FALSE;
        TranslationCmd.PositionTgt := 0;

        // T345-L2 : vrai latch inter-scan. Le scan qui observe le neutre arme le
        // geste suivant, mais ne peut pas consommer ce meme armement. AX15B exige
        // donc toujours un push posterieur a au moins un scan neutre en AX15A.
        IF SeenNeutralAfterArrival THEN
            WaitingForOperator := NOT (DeadmanArmed AND JoystickPush);
            WaitingForProcess := DeadmanArmed AND JoystickPush;
            OperatorAction := 'AX15a - Pousser vers le bas pour ouvrir et vider.';
            IF DeadmanArmed AND JoystickPush THEN
                State := E_AutoCycleStep.AX15B_DUMP_OPEN;
            END_IF;
        ELSIF NOT JoystickDeflected THEN
            SeenNeutralAfterArrival := TRUE;
            OperatorAction := 'AX15a - Pousser vers le bas pour ouvrir et vider.';
        END_IF;

    E_AutoCycleStep.AX15B_DUMP_OPEN:
        CycleStep := E_AutoCycleStep.AX15B_DUMP_OPEN;
        CycleStateStr := 'AX15b - Vidage : ouverture benne, treuils arretes';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_Y;
        ExpectedDirection := -1;
        WaitingForOperator := NOT (DeadmanArmed AND JoystickPush);
        WaitingForProcess := DeadmanArmed AND JoystickPush;
        OperatorActionId := 16#040B;
        OperatorAction := 'AX15b - Pousser : vidage. Tirer : fermer sur place (micro-step).';

        // Config treuil UNIQUE : etape benne seule, les deux treuils neutralises
        // (plus de descente couplee M1+M2 simultanee a l'ouverture benne -> plus
        // d'ecart M1/M2 volontaire ni de faux SafeStop concordance contacteurs).
        WinchM1Cmd.RunRequest := FALSE; WinchM1Cmd.ReqAscent := FALSE; WinchM1Cmd.ReqDescend := FALSE; WinchM1Cmd.StepTgt := 0;
        WinchM2Cmd.RunRequest := FALSE; WinchM2Cmd.ReqAscent := FALSE; WinchM2Cmd.ReqDescend := FALSE; WinchM2Cmd.StepTgt := 0;
        TranslationCmd.ReqStart := FALSE;
        TranslationCmd.PositionTgt := 0;

        BucketCmd.ReqOpen := DeadmanArmed AND JoystickPush;

        // 🔄 T383 (amendement GEL 2026-09-22) : le tirer n'effectue PLUS de saut AX15B -> AX10
        // (saut arriere non declare, GEL ne le connait pas). Le tirer entre dans le micro-step
        // AX15D_DUMP_BUCKET_JOG qui permet d'ouvrir/refermer la benne SUR PLACE a la tremie, sans
        // quitter la phase de vidage et sans mouvement de treuil ni de translation. Retour AX15B
        // au relachement (centre mort) ; la fin de vidage reste AX18 (AT15B inchange). Aucune
        // echappatoire vers AX10 (decision exploitant arbitrage 3, confirmee par les 2 revues C4).
        IF DeadmanArmed AND JoystickPull THEN
            BucketCmd.ReqOpen := FALSE;
            State := E_AutoCycleStep.AX15D_DUMP_BUCKET_JOG;
        ELSIF RepositionRequest THEN
            State := E_AutoCycleStep.AX15C_DUMP_REPOSITION;
        ELSIF DeadmanArmed AND JoystickPush AND Benne_Done AND Benne_IsOpen THEN
            BucketCmd.ReqOpen := FALSE;
            State := E_AutoCycleStep.AX18_DONE_SYNC;
        END_IF;

    E_AutoCycleStep.AX15D_DUMP_BUCKET_JOG:
        CycleStep := E_AutoCycleStep.AX15D_DUMP_BUCKET_JOG;
        CycleStateStr := 'AX15d - Module benne a la tremie';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_Y;
        ExpectedDirection := -1;
        WaitingForOperator := NOT (DeadmanArmed AND (JoystickPush OR JoystickPull));
        WaitingForProcess := DeadmanArmed AND (JoystickPush OR JoystickPull);
        OperatorActionId := 16#040D;
        OperatorAction := 'AX15d - Pousser : ouvrir benne. Tirer : fermer. Relacher : retour.';

        // Module benne SUR PLACE a la tremie : treuils M1+M2 a 0, translation 0,
        // aucun mouvement de treuil. Le geste ouvre (ReqOpen), l'inverse ferme
        // (ReqClose), neutre = les deux FALSE (la benne se module sur place).
        WinchM1Cmd.RunRequest := FALSE; WinchM1Cmd.ReqAscent := FALSE; WinchM1Cmd.ReqDescend := FALSE; WinchM1Cmd.StepTgt := 0;
        WinchM2Cmd.RunRequest := FALSE; WinchM2Cmd.ReqAscent := FALSE; WinchM2Cmd.ReqDescend := FALSE; WinchM2Cmd.StepTgt := 0;
        TranslationCmd.ReqStart := FALSE;
        TranslationCmd.PositionTgt := 0;
        BucketCmd.ReqOpen := DeadmanArmed AND JoystickPush;
        BucketCmd.ReqClose := DeadmanArmed AND JoystickPull;

        // Sorties TOUTES declarees au GEL (amendement T383) :
        //  - retour au centre mort (relachement du manche) -> AX15B (reprendre le vidage)
        //  - Benne_Done AND Benne_IsOpen (contenu vide) -> AX18
        // La perte de l'homme-mort NE sort PAS d'AX15D : le gate §4 (Lifecycle.Busy AND NOT
        // CycleMotionPermit) neutralise les commandes benne/treuils en conservant l'etape
        // (doctrine identique a AX15B / AX10). Seul le relachement du manche ramene a AX15B.
        IF NOT JoystickDeflected THEN
            BucketCmd.ReqOpen := FALSE;
            BucketCmd.ReqClose := FALSE;
            State := E_AutoCycleStep.AX15B_DUMP_OPEN;
        ELSIF DeadmanArmed AND JoystickPush AND Benne_Done AND Benne_IsOpen THEN
            BucketCmd.ReqOpen := FALSE;
            BucketCmd.ReqClose := FALSE;
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
        OperatorAction := 'AX15c - Descente couplee M1+M2 ; relacher l option pour reprendre le vidage.';

        // Descente couplee M1+M2, palier lent, sous homme-mort. Commandes SYMETRIQUES
        // (meme sens, meme palier) -> FB_SyncDeviation actif, pas d'ecart volontaire.
        WinchM1Cmd.ReqAscent := FALSE; WinchM1Cmd.ReqDescend := TRUE;
        WinchM1Cmd.RunRequest := CycleMotionPermit;
        WinchM1Cmd.StepTgt := CST_StepSlow;
        WinchM2Cmd.ReqAscent := FALSE; WinchM2Cmd.ReqDescend := TRUE;
        WinchM2Cmd.RunRequest := CycleMotionPermit;
        WinchM2Cmd.StepTgt := CST_StepSlow;
        TranslationCmd.ReqStart := FALSE;
        TranslationCmd.PositionTgt := 0;

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
        WaitingForOperator := NOT (DeadmanArmed AND JoystickRight);
        WaitingForProcess := DeadmanArmed AND JoystickRight;
        OperatorActionId := 16#040D;
        OperatorAction := 'AX18 - Cycle termine. Aller en P1 (joystick a droite).';

        // Compteur de prélèvements (RETAIN) + durée du cycle — F2: cadré par front (1 seul par cycle)
        IF NOT SampleCountDone THEN
            SampleCount := SampleCount + 1;            // JOURNALIER (RAZ IHM/mode auto possible)
            SampleCountTotal := SampleCountTotal + 1;  // TOTALISATEUR : SEULE ecriture de toute l'application (gate G508)
            LastCycleDuration_Min := CurrentCycleElapsed_Min;  // fige la duree du cycle qui vient de s'achever
            LastCycleDuration_S   := CurrentCycleElapsed_S;
            SampleCountDone := TRUE;
        END_IF;

        // Rebouclage DIRECT sur AX2_TRANSLATE_P1 (GEL Q14) : la machine est deja
        // referencee, la passe suivante enchaine sur la translation P1 (pas de retour AX0).
        // Relance sur StartCycle OU FRONT joystick (geste franc) - pas sur simple maintien,
        // pour que AX18 (Lifecycle.Done + msg) soit reellement observable / tracable.
        IF StartEdge.Q OR (DeadmanArmed AND JoystickRight) THEN
            SampleCountDone := FALSE;
            Lifecycle.Done := FALSE;
            State := E_AutoCycleStep.AX2_TRANSLATE_P1;
        END_IF;

    E_AutoCycleStep.AX_STAB:
        CycleStep := E_AutoCycleStep.AX_STAB;
        CycleStateStr := 'STABILISATION - defaut cycle';
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
        IF ResumeAfterFaultAvailable THEN
            OperatorAction := 'AX_STAB : cause disparue - Reprendre ou Abandonner.';
        ELSIF Translation_PosMaintenance AND NOT Translation_PosP1 THEN
            // Reprise boot : Maintenance active + P1 retombe = chariot déjà au-delà
            // de P1. Ne jamais proposer de continuer à droite vers Maintenance.
            // Le retour gauche traverse P1 ; le front P1 réarme AtP1 et la branche
            // précédente termine AX2 normalement.
            ExpectedDirection := 1;
            WaitingForOperator := NOT JoystickDeflected;
            WaitingForProcess := JoystickDeflected;
            OperatorActionId := 16#0402;
            OperatorAction := 'AX2 - M3 au-dela de P1 : pousser vers tremie (gauche) jusqu a P1.';
            TranslationCmd.PositionTgt := 1;      // sens retour vers Trémie
            TranslationCmd.ReqStart := TranslationTremiePermit;
        ELSE
            OperatorAction := 'AX_STAB : lever la cause puis Reprendre/Abandonner.';
        END_IF;

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

RequestActive := WinchM1Cmd.RunRequest OR WinchM2Cmd.RunRequest OR TranslationCmd.ReqStart OR BucketCmd.ReqOpen OR BucketCmd.ReqClose OR BucketCmd.ReqHoldAscentP1AfterClose OR BucketCmd.ReqKoboldMeasureEnable; // Somme logique complete des demandes (contacteur Kobold inclus)
{endregion}

END_FUNCTION_BLOCK
