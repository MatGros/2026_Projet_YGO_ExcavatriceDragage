(* =======================================================================
   ⚙️ E_CycleStep — Étapes de la machine d'état du cycle automatique
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Énumération des étapes du cycle automatique de dragage (X0 à X13 + STABILIZING)
   📄 Doc métier : DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.2.md
   ======================================================================= *)

TYPE E_CycleStep :
(
  X0_PREPARATION      := 0,   (* Début de graphe : à la TRÉMIE, treuils en position HAUTE *)
  X1_HOMING           := 1,   (* Vitesses lentes pour chercher capteur top + référencement *)
  X2_WORK_POS_SELECT  := 2,   (* Sélection cible Trémie/P1/Maintenance + translation validée *)
  X3_OPEN_BUCKET      := 3,   (* Ouverture benne (si déjà ouverte -> passe vite) *)
  X4_DESCEND_OPEN     := 4,   (* Plongée benne ouverte, M1+M2 synchro, Kobold mesure ON *)
  X5_BOTTOM_CONFIRMED := 5,   (* Fond validé (FB_DiveSearch) ; arrêt descente *)
  X6_CLOSE_BUCKET     := 6,   (* Fermeture benne — tolérance « à peu près fermé » *)
  X7_CTRL_ASCENT      := 7,   (* Remontée palier 1 de contrôle *)
  X8_ASCENT_LOADED    := 8,   (* Remontée nominale jusqu'à limite haute *)
  X9_DRAIN_PAUSE      := 9,   (* Égouttage temporisé — temps affiché IHM *)
  X10_TRANSLATE_DUMP  := 10,  (* Translation vers trémie + avertissements IHM *)
  X11_OPEN_DUMP       := 11,  (* Ouverture benne = vidage ; montée possible, descente ouvre *)
  X13_DONE_SYNC       := 13,  (* Fin de cycle, synchronisation finale (R4) + compteur *)
  STABILIZING         := 14   (* État d'attente/stabilisation — pas une erreur *)
);
END_TYPE
