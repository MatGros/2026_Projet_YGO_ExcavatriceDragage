(* ═══════════════════════════════════════════════════════════════
   ST_BypassCommun — Bypass maintenance GRANULAIRE, applicable aux 2 treuils à la fois
   ───────────────────────────────────────────────────────────────
   🎨 Distinct des bypass individuels M1/M2 (ST_BypassWinch)
      un OUI ici lève la protection sur LES DEUX treuils simultanément (pilotage "both",
      GVL_IHM.Commun.BtnWinchBothAscent/Descent), en OR avec le bypass individuel de chaque instance
      (PRG_04_Treuils_Benne). Évite de devoir activer 2 fois le même bypass (M1 ET M2) avant un
      pilotage groupé — SANS retirer les bypass individuels pour le pilotage à l'unité.
      ⚠️ Ne remplace PAS les bypass individuels : les deux se combinent en OR, jamais l'un
      n'entraîne la désactivation de l'autre.
   🔒 Doctrine : actionnable UNIQUEMENT en MAINT_N2, RETAIN, jamais masque
      les autres défauts du même bloc (voir REGISTRE_ACTIONS_Bypass_v1.0 (archive)).
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_BypassCommun :
STRUCT
    Global            : BOOL; (* 🌐 Bypass Global Commun (toutes sécurités communes M1+M2) *)
    SlackCable        : BOOL; (* ⚠️ Bypass capteur mou de câble — capteur unique M1/M2, OR avec bypass individuel *)
    TopLimitSwitch    : BOOL; (* 🚧 Bypass fin de course physique haute (capteur, bit5), OR avec bypass individuel *)
    TopLimitSoftware  : BOOL; (* : Bypass fin de course logiciel haut (position calculée), OR avec bypass individuel *)
    CableLimitSwitch  : BOOL; (* : Bypass limite basse physique (longueur câble), OR avec bypass individuel *)
    LimitLegal        : BOOL; (* : Bypass limite légale de profondeur, OR avec bypass individuel *)
    Initialized       : BOOL; (* Initialisé au boot *)
END_STRUCT
END_TYPE
