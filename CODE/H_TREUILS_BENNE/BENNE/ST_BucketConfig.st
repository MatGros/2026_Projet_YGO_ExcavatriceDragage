(* =======================================================================
   ⚙️ ST_BucketConfig — Configuration des offsets du benne
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Structure de paramétrage des décalages et anticipations benne
   📄 Doc métier : DOC/AF/AF_Partie-10_Fonction_Winch_v2.0.md
   ======================================================================= *)
TYPE ST_BucketConfig :
STRUCT
    OffsetOpenM        : REAL;                                        // Ecart M1/M2 en metres benne ouvert (m)
    OffsetCloseM       : REAL;                                        // Ecart M1/M2 en metres benne ferme (m)
    CoherenceLimitM    : REAL;                                        // Seuil de detection d'incoherence au boot (m)
    CloseAnticipationM : REAL := 1.0;                                 // Anticipation coupure commande fermeture (m)
    OpenAnticipationM  : REAL := 1.3;                                 // Anticipation coupure commande ouverture (m)
END_STRUCT
END_TYPE
