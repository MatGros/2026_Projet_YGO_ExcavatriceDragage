(* =======================================================================
   ⚙️ E_AutoCycleStep — Etapes du GRAFCET du cycle SEMI_AUTO (dragage)
   ───────────────────────────────────────────────────────────────
   🎯 Role : Enumeration des steps du sequenceur SEMI_AUTO (FB_CycleSemiAuto).
             Prefixe AX (Auto) homogene au homing machine (prefixe HX).
   📄 Doc metier : DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.3.md
                   + DOC/WFLOW/CONTRACTS/GEL_GRAFCET_SEMIAUTO_20260903.md
   🧊 GEL 2026-09-03 : DIVING decompose en 5 steps de plein droit (AX4..AX8) +
             step special AX_DIVING_RETRY ; EXTRACTION = AX9..AX12 ;
             DECHARGE = AX13..AX15C + AX18_DONE_SYNC ; AX_STAB repli defaut.
   ======================================================================= *)

TYPE E_AutoCycleStep :
(
  AX0_REPOS             := 0,   (* Repos / park : toutes commandes 0, etat neutre - etape initiale pure *)
  AX1_INIT             := 1,    (* Verif CONDITIONS INITIALES (Homed M1/M2, treuils FDC haut, M3 pas a droite de P1) - aucun mouvement, aucun referencement *)
  AX2_TRANSLATE_P1     := 2,    (* Translation vers P1 : joystick vers la droite, le cycle n'emet aucune commande M3 ; surveillance treuils au FDC haut *)
  AX3_OPEN_BUCKET      := 3,    (* Ouverture benne jusqu'au FDC logiciel benne ouverte *)

  (* --- DIVING (5 steps + retry) --- *)
  AX4_DESCEND_DIVING   := 4,    (* Plongee couplee benne ouverte palier 4 jusqu'a l'altimetrie de lancement (DiveStartMin_M) - Kobold PAS enclenche *)
  AX5_KOBOLD_INIT      := 5,    (* Activation contacteur Kobold << au vol >>, verif retour contacteur, descente palier 4 maintenue *)
  AX6_SEARCH_IMMERSION := 6,    (* Recherche entree dans l'eau : attente front DI Kobold 0->1, descente palier 4 maintenue *)
  AX7_SEARCH_BOTTOM    := 7,    (* Recherche du fond : attente front DI Kobold 1->0, descente palier 4 maintenue *)
  AX8_BOTTOM_CONFIRMED := 8,    (* Fond confirme : coupure instantanee treuils, set bit fond, TouchPositionM / RaiseTargetM *)

  (* --- EXTRACTION (4 steps) --- *)
  AX9_RAISE_OFF_BOTTOM := 9,    (* Retente les cables (palier 1), decollement du fond ; selecteur couplage BOTH/M1/M2 accessible *)
  AX10_CLOSE_BUCKET    := 10,   (* Fermeture benne, treuils explicitement 0 *)
  AX11_CTRL_ASCENT     := 11,   (* Montee controle palier max reglable [1..2] + surveillance ecart vitesse M1/M2 ; benne mal fermee autorisee *)
  AX12_LOADED_ASCENT   := 12,   (* Montee en charge : palier 4 si benne fermee, palier 1 si mal fermee ; pas de ralenti 1 m avant top *)

  (* --- DECHARGE (6 steps) --- *)
  AX13_DRAIN_PAUSE     := 13,   (* Egouttage temporise - duree reglable IHM + bypass immediat *)
  AX14_TRANSLATE_DUMP  := 14,   (* Translation vers tremie (depart P1) + avertissements IHM *)
  AX15A_DUMP_ARRIVE    := 15,   (* Arrivee tremie : treuils a l'arret, attente geste operateur *)
  AX15B_DUMP_OPEN      := 16,   (* Vidage : ouverture benne au-dessus de la tremie, LES DEUX treuils a l'arret *)
  AX15C_DUMP_REPOSITION := 17,  (* Repositionnement couple M1+M2 (option IHM maintenue), retour AX15B au relachement *)
  AX18_DONE_SYNC       := 18,   (* Fin de passe : compteur vidages + duree cycle ; msg << aller en P1 >> ; rebouclage direct sur AX2 *)

  (* --- STEPS SPECIAUX --- *)
  AX_STAB              := 19,   (* Repli defaut / stabilisation - pas une erreur *)
  AX_DIVING_RETRY      := 20,   (* Reprise diving : remontee assistee palier lent jusqu'au FDC haut puis retour AX4 ; sur erreur Kobold / joystick relache / palier <> 4 en AX5..AX7 *)
  AX3_WAIT_DIVE_START  := 21    (* Transition benne->plongee : sorties neutres jusqu'a l'arret mecanique confirme M1/M2, joystick pousse maintenu *)
);
END_TYPE
