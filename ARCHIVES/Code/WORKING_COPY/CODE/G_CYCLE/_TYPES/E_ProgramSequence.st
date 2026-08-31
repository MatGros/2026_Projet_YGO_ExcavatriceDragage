(* =======================================================================
   ⚙️ E_ProgramSequence — Identifiant de la séquence programme active
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Identification de la séquence en cours d'exécution
   📄 Doc métier : DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.3.md
   ======================================================================= *)

TYPE E_ProgramSequence :
(
    NONE        := 0, (* Aucune séquence active *)
    MAIN_CYCLE  := 1, (* Cycle principal automatique de dragage X0..X13 *)
    DIVE_SEARCH := 2, (* Sous-séquence de plongée / recherche de fond *)
    EXTRACTION  := 3  (* Sous-séquence d'extraction et fermeture *)
);
END_TYPE
