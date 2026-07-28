(* ═══════════════════════════════════════════════════════════════
   🌊 E_DiveSearchState — Phases internes de recherche du fond Kobold
   📄 Doc : DOC/AF_Partie-04_Cycle_Sequenceur_v1.5.md §3ter
   ═══════════════════════════════════════════════════════════════ *)
TYPE E_DiveSearchState :
(
    WAIT_PRECONDITIONS := 0, (* Attente benne ouverte, positions et Kobold au repos *)
    READY_TO_DESCEND   := 1, (* Prêt à assister une demande de descente *)
    SEARCHING_IMMERSION := 2, (* Descente : attente front 0→1 dans fenêtre eau *)
    SEARCHING_BOTTOM    := 3, (* Immersion validée : attente front 1→0 au fond *)
    BOTTOM_CONFIRMED    := 4, (* Fond validé ; extraction peut être demandée *)
    ERROR_HOLD          := 5  (* Séquence invalide, descente assistée interdite *)
);
END_TYPE
