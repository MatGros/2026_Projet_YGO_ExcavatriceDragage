(* =======================================================================
   🔌 ST_fbEncoder_HwOut — Ordres preset de sortie codeur (HwOut)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Regrouper les SEULES sorties/ordres preset d'un codeur absolu
      EtherCAT produits par FB_Encoder vers le PDO Rx (bus sortie).
   🔒 Ownership : FB_Encoder produit ce bus ; PRG_02_Acquisition le relaie
      vers le device.
   📄 Doc métier : DOC/AF/AF_Partie-09_Fonction_Encoder_v2.3.md
   ======================================================================= *)

TYPE ST_fbEncoder_HwOut :
STRUCT
    // === SORTIES BUS ETHERCAT (ordres preset vers PDO Rx) ===
    PresetTriggerCmd   : WORD;   // <-- [ACT] Declenchement preset vers PDO Rx
    CodeSeqTriggerCmd  : WORD;   // <-- [ACT] Sequence code vers PDO Rx, maintenue a 0
    PresetValueOut     : UDINT;  // <-- [ACT] Valeur brute envoyee au preset
END_STRUCT
END_TYPE
