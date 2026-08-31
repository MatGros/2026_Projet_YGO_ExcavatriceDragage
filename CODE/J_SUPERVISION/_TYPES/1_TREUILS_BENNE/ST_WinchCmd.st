(* ═══════════════════════════════════════════════════════════════
   🎮 ST_WinchCmd — Commandes IHM pour un Treuil M1/M2
   ───────────────────────────────────────────────────────────────
   🎨 Destiné au pilotage manuel et maintenance du treuil depuis l'IHM.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_WinchCmd :
STRUCT
    BtnUp               : BOOL;             (* ⬆️ Mouvement montee maintenu (mode boutons IHM, MAINT_N1 accessible) *)
    BtnDown             : BOOL;             (* ⬇️ Mouvement descente maintenu (mode boutons IHM, MAINT_N1 accessible) *)
    BtnReset            : BOOL;             (* 🔑 Demande reset exposée par treuil ; agrégée dans le reset domaine partagé *)
    BtnHome             : BOOL;             (* 🎯 Homing nominal si Couplé, unitaire si M1/M2 sélectionné en MAINT_N2 *)
    BtnConfirmCoherence : BOOL;             (* 🔓 Confirmation de cohérence au démarrage *)
    BtnInhibit          : BOOL;             (* Bouton IHM inhibition treuil — mise en service,
                                                    UNIQUEMENT actif si MAINT_N2 (voir FB_Modes.InhibitM1/M2) *)
    BtnHomingAtZero     : BOOL;             (* Force le homing à 0 m (points codeur centre),
                                                    sans devoir modifier CfgTopSensorPos_M *)
    BtnOverrideTopSoftware : BOOL;          (* Autorisation MAINTENUE de dépasser le FDC
                                                    haut LOGICIEL (7,5 m) jusqu'au capteur physique
                                                    (CfgTopSensorPos_M ≈ 8,5 m). Bouton, pas toggle :
                                                    relâché ➔ retour immédiat à 7,5 m. Sans effet hors
                                                    MAINT_N1 (N2 utilise le bypass latché
                                                    Bypass.TopLimitSoftware). N'ouvre JAMAIS le FDC
                                                    capteur physique. *)
    BtnLearnSpeed : BOOL;                   (* 💾 Bit IHM lancer l'apprentissage passif des vitesses
                                                    réelles par palier (FB_WinchSpeedLearning).
                                                    Collecteur STRICTEMENT PASSIF : aucune commande moteur.
                                                    Maintenu pendant la collecte ; la table RETAIN
                                                    _WinchSpeedLearnTable est remplie par palier/sens/
                                                    charge/vide. *)
END_STRUCT
END_TYPE
