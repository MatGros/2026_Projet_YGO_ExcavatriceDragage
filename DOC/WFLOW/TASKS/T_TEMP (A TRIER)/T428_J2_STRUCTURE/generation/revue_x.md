# Revue J3 — gpt-oss, avocat du diable mainteneur

Sortie brute du modèle, non corrigée. Vérification à la source : `../J3_MAILLONS.md` §4.

```text
V|PRG_06_Outputs.instSafetyEmergencyManagement.BypassPowerCutOff|OK|copie directe de GVL_BypassRetain.BypassAuPowerCutOff → CODE/M_MAIN/PRG_06_Outputs.st:499  
V|PRG_06_Outputs.instSafetyEmergencyManagement.BypassRedundancyTest|OK|copie directe de GVL_BypassRetain.BypassAuRedundancyTest → CODE/M_MAIN/PRG_06_Outputs.st:495  
V|PRG_02_Acquisition.Data.EncoderM1.HomedAndReliable|OK|propagation depuis FB_EncoderReliability → CODE/E_CODEURS/FB_EncoderReliability.st:34, puis assigné à MachineHomingM1Status → CODE/M_MAIN/PRG_02_Acquisition.st:549  
V|PRG_04_Treuils_Benne.SafetyPermitM1_Ascent|DOUTE|source instSafetyWinchM1.AscentPermit non visible dans les extraits → besoin de la définition de instSafetyWinchM1.AscentPermit (fichier ? :ligne ?)  
V|PRG_04_Treuils_Benne.SafetyPermitM1_Descend|DOUTE|source instSafetyWinchM1.DescendPermit non visible → besoin de la définition de instSafetyWinchM1.DescendPermit  
V|GVL_IHM.IoHw.Out.M1_SpeedContactor_2_DQ|OK|assigné depuis M1_SpeedContactor_2 → CODE/M_MAIN/PRG_06_Outputs.st:372 puis recopié → CODE/M_MAIN/PRG_07_Supervision.st:580  
V|GVL_IHM.IoHw.Out.M1_SpeedContactor_3_DQ|OK|assigné depuis M1_SpeedContactor_3 → CODE/M_MAIN/PRG_06_Outputs.st:373 puis recopié → CODE/M_MAIN/PRG_07_Supervision.st:581  
V|GVL_IHM.IoHw.Out.M1_BrakeRelease_RQ|OK|assigné depuis M1BrakeCmd → CODE/M_MAIN/PRG_06_Outputs.st:375 puis recopié → CODE/M_MAIN/PRG_07_Supervision.st:587  
V|PRG_02_Acquisition.Data.EncoderM2.HomedAndReliable|OK|propagation depuis FB_EncoderReliability → CODE/E_CODEURS/FB_EncoderReliability.st:34, puis assigné à MachineHomingM2Status → CODE/M_MAIN/PRG_02_Acquisition.st:553  
V|PRG_04_Treuils_Benne.SafetyPermitM2_Ascent|DOUTE|source instSafetyWinchM2.AscentPermit non visible → besoin de la définition de instSafetyWinchM2.AscentPermit  
V|PRG_04_Treuils_Benne.SafetyPermitM2_Descend|DOUTE|source instSafetyWinchM2.DescendPermit non visible → besoin de la définition de instSafetyWinchM2.DescendPermit  
V|GVL_IHM.IoHw.Out.M2_SpeedContactor_2_DQ|OK|assigné depuis M2_SpeedContactor_2 → CODE/M_MAIN/PRG_06_Outputs.st:381 puis recopié → CODE/M_MAIN/PRG_07_Supervision.st:584  
V|GVL_IHM.IoHw.Out.M2_SpeedContactor_3_DQ|OK|assigné depuis M2_SpeedContactor_3 → CODE/M_MAIN/PRG_06_Outputs.st:382 puis recopié → CODE/M_MAIN/PRG_07_Supervision.st:585  
V|GVL_IHM.IoHw.Out.M2_BrakeRelease_RQ|OK|assigné depuis M2BrakeCmd → CODE/M_MAIN/PRG_06_Outputs.st:384 puis recopié → CODE/M_MAIN/PRG_07_Supervision.st:588  
V|PRG_06_Outputs.M3_TremieHardStopActive|OK|propagation du DI hardware → CODE/M_MAIN/PRG_06_Outputs.st:431 (source PRG_02_Acquisition.HwIn.Translation.M3_PosTremie_DI)  
V|GVL_IHM.IoHw.Out.M3_CommandWord|OK|assigné depuis instTranslationOutputInterlockM3.DriveControlWord → CODE/M_MAIN/PRG_06_Outputs.st:458 puis recopié → CODE/M_MAIN/PRG_07_Supervision.st:600  
V|GVL_IHM.IoHw.Out.M3_BrakeRelease_RQ|OK|assigné depuis TranslationBrakeCmd → CODE/M_MAIN/PRG_06_Outputs.st:457 puis recopié → CODE/M_MAIN/PRG_07_Supervision.st:589  
V|PRG_04_Treuils_Benne.WinchBothFinalRequestsCoherent|FAUX|aucune assignation visible (ligne 1648 incomplète) → risque de valeur indéterminée  
V|PRG_04_Treuils_Benne.SyncOperationPermit|OK|assigné depuis PRG_03_Modes_Cycle.Data.Auth.SyncEnable → CODE/M_MAIN/PRG_04_Treuils_Benne.st:426 (source non montré mais logique)  
V|PRG_04_Treuils_Benne.ManualBucketJogActive|OK|assigné depuis joystick select = 2 → CODE/M_MAIN/PRG_04_Treuils_Benne.st:305  
V|PRG_04_Treuils_Benne.M2_LimitShift|OK|initialisé depuis instBucket.ActiveOffsetM → CODE/M_MAIN/PRG_04_Treuils_Benne.st:835 (re‑assignement à lui‑même est neutre)  
V|GVL_Troubleshooting.G_CycleSemiAuto.Idx207_StepStr|OK|copie du CycleStepStr → CODE/J_SUPERVISION/FB_TroubleshootingView.st:761  
V|GVL_Troubleshooting.G_CycleSemiAuto.Idx212_OperatorAction|OK|copie du CycleOperatorAction → CODE/J_SUPERVISION/FB_TroubleshootingView.st:766  
V|GVL_Troubleshooting.G_CycleSemiAuto.Idx222_ForceStepResult|OK|copie du CycleForceStepResult → CODE/J_SUPERVISION/FB_TroubleshootingView.st:759  

M|SafetyPermitM1_Ascent/Descend manquant|source instSafetyWinchM1.AscentPermit & DescendPermit non fourni → impossible de confirmer que la valeur reflète le permis effectif (fichier ? :ligne ?)  
M|SafetyPermitM2_Ascent/Descend manquant|source instSafetyWinchM2.AscentPermit & DescendPermit non fourni → même incertitude que ci‑dessus  
M|WinchBothFinalRequestsCoherent non initialisé|ligne 1648 vide → valeur indéterminée, risque de fausse indication de cohérence des demandes physiques  
M|SyncOperationPermit dépend de PRG_03_Modes_Cycle.Data.Auth.SyncEnable|déf. de SyncEnable non montrée → si SyncEnable erroné, le permis sera faux  
M|BypassPowerCutOff / BypassRedundancyTest dépend de GVL_BypassRetain|déf. et mise à jour de GVL_BypassRetain non fournie → risque que le statut de bypass ne reflète pas la réalité  
M|Encoder HomedAndReliable (M1/M2) dépend de EncoderAvailable, Homed, EncoderIncoherent|logique interne non visible → si ces signaux sont erronés, la variable sera trompeuse  
M|M3_TremieHardStopActive dépend du DI M3_PosTremie_DI|déf. du DI non montrée → si le capteur est défectueux, la variable sera fausse  
M|ManualBucketJogActive dépend du joystick select|pas de validation du mapping joystick → risque de déclenchement involontaire en mode MAINT_N1/2  

FIN|
```
