(* ═══════════════════════════════════════════════════════════════
   📏 ST_EncoderMeasurements — Mesures codeurs M1/M2 (contrat frontière)
   ───────────────────────────────────────────────────────────────
   📄 Lot M1 · Doc : DOC/AF_Partie-06_Acquisition_Qualification_IO_v2.0.md §2ter
   🎨 Un sous-DUT par treuil (M1, M2) de la chaîne de mesure pure.
   🔗 Producteur unique : PRG_02_Acquisition_CFC (rang 02, chaîne codeur M1/M2).
      Lecteurs : PRG_04_Treuils_Benne_CFC, PRG_03_Modes_Cycle_CFC, Supervision/IHM.
   🛡️ Sans simulation : M1 reflète COD1, M2 reflète COD2 — jamais croisés.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_EncoderMeasurements :
STRUCT
    M1 : ST_EncoderMeasurement; (* Chaîne de mesure treuil M1 (COD1) *)
    M2 : ST_EncoderMeasurement; (* Chaîne de mesure treuil M2 (COD2) *)
END_STRUCT
END_TYPE
