(* ═══════════════════════════════════════════════════════════════
   🧪 GVL_Simulation — Variables et stimuli de simulation (Banc d'essai)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF/AF_Partie-13_Fonction_Simulation_v2.3.md
   🎯 Polarité positive : TRUE = simulé/stimulus actif ; FALSE = réel/repos.
   🔒 Consommée à la frontière PRG_02_Acquisition, par le banc, et par PRG_04_Treuils_Benne
   🔒 (SimulationBypassActive : n'arme les bypass de sécurité QUE si SimulationModeActive
   🔒  ET SimWinchActive — strictement inopérant sur machine réelle).
   ═══════════════════════════════════════════════════════════════ *)

{attribute 'qualified_only'}
VAR_GLOBAL
    // 🔑 Bit maître — rien n'est simulé si FALSE (machine réelle)
    SimulationModeActive        : BOOL := FALSE;
    // 🎭 Master Bypass Essais Banc — arme LimitLegal + TopLimits en mode MAINT (inopérant sur machine réelle)
    SimulationBypassActive      : BOOL := FALSE;

    // 🌐 Activation par domaine (simulé si SimulationModeActive AND Sim<Domaine>Active)
    SimWinchActive              : BOOL := FALSE; // M1+M2 : codeurs, contacteurs, freins, thermiques, capteur haut, câble tendu
    SimTranslationActive        : BOOL := FALSE; // M3 : AC600, fréquence, 5 capteurs et frein
    SimOperatorActive           : BOOL := FALSE; // Joystick : bus CANopen, axes RawX/RawY et homme-mort brut
    SimSafetyActive             : BOOL := FALSE; // AU, contacteur puissance, phases, thermiques, Kobold et auxiliaires communs

    // ↔️ STIMULI TRANSLATION M3 — override manuel du mot capteurs, sinon modèle dynamique.
    // Bit4=Trémie, bit3=PV, bit2=PVP2, bit1=P1, bit0=Maintenance ; 16#07 = position P2 (00111).
    SimM3SensorsWordOverrideActive : BOOL := FALSE; // TRUE = SimM3SensorsWord remplace le modèle ; réserver aux injections ciblées
    SimM3SensorsWord               : BYTE := 16#07; // Mot manuel valide nominal : P2

    // 🕹️ STIMULI OPÉRATEUR — les boutons directionnels imposent 0/5000/10000 ; combinaison = neutre.
    SimJoystickLeft_Rev_TREMIE_Active  : BOOL := FALSE; // Translation M3 Arrière vers Trémie (RawX=0, RawY=5000)
    SimJoystickRight_Fwd_MAINT_Active  : BOOL := FALSE; // Translation M3 Avant vers Maintenance (RawX=10000, RawY=5000)
    SimJoystickFwd_Up_Close_Active     : BOOL := FALSE; // Treuils Montée M1/M2 / Fermeture Benne M2 (RawX=5000, RawY=10000)
    SimJoystickRev_Down_Open_Active    : BOOL := FALSE; // Treuils Descente M1/M2 / Ouverture Benne M2 (RawX=5000, RawY=0)
    SimJoystickRawX                    : INT := 5000;  // Stimulus analogique avancé 0..10000, utilisé sans bouton directionnel
    SimJoystickRawY                    : INT := 5000;  // Stimulus analogique avancé 0..10000, utilisé sans bouton directionnel
    SimJoystickRawButton               : BOOL := FALSE; // Homme-mort brut : TRUE = bouton joystick appuyé

    // 🪝 STIMULI TREUILS — paramètres du modèle codeur et injection ponctuelle d'un défaut synchro.
    SimEncoderSpeedFactor       : REAL := 1.0;  // Multiplicateur vitesse codeurs simulés ; 1.0 = nominal
    SimSyncDeviationInjectM1    : BOOL := FALSE; // Front montant : ajoute SimSyncDeviationOffset_M à la position M1 simulée
    SimSyncDeviationInjectM2    : BOOL := FALSE; // Front montant : ajoute SimSyncDeviationOffset_M à la position M2 simulée
    SimSyncDeviationOffset_M    : REAL := 0.5; // Écart signé injecté, mètres ; persiste dans la position simulée jusqu'au reset/preset

    // 🛡️ STIMULI SAFETY — fait capteur amont, jamais une sortie de commande forcée.
    SimKoboldContactValue       : BOOL := FALSE; // TRUE = Kobold détecte un contact fond simulé
END_VAR
