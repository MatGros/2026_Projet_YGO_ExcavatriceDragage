(* ═══════════════════════════════════════════════════════════════
   ↔️ ST_ChariotHMI — Données d'échange IHM pour le Chariot M3
   ───────────────────────────────────────────────────────────────
   🎨 Destiné à l'affichage des états, commandes et diagnostics du chariot.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_ChariotHMI :
STRUCT
    FBState                 : E_State; (* 🤖 État de l'automate interne (FB_Chariot) *)
    Ready                   : BOOL;    (* 🟢 Chariot prêt à fonctionner *)
    Busy                    : BOOL;    (* ⚙️ Mouvement en cours *)
    Done                    : BOOL;    (* ✅ Mouvement terminé avec succès *)
    Error                   : BOOL;    (* 🔴 Chariot en défaut *)
    ErrorId                 : WORD;    (* ❌ Code du défaut actif *)
    BrakeCmd                : BOOL;    (* 🔓 Commande de desserrage du frein *)
    BrakeFeedback           : BOOL;    (* 🔌 Retour physique de l'état du frein *)
    PositionSensorTarget    : BOOL;    (* 🎯 Capteur de détection de la position cible atteint *)
    SelectedTargetNum       : INT;     (* 🔢 Numéro de la cible de position sélectionnée *)
    DriveStatusWord         : WORD;    (* 📡 Mot d'état du variateur (EtherCAT) *)
    DriveActualFreqHz       : REAL;    (* 📈 Fréquence de sortie réelle du variateur (Hz) *)
    BypassContactorFeedback : BOOL;    (* 🔌 Activation du bypass des retours contacteurs *)
    BypassBrakeFeedback     : BOOL;    (* 🔓 Activation du bypass du retour frein *)
    SafetyError             : BOOL;    (* 🛡️ Bloc sécurité (Safety) en défaut *)
    SafetyErrorId           : WORD;    (* ❌ Code bitfield du défaut de sécurité *)
END_STRUCT
END_TYPE
