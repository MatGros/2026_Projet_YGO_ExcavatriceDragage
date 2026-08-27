(* =======================================================================
   📊 ST_EncoderMeasurements — Mesures codeurs M1/M2 (contrat frontière)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Structure frontière regroupant les sous-DUTs de mesure des treuils M1 et M2
   🔌 Interface : Producteur unique PRG_02_Acquisition
   📄 Doc métier : DOC/AF/AF_Partie-06_Acquisition_Qualification_IO_v2.4.md
   ======================================================================= *)

TYPE ST_EncoderMeasurements :
STRUCT
    // === CHAINES DE MESURE PAR TREUIL ===
    M1 : ST_fbEncoder_Measurement; // Chaine de mesure treuil M1 (COD1)
    M2 : ST_fbEncoder_Measurement; // Chaine de mesure treuil M2 (COD2)
END_STRUCT
END_TYPE
