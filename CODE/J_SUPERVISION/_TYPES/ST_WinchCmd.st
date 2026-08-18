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
END_STRUCT
END_TYPE
