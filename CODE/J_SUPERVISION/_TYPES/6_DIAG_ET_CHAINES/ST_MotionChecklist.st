(* ═══════════════════════════════════════════════════════════════
   ⚙️ ST_MotionChecklist — Diagnostic chronologique de commande de mouvement
   ───────────────────────────────────────────────────────────────
   🎨 Permet de voir en un coup d'œil pourquoi un ordre de mouvement ne fait pas coller les relais.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_MotionChecklist :
STRUCT
    (* 1. Puissance & Mode *)
    Step1_PowerEngaged           : BOOL; (* TRUE = Contacteur principal sous tension (PowerContactorEngaged_DI) ➔ Armer puissance via Reset *)
    Step2_ModeAuthorized         : BOOL; (* TRUE = Mode MAINT_N1 ou N2 actif (pas DISABLE) ➔ Commutateur Mode IHM *)
    Step3_NotBusyOtherTask       : BOOL; (* TRUE = Pas d'autre séquence en cours (Homing, Benne busy, etc.) *)

    (* 1bis. Entrées physiques directes HwIn (vérité terrain) *)
    HwIn_PowerContactorEngaged_DI: BOOL; (* Contacteur puissance principal issu de HwIn.Machine *)
    HwIn_BrakeIsOpen_DI          : BOOL; (* Retour fin de course frein (1 = ouvert) issu de HwIn *)
    Cmd_BrakeRelease             : BOOL; (* Ordre de commande d'ouverture de frein généré par l'automate *)

    (* 2. Intention & Demande *)
    Step4_MotionRequested        : BOOL; (* TRUE = Demande active (Bouton IHM ou Joystick) ➔ Si IHM : TglJoystickMaster doit être à 0 ! *)
    RequestedDirection           : INT;  (* +1 = Ascending, -1 = Descending, 0 = Repos *)
    RequestedSpeedPct            : REAL; (* 0..100 % consigne demandée *)

    (* 3. Chaîne de Sécurité & Verrous *)
    Step5_NoSafetyFault          : BOOL; (* TRUE = Pas de SafeStop ni AU actif sur cet axe *)
    Step6_DirectionAllowed       : BOOL; (* TRUE = Sens autorisé (AscentPermit/DescendPermit / TremiePermit/MaintenancePermit) *)
    Step7_BrakeReleased          : BOOL; (* TRUE = Commande frein activée & retour frein OK *)
    Step8_OutputInterlockOk      : BOOL; (* TRUE = Étage de sortie LD débloqué (pas d'interlock actif).
                                             🛡️ T371 : dérivé de l'ÉTAT publié + du défaut de la barrière finale,
                                             JAMAIS du seul FinalInterlockError (qui ne porte que le timeout frein). *)

    (* 4. Bilan & Exécution Physiques *)
    AllConditionsMet             : BOOL; (* 🟢 TRUE = TOUTES LES CONDITIONS SONT REMPLIES, LES RELAIS DOIVENT COLLER ! *)
    RelayFwdActive               : BOOL; (* 🛗 Relais Ascending physiquement commandé *)
    RelayRevActive               : BOOL; (* 🛗 Relais Descending physiquement commandé *)
    SpeedContactor1Active        : BOOL; (* 🔌 Contacteur de vitesse Palier 1 commandé *)

    (* 5. Barrière finale — état & cause publiés (T371, LECTURE SEULE) *)
    (* ⚠️ Ajout en FIN de STRUCT : aucun champ existant n'est décalé (mapping IHM/SCADA + online change).
       ⚠️ VOCABULAIRE COMMUN aux 3 axes (famille E_WinchFinalInterlock...), choisi parce que ce DUT est
          PARTAGÉ par M1, M2 et M3 et qu'AUCUNE conversion de type n'est nécessaire :
          · M1/M2 — recopie DIRECTE de l'énumération publiée par la barrière (aucune projection) ;
          · M3   — la barrière M3 ne publie qu'un état dérivé du défaut : E_State.READY -> READY et
                   E_State.ERROR -> FAULT (projection EXPLICITE, cf. FB_TroubleshootingView.st §11),
                   ses 3 raisons étant identiques (NONE / BRAKE_COMMAND_NOT_CONFIRMED / RESTART_INHIBITED).
          Le type énuméré (et non INT) évite toute conversion — la conversion explicite de l'énumération
          d'un membre d'IEC_STRUCT n'est pas supportée par le compilateur de test, et un INT aurait rendu
          la table de valeurs DÉPENDANTE DE L'AXE. La famille M3 (E_State) n'est volontairement pas
          réutilisée ici : sa numérotation diffère (READY = 2 vs 1) et rendrait la lecture ambiguë.
       ⚠️ USAGE DIAGNOSTIC UNIQUEMENT (latence N-1 assumée, projection PRG_04:1688-1696) : aucune ligne
          de CONDUITE ne doit consommer ces deux champs. *)
    Step8_InterlockState         : E_WinchFinalInterlockState;  (* 🛡️ [DIAG/LECTURE] État publié de la barrière
                                             finale, vocabulaire commun aux 3 axes :
                                             DISABLED(0) · READY(1) · WAIT_BRAKE_COMMAND_CONFIRMATION(2) ·
                                             WAIT_STEP_DELAY(3) · WAIT_RESTART_DELAY(4) · FAULT(5) ·
                                             WAIT_SENSE_DROP_CONFIRM(6).
                                             ⚠️ WAIT_STEP_DELAY(3) n'est JAMAIS produit : `FB_WinchOutputInterlock.st`
                                                ne l'affecte nulle part (la montée de palier reste en READY, :473) —
                                                entrée conservée pour la complétude de l'énumération (REX revue T371). *)
    Step8_InterlockReason        : E_WinchFinalInterlockReason; (* 🛡️ [DIAG/LECTURE] Cause MÉMORISÉE publiée par la
                                             barrière finale, vocabulaire commun aux 3 axes :
                                             NONE(0) · BRAKE_COMMAND_NOT_CONFIRMED(1) · RESTART_INHIBITED(2) ·
                                             SENSE_DROP_TIMEOUT(3 — M1/M2 uniquement).
                                             ⚠️ Cause mémorisée, JAMAIS remise à NONE par un acquittement sur
                                                certains chemins (SENSE_DROP_TIMEOUT M1/M2, RESTART_INHIBITED M3) :
                                                elle informe, elle ne prouve pas un refus ACTIF. *)
END_STRUCT
END_TYPE
