(* =======================================================================
   📏 FB_SyncDeviation — Comparateur d'ecart position M1/M2 (pur)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Signaler l'ecart de position entre M1 et M2 sur 2 seuils
      (Warn = signaler / Fault = critique). Comparateur PUR : il signale,
      il ne decide pas de ralentir ni d'arreter — le consommateur decide.
   🔌 Interface : Bloc de surveillance transverse (1 instance)
   🧬 Responsabilite : n'interprete PAS l'etat benne. Il reçoit ActiveOffsetM
      deja resolu (calcul offset-selon-etat-benne = FB_Bucket/HoldOffset).
   🔒 Polarite : SyncDeviationWarn/Fault = TRUE si ecart hors seuil.
   📄 Doc : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md
   ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_SyncDeviation
VAR_INPUT
    // === COMMANDES ET CONSIGNES ===
    Enable                          : BOOL;                           // --> [CMD] Validation surveillance globale
    Reset                           : BOOL;                           // --> [CMD] Acquittement defaut sur front
    SyncEnable                      : BOOL;                           // --> [CMD] Autorisation utilisateur synchro

    // === MESURES ET ETATS CODEURS ===
    CablePosM1                      : REAL;                           // --> [HW] Position cable treuil M1 (m)
    CablePosM2                      : REAL;                           // --> [HW] Position cable treuil M2 (m)
    HomedAndReliableM1              : BOOL;                           // --> [STAT] Gate fiable M1 (FB_EncoderReliability)
    HomedAndReliableM2              : BOOL;                           // --> [STAT] Gate fiable M2 (FB_EncoderReliability)

    // === REGLAGES ET CONFIGURATION ===
    CfgSyncToleranceM               : REAL := 3.0;                    // --> [CFG] Seuil 1 (Warn) — ecart max avant alerte (m)
    CfgSyncCriticalToleranceM       : REAL := 6.0;                    // --> [CFG] Seuil 2 (Fault) — ecart critique (m)
    ActiveOffsetM                   : REAL := 0.0;                    // --> [CFG] Offset cible RESOLU (ex: benne)

    // === BYPASSES ET SIMULATION ===
    BypassGlobal                    : BOOL := FALSE;                  // --> [TST] Neutralise la surveillance ecart
END_VAR
VAR_OUTPUT
    // === MESURES ET DIAGNOSTICS DE SYNCHRO ===
    DeltaPosM                       : REAL;                           // <-- [DIAG] Ecart absolu position |M1 - M2| (m)
    SignedDeltaPosM                 : REAL;                           // <-- [DIAG] Ecart signe position (M1 - M2) (m)
    SyncDeviationWarn               : BOOL;                           // <-- [DIAG] Seuil 1 depasse : signaler / forcer palier 1
    SyncDeviationFault              : BOOL;                           // <-- [SAFE] Seuil 2 depasse : ecart critique (block signal)
END_VAR
VAR
    // === DETECTEURS ET TIMERS INTERNES ===
    ResetEdge                       : R_TRIG;                         // . [LOC] Detecteur front montant Reset
    DeviationFaultTimer            : TON;                            // . [LOC] Tempo filtrage transitoire ecart (seuil 2)

    // === VARIABLES LOCALES INTERNES ===
    WarnActive                      : BOOL;                           // . [LOC] Ecart hors seuil 1 actif
    FaultActive                     : BOOL;                           // . [LOC] Ecart hors seuil 2 actif
    WarnLatched                     : BOOL;                           // . [LOC] Latch ecart seuil 1 (degrada palier 1 stable)
END_VAR

{region "§1 Gate neutralisation"}
// 🛑 1. GATE
IF NOT Enable THEN
    DeltaPosM := 0.0; SignedDeltaPosM := 0.0;
    SyncDeviationWarn := FALSE; SyncDeviationFault := FALSE;
    WarnLatched := FALSE;
    RETURN;
END_IF;
ResetEdge(CLK := Reset);
{endregion}

{region "§2 Calcul ecart"}
// 📏 2. ÉCART M1/M2 — calculé en continu si les 2 treuils sont fiables (HomedAndReliable)
IF HomedAndReliableM1 AND HomedAndReliableM2 THEN
    SignedDeltaPosM := CablePosM1 - CablePosM2 + ActiveOffsetM;
    DeltaPosM := ABS(SignedDeltaPosM);
ELSE
    SignedDeltaPosM := 0.0;
    DeltaPosM := 0.0;
END_IF;
{endregion}

{region "§3 Surveillance ecart 2 seuils"}
// 🔍 3. SURVEILLANCE ECART — 2 seuils (Warn/Fault).
// Warn (seuil 1) = INSTANTANE + LATCH : degrade le palier 1 des que l'ecart depasse,
// sans retard temporel ni oscillation (fidele a l'ancien SyncDegradedStep1).
// Fault (seuil 2) = filtre temporel pour le transitoire mecanique d'arret.
IF NOT BypassGlobal THEN
    WarnActive  := SyncEnable AND HomedAndReliableM1 AND HomedAndReliableM2 AND (DeltaPosM > CfgSyncToleranceM);
    FaultActive := SyncEnable AND HomedAndReliableM1 AND HomedAndReliableM2 AND (DeltaPosM > CfgSyncCriticalToleranceM);

    // Latch Warn : reste actif tant que la cause persiste OU que Reset n'a pas ete demande
    IF WarnActive THEN
        WarnLatched := TRUE;
    ELSIF ResetEdge.Q AND NOT WarnActive THEN
        WarnLatched := FALSE;
    END_IF;
    SyncDeviationWarn := WarnActive OR WarnLatched;

    DeviationFaultTimer(IN := FaultActive, PT := T#800ms);
    SyncDeviationFault := DeviationFaultTimer.Q;
ELSE
    SyncDeviationWarn := FALSE;
    SyncDeviationFault := FALSE;
    WarnLatched := FALSE;
END_IF;
{endregion}
