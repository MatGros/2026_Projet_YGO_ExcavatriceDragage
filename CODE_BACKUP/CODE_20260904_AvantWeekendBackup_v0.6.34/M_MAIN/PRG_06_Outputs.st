(* ═══════════════════════════════════════════════════════════════
   📤 PRG_06_Outputs — Barrière finale des sorties physiques (ST pur)
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF/AF_Partie-06_Acquisition_Qualification_IO_v2.4.md §5
   ⚙️ Exécuté en position 6 (après PRG_05_Translation).
   🛡️ Interlocks finaux M1/M2/M3 + agrégation PowerCutOff + chaîne AU.
   🎨 Organisation FONCTIONNELLE : chaque bloc regroupe la chaîne complète d'une
       fonction — conditions qui activent/désactivent la sortie (SafeStop / PowerCutOff /
       interlocks) → FB interlock → ordres → sorties physiques → bus inter-PRG. Lisible
       d'un coup d'œil.
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_06_Outputs

VAR_INPUT
    // === 📥 ENTRÉES PROGRAMME (AUCUNE - PILOTÉ VIA GVL_IHM & PRG_02 À 05) ===
END_VAR

VAR_OUTPUT
    // === 🚌 BUS INTER-PRG (producteur unique) ===
    Data : ST_OutputsInterPrg; // <-- [BUS] Ordres actionneurs finaux (rebouclés FB_SimBench)

    // === 🚨 ÉTATS CHAÎNE AU & COUPURE ===
    EmergencyState               : ST_Safety_Emergency_State; // <-- [STAT] Etat chaine AU
    EmergencyDiag                : ST_Safety_Emergency_Diag;  // <-- [DIAG] Diagnostic chaine AU
    EmergencyReady               : BOOL; // <-- [STAT] FB AU pret a fonctionner (Enable + pas de StartupFail)
    EmergencyDone                : BOOL; // <-- [STAT] Cycle rearmement AU termine (contacteur confirme engage)
    EmergencyFault               : ST_Fault; // <-- [DIAG] Defaut latte chaine AU (socle FB_FaultCore)
    EmergencyOperatorMessage     : STRING(120); // <-- [DIAG] Message operateur par etat / probleme chaine AU
    PowerCutOffActive            : BOOL; // <-- [SAFE] Demande de coupure finale active

    M1InterlockEnable            : BOOL; // <-- [SAFE] Gate finale M1 (Enable AND NOT PowerCutOff)
    M2InterlockEnable            : BOOL; // <-- [SAFE] Gate finale M2 (Enable AND NOT PowerCutOff)
    M3InterlockEnable            : BOOL; // <-- [SAFE] Gate finale M3 (Enable AND NOT PowerCutOff)
    M1PowerCutOffSafetyInfo      : BOOL; // <-- [DIAG] Securites M1 coupant la puissance
    M1SafeStopSafetyInfo         : BOOL; // <-- [DIAG] Securites M1 SafeStop
    M1BlockedBySafetyInfo        : BOOL; // <-- [DIAG] M1 bloque par securite (PowerCutOff OU SafeStop)
    M2PowerCutOffSafetyInfo      : BOOL; // <-- [DIAG] Securites M2 coupant la puissance
    M2SafeStopSafetyInfo         : BOOL; // <-- [DIAG] Securites M2 SafeStop
    M2BlockedBySafetyInfo        : BOOL; // <-- [DIAG] M2 bloque par securite (PowerCutOff OU SafeStop)
    M3PowerCutOffSafetyInfo      : BOOL; // <-- [DIAG] Securites M3 coupant la puissance
    M3SafeStopSafetyInfo         : BOOL; // <-- [DIAG] Securites M3 SafeStop
    M3BlockedBySafetyInfo        : BOOL; // <-- [DIAG] M3 bloque par securite (PowerCutOff OU SafeStop)

    // Les noms Device bruts (*_DQ / *_RQ) ne sont pas declares ici : les declarer
    // creerait une collision avec la globale homonyme du mapping E/S.
    KoboldContactorCmd           : BOOL; // <-- [ACT] Ordre alimentation contacteur capteur fond Kobold
END_VAR

VAR
    // === 🛡️ SOUS-INSTANCES FB INTERLOCKS SORTIES ===
    instWinchOutputInterlockM1       : FB_WinchOutputInterlock;       // * [INST] Barriere finale treuil M1
    instWinchOutputInterlockM2       : FB_WinchOutputInterlock;       // * [INST] Barriere finale treuil M2
    instTranslationOutputInterlockM3 : FB_TranslationOutputInterlock; // * [INST] Barriere finale translation M3
    instSafetyEmergencyManagement    : FB_Safety_EmergencyManagement;    // * [INST] Gestionnaire de rearmement AU
    instArmContactorProtector        : FB_ContactorProtector;            // * [INST] Garde anti-chatter impulsion contacteur AU (EmergencyArming_RQ)
    instKeepAliveAProtector          : FB_ContactorProtector;            // * [INST] Garde anti-chatter contacteur CHAIN OK voie A (PowerKeepAlive_A_RQ)
    instKeepAliveBProtector          : FB_ContactorProtector;            // * [INST] Garde anti-chatter contacteur CHAIN OK voie B (PowerKeepAlive_B_RQ)
    // Garde anti-chatter DURE, au plus près des sorties mouvement : contacteurs de SENS et
    // de PALIER M1/M2. PAS sur le frein (doit re-desserrer immédiatement, cf. §2quater).
    // Cfg_MinInterval (CST_ContactorMinInterval) < TOUTE tempo de séquencement des interlocks
    // (DeadTime 1 s, RestartDelay 1,5 s, StepDelay 1,25 s) : transparent en exploitation.
    instM1FwdProtector               : FB_ContactorProtector;            // * [INST] Anti-chatter relais montée M1
    instM1RevProtector               : FB_ContactorProtector;            // * [INST] Anti-chatter relais descente M1
    instM1Sc1Protector               : FB_ContactorProtector;            // * [INST] Anti-chatter contacteur palier 1 M1
    instM1Sc2Protector               : FB_ContactorProtector;            // * [INST] Anti-chatter contacteur palier 2 M1
    instM1Sc3Protector               : FB_ContactorProtector;            // * [INST] Anti-chatter contacteur palier 3 M1
    instM1Sc4Protector               : FB_ContactorProtector;            // * [INST] Anti-chatter contacteur palier 4 M1
    instM2FwdProtector               : FB_ContactorProtector;            // * [INST] Anti-chatter relais montée/fermeture M2
    instM2RevProtector               : FB_ContactorProtector;            // * [INST] Anti-chatter relais descente/ouverture M2
    instM2Sc1Protector               : FB_ContactorProtector;            // * [INST] Anti-chatter contacteur palier 1 M2
    instM2Sc2Protector               : FB_ContactorProtector;            // * [INST] Anti-chatter contacteur palier 2 M2
    instM2Sc3Protector               : FB_ContactorProtector;            // * [INST] Anti-chatter contacteur palier 3 M2
    instM2Sc4Protector               : FB_ContactorProtector;            // * [INST] Anti-chatter contacteur palier 4 M2
    // Concordance contacteurs M1/M2 sur les vecteurs PHYSIQUES finaux (post §2quater),
    // reponse graduee (debounce 500 ms -> SafeStop ; +escalade -> PowerCutOff MecaE bit13).
    // Remplace le zeroage binaire instantane de l'ex-§2ter.
    instSyncContactorFinal          : FB_SyncContactor;                 // * [INST] Coherence commandes/contacteurs M1/M2 finaux

    // === ⚡ ORDRES ACTIONNEURS (publiés via Data) ===
    M1RelayFwd                   : BOOL; // . [LOC] Ordre contacteur montee treuil M1
    M1RelayRev                   : BOOL; // . [LOC] Ordre contacteur descente treuil M1
    M1SpeedContactor1            : BOOL; // . [LOC] Ordre contacteur palier 1 treuil M1
    M1SpeedContactor2            : BOOL; // . [LOC] Ordre contacteur palier 2 treuil M1
    M1SpeedContactor3            : BOOL; // . [LOC] Ordre contacteur palier 3 treuil M1
    M1SpeedContactor4            : BOOL; // . [LOC] Ordre contacteur palier 4 treuil M1
    M1BrakeCmd                   : BOOL; // . [LOC] Ordre desserrage frein M1
    M2RelayFwd                   : BOOL; // . [LOC] Ordre contacteur montee/fermeture treuil M2
    M2RelayRev                   : BOOL; // . [LOC] Ordre contacteur descente/ouverture treuil M2
    M2SpeedContactor1            : BOOL; // . [LOC] Ordre contacteur palier 1 treuil M2
    M2SpeedContactor2            : BOOL; // . [LOC] Ordre contacteur palier 2 treuil M2
    M2SpeedContactor3            : BOOL; // . [LOC] Ordre contacteur palier 3 treuil M2
    M2SpeedContactor4            : BOOL; // . [LOC] Ordre contacteur palier 4 treuil M2
    M2BrakeCmd                   : BOOL; // . [LOC] Ordre desserrage frein M2
    TranslationBrakeCmd          : BOOL; // . [LOC] Demande frein M3 arbitree
    PowerKeepAliveACmd           : BOOL; // . [LOC] Maintien puissance voie A
    PowerKeepAliveBCmd           : BOOL; // . [LOC] Maintien puissance voie B
    EmergencyArmingCmd           : BOOL; // . [LOC] Impulsion rearmement puissance AU

    // === ⚙️ VARIABLES LOCALES INTERNES ===
    PowerCutOffReq                   : BOOL; // . [LOC] Demande agregative coupure puissance

    // === 🔒 CONCORDANCE SORTIES TREUILS M1/M2 (§2ter) ===
    WinchOutputCoupled               : BOOL; // . [LOC] Treuils couples (synchro OU both) : arme instSyncContactorFinal
END_VAR

VAR CONSTANT
    // Intervalle mini entre 2 activations d'un même contacteur mouvement (anti-chatter dur).
    // Choisi STRICTEMENT sous la plus courte tempo de séquencement des interlocks
    // (BrakeTimeout 0,5 s) pour rester transparent en exploitation.
    CST_ContactorMinInterval         : TIME := T#400ms;
END_VAR

// ═══════════════════════════════════════════════════════════════
// 🛗 §1 TREUIL M1 (Retenue) — conditions + interlock + sorties
// ═══════════════════════════════════════════════════════════════
// 👁️ D'un coup d'œil : ce qui active/désactive la sortie M1.
//   - M1InterlockEnable      : gate finale (Enable ET pas de PowerCutOff)
//   - M1PowerCutOffSafetyInfo: défauts qui COUPENT la puissance
//   - M1SafeStopSafetyInfo   : défauts qui font SafeStop (rampe rapide)
//   - AscentPermit/DescendPermit : permis directionnels reconsommes par la barriere finale
//   - M1BlockedBySafetyInfo  : synthese (PowerCutOff OU SafeStop)
// Sources : PRG_04 (WinchM1FinalInterlockRequest / WinchM1Safety).

M1InterlockEnable := PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.Enable
                      AND NOT PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.PowerCutOff;

M1PowerCutOffSafetyInfo := PRG_04_Treuils_Benne.Data.WinchM1Safety.PowerCutOff
                        OR PRG_04_Treuils_Benne.Data.WinchM1Safety.ErrorMecaA
                        OR PRG_04_Treuils_Benne.Data.WinchM1Safety.ErrorMecaB
                        OR PRG_04_Treuils_Benne.Data.WinchM1Safety.ErrorMecaC
                        OR PRG_04_Treuils_Benne.Data.WinchM1Safety.ErrorMecaD
                        OR PRG_04_Treuils_Benne.Data.WinchM1Safety.ErrorMecaE
                        OR PRG_04_Treuils_Benne.Data.WinchM1Safety.ThermalFault;

M1SafeStopSafetyInfo := PRG_04_Treuils_Benne.Data.WinchM1Safety.SafeStop
                     OR PRG_04_Treuils_Benne.Data.WinchM1Safety.Error
                     OR PRG_04_Treuils_Benne.Data.WinchM1Safety.ErrorOperatorComm
                     OR PRG_04_Treuils_Benne.Data.WinchM1Safety.ErrorEncoder
                     OR PRG_04_Treuils_Benne.Data.WinchM1Safety.ErrorPhaseRotation
                     OR PRG_04_Treuils_Benne.Data.WinchM1Safety.ErrorOppositeDir
                     OR PRG_04_Treuils_Benne.Data.WinchM1Safety.ErrorNoMovement;

M1BlockedBySafetyInfo := M1PowerCutOffSafetyInfo OR M1SafeStopSafetyInfo;

instWinchOutputInterlockM1(
    Enable                     := M1InterlockEnable,
    Reset                      := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged      := PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.PowerContactorEngaged,
    SafeStop                   := PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.SafeStop,
    AscentPermit               := PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.AscentPermit,
    DescendPermit              := PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.DescendPermit,
    BrakeFeedback              := PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.BrakeFeedback,
    FwdRevSpeedFeedbackOff     := PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.FwdRevSpeedFeedbackOff,
    RequestedRelayFwd          := PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.RequestedRelayFwd,
    RequestedRelayRev          := PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.RequestedRelayRev,
    RequestedContactor1        := PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.RequestedContactor1,
    RequestedContactor2        := PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.RequestedContactor2,
    RequestedContactor3        := PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.RequestedContactor3,
    RequestedContactor4        := PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.RequestedContactor4,
    RequestedStep               := PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.RequestedStep
);

M1RelayFwd        := instWinchOutputInterlockM1.RelayFwd;
M1RelayRev        := instWinchOutputInterlockM1.RelayRev;
M1SpeedContactor1 := instWinchOutputInterlockM1.Contactor1;
M1SpeedContactor2 := instWinchOutputInterlockM1.Contactor2;
M1SpeedContactor3 := instWinchOutputInterlockM1.Contactor3;
M1SpeedContactor4 := instWinchOutputInterlockM1.Contactor4;
// Pre-calcul frein M1 (regate en §2ter apres controle concordance M1/M2).
M1BrakeCmd        := M1RelayFwd OR M1RelayRev;
// Sorties physiques M1 + bus inter-PRG : ecrites en §2ter, apres le controle
// de concordance des vecteurs M1/M2 (une seule ecriture des DQ treuils).

// ═══════════════════════════════════════════════════════════════
// 🛗 §2 TREUIL M2 (Benne) — conditions + interlock + sorties
// ═══════════════════════════════════════════════════════════════
// 👁️ Même lecture que M1 : gate finale, défauts PowerCutOff / SafeStop, synthèse.
// Sources : PRG_04 (WinchM2FinalInterlockRequest / WinchM2Safety / BucketState).

M2InterlockEnable := PRG_04_Treuils_Benne.Data.WinchM2FinalInterlockRequest.Enable
                      AND NOT PRG_04_Treuils_Benne.Data.WinchM2FinalInterlockRequest.PowerCutOff;

M2PowerCutOffSafetyInfo := PRG_04_Treuils_Benne.Data.WinchM2Safety.PowerCutOff
                        OR PRG_04_Treuils_Benne.Data.WinchM2Safety.ErrorMecaA
                        OR PRG_04_Treuils_Benne.Data.WinchM2Safety.ErrorMecaB
                        OR PRG_04_Treuils_Benne.Data.WinchM2Safety.ErrorMecaC
                        OR PRG_04_Treuils_Benne.Data.WinchM2Safety.ErrorMecaD
                        OR PRG_04_Treuils_Benne.Data.WinchM2Safety.ErrorMecaE
                        OR PRG_04_Treuils_Benne.Data.WinchM2Safety.ThermalFault;

M2SafeStopSafetyInfo := PRG_04_Treuils_Benne.Data.WinchM2Safety.SafeStop
                     OR PRG_04_Treuils_Benne.Data.WinchM2Safety.Error
                     OR PRG_04_Treuils_Benne.Data.WinchM2Safety.ErrorOperatorComm
                     OR PRG_04_Treuils_Benne.Data.WinchM2Safety.ErrorEncoder
                     OR PRG_04_Treuils_Benne.Data.WinchM2Safety.ErrorPhaseRotation
                     OR PRG_04_Treuils_Benne.Data.WinchM2Safety.ErrorOppositeDir
                     OR PRG_04_Treuils_Benne.Data.WinchM2Safety.ErrorNoMovement
                     OR PRG_04_Treuils_Benne.Data.WinchM2Safety.SlackCable
                     OR PRG_04_Treuils_Benne.Data.BucketState.Error
                     OR PRG_04_Treuils_Benne.Data.BucketState.CoupledMotionBlockedByBucket;

M2BlockedBySafetyInfo := M2PowerCutOffSafetyInfo OR M2SafeStopSafetyInfo;

instWinchOutputInterlockM2(
    Enable                     := M2InterlockEnable,
    Reset                      := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged      := PRG_04_Treuils_Benne.Data.WinchM2FinalInterlockRequest.PowerContactorEngaged,
    SafeStop                   := PRG_04_Treuils_Benne.Data.WinchM2FinalInterlockRequest.SafeStop,
    AscentPermit               := PRG_04_Treuils_Benne.Data.WinchM2FinalInterlockRequest.AscentPermit,
    DescendPermit              := PRG_04_Treuils_Benne.Data.WinchM2FinalInterlockRequest.DescendPermit,
    BrakeFeedback              := PRG_04_Treuils_Benne.Data.WinchM2FinalInterlockRequest.BrakeFeedback,
    FwdRevSpeedFeedbackOff     := PRG_04_Treuils_Benne.Data.WinchM2FinalInterlockRequest.FwdRevSpeedFeedbackOff,
    RequestedRelayFwd          := PRG_04_Treuils_Benne.Data.WinchM2FinalInterlockRequest.RequestedRelayFwd,
    RequestedRelayRev          := PRG_04_Treuils_Benne.Data.WinchM2FinalInterlockRequest.RequestedRelayRev,
    RequestedContactor1        := PRG_04_Treuils_Benne.Data.WinchM2FinalInterlockRequest.RequestedContactor1,
    RequestedContactor2        := PRG_04_Treuils_Benne.Data.WinchM2FinalInterlockRequest.RequestedContactor2,
    RequestedContactor3        := PRG_04_Treuils_Benne.Data.WinchM2FinalInterlockRequest.RequestedContactor3,
    RequestedContactor4        := PRG_04_Treuils_Benne.Data.WinchM2FinalInterlockRequest.RequestedContactor4,
    RequestedStep               := PRG_04_Treuils_Benne.Data.WinchM2FinalInterlockRequest.RequestedStep
);

M2RelayFwd        := instWinchOutputInterlockM2.RelayFwd;
M2RelayRev        := instWinchOutputInterlockM2.RelayRev;
M2SpeedContactor1 := instWinchOutputInterlockM2.Contactor1;
M2SpeedContactor2 := instWinchOutputInterlockM2.Contactor2;
M2SpeedContactor3 := instWinchOutputInterlockM2.Contactor3;
M2SpeedContactor4 := instWinchOutputInterlockM2.Contactor4;
// Pre-calcul frein M2 (regate en §2ter apres controle concordance M1/M2).
M2BrakeCmd        := M2RelayFwd OR M2RelayRev;

// ═══════════════════════════════════════════════════════════════
// 🔒 §2ter CONCORDANCE SORTIES TREUILS M1/M2
// ═══════════════════════════════════════════════════════════════
// Les 2 barrieres finales (instWinchOutputInterlockM1/M2) resolvent chacune leur
// commande via des tempos INDEPENDANTES : rien ne garantit des vecteurs identiques
// le meme scan. En couple, un contacteur asymetrique = les 2 treuils tirent le
// cable de facon desynchronisee.
// 🛡️ L'ex-zeroage binaire INSTANTANE est remplace par instSyncContactorFinal :
//    reponse graduee, debounce 500 ms (tolere les transitoires de changement de
//    palier), et remontee decodee. La coupure effective (SafeStop niveau 1,
//    PowerCutOff niveau 2 via MecaE bit13) est appliquee par la chaine safety
//    (PRG_04) au scan suivant. Bypass = GVL_IHM.M1M2Sync.Bypass.Global.
// Concordance contacteurs M1/M2 : jamais armee pendant un homing machine (M2-M1 varie
// volontairement de ~15 m -> faux ContactorMismatch -> escalade MecaE bit13 / PowerCutOff).
WinchOutputCoupled := (PRG_04_Treuils_Benne.Data.SyncState.SyncActive
                       OR PRG_03_Modes_Cycle.Data.WinchBothIntent.Active)
                      AND NOT PRG_02_Acquisition.Data.MachineHoming.Active;

// Frein = OR des relais de sens GATES (jamais desserre sans un sens valide).
M1BrakeCmd := M1RelayFwd OR M1RelayRev;
M2BrakeCmd := M2RelayFwd OR M2RelayRev;

{region "🛡️ §2quater Garde anti-chatter dure sorties contacteurs M1/M2"}
// ═══════════════════════════════════════════════════════════════
// 🛡️ §2quater GARDE ANTI-CHATTER DURE — au plus près des sorties contacteurs
// ═══════════════════════════════════════════════════════════════
// Dernier rempart avant l'écriture hardware : contacteurs de SENS et de PALIER passent
// par un FB_ContactorProtector. À la retombée d'une commande, aucune ré-activation avant
// CST_ContactorMinInterval (400 ms). Les interlocks amont séquencent déjà à >= 500 ms
// -> transparent en exploitation ; n'agit qu'en cas de re-commande anormalement rapide
// (bug logique, bypass, glitch concordance §2ter).
// Enable=TRUE fixe : sécurité positive assurée par le FB (Cmd=FALSE si non autorisé).
//
// ⚠️ PAS sur le FREIN : il doit pouvoir re-desserrer IMMÉDIATEMENT quand un mouvement est
//    (re)commandé. Un plancher retarderait le desserrage -> couple moteur contre frein serré
//    = contrainte méca + usure (frein serré alors que le treuil est commandé). Le frein suit déjà les relais de sens
//    filtrés (M1BrakeCmd := M1RelayFwd OR M1RelayRev), eux planchés à 1 s par le DeadTime
//    interlock -> il ne peut pas mitrailler plus vite que les relais.
instM1FwdProtector(Enable := TRUE, Request := M1RelayFwd, Cfg_MinInterval := CST_ContactorMinInterval);
instM1RevProtector(Enable := TRUE, Request := M1RelayRev, Cfg_MinInterval := CST_ContactorMinInterval);
instM1Sc1Protector(Enable := TRUE, Request := M1SpeedContactor1, Cfg_MinInterval := CST_ContactorMinInterval);
instM1Sc2Protector(Enable := TRUE, Request := M1SpeedContactor2, Cfg_MinInterval := CST_ContactorMinInterval);
instM1Sc3Protector(Enable := TRUE, Request := M1SpeedContactor3, Cfg_MinInterval := CST_ContactorMinInterval);
instM1Sc4Protector(Enable := TRUE, Request := M1SpeedContactor4, Cfg_MinInterval := CST_ContactorMinInterval);
M1RelayFwd        := instM1FwdProtector.Cmd;
M1RelayRev        := instM1RevProtector.Cmd;
M1SpeedContactor1 := instM1Sc1Protector.Cmd;
M1SpeedContactor2 := instM1Sc2Protector.Cmd;
M1SpeedContactor3 := instM1Sc3Protector.Cmd;
M1SpeedContactor4 := instM1Sc4Protector.Cmd;

instM2FwdProtector(Enable := TRUE, Request := M2RelayFwd, Cfg_MinInterval := CST_ContactorMinInterval);
instM2RevProtector(Enable := TRUE, Request := M2RelayRev, Cfg_MinInterval := CST_ContactorMinInterval);
instM2Sc1Protector(Enable := TRUE, Request := M2SpeedContactor1, Cfg_MinInterval := CST_ContactorMinInterval);
instM2Sc2Protector(Enable := TRUE, Request := M2SpeedContactor2, Cfg_MinInterval := CST_ContactorMinInterval);
instM2Sc3Protector(Enable := TRUE, Request := M2SpeedContactor3, Cfg_MinInterval := CST_ContactorMinInterval);
instM2Sc4Protector(Enable := TRUE, Request := M2SpeedContactor4, Cfg_MinInterval := CST_ContactorMinInterval);
M2RelayFwd        := instM2FwdProtector.Cmd;
M2RelayRev        := instM2RevProtector.Cmd;
M2SpeedContactor1 := instM2Sc1Protector.Cmd;
M2SpeedContactor2 := instM2Sc2Protector.Cmd;
M2SpeedContactor3 := instM2Sc3Protector.Cmd;
M2SpeedContactor4 := instM2Sc4Protector.Cmd;

// Frein recalculé APRÈS filtrage des relais de sens (pas de protecteur propre, cf. supra).
M1BrakeCmd := M1RelayFwd OR M1RelayRev;
M2BrakeCmd := M2RelayFwd OR M2RelayRev;
{endregion}

{region "🔀 §2quinquies Concordance contacteurs M1/M2"}
// Compare les vecteurs PHYSIQUES finaux M1/M2 (post §2quater). Reponse graduee via
// FB_SyncContactor : niveau 1 (debounce 500 ms) -> Data.ContactorMismatch -> SafeStop
// des 2 treuils (PRG_04, scan N+1) ; niveau 2 (persistance CST_SyncEscalationTime) ->
// Data.ContactorMismatchEscalated -> latch MecaE escalade -> PowerCutOff.
// Bypass : groupe synchro treuils OU l'un des 2 bypass groupe treuil (l'operateur
// qui bypasse un treuil en MES neutralise aussi la concordance).
instSyncContactorFinal(
    Enable        := TRUE,
    Reset         := PRG_07_Supervision.FaultMachineReset_IHM,
    SyncEnable    := WinchOutputCoupled,
    RelayFwdM1    := M1RelayFwd,        RelayFwdM2    := M2RelayFwd,
    RelayRevM1    := M1RelayRev,        RelayRevM2    := M2RelayRev,
    Contactor1_M1 := M1SpeedContactor1, Contactor1_M2 := M2SpeedContactor1,
    Contactor2_M1 := M1SpeedContactor2, Contactor2_M2 := M2SpeedContactor2,
    Contactor3_M1 := M1SpeedContactor3, Contactor3_M2 := M2SpeedContactor3,
    Contactor4_M1 := M1SpeedContactor4, Contactor4_M2 := M2SpeedContactor4,
    BypassGlobal  := GVL_IHM.M1M2Sync.Bypass.Global
                     OR GVL_IHM.M1TreuilRetenue.Bypass.Global
                     OR GVL_IHM.M2TreuilBenne.Bypass.Global
);
Data.ContactorMismatch          := instSyncContactorFinal.ContactorMismatch;
Data.ContactorMismatchEscalated := instSyncContactorFinal.ContactorMismatchEscalated;
Data.SyncContactorDiag          := instSyncContactorFinal.Diag;
{endregion}

// ── Sorties physiques M1 (apres controle concordance §2ter) ──
M1_RelayAscent_DQ            := M1RelayFwd;
M1_RelayDescent_DQ           := M1RelayRev;
M1_SpeedContactor_1_DQ       := M1SpeedContactor1;
M1_SpeedContactor_2_DQ       := M1SpeedContactor2;
M1_SpeedContactor_3_DQ       := M1SpeedContactor3;
M1_SpeedContactor_4_DQ       := M1SpeedContactor4;
M1_BrakeRelease_RQ           := M1BrakeCmd;

// ── Sorties physiques M2 (apres controle concordance §2ter) ──
M2_RelayAscent_Close_DQ      := M2RelayFwd;
M2_RelayDescent_Open_DQ      := M2RelayRev;
M2_SpeedContactor_1_DQ       := M2SpeedContactor1;
M2_SpeedContactor_2_DQ       := M2SpeedContactor2;
M2_SpeedContactor_3_DQ       := M2SpeedContactor3;
M2_SpeedContactor_4_DQ       := M2SpeedContactor4;
M2_BrakeRelease_RQ           := M2BrakeCmd;

// ── Bus inter-PRG M1 (image reelle des sorties, apres §2ter) ──
Data.M1RelayFwd            := M1RelayFwd;
Data.M1RelayRev            := M1RelayRev;
Data.M1SpeedContactor1     := M1SpeedContactor1;
Data.M1SpeedContactor2     := M1SpeedContactor2;
Data.M1SpeedContactor3     := M1SpeedContactor3;
Data.M1SpeedContactor4     := M1SpeedContactor4;
Data.M1BrakeCmd            := M1BrakeCmd;

// ── Bus inter-PRG M2 (image reelle des sorties, apres §2ter) ──
Data.M2RelayFwd            := M2RelayFwd;
Data.M2RelayRev            := M2RelayRev;
Data.M2SpeedContactor1     := M2SpeedContactor1;
Data.M2SpeedContactor2     := M2SpeedContactor2;
Data.M2SpeedContactor3     := M2SpeedContactor3;
Data.M2SpeedContactor4     := M2SpeedContactor4;
Data.M2BrakeCmd            := M2BrakeCmd;

// ═══════════════════════════════════════════════════════════════
// ↔️ §3 TRANSLATION M3 (variateur AC600) — conditions + interlock + sorties
// ═══════════════════════════════════════════════════════════════
// 👁️ Même lecture : gate finale, défauts PowerCutOff / SafeStop, synthèse.
// Sources : PRG_05 (TranslationFinalInterlockRequest / TranslationSafety).

M3InterlockEnable := PRG_05_Translation.Data.TranslationFinalInterlockRequest.Enable
                      AND NOT PRG_05_Translation.Data.TranslationFinalInterlockRequest.PowerCutOff;

M3PowerCutOffSafetyInfo := PRG_05_Translation.Data.TranslationSafety.PowerCutOff
                        OR PRG_05_Translation.Data.TranslationSafety.ErrorMecaA
                        OR PRG_05_Translation.Data.TranslationSafety.ErrorMecaB
                        OR PRG_05_Translation.Data.TranslationSafety.ErrorBrakeThermal;

M3SafeStopSafetyInfo := PRG_05_Translation.Data.TranslationSafety.SafeStop
                     OR PRG_05_Translation.Data.TranslationSafety.Error
                     OR PRG_05_Translation.Data.TranslationSafety.ErrorOperatorComm
                     OR PRG_05_Translation.Data.TranslationSafety.ErrorDriveComm
                     OR PRG_05_Translation.Data.TranslationSafety.ErrorPhaseRotation
                     OR PRG_05_Translation.Data.TranslationSafety.ErrorLimitSwitch
                     OR PRG_05_Translation.Data.TranslationSafety.ErrorSensorIncoherent;

M3BlockedBySafetyInfo := M3PowerCutOffSafetyInfo OR M3SafeStopSafetyInfo;

instTranslationOutputInterlockM3(
    Enable                     := M3InterlockEnable,
    Reset                      := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged      := PRG_05_Translation.Data.TranslationFinalInterlockRequest.PowerContactorEngaged,
    SafeStop                   := PRG_05_Translation.Data.TranslationFinalInterlockRequest.SafeStop,
    EffectivePermitM3_Tremie   := PRG_05_Translation.Data.TranslationFinalInterlockRequest.EffectivePermitM3_Tremie,
    EffectivePermitM3_Maintenance := PRG_05_Translation.Data.TranslationFinalInterlockRequest.EffectivePermitM3_Maintenance,
    BrakeReleaseRequest        := PRG_05_Translation.Data.TranslationFinalInterlockRequest.BrakeReleaseRequest,
    BrakeCommandOpenConfirmed  := PRG_05_Translation.Data.TranslationFinalInterlockRequest.BrakeCommandOpenConfirmed,
    RequestedDriveControlWord  := PRG_05_Translation.Data.TranslationFinalInterlockRequest.RequestedDriveControlWord,
    RequestedDriveFreqHz       := PRG_05_Translation.Data.TranslationFinalInterlockRequest.RequestedDriveFreqHz
);

TranslationBrakeCmd := instTranslationOutputInterlockM3.BrakeCmd;
// Pas de garde anti-chatter sur le frein M3 : re-desserrage immédiat requis (cf. §2quater).

// ── Sorties physiques M3 ──
M3_BrakeRelease_RQ           := TranslationBrakeCmd;
M3_CommandWord               := instTranslationOutputInterlockM3.DriveControlWord;
M3_SetpointFrequencyHz       := instTranslationOutputInterlockM3.DriveFreqCmdWord;

// ── Bus inter-PRG M3 ──
Data.TranslationBrakeCmd   := TranslationBrakeCmd;

// ═══════════════════════════════════════════════════════════════
// 🪝 §4 KOBOLD (capteur fond) — commande + sortie
// ═══════════════════════════════════════════════════════════════
// Source : PRG_04 (KoboldContactorCmdArbitrated).
KoboldContactorCmd := PRG_04_Treuils_Benne.Data.KoboldContactorCmdArbitrated;
M1_M2_KoboldMeasureEnable_DQ := KoboldContactorCmd;

// ═══════════════════════════════════════════════════════════════
// 🛡️ §5 AU / MAINTIEN PUISSANCE — coupure + réarmement + sorties
// ═══════════════════════════════════════════════════════════════
// 👁️ D'un coup d'œil : ce qui coupe la puissance (PowerCutOffReq) et ce qui
//    maintient/réarme (instSafetyEmergencyManagement) → sorties physiques.
// Sources : PRG_04/05 (PowerCutOff), GVL_IHM (ArmRequest / BtnEmergencyCutOff),
//           PRG_02 (EmergencyChainClosed / PowerContactorEngaged).

// PowerCutOffReq = agrégation OU strict des demandes de coupure des trois procédés (M5, A-04).
PowerCutOffReq := PRG_04_Treuils_Benne.Data.WinchM1FinalInterlockRequest.PowerCutOff
               OR PRG_04_Treuils_Benne.Data.WinchM2FinalInterlockRequest.PowerCutOff
               OR PRG_05_Translation.Data.TranslationFinalInterlockRequest.PowerCutOff;

instSafetyEmergencyManagement(
    Enable := TRUE,
    Reset := PRG_07_Supervision.FaultMachineReset_IHM,
    ArmRequest := GVL_IHM.Emergency.Cmd.BtnEmergencyArming,
    EmergencyChainClosed := PRG_02_Acquisition.HwIn.Machine.EmergencyChainClosed_DI,
    PowerContactorEngaged := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    PowerCutOffRequest := PowerCutOffReq,
    BtnEmergencyCutOff := GVL_IHM.Emergency.Cmd.BtnEmergencyCutOff,
    // 🛠️ Bypass ingenierie MES (RETAIN, jamais IHM) — trace timing chaine/contacteur
    BypassArmingPreconditions := GVL_BypassRetain.BypassAuArmingPreconditions,
    BypassRedundancyTest := GVL_BypassRetain.BypassAuRedundancyTest,
    BypassPowerCutOff := GVL_BypassRetain.BypassAuPowerCutOff
);

// ── Ordres AU (logique) — sorties structurées Status : ST_Safety_Emergency_Status + Cmd : ST_Safety_Emergency_Cmd ──
// 🛡️ Garde anti-chatter sur les 2 contacteurs CHAIN OK (PowerKeepAlive A/B) : chaque
//    ré-enclenchement est espacé d'au moins Cfg_MinInterval. Intervalle court (100 ms) :
//    inférieur à la durée du test de redondance (CST_TestDuration 200 ms) pour ne pas bloquer
//    RESTORE_A/B, mais suffisant pour tuer un mitraillage. La retombée reste instantanée.
instKeepAliveAProtector(
    Enable          := TRUE,
    Request         := instSafetyEmergencyManagement.Cmd.MaintainA_Cmd,
    Cfg_MinInterval := T#100ms
);
instKeepAliveBProtector(
    Enable          := TRUE,
    Request         := instSafetyEmergencyManagement.Cmd.MaintainB_Cmd,
    Cfg_MinInterval := T#100ms
);
PowerKeepAliveACmd := instKeepAliveAProtector.Cmd;
PowerKeepAliveBCmd := instKeepAliveBProtector.Cmd;
// 🛡️ Garde anti-chatter generique sur l'impulsion contacteur AU : une impulsion passe
//    integralement, puis aucune nouvelle avant 5s (redondant avec la garde interne du FB AU,
//    au plus pres de la sortie physique). Un cyclage rapide du contacteur casse le materiel.
instArmContactorProtector(
    Enable          := TRUE,
    Request         := instSafetyEmergencyManagement.Cmd.ArmPulse_Cmd,
    Cfg_MinInterval := T#5s
);
EmergencyArmingCmd := instArmContactorProtector.Cmd;

// ── Sorties physiques AU ──
PowerKeepAlive_A_RQ          := PowerKeepAliveACmd;
PowerKeepAlive_B_RQ          := PowerKeepAliveBCmd;
EmergencyArming_RQ           := EmergencyArmingCmd;

// ── Bus inter-PRG AU ──
Data.PowerKeepAliveACmd    := PowerKeepAliveACmd;
Data.PowerKeepAliveBCmd    := PowerKeepAliveBCmd;
Data.EmergencyArmingCmd    := EmergencyArmingCmd;
Data.TestCutActive         := instSafetyEmergencyManagement.Cmd.TestCutActive;
Data.PowerCutOffRequest    := PowerCutOffReq;

// ── Diagnostics chaîne AU (DUT structurés State/Diag, source unique) ──
EmergencyState := instSafetyEmergencyManagement.Status.State;
EmergencyDiag := instSafetyEmergencyManagement.Status.Diag;
EmergencyReady := instSafetyEmergencyManagement.Status.Ready;
EmergencyDone := instSafetyEmergencyManagement.Status.Done;
EmergencyFault := instSafetyEmergencyManagement.Status.Fault;
EmergencyOperatorMessage := instSafetyEmergencyManagement.Status.OperatorMessage;
PowerCutOffActive := PowerCutOffReq;

END_PROGRAM
