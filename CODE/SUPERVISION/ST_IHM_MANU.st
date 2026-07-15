(* ═══════════════════════════════════════════════════════════════
   🚨 ST_IHM_MANU — Table d'échange IHM provisoire (mise en service URGENCE)
   ───────────────────────────────────────────────────────────────
   🎨 Pilotage manuel DIRECT des sorties physiques (relais, contacteurs
      vitesse, freins) — programme fonctionnel normal bypassé en sortie
      (PRG_10_Outputs uniquement), aucune sécurité logicielle métier active.
   ⚠️ DANGER : seuls les interlocks Fwd/Rev (couplé/individuel mutuellement
      exclusifs, voir PRG_10_Outputs) protègent, plus la chaîne AU/PowerCutOff
      (toujours active, non bypassée). Pas de limites logicielles, pas de synchro.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_IHM_MANU :
STRUCT
    (* 🔑 Activation — logique INVERSÉE volontaire (REX 2026-07-09) *)
    ModeDisable      : BOOL; (* 🔴 FALSE (défaut, y compris à CHAQUE démarrage/download automate,
                                 variable non-RETAIN) = mode Manu ACTIF d'origine. Passer à TRUE
                                 pour rendre la main au programme fonctionnel normal (PRG_06/07/03). *)

    (* 🕹️ Source & Sélection Mouvement *)
    JoystickSelect   : BOOL; (* 🔌 TRUE = Joystick CANopen | FALSE = Boutons IHM *)
    JoystickWinchSelect : INT; (* 🛗 1 = M1, 2 = M2, 3 = Couplé *)

    (* 🪝 Treuil M1 *)
    PositionM_M1     : REAL; (* 📊 [m] Position brute codeur M1 *)
    M1_RelayFwd      : BOOL; (* 🛗 Commande montée M1 + frein *)
    M1_RelayRev      : BOOL; (* 🛗 Commande descente M1 + frein *)
    HomingEncoder_M1 : BOOL; (* 🎯 Front = référencement codeur M1 (OR avec GVL_IHM.WinchM1.CmdHome existant) *)

    (* 🪝 Treuil M2 *)
    PositionM_M2     : REAL; (* 📊 [m] Position brute codeur M2 *)
    M2_RelayFwd      : BOOL; (* 🛗 Commande montée M2 + frein *)
    M2_RelayRev      : BOOL; (* 🛗 Commande descente M2 + frein *)
    HomingEncoder_M2 : BOOL; (* 🎯 Front = référencement codeur M2 (OR avec GVL_IHM.WinchM2.CmdHome existant) *)

    (* 🔗 Commande couplée M1+M2 *)
    M1_M2_RelayFwd   : BOOL; (* 🔗 Commande montée M1 et M2 + frein *)
    M1_M2_RelayRev   : BOOL; (* 🔗 Commande descente M1 et M2 + frein *)
    M1_M2_Contactor1 : BOOL; (* ⚡ Vitesse M1 et M2 *)
    M1_M2_Contactor2 : BOOL; (* ⚡ Vitesse M1 et M2 *)
    M1_M2_Contactor3 : BOOL; (* ⚡ Vitesse M1 et M2 *)
    M1_M2_Contactor4 : BOOL; (* ⚡ Vitesse M1 et M2 *)

    (* 🌾 Auxiliaires Hydrauliques (HMI maintained action) *)
    GridOpenCmd      : BOOL; (* 🌾 Commande ouverture grille *)
    GridCloseCmd     : BOOL; (* 🌾 Commande fermeture grille *)
    HelmetOpenCmd    : BOOL; (* 🪖 Commande ouverture casque *)
    HelmetCloseCmd   : BOOL; (* 🪖 Commande fermeture casque *)

    (* 📊 Fins de Course Virtuels Grappin (delta M1 - M2) *)
    FdcGrappinOpenEnable   : BOOL; (* 🎚️ Activer FDC Ouvert (stop M2 descente si delta >= 0.0m) *)
    FdcGrappinCloseEnable  : BOOL; (* 🎚️ Activer FDC Fermé (stop M2 montée si delta <= -10.0m) *)
    FdcGrappinOpen          : BOOL; (* ⚠️ OBSOLÈTE (visu) — alias de FdcGrappinOpenEnable *)
    FdcGrappinClose         : BOOL; (* ⚠️ OBSOLÈTE (visu) — alias de FdcGrappinCloseEnable *)
    GrappinDelta     : REAL; (* 📊 [m] Écart M1-M2 en temps réel *)
    FdcGrappinOpenActive  : BOOL; (* 🚨 Limite basse M2 atteinte (descente coupée) *)
    FdcGrappinCloseActive : BOOL; (* 🚨 Limite haute M2 atteinte (montée coupée) *)

    (* ⚡ Réglages dynamiques des limites de vitesse (paliers max) *)
    WinchMaxStepFwd  : INT; (* ⚡ Palier max en montée (1..5, défaut 5) *)
    WinchMaxStepRev  : INT; (* ⚡ Palier max en descente (1..5, défaut 2) *)
END_STRUCT
END_TYPE
