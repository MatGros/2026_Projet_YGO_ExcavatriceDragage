(* ═══════════════════════════════════════════════════════════════
   🌐 ST_CommunHMI — Données d'échange IHM COMMUNES (pas propres à un axe)
   ───────────────────────────────────────────────────────────────
   🆕 REX 2026-07-08 (demande utilisateur) : regroupe les signaux qui ne concernent
   PAS un axe/mécanisme en particulier (1 seul capteur/signal partagé par toute la
   machine) — évite de les dupliquer ou de les laisser en variables isolées
   directement dans GVL_IHM. Exemple : TopPositionSensorActive (capteur unique,
   commun M1+M2), BrakeThermalFault (retour unique, commun M1+M2+M3).
   ⚠️ Ne pas y mettre HmiInitDone (indicateur interne de séquencement boot, pas une
   information machine destinée à l'opérateur) — reste seul dans GVL_IHM.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_CommunHMI :
STRUCT
    TopPositionSensorActive   : BOOL; (* ⚠️ Capteur de position haute commun M1+M2 détecté *)
    BrakeThermalFault         : BOOL; (* 🌡️ Défaut/perte thermique frein — retour unique commun M1/M2/M3, escalade PowerCutOff *)
    PhaseRotationFault        : BOOL; (* 🆕 REX 2026-07-08 : rotation de phase incorrecte — retour unique commun M1/M2/M3
                                          (auparavant invisible IHM, seulement décodable via SafetyErrorId bit4/bit2) *)
    LimitLegalReached         : BOOL; (* 📐 Limite légale de profondeur de dragage atteinte (globale) *)
    Cfg                       : ST_CommunCfg; (* 🔧 Configuration des paramètres communs machine *)
    HydraulicThermalFault     : BOOL; (* 🆕 REX 2026-07-18 : défaut/perte thermique centrale hydraulique
                                          (PRG_08_AuxiliaryControl, diagnostic seul — aucune commande PLC) *)

    (* 🔧 Bypass maintenance de capteurs COMMUNS (voir REGISTRE_ACTIONS_Bypass_v1.0 (archive)) *)
    Bypass : ST_BypassCommun;    (* SlackCable, TopPositionSensor — capteur physique unique M1/M2, jamais duplique par axe *)

    (* 💓 Heartbeat IHM↔PLC — IHM inverse TglHeartbeatIhm toutes les 500 ms. *)
    TglHeartbeatIhm        : BOOL; (* IHM→PLC : toggle périodique, jamais valeur constante *)
    TglHeartbeatPlc        : BOOL; (* PLC→IHM : clignotant activité PLC *)
    HeartbeatIhmOk            : BOOL; (* PLC→IHM : front IHM post-boot reçu et timeout absent *)
    HeartbeatIhmTimeout       : BOOL; (* PLC→IHM : aucun front IHM depuis 2 s *)
    HeartbeatIhmElapsed       : TIME; (* PLC→IHM : temps depuis dernier front IHM *)

    // 🆕 Boutons pilotage direct des 2 treuils (communs, remplace SelJoystickWinch en mode boutons)
    BtnWinchBothUp     : BOOL; (* ⬆️ Monte les 2 treuils simultanément *)
    BtnWinchBothDown   : BOOL; (* ⬇️ Descend les 2 treuils simultanément *)

    // 🐛 FIX 2026-07-23 : alarme restauration config PERSISTENT (RETAIN invalidé, ex. changement de
    // struct ST_*HMI) — visible et acquittable, jamais de disparition automatique silencieuse
    // (doctrine reset=front, PRG_09_Supervision.st §2bis). Vérifier les valeurs avant reprise cycle.
    ConfigRestoredFromPersistent : BOOL; (* ⚠️ PLC→IHM : restauration détectée ce boot, à vérifier *)
    BtnAckConfigRestored         : BOOL; (* 🔘 IHM→PLC : acquittement opérateur (front) *)

    Preflight : ST_PreflightHMI; (* 🩺 Verdict observateur à l'arrêt — jamais bloquant *)
    WinchSymmetry : ST_WinchSymmetryHMI; (* ⚖️ MES-008 : mesures passives M1/M2 *)
END_STRUCT
END_TYPE
