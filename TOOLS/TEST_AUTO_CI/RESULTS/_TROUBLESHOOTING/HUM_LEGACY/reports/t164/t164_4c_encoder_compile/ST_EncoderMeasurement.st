(* =======================================================================
   📊 ST_EncoderMeasurement — Mesures codeur conditionnées (1 sous-DUT par treuil)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Regroupement des mesures et faits de la chaîne codeur d'un treuil (Abs → Scale → Safety → Speed)
   🔌 Interface : Interface de mesure normalisée pour PRG_02_Acquisition
   📄 Doc métier : DOC/AF/AF_Partie-06_Acquisition_Qualification_IO_v2.4.md
   ======================================================================= *)

TYPE ST_EncoderMeasurement :
STRUCT
    // === DONNEES BRUTES & STATUT BUS ===
    RawPos            : UDINT;        // Position brute codeur (gelee si EncoderAvailable=FALSE)
    EncoderAvailable  : BOOL;         // TRUE = bus/esclave EtherCAT operationnel et disponible

    // === MESURES DE POSITION CABLE ===
    CablePosM         : REAL;         // Position cable (m, signee, + enroule)
    CablePosMSafe     : REAL;         // Position cable instantanee validee par EncoderIncoherent (m)
    EncoderIncoherent : BOOL;         // TRUE = incoherence redemarrage ou hors bornes

    // === MESURES DE VITESSE CABLE ===
    Speed_Mps         : REAL;         // Vitesse absolue sur fenetre glissante (m/s)
    SignedSpeed_Mps   : REAL;         // Vitesse signee (m/s, + montee, - descente)
    SpeedValid        : BOOL;         // TRUE si 6 echantillons valides sur au moins 50 ms

    // === STATUTS DES SOUS-FB & REFERENCE ===
    HomingStatus      : ST_Status;  // Statut FB_Encoder_Homing (etat du referencement)
    AbsStatus         : ST_Status;  // Statut FB_Encoder_Abs (etat acquisition bus)
    HomingRefRaw      : UDINT;        // Reference brute du dernier homing reussi (re-expose)
END_STRUCT
END_TYPE
