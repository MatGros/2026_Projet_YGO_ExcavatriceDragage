(* ═══════════════════════════════════════════════════════════════
   🔄 E_CycleStep — Étapes de la machine d'état du cycle automatique
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.1.md §3
   🆕 v2.1 : refonte conforme §11bis R1-R9 — labels Xn, STABILIZING,
      X12 supprimé (rebouclage trémie/treuils hauts).
   ═══════════════════════════════════════════════════════════════ *)

TYPE E_CycleStep :
(
  X0_PREPARATION      := 0,   (* 🏁 Début de graphe : à la TRÉMIE, treuils en position HAUTE *)
  X1_HOMING           := 1,   (* 🆕 vitesses lentes pour chercher capteur top + référencement *)
  X2_WORK_POS_SELECT  := 2,   (* sélection cible Trémie/P1/Maintenance + translation validée *)
  X3_OPEN_BUCKET      := 3,   (* 🆕 ouverture benne (si déjà ouverte → passe vite) *)
  X4_DESCEND_OPEN     := 4,   (* plongée benne ouverte, M1+M2 synchro, Kobold mesure ON *)
  X5_BOTTOM_CONFIRMED := 5,   (* fond validé (FB_DiveSearch) ; arrêt descente *)
  X6_CLOSE_BUCKET     := 6,   (* fermeture benne — tolérance « à peu près fermé » *)
  X7_CTRL_ASCENT      := 7,   (* remontée palier 1 de contrôle *)
  X8_ASCENT_LOADED    := 8,   (* remontée nominale jusqu'à limite haute *)
  X9_DRAIN_PAUSE      := 9,   (* égouttage temporisé — temps affiché IHM *)
  X10_TRANSLATE_DUMP  := 10,  (* translation vers trémie + avertissements IHM *)
  X11_OPEN_DUMP       := 11,  (* ouverture benne = vidage ; montée possible, descente ouvre *)
  X13_DONE_SYNC       := 13,  (* fin de cycle, synchronisation finale (R4) + compteur *)
  STABILIZING         := 14   (* 🆕 état d'attente/stabilisation (ex-ERROR_HOLD) — pas une erreur *)
);
END_TYPE
