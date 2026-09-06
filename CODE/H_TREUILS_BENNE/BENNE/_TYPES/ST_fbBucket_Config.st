(* =======================================================================
   ⚙️ ST_fbBucket_Config — Configuration des offsets du benne
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Structure de paramétrage des décalages et anticipations benne
   📄 Doc métier : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md
   ======================================================================= *)
TYPE ST_fbBucket_Config :
STRUCT
    OffsetOpenM        : REAL;                                        // Ecart M1/M2 en metres benne ouvert (m)
    OffsetCloseM       : REAL;                                        // Ecart M1/M2 en metres benne ferme (m)
    CoherenceLimitM    : REAL;                                        // Seuil de detection d'incoherence au boot (m)
    CloseAnticipationM : REAL := 1.2;                                 // Anticipation coupure commande fermeture (m) -- reglable IHM
    OpenAnticipationM  : REAL := 1.3;                                 // Anticipation coupure commande ouverture (m) -- reglable IHM
    JogSlowdownZoneM   : REAL := 1.0;                                 // Distance avant le point d'arret anticipe ou le jog unitaire M2 est force au palier 1 (m) -- reglable IHM
    MaxStepUp          : INT := 2;                                    // Plafond palier benne en montée/fermeture (1..5) -- reglable IHM
    MaxStepDown        : INT := 4;                                    // Plafond palier benne en descente/ouverture (1..5) -- reglable IHM
END_STRUCT
END_TYPE
