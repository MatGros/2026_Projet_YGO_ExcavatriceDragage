(* =======================================================================
   📊 FB_WinchLoadEstimator — Estimation empirique de charge treuil
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Estimation informative de la charge par croisement palier/vitesse
   📄 Doc métier : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md
   🔌 Interface : Brique de diagnostic/mesure (1 instance par treuil)
   🔒 Sécurité : Aucune commande moteur ni action sur SafeStop (information IHM)
   ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_WinchLoadEstimator

VAR_INPUT
    // === COMMANDES ET CONSIGNES ===
    Enable                          : BOOL;                           // --> [CMD] Autorisation generale FB
    Reset                           : BOOL;                           // --> [CMD] Acquittement defaut sur front
    Mode                            : E_Mode;                         // --> [CMD] Mode d'exploitation actif
    ActiveSpeedStep                 : INT;                            // --> [CMD] Palier commande actif (0..5)

    // === SECOURS ET HARDWARE ===
    PowerContactorEngaged           : BOOL;                           // --> [SAFE] Chaine AU rearmee et puissance OK
    MeasuredSpeedMps                : REAL;                           // --> [HW] Vitesse cable absolue (m/s)
    MeasuredSpeedSignedMps          : REAL;                           // --> [HW] Vitesse signee (+: montee, -: descente) (m/s)

    // === REGLAGES ET TABLES ===
    SpeedConfig                     : ST_fbWinchLoadEstimator_SpeedCfg;            // --> [CFG] Configuration des plages de vitesse
    LoadTable                       : ST_fbWinchLoadEstimator_Table;      // --> [CFG] Table empirique d'estimation 5x5
END_VAR
VAR_OUTPUT
    // === ETATS IEC ET SYNOPTIQUE ===
    Ready                           : BOOL;                           // <-- [STAT] FB pret a fonctionner
    // 🧩 Statut transverse (forme cible ST_Fault)
    Fault                           : ST_Fault;

    // === DIAGNOSTICS ET ESTIMATIONS ===
    SpeedBand                       : INT;                            // <-- [DIAG] Bande de vitesse courante (0..5)
    EstimatedLoadPct                : REAL;                           // <-- [DIAG] Estimation de charge (0..100%)
    Configured                      : BOOL;                           // <-- [STAT] Table explicitement validee
    Ascending                       : BOOL;                           // <-- [STAT] Montee effective mesuree en cours
END_VAR
VAR
    // === DETECTEURS ET TIMERS INTERNES ===
    ResetEdge                       : R_TRIG;                         // . [LOC] Detecteur front montant Reset

    // === VARIABLES LOCALES CALCULÉES ===
    PreviousSpeedBand               : INT;                            // . [LOC] Memoire bande de vitesse cycle precedent
    HasPreviousBand                 : BOOL;                           // . [LOC] Indicateur premiere bande memorisee
    SelectedLoadPct                 : REAL;                           // . [LOC] Valeur de charge extraite de la table
    ConfigOrSpeedFault              : BOOL;                           // . [LOC] Latch défaut configuration / vitesse

    // === SOCLE DEFAUT ===
    instFault                       : FB_FaultCore;                   // * [INST] Socle défaut transverse
    instCauses                      : ARRAY[0..15] OF ST_FaultCause;  // . [LOC] Table des causes nommées
END_VAR

// === IMPLEMENTATION ===

{region "§1 Causes & Socle Défaut (évalué en continu)"}
// 🔑 1. FRONTS
ResetEdge(CLK := Reset);

IF ResetEdge.Q AND (MeasuredSpeedMps >= 0.0) THEN
    ConfigOrSpeedFault := FALSE;
END_IF;

instCauses[0].Active   := ConfigOrSpeedFault;
instCauses[0].Latching := TRUE;
instCauses[0].Texte    := 'Parametrage ou vitesse estimation charge invalide';

// Appel du socle de défaut
instFault(Enable := Enable, Reset := Reset, Causes := instCauses);
Fault := instFault.Fault;
{endregion}

{region "§2 Gate neutralisation"}
// 🛑 2. GATE
IF NOT Enable OR NOT PowerContactorEngaged THEN
    Ready := FALSE;
    SpeedBand := 0;
    EstimatedLoadPct := 0.0;
    Configured := FALSE;
    Ascending := FALSE;
    HasPreviousBand := FALSE;
    RETURN;
END_IF;

Ready := Enable AND NOT Fault.Latched;
Configured := LoadTable.IsConfigured;
Ascending := (MeasuredSpeedSignedMps > 0.0);
{endregion}

{region "§3 Classement vitesse"}
// 📏 3. CLASSEMENT DE LA VITESSE — hystérésis autour des 4 frontières.
IF (MeasuredSpeedMps < 0.0) OR (SpeedConfig.MaxMeasuredSpeedMps <= 0.0) THEN
    ConfigOrSpeedFault := TRUE;
    SpeedBand := 0;
ELSIF NOT HasPreviousBand THEN
    IF MeasuredSpeedMps <= SpeedConfig.SpeedBandMaxMps[1] THEN
        PreviousSpeedBand := 1;
    ELSIF MeasuredSpeedMps <= SpeedConfig.SpeedBandMaxMps[2] THEN
        PreviousSpeedBand := 2;
    ELSIF MeasuredSpeedMps <= SpeedConfig.SpeedBandMaxMps[3] THEN
        PreviousSpeedBand := 3;
    ELSIF MeasuredSpeedMps <= SpeedConfig.SpeedBandMaxMps[4] THEN
        PreviousSpeedBand := 4;
    ELSE
        PreviousSpeedBand := 5;
    END_IF;
    HasPreviousBand := TRUE;
    SpeedBand := PreviousSpeedBand;
ELSE
    IF PreviousSpeedBand < 1 OR PreviousSpeedBand > 5 THEN
        PreviousSpeedBand := 1;
        ConfigOrSpeedFault := TRUE;
    END_IF;

    IF PreviousSpeedBand < 5 THEN
        IF MeasuredSpeedMps > (SpeedConfig.SpeedBandMaxMps[PreviousSpeedBand]
                               + SpeedConfig.SpeedBandHysteresisMps) THEN
            PreviousSpeedBand := PreviousSpeedBand + 1;
        END_IF;
    END_IF;
    IF PreviousSpeedBand > 1 THEN
        IF MeasuredSpeedMps < (SpeedConfig.SpeedBandMaxMps[PreviousSpeedBand - 1]
                               - SpeedConfig.SpeedBandHysteresisMps) THEN
            PreviousSpeedBand := PreviousSpeedBand - 1;
        END_IF;
    END_IF;
    SpeedBand := PreviousSpeedBand;
END_IF;
{endregion}

{region "§4 Lecture table"}
// 📊 4. LECTURE TABLE
EstimatedLoadPct := 0.0;
IF Configured THEN
    IF Ascending THEN
        IF ActiveSpeedStep >= 1 THEN
            IF ActiveSpeedStep <= 5 THEN
                IF SpeedBand >= 1 THEN
                    IF SpeedBand <= 5 THEN
                        SelectedLoadPct := LoadTable.LoadPctByStepAndSpeedBand[ActiveSpeedStep][SpeedBand];
                        IF (SelectedLoadPct < 0.0) OR (SelectedLoadPct > 100.0) THEN
                            ConfigOrSpeedFault := TRUE;
                        ELSE
                            EstimatedLoadPct := SelectedLoadPct;
                        END_IF;
                    END_IF;
                END_IF;
            END_IF;
        END_IF;
    END_IF;
END_IF;
{endregion}

END_FUNCTION_BLOCK
