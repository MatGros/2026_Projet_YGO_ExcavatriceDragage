(* =======================================================================
   ↔️ ST_TraceTranslation — Trace de blocage terrain de la translation M3
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Publier au technicien « pourquoi la translation M3 ne bouge pas » :
      permis de mouvement effectif, interlock hauteur, source SafeStop/coupure
      et cause de blocage priorisée.
   📤 Producteur unique : PRG_05_Translation (Data.TranslationTrace).
   📥 Consommateur : FB_TroubleshootingView (pure recopie → GVL_Troubleshooting.S_TraceTranslation).
   🔒 Lecture seule — aucun calcul de commande n'en dépend.
   🕒 BlockReasonTimestamp : ms depuis démarrage PLC (TIME()), latched au dernier
      changement de BlockReason (1 scan, mémoire).
   📄 Doc métier : DOC/AF/AF_Partie-14_Fonction_Troubleshooting/FB_TroubleshootingView_v1.2.md
   ======================================================================= *)
TYPE ST_TraceTranslation :
STRUCT
    // Permis de mouvement effectif (agrégat diagnostic : toutes les barrières levées)
    MotionPermitEffective    : BOOL;   // 🟢 Translation réellement autorisée à se déplacer
    // Permis directionnels par sens (reflet exact des permis appliqués au mouvement M3)
    EffectivePermitM3_Tremie      : BOOL;   // 🟢 Permis canonique M3 vers Trémie (reflet lecture seule)
    EffectivePermitM3_Maintenance : BOOL;   // 🟢 Permis canonique M3 vers Maintenance/P1 (reflet lecture seule)
    TremieProcessBlockActive : BOOL;   // 🛑 Approche trémie interdite par process (trémie pleine / grille levée) — recul libre. Motif du permis trémie rouge.
    HeightInterlockBlocking  : BOOL;   // 🚧 Interlock hauteur M1/M2 actif (risque collision)

    // Source de blocage — pour distinguer l'origine
    SafeStopActive           : BOOL;   // 🟧 SafeStop effectif appliqué (M3_SafeStop_Aggregate)
    SafeStopSourceInput      : BOOL;   // 📥 SafeStop issu du module d'entrée (InputModuleFault)
    SafeStopSourceSafety     : BOOL;   // 🛡️ SafeStop issu de FB_Safety_Translation (défaut safety)
    PowerCutOffActive        : BOOL;   // 🧨 Coupure puissance amont active
    DriveOperational         : BOOL;   // 📡 Variateur AC600 opérationnel

    // Barrière finale (frein / redémarrage)
    FinalInterlockError      : BOOL;   // 🛑 Défaut barrière finale (frein / redémarrage)

    // Cause de blocage priorisée + horodatage
    BlockReason              : E_TranslationTraceBlockReason; // 🎯 Cause de blocage prioritaire (ordre de priorité croissant)
    BlockReasonTimestamp     : UDINT;  // 🕒 ms depuis démarrage PLC (TIME()) — dernier changement de BlockReason
END_STRUCT
END_TYPE
