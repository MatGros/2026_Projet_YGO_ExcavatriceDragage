(* ═══════════════════════════════════════════════════════════════
   🚦 ST_BucketHMIState — États et diagnostics IHM de la benne (M2)
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_BucketHMIState :
STRUCT
    MechState           : ST_fbBucket_State; (* 🚥 État mécanique mémorisé (IsOpen, IsClosed...) *)
    FBState             : E_State;          (* 🤖 État de l'automate interne (FB_Bucket) *)
    ActiveOffset_M        : REAL;             (* 📐 Offset actif injecté dans la synchro *)
    M2StartStop         : BOOL;             (* 🛗 Commande Start/Stop forcée vers M2 *)
    M2Direction         : INT;              (* 🛗 Commande direction forcée vers M2 *)
    M2ForceSlowSpeed    : BOOL;             (* 🐢 Blocage vitesse rapide de M2 *)
    Ready               : BOOL;             (* 🟢 Bloc opérationnel *)
    Busy                : BOOL;             (* ⚙️ Mouvement d'ouverture/fermeture en cours *)
    Done                : BOOL;             (* ✅ Mouvement terminé avec succès *)
    Error               : BOOL;             (* Benne en défaut *)
    ErrorId             : WORD;             (* ❌ Code bitfield du défaut benne *)
    RemainingTravel_M     : REAL;             (* 📏 Distance restante avant cible (m) *)
    DeltaPosition_M       : REAL;             (* 📏 Écart réel signé M2 - M1 (mètres) pour jauge/bargraphe IHM *)
    CloseActive            : BOOL;             (* Demande de fermeture active (image FB_Bucket) *)
    OpenActive             : BOOL;             (* Demande d'ouverture active (image FB_Bucket) *)
    M2PositionCorrected : REAL;             (* 📊 WinchM2.PositionM - ActiveOffset_M, affichage bargraphe *)
    AutoBucketSeqActive : BOOL;             (* ⚙️ Séquencement automatique benne en cours (ouverture/fermeture auto) *)
    CoupledDiveOpenArmed    : BOOL;         (* : Ouverture auto armée (descente couplée demandée, benne pas ouverte) *)
    CoupledAscentCloseArmed : BOOL;         (* : Fermeture auto armée (montée couplée demandée, benne pas fermée) *)
    ControlAscentActive     : BOOL;         (* : Phase vitesse contrôlée montée en cours (post-fermeture auto) *)
    CoupledMotionBlockedByBucket : BOOL;    (* : Mouvement couplé bloqué -- auto-séquencement armé mais benne pas Busy (défaut/précondition) *)
END_STRUCT
END_TYPE
