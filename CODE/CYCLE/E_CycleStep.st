(* ═══════════════════════════════════════════════════════════════
   🔄 E_CycleStep — Étapes de la machine d'état du cycle automatique
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF_Partie4_Cycle_Sequenceur_v1.2.md §1
   ═══════════════════════════════════════════════════════════════ *)

TYPE E_CycleStep :
(
  INIT                 := 0,   (* Vérifs cohérence états + sécurités, mise en position init *)
  WORK_POS_SELECT      := 1,   (* Choix opérateur pos travail 1/2 + déplacement validé joystick *)
  DESCENDING_OPEN      := 2,   (* Plongée grappin déjà ouvert, M1+M2 synchro *)
  BOTTOM_TOUCH_WAIT    := 3,   (* Attente info BOOL capteur "fond touché" *)
  SYNCHRO_ADJUST       := 4,   (* Désynchro M2 petite vitesse (offset X) → fermeture grappin *)
  CTRL_ASCENDING       := 5,   (* Remontée lente de contrôle (vérification fermeture) *)
  ASCENDING_LOADED     := 6,   (* Remontée pleine vitesse charge *)
  DRAINING_PAUSE       := 7,   (* Égouttage temporisé (durée RETAIN) *)
  CHARIOT_MOVE         := 8,   (* Déplacement chariot M3 vers trémie *)
  DESCENDING_OPEN_DUMP := 9,   (* Descente de vidage + ouverture grappin *)
  RETURN_WORK_POS      := 10,  (* Retour position travail (remontée synchro) *)
  READY                := 11,  (* Cycle terminé, prêt à reboucler *)
  ERROR_HOLD           := 12   (* Arrêt sûr figé sur défaut (SafeStop) *)
);
END_TYPE
