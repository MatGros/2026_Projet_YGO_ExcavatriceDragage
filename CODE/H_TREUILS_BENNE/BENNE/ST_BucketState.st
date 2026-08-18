(* =======================================================================
   🚦 ST_BucketState — État mémorisé et diagnostic du benne
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Structure d'état physique mémorisé et de diagnostic du benne
   📄 Doc métier : DOC/AF/AF_Partie-10_Fonction_Winch_v2.0.md
   ======================================================================= *)
TYPE ST_BucketState :
STRUCT
    IsOpen          : BOOL;                                           // Benne ouvert memorise
    IsClosed        : BOOL;                                           // Benne ferme memorise
    TooOpen         : BOOL;                                           // Depassement ouverture (Delta < OffsetOpen - Tolerance)
    TooClosed       : BOOL;                                           // Depassement fermeture (Delta > OffsetClose + Tolerance)
    IsIntermediate  : BOOL;                                           // Position intermediaire (entre Ouvert et Ferme)
    LastPosM2Open   : REAL;                                           // Derniere position M2 memorisee ouvert (m)
    LastPosM2Close  : REAL;                                           // Derniere position M2 memorisee ferme (m)
    StateIncoherent : BOOL;                                           // Etat non sur (divergence boot/reel)
END_STRUCT
END_TYPE
