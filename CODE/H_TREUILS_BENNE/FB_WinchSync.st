(* =======================================================================
   ⚖️ FB_WinchSync — Surveillance de synchro M1/M2 (sans correction)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Calcul d'écart de position entre M1 et M2 et contrôle de cohérence
   📄 Doc métier : DOC/AF/AF_Partie-10_Fonction_Winch_v2.0.md
   🔌 Interface : FB standard de surveillance transverse (1 instance)
   🔒 Sécurité : Génération d'avertissement et détection de discordances
   ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_WinchSync
VAR_INPUT
    // === COMMANDES ET CONSIGNES ===
    Enable                          : BOOL;                           // --> [CMD] Validation surveillance globale
    Reset                           : BOOL;                           // --> [CMD] Acquittement defaut sur front
    Mode                            : E_Mode;                         // --> [CMD] Mode courant pour arbitrage SyncActive
    SyncEnable                      : BOOL;                           // --> [CMD] Autorisation utilisateur synchro

    // === SECOURS ET HARDWARE ===
    PowerContactorEngaged           : BOOL;                           // --> [SAFE] Puissance contacteur ligne engagee

    // === MESURES ET ETATS CODEURS ===
    CablePosM1                      : REAL;                           // --> [HW] Position cable treuil M1 (m)
    CablePosM2                      : REAL;                           // --> [HW] Position cable treuil M2 (m)
    HomedM1                         : BOOL;                           // --> [HW] Treuil M1 reference
    HomedM2                         : BOOL;                           // --> [HW] Treuil M2 reference

    // === REGLAGES ET CONFIGURATION ===
    CfgSyncToleranceM               : REAL := 0.10;                   // --> [CFG] Ecart max tolere avant alerte (m)
    ActiveOffsetM                   : REAL := 0.0;                    // --> [CFG] Offset cible applique (ex: benne)

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
    // ErrorId : <-- [DIAG] bitmask (bit0: ecart, bit1: incoherence)
    Status                          : ST_FbStatus;                    // <-- [STAT] Statut FB groupe (Busy/Done/Error/State/StateAtError)

    // === MESURES ET DIAGNOSTICS DE SYNCHRO ===
    DeltaPosM                       : REAL;                           // <-- [DIAG] Ecart absolu position |M1 - M2| (m)
    SignedDeltaPosM                 : REAL;                           // <-- [DIAG] Ecart signe position (M1 - M2) (m)
    SyncActive                      : BOOL;                           // <-- [STAT] Statut synchro active selon mode
    SyncWarn                        : BOOL;                           // <-- [DIAG] Avertissement IHM ecart tolere depasse
    SyncDegradedStep1               : BOOL;                           // <-- [DIAG] Forcage palier 1 sur ecart modere
END_VAR
VAR
    // === DETECTEURS ET TIMERS INTERNES ===
    ResetEdge                       : R_TRIG;                         // . [LOC] Detecteur front montant Reset
    ErrorEdge                       : R_TRIG;                         // . [LOC] Detecteur front montant Erreur
    MismatchTimer                   : TON;                            // . [LOC] Tempo filtrage incoherence commande
    DeviationTimer                  : TON;                            // . [LOC] Tempo filtrage transitoire ecart

    // === VARIABLES LOCALES INTERNES ===
    MismatchActive                  : BOOL;                           // . [LOC] Discordance commande active
    DeviationActive                 : BOOL;                           // . [LOC] Ecart position hors tolerance actif
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_WinchSync) ===

{region "§1 Gate neutralisation"}
// 🛑 1. GATE
IF NOT Enable OR NOT PowerContactorEngaged THEN
    Ready := FALSE; Status.Busy := FALSE; Status.Done := FALSE;
    Status.State := E_State.DISABLED;
    DeltaPosM := 0.0;
    SyncActive := FALSE;
    SyncWarn := FALSE;
    SyncDegradedStep1 := FALSE;
    Status.Error := FALSE;
    Status.ErrorId := 16#0000;
    RETURN;
END_IF;

{endregion}

{region "§2 Initialisation et activation synchro"}
Ready := TRUE;
Status.State := E_State.READY;

// 🔑 2. RESET FRONT
ResetEdge(CLK := Reset);

// 🌐 BYPASS GLOBAL : force ErrorId = 0 et ignore toute la surveillance synchro
IF BypassGlobal THEN
    Status.ErrorId := 16#0000;
END_IF;

// 🎚️ 3. SyncActive SELON MODE (Partie9 §9)
CASE Mode OF
    E_Mode.MAINT_N1:
        SyncActive := TRUE;                  // Imposée, non désactivable (sécurité maintenue N1)
    E_Mode.MAINT_N2:
        SyncActive := SyncEnable;             // Polarité positive (TRUE = synchro active)
    ELSE
        SyncActive := TRUE;                  // MANUEL/SEMI_AUTO : pas de logique dédiée (FB_Cycle absent), actif par prudence
END_CASE;

{endregion}

{region "§3 Calcul ecart position"}
// 📏 4. ÉCART M1/M2 — calculé en continu si les 2 treuils sont homés (même si BypassGlobal est actif)
IF HomedM1 AND HomedM2 THEN
    SignedDeltaPosM := CablePosM1 - CablePosM2 + ActiveOffsetM;
    DeltaPosM := ABS(SignedDeltaPosM);
ELSE
    SignedDeltaPosM := 0.0;
    DeltaPosM := 0.0;
END_IF;

{endregion}

{region "§4 Surveillance synchronisme"}
// 🌐 BYPASS GLOBAL : si actif, on saute TOUTE la logique d'erreur/surveillance
IF NOT BypassGlobal THEN

// 🔍 5. DÉTECTION ÉCART HORS TOLÉRANCE — bit0
// Filtre temporel (même pattern que MismatchTimer bit1) — absorbe le transitoire mécanique
// normal d'arrêt (coast-down différentiel M1/M2), évite le blocage intempestif.
// Si écart > CfgSyncToleranceM -> alarme d'écart (SyncWarn / bit0) et dégradation en vitesse
// lente Palier 1 (SyncDegradedStep1). L'arrêt brutal SafeStop est réservé à l'écart critique
// Méca E (> CriticalSyncToleranceM).
DeviationActive := SyncActive AND HomedM1 AND HomedM2 AND (DeltaPosM > CfgSyncToleranceM);
DeviationTimer(IN := DeviationActive, PT := T#800ms);  // 🔧 théorique, à ajuster sur site — absorbe le transitoire mécanique normal d'arrêt (coast-down différentiel M1/M2)
IF DeviationTimer.Q THEN
    Status.ErrorId := Status.ErrorId OR 16#0001;
ELSIF ResetEdge.Q AND NOT DeviationActive THEN
    Status.ErrorId := Status.ErrorId AND 16#FFFE;
END_IF;

// 🐢 Dégradation au Palier 1 dès que l'écart dépasse la tolérance (sans attendre le SafeStop)
SyncDegradedStep1 := SyncActive AND HomedM1 AND HomedM2 AND ((DeltaPosM > CfgSyncToleranceM) OR ((Status.ErrorId AND 16#0001) <> 16#0000));

// 🔍 5bis. COHÉRENCE DES COMMANDES SÉCURITÉ — bit1
// Vérifie que les commandes envoyées aux deux treuils sont identiques (sens et contacteurs)
// Filtre de 500ms pour tolérer les transitions et rampes.
MismatchActive := SyncActive AND (
    (RelayFwdM1 <> RelayFwdM2) OR
    (RelayRevM1 <> RelayRevM2) OR
    (Contactor1_M1 <> Contactor1_M2) OR
    (Contactor2_M1 <> Contactor2_M2) OR
    (Contactor3_M1 <> Contactor3_M2) OR
    (Contactor4_M1 <> Contactor4_M2)
);

MismatchTimer(IN := MismatchActive, PT := T#500ms);

IF MismatchTimer.Q THEN
    Status.ErrorId := Status.ErrorId OR 16#0002;
ELSIF ResetEdge.Q THEN
    Status.ErrorId := Status.ErrorId AND 16#FFFD;
END_IF; // fin du IF MismatchActive

ELSE
    SyncDegradedStep1 := FALSE;
END_IF; // fin IF NOT BypassGlobal

{endregion}

{region "§5 Etats et diagnostic"}
// 📤 6. SORTIES ÉTAT
Status.Error := (Status.ErrorId <> 16#0000);
ErrorEdge(CLK := Status.Error);
IF ErrorEdge.Q THEN
    Status.StateAtError := Status.State;
END_IF;

SyncWarn := Status.Error;   // ⚠️ IHM uniquement — voir en-tête, pas de SafeStop
Status.Busy := FALSE;
Status.Done := FALSE;

{endregion}
