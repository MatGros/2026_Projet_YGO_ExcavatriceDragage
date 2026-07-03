(* ═══════════════════════════════════════════════════════════════
   🎛️ GVL_IHM — Variables globales d'échange pour l'IHM
   ───────────────────────────────────────────────────────────────
   📄 Lot A : Mise en service et calibration de la machine de dragage.
   💾 Déclaré en RETAIN pour la persistance des configurations opérateur.
   ═══════════════════════════════════════════════════════════════ *)
VAR_GLOBAL RETAIN
    WinchM1 : ST_WinchHMI;  (* 🛗 Variables d'échange IHM Treuil Principal M1 *)
    WinchM2 : ST_WinchHMI;  (* 🛗 Variables d'échange IHM Treuil Auxiliaire M2 *)
    Grappin : ST_GrappinHMI;(* 🪣 Variables d'échange IHM Mécanisme Grappin *)
    Sync    : ST_SyncHMI;   (* ⚖️ Variables d'échange IHM Surveillance de synchro *)
END_VAR
