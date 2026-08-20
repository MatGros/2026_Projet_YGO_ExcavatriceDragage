(* ═══════════════════════════════════════════════════════════════
   🌐 ST_CommunHMI — Données d'échange IHM COMMUNES (pas propres à un axe)
   ───────────────────────────────────────────────────────────────
   Regroupe les signaux qui ne concernent
   PAS un axe/mécanisme en particulier (1 seul capteur/signal partagé par toute la
   machine) — évite de les dupliquer ou de les laisser en variables isolées
   directement dans GVL_IHM. Exemple : TopPositionSensorActive (capteur unique,
   commun M1+M2), BrakeThermalFault (retour unique, commun M1+M2+M3).
   ⚠️ Ne pas y mettre HmiInitDone (indicateur interne de séquencement boot, pas une
   information machine destinée à l'opérateur) — reste seul dans GVL_IHM.
   🧭 Structuration homogène : états → Cfg → Bypass (Cfg au-dessus de Bypass,
   Bypass en bas), cohérent avec ST_WinchHMI / ST_SyncHMI.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_CommunHMI :
STRUCT
    TopPositionSensorActive   : BOOL; (* ⚠️ Capteur de position haute commun M1+M2 détecté *)
    BrakeThermalFault         : BOOL; (* 🌡️ Défaut/perte thermique frein — retour unique commun M1/M2/M3, escalade PowerCutOff *)
    PhaseRotationFault        : BOOL; (* : rotation de phase incorrecte — retour unique commun M1/M2/M3
                                          (auparavant invisible IHM, seulement décodable via SafetyErrorId bit4/bit2) *)
    LimitLegalReached         : BOOL; (* 📐 Limite légale de profondeur de dragage atteinte (globale) *)
    HydraulicThermalFault     : BOOL; (* : défaut/perte thermique centrale hydraulique
                                          (PRG_AUXILIARY_CFC, diagnostic seul — aucune commande PLC) *)

    (* 🩺 Indicateurs diagnostic simulation — PLC→IHM, pas des bypass opérateur *)
    SimTopSensorBypassActive  : BOOL; (* 🩺 Capteur haut ignoré car simulation active *)
    SimSlackCableBypassActive : BOOL; (* 🩺 Mou de câble ignoré car simulation active *)
    WinchInputSourceChanged   : BOOL; (* 🔀 PLC→IHM : source Winch a basculé (réel/simu) ce cycle *)

    (* 💓 Heartbeat IHM↔PLC — IHM inverse TglHeartbeatIhm toutes les 500 ms. *)
    TglHeartbeatIhm        : BOOL; (* IHM→PLC : toggle périodique, jamais valeur constante *)
    TglHeartbeatPlc        : BOOL; (* PLC→IHM : clignotant activité PLC *)
    HeartbeatIhmOk            : BOOL; (* PLC→IHM : front IHM post-boot reçu et timeout absent *)
    HeartbeatIhmTimeout       : BOOL; (* PLC→IHM : aucun front IHM depuis 2 s *)
    HeartbeatIhmElapsed       : TIME; (* PLC→IHM : temps depuis dernier front IHM *)

    // Boutons pilotage direct des 2 treuils (communs, remplace SelJoystickWinch en mode boutons)
    BtnWinchBothUp     : BOOL; (* ⬆️ Monte les 2 treuils simultanément *)
    BtnWinchBothDown   : BOOL; (* ⬇️ Descend les 2 treuils simultanément *)

    // Alarme restauration config PERSISTENT (RETAIN invalidé, ex. changement de
    // struct ST_*HMI) — visible et acquittable, jamais de disparition automatique silencieuse
    // (doctrine reset=front, PRG_SUPERVISION_CFC.st §2bis). Vérifier les valeurs avant reprise cycle.
    ConfigRestoredFromPersistent : BOOL; (* ⚠️ PLC→IHM : restauration détectée ce boot, à vérifier *)
    BtnAckConfigRestored         : BOOL; (* 🔘 IHM→PLC : acquittement opérateur (front) *)

    Preflight : ST_PreflightHMI; (* 🩺 Verdict observateur à l'arrêt — jamais bloquant *)
    WinchSymmetry : ST_WinchSymmetryHMI; (* ⚖️ Mesures passives M1/M2 *)

    (* 🩺 Diagnostic arrêt auto descente Kobold (pilotage normal) *)
    KoboldImmersionConfirmed : BOOL; (* Front Kobold confirmé dans la fenêtre d'immersion *)
    KoboldBottomTouchLatched : BOOL; (* Fond détecté, descente bloquée (DescendPermitM1/M2_Raw) *)

    (* 📐 Configuration des paramètres communs machine (au-dessus des bypass) *)
    Cfg : ST_CommunCfg;

    (* 🔒 Bypass maintenance de capteurs COMMUNS (voir REGISTRE_ACTIONS_Bypass_v1.0 (archive)) *)
    Bypass : ST_BypassCommun;    (* : granulaire, applique le bypass aux 2 treuils simultanément (pilotage "both") — OR avec le bypass individuel M1/M2 dans PRG_04 *)
END_STRUCT
END_TYPE
