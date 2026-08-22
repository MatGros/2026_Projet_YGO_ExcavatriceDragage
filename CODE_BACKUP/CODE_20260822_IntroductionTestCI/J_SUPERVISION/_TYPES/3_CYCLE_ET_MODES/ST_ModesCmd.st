(* ═══════════════════════════════════════════════════════════════
   🎮 ST_ModesCmd — Commandes IHM pour les modes de marche
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_ModesCmd :
STRUCT
    SelMode            : E_Mode := E_Mode.MAINT_N1; (* 🖥️ Demande de changement de mode de marche — accès N2 filtré côté IHM () *)
    BtnFaultReset      : BOOL;   (* 🔔 Acquittement défauts/alarmes domaine sécurité/métier — jamais Modes/Cycle *)
    BtnModeReset       : BOOL;   (* 🔁 Acquittement défaut FB_Modes uniquement () *)

    // — Séquence réarmement AU (voir DOC/AF/AF_Partie-01_Analyse_Fonctionnelle_v2.0.md §5)
    BtnEmergencyArming : BOOL;   (* 🎮 Commande IHM réarmement contacteur puissance (front) — PAS de réarmement automatique *)
    BtnEmergencyCutOff : BOOL;   (* 🎮 Commande IHM coupure d'urgence puissance amont (arrêt à distance) *)

    // Sélection treuil au joystick, arbitrée par FB_Modes (0=couplé nominal, 1/2 unitaires MAINT_N2 uniquement)
    SelJoystickWinch   : INT := 0; (* 🕹️ 0=M1+M2 couplés (nominal), 1=M1 seul, 2=M2 seul — unitaires MAINT_N2 uniquement *)

    // — bascule UNIQUEMENT la SOURCE du signal StartStop/Direction/
    // SpeedRefPct (joystick vs boutons IHM) — SelJoystickWinch ci-dessus reste l'unique autorité de
    // sélection treuil (M1/M2/Couplé), appliquée IDENTIQUEMENT quelle que soit la source.
    // 🔀 Switch machine unique — pilote aussi Translation M3.
    TglJoystickMaster  : BOOL := TRUE; (* 🕹️ TRUE (défaut) = joystick pilote Winch M1/M2 ET Translation M3 ; FALSE = boutons IHM (BtnUp/BtnDown, BtnFwd/BtnRev) *)
END_STRUCT
END_TYPE
