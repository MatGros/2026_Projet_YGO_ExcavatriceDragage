(* ═══════════════════════════════════════════════════════════════
   ⚙️ ST_GrappinHMI — Données d'échange IHM pour le grappin
   ───────────────────────────────────────────────────────────────
   🎨 Intègre la configuration, l'état persistant et les commandes.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_GrappinHMI :
STRUCT
    (* ⚙️ Configurations & Paramètres (Lecture/Écriture RETAIN) *)
    Config              : ST_GrappinConfig; (* 🔧 Offsets Open/Close/Coherence *)
    TimeoutDuration     : TIME := T#30s;    (* ⏱️ Temps max pour l'ouverture/fermeture *)

    (* 🚦 États & Retours (Lecture seule) *)
    State               : ST_GrappinState;  (* 🚥 État mémorisé (IsOpen, IsClosed, etc.) *)
    FBState             : E_State;          (* 🤖 État de l'automate interne (FB_Grappin) *)
    ActiveOffsetM       : REAL;             (* 📐 Offset actif injecté dans la synchro *)
    M2StartStop         : BOOL;             (* 🛗 Commande Start/Stop forcée vers M2 *)
    M2Direction         : INT;              (* 🛗 Commande direction forcée vers M2 *)
    M2ForceSlowSpeed    : BOOL;             (* 🐢 Blocage vitesse rapide de M2 *)
    Ready               : BOOL;             (* 🟢 Bloc opérationnel *)
    Busy                : BOOL;             (* ⚙️ Mouvement d'ouverture/fermeture en cours *)
    Done                : BOOL;             (* ✅ Mouvement terminé avec succès *)
    Error               : BOOL;             (* 🔴 Grappin en défaut *)
    ErrorId             : WORD;             (* ❌ Code bitfield du défaut grappin *)

    (* 🎮 Commandes Opérateur (Boutons tactiles) *)
    CmdOpen             : BOOL;             (* 🪣 Bouton commande ouverture *)
    CmdClose            : BOOL;             (* 🪣 Bouton commande fermeture *)
    CmdReset            : BOOL;             (* 🔑 Acquittement défaut grappin *)
END_STRUCT
END_TYPE
