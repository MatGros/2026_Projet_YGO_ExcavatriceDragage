(* =======================================================================
   🎯 E_TranslationTraceBlockReason — Cause de blocage priorisée translation M3
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Ordre de priorité de la cause de blocage de la translation M3,
      calculé en PRG_05_Translation et publié via Data.TranslationTrace.
      L'ordre de l'enum EST l'ordre de priorité (valeur croissante = priorité
      décroissante) : la cause la plus grave gagne (PowerCutOff > … > NONE).
   📤 Producteur unique : PRG_05_Translation.
   📥 Consommateur : FB_TroubleshootingView (recopie → GVL_Troubleshooting.S_TraceTranslation).
   🔒 Lecture seule — aucune action de conduite n'en dépend.
   📄 Doc métier : DOC/AF/AF_Partie-14_Fonction_Troubleshooting/FB_TroubleshootingView_v1.2.md
   ======================================================================= *)
{attribute 'qualified_only'}
TYPE E_TranslationTraceBlockReason :
(
    NONE              := 0,   // ✅ Aucun blocage — permis de mouvement effectif
    POWER_CUTOFF      := 1,   // 🧨 Coupure puissance amont (instSafetyTranslationM3.PowerCutOff) — priorité max
    SAFESTOP          := 2,   // 🟧 SafeStop effectif (InputModule OR safety M3)
    SAFETY_FAULT      := 3,   // 🛡️ Défaut safety M3 latched (FB_Safety_Translation.Fault.Error)
    HEIGHT_INTERLOCK  := 4,   // 🚧 Interlock hauteur M1/M2 actif (risque collision)
    DRIVE_UNAVAILABLE := 5,   // 📡 Variateur AC600 injoignable / non opérationnel
    FINAL_INTERLOCK   := 6,   // 🛑 Barrière finale en défaut (frein / redémarrage)
    FAULT             := 7    // ❌ Défaut mouvement M3 latched (FB_Translation.Fault.Error)
);
END_TYPE
