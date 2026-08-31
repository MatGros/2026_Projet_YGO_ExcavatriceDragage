(* ═══════════════════════════════════════════════════════════════
   🛡️ GVL_Safety_Emergency — Constantes globales chaîne AU
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Constantes symboliques de la séquence de réarmement AU —
      étapes CST_STEP_* et causes d'abandon CST_ABORT_* — partagées
      entre POU. Sorties du bloc `VAR CONSTANT` local du FB
      FB_Safety_EmergencyManagement (conformité IEC : CODESYS refuse
      les constantes locales d'un FUNCTION_BLOCK comme étiquettes de
      CASE — erreur C0218). En `VAR_GLOBAL CONSTANT`, elles sont des
      labels de CASE valides.
   🔒 Sécurité : valeurs figées par conception (étapes 0..6, causes
      bitfield 1,2,4,8,16,32,64,128) — jamais modifiables à l'exécution.
   📄 Doc métier : DOC/AF/AF_Partie-01_Analyse_Fonctionnelle_v2.1.md
   ═══════════════════════════════════════════════════════════════ *)

VAR_GLOBAL CONSTANT
    // === ETAPES SEQUENCE REARMEMENT (ArmingSeqStep reste INT) ===
    CST_STEP_IDLE      : INT := 0; // Repos
    CST_STEP_TEST_A    : INT := 1; // Autotest canal A
    CST_STEP_RESTORE_A : INT := 2; // Restauration canal A
    CST_STEP_TEST_B    : INT := 3; // Autotest canal B
    CST_STEP_RESTORE_B : INT := 4; // Restauration canal B
    CST_STEP_PULSE     : INT := 5; // Impulsion rearmement contacteur
    CST_STEP_CONFIRM   : INT := 6; // Attente confirmation contacteur

    // === CAUSES D'ABANDON (LastAbortCause, valeurs load-bearing IHM) ===
    // ⚠️ Type INT (décimal) : valeurs identiques aux anciens masques hex (1,2,4,8,16,32,64,128).
    //    LastAbortCause reste WORD (bitfield) : conversion implicite INT→WORD en CODESYS.
    CST_ABORT_NONE               : INT := 0;   // Aucun abandon
    CST_ABORT_CUT_IHM            : INT := 1;   // Coupure manuelle IHM
    CST_ABORT_CHAIN_DROP         : INT := 2;   // Chute boucle AU pendant impulsion/confirmation
    CST_ABORT_TIMEOUT_RESTORE_A  : INT := 4;   // Timeout restauration canal A
    CST_ABORT_TIMEOUT_RESTORE_B  : INT := 8;   // Timeout restauration canal B
    CST_ABORT_POWER_CUTOFF       : INT := 16;  // Coupure securite metier (PowerCutOff)
    CST_ABORT_REDUNDANCY_A       : INT := 32;  // Defaut redondance canal A
    CST_ABORT_REDUNDANCY_B       : INT := 64;  // Defaut redondance canal B
    CST_ABORT_TIMEOUT_CONTACTOR  : INT := 128; // Timeout confirmation contacteur
    CST_ABORT_INVALID_STEP       : INT := 256; // Etape sequence inconnue
END_VAR
