(* ═══════════════════════════════════════════════════════════════
   🎮 ST_OperatorAction — Consigne unique de conduite opérateur
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF/AF_Partie-07_Interface_IHM_v2.1.md
   🎯 Les alarmes restent dans Error/ErrorId : cette struct répond seulement
      à « quelle action attend-on maintenant de l'opérateur ? ».
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_OperatorAction :
STRUCT
    ActionId : WORD;        (* Identifiant stable : table de textes IHM possible *)
    Text     : STRING(120); (* Texte de secours pour IHM/diagnostic acceptant les STRING *)
END_STRUCT
END_TYPE
