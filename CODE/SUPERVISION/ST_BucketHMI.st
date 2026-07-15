(* ═══════════════════════════════════════════════════════════════
   ⚙️ ST_BucketHMI — Données d'échange IHM pour le benne
   ───────────────────────────────────────────────────────────────
   🎨 Intègre la configuration, l'état persistant et les commandes.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_BucketHMI :
STRUCT
    (* ⚙️ Configurations & Paramètres (Lecture/Écriture RETAIN) *)
    Config              : ST_BucketConfig; (* 🔧 Offsets Open/Close/Coherence *)
    TimeoutDuration     : TIME := T#30s;    (* ⏱️ Temps max pour l'ouverture/fermeture *)

    (* 🚦 États & Retours (Lecture seule) *)
    State               : ST_BucketState;  (* 🚥 État mémorisé (IsOpen, IsClosed, etc.) *)
    FBState             : E_State;          (* 🤖 État de l'automate interne (FB_Bucket) *)
    ActiveOffsetM       : REAL;             (* 📐 Offset actif injecté dans la synchro *)
    M2StartStop         : BOOL;             (* 🛗 Commande Start/Stop forcée vers M2 *)
    M2Direction         : INT;              (* 🛗 Commande direction forcée vers M2 *)
    M2ForceSlowSpeed    : BOOL;             (* 🐢 Blocage vitesse rapide de M2 *)
    Ready               : BOOL;             (* 🟢 Bloc opérationnel *)
    Busy                : BOOL;             (* ⚙️ Mouvement d'ouverture/fermeture en cours *)
    Done                : BOOL;             (* ✅ Mouvement terminé avec succès *)
    Error               : BOOL;             (* 🔴 Benne en défaut *)
    ErrorId             : WORD;             (* ❌ Code bitfield du défaut benne *)
    RemainingTravelM    : REAL;             (* 📏 REX 2026-07-07 : distance restante avant cible (m),
                                                pour jauge/aiguille IHM — 0.0 hors mouvement *)
    CloseReq            : BOOL;             (* 🆕 REX 2026-07-08 : demande de fermeture active (image FB_Bucket) —
                                                FALSE dès la cible atteinte OU le retour à la position de départ *)
    OpenReq             : BOOL;             (* 🆕 REX 2026-07-08 : demande d'ouverture active (image FB_Bucket), même principe *)
    M2PositionCorrected : REAL;             (* 📊 REX 2026-07-07 : WinchM2.PositionM - ActiveOffsetM —
                                                pure valeur d'AFFICHAGE (bargraphe), égale à WinchM1.PositionM
                                                quand tout est nominal ; ne remplace PAS DeltaPosM (Sync),
                                                qui reste la valeur de sécurité/surveillance de référence *)

    (* 🎮 Commandes Opérateur (Boutons tactiles) *)
    CmdOpen             : BOOL;             (* 🪣 Bouton commande ouverture *)
    CmdClose            : BOOL;             (* 🪣 Bouton commande fermeture *)
    CmdReset            : BOOL;             (* 🔑 Acquittement défaut benne *)
    CmdConfirmOpenPosition : BOOL;          (* 🆕 REX 2026-07-08 : référencement benne position ouverte (mise en
                                                service) — confirmation pure, AUCUN mouvement, à utiliser juste après
                                                le référencement des codeurs M1/M2 (benne physiquement ouvert) *)
    CmdConfirmClosePosition : BOOL;         (* 🆕 REX 2026-07-08 : référencement benne position fermée (mise en
                                                service) — confirmation pure, AUCUN mouvement, à utiliser juste après
                                                le référencement des codeurs M1/M2 (benne physiquement fermé) *)
END_STRUCT
END_TYPE
