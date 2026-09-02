(* =======================================================================
   🔀 FB_SyncContactor — Coherence commandes/contacteurs M1/M2
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Detecter une discordance entre les commandes/contacteurs des
      2 treuils (sens + paliers). Independante des codeurs — surveillable
      meme si les codeurs sont bypasses.
   🔌 Interface : Bloc de surveillance transverse (1..N instances : requetes
      amont dans FB_WinchSync, sorties physiques finales dans PRG_06).
   🔒 Polarite : ContactorMismatch = TRUE si discordance confirmee (debounce).
      Reponse GRADUEE : ContactorMismatch (niveau 1, filtre MismatchDebounce)
      -> SafeStop ; ContactorMismatchEscalated (niveau 2, si la discordance
      tient CST_SyncEscalationTime) -> escalade PowerCutOff.
   ⚖️ Concordance ACTIVE des que les 2 treuils sont commandes (relais ou
      contacteur) OU en mode synchronisme (SyncEnable). Seul BypassGlobal
      neutralise.
   📄 Doc : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md
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
    // === RESULTAT (reponse graduee) ===
    ContactorMismatch               : BOOL;                           // <-- [SAFE] Niveau 1 : discordance commande/contacteurs confirmee (debounce) -> SafeStop
    ContactorMismatchEscalated      : BOOL;                           // <-- [SAFE] Niveau 2 : discordance persistante -> escalade PowerCutOff
    Diag                            : ST_SyncContactorDiag;           // <-- [DIAG] Detail : quel contacteur diverge + niveau atteint
END_VAR
VAR CONSTANT
    MismatchDebounce                : TIME := T#500ms;                // Filtre transitoires/rampes avant de confirmer la discordance (niveau 1)
    CST_SyncEscalationTime          : TIME := T#3s;                   // Discordance confirmee tenue au-dela de ce delai -> escalade (niveau 2)
END_VAR
VAR
    // === DETECTEURS ET TIMERS INTERNES ===
    MismatchTimer                   : TON;                            // . [LOC] Tempo filtrage incoherence (niveau 1)
    EscalationTimer                 : TON;                            // . [LOC] Tempo escalade (niveau 2)

    // === VARIABLES LOCALES INTERNES ===
    MismatchActive                  : BOOL;                           // . [LOC] Discordance instantanee (avant debounce)
    BothCommanded                   : BOOL;                           // . [LOC] Les 2 treuils sont commandes (relais ou contacteur)
END_VAR

{region "§1 Gate neutralisation"}
// 🛑 1. GATE
IF NOT Enable OR BypassGlobal THEN
    ContactorMismatch := FALSE;
    ContactorMismatchEscalated := FALSE;
    MismatchActive := FALSE;
    BothCommanded := FALSE;
    MismatchTimer(IN := FALSE);
    EscalationTimer(IN := FALSE);
    Diag.RelayFwdMismatch := FALSE;
    Diag.RelayRevMismatch := FALSE;
    Diag.Step1Mismatch := FALSE;
    Diag.Step2Mismatch := FALSE;
    Diag.Step3Mismatch := FALSE;
    Diag.Step4Mismatch := FALSE;
    Diag.MismatchLevel := 0;
    RETURN;
END_IF;
{endregion}

{region "§2 Detection discordance + diagnostic decode"}
// 🔍 2. COHÉRENCE DES COMMANDES SÉCURITÉ — verifie que les commandes envoyees
// aux deux treuils sont identiques (sens et contacteurs).
// Concordance ACTIVE des que les 2 treuils sont commandes (relais ou contacteur)
// OU en mode synchronisme (SyncEnable).
BothCommanded := (RelayFwdM1 OR RelayRevM1 OR Contactor1_M1 OR Contactor2_M1
                  OR Contactor3_M1 OR Contactor4_M1)
             AND (RelayFwdM2 OR RelayRevM2 OR Contactor1_M2 OR Contactor2_M2
                  OR Contactor3_M2 OR Contactor4_M2);

// Diagnostic decode : quel(s) contacteur(s) diverge(nt) (bits nommes, plusieurs possibles).
Diag.RelayFwdMismatch := (BothCommanded OR SyncEnable) AND (RelayFwdM1 <> RelayFwdM2);
Diag.RelayRevMismatch := (BothCommanded OR SyncEnable) AND (RelayRevM1 <> RelayRevM2);
Diag.Step1Mismatch    := (BothCommanded OR SyncEnable) AND (Contactor1_M1 <> Contactor1_M2);
Diag.Step2Mismatch    := (BothCommanded OR SyncEnable) AND (Contactor2_M1 <> Contactor2_M2);
Diag.Step3Mismatch    := (BothCommanded OR SyncEnable) AND (Contactor3_M1 <> Contactor3_M2);
Diag.Step4Mismatch    := (BothCommanded OR SyncEnable) AND (Contactor4_M1 <> Contactor4_M2);

MismatchActive := Diag.RelayFwdMismatch OR Diag.RelayRevMismatch
    OR Diag.Step1Mismatch OR Diag.Step2Mismatch
    OR Diag.Step3Mismatch OR Diag.Step4Mismatch;

// Niveau 1 : discordance confirmee apres MismatchDebounce.
MismatchTimer(IN := MismatchActive, PT := MismatchDebounce);
ContactorMismatch := MismatchTimer.Q;

// Niveau 2 : la discordance confirmee tient au-dela de CST_SyncEscalationTime.
EscalationTimer(IN := ContactorMismatch, PT := CST_SyncEscalationTime);
ContactorMismatchEscalated := EscalationTimer.Q;

// Niveau publie.
IF ContactorMismatchEscalated THEN
    Diag.MismatchLevel := 2;
ELSIF ContactorMismatch THEN
    Diag.MismatchLevel := 1;
ELSE
    Diag.MismatchLevel := 0;
END_IF;
{endregion}

END_FUNCTION_BLOCK
