(* ═══════════════════════════════════════════════════════════════
   🎛️ GVL_IHM — Variables globales d'échange pour l'IHM
   ───────────────────────────────────────────────────────────────
   📄 Lot A : Mise en service et calibration de la machine de dragage.
   💾 Déclaré en RETAIN pour la persistance des configurations opérateur.
   ═══════════════════════════════════════════════════════════════ *)
VAR_GLOBAL RETAIN
    M1TreuilRetenue : ST_WinchHMI;  (* 🛗 Variables d'échange IHM Treuil Retenue (M1) *)
    M2TreuilBucket : ST_WinchHMI;  (* 🛗 Variables d'échange IHM Treuil Benne (M2) *)
    Bucket : ST_BucketHMI;(* 🪣 Variables d'échange IHM Mécanisme Benne (M2) *)
    Sync    : ST_SyncHMI;   (* ⚖️ Variables d'échange IHM Surveillance de synchro *)
    JoystickJOY1 : ST_JoystickHMI; (* 🕹️ Variables d'échange IHM Joystick (noeud CANopen JOY1) *)
    Modes   : ST_ModesHMI;  (* 🎚️ Variables d'échange IHM Modes de marche *)
    TranslationM3 : ST_TranslationHMI;(* ↔️ Variables d'échange IHM Translation M3 *)
    Cycle   : ST_CycleHMI;    (* 🔄 Commandes, états et diagnostic cycle semi-automatique *)
    Network : ST_NetworkDiagHMI;(* 📡 Variables d'échange IHM Diagnostics réseau *)
    Commun  : ST_CommunHMI; (* 🌐 REX 2026-07-08 : signaux communs, pas propres à un axe (TopPositionSensorActive, BrakeThermalFault, LimitLegal) *)
    // 🔧 REX 2026-07-19 : IHM_MANU (ST_IHM_MANU) supprimé définitivement — dispositif dérogatoire
    // de mise en service urgence (2026-07-09), remplacé par MAINT_N1/MAINT_N2 + joystick homme-mort.
    // Historique complet : ARCHIVES/Doc/IHM_MANU_Journal_Modifications.md.
    HmiInitDone : BOOL;               (* 🚩 Indicateur d'initialisation IHM depuis PERSISTENT *)
END_VAR

(* ═══════════════════════════════════════════════════════════════
   📝 NOTE : PROCÉDURE DE TEST SUR BANC AVEC SIMULATION DYNAMIQUE
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie-13_Fonction_Simulation_v1.2.md
   Cette simulation (GVL_Simulation + CODE/SIMULATION/FB_Sim_*) permet de
   valider le comportement des treuils M1/M2, du Homing et du Benne sans
   moteurs ni codeurs physiques connectés.

   1. CONFIGURATION INITIALE DU BANC DE TEST :
      - Bit maître déjà TRUE par défaut : GVL_Simulation.SimulationModeActive
      - Tous les `*IsReal` restent FALSE par défaut (tout est simulé). Si un
        device précis est déjà câblé réel, basculer UNIQUEMENT son
        `*IsReal` à TRUE (ex. GVL_Simulation.SensorEmergencyStopChainIsReal).
      - Forcer la demande de mode machine en maintenance N1 :
        GVL_IHM.Modes.SelMode := E_Mode.MAINT_N1
      - Acquitter les défauts initiaux domaine sécurité/métier (🔧 REX 2026-07-07 : plus de
        reset unique — Modes/Cycle ont chacun le leur, voir GVL_IHM.Modes.BtnModeReset /
        CmdResetCycle_IHM dans PRG_05_Cycle) :
        GVL_IHM.Modes.BtnFaultReset := TRUE puis FALSE (front)

   2. TEST DU MOUVEMENT DES TREUILS :
      - Le homme-mort joystick reste RÉEL (plus de bypass) : simuler un appui
        en forçant `PRG_01_Diagnostics.instSimJoystick.RawButton` à TRUE en
        instance CODESYS, et un débattement via `RawX`/`RawY`.
      - Vérifier que les codeurs simulés (`PRG_02_Encoders.instSimEncoderM1/M2.RawPosOut`)
        incrémentent en montée (Fwd) et décrémentent en descente (Rev),
        proportionnellement à la vitesse.

   3. TEST DE LA PROCÉDURE DE HOMING (RÉFÉRENCEMENT NOMINAL) :
      - S'assurer que le mode est MAINT_N1 (requis pour le homing nominal).
      - Les treuils doivent être arrêtés (pas de commande de mouvement).
      - Simuler l'activation du capteur de position haute commun :
        GVL_Simulation.SensorTopPositionIsReal reste FALSE, puis forcer
        PRG_00_Inputs.M1_M2_TopPositionSensor_DI à TRUE (ou l'OR équivalent)
       - Lancer le homing nominal en basculant indépendamment le bouton du treuil voulu :
         GVL_IHM.M1TreuilRetenue.BtnHome ou GVL_IHM.M2TreuilBucket.BtnHome := TRUE puis FALSE (front).
         Les deux fronts peuvent être envoyés simultanément ; aucun sélecteur HomingMode_IHM
         ni bouton StubHomeButton_IHM n'est utilisé.
      - La simulation détectera le signal de preset (COD1_PresettTrigCmd /
        COD2_PresettTrigCmd) et écrira automatiquement la valeur du preset
        dans les registres bruts simulés.
      - Vérifier que instHomingM1.Homed et instHomingM2.Homed passent à TRUE.
      - La position calculée (CablePosM) doit se caler exactement à 8.5m
         (ou la valeur définie par CfgTopSensorPosM de chaque structure IHM).

   4. TEST DU BENNE (OUVERTURE / FERMETURE) — 🔧 REX 2026-07-07 : sens ET offset inversés
      - S'assurer que les treuils ont été préalablement référencés (Homed = TRUE sur M1 ET M2 —
        désormais vérifié en dur par FB_Bucket, bit3 ErrorId "Codeur(s) non référencé(s)" sinon).
      - Choisir une commande Benne sur l'IHM :
        * Pour OUVRIR : GVL_IHM.Bucket.BtnOpen := TRUE (et BtnClose := FALSE)
        * Pour FERMER : GVL_IHM.Bucket.BtnClose := TRUE (et BtnOpen := FALSE)
      - Actionner et maintenir le joystick Y dans le sens correspondant :
        * UP / enrouler (Direction = 1) pour la FERMETURE
        * DOWN / dérouler (Direction = -1) pour l'OUVERTURE
      - Le bloc Benne prend le contrôle de M2 en vitesse lente forcée :
        * En fermeture, le codeur simulé M2 augmente jusqu'à ce que CablePosM2 >= CablePosM1 + OffsetCloseM (8.5m + 10.0m = 18.5m).
        * En ouverture, le codeur simulé M2 diminue jusqu'à ce que CablePosM2 <= CablePosM1 + OffsetOpenM (8.5m + 0.0m = 8.5m).
          ⚠️ Juste après un homing M1+M2 (les deux à 8.5m), la cible d'ouverture est DÉJÀ atteinte
          (CablePosM2 = CablePosM1) : une demande d'ouverture se termine donc immédiatement (Done)
          sans mouvement réel de M2 — comportement normal, pas un bug.
      - Vérifier que Benne.Busy passe à FALSE et Benne.Done à TRUE lorsque la
        cible est atteinte, et que l'état physique du benne est mis à jour.
      - Relâcher le joystick pour terminer le cycle de commande.
   ═══════════════════════════════════════════════════════════════ *)

