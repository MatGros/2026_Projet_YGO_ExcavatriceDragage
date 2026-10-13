(* Harnais de test T417 : boucle fermee FB_Translation REEL (non modifie) + decodeur + FB_Sim_Translation.
   Un appel = un scan. Reproduit le cablage de PRG_05 (decodeur, ralentissements d approche, FdC bistable P1
   quand Maintenance est interdite, permis, jeton d arrivee P1). Non reproduit : FB_TranslationOutputInterlock
   (traite en transparent) et FB_Safety_Translation. Cible P1. Jamais compile dans le programme CODESYS. *)
FUNCTION_BLOCK FB_TestLoopTranslation
VAR_INPUT
    HoldRequest : BOOL;
END_VAR
VAR_OUTPUT
    Phase : INT;
    Overshoot_M : REAL;
    FreqAtCross_Hz : REAL;
    MaxCmdAfter_Hz : REAL;
    PositionTrue_M : REAL;
    CtrlWord : WORD;
    FreqReq_Hz : REAL;
    ActualFreq_Hz : REAL;
    AtP1Token : BOOL;
    SensorsWord : BYTE;
END_VAR
VAR
    tr : FB_Translation;
    sim : FB_Sim_Translation;
    dec : FB_Translation_PositionDecoder;
    cfg : ST_fbTranslation_Cfg;
    Initialized : BOOL;
    reqTremie : BOOL;
    reqMaint : BOOL;
    limTremieStable : BOOL;
    limMaintStable : BOOL;
    limMaintEff : BOOL;
    atP1 : BOOL;
    wordPrev : BYTE;
    wordChanged : BOOL;
    stopCount : INT;
    maxPos_M : REAL;
    crossed : BOOL;
END_VAR

IF NOT Initialized THEN
    Initialized := TRUE;
    cfg.CfgRampAccelRate := 40.0;
    cfg.CfgRampDecelNormalRate := 50.0;
    cfg.CfgRampDecelFastRate := 100.0;
    cfg.DriveFreqScaleMaxHz := 50.0;
    cfg.ApproachSpeedTremieHz := 20.0;
    cfg.ApproachSpeedMaintenanceHz := 20.0;
    cfg.ApproachSpeedP1Hz := 20.0;
    Phase := 0;
    reqTremie := TRUE;
END_IF;

dec(SensorTremie := sim.PosTremie, SensorPV := sim.PosPV, SensorP2 := sim.PosP2,
    SensorP1 := sim.PosP1, SensorMaintenance := sim.PosMaintenance);
limMaintEff := (NOT dec.TranslationPosP1) AND dec.TranslationPosMaintenance;
IF dec.LimitSwitchTremie THEN
    limTremieStable := TRUE;
ELSIF reqMaint THEN
    limTremieStable := FALSE;
END_IF;
IF limMaintEff THEN
    limMaintStable := TRUE;
ELSIF reqTremie THEN
    limMaintStable := FALSE;
END_IF;
wordChanged := (dec.SensorsWord <> wordPrev);
wordPrev := dec.SensorsWord;
IF dec.TranslationAtP1 THEN
    atP1 := TRUE;
ELSIF dec.TranslationAtP2 OR dec.TranslationAtPV OR dec.TranslationAtTremie OR dec.TranslationAtMaintenance OR wordChanged THEN
    atP1 := FALSE;
END_IF;

tr(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, RunRequest := TRUE, SafeStop := FALSE,
   ReqTremie := reqTremie, ReqMaintenance := reqMaint, SpeedTgt_Pct := 100.0,
   PositionSensorTarget := atP1 AND reqMaint,
   SlowdownSensorTremie := dec.TranslationPosPV,
   SlowdownSensorMaintenance := (NOT dec.TranslationPosP1) AND dec.TranslationPosMaintenance,
   SlowdownSensorP1 := (NOT dec.TranslationPosP2) AND dec.TranslationPosP1,
   LimitSwitchTremie := limTremieStable, LimitSwitchMaintenance := limMaintStable,
   EffectivePermitM3_Tremie := NOT limTremieStable, EffectivePermitM3_Maintenance := NOT limMaintStable,
   DriveStatusWord := 0, DriveActualFreqHz := sim.ActualFrequency_Hz,
   BrakeFeedback := sim.BrakeContactOpen, Cfg := cfg);
sim(Enable := TRUE,
    ReqTremie := (tr.RequestedDriveControlWord = 1), ReqMaintenance := (tr.RequestedDriveControlWord = 2),
    SpeedTgt_Pct := LIMIT(0.0, tr.RequestedDriveFreqHz / 50.0 * 100.0, 100.0),
    BrakeReleaseCmd := tr.BrakeReleaseRequest,
    LoadFrequencyDroopGain_Hz := 0.0, LoadReactionGain_Mps2 := 0.0);
PositionTrue_M := sim.PositionTrue_M;
CtrlWord := tr.RequestedDriveControlWord;
FreqReq_Hz := tr.RequestedDriveFreqHz;
ActualFreq_Hz := sim.ActualFrequency_Hz;
AtP1Token := atP1;
SensorsWord := dec.SensorsWord;

CASE Phase OF
    0:  (* jambe Tremie jusqu a 6 m : vitesse pleine atteinte hors zone d approche *)
        IF sim.PositionTrue_M < 6.0 THEN
            reqTremie := FALSE;
            Phase := 1;
            stopCount := 0;
        END_IF;
    1:  (* arret complet, frein ferme *)
        IF (sim.ActualFrequency_Hz < 0.5) AND (NOT sim.BrakeMechanicallyOpen) THEN
            stopCount := stopCount + 1;
        ELSE
            stopCount := 0;
        END_IF;
        IF stopCount > 30 THEN
            reqMaint := TRUE;
            Phase := 2;
        END_IF;
    2:  (* jambe Maintenance vers la cible P1 *)
        IF atP1 AND NOT HoldRequest THEN
            reqMaint := FALSE;
        END_IF;
        IF sim.PositionTrue_M > 20.0 THEN
            IF NOT crossed THEN
                crossed := TRUE;
                FreqAtCross_Hz := sim.ActualFrequency_Hz;
            END_IF;
            maxPos_M := MAX(maxPos_M, sim.PositionTrue_M);
            MaxCmdAfter_Hz := MAX(MaxCmdAfter_Hz, tr.RequestedDriveFreqHz);
        END_IF;
        IF crossed AND (sim.ActualFrequency_Hz < 0.5) AND (ABS(sim.VelocityTrue_Mps) < 0.01) THEN
            Phase := 3;
        END_IF;
END_CASE;
Overshoot_M := maxPos_M - 20.0;
END_FUNCTION_BLOCK
