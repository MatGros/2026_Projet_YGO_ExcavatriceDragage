# Mission 2 — Audit Chaine Automate Reelle M3 (Lecture Seule)

Tu es un Expert Automatisme Industriel CODESYS ST & Securite Machine.
Regle : cite toujours `fichier:ligne` pour chaque affirmation. Zero complaisance.

## Probleme etudie
En reel, le chariot M3 depasse parfois la butee electrique (ex. Tremie ou Maintenance) a petite vitesse jusqu'au choc mecanique.
Note de trace reelle (trace 27 du 2026-09-04) :
- 26353 ms : Tremie=0, ContactFrein=1, Freq=1000 (10.00 Hz), Cmd=1, ErrorId=0
- 26438 ms : Tremie=1, ContactFrein=0, Freq=1000 (10.00 Hz), Cmd=0, ErrorId=64
- 26553 ms : Tremie=0 (perdu!), ContactFrein=0, Freq=913, Cmd=0, ErrorId=64

## Code reel PRG_05_Translation.st (lignes 470-760)
```iecst
470: // neutralisation des sécurités de fin de course depuis un mode de marche nominal.
471: // La garde est posée AU POINT DE CONSOMMATION : le stockage RETAIN et sa restauration vers
472: // l'IHM ne sont pas touchés, le bit reste donc lisible et actionnable en MAINT_N2.
473: // Origine du mode = arbitrage FB_Modes (Auth.Mode), jamais le sélecteur IHM brut — même
474: // exigence que la garde des bypass treuils.
475: M3_MaintN2 := (PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.MAINT_N2);
476: {endregion}
477: 
478: {region "§1bis Securite M3"}
479: // === 🛡️ §1bis SÉCURITÉ M3 (FB_Safety_Translation, câblée en parallèle visible) ===
480: // ⚠️ Ordre d'appel volontaire : la safety lit ici le BrakeReleaseRequest et le
481: // BrakeCmd du SCAN PRÉCÉDENT d'instTranslationM3 (elle est appelée avant), soit un retard
482: // d'un scan. Bénin : BrakeReleaseRequest ne change pas plus vite qu'un scan MainTask 10 ms
483: // sur une commande frein.
484: instSafetyTranslationM3(
485:     Enable                  := (PRG_03_Modes_Cycle.Data.Auth.Mode <> E_Mode.DISABLE),
486:     Reset                   := PRG_07_Supervision.FaultMachineReset_IHM,
487:     PowerContactorEngaged   := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
488:     Mode                    := PRG_03_Modes_Cycle.Data.Auth.Mode,
489:     JoystickOnline          := PRG_02_Acquisition.Data.Network.Joystick.Online,
490:     JoystickOperational     := PRG_02_Acquisition.Data.Network.Joystick.Operational,
491:     HeartbeatIhmOk          := GVL_IHM.Commun.HeartbeatIhmOk,
492:     PhaseRotationOk         := PRG_02_Acquisition.HwIn.Machine.PhaseRotationOk_DI,
493:     BrakeThermalFeedback    := NOT PRG_02_Acquisition.HwIn.Machine.M1_M2_M3_BrakeThermalOk_DI,
494:     DriveOnline             := PRG_02_Acquisition.Data.Network.DriveM3.Online,
495:     DriveOperational        := PRG_02_Acquisition.Data.Network.DriveM3.Operational,
496:     DriveStatusWord         := PRG_02_Acquisition.Data.M3.StatusWord,
497:     DriveActualFreqHz       := UINT_TO_REAL(PRG_02_Acquisition.Data.M3.ActualFrequencyHz) / 100.0,
498:     BrakeFeedback           := SEL(GVL_IHM.M3Translation.Bypass.ContactorFeedback OR GVL_IHM.M3Translation.Bypass.Global, PRG_02_Acquisition.HwIn.Translation.M3_BrakeIsOpen_DI, instTranslationM3.BrakeReleaseRequest),
499:     BrakeCmd                := instTranslationM3.BrakeReleaseRequest,
500:     RunRequest              := M3_RunRequest_Active,
501:     ReqTremie               := M3_ReqTremie_Active,
502:     ReqMaintenance          := M3_ReqMaintenance_Active,
503:     LimitSwitchTremie       := M3_LimitSwitchTremieStable,
504:     LimitSwitchMaintenance  := M3_LimitSwitchMaintenanceStable,
505:     SensorWordIncoherent    := instPosDecoderM3.Incoherent,
506:     BypassGlobal            := GVL_IHM.M3Translation.Bypass.Global,
507:     BypassOperatorComm      := GVL_IHM.M3Translation.Bypass.OperatorComm,
508:     BypassDriveComm         := GVL_IHM.M3Translation.Bypass.DriveComm,
509:     BypassPhaseRotation     := GVL_IHM.M3Translation.Bypass.PhaseRotation,
510:     BypassBrakeThermal      := GVL_IHM.M3Translation.Bypass.BrakeThermal,
511:     BypassMecaB             := GVL_IHM.M3Translation.Bypass.MecaB,
512:     BypassMecaA             := GVL_IHM.M3Translation.Bypass.MecaA,
513:     BypassLimitSwitch       := M3_MaintN2 AND (GVL_IHM.M3Translation.Bypass.LimitSwitch OR GVL_IHM.M3Translation.Bypass.Global),
514:     BypassSensorIncoherent  := GVL_IHM.M3Translation.Bypass.SensorIncoherent,
515:     BypassSafety            := GVL_IHM.M3Translation.Bypass.Safety,
516:     BypassProcess           := GVL_IHM.M3Translation.Bypass.Process
517: );
518: 
519: // SafeStop réellement appliqué au mouvement = agrégat InputModuleFault OR safety M3
520: // (8 mécanismes) — aucune des deux causes ne doit être perdue.
521: // + Verrou translation pendant le cycle de homing machine (HX2..HX6) : le chariot M3
522: //   ne doit pas bouger tant que M1/M2 se référencent (produit par FB_CycleMachineHoming,
523: //   publié PRG_02.Data.MachineHoming.M3Locked). Pas de bypass : conscient = quitter le cycle.
524: M3_SafeStop_Aggregate := M3_SafeStop_Active
525:                          OR instSafetyTranslationM3.SafeStop
526:                          OR PRG_02_Acquisition.Data.MachineHoming.M3Locked;
527: 
528: {endregion}
529: 
530: {region "§1ter Permis effectifs M3 (D1)"}
531: // === 🟢 §1ter PERMIS EFFECTIFS M3 (D1 — Phase 3) ===
532: // Niveau exposé à l'IHM = EFFECTIF, aligné sur les treuils M1/M2 (PRG_04 §5).
533: // ⚠️ Le permit est une INFORMATION DE POSSIBILITÉ de mouvement dans une direction,
534: // donnée AVANT l'ordre. Il reflète que l'axe est PRÊT À FONCTIONNER (pas de défaut,
535: // puissance, thermique) ET que la direction est physiquement possible (fins de course,
536: // autorisation cible). Il ne reflète PAS la commande (homme-mort) : l'homme-mort est une
537: // condition de COMMANDE (arbitrage FB_TranslationCmdArbitrationM3 / FB_CycleSemiAuto), pas de
538: // possibilité — il n'entre donc PAS dans le permit exposé.
539: // Pour M3, le Safety (FB_Safety_Translation) fournit les faits de sécurité :
540: //   - TremieLimitClear = NOT LimitSwitchTremie (direction possible vers Trémie)
541: //   - MaintenanceLimitClear = NOT LimitSwitchMaintenance (direction possible jusqu'à P1)
542: //   - SafeStop / PowerCutOff = défauts (thermique, Méca A/B, incohérence, comm, phases...)
543: // Le permis effectif = fait de limite libre AND NOT SafeStop AND NOT PowerCutOff
544: // (prêt à fonctionner), aligné sur le modèle treuils où le Safety produit déjà des
545: // permis gatés par les défauts. Pas de Process supplémentaire (pas de benne/Kobold).
546: // ⚠️ Le verrou « descente treuil interdite tant que M3 pas à P1 » (DumpAtTremieDescentLocked)
547: // est côté TREUIL (PRG_04 §5, lignes 802-805), pas dans le permit M3 : le permit M3 reste une
548: // information de possibilité de mouvement de la translation, indépendante de l'état de la trémie.
549: // ⚠️ Le permit M3 est un permit EFFECTIF « pouvoir bouger » (prêt à fonctionner), PAS un pur
550: // directionnel. Quand l'axe est en défaut (SafeStop/PowerCutOff), TOUS les sens sont bloqués ;
551: // au retour en condition, un sens peut être permis et pas l'autre. L'interdiction d'accès à la
552: // zone Maintenance ne retire PAS le permis de rejoindre P1 : elle agit sur la cible et la
553: // coupure dure M3_LimitSwitchMaintenanceEffective.
554: EffectivePermitM3_Tremie    := instSafetyTranslationM3.TremieLimitClear
555:                                AND NOT M3_SafeStop_Aggregate
556:                                AND NOT instSafetyTranslationM3.PowerCutOff
557:                                AND NOT M3_TremieProcessBlock;
558: EffectivePermitM3_Maintenance := instSafetyTranslationM3.MaintenanceLimitClear
559:                                   AND NOT M3_SafeStop_Aggregate
560:                                   AND NOT instSafetyTranslationM3.PowerCutOff;
561: 
562: {endregion}
563: 
564: {region "§2 Pilotage translation M3"}
565: // === ⚙️ §2 EXÉCUTION PILOTAGE TRANSLATION M3 ===
566: 
567: // 🔧 Assemblage de la config FB_Translation (C3) — SOURCE UNIQUE : GVL_PERSISTENT.
568: // Fini le double sourcing (rampes flat + vitesses d'approche via GVL_IHM.M3Translation.Cfg).
569: // Les 3 vitesses d'approche sont lues dans _TranslationCfgPersist (miroir persistant de
570: // ST_TranslationCfg, synchronisé par FB_CfgPersistBridge_TranslationCfg dans PRG_07) — la
571: // valeur reflète toute modification IHM persistée. Les délais (DirectionInterlockDelay,
572: // CaptorDebounce, BrakeDelay*, BrakeFeedbackTimeout) restent aux valeurs défaut du struct
573: // (non réglés IHM) — même comportement qu'avant (non câblés, défauts FB).
574: TranslationCfg.CfgRampAccelRate           := _TranslationRampAccelRate_Pct;
575: TranslationCfg.CfgRampDecelNormalRate     := _TranslationRampDecelNormal_Pct;
576: TranslationCfg.CfgRampDecelFastRate       := _TranslationRampDecelFast_Pct;
577: TranslationCfg.DriveFreqScaleMaxHz        := _TranslationMaxFreq_Hz;
578: TranslationCfg.ApproachSpeedTremieHz      := _TranslationCfgPersist.CfgApproachSpeedTremie_Hz;
579: TranslationCfg.ApproachSpeedMaintenanceHz := _TranslationCfgPersist.CfgApproachSpeedMaintenance_Hz;
580: TranslationCfg.ApproachSpeedP1Hz          := _TranslationCfgPersist.CfgApproachSpeedP1_Hz;
581: 
582: instTranslationM3(
583:     Enable                  := (PRG_03_Modes_Cycle.Data.Auth.Mode <> E_Mode.DISABLE),
584:     Reset                   := PRG_07_Supervision.FaultMachineReset_IHM,
585:     PowerContactorEngaged   := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
586:     Mode                    := PRG_03_Modes_Cycle.Data.Auth.Mode,
587:     RunRequest              := M3_RunRequest_Active,
588:     SafeStop                := M3_SafeStop_Aggregate,
589:     ReqTremie               := M3_ReqTremie_Active,
590:     ReqMaintenance          := M3_ReqMaintenance_Active,
591:     InvertDriveDirection    := GVL_IHM.M3Translation.Cmd.InvertDirection,
592:     SpeedTgt_Pct            := M3_SpeedCmd_Active,
593:     PositionSensorTarget    := M3_PositionSensorTarget,
594:     SlowdownSensorTremie       := instPosDecoderM3.TranslationPosPV,
595:     // Les 5 capteurs forment un code thermomètre cumulatif depuis la Trémie (voir
596:     // FB_Translation_PositionDecoder.st). Chaque zone est délimitée par "capteur PRÉCÉDENT retombé
597:     // à 0" ET "capteur de la zone encore à 1" — zone P2→P1 = NOT PosP2 AND PosP1 (mot 00011) ;
598:     // zone P1→Maintenance = NOT PosP1 AND PosMaintenance (mot 00001). Zones mutuellement exclusives,
599:     // chacune sa propre vitesse d'approche (CfgApproachSpeedP1_Hz / CfgApproachSpeedMaintenance_Hz).
600:     SlowdownSensorMaintenance  := (NOT instPosDecoderM3.TranslationPosP1) AND instPosDecoderM3.TranslationPosMaintenance,
601:     // Ralentissement P2→P1 UNIQUEMENT si P1 est un vrai point
602:     // d'arrêt (zone Maintenance NON autorisée). Zone Maintenance autorisée -> 100% vitesse jusqu'à
603:     // P1, ralentissement seulement après (zone P1→Maintenance, SlowdownSensorMaintenance ci-dessus).
604:     SlowdownSensorP1           := (NOT instPosDecoderM3.TranslationPosP2) AND instPosDecoderM3.TranslationPosP1
605:                                    AND NOT PRG_03_Modes_Cycle.Data.Auth.MaintenanceM3TargetEnable,
606:     LimitSwitchTremie       := M3_LimitSwitchTremieStable,
607:     LimitSwitchMaintenance  := M3_LimitSwitchMaintenanceStable,
608:     // 🛡️ Permis directionnels SAFETY (source unique instSafetyTranslationM3) — gate de sens FB_Translation
609:     EffectivePermitM3_Tremie := EffectivePermitM3_Tremie,
610:     EffectivePermitM3_Maintenance := EffectivePermitM3_Maintenance,
611:     DriveStatusWord         := PRG_02_Acquisition.Data.M3.StatusWord,
612:     DriveActualFreqHz       := UINT_TO_REAL(PRG_02_Acquisition.Data.M3.ActualFrequencyHz) / 100.0,
613:     Cfg                     := TranslationCfg,
614:     BrakeFeedback           := SEL(GVL_IHM.M3Translation.Bypass.ContactorFeedback OR GVL_IHM.M3Translation.Bypass.Global, PRG_02_Acquisition.HwIn.Translation.M3_BrakeIsOpen_DI, instTranslationM3.BrakeReleaseRequest),
615:     BypassContactorCheck    := GVL_IHM.M3Translation.Bypass.Global OR GVL_IHM.M3Translation.Bypass.ContactorFeedback,
616:     BypassLimitSwitch       := M3_MaintN2 AND (GVL_IHM.M3Translation.Bypass.Global OR GVL_IHM.M3Translation.Bypass.LimitSwitch)
617: );
618: 
619: // 📏 Gain odométrique (T301) : réglage site |P2-PV| / (CalibFreq × CalibTime), repli sur le gain
620: // persistant si non saisi. La mesure P2 <-> PV est PROPOSÉE (State.OdometryMeasured*), jamais appliquée.
621: instOdometryGainM3(
622:     Enable               := (PRG_03_Modes_Cycle.Data.Auth.Mode <> E_Mode.DISABLE),
623:     SensorPV             := instPosDecoderM3.TranslationPosPV,
624:     SensorP2             := instPosDecoderM3.TranslationPosP2,
625:     DriveActualFreq_Hz   := TO_REAL(PRG_02_Acquisition.Data.M3.ActualFrequencyHz) / 100.0,
626:     PosPV_M              := GVL_PERSISTENT._TranslationPosPV_M,
627:     PosP2_M              := GVL_PERSISTENT._TranslationPosP2_M,
628:     CalibFreq_Hz         := GVL_PERSISTENT._TranslationCalibFreq_Hz,
629:     CalibTime_S          := GVL_PERSISTENT._TranslationCalibTimeP2PV_S,
630:     FallbackGain         := GVL_PERSISTENT._TranslationGainMetersPerHzSec
631: );
632: 
633: // 📐 Estimateur de position continue M3 (odométrie + recalage 5 capteurs)
634: instPosEstimatorM3(
635:     Enable               := (PRG_03_Modes_Cycle.Data.Auth.Mode <> E_Mode.DISABLE),
636:     Reset                := PRG_07_Supervision.FaultMachineReset_IHM,
637:     DriveActualFreqHz    := TO_REAL(PRG_02_Acquisition.Data.M3.ActualFrequencyHz) / 100.0,
638:     ReqTremie            := M3_ReqTremie_Active,
639:     ReqMaintenance       := M3_ReqMaintenance_Active,
640:     SensorMaintenance    := instPosDecoderM3.TranslationPosMaintenance,
641:     SensorP1             := instPosDecoderM3.TranslationPosP1,
642:     SensorP2             := instPosDecoderM3.TranslationPosP2,
643:     SensorPV             := instPosDecoderM3.TranslationPosPV,
644:     SensorTremie         := instPosDecoderM3.TranslationPosTremie,
645:     PosMaintenanceM      := GVL_PERSISTENT._TranslationPosMaintenance_M,
646:     PosP1M               := GVL_PERSISTENT._TranslationPosP1_M,
647:     PosP2M               := GVL_PERSISTENT._TranslationPosP2_M,
648:     PosPVM               := GVL_PERSISTENT._TranslationPosPV_M,
649:     PosTremieM           := GVL_PERSISTENT._TranslationPosTremie_M,
650:     GainMetersPerHzSec   := instOdometryGainM3.GainActive,
651:     PersistedPositionM   := GVL_PERSISTENT._TranslationPosEstimated_M,
652:     PersistedInitialized := GVL_PERSISTENT._TranslationPosEstimatedInitialized
653: );
654: // Recopie continue (reprise après reboot, doctrine _TranslationSetFreq_Hz) — pas de bridge dédié.
655: GVL_PERSISTENT._TranslationPosEstimated_M := instPosEstimatorM3.PositionEstimatedM;
656: GVL_PERSISTENT._TranslationPosEstimatedInitialized := instPosEstimatorM3.Initialized;
657: 
658: // === T249-B : TEXTE STATUT POSITION M3 (lecture seule IHM) ============================
659: // Source = jeton "at position" sur front capteur (M3_AtXxxStable, mecanisme d'origine,
660: // RAZ sur changement de mot capteurs). Sinon zone entre 2 capteurs via SensorsWord
661: // (code thermometre cumulatif). AUCUNE dependance a la frequence variateur.
662: IF M3_AtTremieStable THEN
663:     M3_StatusText := 'M3 a la Tremie';
664: ELSIF M3_AtMaintenanceStable THEN
665:     M3_StatusText := 'M3 a la Maintenance';
666: ELSIF M3_AtP1Stable THEN
667:     M3_StatusText := 'M3 a P1';
668: ELSIF M3_AtP2Stable THEN
669:     M3_StatusText := 'M3 a P2';
670: ELSIF M3_AtPVStable THEN
671:     M3_StatusText := 'M3 a PV';
672: ELSIF instPosDecoderM3.Incoherent THEN
673:     M3_StatusText := 'M3 capteurs INCOHERENTS';
674: ELSE
675:     CASE instPosDecoderM3.SensorsWord OF
676:         2#11111: M3_StatusText := 'M3 a la Tremie';
677:         2#01111: M3_StatusText := 'M3 entre Tremie et PV';
678:         2#00111: M3_StatusText := 'M3 entre PV et P2';
679:         2#00011: M3_StatusText := 'M3 entre P2 et P1';
680:         2#00001: M3_StatusText := 'M3 entre P1 et Maintenance';
681:         2#00000: M3_StatusText := 'M3 a la Maintenance';
682:     ELSE
683:         M3_StatusText := 'M3 position indeterminee';
684:     END_CASE;
685: END_IF;
686: // Suffixe sens de deplacement (commande active).
687: IF M3_ReqTremie_Active THEN
688:     M3_StatusText := CONCAT(M3_StatusText, ' -> Tremie');
689: ELSIF M3_ReqMaintenance_Active THEN
690:     M3_StatusText := CONCAT(M3_StatusText, ' -> Maintenance');
691: END_IF;
692: 
693: {endregion}
694: 
695: {region "§3 Publication demande translation"}
696: // === 📤 §3 PUBLICATION DEMANDE BRUTE TRANSLATION ===
697: 
698: TranslationFinalInterlockRequest.Enable := (PRG_03_Modes_Cycle.Data.Auth.Mode <> E_Mode.DISABLE);
699: TranslationFinalInterlockRequest.Reset := PRG_07_Supervision.FaultMachineReset_IHM;
700: TranslationFinalInterlockRequest.PowerContactorEngaged := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI;
701: TranslationFinalInterlockRequest.SafeStop := M3_SafeStop_Aggregate;
702: TranslationFinalInterlockRequest.PowerCutOff := instSafetyTranslationM3.PowerCutOff;
703: TranslationFinalInterlockRequest.EffectivePermitM3_Tremie := EffectivePermitM3_Tremie;
704: TranslationFinalInterlockRequest.EffectivePermitM3_Maintenance := EffectivePermitM3_Maintenance;
705: TranslationFinalInterlockRequest.BrakeReleaseRequest := instTranslationM3.BrakeReleaseRequest;
706: TranslationFinalInterlockRequest.BrakeCommandOpenConfirmed := instTranslationM3.BrakeCommandOpenConfirmed;
707: TranslationFinalInterlockRequest.RequestedDriveControlWord := instTranslationM3.RequestedDriveControlWord;
708: TranslationFinalInterlockRequest.RequestedDriveFreqHz := instTranslationM3.RequestedDriveFreqHz;
709: TranslationFinalInterlockRequest.ReqTremieSemantic := M3_ReqTremie_Active;
710: 
711: // Derniere barriere avant PRG_06 : neutralisation immediate du variateur ET du
712: // frein M3 hors AX2/AX14 en SEMI_AUTO. Elle reste volontairement redondante avec
713: // le veto amont pour qu'une rampe ou un sens memorise dans FB_Translation ne
714: // puisse alimenter M3 pendant une etape benne.
715: IF (PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.SEMI_AUTO)
716:    AND NOT M3_CycleTranslationStepAuthorized THEN
717:     TranslationFinalInterlockRequest.BrakeReleaseRequest := FALSE;
718:     TranslationFinalInterlockRequest.RequestedDriveControlWord := 0;
719:     TranslationFinalInterlockRequest.RequestedDriveFreqHz := 0.0;
720:     TranslationFinalInterlockRequest.ReqTremieSemantic := FALSE;
721: END_IF;
722: 
723: {endregion}
724: 
725: {region "§4 Publication etat IHM"}
726: // === 📤 PUBLICATION ÉTAT TRANSLATION IHM (lecture seule) ===
727: IF instTranslationM3.Fault.Error THEN
728:     TranslationState.FBState := E_State.ERROR;
729: ELSIF ABS(instTranslationM3.RequestedDriveFreqHz) > 0.1 THEN
730:     TranslationState.FBState := E_State.BUSY;
731: ELSE
732:     TranslationState.FBState := E_State.READY;
733: END_IF;
734: TranslationState.Ready := instTranslationM3.Ready;
735: TranslationState.Busy := (ABS(instTranslationM3.RequestedDriveFreqHz) > 0.1);
736: TranslationState.Done := instTranslationM3.TargetReached;
737: TranslationState.Error := instTranslationM3.Fault.Error;
738: TranslationState.ErrorId := instTranslationM3.Fault.ErrorId;
739: TranslationState.BrakeCmd := instTranslationM3.BrakeReleaseRequest;
740: TranslationState.BrakeCommandOpenConfirmed := instTranslationM3.BrakeCommandOpenConfirmed;
741: // 🔌 Retour physique direct frein M3 (même source que le SEL §1bis/§2) — consommé FB_TroubleshootingView Idx108
742: TranslationState.BrakeFeedback := PRG_02_Acquisition.HwIn.Translation.M3_BrakeIsOpen_DI;
743: TranslationState.PositionReached := instTranslationM3.TargetReached;
744: TranslationState.DriveControlWord := instTranslationM3.RequestedDriveControlWord;
745: TranslationState.DriveFreqCmd_Hz := instTranslationM3.RequestedDriveFreqHz;
746: // 🎯 Cohérence sim : les bits actifs/SpeedCmd_Pct n'affichent la
747: // consigne QUE si la commande variateur est réellement émise (RequestedDriveControlWord <> 0).
748: // Sinon, un interlock bloquant (hauteur, SafeStop…) laisserait l'IHM suggérer un mouvement
749: // qui n'a pas lieu ("je bouge mais ça bouge pas"). Affiche 0 quand c'est bloqué.
750: TranslationState.ActiveTremie := instTranslationM3.RequestedDriveControlWord = 1;
751: TranslationState.ActiveMaintenance := instTranslationM3.RequestedDriveControlWord = 2;
752: TranslationState.SpeedCmd_Pct := SEL(instTranslationM3.RequestedDriveControlWord <> 0, M3_SpeedCmd_Active, 0.0);
753: TranslationState.PositionTremie := instPosDecoderM3.TranslationPosTremie;
754: TranslationState.PositionPV := instPosDecoderM3.TranslationPosPV;
755: TranslationState.PositionP2 := instPosDecoderM3.TranslationPosP2;
756: TranslationState.PositionP1 := instPosDecoderM3.TranslationPosP1;
757: TranslationState.PositionMaintenance := instPosDecoderM3.TranslationPosMaintenance;
758: // Affichage IHM = M3_AtXxxStable (§0quater) — armé sur front
759: // (direction-dépendant), libéré sur mouvement réel confirmé ≥1.5s (pas juste un rebond capteur
760: // ni un changement de sens instantané). Même signal que celui consommé par M3_PositionSensorTarget.
```

## Code reel PRG_06_Outputs.st (lignes 405-470)
```iecst
405: // ↔️ §3 TRANSLATION M3 (variateur AC600) — conditions + interlock + sorties
406: // ═══════════════════════════════════════════════════════════════
407: // 👁️ Même lecture : gate finale, défauts PowerCutOff / SafeStop, synthèse.
408: // Sources : PRG_05 (TranslationFinalInterlockRequest / TranslationSafety).
409: 
410: M3InterlockEnable := PRG_05_Translation.Data.TranslationFinalInterlockRequest.Enable
411:                       AND NOT PRG_05_Translation.Data.TranslationFinalInterlockRequest.PowerCutOff;
412: 
413: M3PowerCutOffSafetyInfo := PRG_05_Translation.Data.TranslationSafety.PowerCutOff
414:                         OR PRG_05_Translation.Data.TranslationSafety.ErrorMecaA
415:                         OR PRG_05_Translation.Data.TranslationSafety.ErrorMecaB
416:                         OR PRG_05_Translation.Data.TranslationSafety.ErrorBrakeThermal;
417: 
418: M3SafeStopSafetyInfo := PRG_05_Translation.Data.TranslationSafety.SafeStop
419:                      OR PRG_05_Translation.Data.TranslationSafety.Error
420:                      OR PRG_05_Translation.Data.TranslationSafety.ErrorOperatorComm
421:                      OR PRG_05_Translation.Data.TranslationSafety.ErrorDriveComm
422:                      OR PRG_05_Translation.Data.TranslationSafety.ErrorPhaseRotation
423:                      OR PRG_05_Translation.Data.TranslationSafety.ErrorLimitSwitch
424:                      OR PRG_05_Translation.Data.TranslationSafety.ErrorSensorIncoherent;
425: 
426: M3BlockedBySafetyInfo := M3PowerCutOffSafetyInfo OR M3SafeStopSafetyInfo;
427: 
428: // Coupure directionnelle ultime sur le FDC physique Tremie. Cette barriere lit
429: // le DI qualifie du meme scan et ne depend ni du decodeur de position, ni du G7,
430: // ni du step courant. Le recul vers P1/Maintenance reste autorise.
431: M3_TremieHardStopActive := PRG_02_Acquisition.HwIn.Translation.M3_PosTremie_DI
432:                            AND PRG_05_Translation.Data.TranslationFinalInterlockRequest.ReqTremieSemantic;
433: 
434: instTranslationOutputInterlockM3(
435:     Enable                     := M3InterlockEnable,
436:     Reset                      := PRG_07_Supervision.FaultMachineReset_IHM,
437:     PowerContactorEngaged      := PRG_05_Translation.Data.TranslationFinalInterlockRequest.PowerContactorEngaged,
438:     SafeStop                   := PRG_05_Translation.Data.TranslationFinalInterlockRequest.SafeStop,
439:     EffectivePermitM3_Tremie   := PRG_05_Translation.Data.TranslationFinalInterlockRequest.EffectivePermitM3_Tremie
440:                                   AND NOT PRG_02_Acquisition.HwIn.Translation.M3_PosTremie_DI,
441:     EffectivePermitM3_Maintenance := PRG_05_Translation.Data.TranslationFinalInterlockRequest.EffectivePermitM3_Maintenance,
442:     BrakeReleaseRequest        := PRG_05_Translation.Data.TranslationFinalInterlockRequest.BrakeReleaseRequest
443:                                   AND NOT M3_TremieHardStopActive,
444:     BrakeCommandOpenConfirmed  := PRG_05_Translation.Data.TranslationFinalInterlockRequest.BrakeCommandOpenConfirmed,
445:     RequestedDriveControlWord  := SEL(M3_TremieHardStopActive,
446:                                       PRG_05_Translation.Data.TranslationFinalInterlockRequest.RequestedDriveControlWord,
447:                                       WORD#0),
448:     RequestedDriveFreqHz       := SEL(M3_TremieHardStopActive,
449:                                       PRG_05_Translation.Data.TranslationFinalInterlockRequest.RequestedDriveFreqHz,
450:                                       0.0)
451: );
452: 
453: TranslationBrakeCmd := instTranslationOutputInterlockM3.BrakeCmd;
454: // Pas de garde anti-chatter sur le frein M3 : re-desserrage immédiat requis (cf. §2quater).
455: 
456: // ── Sorties physiques M3 ──
457: M3_BrakeRelease_RQ           := TranslationBrakeCmd;
458: M3_CommandWord               := instTranslationOutputInterlockM3.DriveControlWord;
459: M3_SetpointFrequencyHz       := instTranslationOutputInterlockM3.DriveFreqCmdWord;
460: 
461: // ── Bus inter-PRG M3 ──
462: Data.TranslationBrakeCmd   := TranslationBrakeCmd;
463: Data.M3CommandWordActive   := (M3_CommandWord <> WORD#0);
464: 
465: // ═══════════════════════════════════════════════════════════════
466: // 🪝 §4 KOBOLD (capteur fond) — commande + sortie
467: // ═══════════════════════════════════════════════════════════════
468: // Source : PRG_04 (KoboldContactorCmdArbitrated).
469: KoboldContactorCmd := PRG_04_Treuils_Benne.Data.KoboldContactorCmdArbitrated;
470: M1_M2_KoboldMeasureEnable_RQ := KoboldContactorCmd;
```

## Livrable attendu (concis, structure TDAH-friendly)
1. **Chemin exact de coupure en butee** (variateur + frein + safety) en petite vitesse (Manu vs SEMI_AUTO).
2. **Failles ou latences possibles** dans ce code reel qui pourraient laisser le chariot franchir la butee electrique a petite vitesse (ex. scan delay, conditionnement de `M3_TremieHardStopActive`, `DelayMotorDecel`, hysteresis/perte capteur, sens Maintenance non protege par HardStop ?).
3. **Points a verifier dans `FB_Translation.st` et `FB_Safety_Translation.st`** (liste ciblee, max 5 points).
