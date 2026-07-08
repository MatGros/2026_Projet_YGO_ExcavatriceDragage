(* ═══════════════════════════════════════════════════════════════
   🎚️ ST_ModesHMI — Données d'échange IHM pour les modes de marche
   ───────────────────────────────────────────────────────────────
   🎨 Destiné à l'affichage et à la commande des modes sur l'IHM.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_ModesHMI :
STRUCT
    CurrentMode     : E_Mode; (* 🎚️ Mode de marche actuellement actif *)
    ModeRequest     : E_Mode := E_Mode.MAINT_N1; (* 🖥️ Demande de changement de mode de marche — accès N2 filtré côté IHM (REX 2026-07-07) *)
    EmergencyStopOk    : BOOL;   (* 🛡️ État de la chaîne d'arrêt d'urgence *)
    FaultMachineReset  : BOOL;   (* 🔔 Acquittement défauts/alarmes domaine sécurité/métier — JAMAIS Modes/Cycle (REX 2026-07-07, ex-MachineReset) *)
    ModeReset          : BOOL;   (* 🔁 Acquittement défaut FB_Modes uniquement (REX 2026-07-07) *)
    AnyFaultActive     : BOOL;   (* 🔴 REX 2026-07-07 : au moins un défaut/alarme actif dans le domaine
                                     sécurité/métier — s'éteint seul quand la cause disparaît ET que
                                     FaultMachineReset a été pressé (OR de tous les .Error du domaine,
                                     même périmètre que FaultMachineReset) *)
    PowerCutOffActive  : BOOL;   (* 🧨 REX 2026-07-07 : au moins un Méca A/B/C (FB_Safety_Winch) ou
                                     PowerCutOff Chariot actif — TRUE = coupure demandée. Attention :
                                     PowerCutOff_A_RQ/B_RQ (sortie physique réelle) sont à la polarité
                                     INVERSÉE (fail-safe, TRUE=maintenu/OK) — ce champ IHM reste en
                                     polarité "alarme" (TRUE=problème) pour cohérence avec AnyFaultActive *)

    // 🔧 REX 2026-07-07 — Séquence réarmement AU (voir DOC/AF_Partie1 v1.5 §Sécurité électrique)
    CmdEmergencyArming : BOOL;   (* 🎮 Commande IHM réarmement contacteur puissance (front) — PAS de réarmement automatique *)
    CmdEmergencyCutOff : BOOL;   (* 🎮 Commande IHM coupure d'urgence puissance amont (arrêt à distance) *)
    EmergencyChainOk   : BOOL;   (* 🔗 Boucle AU saine (coup-de-poing relâchés + pas de PowerCutOff PLC actif) *)
    PowerContactorOk   : BOOL;   (* 🔌 Contacteur de puissance confirmé engagé (miroir EmergencyStopOk) *)
    EmergencyArmable   : BOOL;   (* 🟢 Réarmement possible maintenant (chaîne saine, ni séquence ni verrouillage en cours,
                                     ni RedundancyTestFailed) *)
    EmergencyArmingBusy: BOOL;   (* ⏳ Auto-test A/B, pulse, confirmation OU verrouillage 5s en cours — nouvelle demande ignorée *)
    RedundancyTestFailed  : BOOL; (* 🔴 Canal A ou B non fonctionnel détecté à l'auto-test — bloque tout réarmement (front Reset requis) *)
    EmergencyArmingFailed : BOOL; (* 🔴 Impulsion envoyée mais contacteur puissance jamais confirmé sous 2s (front Reset + contacteur confirmé requis) *)
END_STRUCT
END_TYPE
