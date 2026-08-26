(* =======================================================================
   ⚖️ FB_WinchSync — Coordonnateur synchro M1/M2 (1 instance)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Coordonner les 2 blocs de surveillance synchro :
      - FB_SyncDeviation  (ecart codeurs M1/M2, 2 seuils Warn/Fault)
      - FB_SyncContactor  (coherence commandes/contacteurs)
      et produire SyncActive (autorisation de couplage) + le statut
      transverse d'ensemble pour les consommateurs (PRG_04/PRG_07/IHM).
   🧬 Responsabilite : coordination + autorisation de couplage. L'ecart
      codeur vit dans FB_SyncDeviation, la coherence contacteurs dans
      FB_SyncContactor. Ce bloc NE calcule PAS l'ecart lui-meme.
   🔒 SyncActive : autorisation de couplage (anti-telescopage), independante
      de l'erreur — le probleme est porte par SyncDeviationWarn/Fault.
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
    // ErrorId : <-- [DIAG] bitmask (bit0: ecart Warn, bit1: discordance contacteurs, bit2: ecart Fault)
    Status                          : ST_FbStatus;                    // <-- [STAT] Statut FB groupe (Busy/Done/Error/State/StateAtError)

    // === MESURES ET DIAGNOSTICS DE SYNCHRO ===
    DeltaPosM                       : REAL;                           // <-- [DIAG] Ecart absolu position |M1 - M2| (m)
    SignedDeltaPosM                 : REAL;                           // <-- [DIAG] Ecart signe position (M1 - M2) (m)
    SyncActive                      : BOOL;                           // <-- [STAT] Statut synchro active selon mode
    SyncWarn                        : BOOL;                           // <-- [DIAG] Avertissement IHM (Warn ou discordance)
    SyncDeviationWarn               : BOOL;                           // <-- [DIAG] Ecart seuil 1 depasse (force palier 1)
    SyncDeviationFault              : BOOL;                           // <-- [SAFE] Ecart seuil 2 critique (block signal)
END_VAR
VAR
    // === DETECTEURS ET TIMERS INTERNES ===
    ResetEdge                       : R_TRIG;                         // . [LOC] Detecteur front montant Reset
    ErrorEdge                       : R_TRIG;                         // . [LOC] Detecteur front montant Erreur

    // === SOUS-INSTANCES FB ===
    instDeviation                   : FB_SyncDeviation;               // * [INST] Comparateur ecart codeurs (pur)
    instContactor                   : FB_SyncContactor;               // * [INST] Coherence commandes/contacteurs
END_VAR

{region "§1 Gate neutralisation"}
// 🛑 1. GATE
IF NOT Enable THEN
    Ready := FALSE; Status.Busy := FALSE; Status.Done := FALSE;
    Status.State := E_State.DISABLED;
    DeltaPosM := 0.0; SignedDeltaPosM := 0.0;
    SyncActive := FALSE;
    SyncWarn := FALSE; SyncDeviationWarn := FALSE; SyncDeviationFault := FALSE;
    Status.Error := FALSE; Status.ErrorId := 16#0000;
    RETURN;
END_IF;
Ready := TRUE;
Status.State := E_State.READY;
{endregion}

{region "§2 Activation synchro"}
// 🔑 2. RESET FRONT
ResetEdge(CLK := Reset);

// 🌐 BYPASS GLOBAL : force ErrorId = 0 et ignore toute la surveillance synchro
IF BypassGlobal THEN
    Status.ErrorId := 16#0000;
END_IF;

// 🎚️ 3. SyncActive SELON MODE (Partie9 §9) — autorisation de couplage, independante de l'erreur
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

{region "§4 Synthese statut"}
// 📤 5. SYNTHESE STATUT — consommateurs (PRG_04/PRG_07/IHM) lisent ce Status
IF NOT BypassGlobal THEN
    // bit0 : ecart seuil 1 (Warn) — force palier 1
    IF instDeviation.SyncDeviationWarn THEN
        Status.ErrorId := Status.ErrorId OR 16#0001;
    ELSIF ResetEdge.Q AND NOT instDeviation.SyncDeviationWarn THEN
        Status.ErrorId := Status.ErrorId AND 16#FFFE;
    END_IF;
    // bit1 : discordance contacteurs
    IF instContactor.ContactorMismatch THEN
        Status.ErrorId := Status.ErrorId OR 16#0002;
    ELSIF ResetEdge.Q THEN
        Status.ErrorId := Status.ErrorId AND 16#FFFD;
    END_IF;
    // bit2 : ecart seuil 2 (Fault) — critique
    IF instDeviation.SyncDeviationFault THEN
        Status.ErrorId := Status.ErrorId OR 16#0004;
    ELSIF ResetEdge.Q AND NOT instDeviation.SyncDeviationFault THEN
        Status.ErrorId := Status.ErrorId AND 16#FFFB;
    END_IF;
ELSE
    Status.ErrorId := 16#0000;
END_IF;

Status.Error := (Status.ErrorId <> 16#0000);
ErrorEdge(CLK := Status.Error);
IF ErrorEdge.Q THEN
    Status.StateAtError := Status.State;
END_IF;

SyncWarn := Status.Error;   // ⚠️ IHM uniquement — pas de SafeStop
Status.Busy := FALSE;
Status.Done := FALSE;
{endregion}
