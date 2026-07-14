(* ═══════════════════════════════════════════════════════════════
   🚨 ST_IHM_MANU — Table d'échange IHM provisoire (mise en service URGENCE)
   ───────────────────────────────────────────────────────────────
   🎨 Pilotage manuel DIRECT des sorties physiques (relais, contacteurs
      vitesse, freins) et du variateur M3 (EtherCAT, mot de commande) —
      programme fonctionnel normal bypassé en sortie (PRG_10_Outputs
      uniquement), aucune sécurité logicielle métier active.
   ⚠️ DANGER : seuls les interlocks Fwd/Rev (couplé/individuel mutuellement
      exclusifs, voir PRG_10_Outputs) protègent, plus la chaîne AU/PowerCutOff
      (toujours active, non bypassée). Pas de limites logicielles, pas de synchro.
   🔧 REX 2026-07-09 : M3_CommandWord (registre 0x3101 côté carte EtherCAT, PAS le
      0x3001 natif variateur) = 0 arrêt / 1 marche avant / 2 marche arrière (recette
      fournisseur) — ⚠️ non vérifié sur banc au moment du codage, à confirmer.
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

    (* ↔️ Chariot M3 (variateur AC600) *)
    M3_RelayFwd      : BOOL; (* ↔️ Commande frein + envoi valeur dans mot de commande *)
    M3_RelayRev      : BOOL; (* ↔️ Commande frein + envoi valeur dans mot de commande *)
    M3_FreqSetpoint  : REAL; (* 🎯 Consigne fréquence variateur [Hz] *)
    M3_FreqActual    : REAL; (* 📊 Retour fréquence mesurée [Hz] *)

    (* 🌾 Auxiliaires Hydrauliques (HMI maintained action) *)
    GridOpenCmd      : BOOL; (* 🌾 Commande ouverture grille *)
    GridCloseCmd     : BOOL; (* 🌾 Commande fermeture grille *)
    HelmetOpenCmd    : BOOL; (* 🪖 Commande ouverture casque *)
    HelmetCloseCmd   : BOOL; (* 🪖 Commande fermeture casque *)

    (* 📊 Fins de Course Virtuels Grappin (delta M1 - M2) *)
    FdcGrappinOpen   : BOOL; (* 🎚️ Activer FDC Ouvert (stop M2 descente si delta >= 0.0m) *)
    FdcGrappinClose  : BOOL; (* 🎚️ Activer FDC Fermé (stop M2 montée si delta <= -10.0m) *)
    GrappinDelta     : REAL; (* 📊 [m] Écart M1-M2 en temps réel *)
    FdcGrappinOpenActive  : BOOL; (* 🚨 Limite basse M2 atteinte (descente coupée) *)
    FdcGrappinCloseActive : BOOL; (* 🚨 Limite haute M2 atteinte (montée coupée) *)

    (* 🔍 Diagnostics Variateur M3 *)
    M3_CommandWordMonitor : WORD; (* 🔍 Mot de commande envoyé au variateur *)
    M3_StatusWordMonitor  : WORD; (* 🔍 Mot d'état reçu du variateur *)
    M3_CommReady          : BOOL; (* 🔍 Variateur M3 : communication prête (bit 7) *)
    M3_PowerReady         : BOOL; (* 🔍 Variateur M3 : puissance prête (bit 0) *)

    (* ⚡ Réglages dynamiques des limites de vitesse (paliers max) *)
    WinchMaxStepFwd  : INT; (* ⚡ Palier max en montée (1..5, défaut 5) *)
    WinchMaxStepRev  : INT; (* ⚡ Palier max en descente (1..5, défaut 2) *)
END_STRUCT
END_TYPE
