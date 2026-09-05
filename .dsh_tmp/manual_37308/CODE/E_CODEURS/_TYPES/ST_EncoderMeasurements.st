(* =======================================================================
   📊 ST_EncoderMeasurements — Mesures codeurs M1/M2 (contrat frontière)
   ───────────────────────────────────────────────────────────────
   ⚠️ ORPHELIN (Tâche C5 — nettoyage données mortes) : ce type n'est plus
   référencé par aucun consommateur dans le CODE actif (après consolidation
   bus acquisition I8, le bus ST_AcquisitionInterPrg utilise désormais
   EncoderM1/EncoderM2 : ST_AcquisitionEncoderQualified). CONSERVÉ (non
   supprimé) car référencé par le harnais de test TOOLS/TEST_AUTO_CI/
   registry.yaml (10 entrées) et par des artefacts bundle. → Proposé à
   l'archivage APRÈS mise à jour du harnais de test.
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
