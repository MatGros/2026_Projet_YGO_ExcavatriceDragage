# Extraction complète - Device.Application.GVL_PERSISTENT

## 1. Calibration & Paliers treuil
* **`_CalibM1`** (`ST_Encoder_Calib`) : Calibration treuil M1
  * `HomingRefRaw` (`UDINT`) = `16750628`
  * `LastKnownRawPos` (`UDINT`) = `16784018`
  * `RestartCoherenceTolerancePts` (`UDINT`) = `1000`
  * `Homed` (`BOOL`) = `TRUE`
  * `HomingSuspect` (`BOOL`) = `FALSE`
* **`_CalibM2`** (`ST_Encoder_Calib`) : Calibration treuil M2
  * `HomingRefRaw` (`UDINT`) = `16747067`
  * `LastKnownRawPos` (`UDINT`) = `16780366`
  * `Homed` (`BOOL`) = `TRUE`
  * `HomingSuspect` (`BOOL`) = `FALSE`
* **`_WinchSpeedStepTable`** (`ST_SpeedStepTable`)
  * `P1R1` (`BOOL`) = `FALSE`
  * `P1R2` (`BOOL`) = `FALSE`
  * `P1R3` (`BOOL`) = `FALSE`
  * `P1R4` (`BOOL`) = `FALSE`
  * `P2R1` (`BOOL`) = `TRUE`
  * `P2R2` (`BOOL`) = `FALSE`
  * `P2R3` (`BOOL`) = `FALSE`
  * `P2R4` (`BOOL`) = `FALSE`
  * `P3R1` (`BOOL`) = `TRUE`
  * `P3R2` (`BOOL`) = `TRUE`
  * `P3R3` (`BOOL`) = `FALSE`
  * `P3R4` (`BOOL`) = `FALSE`
  * `P4R1` (`BOOL`) = `TRUE`
  * `P4R2` (`BOOL`) = `TRUE`
  * `P4R3` (`BOOL`) = `TRUE`
  * `P4R4` (`BOOL`) = `FALSE`
  * `P5R1` (`BOOL`) = `TRUE`
  * `P5R2` (`BOOL`) = `TRUE`
  * `P5R3` (`BOOL`) = *(non visible sur capture)*
  * `P5R4` (`BOOL`) = `FALSE`
  * `StepThreshold_Pct` (`ARRAY [1..5] OF REAL`) = *(replié)*
  * `SpeedStepHystMargin` (`REAL`) = `2`
  * `Initialized` (`BOOL`) = `TRUE`

## 2. Configuration vitesse, charge & symétrie treuil
* **`_WinchSpeedConfig`** (`ST_fbWinchLoadEsti...`)
  * `MaxMeasuredSpeedMps` (`REAL`) = `2`
  * `SpeedBandMaxMps` (`ARRAY [1..5] OF REAL`)
    * `SpeedBandMaxMps[1]` (`REAL`) = `0.4`
    * `SpeedBandMaxMps[2]` (`REAL`) = `0.8`
    * `SpeedBandMaxMps[3]` (`REAL`) = `1.2`
    * `SpeedBandMaxMps[4]` (`REAL`) = `1.6`
    * `SpeedBandMaxMps[5]` (`REAL`) = `2`
  * `SpeedBandHysteresisMps` (`REAL`) = `0.05`
* **`_WinchLoadEstimateTable`** (`ST_fbWinchLoadEsti...`)
  * `IsConfigured` (`BOOL`) = `FALSE`
  * `LoadPctByStepAndSpeedBand` (`ARRAY [1..5] OF ARRAY [1..5] OF REAL`)
    * `LoadPctByStepAndSpeedBand[1][1]` (`REAL`) = `0`
    * `LoadPctByStepAndSpeedBand[1][2]` (`REAL`) = `0`
    * `LoadPctByStepAndSpeedBand[1][3]` (`REAL`) = `0`
    * `LoadPctByStepAndSpeedBand[1][4]` (`REAL`) = `0`
    * `LoadPctByStepAndSpeedBand[1][5]` (`REAL`) = `0`
    * `LoadPctByStepAndSpeedBand[2..5]` = *(repliés)*
* **`_WinchSymmetryCfgPersist`** (`ST_fbWinch_Symmet...`)
  * `DeltaStartDelay_Ms` (`UDINT`) = `100`
  * `DeltaBrakeReleaseTime_Ms` (`UDINT`) = `100`
  * `DeltaBrakeApplyTime_Ms` (`UDINT`) = `100`
  * `DeltaStopDistance_Mm` (`UDINT`) = `100`
  * `DeltaStopTime_Ms` (`UDINT`) = `200`
  * `MinimumCommandTime_Ms` (`UDINT`) = `1000`
  * `MinimumSpeed_Mps` (`REAL`) = `0.05`
* **`_WinchSymmetryDataPersist`** (`ST_fbWinch_Symmet...`)
  * `DeltaStartDelay_Ms` (`UDINT`) = `330`
  * `DeltaBrakeReleaseTime_Ms` (`UDINT`) = `0`
  * `DeltaBrakeApplyTime_Ms` (`UDINT`) = `0`
  * `DeltaStopDistance_Mm` (`UDINT`) = `69`
  * `DeltaStopTime_Ms` (`UDINT`) = `90`
  * `MaxSyncDeviation_M` (`REAL`) = `3.022705`

## 3. Paramètres treuils M1 / M2 & Synchronisation
* **`_WinchM1CfgPersist`** (`ST_WinchCfg`)
  * `CfgTopSensorPos_M` (`REAL`) = `8.5`
  * `CfgHomingTarget_M` (`REAL`) = `0`
  * `CfgRampAccelRate` (`REAL`) = `10`
  * `CfgRampDecelNormalRate` (`REAL`) = `150`
  * `CfgRampDecelFastRate` (`REAL`) = `400`
  * `CfgCableLimitDescent_M` (`REAL`) = `-50`
  * `Initialized` (`BOOL`) = `TRUE`
* **`_WinchM2CfgPersist`** (`ST_WinchCfg`)
  * `CfgTopSensorPos_M` (`REAL`) = `8.5`
  * `CfgHomingTarget_M` (`REAL`) = `0`
  * `CfgRampAccelRate` (`REAL`) = `10`
  * `CfgRampDecelNormalRate` (`REAL`) = `150`
  * `CfgRampDecelFastRate` (`REAL`) = `400`
  * `CfgCableLimitDescent_M` (`REAL`) = `-50`
  * `Initialized` (`BOOL`) = `TRUE`
* **`_SyncCfgPersist`** (`ST_SyncCfg`)
  * `CfgSyncTolerance_M` (`REAL`) = `3`
  * `CfgSyncCriticalTolerance_M` (`REAL`) = `6`
  * `Initialized` (`BOOL`) = `TRUE`
* **Variables globales de synchronisation**
  * `_WinchCriticalSyncTolerance_M` (`REAL`) = `7`
  * `_SyncSoftStopEnable` (`BOOL`) = `FALSE`

## 4. Benne (Bucket)
* **`_BucketCfgPersist`** (`ST_BucketCfg`)
  * `Config` (`ST_fbBucket_Config`)
    * `OffsetOpenM` (`REAL`) = `0`
    * `OffsetCloseM` (`REAL`) = `15`
    * `CoherenceLimitM` (`REAL`) = `1`
    * `CloseAnticipationM` (`REAL`) = `1.2`
    * `OpenAnticipationM` (`REAL`) = `1.3`
    * `JogSlowdownZoneM` (`REAL`) = `1`
    * `MaxStepUp` (`INT`) = `2`
    * `MaxStepDown` (`INT`) = `4`
  * `CfgTimeoutDuration` (`TIME`) = `T#1m`
  * `Initialized` (`BOOL`) = `TRUE`
* **`_BucketState`** (`ST_fbBucket_State`)
  * `IsOpen` (`BOOL`) = `TRUE`
  * `IsClosed` (`BOOL`) = `FALSE`
  * `TooOpen` (`BOOL`) = `FALSE`
  * `TooClosed` (`BOOL`) = `FALSE`
  * `IsIntermediate` (`BOOL`) = `FALSE`
  * `LastPosM2Open` (`REAL`) = `8.129639`
  * `LastPosM2Close` (`REAL`) = `22.1555176`
  * `ActiveOffsetValid` (`BOOL`) = `TRUE`
  * `BucketReferenced` (`BOOL`) = `TRUE`
  * `StateIncoherent` (`BOOL`) = `FALSE`

## 5. Translation & Joystick
* **`_TranslationCfgPersist`** (`ST_TranslationCfg`)
  * `CfgApproachSpeedTremie_Hz` (`REAL`) = `20`
  * `CfgApproachSpeedMaintenance_Hz` (`REAL`) = `20`
  * `CfgApproachSpeedP1_Hz` (`REAL`) = `20`
  * `Initialized` (`BOOL`) = `TRUE`
* **Variables globales de translation**
  * `_TranslationMaxFreq_Hz` (`REAL`) = `50`
  * `_TranslationMinHeightM1M2_M` (`REAL`) = `6`
  * `_TranslationRampAccelRate_Pct` (`REAL`) = `40`
  * `_TranslationRampDecelNormal_Pct` (`REAL`) = `50`
  * `_TranslationRampDecelFast_Pct` (`REAL`) = `100`
  * `_TranslationAutoSpeedCap_Pct` (`REAL`) = `40`
  * `_TranslationSetFreq_Hz` (`REAL`) = `50`
  * `_TranslationPosTremie_M` (`REAL`) = `0`
  * `_TranslationPosPV_M` (`REAL`) = `5`
  * `_TranslationPosP2_M` (`REAL`) = `15`
  * `_TranslationPosP1_M` (`REAL`) = `20`
  * `_TranslationPosMaintenance_M` (`REAL`) = `30`
  * `_TranslationGainMetersPerHzSec` (`REAL`) = `0.02`
  * `_TranslationPosEstimated_M` (`REAL`) = `30`
  * `_TranslationPosEstimatedInitialized` (`BOOL`) = `TRUE`
  * `_TranslationAtTremiePersisted` (`BOOL`) = `FALSE`
  * `_TranslationAtPVPersisted` (`BOOL`) = `FALSE`
  * `_TranslationAtP2Persisted` (`BOOL`) = `FALSE`
  * `_TranslationAtP1Persisted` (`BOOL`) = `FALSE`
  * `_TranslationAtMaintenancePersisted` (`BOOL`) = `FALSE`
* **Variables globales de joystick**
  * `_JoystickNeutralX` (`INT`) = `5000`
  * `_JoystickNeutralY` (`INT`) = `5000`
  * `_JoystickAccelRate_Pct` (`REAL`) = `50`
  * `_JoystickDecelRate_Pct` (`REAL`) = `150`
* **`_JoystickCfgPersist`** (`ST_fbJoystick_Cfg`)
  * `DeadbandRaw` (`INT`) = `300`
  * `NeutralHoldTime` (`TIME`) = `T#100ms`
  * `DeadmanArmHoldTime` (`TIME`) = `T#100ms`
  * `DeadmanArmGraceTime` (`TIME`) = `T#3s`
  * `RawOutOfRangeMargin` (`INT`) = `500`
  * `SpeedStepTable` (`ST_SpeedStepTable`)
    * `P1R1` à `P1R4` (`BOOL`) = `FALSE`
    * `P2R1` à `P2R4` (`BOOL`) = `FALSE`
    * `P3R1` à `P3R4` (`BOOL`) = `FALSE`
    * `P4R1` à `P4R4` (`BOOL`) = `FALSE`
    * `P5R1` (`BOOL`) = `FALSE`
    * `P5R2`, `P5R3` (`BOOL`) = *(non visibles sur capture)*
    * `P5R4` (`BOOL`) = `FALSE`
    * `StepThreshold_Pct` (`ARRAY [1..5] OF REAL`) = *(replié)*
    * `SpeedStepHystMargin` (`REAL`) = `2`
    * `Initialized` (`BOOL`) = `TRUE`

## 6. Cycle, Sécurité commune & Apprentissage
* **`_CycleCfgPersist`** (`ST_CycleCfg`)
  * `SetDepth_M` (`REAL`) = `-30`
  * `DepthStopMode` (`E_CYCLEDEPTHSTOP...`) = `KOBOLD_OR_SETPOINT`
  * `DrainTime_S` (`INT`) = `2`
  * `RaiseOffBottom_M` (`REAL`) = `0`
  * `CtrlAscentMaxStep` (`INT`) = `2`
  * `ExtractionStartOpening_Pct` (`INT`) = `10`
  * `_ReservedInerte_01` (`INT`) = `0`
  * `DiveStartMin_M` (`REAL`) = `4`
  * `ImmersionUpper_M` (`REAL`) = `0.5`
  * `ImmersionLower_M` (`REAL`) = `-0.5`
  * `ExtractionControlDistance_M` (`REAL`) = `1`
  * `Initialized` (`BOOL`) = `TRUE`
  * `SampleCountResetMode` (`E_CYCLESAMPLECO...`) = `NEVER`
* **`_CycleMachineHomingCfgPersist`** (`ST_CycleMachineHo...`)
  * `ForceStepTarget` (`INT`) = `0`
  * `Initialized` (`BOOL`) = `TRUE`
* **`_CommunCfgPersist`** (`ST_CommunCfg`)
  * `LimitLegalDepthMinAllowed_M` (`REAL`) = `-30`
  * `LimitLegalEnabled` (`BOOL`) = `TRUE`
  * `SelHomingApproachEnable` (`BOOL`) = `FALSE`
  * `WinchMaxStepDescent` (`INT`) = `4`
  * `WinchMaxStepAscent` (`INT`) = `5`
  * `WinchSlowdownDistanceTop_M` (`REAL`) = `0.5`
  * `WinchSlowdownDistanceBottom_M` (`REAL`) = `1`
  * `WinchSlowdownMaxStep` (`INT`) = `1`
  * `CfgCableLimitAscent_M` (`REAL`) = `7.7`
  * `TglEnableKoboldAutoStopDescent` (`BOOL`) = `FALSE`
  * `TglEnableCoupledBucketSequencing` (`BOOL`) = `TRUE`
  * `TglEnableWinchDescentLock_M3` (`BOOL`) = `TRUE`
  * `Initialized` (`BOOL`) = `TRUE`
* **`_EncoderCfgPersist`** (`ST_fbEncoder_Cfg`)
  * `PresetConfirmMode` (`E_PRESETCONFIRM...`) = `READBACK_ONLY`
  * `Initialized` (`BOOL`) = `TRUE`
* **`_WinchSpeedLearnTable`** (`ST_fbWinchSpeedLe...`)
  * `Cell` (`ARRAY [1..2, 1..2, 1..5, 1..5] OF ST_fbWinchSpeedLe...`)
    * `Cell[1, 1, 1, 1].Valid` (`BOOL`) = `FALSE`
    * `Cell[1, 1, 1, 1].SpeedMps` (`REAL`) = `0`
    * `Cell[1, 1, 1, 1].SampleCount` (`UDINT`) = `0`
    * `Cell[1, 1, 1, 2..3]` = *(repliés)*
    * `Cell[2, 2, 2, 4..5]` = *(repliés)*
* **`_WinchSpeedLearnCfg`** (`ST_fbWinchSpeedLe...`)
  * `MinSpeedMps` (`ARRAY [1..5] OF REAL`)
    * `MinSpeedMps[1]` (`REAL`) = `0`
    * `MinSpeedMps[2]` (`REAL`) = `0.3`
    * `MinSpeedMps[3]` (`REAL`) = `0.5`
    * `MinSpeedMps[4]` (`REAL`) = `0.8`
    * `MinSpeedMps[5]` (`REAL`) = `1`
  * `MaxSpeedMps` (`ARRAY [1..5] OF REAL`)
    * `MaxSpeedMps[1]` (`REAL`) = `0.5`
    * `MaxSpeedMps[2]` (`REAL`) = `1`
    * `MaxSpeedMps[3]` (`REAL`) = `1.5`
    * `MaxSpeedMps[4]` (`REAL`) = `2`
    * `MaxSpeedMps[5]` (`REAL`) = `2.5`
  * `MinSamples` (`UDINT`) = `3`
* **Variables globales diverses, maintenance & compteurs**
  * `_BlinkTimeOn` (`TIME`) = `T#1s`
  * `_BlinkTimeOff` (`TIME`) = `T#900ms`
  * `_CycleSampleCount` (`INT`) = `30`
  * `_SimEncoderRawPosM1` (`UDINT`) = `1000000`
  * `_SimEncoderRawPosM2` (`UDINT`) = `1000000`
  * `_MaintM1HomingRequired` (`BOOL`) = `FALSE`
  * `_MaintM2HomingRequired` (`BOOL`) = `FALSE`
  * `_CycleSampleCountTotal` (`UDINT`) = `734`