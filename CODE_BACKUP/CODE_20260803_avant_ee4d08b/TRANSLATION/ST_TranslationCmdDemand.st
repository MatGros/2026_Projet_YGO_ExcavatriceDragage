(* ═══════════════════════════════════════════════════════════════
   ↔️ ST_TranslationCmdDemand — Demande de commande translation M3 (depuis cycle)
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF_Partie-12_Fonction_Diagnostic_v1.0.md
            DOC/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.0.md
   🎯 Demande de mouvement pour translation M3 (depuis FB_Cycle).
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_TranslationCmdDemand :
STRUCT
    Start   : BOOL;  // TRUE = démarrer mouvement
    Target  : INT;   // Cible de position (ex: 1=Trémie, 2=P2, 3=P1, 4=Maintenance)
END_STRUCT
END_TYPE