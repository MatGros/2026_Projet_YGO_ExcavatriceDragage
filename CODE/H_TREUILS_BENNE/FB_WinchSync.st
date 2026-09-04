(* =======================================================================
   ⚖️ FB_WinchSync — Coordonnateur synchro M1/M2 (1 instance)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Coordonner les 2 blocs de surveillance synchro :
      - FB_SyncDeviation  (ecart codeurs M1/M2, 2 seuils Warn/Fault)
      - FB_SyncContactor  (coherence commandes/contacteurs)
      et produire SyncActive (autorisation de couplage) + le statut
      transverse d'ensemble pour les consommateurs (PRG_04/PRG_07/IHM).
   🧬 Responsabilite : coordination + autorisation de couplage.
   📄 Doc : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md
   ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_WinchSync
VAR_INPUT
    // === COMMANDES ET CONSIGNES ===
    Enable                          : BOOL;                           // --> [CMD] Validation surveillance globale
    Reset                           : BOOL;                           // --> [CMD] Acquittement defaut sur front
    Mode                            : E_Mode;                         // --> [CMD] Mode courant pour arbitrage SyncActive
    SyncEnable                      : BOOL;                           // --> [CMD] Autorisation utilisateur synchro

    // === MESURES ET ETATS CODEURS ===
    CablePosM1                      : REAL;                           // --> [HW] Position cable treuil M1 (m)
    CablePosM2                      : REAL;                           // --> [HW] Position cable treuil M2 (m)
    HomedAndReliableM1              : BOOL;                           // --> [STAT] Gate fiable M1 (FB_EncoderReliability)
    HomedAndReliableM2              : BOOL;                           // --> [STAT] Gate fiable M2 (FB_EncoderReliability)

    // === REGLAGES ET CONFIGURATION ===
    CfgSyncToleranceM               : REAL := 0.10;                   // --> [CFG] Seuil 1 (Warn) — ecart max avant alerte (m)
    CfgSyncCriticalToleranceM       : REAL := 0.50;                   // --> [CFG] Seuil 2 (Fault) — ecart critique (m)
    ActiveOffsetM                   : REAL := 0.0;                    // --> [CFG] Offset cible RESOLU (ex: benne)

    // === COMMANDES ET FEEDBACKS ACTIONS ===
    RelayFwdM1                      : BOOL;                           // --> [HW] Feedback/Ordre montee M1
    RelayFwdM2                      : BOOL;                           // --> [HW] Feedback/Ordre montee M2
    RelayRevM1                      : BOOL;                           // --> [HW] Feedback/Ordre descente M1
    RelayRevM2                      : BOOL;                           // --> [HW] Feedback/Ordre descente M2
    Contactor1_M1                   : BOOL;                           // --> [HW] Contacteur palier 1 M1
    Contactor1_M2                   : BOOL;                           // --> [HW] Contacteur palier 1 M2
    Contactor2_M1                   : BOOL;                           // --> [HW] Contacteur palier 2 M1
    Contactor2_M2                   : BOOL;                           // --> [HW] Contacteur palier 2 M2
    Contactor3_M1                   : BOOL;                           // --> [HW] Contacteur palier 3 M1
    Contactor3_M2                   : BOOL;                           // --> [HW] Contacteur palier 3 M2
    Contactor4_M1                   : BOOL;                           // --> [HW] Contacteur palier 4 M1
    Contactor4_M2                   : BOOL;                           // --> [HW] Contacteur palier 4 M2

    // === BYPASSES ET SIMULATION ===
    BypassGlobal                    : BOOL := FALSE;                  // --> [TST] Force ErrorId=0 global
END_VAR
VAR_OUTPUT
    // === ETATS IEC ET SYNOPTIQUE ===
    Ready                           : BOOL;                           // <-- [STAT] FB pret a fonctionner
    // 🧩 Statut transverse (forme cible ST_Fault)
    Fault                           : ST_Fault;

    // === MESURES ET DIAGNOSTICS DE SYNCHRO ===
    DeltaPosM                       : REAL;                           // <-- [DIAG] Ecart absolu position |M1 - M2| (m)
    SignedDeltaPosM                 : REAL;                           // <-- [DIAG] Ecart signe position (M1 - M2) (m)
    SyncActive                      : BOOL;                           // <-- [STAT] Statut synchro active selon mode
    SyncWarn                        : BOOL;                           // <-- [DIAG] Avertissement IHM (Warn ou discordance)
    SyncDeviationWarn               : BOOL;                           // <-- [DIAG] Ecart seuil 1 depasse (force palier 1)
    SyncDeviationFault              : BOOL;                           // <-- [SAFE] Ecart seuil 2 critique (block signal)
    ContactorMismatch              : BOOL;                           // <-- [SAFE] Discordance contacteurs M1/M2 confirmee (miroir instContactor, nom -> plus de masque hexa cote PRG_04)
END_VAR
VAR
    // === DETECTEURS ET TIMERS INTERNES ===
    ResetEdge                       : R_TRIG;                         // . [LOC] Detecteur front montant Reset

    // === SOUS-INSTANCES FB ===
    instDeviation                   : FB_SyncDeviation;               // * [INST] Comparateur ecart codeurs (pur)
    instContactor                   : FB_SyncContactor;               // * [INST] Coherence commandes/contacteurs

    // === SOCLE DEFAUT ===
    instFault                       : FB_FaultCore;                   // * [INST] Socle défaut transverse
    instCauses                      : ARRAY[0..15] OF ST_FaultCause;  // . [LOC] Table des causes nommées
END_VAR

// === IMPLEMENTATION ===

{region "§1 Gate neutralisation"}
// 🛑 1. GATE
// Enable=FALSE = phase ou l'ecart M1/M2 est volontairement grand (homing, benne, unitaire).
// On PURGE inconditionnellement : aucune cause ni aucun latch de FB_FaultCore ne doit
// survivre a la desactivation, sinon un seul scan d'armement avant que le gate ne se ferme
// laisserait Fault.Latched cote PRG_04 (RAZ = Reset explicite seulement). La concordance
// contacteurs "physique" reste couverte par instSyncContactorFinal (PRG_06), independant.
IF NOT Enable THEN
    Ready := FALSE;
    DeltaPosM := 0.0; SignedDeltaPosM := 0.0;
    SyncActive := FALSE;
    SyncWarn := FALSE; SyncDeviationWarn := FALSE; SyncDeviationFault := FALSE;
    ContactorMismatch := FALSE;
    instCauses[0].Active := FALSE;
    instCauses[1].Active := FALSE;
    instCauses[2].Active := FALSE;
    instFault(Enable := FALSE, Reset := TRUE, Causes := instCauses);
    Fault := instFault.Fault;
    RETURN;
END_IF;

Ready := TRUE;
{endregion}

{region "§2 Activation synchro"}
// 🔑 2. RESET FRONT
ResetEdge(CLK := Reset);

// 🎚️ 3. SyncActive SELON MODE (Partie9 §9)
CASE Mode OF
    E_Mode.MAINT_N1:
        SyncActive := TRUE;                  // Imposée, non désactivable (sécurité maintenue N1)
    E_Mode.MAINT_N2:
        SyncActive := SyncEnable;             // Polarité positive (TRUE = synchro active)
    ELSE
        SyncActive := TRUE;                  // MANUEL/SEMI_AUTO : actif par prudence
END_CASE;
{endregion}

{region "§3 Sous-blocs deviation et contacteurs"}
// 📏 4. ÉCART CODEURS (FB_SyncDeviation) + COHERENCE CONTACTEURS (FB_SyncContactor)
instDeviation(
    Enable               := Enable,
    Reset                := Reset,
    SyncEnable           := SyncActive,
    CablePosM1           := CablePosM1,
    CablePosM2           := CablePosM2,
    HomedAndReliableM1   := HomedAndReliableM1,
    HomedAndReliableM2   := HomedAndReliableM2,
    CfgSyncToleranceM    := CfgSyncToleranceM,
    CfgSyncCriticalToleranceM := CfgSyncCriticalToleranceM,
    ActiveOffsetM        := ActiveOffsetM,
    BypassGlobal         := BypassGlobal
);
DeltaPosM := instDeviation.DeltaPosM;
SignedDeltaPosM := instDeviation.SignedDeltaPosM;
SyncDeviationWarn := instDeviation.SyncDeviationWarn;
SyncDeviationFault := instDeviation.SyncDeviationFault;

instContactor(
    Enable          := Enable,
    Reset           := Reset,
    SyncEnable      := SyncActive,
    RelayFwdM1      := RelayFwdM1,
    RelayFwdM2      := RelayFwdM2,
    RelayRevM1      := RelayRevM1,
    RelayRevM2      := RelayRevM2,
    Contactor1_M1   := Contactor1_M1,
    Contactor1_M2   := Contactor1_M2,
    Contactor2_M1   := Contactor2_M1,
    Contactor2_M2   := Contactor2_M2,
    Contactor3_M1   := Contactor3_M1,
    Contactor3_M2   := Contactor3_M2,
    Contactor4_M1   := Contactor4_M1,
    Contactor4_M2   := Contactor4_M2,
    BypassGlobal    := BypassGlobal
);
{endregion}

{region "§4 Causes & Socle Défaut"}
IF NOT BypassGlobal THEN
    instCauses[0].Active   := instDeviation.SyncDeviationWarn;
    instCauses[0].Latching := FALSE;
    instCauses[0].Texte    := 'Alerte ecart synchronisation M1/M2';

    instCauses[1].Active   := instContactor.ContactorMismatch;
    instCauses[1].Latching := TRUE;
    instCauses[1].Texte    := 'Discordance contacteurs treuils M1/M2';

    instCauses[2].Active   := instDeviation.SyncDeviationFault;
    instCauses[2].Latching := TRUE;
    instCauses[2].Texte    := 'Ecart critique synchronisation treuils M1/M2';
ELSE
    instCauses[0].Active := FALSE;
    instCauses[1].Active := FALSE;
    instCauses[2].Active := FALSE;
END_IF;

// Appel du socle de défaut
instFault(Enable := Enable, Reset := Reset, Causes := instCauses);
Fault := instFault.Fault;

SyncWarn := Fault.Error;
Ready := Enable AND NOT Fault.Latched;

// Miroir nomme de la discordance contacteurs (le consommateur lit ce booleen,
// plus le masque hexa sur Fault.ErrorId). BypassGlobal deja gere dans instContactor.
ContactorMismatch := instContactor.ContactorMismatch;
{endregion}

END_FUNCTION_BLOCK
