(* =======================================================================
   ⚙️ E_AutoCycleStep — Etapes du GRAFCET du cycle SEMI_AUTO (dragage)
   ───────────────────────────────────────────────────────────────
   🎯 Role : Enumeration des steps du sequenceur SEMI_AUTO (FB_CycleSemiAuto).
             Prefixe AX (Auto) homogene au homing machine (prefixe HX).
   📄 Doc metier : DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.3.md
                   + DOC/WFLOW/CONTRACTS/GEL_GRAFCET_SEMIAUTO_20260903.md
   ======================================================================= *)

TYPE E_AutoCycleStep :
(
  AX0_REPOS            := 0,   (* Repos / park : toutes commandes 0, etat neutre *)
  AX1_HOMING           := 1,   (* Verif reference machine (HomedM1/M2) - aucun mouvement *)
  AX2_TRANSLATE_P1     := 2,   (* Translation vers P1 au joystick (pas de selection, comme maintenance) *)
  AX3_OPEN_BUCKET      := 3,   (* Ouverture benne (si deja ouverte -> passe vite) *)
  AX4_DESCEND_OPEN     := 4,   (* Plongee benne ouverte, M1+M2 synchro, Kobold mesure ON *)
  AX5_BOTTOM_CONFIRMED := 5,   (* Fond confirme (Kobold) ; montee lente securisee *)
  AX6_CLOSE_BUCKET     := 6,   (* Fermeture benne - tolerance a peu pres ferme *)
  AX7_CTRL_ASCENT      := 7,   (* Remontee palier 1 de controle + surveillance ecart M1/M2 *)
  AX8_ASCENT_LOADED    := 8,   (* Remontee en charge jusqu'a limite haute *)
  AX9_DRAIN_PAUSE      := 9,   (* Egouttage temporise - duree configurable / passable IHM *)
  AX10_TRANSLATE_DUMP  := 10,  (* Translation vers tremie (depart P1) + avertissements IHM *)
  AX11A_DUMP_ARRIVE    := 11,  (* Arrivee tremie : treuils a l'arret, attente geste operateur *)
  AX13_DONE_SYNC       := 13,  (* Fin de cycle : compteur vidages + duree cycle *)
  AX_STAB              := 14,  (* Repli defaut / stabilisation - pas une erreur *)
  AX11B_DUMP_OPEN      := 15,  (* Vidage tremie : ouverture benne, LES DEUX treuils a l'arret *)
  AX11C_DUMP_REPOSITION := 16  (* Repositionnement couple M1+M2 (option IHM maintenue), retour AX11B au relachement *)
);
END_TYPE
