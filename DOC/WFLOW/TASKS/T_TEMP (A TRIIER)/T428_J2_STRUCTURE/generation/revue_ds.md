# Revue J3 — DeepSeek, challenger sûreté

Sortie brute du modèle, non corrigée. Vérification à la source : `../J3_MAILLONS.md` §4.

```text
V|PRG_06_Outputs.instSafetyEmergencyManagement.BypassPowerCutOff|OK|Affecté depuis GVL_BypassRetain en PRG_06:499, lu après PRG_06 par PRG_07 ; valeur réelle du bypass.
V|PRG_06_Outputs.instSafetyEmergencyManagement.BypassRedundancyTest|OK|Affecté PRG_06:495 depuis GVL_BypassRetain ; cohérent avec déclaration FB:30.
V|PRG_02_Acquisition.Data.EncoderM1.HomedAndReliable|OK|Recopié PRG_02:682 depuis instEncoderM1, calculé FB_EncoderReliability:34 (dispo ET ref ET pas incohérent).
V|PRG_04_Treuils_Benne.SafetyPermitM1_Ascent|OK|Affecté PRG_04:1067 depuis instSafetyWinchM1.AscentPermit ; vrai permis Safety.
V|PRG_04_Treuils_Benne.SafetyPermitM1_Descend|OK|Affecté PRG_04:1065 depuis instSafetyWinchM1.DescendPermit.
V|GVL_IHM.IoHw.Out.M1_SpeedContactor_2_DQ|OK|Image sortie PRG_06:372 puis recopie PRG_07:580 ; reflète la commande automate, pas le retour physique.
V|GVL_IHM.IoHw.Out.M1_SpeedContactor_3_DQ|OK|PRG_06:373 puis PRG_07:581 ; image de sortie cohérente.
V|GVL_IHM.IoHw.Out.M1_BrakeRelease_RQ|OK|PRG_06:375 (M1BrakeCmd) puis PRG_07:587 ; sortie réelle frein M1.
V|PRG_02_Acquisition.Data.EncoderM2.HomedAndReliable|DOUTE|Extraits ne montrent que la recopie M1 (PRG_02:682) ; ligne d'affectation EncoderM2 absente.
V|PRG_04_Treuils_Benne.SafetyPermitM2_Ascent|OK|Affecté PRG_04:1068 depuis instSafetyWinchM2.AscentPermit.
V|PRG_04_Treuils_Benne.SafetyPermitM2_Descend|OK|Affecté PRG_04:1066 depuis instSafetyWinchM2.DescendPermit.
V|GVL_IHM.IoHw.Out.M2_SpeedContactor_2_DQ|OK|PRG_06:381 puis PRG_07:584 ; image sortie.
V|GVL_IHM.IoHw.Out.M2_SpeedContactor_3_DQ|OK|PRG_06:382 puis PRG_07:585 ; image sortie.
V|GVL_IHM.IoHw.Out.M2_BrakeRelease_RQ|OK|PRG_06:384 (M2BrakeCmd) puis PRG_07:588 ; sortie réelle frein M2.
V|PRG_06_Outputs.M3_TremieHardStopActive|OK|PRG_06:431 recopie directe du DI brut M3_PosTremie_DI ; coupure visible.
V|GVL_IHM.IoHw.Out.M3_CommandWord|OK|PRG_06:458 depuis DriveControlWord puis PRG_07:600 ; mot réel M3.
V|GVL_IHM.IoHw.Out.M3_BrakeRelease_RQ|OK|PRG_06:457 (TranslationBrakeCmd) puis PRG_07:589 ; sortie réelle frein M3.
V|PRG_04_Treuils_Benne.WinchBothFinalRequestsCoherent|DOUTE|Déclaration PRG_04:83 et affectation:1648 tronquée ; expression non fournie.
V|PRG_04_Treuils_Benne.SyncOperationPermit|OK|Affecté PRG_04:426 depuis PRG_03.Data.Auth.SyncEnable ; gate canonique.
V|PRG_04_Treuils_Benne.ManualBucketJogActive|DOUTE|PRG_04:305 ne montre que la condition WinchSel=2 ; la condition MAINT annoncée:200 n'est pas dans l'extrait.
V|PRG_04_Treuils_Benne.M2_LimitShift|OK|PRG_04:835 depuis instBucket.ActiveOffsetM ; décalage benne M2 réel.
V|GVL_Troubleshooting.G_CycleSemiAuto.Idx207_StepStr|OK|Recopie FB_TroubleshootingView:761 depuis CycleStepStr ; libellé étape.
V|GVL_Troubleshooting.G_CycleSemiAuto.Idx212_OperatorAction|OK|Recopie:766 depuis CycleOperatorAction ; action/attente.
V|GVL_Troubleshooting.G_CycleSemiAuto.Idx222_ForceStepResult|OK|Recopie:759 depuis CycleForceStepResult ; motif rejet forçage.

M|EncoderM2.HomedAndReliable|Affectation Data.EncoderM2 manquante dans les extraits (seul M1:682 fourni) ; à confirmer.
M|WinchBothFinalRequestsCoherent|Expression:1648 tronquée ; impossible de vérifier l'égalité effective annoncée.
M|ManualBucketJogActive|Condition MAINT absente de l'extrait:305 ; risque de faux positif hors MAINT.
M|IoHw.Out = image commande, pas retour terrain|PRG_06:372-384 recopie la commande automate ; ne prouve pas l'état physique réel du contacteur/frein.
M|Ordre scan PRG_07 après PRG_06|Cohérence supposée par l'ordre MainTask fourni ; non vérifiable dans les extraits.
M|Bypass lus depuis GVL_BypassRetain|PRG_06:495/499 ; dépend de la fraîcheur de cette GVL, non montrée.
FIN|
```
