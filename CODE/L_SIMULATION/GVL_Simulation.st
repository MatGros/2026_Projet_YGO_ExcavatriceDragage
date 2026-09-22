(* ═══════════════════════════════════════════════════════════════
   🧪 GVL_Simulation — Variables et stimuli de simulation (Banc d'essai)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF/AF_Partie-13_Fonction_Simulation_v2.5.md
   🎯 Polarité positive : TRUE = simulé/stimulus actif ; FALSE = réel/repos.
   🔒 Consommée à la frontière PRG_02_Acquisition, par le banc, et par PRG_04_Treuils_Benne
   🔒 (SimulationBypassActive : n'arme les bypass de sécurité QUE si SimulationModeActive
   🔒  ET SimWinchActive — strictement inopérant sur machine réelle).
   ═══════════════════════════════════════════════════════════════ *)

{attribute 'qualified_only'}
VAR_GLOBAL
    // 🔑 Bit maître — rien n'est simulé si FALSE (machine réelle)
    SimulationModeActive        : BOOL := FALSE;
    // 🎭 Master Bypass Essais Banc — arme les bypass Meca (Safety/Process) en mode MAINT
    // (inopérant sur machine réelle). Arme aussi les limites banc TopLimitSwitch,
    // TopLimitSoftware et CableLimitSwitch, exclusivement sous le triple gate
    // SimulationModeActive AND SimWinchActive AND SimulationBypassActive.
    // Défaut TRUE : pré-arme le bypass banc dès le boot (n'agit que si SimulationModeActive AND SimWinchActive).
    // Permet de travailler en banc sans faux blocage Meca au homing sans mouvement.
    SimulationBypassActive      : BOOL := FALSE;

    // 🌐 Activation par domaine (simulé si SimulationModeActive AND Sim<Domaine>Active)
    SimWinchActive              : BOOL := FALSE; // M1+M2 : codeurs, contacteurs, freins, thermiques, capteur haut, câble tendu
    // Stimulus explicite du capteur haut commun pour qualifier le référencement benne.
    // TRUE = capteur haut actif; FALSE = position libre. Inopérant hors simulation.
    SimTopPositionActive        : BOOL := FALSE;
    SimTranslationActive        : BOOL := FALSE; // M3 : AC600, fréquence, 5 capteurs et frein
    SimOperatorActive           : BOOL := FALSE; // Joystick : bus CANopen, axes RawX/RawY et homme-mort brut
    SimSafetyActive             : BOOL := FALSE; // AU, contacteur puissance, phases, thermiques, Kobold et auxiliaires communs
    // 🧪 Stimulus défaut rotation de phases : TRUE = phases réseau saines (comportement
    // nominal, identique au codage en dur d'avant ce lot) ; FALSE = inverse/coupe les phases
    // (PhaseRotationOk_DI = FALSE dans l'image machine simulée). Inopérant hors simulation.
    SimPhaseRotationOk          : BOOL := TRUE;

    // ↔️ STIMULI TRANSLATION M3 — override manuel du mot capteurs, sinon modèle dynamique.
    // Bit4=Trémie, bit3=PV, bit2=PVP2, bit1=P1, bit0=Maintenance ; 16#07 = position P2 (00111).
    SimM3SensorsWordOverrideActive : BOOL := FALSE; // TRUE = SimM3SensorsWord remplace le modèle ; réserver aux injections ciblées
    SimM3SensorsWord               : BYTE := 16#07; // Mot manuel valide nominal : P2
    // Episode capteur dynamique : FALSE conserve le profil nominal. TRUE publie des
    // pertes/reprises deterministes apres un franchissement mecanique, pour qualifier
    // le decodeur et les fins de course sans ecrire directement dans le metier.
    SimM3SensorIntermittenceActive  : BOOL := FALSE;
    SimM3SensorStabilizationS       : REAL := 1.0;
    SimM3SensorElectricalDelayS     : REAL := 0.01;
    SimM3SensorIntermittencePeriodS : REAL := 0.12;
    SimM3SensorHysteresis_M         : REAL := 0.02;
    SimM3SensorLoadAngleTriggerRad  : REAL := 0.01;
    SimM3SensorScenarioSeed         : UDINT := 3001;
    // ⚡ BLIP COURT — second profil de perte/reprise, independant du train ~1 s ci-dessus
    // (SimM3SensorStabilizationS). 0 = desactive (profil historique inchange).
    // Rejoue les excursions courtes de la trace terrain du 2026-09-04 :
    //   Tremie : 1 excursion de 0,2 s (actif 2 echantillons a 12,24 s en s'eloignant) ;
    //   PV     : 1 excursion de 0,1 s (reactive 1 echantillon a 14,94 s en deceleration).
    SimM3SensorBlipTransitions      : UDINT := 0;
    SimM3SensorBlipDurationS        : REAL := 0.2;
    // 🧲 BUTEE MECANIQUE M3 — recul borne apres arret serre (C5).
    // 0.0 = behavior historique : position ET vitesse figees a la butee (decision de review
    // tracee). > 0 autorise la reaction de charge a ressortir le chariot de la zone capteur.
    // Valeur SYNTHETIQUE, non calibree : a mesurer en mise en service.
    SimM3EndStopRecoilMax_M         : REAL := 0.0;
    // Gain de reaction de charge utilisee par le modele M3 (SYNTHETIQUE).
    // 0.20 = valeur historique ; un gain plus eleve est necessaire pour rejouer le recul
    // post-arret observe sur la trace terrain du 2026-09-04. A calibrer.
    SimM3LoadReactionGain_Mps2      : REAL := 0.20;
    // 🔥 FAUTE EXPLICITE FREIN M3 — defaut FALSE : comportement nominal strictement inchange.
    // TRUE rejoue le defaut terrain « cause 6 instantanee » : contact frein ferme alors que le
    // variateur retourne encore 10,00 Hz (trace 2026-09-04, 26,437 s, State.ErrorId=64).
    // La garde nominale de fermeture (0,5 Hz) est CONSERVEE : elle est validee par la meme trace
    // (frein ouvert a 0,60 Hz, ferme a 0,00 Hz). Stimulus de banc, inoperant hors simulation.
    SimM3BrakeFaultCloseWhileRunning : BOOL := FALSE;
    SimM3BrakeFaultCloseDelayS       : REAL := 0.0;

    // 🕹️ STIMULI OPÉRATEUR — les boutons directionnels imposent 0/5000/10000 ; combinaison = neutre.
    SimJoystickLeft_Rev_TREMIE_Active  : BOOL := FALSE; // Translation M3 Arrière vers Trémie (RawX=0, RawY=5000)
    SimJoystickRight_Fwd_MAINT_Active  : BOOL := FALSE; // Translation M3 Avant vers Maintenance (RawX=10000, RawY=5000)
    SimJoystickFwd_Up_Close_Active     : BOOL := FALSE; // Treuils Ascending M1/M2 / Fermeture Benne M2 (RawX=5000, RawY=10000)
    SimJoystickRev_Down_Open_Active    : BOOL := FALSE; // Treuils Descending M1/M2 / Ouverture Benne M2 (RawX=5000, RawY=0)
    SimJoystickRawX                    : INT := 5000;  // Stimulus analogique avancé 0..10000, utilisé sans bouton directionnel
    SimJoystickRawY                    : INT := 5000;  // Stimulus analogique avancé 0..10000, utilisé sans bouton directionnel
    SimJoystickRawButton               : BOOL := FALSE; // Homme-mort brut : TRUE = bouton joystick appuyé
    SimJoystickOvershoot_Active        : BOOL := FALSE; // TRUE = dépassement de montée au-delà de 100% (défaut capteur hors plage)
    SimJoystickBagotement_Active       : BOOL := FALSE; // TRUE = bagotement au relâchement (petit balancement autour du neutre)

    // 🎛️ STIMULI BOUTONS IHM M3 — simulation des boutons IHM Translation M3 (Trémie/Maintenance).
    // Pilotent GVL_IHM.M3Translation.Cmd.BtnTremie/BtnMaintenance UNIQUEMENT en mode simulation
    // ET quand JoyMaster est inactif (le joystick prime sinon). Défaut FALSE = bouton relâché.
    SimBtnTremie         : BOOL := FALSE; // TRUE = bouton IHM "vers Trémie" simulé appuyé
    SimBtnMaintenance    : BOOL := FALSE; // TRUE = bouton IHM "vers Maintenance" simulé appuyé

    // 🪝 STIMULI TREUILS — paramètres du modèle codeur et injection ponctuelle d'un défaut synchro.
    SimEncoderSpeedFactor       : REAL := 1.0;  // Multiplicateur vitesse codeurs simulés ; 1.0 = nominal
    SimWinchCoast_M             : REAL := 0.35;  // Roulis inertiel treuils simulés après coupure des relais (m). 0 = arrêt net. ~0.35 = la benne roule quelques dizaines de cm après l'arrêt commandé -> finit dans la bande ouvert/fermé (±CoherenceLimitM) malgré l'anticipation d'arrêt (Close 1.0 / Open 1.3).
    SimSyncDeviationInjectM1    : BOOL := FALSE; // Front montant : ajoute SimSyncDeviationOffset_M à la position M1 simulée
    SimSyncDeviationInjectM2    : BOOL := FALSE; // Front montant : ajoute SimSyncDeviationOffset_M à la position M2 simulée
    SimSyncDeviationOffset_M    : REAL := 0.5; // Écart signé injecté, mètres ; persiste dans la position simulée jusqu'au reset/preset

    // === PROFIL SIMPLE / DYNAMIQUES TREUILS ===
    // FALSE = retour historique instantané ; TRUE = applique les trois réglages synthétiques ci-dessous.
    SimWinchDynamicsActive              : BOOL := FALSE;
    SimWinchSpeedReportTauS             : REAL := 0.15;
    SimWinchBrakeOpenDelayS             : REAL := 0.10;
    SimWinchBrakeCloseDelayS            : REAL := 0.09;
    // Diagnostic électrique isolé : ne pilote jamais une entrée safety ou une commande moteur.
    SimWinchElectricalDiagnosticsActive : BOOL := TRUE;

    // === ACQUITTEMENT DIAGNOSTIC TRANSITOIRE (réseaux EtherCAT / CANopen) ===
    // ⛔ Aucun réglage de PRODUCTION ici : les 2 autorisations et les 3 temporisations de ce
    //    service vivent au site d'appel, câblées en dur à TRUE et aux défauts déclarés du FB.
    //    Cette GVL ne porte que des réglages de BANC (frontière réel/simulé).

    // Injection safety explicite : TRUE simule le câble non tendu ; FALSE = signal nominal sain.
    SimM2TensionedCableFaultInject      : BOOL := FALSE;

    // 🔗 RATTRAPAGE MÉCANIQUE M1/M2 — le banc reproduit la reprise de jeu entre les deux treuils.
    // En MONTÉE couplée (relais de sens identiques + freins desserrés côté sim), l'écart relatif
    // M2-M1 rejoint la bande FERMÉE au lieu de rester bloqué juste en dessous (trou métier de
    // fermeture : coupure d'anticipation à 13,8 m alors que l'état fermé exige 14,0 m), ce qui
    // laissait la benne « non fermée » et plafonnait la montée au palier 1. Inopérant hors simulation.
    SimWinchCouplingModelActive : BOOL := TRUE;   // [CFG] TRUE = rattrapage mécanique modélisé (FALSE = rejeu d'avant le lot)
    SimBucketJamActive          : BOOL := FALSE;  // [TST] TRUE = mâchoires bloquées (objet coincé) : pas de rattrapage, charge forcée

    // 🪝 MODÈLE M2 / KOBOLD — réglages de banc, actifs exclusivement via FB_SimBench.
    // M2 est calculé depuis M1 pendant une descente BOTH effective. Le coefficient est
    // issu de la trace 2026-09-05 ; TRUE par défaut pour reproduire le comportement mesuré.
    SimM2CoupledDescentModelActive : BOOL := TRUE;
    SimM2CoupledDescentFactor      : REAL := 0.9333; // Ratio déplacement M2 / déplacement M1 en descente BOTH (mesure: 0,6 m / 9 m)

    // Le mode auto est armé sur entrée SEMI_AUTO pendant la simulation et libéré à sa sortie.
    // Une désactivation opérateur pendant une plongée est prise en compte à la plongée suivante.
    SimKoboldAutoModeActive    : BOOL := FALSE;
    SimKoboldAutoDepth_M       : REAL := -15.0;  // Altitude fond signée (m), négative sous l'eau
    SimKoboldPowerUpTime       : TIME := T#50ms; // Réponse sonde après alimentation Kobold
    SimKoboldCoast_M           : REAL := 1.0;   // Roulis déterministe M1/M2 après arrêt Kobold (m)

    // 🛡️ STIMULI SAFETY — fait capteur amont, jamais une sortie de commande forcée.
    SimKoboldContactValue       : BOOL := FALSE; // TRUE = Kobold détecte un contact fond simulé
    // 🧪 Contrôle granulaire de la chaîne AU : TRUE = simuler la chaîne fermée (on peut armer) ;
    //    FALSE = chaîne ouverte (on ne peut pas armer). Défaut FALSE → à la ré-entrée en simu,
    //    la chaîne est ouverte et le contacteur non engagé (on n'a pas armé).
    SimChainOk                  : BOOL := FALSE;
END_VAR
