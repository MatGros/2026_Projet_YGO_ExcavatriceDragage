(* ═══════════════════════════════════════════════════════════════
   🎚️ ST_ModesHMI — Données d'échange IHM pour les modes de marche
   ───────────────────────────────────────────────────────────────
   🎨 Destiné à l'affichage et à la commande des modes sur l'IHM.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_ModesHMI :
STRUCT
    CurrentMode     : E_Mode; (* 🎚️ Mode de marche actuellement actif *)
    SelMode     : E_Mode := E_Mode.MAINT_N1; (* 🖥️ Demande de changement de mode de marche — accès N2 filtré côté IHM (REX 2026-07-07) *)
    EmergencyStopOk    : BOOL;   (* 🛡️ État de la chaîne d'arrêt d'urgence *)
    BtnFaultReset  : BOOL;   (* 🔔 Acquittement défauts/alarmes domaine sécurité/métier — JAMAIS Modes/Cycle (REX 2026-07-07, ex-MachineReset) *)
    BtnModeReset          : BOOL;   (* 🔁 Acquittement défaut FB_Modes uniquement (REX 2026-07-07) *)
    AnyFaultActive     : BOOL;   (* 🔴 REX 2026-07-07 : au moins un défaut/alarme actif dans le domaine
                                     sécurité/métier — s'éteint seul quand la cause disparaît ET que
                                     BtnFaultReset a été pressé (OR de tous les .Error du domaine,
                                     même périmètre que BtnFaultReset) *)
    PowerCutOffActive  : BOOL;   (* 🧨 REX 2026-07-07 : au moins un Méca A/B/C (FB_Safety_Winch) ou
                                     PowerCutOff Translation actif — TRUE = coupure demandée. Attention :
                                     PowerCutOff_A_RQ/B_RQ (sortie physique réelle) sont à la polarité
                                     INVERSÉE (fail-safe, TRUE=maintenu/OK) — ce champ IHM reste en
                                     polarité "alarme" (TRUE=problème) pour cohérence avec AnyFaultActive *)

    // 🔧 REX 2026-07-07 — Séquence réarmement AU (voir DOC/AF_Partie-01_Analyse_Fonctionnelle_v1.6.md §Sécurité électrique)
    BtnEmergencyArming : BOOL;   (* 🎮 Commande IHM réarmement contacteur puissance (front) — PAS de réarmement automatique *)
    BtnEmergencyCutOff : BOOL;   (* 🎮 Commande IHM coupure d'urgence puissance amont (arrêt à distance) *)
    EmergencyChainOk   : BOOL;   (* 🔗 Boucle AU saine (coup-de-poing relâchés + pas de PowerCutOff PLC actif) *)
    PowerContactorOk   : BOOL;   (* 🔌 Contacteur de puissance confirmé engagé (miroir EmergencyStopOk) *)
    EmergencyArmable   : BOOL;   (* 🟢 Réarmement possible maintenant (chaîne saine, ni séquence ni verrouillage en cours,
                                     ni RedundancyTestFailed) *)
    EmergencyArmingBusy: BOOL;   (* ⏳ Auto-test A/B, pulse, confirmation OU verrouillage 5s en cours — nouvelle demande ignorée *)
    RedundancyTestFailed  : BOOL; (* 🔴 Canal A ou B non fonctionnel détecté à l'auto-test — bloque tout réarmement (front Reset requis) *)
    EmergencyArmingFailed : BOOL; (* 🔴 Impulsion envoyée mais contacteur puissance jamais confirmé sous 2s (front Reset + contacteur confirmé requis) *)

    // 🔧 REX 2026-07-19 : rapatrié depuis GVL_IHM.IHM_MANU (suppression IHM_MANU) — TASK-0001,
    // sélection treuil au joystick, arbitrée par FB_Modes (MAINT_N2 uniquement, forcé à 3=Couplé sinon)
    SelJoystickWinch : INT; (* 🕹️ 1=M1 seul, 2=M2 seul, 3=Couplé — voir FB_Modes.JoystickWinchSelectArbitrated *)

    // 🆕 REX (session WINCH-BTN-01) — reouverture documentee doctrine T40 (voir
    // DOC/AUDITS/WinchIhmButtons/REGISTRE_ACTIONS_WinchIhmButtons_v1.0.md). Bascule UNIQUEMENT
    // la SOURCE du signal StartStop/Direction/SpeedRefPct (joystick vs boutons IHM) —
    // SelJoystickWinch ci-dessus reste l'unique autorite de selection treuil (M1/M2/Couple),
    // appliquee IDENTIQUEMENT quelle que soit la source. Accessible des MAINT_N1 (pas de mot
    // de passe), homme-mort joystick reel toujours obligatoire meme en pilotage boutons
    // (lecon precedent AF_Partie-11 v1.9 §6bis, bug Translation deja corrige).
    TglJoystickMaster : BOOL := TRUE; (* 🕹️ TRUE (defaut) = joystick pilote Winch (comportement historique, preserve au boot) ; FALSE = boutons IHM BtnUp/BtnDown *)
END_STRUCT
END_TYPE
