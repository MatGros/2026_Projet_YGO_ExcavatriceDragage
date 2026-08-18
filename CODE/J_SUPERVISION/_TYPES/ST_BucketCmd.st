(* ═══════════════════════════════════════════════════════════════
   🎮 ST_BucketCmd — Commandes IHM pour la benne (M2)
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_BucketCmd :
STRUCT
    BtnOpen             : BOOL; (* 🪣 Bouton commande ouverture *)
    BtnClose            : BOOL; (* 🪣 Bouton commande fermeture *)
    BtnReset            : BOOL; (* 🔑 Acquittement défaut benne *)
    BtnConfirmOpenPos   : BOOL; (* Référencement benne position ouverte (mise en service) — confirmation pure, aucun mouvement *)
    BtnConfirmClosePos  : BOOL; (* Référencement benne position fermée (mise en service) — confirmation pure, aucun mouvement *)
    // (18) : mode pilotage unitaire M2 "sécurisé" (demande client) -- actif
    // uniquement en SelJoystickWinch=2 (unitaire M2). Si TRUE : borne le déplacement entre les
    // positions ouvert/fermé configurées (OffsetOpenM/OffsetCloseM relatif à M1, mêmes bornes que
    // FB_Bucket) ET plafonne la vitesse au palier 1, sans passer par instBucket (pas de mémorisation
    // CloseReq/OpenReq, jogging libre borné). Défaut FALSE : pilotage unitaire M2 sans limite dédiée.
    TglManualBucketLimits : BOOL := TRUE; // (18bis) : défaut TRUE (demande client) -- pilotage unitaire M2 borné + palier 1 par défaut
END_STRUCT
END_TYPE
