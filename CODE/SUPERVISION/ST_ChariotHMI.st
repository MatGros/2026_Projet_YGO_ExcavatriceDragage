(* ═══════════════════════════════════════════════════════════════
   ↔️ ST_ChariotHMI — Données d'échange IHM pour le Chariot M3
   ───────────────────────────────────────────────────────────────
   🎨 Destiné à l'affichage des états, commandes et diagnostics du chariot.
   📄 Migration des champs manuels ex-ST_IHM_MANU (étape en cours, pas l'état final) —
      doc métier : DOC/AF_Partie-11_Fonction_Chariot_v1.6.md
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_ChariotHMI :
STRUCT
    (* 🎮 Commandes opérateur (manuel / maintenance) *)
    SelectedTargetNum       : INT;     (* 🔢 Numéro de la cible de position sélectionnée *)
    ReqFwd                  : BOOL;    (* ↔️ Requête marche avant manuelle (bouton IHM, pas encore arbitrée) *)
    ReqRev                  : BOOL;    (* ↔️ Requête marche arrière manuelle (bouton IHM, pas encore arbitrée) *)
    FreqSetpointHz          : REAL;    (* 🎯 Consigne fréquence manuelle [Hz], clampée par PRG_10_Outputs *)

    (* 🚦 États & diagnostics FB_Chariot *)
    FBState                 : E_State; (* 🤖 État de l'automate interne (FB_Chariot) *)
    Ready                   : BOOL;    (* 🟢 Chariot prêt à fonctionner *)
    Busy                    : BOOL;    (* ⚙️ Mouvement en cours *)
    Done                    : BOOL;    (* ✅ Mouvement terminé avec succès *)
    Error                   : BOOL;    (* 🔴 Chariot en défaut *)
    ErrorId                 : WORD;    (* ❌ Code du défaut actif *)
    BrakeCmd                : BOOL;    (* 🔓 Commande de desserrage du frein (lecture seule, TRUE = desserré) *)
    BrakeFeedback           : BOOL;    (* 🔌 Retour physique de l'état du frein *)
    PositionSensorTarget    : BOOL;    (* 🎯 Capteur de détection de la position cible atteint *)
    DriveActualFreqHz       : REAL;    (* 📈 Fréquence de sortie réelle du variateur (Hz) *)

    (* 🔌 Diagnostic variateur EtherCAT (décodé — pas de bit-masking côté IHM) *)
    DriveCommReady          : BOOL;    (* 📡 Variateur M3 : communication prête (StatusWord bit7) *)
    DrivePowerReady         : BOOL;    (* ⚡ Variateur M3 : puissance prête (StatusWord bit0) *)

    (* 🐞 Bypass diag (banc de test — auto-calculé depuis GVL_Simulation) *)
    BypassContactorFeedback : BOOL;    (* 🔌 Activation du bypass des retours contacteurs (sens + frein) *)

    (* 🛡️ Sécurité (FB_Safety_Chariot) *)
    SafetyError             : BOOL;    (* 🛡️ Bloc sécurité (Safety) en défaut *)
    SafetyErrorId           : WORD;    (* ❌ Code bitfield du défaut de sécurité *)
END_STRUCT
END_TYPE
