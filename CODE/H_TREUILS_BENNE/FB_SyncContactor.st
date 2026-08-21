(* =======================================================================
   🔀 FB_SyncContactor — Coherence commandes/contacteurs M1/M2
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Detecter une discordance entre les commandes/contacteurs des
      2 treuils (sens + paliers). Independante des codeurs — surveillable
      meme si les codeurs sont bypasses.
   🔌 Interface : Bloc de surveillance transverse (1 instance)
   🔒 Polarite : ContactorMismatch = TRUE si discordance confirmee.
   📄 Doc : DOC/AF/AF_Partie-10_Fonction_Winch_v2.0.md
   ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_SyncContactor
VAR_INPUT
    // === COMMANDES ET CONSIGNES ===
    Enable                          : BOOL;                           // --> [CMD] Validation surveillance globale
    Reset                           : BOOL;                           // --> [CMD] Acquittement defaut sur front
    SyncEnable                      : BOOL;                           // --> [CMD] Autorisation utilisateur synchro

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
    BypassGlobal                    : BOOL := FALSE;                  // --> [TST] Neutralise la surveillance contacteurs
END_VAR
VAR_OUTPUT
    // === RESULTAT ===
    ContactorMismatch               : BOOL;                           // <-- [SAFE] Discordance commande/contacteurs confirmee
END_VAR
VAR
    // === DETECTEURS ET TIMERS INTERNES ===
    MismatchTimer                   : TON;                            // . [LOC] Tempo filtrage incoherence commande

    // === VARIABLES LOCALES INTERNES ===
    MismatchActive                  : BOOL;                           // . [LOC] Discordance commande active
END_VAR

{region "§1 Gate neutralisation"}
// 🛑 1. GATE
IF NOT Enable THEN
    ContactorMismatch := FALSE;
    MismatchActive := FALSE;
    MismatchTimer(IN := FALSE);
    RETURN;
END_IF;
{endregion}

{region "§2 Detection discordance"}
// 🔍 2. COHÉRENCE DES COMMANDES SÉCURITÉ — verifie que les commandes envoyees
// aux deux treuils sont identiques (sens et contacteurs).
// Filtre de 500ms pour tolerer les transitions et rampes.
IF NOT BypassGlobal THEN
    MismatchActive := SyncEnable AND (
        (RelayFwdM1 <> RelayFwdM2) OR
        (RelayRevM1 <> RelayRevM2) OR
        (Contactor1_M1 <> Contactor1_M2) OR
        (Contactor2_M1 <> Contactor2_M2) OR
        (Contactor3_M1 <> Contactor3_M2) OR
        (Contactor4_M1 <> Contactor4_M2)
    );
    MismatchTimer(IN := MismatchActive, PT := T#500ms);
    ContactorMismatch := MismatchTimer.Q;
ELSE
    ContactorMismatch := FALSE;
    MismatchActive := FALSE;
    MismatchTimer(IN := FALSE);
END_IF;
{endregion}
