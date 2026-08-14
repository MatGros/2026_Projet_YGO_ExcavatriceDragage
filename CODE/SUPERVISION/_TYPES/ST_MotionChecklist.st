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
    RequestedDirection           : INT;  (* +1 = Montée, -1 = Descente, 0 = Repos *)
    RequestedSpeedPct            : REAL; (* 0..100 % consigne demandée *)

    (* 3. Chaîne de Sécurité & Verrous *)
    Step5_NoSafetyFault          : BOOL; (* TRUE = Pas de SafeStop ni AU actif sur cet axe *)
    Step6_DirectionAllowed       : BOOL; (* TRUE = Sens non interdit (ForbidAscent/ForbidDescent) *)
    Step7_BrakeReleased          : BOOL; (* TRUE = Commande frein activée & retour frein OK *)
    Step8_OutputInterlockOk      : BOOL; (* TRUE = Étage de sortie LD débloqué (pas d'interlock actif) *)

    (* 4. Bilan & Exécution Physiques *)
    AllConditionsMet             : BOOL; (* 🟢 TRUE = TOUTES LES CONDITIONS SONT REMPLIES, LES RELAIS DOIVENT COLLER ! *)
    RelayFwdActive               : BOOL; (* 🛗 Relais Montée physiquement commandé *)
    RelayRevActive               : BOOL; (* 🛗 Relais Descente physiquement commandé *)
    SpeedContactor1Active        : BOOL; (* 🔌 Contacteur de vitesse Palier 1 commandé *)
END_STRUCT
END_TYPE
