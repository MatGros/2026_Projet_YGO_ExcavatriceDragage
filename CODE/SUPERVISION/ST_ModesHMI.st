(* ═══════════════════════════════════════════════════════════════
   🎚️ ST_ModesHMI — Données d'échange IHM pour les modes de marche
   ───────────────────────────────────────────────────────────────
   🎨 Destiné à l'affichage et à la commande des modes sur l'IHM.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_ModesHMI :
STRUCT
    CurrentMode     : E_Mode; (* 🎚️ Mode de marche actuellement actif *)
    ModeRequest     : E_Mode := E_Mode.MAINT_N1; (* 🖥️ Demande de changement de mode de marche *)
    PasswordOk      : BOOL;   (* 🔑 Authentification pour le mode maintenance N2 *)
    EmergencyStopOk : BOOL;   (* 🛡️ État de la chaîne d'arrêt d'urgence *)
    MachineReset    : BOOL;   (* 🔁 Commande d'acquittement général de la machine *)
END_STRUCT
END_TYPE
