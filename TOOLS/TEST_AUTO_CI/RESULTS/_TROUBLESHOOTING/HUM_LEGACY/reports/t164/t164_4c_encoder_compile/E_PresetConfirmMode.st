(* =======================================================================
   ⚙️ E_PresetConfirmMode — Mode de confirmation du preset codeur
   ───────────────────────────────────────────────────────────────────────
   🎯 Rôle : sélectionner le fait public utilisé pour valider un preset.
   📄 Doc : DOC/AF/AF_Partie-09_Fonction_Encoder_v2.3.md
   ======================================================================= *)

TYPE E_PresetConfirmMode :
    (READBACK_ONLY := 0, READBACK_AND_STATUSBIT := 1, STATUSBIT_ONLY := 2);
END_TYPE
