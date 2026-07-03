(* ═══════════════════════════════════════════════════════════════
   🎛️ GVL_IHM — Variables globales d'échange pour l'IHM
   ───────────────────────────────────────────────────────────────
   📄 Lot A : Mise en service et calibration de la machine de dragage.
   💾 Déclaré en RETAIN pour la persistance des configurations opérateur.
   ═══════════════════════════════════════════════════════════════ *)
VAR_GLOBAL RETAIN
    WinchM1 : ST_WinchHMI;  (* 🛗 Variables d'échange IHM Treuil Principal M1 *)
    WinchM2 : ST_WinchHMI;  (* 🛗 Variables d'échange IHM Treuil Auxiliaire M2 *)
    Grappin : ST_GrappinHMI;(* 🪣 Variables d'échange IHM Mécanisme Grappin *)
    Sync    : ST_SyncHMI;   (* ⚖️ Variables d'échange IHM Surveillance de synchro *)
    Joystick : ST_JoystickHMI; (* 🕹️ Variables d'échange IHM Joystick *)
    Modes   : ST_ModesHMI;  (* 🎚️ Variables d'échange IHM Modes de marche *)
    Chariot : ST_ChariotHMI;(* ↔️ Variables d'échange IHM Chariot M3 *)
    Network : ST_NetworkDiagHMI;(* 📡 Variables d'échange IHM Diagnostics réseau *)
END_VAR

(* ═══════════════════════════════════════════════════════════════
   📝 NOTE : PROCÉDURE DE TEST SUR BANC AVEC SIMULATION DYNAMIQUE
   ───────────────────────────────────────────────────────────────
   Cette simulation (intégrée dans PRG_MAIN) permet de valider le
   comportement des treuils M1/M2, du Homing et du Grappin sans
   moteurs ni codeurs physiques connectés.

   1. CONFIGURATION INITIALE DU BANC DE TEST :
      - Activer le bypass général des contacteurs :
        GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST := TRUE
      - Activer les autres bypass nécessaires si aucun matériel n'est câblé :
        * GVL_DEBUG.DBG_EmergencyStopOkBypass_TEST := TRUE (Arrêt d'Urgence)
        * GVL_DEBUG.DBG_CtrlPhaseRotation_Bypass_TEST := TRUE (Ordre des phases)
        * GVL_DEBUG.DBG_SlackCableSwitch_TEST := TRUE (Mou de câble)
      - Forcer la demande de mode machine en maintenance N1 :
        ModeRequest_IHM := E_Mode.MAINT_N1
      - Acquitter les défauts initiaux en basculant la variable générale :
        MachineReset_IHM := TRUE puis FALSE (front)

   2. TEST DU MOUVEMENT DES TREUILS :
      - S'assurer que l'homme-mort joystick est armé (ou forcé via
        GVL_DEBUG.DBG_DeadmanBypass_TEST := TRUE).
      - Actionner le joystick (axe Y).
      - Vérifier que les variables de position brute simulée de PRG_MAIN
        (SimulatedM1Raw et SimulatedM2Raw) incrémentent en montée (Fwd) et
        décrémentent en descente (Rev), proportionnellement à la vitesse.

   3. TEST DE LA PROCÉDURE DE HOMING (RÉFÉRENCEMENT NOMINAL) :
      - S'assurer que le mode est MAINT_N1 (requis pour le homing nominal).
      - Les treuils doivent être arrêtés (pas de commande de mouvement).
      - Simuler l'activation du capteur de position haute commun :
        GVL_DEBUG.DBG_TopPositionSensorBypass_TEST := TRUE
      - Choisir le mode de référencement (ex. HomingMode_IHM := 3 pour M1+M2).
      - Lancer le homing en basculant :
        StubHomeButton_IHM := TRUE puis FALSE (front).
      - La simulation détectera le signal de preset (COD1_PresettTrigCmd /
        COD2_PresettTrigCmd) et écrira automatiquement la valeur du preset
        dans les registres bruts simulés.
      - Vérifier que instHomingM1.Homed et instHomingM2.Homed passent à TRUE.
      - La position calculée (CablePosM) doit se caler exactement à 12.5m
        (ou la valeur définie par M1_TopSensorPositionM / M2_TopSensorPositionM).
      - Repasser le capteur haut à FALSE après le test :
        GVL_DEBUG.DBG_TopPositionSensorBypass_TEST := FALSE

   4. TEST DU GRAPPIN (OUVERTURE / FERMETURE) :
      - S'assurer que les treuils ont été préalablement référencés (Homed = TRUE).
      - Choisir une commande Grappin sur l'IHM :
        * Pour OUVRIR : GVL_IHM.Grappin.CmdOpen := TRUE (et CmdClose := FALSE)
        * Pour FERMER : GVL_IHM.Grappin.CmdClose := TRUE (et CmdOpen := FALSE)
      - Actionner et maintenir le joystick Y dans le sens correspondant :
        * UP (Direction = 1) pour l'ouverture
        * DOWN (Direction = -1) pour la fermeture
      - Le bloc Grappin prend le contrôle de M2 en vitesse lente forcée :
        * En ouverture, SimulatedM2Raw augmente jusqu'à ce que CablePosM2 >= CablePosM1 + OffsetOpenM (12.5m + 0.0m = 12.5m).
        * En fermeture, SimulatedM2Raw diminue jusqu'à ce que CablePosM2 <= CablePosM1 + OffsetCloseM (12.5m - 1.5m = 11.0m).
      - Vérifier que Grappin.Busy passe à FALSE et Grappin.Done à TRUE lorsque la
        cible est atteinte, et que l'état physique du grappin est mis à jour.
      - Relâcher le joystick pour terminer le cycle de commande.
   ═══════════════════════════════════════════════════════════════ *)

