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
    // Bornes benne -- actif tant que TRUE, quel que soit le sélecteur treuil (unitaire M2 ou
    // couplé). Si TRUE : borne le déplacement entre les positions ouvert/fermé configurées
    // (OffsetOpenM/OffsetCloseM relatif à M1, mêmes bornes que FB_Bucket) ET plafonne la
    // vitesse au palier 1, sans passer par instBucket (pas de mémorisation CloseReq/OpenReq,
    // jogging libre borné). Défaut FALSE : pilotage benne sans limite dédiée.
    TglManualBucketLimits : BOOL := TRUE; // Défaut TRUE -- bornes benne actives + palier 1 par défaut
    // Assistance "vidage à la trémie" (MAINT_N1/N2) : arme l'ouverture auto de la benne quand
    // M3 est stable à la Trémie. Indépendant du verrou descente treuil (WinchDescentAuth_M3).
    TglEnableDumpAtTremie : BOOL := FALSE;
END_STRUCT
END_TYPE
