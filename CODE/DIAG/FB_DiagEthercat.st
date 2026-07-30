(* ═══════════════════════════════════════════════════════════════
   📡 FB_DiagEthercat — Diagnostic de communication bus EtherCAT (3 esclaves)
   ───────────────────────────────────────────────────────────────
   🔧 REX 2026-07-24 (demande utilisateur, mise en service) : REFONTE responsabilités —
   PRG_01_Diagnostics ne transmet plus que les valeurs BRUTES (GetDeviceState()) et les 2 bypass
   bruts par device (simulation, bypass réseau IHM global) ; c'est CE FB qui décide désormais
   Online/Operational ET distingue explicitement dans `State` :
     - INIT       : pas encore online (ni réel, ni bypass) — initialisation normale
     - SIMULATED  : bypass actif (simulation ou bypass réseau IHM) mais bus réel PAS confirmé online
     - READY      : bus réellement online (le bypass, actif ou non, ne change rien ici)
     - ERROR      : défaut détecté
   But : ne plus jamais confondre en mise en service un bypass masquant (SIMULATED) avec un vrai
   bus opérationnel (READY) — ambiguïté qui a causé un faux diagnostic "online" alors que le bus
   réel ne l'était pas.
    📄 Docs : DOC/AF_Partie-02_Architecture_Programme_v3.0.md
*)
FUNCTION_BLOCK PUBLIC FB_DiagEthercat
VAR_INPUT
    Enable              : BOOL;        (* Active la surveillance EtherCAT *)
    Reset               : BOOL;        (* Front d'acquittement des défauts *)

    // 🆕 REX 2026-07-24 : valeurs BRUTES non interprétées — l'appelant (PRG_01) ne fait plus
    // qu'acquérir, cette FB décide seule de l'interprétation (voir en-tête).
    (* Variateur M3 (AC600_ECAT_Drive) *)
    DeviceVariateurStateRaw     : DEVICE_STATE; (* Valeur brute AC600_ECAT_Drive.GetDeviceState() *)
    DeviceVariateurSimBypass    : BOOL;         (* TRUE = simulation active (SimulationModeActive AND NOT BusVariateurM3IsReal), calculé par l'appelant *)

    (* Encodeur M1 (COD1_CODEUR) *)
    DeviceEncoderM1StateRaw     : DEVICE_STATE; (* Valeur brute COD1_CODEUR.GetDeviceState() *)
    DeviceEncoderM1SimBypass    : BOOL;         (* TRUE = simulation active (SimulationModeActive AND NOT BusEncoderM1IsReal) *)

    (* Encodeur M2 (COD2_CODEUR) *)
    DeviceEncoderM2StateRaw     : DEVICE_STATE; (* Valeur brute COD2_CODEUR.GetDeviceState() *)
    DeviceEncoderM2SimBypass    : BOOL;         (* TRUE = simulation active (SimulationModeActive AND NOT BusEncoderM2IsReal) *)

    NetworkBypassActive         : BOOL;         (* TRUE = bypass réseau global IHM (GVL_IHM.Network.Bypass.Global), commun aux 3 devices *)
END_VAR
VAR_OUTPUT
    Ready               : BOOL;        (* Logique de surveillance active *)
    Busy                : BOOL;        (* Non utilisé (conformité) *)
    Done                : BOOL;        (* Non utilisé *)
    Error               : BOOL;        (* Résumé anomalie de communication bus *)
    ErrorId             : WORD;        (* Code défaut global résumé *)
    State               : E_DiagState; (* Phase courante du diagnostic global — voir en-tête *)
    StateAtError        : E_DiagState; (* Phase figée à l'apparition de l'erreur *)
    DeviceEthercatMaster : ST_DiagDevice; (* Diagnostics bus EtherCAT *)
    DeviceVariateur     : ST_DiagDevice;  (* Diagnostics esclave AC600 *)
    DeviceEncoderM1     : ST_DiagDevice;  (* Diagnostics esclave COD1 *)
    DeviceEncoderM2     : ST_DiagDevice;  (* Diagnostics esclave COD2 *)
    // 🆕 REX 2026-07-24 — miroirs bruts (voir VAR_INPUT ci-dessus), lisibles directement sur
    // l'instance (Device.Application.PRG_01_Diagnostics.instDiagEthercat.<Nom>).
    DeviceVariateurStateRawOut : DEVICE_STATE;
    DeviceEncoderM1StateRawOut : DEVICE_STATE;
    DeviceEncoderM2StateRawOut : DEVICE_STATE;
END_VAR
VAR
    ResetEdge           : R_TRIG;      (* Détecteur front de reset *)
    // 🆕 REX 2026-07-24 — interprétation interne (voir en-tête)
    VariateurOnlineReal  : BOOL; (* GetDeviceState() = RUNNING, hors tout bypass *)
    EncoderM1OnlineReal  : BOOL;
    EncoderM2OnlineReal  : BOOL;
    VariateurBypass      : BOOL; (* Simulation OU bypass réseau IHM, pour ce device *)
    EncoderM1Bypass      : BOOL;
    EncoderM2Bypass      : BOOL;
    VariateurOnlineEff   : BOOL; (* Online effectif utilisé pour la logique (réel OU bypass) *)
    EncoderM1OnlineEff   : BOOL;
    EncoderM2OnlineEff   : BOOL;
END_VAR

// 🛑 1. GATE : Désactivation si Enable = FALSE
IF NOT Enable THEN
    Ready := FALSE;
    State := E_DiagState.DISABLED;
    DeviceVariateur.State := E_DiagState.DISABLED;
    DeviceEncoderM1.State := E_DiagState.DISABLED;
    DeviceEncoderM2.State := E_DiagState.DISABLED;
    DeviceVariateur.Online := FALSE;
    DeviceEncoderM1.Online := FALSE;
    DeviceEncoderM2.Online := FALSE;
    DeviceVariateur.Operational := FALSE;
    DeviceEncoderM1.Operational := FALSE;
    DeviceEncoderM2.Operational := FALSE;
    DeviceVariateur.Error := FALSE;
    DeviceEncoderM1.Error := FALSE;
    DeviceEncoderM2.Error := FALSE;
    Error := FALSE;
    ErrorId := 16#0000;
    // 🐛 REX 2026-07-24 (ter) — BUG CORRIGÉ (même bug que FB_DiagCanOpen, trouvé en mise en
    // service) : DeviceEthercatMaster.State/.Online/.Operational n'étaient JAMAIS remis à zéro ici
    // (ni .State assigné nulle part dans le corps normal) → restaient figés sur la dernière valeur
    // active (ou DISABLED=0 par défaut au tout premier cycle) même après désactivation/rechargement.
    DeviceEthercatMaster.State := E_DiagState.DISABLED;
    DeviceEthercatMaster.Online := FALSE;
    DeviceEthercatMaster.Operational := FALSE;
    // 🆕 miroirs bruts toujours à jour, même désactivé (voir en-tête)
    DeviceVariateurStateRawOut := DeviceVariateurStateRaw;
    DeviceEncoderM1StateRawOut := DeviceEncoderM1StateRaw;
    DeviceEncoderM2StateRawOut := DeviceEncoderM2StateRaw;
    RETURN;
END_IF;

Ready := TRUE;

// 🧮 2. INTERPRÉTATION DES VALEURS BRUTES (REX 2026-07-24, rapatrié depuis PRG_01_Diagnostics)
VariateurOnlineReal := (DeviceVariateurStateRaw = DEVICE_STATE.RUNNING);
EncoderM1OnlineReal := (DeviceEncoderM1StateRaw = DEVICE_STATE.RUNNING);
EncoderM2OnlineReal := (DeviceEncoderM2StateRaw = DEVICE_STATE.RUNNING);

VariateurBypass := DeviceVariateurSimBypass OR NetworkBypassActive;
EncoderM1Bypass := DeviceEncoderM1SimBypass OR NetworkBypassActive;
EncoderM2Bypass := DeviceEncoderM2SimBypass OR NetworkBypassActive;

VariateurOnlineEff := VariateurOnlineReal OR VariateurBypass;
EncoderM1OnlineEff := EncoderM1OnlineReal OR EncoderM1Bypass;
EncoderM2OnlineEff := EncoderM2OnlineReal OR EncoderM2Bypass;

// 🔑 3. RESET FRONT
ResetEdge(CLK := Reset);

// 🔍 4. DIAGNOSTIC VARIATEUR (AC600_ECAT_Drive / Translation M3)
DeviceVariateur.Online := VariateurOnlineEff;
DeviceVariateur.Operational := VariateurOnlineEff;

IF NOT DeviceVariateur.Online THEN
    DeviceVariateur.ErrorId := DeviceVariateur.ErrorId OR 16#0010;  (* Perte liaison physique variateur *)
ELSE
    DeviceVariateur.ErrorId := DeviceVariateur.ErrorId AND 16#FFEF; (* Effacement auto dès que RUNNING *)
END_IF;

// 🔍 5. DIAGNOSTIC ENCODEUR M1 (COD1_CODEUR / WinchM1)
DeviceEncoderM1.Online := EncoderM1OnlineEff;
DeviceEncoderM1.Operational := EncoderM1OnlineEff;

IF NOT DeviceEncoderM1.Online THEN
    DeviceEncoderM1.ErrorId := DeviceEncoderM1.ErrorId OR 16#0020;  (* Perte liaison encodeur M1 *)
ELSE
    DeviceEncoderM1.ErrorId := DeviceEncoderM1.ErrorId AND 16#FFDF; (* Effacement auto dès que RUNNING *)
END_IF;

// 🔍 6. DIAGNOSTIC ENCODEUR M2 (COD2_CODEUR / WinchM2)
DeviceEncoderM2.Online := EncoderM2OnlineEff;
DeviceEncoderM2.Operational := EncoderM2OnlineEff;

IF NOT DeviceEncoderM2.Online THEN
    DeviceEncoderM2.ErrorId := DeviceEncoderM2.ErrorId OR 16#0030;  (* Perte liaison encodeur M2 *)
ELSE
    DeviceEncoderM2.ErrorId := DeviceEncoderM2.ErrorId AND 16#FFCF; (* Effacement auto dès que RUNNING *)
END_IF;

// 🚦 7. STATE MACHINES DE CHAQUE APPAREIL — 🆕 REX 2026-07-24 : distingue SIMULATED (bypass actif,
// bus réel pas confirmé) de READY (réel).
IF DeviceVariateur.ErrorId <> 0 THEN
    DeviceVariateur.State := E_DiagState.ERROR;
ELSIF NOT VariateurOnlineEff THEN
    DeviceVariateur.State := E_DiagState.INIT;
ELSIF VariateurBypass AND NOT VariateurOnlineReal THEN
    DeviceVariateur.State := E_DiagState.SIMULATED;
ELSE
    DeviceVariateur.State := E_DiagState.READY;
END_IF;

IF DeviceEncoderM1.ErrorId <> 0 THEN
    DeviceEncoderM1.State := E_DiagState.ERROR;
ELSIF NOT EncoderM1OnlineEff THEN
    DeviceEncoderM1.State := E_DiagState.INIT;
ELSIF EncoderM1Bypass AND NOT EncoderM1OnlineReal THEN
    DeviceEncoderM1.State := E_DiagState.SIMULATED;
ELSE
    DeviceEncoderM1.State := E_DiagState.READY;
END_IF;

IF DeviceEncoderM2.ErrorId <> 0 THEN
    DeviceEncoderM2.State := E_DiagState.ERROR;
ELSIF NOT EncoderM2OnlineEff THEN
    DeviceEncoderM2.State := E_DiagState.INIT;
ELSIF EncoderM2Bypass AND NOT EncoderM2OnlineReal THEN
    DeviceEncoderM2.State := E_DiagState.SIMULATED;
ELSE
    DeviceEncoderM2.State := E_DiagState.READY;
END_IF;

// Fige la phase du diagnostic global sur le premier défaut
IF (DeviceVariateur.ErrorId <> 0 OR DeviceEncoderM1.ErrorId <> 0 OR DeviceEncoderM2.ErrorId <> 0) THEN
    IF StateAtError = E_DiagState.DISABLED THEN
        StateAtError := State;
    END_IF;
END_IF;

// 📤 8. RÉSUMÉ ET DÉFAUTS
DeviceVariateur.Error := (DeviceVariateur.ErrorId <> 0);
DeviceEncoderM1.Error := (DeviceEncoderM1.ErrorId <> 0);
DeviceEncoderM2.Error := (DeviceEncoderM2.ErrorId <> 0);

Error := (DeviceVariateur.Error OR DeviceEncoderM1.Error OR DeviceEncoderM2.Error);

ErrorId := 16#0000;
IF DeviceVariateur.Error THEN
    ErrorId := ErrorId OR 16#00F0;
END_IF;
IF DeviceEncoderM1.Error THEN
    ErrorId := ErrorId OR 16#0F00;
END_IF;
IF DeviceEncoderM2.Error THEN
    ErrorId := ErrorId OR 16#F000;
END_IF;

IF Error THEN
    State := E_DiagState.ERROR;
ELSIF NOT (VariateurOnlineEff AND EncoderM1OnlineEff AND EncoderM2OnlineEff) THEN
    State := E_DiagState.INIT;
ELSIF (VariateurBypass OR EncoderM1Bypass OR EncoderM2Bypass)
      AND NOT (VariateurOnlineReal AND EncoderM1OnlineReal AND EncoderM2OnlineReal) THEN
    State := E_DiagState.SIMULATED;
ELSE
    State := E_DiagState.READY;
END_IF;

DeviceEthercatMaster.Online := VariateurOnlineEff AND EncoderM1OnlineEff AND EncoderM2OnlineEff;
DeviceEthercatMaster.Operational := DeviceEthercatMaster.Online;

// 🆕 REX 2026-07-24 — miroirs bruts (voir en-tête), toujours à jour
DeviceVariateurStateRawOut := DeviceVariateurStateRaw;
DeviceEncoderM1StateRawOut := DeviceEncoderM1StateRaw;
DeviceEncoderM2StateRawOut := DeviceEncoderM2StateRaw;

Busy := FALSE;
Done := FALSE;
