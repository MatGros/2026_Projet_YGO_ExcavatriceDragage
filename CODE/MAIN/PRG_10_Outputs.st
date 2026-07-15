(* ═══════════════════════════════════════════════════════════════
   📤 PRG_10_Outputs — Écriture des SORTIES physiques (PROGRAMME)
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF_Partie6_IO_Conditioning_v1.2.md §5
   ⚙️ Exécuté par la tâche PLC en position 10.
   ✅ Reçoit ses commandes en VAR_INPUT (écrites par le reste du code).
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_10_Outputs
VAR_INPUT
    // ── 🪝 TREUIL M1 ─────────────────────────────────────────────────────────────────────
    M1RelayFwd        : BOOL;  // ⬆️ Relais MONTÉE M1 (NO) : TRUE=bobine ON, moteur monte | FALSE=arrêt ✅
    M1RelayRev        : BOOL;  // ⬇️ Relais DESCENTE M1 (NO) : TRUE=bobine ON, moteur descend | FALSE=arrêt ✅
    M1SpeedContactor1 : BOOL;  // 🐢 Contacteur vitesse 1 M1 — palier 1 lent (résistance max)
    M1SpeedContactor2 : BOOL;  // 🐇 Contacteur vitesse 2 M1 — palier 2
    M1SpeedContactor3 : BOOL;  // 🐇🐇 Contacteur vitesse 3 M1 — palier 3
    M1SpeedContactor4 : BOOL;  // 🚀 Contacteur vitesse 4 M1 — palier 4 pleine puissance
    M1BrakeCmd        : BOOL;  // 🔓 Frein M1 ⚠️INVERSÉ : TRUE=desserré/mouvement | FALSE=SERRÉ sécurité ✅

    // ── 🪝 TREUIL M2 (même logique que M1) ──────────────────────────────────────────────
    M2RelayFwd        : BOOL;  // ⬆️ Relais MONTÉE M2 (NO) : TRUE=bobine ON, moteur monte | FALSE=arrêt ✅
    M2RelayRev        : BOOL;  // ⬇️ Relais DESCENTE M2 (NO) : TRUE=bobine ON, moteur descend | FALSE=arrêt ✅
    M2SpeedContactor1 : BOOL;  // 🐢 Contacteur vitesse 1 M2 — palier 1 lent
    M2SpeedContactor2 : BOOL;  // 🐇 Contacteur vitesse 2 M2 — palier 2
    M2SpeedContactor3 : BOOL;  // 🐇🐇 Contacteur vitesse 3 M2 — palier 3
    M2SpeedContactor4 : BOOL;  // 🚀 Contacteur vitesse 4 M2 — palier 4 pleine puissance
    M2BrakeCmd        : BOOL;  // 🔓 Frein M2 ⚠️INVERSÉ : TRUE=desserré/mouvement | FALSE=SERRÉ sécurité ✅

    // ── ↔️ CHARIOT M3 (sens/vitesse via variateur EtherCAT, TOR=frein uniquement) ────────
    ChariotBrakeCmd   : BOOL;  // 🔓 Frein M3 ⚠️INVERSÉ : TRUE=desserré/mouvement | FALSE=SERRÉ sécurité ✅
END_VAR
VAR_OUTPUT
    // 🔧 REX 2026-07-07 — état séquence réarmement AU, exposé pour affichage IHM (PRG_09_Supervision)
    EmergencyArmingPulseActive   : BOOL; // Pulse 1s en cours
    EmergencyArmingLockoutActive: BOOL; // Verrouillage 5s après pulse (mécanisme à ressort)
    ArmingSeqStep                : INT;  // 0=IDLE,1=TestA,2=RestoreA,3=TestB,4=RestoreB,5=Pulse,6=Confirm
    RedundancyTestFailed         : BOOL; // Canal A ou B non fonctionnel détecté à l'auto-test — bloque le réarmement
    EmergencyArmingFailed        : BOOL; // Impulsion envoyée mais contacteur puissance jamais confirmé
END_VAR
VAR
    // Instances de sortie
    instM1RelayFwd        : FB_Output;
    instM1RelayRev        : FB_Output;
    instM1SpeedContactor1 : FB_Output;
    instM1SpeedContactor2 : FB_Output;
    instM1SpeedContactor3 : FB_Output;
    instM1SpeedContactor4 : FB_Output;
    instM1BrakeCmd        : FB_Output;

    instM2RelayFwd        : FB_Output;
    instM2RelayRev        : FB_Output;
    instM2SpeedContactor1 : FB_Output;
    instM2SpeedContactor2 : FB_Output;
    instM2SpeedContactor3 : FB_Output;
    instM2SpeedContactor4 : FB_Output;
    instM2BrakeCmd        : FB_Output;

    instChariotBrakeCmd   : FB_Output;

    // 🔧 REX 2026-07-07 — séquence réarmement AU + auto-test redondance A/B (voir §🚨 en bas de fichier)
    ArmReqEdge            : R_TRIG;
    ResetEdge             : R_TRIG;
    ForceTestA            : BOOL; // force PowerCutOff_A_RQ bas pendant l'auto-test canal A
    ForceTestB            : BOOL; // force PowerCutOff_B_RQ bas pendant l'auto-test canal B
    TonTestA              : TON;  // 200ms — coupe A seul, vérifie EmergencyChain tombe
    TonRestoreA           : TON;  // 200ms — restaure A, attend le retour de la boucle
    TonTestB              : TON;  // 200ms — coupe B seul, vérifie EmergencyChain tombe
    TonRestoreB           : TON;  // 200ms — restaure B, attend le retour de la boucle
    TonArmingPulse        : TON;  // 1s — durée de l'impulsion réarmement (mécanisme à ressort)
    TonArmingConfirm      : TON;  // 2s — attente confirmation contacteur après le pulse
    TonArmingLockout      : TON;  // 5s — verrouillage avant nouvelle tentative possible

    // ─────────  Début modification IHM_MANU  ─────────
    // 🆕 REX 2026-07-09 — Mode IHM_MANU (mise en service urgence, override direct sorties)
    ManuActive            : BOOL; // NOT GVL_IHM.IHM_MANU.ModeDisable (logique inversée, voir ST_IHM_MANU)
    // Détection de fronts montants pour priorité temporelle (Boutons HMI uniquement)
    TrigM1Fwd             : BOOL;
    TrigM1Rev             : BOOL;
    TrigM2Fwd             : BOOL;
    TrigM2Rev             : BOOL;
    TrigCoupledFwd        : BOOL;
    TrigCoupledRev        : BOOL;
    TrigM3Fwd             : BOOL;
    TrigM3Rev             : BOOL;
    // États au scan précédent (Boutons HMI uniquement)
    LastM1Fwd             : BOOL;
    LastM1Rev             : BOOL;
    LastM2Fwd             : BOOL;
    LastM2Rev             : BOOL;
    LastCoupledFwd        : BOOL;
    LastCoupledRev        : BOOL;
    LastM3Fwd             : BOOL;
    LastM3Rev             : BOOL;

    // Commandes brutes demandées (après aiguillage HMI / Joystick)
    M1Fwd_Demand          : BOOL;
    M1Rev_Demand          : BOOL;
    M2Fwd_Demand          : BOOL;
    M2Rev_Demand          : BOOL;
    CoupledFwd_Demand     : BOOL;
    CoupledRev_Demand     : BOOL;
    M3Fwd_Demand          : BOOL;
    M3Rev_Demand          : BOOL;

    // États effectifs calculés (après interlocks) — M3 uniquement : M1/M2 pilotés désormais via
    // FB_Winch (PRG_06_WinchControl §1/§2, REX 2026-07-15 (2)) — ex-M1Fwd_Eff/M1Rev_Eff/M2Fwd_Eff/
    // M2Rev_Eff/K1-4_Eff/SimM1Fwd_Eff/SimM1Rev_Eff/SimM2Fwd_Eff/SimM2Rev_Eff RETIRÉS (obsolètes,
    // FB_Winch gère nativement rampe+paliers+ralentissement bordure+relais tenu pendant décél).
    M3Fwd_Eff             : BOOL;
    M3Rev_Eff             : BOOL;

    instM3RelayFwdLed     : FB_Output; // 💡 LED témoin mise en service (M3_RelayFwd_DQ) — PAS de mouvement réel
    instM3RelayRevLed     : FB_Output; // 💡 LED témoin mise en service (M3_RelayRev_DQ) — PAS de mouvement réel

    // 🔧 REX 2026-07-15 (2) : rampe HMI locale (CycleTimeCalc/instHmiSpeedRamp/SpeedRefPct) et
    // décodage paliers (instManuSpeedStep/ActiveMaxStepFwd/Rev) RETIRÉS avec M1Fwd_Eff ci-dessus.
    WinchMoving           : BOOL;         // 🚨 Au moins une commande de treuil HMI active (verrouillage aiguillage)
    M3_ActiveFreqCmd      : REAL;         // ⚡ Consigne active fréquence Chariot M3 au cycle courant (Hz)
    M3_DriveIsReal        : BOOL;         // ⚡ Indique si le variateur Chariot M3 est configuré comme réel
    M1_IsReal             : BOOL;         // ⚡ Indique si le treuil M1 est configuré comme réel
    M2_IsReal             : BOOL;         // ⚡ Indique si le treuil M2 est configuré comme réel
    M3_IsReal             : BOOL;         // ⚡ Indique si le chariot M3 est configuré comme réel
    PowerCutOffActive_Eff : BOOL;         // ⚡ Indique si une coupure de puissance est active sur un équipement réel
    StartupNeutralOk      : BOOL := FALSE; // 🔒 Sécurité démarrage : exige le retour au neutre initial
    // ─────────  Fin modification IHM_MANU  ─────────
END_VAR

// === IMPLEMENTATION (corps du PROGRAM PRG_10_Outputs) ===

// ─────────  Début modification IHM_MANU  ─────────
// ═══════════════════════════════════════════════════════════════════════════
// 🚨 MODE IHM_MANU — override direct des sorties (mise en service urgence)
// ───────────────────────────────────────────────────────────────────────────
// 🆕 REX 2026-07-09 : logique inversée VOLONTAIRE — GVL_IHM.IHM_MANU.ModeDisable
// est non-RETAIN, donc FALSE à CHAQUE démarrage/download automate = mode Manu
// ACTIF d'origine, sans action opérateur. Il faut explicitement passer
// ModeDisable=TRUE pour rendre la main au programme fonctionnel normal
// (PRG_06_WinchControl/PRG_07_ChariotControl/PRG_03_Safety, intouchés).
// ⚠️ Aucune sécurité logicielle métier active en Manu (safety M1/M2/M3, synchro,
// limites logicielles, homing) — seuls les interlocks Fwd/Rev, K1-K4 ci-dessous,
// les fins de course grappin, et la chaîne AU/PowerCutOff (§ plus bas, TOUJOURS
// active, non bypassée), protègent la machine et les personnes.
// 📍 Placé en tête de PRG_10_Outputs (position tâche 10, la plus en aval) : écrase
// les VAR_INPUT juste avant leur écriture réelle, APRÈS que PRG_06/07 (positions
// 6/7) les aient déjà remplis — le programme normal tourne dans le vide, ignoré.
ManuActive := NOT GVL_IHM.IHM_MANU.ModeDisable;

// Affichage position — utile même hors Manu pour vérifier le câblage codeur en direct
GVL_IHM.IHM_MANU.PositionM_M1 := PRG_02_Encoders.instEncoderScaleM1.CablePosM;
GVL_IHM.IHM_MANU.PositionM_M2 := PRG_02_Encoders.instEncoderScaleM2.CablePosM;

// 📊 Calcul de l'écart grappin et des états de fin de course (delta = M1 - M2)
GVL_IHM.IHM_MANU.GrappinDelta := GVL_IHM.IHM_MANU.PositionM_M1 - GVL_IHM.IHM_MANU.PositionM_M2;
GVL_IHM.IHM_MANU.FdcGrappinOpenActive  := GVL_IHM.IHM_MANU.FdcGrappinOpen AND (GVL_IHM.IHM_MANU.GrappinDelta >= 0.0);
GVL_IHM.IHM_MANU.FdcGrappinCloseActive := GVL_IHM.IHM_MANU.FdcGrappinClose AND (GVL_IHM.IHM_MANU.GrappinDelta <= -10.0);

IF ManuActive THEN
    // 1️⃣ Détection des nouveaux appuis sur boutons HMI (uniquement pour interlocks HMI)
    TrigM1Fwd      := GVL_IHM.IHM_MANU.M1_RelayFwd AND NOT LastM1Fwd;
    TrigM1Rev      := GVL_IHM.IHM_MANU.M1_RelayRev AND NOT LastM1Rev;
    TrigM2Fwd      := GVL_IHM.IHM_MANU.M2_RelayFwd AND NOT LastM2Fwd;
    TrigM2Rev      := GVL_IHM.IHM_MANU.M2_RelayRev AND NOT LastM2Rev;
    TrigCoupledFwd := GVL_IHM.IHM_MANU.M1_M2_RelayFwd AND NOT LastCoupledFwd;
    TrigCoupledRev := GVL_IHM.IHM_MANU.M1_M2_RelayRev AND NOT LastCoupledRev;
    TrigM3Fwd      := GVL_IHM.IHM_MANU.M3_RelayFwd AND NOT LastM3Fwd;
    TrigM3Rev      := GVL_IHM.IHM_MANU.M3_RelayRev AND NOT LastM3Rev;

    // 2️⃣ Interlocks de sécurité sur boutons HMI (Montée vs Descente)
    IF GVL_IHM.IHM_MANU.M1_RelayFwd AND GVL_IHM.IHM_MANU.M1_RelayRev THEN
        IF TrigM1Rev THEN
            GVL_IHM.IHM_MANU.M1_RelayRev := FALSE; (* Rejet Rev *)
        ELSIF TrigM1Fwd THEN
            GVL_IHM.IHM_MANU.M1_RelayFwd := FALSE; (* Rejet Fwd *)
        ELSE
            GVL_IHM.IHM_MANU.M1_RelayFwd := FALSE;
            GVL_IHM.IHM_MANU.M1_RelayRev := FALSE;
        END_IF;
    END_IF;

    IF GVL_IHM.IHM_MANU.M2_RelayFwd AND GVL_IHM.IHM_MANU.M2_RelayRev THEN
        IF TrigM2Rev THEN
            GVL_IHM.IHM_MANU.M2_RelayRev := FALSE;
        ELSIF TrigM2Fwd THEN
            GVL_IHM.IHM_MANU.M2_RelayFwd := FALSE;
        ELSE
            GVL_IHM.IHM_MANU.M2_RelayFwd := FALSE;
            GVL_IHM.IHM_MANU.M2_RelayRev := FALSE;
        END_IF;
    END_IF;

    IF GVL_IHM.IHM_MANU.M1_M2_RelayFwd AND GVL_IHM.IHM_MANU.M1_M2_RelayRev THEN
        IF TrigCoupledRev THEN
            GVL_IHM.IHM_MANU.M1_M2_RelayRev := FALSE;
        ELSIF TrigCoupledFwd THEN
            GVL_IHM.IHM_MANU.M1_M2_RelayFwd := FALSE;
        ELSE
            GVL_IHM.IHM_MANU.M1_M2_RelayFwd := FALSE;
            GVL_IHM.IHM_MANU.M1_M2_RelayRev := FALSE;
        END_IF;
    END_IF;

    IF GVL_IHM.IHM_MANU.M3_RelayFwd AND GVL_IHM.IHM_MANU.M3_RelayRev THEN
        IF TrigM3Rev THEN
            GVL_IHM.IHM_MANU.M3_RelayRev := FALSE;
        ELSIF TrigM3Fwd THEN
            GVL_IHM.IHM_MANU.M3_RelayFwd := FALSE;
        ELSE
            GVL_IHM.IHM_MANU.M3_RelayFwd := FALSE;
            GVL_IHM.IHM_MANU.M3_RelayRev := FALSE;
        END_IF;
    END_IF;

    // 3️⃣ Conflits boutons HMI entre mouvements Individuels et Couplés
    IF GVL_IHM.IHM_MANU.M1_M2_RelayFwd THEN
        IF GVL_IHM.IHM_MANU.M1_RelayRev THEN GVL_IHM.IHM_MANU.M1_RelayRev := FALSE; END_IF;
        IF GVL_IHM.IHM_MANU.M2_RelayRev THEN GVL_IHM.IHM_MANU.M2_RelayRev := FALSE; END_IF;
    END_IF;

    IF GVL_IHM.IHM_MANU.M1_M2_RelayRev THEN
        IF GVL_IHM.IHM_MANU.M1_RelayFwd THEN GVL_IHM.IHM_MANU.M1_RelayFwd := FALSE; END_IF;
        IF GVL_IHM.IHM_MANU.M2_RelayFwd THEN GVL_IHM.IHM_MANU.M2_RelayFwd := FALSE; END_IF;
    END_IF;

    IF (GVL_IHM.IHM_MANU.M1_RelayRev OR GVL_IHM.IHM_MANU.M2_RelayRev) AND GVL_IHM.IHM_MANU.M1_M2_RelayFwd THEN
        GVL_IHM.IHM_MANU.M1_M2_RelayFwd := FALSE;
    END_IF;

    IF (GVL_IHM.IHM_MANU.M1_RelayFwd OR GVL_IHM.IHM_MANU.M2_RelayFwd) AND GVL_IHM.IHM_MANU.M1_M2_RelayRev THEN
        GVL_IHM.IHM_MANU.M1_M2_RelayRev := FALSE;
    END_IF;

    // 4️⃣ Aiguillage de la commande de mouvement (HMI vs Joystick CANopen)
    M3_DriveIsReal := (NOT GVL_Simulation.SimulationModeActive OR GVL_Simulation.VariateurM3_IsReal)
                      AND (NOT GVL_Simulation.SimulationModeActive OR GVL_Simulation.ChariotPosition_IsReal);
    M1_IsReal := NOT GVL_Simulation.SimulationModeActive OR GVL_Simulation.EncoderM1_IsReal OR GVL_Simulation.ContactorFeedbackM1_IsReal OR GVL_Simulation.ThermalM1_IsReal;
    M2_IsReal := NOT GVL_Simulation.SimulationModeActive OR GVL_Simulation.EncoderM2_IsReal OR GVL_Simulation.ContactorFeedbackM2_IsReal OR GVL_Simulation.ThermalM2_IsReal;
    M3_IsReal := NOT GVL_Simulation.SimulationModeActive OR GVL_Simulation.VariateurM3_IsReal OR GVL_Simulation.ContactorFeedbackM3_IsReal OR GVL_Simulation.ChariotPosition_IsReal;
    PowerCutOffActive_Eff := (M1_IsReal AND PRG_03_Safety.instSafetyWinchM1.PowerCutOff)
                             OR (M2_IsReal AND PRG_03_Safety.instSafetyWinchM2.PowerCutOff)
                             OR (M3_IsReal AND PRG_03_Safety.instSafetyChariotM3.PowerCutOff);
    // ⚡ Clamp de sécurité sur la consigne saisie par l'opérateur (limité par le plafond absolu persistant)
    IF GVL_IHM.IHM_MANU.M3_FreqSetpoint > GVL_PERSISTENT.ChariotMaxFreqHz THEN
        GVL_IHM.IHM_MANU.M3_FreqSetpoint := GVL_PERSISTENT.ChariotMaxFreqHz;
    ELSIF GVL_IHM.IHM_MANU.M3_FreqSetpoint < 0.0 THEN
        GVL_IHM.IHM_MANU.M3_FreqSetpoint := 0.0;
    END_IF;

    IF GVL_IHM.IHM_MANU.JoystickSelect THEN
        // Commandes via le Joystick CANopen (arbitrées selon le mode de sécurité de FB_Modes, cf. TASK-0001)
        M1Fwd_Demand := (PRG_04_Modes.instModes.JoystickWinchSelectArbitrated = 1) AND (PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.Direction = 1);
        M1Rev_Demand := (PRG_04_Modes.instModes.JoystickWinchSelectArbitrated = 1) AND (PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.Direction = -1);
        
        M2Fwd_Demand := (PRG_04_Modes.instModes.JoystickWinchSelectArbitrated = 2) AND (PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.Direction = 1);
        M2Rev_Demand := (PRG_04_Modes.instModes.JoystickWinchSelectArbitrated = 2) AND (PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.Direction = -1);
        
        CoupledFwd_Demand := (PRG_04_Modes.instModes.JoystickWinchSelectArbitrated = 3) AND (PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.Direction = 1);
        CoupledRev_Demand := (PRG_04_Modes.instModes.JoystickWinchSelectArbitrated = 3) AND (PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.Direction = -1);
        
        M3Fwd_Demand := (PRG_01_Diagnostics.FB_Joystick_0.AxisCmdX.Direction = 1);
        M3Rev_Demand := (PRG_01_Diagnostics.FB_Joystick_0.AxisCmdX.Direction = -1);
        
        // Consigne active Chariot M3 (0..M3_FreqSetpoint Hz) via déflexion X (la consigne HMI est prise pour 100%)
        M3_ActiveFreqCmd := (ABS(PRG_01_Diagnostics.FB_Joystick_0.AxisCmdX.SpeedRef) / 100.0) * GVL_IHM.IHM_MANU.M3_FreqSetpoint;
    ELSE
        // 💡 Détection de mouvement en cours (pour verrouillage croisé)
        WinchMoving := M1Fwd_Demand OR M1Rev_Demand OR M2Fwd_Demand OR M2Rev_Demand OR CoupledFwd_Demand OR CoupledRev_Demand;

        // 🔒 Verrouillage d'aiguillage HMI : on ne démarre un mouvement que si aucun autre n'est en cours
        // 🔧 REX 2026-07-15 (2) : ex-tenue "AND SpeedRefPct > 0.1" retirée — rampe HMI locale
        // supprimée (M1/M2 pilotés via FB_Winch, PRG_06_WinchControl), qui gère désormais SEUL la
        // rampe et l'interlock de changement de sens (DirectionChangePending/DirectionChangeDelay,
        // voir FB_Winch.st) : plus besoin de tenir la demande le temps d'une décél locale ici.
        M1Fwd_Demand := GVL_IHM.IHM_MANU.M1_RelayFwd AND (NOT WinchMoving OR M1Fwd_Demand);
        M1Rev_Demand := GVL_IHM.IHM_MANU.M1_RelayRev AND (NOT WinchMoving OR M1Rev_Demand);
        M2Fwd_Demand := GVL_IHM.IHM_MANU.M2_RelayFwd AND (NOT WinchMoving OR M2Fwd_Demand);
        M2Rev_Demand := GVL_IHM.IHM_MANU.M2_RelayRev AND (NOT WinchMoving OR M2Rev_Demand);
        CoupledFwd_Demand := GVL_IHM.IHM_MANU.M1_M2_RelayFwd AND (NOT WinchMoving OR CoupledFwd_Demand);
        CoupledRev_Demand := GVL_IHM.IHM_MANU.M1_M2_RelayRev AND (NOT WinchMoving OR CoupledRev_Demand);

        M3Fwd_Demand := GVL_IHM.IHM_MANU.M3_RelayFwd;
        M3Rev_Demand := GVL_IHM.IHM_MANU.M3_RelayRev;

        // En mode HMI boutons / Simulation, la consigne active envoyée est directement M3_FreqSetpoint
        M3_ActiveFreqCmd := GVL_IHM.IHM_MANU.M3_FreqSetpoint;
    END_IF;

    // 🔒 Sécurité démarrage : exige que toutes les commandes HMI et Joystick soient au repos (neutre) au démarrage
    IF NOT StartupNeutralOk THEN
        IF NOT GVL_IHM.IHM_MANU.M1_RelayFwd AND NOT GVL_IHM.IHM_MANU.M1_RelayRev
           AND NOT GVL_IHM.IHM_MANU.M2_RelayFwd AND NOT GVL_IHM.IHM_MANU.M2_RelayRev
           AND NOT GVL_IHM.IHM_MANU.M1_M2_RelayFwd AND NOT GVL_IHM.IHM_MANU.M1_M2_RelayRev
           AND NOT GVL_IHM.IHM_MANU.M3_RelayFwd AND NOT GVL_IHM.IHM_MANU.M3_RelayRev
           AND ABS(PRG_01_Diagnostics.FB_Joystick_0.AxisCmdX.SpeedRef) < 1.0
           AND ABS(PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.SpeedRef) < 1.0 THEN
            StartupNeutralOk := TRUE;
        END_IF;
    END_IF;

    IF NOT StartupNeutralOk THEN
        M1Fwd_Demand := FALSE;
        M1Rev_Demand := FALSE;
        M2Fwd_Demand := FALSE;
        M2Rev_Demand := FALSE;
        CoupledFwd_Demand := FALSE;
        CoupledRev_Demand := FALSE;
        M3Fwd_Demand := FALSE;
        M3Rev_Demand := FALSE;
    END_IF;

    // 🔧 REX 2026-07-15 (2) : ex-§5️⃣/§5bis/§6️⃣ (M1Fwd_Eff/M1Rev_Eff/M2Fwd_Eff/M2Rev_Eff/
    // SimM1Fwd_Eff.../décodage K1-K4 via instManuSpeedStep) RETIRÉS — M1/M2 pilotés désormais par
    // instWinchM1/instWinchM2 (PRG_06_WinchControl §1/§2/§6/§7), qui écrivent directement
    // PRG_10_Outputs.M1RelayFwd/M1RelayRev/M1SpeedContactor1-4/M1BrakeCmd (et M2) via §8 de ce
    // même fichier PRG_06 — AVANT que ce PRG_10_Outputs ne s'exécute (position 6 < 10). Plus besoin
    // de "Recopie vers les VAR_INPUT" ci-dessous pour M1/M2 (voir fin de fichier).

    // 7️⃣ Commandes effectives Chariot M3 (interlockées avec l'AU, et avec la disponibilité variateur SEULEMENT s'il est configuré Réel)
    M3Fwd_Eff := M3Fwd_Demand AND PRG_00_Inputs.EmergencyStopOk 
                 AND (M3_StatusWord.7 OR NOT M3_DriveIsReal) 
                 AND (M3_StatusWord.0 OR NOT M3_DriveIsReal)
                 AND (NOT M3_IsReal OR NOT PRG_03_Safety.instSafetyChariotM3.SafeStop);

    M3Rev_Eff := M3Rev_Demand AND PRG_00_Inputs.EmergencyStopOk 
                 AND (M3_StatusWord.7 OR NOT M3_DriveIsReal) 
                 AND (M3_StatusWord.0 OR NOT M3_DriveIsReal)
                 AND (NOT M3_IsReal OR NOT PRG_03_Safety.instSafetyChariotM3.SafeStop);

    // 8️⃣ Auxiliaires Hydrauliques (action maintenue IHM + interlock logique d'exclusion mutuelle)
    IF GVL_IHM.IHM_MANU.GridOpenCmd AND NOT GVL_IHM.IHM_MANU.GridCloseCmd AND PRG_00_Inputs.EmergencyStopOk THEN
        GridUp_RQ := TRUE;
        GridDown_RQ := FALSE;
    ELSIF GVL_IHM.IHM_MANU.GridCloseCmd AND NOT GVL_IHM.IHM_MANU.GridOpenCmd AND PRG_00_Inputs.EmergencyStopOk THEN
        GridUp_RQ := FALSE;
        GridDown_RQ := TRUE;
    ELSE
        GridUp_RQ := FALSE;
        GridDown_RQ := FALSE;
    END_IF;

    IF GVL_IHM.IHM_MANU.HelmetOpenCmd AND NOT GVL_IHM.IHM_MANU.HelmetCloseCmd AND PRG_00_Inputs.EmergencyStopOk THEN
        HelmetOpen_RQ := TRUE;
        HelmetClose_RQ := FALSE;
    ELSIF GVL_IHM.IHM_MANU.HelmetCloseCmd AND NOT GVL_IHM.IHM_MANU.HelmetOpenCmd AND PRG_00_Inputs.EmergencyStopOk THEN
        HelmetOpen_RQ := FALSE;
        HelmetClose_RQ := TRUE;
    ELSE
        HelmetOpen_RQ := FALSE;
        HelmetClose_RQ := FALSE;
    END_IF;

    // Démarrage automatique du groupe hydraulique si un mouvement auxiliaire est demandé et AU armé
    PRG_08_AuxiliaryControl.HydraulicPumpRunCmd := (GVL_IHM.IHM_MANU.GridOpenCmd 
                                                 OR GVL_IHM.IHM_MANU.GridCloseCmd 
                                                 OR GVL_IHM.IHM_MANU.HelmetOpenCmd 
                                                 OR GVL_IHM.IHM_MANU.HelmetCloseCmd)
                                                 AND PRG_00_Inputs.EmergencyStopOk;

    // 🔧 REX 2026-07-15 (2) : plus de recopie M1/M2 ici — déjà écrites par PRG_06_WinchControl §8
    // (instWinchM1/instWinchM2.RelayFwd/RelayRev/Contactor1-4/BrakeCmd), AVANT ce PRG_10_Outputs
    // dans l'ordre de tâche (position 6 < 10), pour Auto ET Manu désormais.
    ChariotBrakeCmd   := M3Fwd_Eff OR M3Rev_Eff;
ELSE
    // Nettoyage en cas de désactivation du mode Manu
    GridUp_RQ := FALSE;
    GridDown_RQ := FALSE;
    HelmetOpen_RQ := FALSE;
    HelmetClose_RQ := FALSE;
END_IF;

// ── Chariot M3 — variateur EtherCAT AC600, mot de commande direct (PAS de relais) ──
// 🔧 REX 2026-07-09 : recette fournisseur pour LE REGISTRE 0x3101 Command (carte EtherCAT,
// PAS le 0x3001 natif du variateur — sémantique différente) : 0=arrêt, 1=marche avant,
// 2=marche arrière. ⚠️ Non vérifié sur banc au moment du codage — à confirmer par
// l'opérateur (Force CODESYS sur M3_CommandWord, moteur à vide si possible) avant un
// usage prolongé. Rien d'autre n'écrit ces PDO aujourd'hui (FB_Chariot encore stubbé,
// DriveStatusWord/ActualFreqHz à 0 en dur) — pas de conflit avec le mode normal.
IF ManuActive AND M3Fwd_Eff THEN
    M3_CommandWord         := 1;
    M3_SetpointFrequencyHz := REAL_TO_UINT(MIN(M3_ActiveFreqCmd, GVL_PERSISTENT.ChariotMaxFreqHz) * 100.0);
ELSIF ManuActive AND M3Rev_Eff THEN
    M3_CommandWord         := 2;
    M3_SetpointFrequencyHz := REAL_TO_UINT(MIN(M3_ActiveFreqCmd, GVL_PERSISTENT.ChariotMaxFreqHz) * 100.0);
ELSE
    M3_CommandWord         := 0; // Arrêt — couvre repos ET mode normal (non-Manu)
    M3_SetpointFrequencyHz := 0;
END_IF;
GVL_IHM.IHM_MANU.M3_FreqActual         := UINT_TO_REAL(M3_ActualFrequencyHz) / 100.0;

// Recopie des mots de commande et d'état pour monitoring HMI
GVL_IHM.IHM_MANU.M3_CommandWordMonitor := M3_CommandWord;
GVL_IHM.IHM_MANU.M3_StatusWordMonitor  := M3_StatusWord;
GVL_IHM.IHM_MANU.M3_CommReady          := M3_StatusWord.7 OR GVL_Simulation.SimulationModeActive;
GVL_IHM.IHM_MANU.M3_PowerReady         := M3_StatusWord.0 OR GVL_Simulation.SimulationModeActive;

// 💡 LED témoin M3 (mise en service) — reflète la demande interlockée, PAS le mouvement réel du variateur
instM3RelayFwdLed(Command := ManuActive AND M3Fwd_Eff);
M3_RelayFwd_DQ := instM3RelayFwdLed.State;
instM3RelayRevLed(Command := ManuActive AND M3Rev_Eff);
M3_RelayRev_DQ := instM3RelayRevLed.State;

// 9️⃣ Enregistrement de l'état précédent (pour le cycle suivant)
LastM1Fwd      := GVL_IHM.IHM_MANU.M1_RelayFwd;
LastM1Rev      := GVL_IHM.IHM_MANU.M1_RelayRev;
LastM2Fwd      := GVL_IHM.IHM_MANU.M2_RelayFwd;
LastM2Rev      := GVL_IHM.IHM_MANU.M2_RelayRev;
LastCoupledFwd := GVL_IHM.IHM_MANU.M1_M2_RelayFwd;
LastCoupledRev := GVL_IHM.IHM_MANU.M1_M2_RelayRev;
LastM3Fwd      := GVL_IHM.IHM_MANU.M3_RelayFwd;
LastM3Rev      := GVL_IHM.IHM_MANU.M3_RelayRev;
// ─────────  Fin modification IHM_MANU  ─────────

// 🪝 ─── WINCH M1 — lit les VAR_INPUT de PRG_10_Outputs, écrit les I/O réels ────
instM1RelayFwd(Command := M1RelayFwd);
M1_RelayFwd_DQ := instM1RelayFwd.State;

instM1RelayRev(Command := M1RelayRev);
M1_RelayRev_DQ := instM1RelayRev.State;

instM1SpeedContactor1(Command := M1SpeedContactor1);
M1_SpeedContactor_1_DQ := instM1SpeedContactor1.State;

instM1SpeedContactor2(Command := M1SpeedContactor2);
M1_SpeedContactor_2_DQ := instM1SpeedContactor2.State;

instM1SpeedContactor3(Command := M1SpeedContactor3);
M1_SpeedContactor_3_DQ := instM1SpeedContactor3.State;

instM1SpeedContactor4(Command := M1SpeedContactor4);
M1_SpeedContactor_4_DQ := instM1SpeedContactor4.State;

instM1BrakeCmd(Command := M1BrakeCmd);
M1_BrakeCmd_RQ := instM1BrakeCmd.State;

// 🪝 ─── WINCH M2 ──────────────────────────────────────────────────────────
instM2RelayFwd(Command := M2RelayFwd);
M2_RelayFwd_DQ := instM2RelayFwd.State;

instM2RelayRev(Command := M2RelayRev);
M2_RelayRev_DQ := instM2RelayRev.State;

instM2SpeedContactor1(Command := M2SpeedContactor1);
M2_SpeedContactor_1_DQ := instM2SpeedContactor1.State;

instM2SpeedContactor2(Command := M2SpeedContactor2);
M2_SpeedContactor_2_DQ := instM2SpeedContactor2.State;

instM2SpeedContactor3(Command := M2SpeedContactor3);
M2_SpeedContactor_3_DQ := instM2SpeedContactor3.State;

instM2SpeedContactor4(Command := M2SpeedContactor4);
M2_SpeedContactor_4_DQ := instM2SpeedContactor4.State;

instM2BrakeCmd(Command := M2BrakeCmd);
M2_BrakeCmd_RQ := instM2BrakeCmd.State;

// ↔️ ─── CHARIOT M3 ────────────────────────────────────────────────────────
instChariotBrakeCmd(Command := ChariotBrakeCmd);
M3_BrakeCmd_RQ := instChariotBrakeCmd.State;


// ─── 🧨 COUPURE PUISSANCE AMONT REDONDANTE (Série physique, commande parallèle) ────────
// 🔴🔧 REX 2026-07-07 : ARCHITECTURE À COMMANDE MAINTENUE (fail-safe) — retour terrain.
// PowerCutOff_A_RQ/B_RQ doivent être MAINTENUS à TRUE tant que tout va bien ; le circuit AU
// s'ouvre (coupe le contacteur de puissance) dès que le PLC ARRÊTE de les maintenir — que ce
// soit volontairement (défaut Méca A/B/C détecté) OU accidentellement (PLC tombe/coupure
// automate). Polarité INVERSÉE par rapport à la 1ère version (qui mettait TRUE = "coupe",
// erreur de conception : en cas de défaut réel, ça aurait MAINTENU la puissance au lieu de
// la couper — pire cas de figure).
// 🔧 REX 2026-07-07 (2) : ForceTestA/ForceTestB permettent à l'auto-test de redondance
// (ci-dessous) de forcer UN SEUL canal bas à la fois, sans dépendre d'un vrai défaut Méca A/B/C.
// ─────────  Début modification IHM_MANU  ─────────
// 🆕 REX 2026-07-09 — MODE IHM_MANU : demande explicite utilisateur — en Manu, RQ_A/B = TRUE
// FIXE dès que l'automate tourne, SANS EXCEPTION (ni Méca A/B/C, ni auto-test ForceTestA/B, ni
// bouton IHM CmdEmergencyCutOff — ce dernier n'a donc plus d'effet tant que ModeDisable=FALSE).
// Seul l'AU physique (chaîne matérielle indépendante) protège encore en Manu.
IF ManuActive THEN
    PowerCutOff_A_RQ := NOT PowerCutOffActive_Eff AND NOT ForceTestA;
    PowerCutOff_B_RQ := NOT PowerCutOffActive_Eff AND NOT ForceTestB;
    // ─────────  Fin modification IHM_MANU  ─────────
ELSE
PowerCutOff_A_RQ := NOT (PRG_03_Safety.instSafetyWinchM1.PowerCutOff
                         OR PRG_03_Safety.instSafetyWinchM2.PowerCutOff
                         OR PRG_03_Safety.instSafetyChariotM3.PowerCutOff)
                    AND NOT ForceTestA
                    AND NOT GVL_IHM.Modes.CmdEmergencyCutOff;

PowerCutOff_B_RQ := NOT (PRG_03_Safety.instSafetyWinchM1.PowerCutOff
                         OR PRG_03_Safety.instSafetyWinchM2.PowerCutOff
                         OR PRG_03_Safety.instSafetyChariotM3.PowerCutOff)
                    AND NOT ForceTestB
                    AND NOT GVL_IHM.Modes.CmdEmergencyCutOff;
END_IF;

// ─── 🚨 SÉQUENCE RÉARMEMENT CONTACTEUR PUISSANCE (REX 2026-07-07) ──────────────────────
// Commande IHM (front, PAS de réarmement automatique) →
//   1) auto-test canal A seul (200ms, coupe A/vérifie EmergencyChain tombe) puis restaure (200ms)
//   2) auto-test canal B seul (200ms) puis restaure (200ms)
//   3) si les 2 canaux sont validés : impulsion 1s sur EmergencyArming_RQ (mécanisme à ressort)
//   4) attente confirmation contacteur (EmergencyStopOk) sous 2s
//   5) verrouillage 5s avant nouvelle tentative possible, succès ou échec
// Si un canal échoue l'auto-test → RedundancyTestFailed, tout est bloqué (on ne peut pas démarrer
// avec un seul contact de sécurité réellement fonctionnel).
ResetEdge(CLK := PRG_09_Supervision.FaultMachineReset_IHM);

ArmReqEdge(CLK := GVL_IHM.Modes.CmdEmergencyArming);
IF ArmReqEdge.Q AND (ArmingSeqStep = 0) AND PRG_00_Inputs.EmergencyChain
   AND NOT EmergencyArmingLockoutActive
   AND NOT PRG_00_Inputs.EmergencyStopOk THEN // 🆕 REX 2026-07-08 : Ignoré si déjà armé pour éviter une coupure intempestive lors de l'auto-test
    ArmingSeqStep := 1;
END_IF;

// Étape 1 : coupe canal A seul, vérifie que la boucle tombe
TonTestA(IN := (ArmingSeqStep = 1), PT := T#200MS);
IF ArmingSeqStep = 1 THEN
    ForceTestA := TRUE;
    IF TonTestA.Q THEN
        ForceTestA := FALSE;
        IF PRG_00_Inputs.EmergencyChain THEN
            // La boucle n'est PAS tombée alors qu'on a coupé A seul → canal A shunté/défaillant
            RedundancyTestFailed := TRUE;
            ArmingSeqStep := 0;
        ELSE
            ArmingSeqStep := 2;
        END_IF;
    END_IF;
ELSE
    ForceTestA := FALSE;
END_IF;

// Étape 2 : restaure A, attend le retour de la boucle
TonRestoreA(IN := (ArmingSeqStep = 2), PT := T#200MS);
IF (ArmingSeqStep = 2) AND TonRestoreA.Q THEN
    IF PRG_00_Inputs.EmergencyChain THEN
        ArmingSeqStep := 3;
    ELSE
        ArmingSeqStep := 0; // boucle pas revenue saine (AU pressé entre-temps ?) — pas d'alarme dédiée, l'opérateur relance
    END_IF;
END_IF;

// Étape 3 : coupe canal B seul, vérifie que la boucle tombe
TonTestB(IN := (ArmingSeqStep = 3), PT := T#200MS);
IF ArmingSeqStep = 3 THEN
    ForceTestB := TRUE;
    IF TonTestB.Q THEN
        ForceTestB := FALSE;
        IF PRG_00_Inputs.EmergencyChain THEN
            RedundancyTestFailed := TRUE;
            ArmingSeqStep := 0;
        ELSE
            ArmingSeqStep := 4;
        END_IF;
    END_IF;
ELSE
    ForceTestB := FALSE;
END_IF;

// Étape 4 : restaure B, attend le retour de la boucle
TonRestoreB(IN := (ArmingSeqStep = 4), PT := T#200MS);
IF (ArmingSeqStep = 4) AND TonRestoreB.Q THEN
    IF PRG_00_Inputs.EmergencyChain THEN
        ArmingSeqStep := 5;
    ELSE
        ArmingSeqStep := 0;
    END_IF;
END_IF;

// Étape 5 : les 2 canaux validés → impulsion réarmement 1s
EmergencyArmingPulseActive := (ArmingSeqStep = 5);
TonArmingPulse(IN := (ArmingSeqStep = 5), PT := T#1S);
IF (ArmingSeqStep = 5) AND TonArmingPulse.Q THEN
    ArmingSeqStep := 6;
END_IF;

// Étape 6 : attente confirmation contacteur (2s max)
TonArmingConfirm(IN := (ArmingSeqStep = 6), PT := T#2S);
IF ArmingSeqStep = 6 THEN
    IF PRG_00_Inputs.EmergencyStopOk THEN
        ArmingSeqStep := 0;
        EmergencyArmingLockoutActive := TRUE;
    ELSIF TonArmingConfirm.Q THEN
        EmergencyArmingFailed := TRUE;
        ArmingSeqStep := 0;
        EmergencyArmingLockoutActive := TRUE;
    END_IF;
END_IF;

TonArmingLockout(IN := EmergencyArmingLockoutActive, PT := T#5S);
IF TonArmingLockout.Q THEN
    EmergencyArmingLockoutActive := FALSE;
END_IF;

EmergencyArming_RQ := EmergencyArmingPulseActive;

IF ResetEdge.Q THEN
    RedundancyTestFailed := FALSE; // défaut câblage : pas de "cause disparue" détectable, front seul suffit
    IF PRG_00_Inputs.EmergencyStopOk THEN
        EmergencyArmingFailed := FALSE; // cause disparue (contacteur confirmé) + front reset
    END_IF;
END_IF;
