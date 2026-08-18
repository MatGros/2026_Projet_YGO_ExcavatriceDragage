(* =======================================================================
   ⚙️ E_ExtractionSequenceState — Phases d'extraction assistée
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Énumération des phases de la séquence d'extraction assistée
   📄 Doc métier : DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.1.md
   ======================================================================= *)

TYPE E_ExtractionSequenceState :
(
    WAIT_BOTTOM_CONFIRMATION := 0, (* Attente fond Kobold ou attestation opérateur *)
    READY_TO_CLOSE            := 1, (* Prêt à fermer la benne *)
    CLOSING_BUCKET            := 2, (* FB_Bucket ferme M2 seul *)
    CONTROL_ASCENT            := 3, (* M1/M2 synchronisés au palier sans contacteur vitesse *)
    NOMINAL_ASCENT            := 4, (* Montée couplée avec vitesse demandée opérateur *)
    ERROR_HOLD                := 5  (* Défaut extraction, reprise interdite avant reset *)
);
END_TYPE
