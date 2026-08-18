(* =======================================================================
   🛡️ FB_Safety_EmergencyManagement — Composite & Façade Publique
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Façade publique, instance unique ; câblage interne Logic/Output & exposition des bus d'état
   🔒 Polarité : MaintainA/B_RQ en maintien (TRUE = voie saine)
   🔌 Architecture : Composition interne Logic/Output
   📄 Doc métier : DOC/AF/AF_Partie-01_Analyse_Fonctionnelle_v2.0.md
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
    // === ETATS IEC & SYNOPTIQUE ===
    Ready                   : BOOL; // <-- [STAT] FB pret a fonctionner
    Busy                    : BOOL; // <-- [STAT] Sequence ou lockout en cours
    Done                    : BOOL; // <-- [STAT] Contacteur puissance confirme engage

    // === DIAGNOSTIQUES & ERREURS ===
    Error                   : BOOL; // <-- [DIAG] Synthese defaut (TRUE = defaut actif)
    ErrorId                 : WORD; // <-- [DIAG] Bitfield erreurs (bit0:Redundancy, bit1:Arming, bit3:Startup)

    // === SORTIES PHYSIQUES (FAIL-SAFE) ===
    MaintainA_RQ            : BOOL; // <-- [ACT]  Sortie pilotage canal A (TRUE = voie maintenue)
    MaintainB_RQ            : BOOL; // <-- [ACT]  Sortie pilotage canal B (TRUE = voie maintenue)
    ArmPulse_RQ             : BOOL; // <-- [ACT]  Impulsion rearmement physique (1s)

    // === BUS D'ETAT & DIAGNOSTIC ===
    State                   : ST_Safety_Emergency_State; // <-- [STAT] Bus d'etat public
    Diag                    : ST_Safety_Emergency_Diag;  // <-- [DIAG] Bus de diagnostic public

    // === DIAGNOSTICS SCALAIRES (RETROCOMPATIBILITE) ===
    ArmingSeqStep                : INT;  // <-- [DIAG] Etape sequence rearmement (0=IDLE..6=Confirm)
    RedundancyTestFailed         : BOOL; // <-- [DIAG] Defaut auto-test canal A ou B reste colle
    EmergencyArmingFailed        : BOOL; // <-- [DIAG] Defaut rearmement contacteur puissance (timeout 2s)
    EmergencyArmingLockoutActive : BOOL; // <-- [DIAG] Verrouillage temporel 5s entre essais
END_VAR
VAR
    // === SOUS-INSTANCES FB ===
    Logic                   : FB_Safety_EmergencyManagementLogic;  // * [INST] Machinerie d'etat et decision AU
    Output                  : FB_Safety_EmergencyManagementOutput; // * [INST] Projection fail-safe vers sorties physiques
END_VAR

// === IMPLEMENTATION ===

// 🛑 1. Appels des instances internes
Logic(
    Enable := Enable,
    Reset := Reset,
    ArmRequest := ArmRequest,
    EmergencyChainClosed := EmergencyChainClosed,
    PowerContactorEngaged := PowerContactorEngaged,
    PowerCutOffRequest := PowerCutOffRequest,
    BtnEmergencyCutOff := BtnEmergencyCutOff
);

Output(
    Enable := Enable,
    Cmd := Logic.Cmd,
    ChainOk := EmergencyChainClosed,
    ContactorOk := PowerContactorEngaged,
    ArmingStep := Logic.ArmingSeqStep,
    Armable := Logic.Armable,
    ArmingBusy := Logic.ArmingBusy,
    Error := Logic.Error,
    ErrorId := Logic.ErrorId,
    RedundancyTestFailed := Logic.RedundancyTestFailed,
    ArmFailed := Logic.EmergencyArmingFailed,
    LockoutActive := Logic.EmergencyArmingLockoutActive
);

// 📤 2. Propagation des signaux vers les sorties du bloc parent
Ready := Enable AND NOT Logic.StartupFail;
Busy  := (Logic.ArmingSeqStep <> 0) OR Logic.EmergencyArmingLockoutActive;
Done  := PowerContactorEngaged;
Error := Logic.Error;
ErrorId := Logic.ErrorId;

// ⚡ Sorties physiques
MaintainA_RQ   := Output.MaintainA_RQ;
MaintainB_RQ   := Output.MaintainB_RQ;
ArmPulse_RQ    := Output.ArmPulse_RQ;

// 🚦 Bus publics
State := Output.State;
Diag  := Output.Diag;

// 🩺 Diagnostics scalaires (rétrocompatibilité)
ArmingSeqStep                := Logic.ArmingSeqStep;
RedundancyTestFailed         := Logic.RedundancyTestFailed;
EmergencyArmingFailed        := Logic.EmergencyArmingFailed;
EmergencyArmingLockoutActive := Logic.EmergencyArmingLockoutActive;
