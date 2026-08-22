(* ═══════════════════════════════════════════════════════════════
   🎮 ST_ModesCmd — Commandes IHM pour les modes de marche
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_ModesCmd :
STRUCT
    SelMode            : E_Mode := E_Mode.MAINT_N1; (* 🖥️ Demande de changement de mode de marche — accès N2 filtré côté IHM (REX 2026-07-07) *)
    BtnFaultReset      : BOOL;   (* 🔔 Acquittement défauts/alarmes domaine sécurité/métier — JAMAIS Modes/Cycle (REX 2026-07-07, ex-MachineReset) *)
    BtnModeReset       : BOOL;   (* 🔁 Acquittement défaut FB_Modes uniquement (REX 2026-07-07) *)

    // 🔧 REX 2026-07-07 — Séquence réarmement AU (voir DOC/AF_Partie-01_Analyse_Fonctionnelle_v2.0.md §5)
    BtnEmergencyArming : BOOL;   (* 🎮 Commande IHM réarmement contacteur puissance (front) — PAS de réarmement automatique *)
    BtnEmergencyCutOff : BOOL;   (* 🎮 Commande IHM coupure d'urgence puissance amont (arrêt à distance) *)

    // 🔧 REX 2026-07-19 : rapatrié depuis GVL_IHM.IHM_MANU (suppression IHM_MANU) — TASK-0001,
    // sélection treuil au joystick, arbitrée par FB_Modes (0=couplé nominal, 1/2 unitaires MAINT_N2 uniquement)
    SelJoystickWinch   : INT := 0; (* 🕹️ 0=M1+M2 couplés (nominal), 1=M1 seul, 2=M2 seul — unitaires MAINT_N2 uniquement *)

    // 🆕 REX (session WINCH-BTN-01) — bascule UNIQUEMENT la SOURCE du signal StartStop/Direction/
    // SpeedRefPct (joystick vs boutons IHM) — SelJoystickWinch ci-dessus reste l'unique autorité de
    // sélection treuil (M1/M2/Couplé), appliquée IDENTIQUEMENT quelle que soit la source.
    // 🔀 2026-08-06 : consolidé en switch UNIQUE machine — pilote aussi Translation M3
    // (ex GVL_IHM.TranslationM3.Cmd.TglJoystickMaster, supprimé, doublon). ⚠️ Le défaut TRUE
    // (joystick) s'applique désormais à M3 aussi au boot — M3 démarrait avant en boutons IHM
    // (FALSE) : changement de comportement au démarrage, assumé (décision 2026-08-06).
    TglJoystickMaster  : BOOL := TRUE; (* 🕹️ TRUE (défaut) = joystick pilote Winch M1/M2 ET Translation M3 (comportement historique Winch, préservé au boot) ; FALSE = boutons IHM (BtnUp/BtnDown, BtnFwd/BtnRev) *)
END_STRUCT
END_TYPE
