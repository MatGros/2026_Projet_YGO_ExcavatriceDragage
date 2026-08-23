(* ═══════════════════════════════════════════════════════════════
   📡 PRG_02_Acquisition — Programme d'Acquisition et Conditionnement I/O
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 1 (premier POU du cycle).
   📄 Doc : DOC/AF/AF_Partie-06_Acquisition_Qualification_IO_v2.3.md §2
   🎯 Rôle unique : Produire les images HwReal/HwSim/HwIn,
      acquérir et traiter les mesures codeurs (M1/M2), décoder M3, traiter le joystick
      et publier les retours.
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_02_Acquisition

VAR_INPUT
    DataIn                     : BOOL;
    DeviceJoystickStateRaw      : DEVICE_STATE; // --> [HW]  Valeur brute JOY1.GetDeviceState()
END_VAR

VAR_OUTPUT
    // === 🚌 BUS INTER-PRG (producteur unique) ===
    DataOut                     : INT; // <-- [BUS] Mesures/joystick/positions M3/diag DI publiés

END_VAR

VAR
    // === 🧩 SOUS-INSTANCES FB ===
    instSimBench             : REAL;                   // * [INST] Banc de simulation integré
 
END_VAR

VAR CONSTANT
    // === ⚙️ CONSTANTES MÉCANIQUES (AF09 §2) ===
    ENCODER_POINTS_PER_REV     : UDINT := 8192; // 13 bits single-turn (8192 pts/tour)

END_VAR

{region "§0 Session simulation & aiguillage"}
// === 🧪 §0 SIMULATION & SÉLECTION DE SOURCE ===
// 🎯 Producteur unique des aiguillages Reel/Simu par domaine (HwReal vs HwSim -> HwIn).



instSimBench(
    Enable                   := GVL_Simulation.SimulationModeActive,
    M1_RelayFwd              := PRG_06_Outputs.Data.M1RelayFwd,
    // 🧪 Simulation M3 — FIDÉLITÉ : le modèle ne doit progresser QUE quand la
    // vraie machine commande réellement (sortie FB_Translation, post-interlock), pas sur la
    // commande brute (sinon il outrepasse butées/limites). Même principe que les treuils M1/M2
    // (alimentés par la sortie PRG_06). Gate direction + vitesse = demande réelle (rampe/arrêt).
    M3_Direction             := SEL(PRG_05_Translation.Data.TranslationFinalInterlockRequest.RequestedDriveControlWord <> 0,
                                    PRG_05_Translation.M3_Direction_Active, 0),
    M3_SpeedRefPct           := LIMIT(0.0,
                                      PRG_05_Translation.Data.TranslationFinalInterlockRequest.RequestedDriveFreqHz / GVL_PERSISTENT._TranslationMaxFreq_Hz * 100.0,
                                      100.0),
    M3_BrakeCmd              := PRG_06_Outputs.Data.TranslationBrakeCmd,
    PowerKeepAlive_A         := PRG_06_Outputs.Data.PowerKeepAliveACmd,
    PowerKeepAlive_B         := PRG_06_Outputs.Data.PowerKeepAliveBCmd,
    // 🧪 Simulation uniquement : l'état étape 5 sécurise le transfert même si la sortie
    // inter-POU ArmPulse est observée avec un cycle de retard dans la tâche.
    EmergencyArming_RQ       := PRG_06_Outputs.Data.EmergencyArmingCmd
                                 OR (PRG_06_Outputs.ArmingSeqStep = 5),
    SimJoystickBagotement_Active       := GVL_Simulation.SimJoystickBagotement_Active,
    SimKoboldContactValue    := GVL_Simulation.SimKoboldContactValue,
    RawPosM2                 := _SimEncoderRawPosM2
);


END_PROGRAM
