(* ═══════════════════════════════════════════════════════════════
   💾 GVL_PERSISTENT_AU — Variables persistantes chaîne AU
   ───────────────────────────────────────────────────────────────
   📄 Rôle : Regroupe les réglages persistants RETAIN propres au
      domaine Arrêt d'Urgence (FB_Safety_EmergencyManagement).
   🎯 Objectif : dissocier les réglages AU des autres domaines
      (treuils, benne, cycle, etc.) pour les bundles de test.
   🔒 RETAIN : survit aux arrêts/redémarrages PLC.
   ═══════════════════════════════════════════════════════════════
    📄 Docs : DOC/AF_Partie-01_Analyse_Fonctionnelle_v2.0.md
              DOC/AF_Partie-01_Analyse_Fonctionnelle_v2.0.md
*)

{attribute 'qualified_only'}
VAR_GLOBAL RETAIN
    // ⏱️ Temporisations de la séquence de réarmement (AF §3.5)
    // Les valeurs ci-dessous sont les défauts de la spec.
    // Ne pas modifier sans comprendre la séquence complète (auto-test A/B).
    TonTestDuration        : TIME := T#200ms;   // Test/Restore A ou B
    TonArmingPulseDuration : TIME := T#1s;      // Impulsion de réarmement
    TonArmingConfirmTimeout: TIME := T#2s;      // Timeout confirmation contacteur
    TonArmingLockout       : TIME := T#5s;      // Verrouillage anti-réessai

    // 🛡️ Configuration chaîne AU
    CfgEmergencyChainNormallyClosed : BOOL := TRUE;  // TRUE = boucle AU fermée = sain
    CfgContactorNormallyOpen        : BOOL := TRUE;  // TRUE = contacteur engagé = sain
END_VAR
