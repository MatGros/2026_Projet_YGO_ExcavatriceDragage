(* =======================================================================
   ⚙️ E_PresetConfirmMode — Mode de confirmation du preset codeur
   ───────────────────────────────────────────────────────────────────────
   🎯 Rôle : sélectionner le fait public utilisé pour valider un preset.
   📄 Doc : DOC/AF/AF_Partie-09_Fonction_Encoder_v2.3.md
   ======================================================================= *)

TYPE E_PresetConfirmMode :
ENUM
    READBACK_ONLY        := 0, // Confirmation par relecture de position
    READBACK_AND_STATUSBIT := 1, // Relecture et bit d'état matériel
    STATUSBIT_ONLY       := 2  // Bit d'état matériel uniquement
END_ENUM
END_TYPE
