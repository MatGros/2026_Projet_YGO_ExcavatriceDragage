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
    // Mode pilotage unitaire M2 "sécurisé" -- actif
    // uniquement en SelJoystickWinch=2 (unitaire M2). Si TRUE : borne le déplacement entre les
    // positions ouvert/fermé configurées (OffsetOpenM/OffsetCloseM relatif à M1, mêmes bornes que
    // FB_Bucket) ET plafonne la vitesse au palier 1, sans passer par instBucket (pas de mémorisation
    // CloseReq/OpenReq, jogging libre borné). Défaut FALSE : pilotage unitaire M2 sans limite dédiée.
    TglManualBucketLimits : BOOL := TRUE; // Défaut TRUE -- pilotage unitaire M2 borné + palier 1 par défaut
    // Assistance "vidage à la trémie" (MAINT_N1/N2) : arme l'ouverture auto de la benne quand
    // M3 est stable à la Trémie. Indépendant du verrou descente treuil (WinchDescentAuth_M3).
    TglEnableDumpAtTremie : BOOL := FALSE;
END_STRUCT
END_TYPE
