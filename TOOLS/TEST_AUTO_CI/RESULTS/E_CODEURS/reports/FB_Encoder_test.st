SETUP
VAR
    fb    : FB_Encoder;
    calib : ST_Encoder_Calib;
    hwIn  : ST_fbEncoder_HwIn;
    cfg   : ST_fbEncoder_Cfg;
END_VAR
END_SETUP

TEST 'TC-P03-001 Dynamique Enable : neutralisation initiale, transition Ready au repos, puis coupure'
    (* Scan 0 : Enable=FALSE -> Neutralisation initiale *)
    fb(Enable := FALSE, Calib := calib);
    ASSERT_FALSE(fb.READY, 'Enable=FALSE -> Ready=FALSE (neutralise)');

    ADVANCE_TIME(10000000);

    (* Scan 1 : Enable=TRUE -> Prete en service *)
    fb(Enable := TRUE, Calib := calib);
    ASSERT_TRUE(fb.READY, 'Enable=TRUE -> Ready=TRUE (nominal)');

    ADVANCE_TIME(10000000);

    (* Scan 2 : Enable=FALSE -> Re-neutralisation *)
    fb(Enable := FALSE, Calib := calib);
    ASSERT_FALSE(fb.READY, 'Enable=FALSE -> Ready retombe a FALSE');
END_TEST

TEST 'TC-P09-010 Acquisition codeur : mise en service nominale'
    fb(Enable := TRUE, PointsPerRev := 4096, CableM_PerRev := 0.5, PositionMinM := -50.0, PositionMaxM := 50.0, Calib := calib);
    ASSERT_TRUE(fb.Ready, 'Codeur actif et pret');
END_TEST

TEST 'TC-P09-011 Preset READBACK_ONLY : commit atomique apres relecture 500ms'
    hwIn.SlaveOperational := TRUE;
    hwIn.RawPosIn := 100000;
    hwIn.PresetStatusBit := FALSE;
    cfg.PresetConfirmMode := E_PresetConfirmMode.READBACK_ONLY;
    calib.Homed := FALSE;
    calib.HomingSuspect := FALSE;
    calib.HomingRefRaw := 1234;

    (* Front de demande : aucune calibration n est publiee avant verification. *)
    fb(Enable := TRUE, HomingPermit := TRUE, HomingAtTargetM := TRUE,
       CfgHomingTargetM := 1.0, HwIn := hwIn, Cfg := cfg, Calib := calib);
    ASSERT_FALSE(calib.Homed, 'Avant verification : Homed reste FALSE');
    ASSERT_EQ(calib.HomingRefRaw, 1234, 'Avant verification : reference existante preservee');

    ADVANCE_TIME(600000000);
    fb(Enable := TRUE, HomingPermit := TRUE, HomingAtTargetM := FALSE,
       CfgHomingTargetM := 1.0, HwIn := hwIn, Cfg := cfg, Calib := calib);
    ASSERT_TRUE(fb.Homed, 'READBACK_ONLY : mesure egale a la cible -> sortie Homed');
    ASSERT_FALSE(fb.HomingSuspect, 'READBACK_ONLY nominal : pas de suspicion');
END_TEST

TEST 'TC-P09-012 Preset READBACK_AND_STATUSBIT : bit FALSE refuse sans valider'
    hwIn.SlaveOperational := TRUE;
    hwIn.RawPosIn := 100000;
    hwIn.PresetStatusBit := FALSE;
    cfg.PresetConfirmMode := E_PresetConfirmMode.READBACK_AND_STATUSBIT;
    calib.Homed := FALSE;
    calib.HomingSuspect := FALSE;
    calib.HomingRefRaw := 2345;

    fb(Enable := TRUE, HomingPermit := TRUE, HomingAtTargetM := TRUE,
       CfgHomingTargetM := 1.0, HwIn := hwIn, Cfg := cfg, Calib := calib);
    ADVANCE_TIME(600000000);
    fb(Enable := TRUE, HomingPermit := TRUE, HomingAtTargetM := FALSE,
       CfgHomingTargetM := 1.0, HwIn := hwIn, Cfg := cfg, Calib := calib);
    ASSERT_FALSE(fb.Homed, 'READBACK_AND_STATUSBIT : bit FALSE -> pas de validation');
    ASSERT_TRUE(fb.HomingSuspect, 'READBACK_AND_STATUSBIT : bit FALSE -> suspicion');
    ASSERT_TRUE(fb.PresetConfirmationFailed, 'READBACK_AND_STATUSBIT : fait diagnostic publie');
END_TEST

TEST 'TC-P09-013 Echec relecture 50mm : suspicion et diagnostic sans validation'
    hwIn.SlaveOperational := TRUE;
    hwIn.RawPosIn := 100000;
    hwIn.PresetStatusBit := FALSE;
    cfg.PresetConfirmMode := E_PresetConfirmMode.READBACK_ONLY;
    calib.Homed := TRUE;
    calib.HomingSuspect := FALSE;
    calib.HomingRefRaw := 70000;
    calib.LastKnownRawPos := 100000;

    fb(Enable := TRUE, HomingPermit := TRUE, HomingAtTargetM := TRUE,
       CfgHomingTargetM := 1.0, HwIn := hwIn, Cfg := cfg, Calib := calib);
    hwIn.RawPosIn := 100205; (* +50mm a 4096 points/m *)
    ADVANCE_TIME(600000000);
    fb(Enable := TRUE, HomingPermit := TRUE, HomingAtTargetM := FALSE,
       CfgHomingTargetM := 1.0, HwIn := hwIn, Cfg := cfg, Calib := calib);
    ASSERT_FALSE(fb.Homed, 'Echec relecture : sortie Homed non validee');
    ASSERT_TRUE(fb.HomingSuspect, 'Echec relecture : suspicion active');
    ASSERT_TRUE(fb.PresetConfirmationFailed, 'Echec relecture : fait diagnostic publie');
END_TEST

TEST 'TC-P09-014 STATUSBIT_ONLY : bit TRUE valide la transaction'
    hwIn.SlaveOperational := TRUE;
    hwIn.RawPosIn := 100000;
    hwIn.PresetStatusBit := TRUE;
    cfg.PresetConfirmMode := E_PresetConfirmMode.STATUSBIT_ONLY;
    calib.Homed := FALSE;
    calib.HomingSuspect := FALSE;

    fb(Enable := TRUE, HomingPermit := TRUE, HomingAtTargetM := TRUE,
       CfgHomingTargetM := 1.0, HwIn := hwIn, Cfg := cfg, Calib := calib);
    ADVANCE_TIME(600000000);
    fb(Enable := TRUE, HomingPermit := TRUE, HomingAtTargetM := FALSE,
       CfgHomingTargetM := 1.0, HwIn := hwIn, Cfg := cfg, Calib := calib);
    ASSERT_TRUE(fb.Homed, 'STATUSBIT_ONLY : bit TRUE -> validation');
END_TEST

TEST 'TC-P09-015 Reset conscient : acquitte le latch sans valider le preset'
    hwIn.SlaveOperational := TRUE;
    hwIn.RawPosIn := 100000;
    hwIn.PresetStatusBit := FALSE;
    cfg.PresetConfirmMode := E_PresetConfirmMode.READBACK_ONLY;
    calib.Homed := FALSE;
    calib.HomingSuspect := FALSE;
    calib.HomingRefRaw := 9999;
    calib.LastKnownRawPos := 100000;

    (* Echec de relecture : preset non confirme -> latch pose. *)
    fb(Enable := TRUE, HomingPermit := TRUE, HomingAtTargetM := TRUE,
       CfgHomingTargetM := 1.0, HwIn := hwIn, Cfg := cfg, Calib := calib);
    hwIn.RawPosIn := 100205; (* +50mm -> hors tolerance *)
    ADVANCE_TIME(600000000);
    fb(Enable := TRUE, HomingPermit := TRUE, HomingAtTargetM := FALSE,
       CfgHomingTargetM := 1.0, HwIn := hwIn, Cfg := cfg, Calib := calib);
    ASSERT_TRUE(fb.PresetConfirmationFailed, 'echec : latch pose');
    ASSERT_FALSE(fb.Homed, 'echec : pas de validation');

    (* Reset front : acquitte le latch, ne valide pas le preset (Homed reste FALSE). *)
    fb(Enable := TRUE, Reset := TRUE, HomingPermit := TRUE,
       HwIn := hwIn, Cfg := cfg, Calib := calib);
    ASSERT_FALSE(fb.PresetConfirmationFailed, 'Reset : latch acquitte');
    ASSERT_FALSE(fb.Homed, 'Reset : ne valide pas le preset');
END_TEST

TEST 'TC-P09-016 Fault live : perte materiel codeur (Cause 0)'
    hwIn.SlaveOperational := FALSE;
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);
    ASSERT_TRUE(fb.Fault.Error, 'perte materiel -> Fault.Error live');
    ASSERT_TRUE((fb.Fault.ErrorId AND 16#0001) <> 0, 'bit0 = cause perte materiel');
    ASSERT_FALSE(fb.Fault.Latched, 'cause live non latchee');

    hwIn.SlaveOperational := TRUE;
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);
    ASSERT_FALSE(fb.Fault.Error, 'cause disparue -> Error retombe seule');
END_TEST

TEST 'TC-P09-017 Fault latched : echec preset + acquittement Reset (Cause 2)'
    hwIn.SlaveOperational := TRUE;
    hwIn.RawPosIn := 100000;
    hwIn.PresetStatusBit := FALSE;
    cfg.PresetConfirmMode := E_PresetConfirmMode.READBACK_ONLY;
    calib.Homed := TRUE;
    calib.HomingSuspect := FALSE;
    calib.HomingRefRaw := 70000;
    calib.LastKnownRawPos := 100000;

    (* Echec de relecture : preset non confirme -> latch pose. *)
    fb(Enable := TRUE, HomingPermit := TRUE, HomingAtTargetM := TRUE,
       CfgHomingTargetM := 1.0, HwIn := hwIn, Cfg := cfg, Calib := calib);
    hwIn.RawPosIn := 100205; (* +50mm -> hors tolerance *)
    ADVANCE_TIME(600000000);
    fb(Enable := TRUE, HomingPermit := TRUE, HomingAtTargetM := FALSE,
       CfgHomingTargetM := 1.0, HwIn := hwIn, Cfg := cfg, Calib := calib);
    ASSERT_TRUE(fb.PresetConfirmationFailed, 'echec : latch preset pose');
    ASSERT_TRUE(fb.Fault.Latched, 'echec preset -> Fault.Latched');
    ASSERT_TRUE((fb.Fault.LatchedId AND 16#0004) <> 0, 'bit2 = cause preset latched');

    (* Reset front : acquitte le latch. *)
    fb(Enable := TRUE, Reset := TRUE, HomingPermit := TRUE,
       HwIn := hwIn, Cfg := cfg, Calib := calib);
    ASSERT_FALSE(fb.Fault.Latched, 'Reset -> latch acquitte');
END_TEST

TEST 'TC-P09-018 Fault live : incoherence mesure (Cause 1)'
    hwIn.SlaveOperational := TRUE;
    hwIn.RawPosIn := 100000;
    calib.Homed := TRUE;
    calib.HomingSuspect := TRUE;  (* -> Safety.EncoderIncoherent -> Cause 1 *)
    calib.HomingRefRaw := 70000;

    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);
    ASSERT_TRUE(fb.Fault.Error, 'incoherence -> Fault.Error live');
    ASSERT_TRUE((fb.Fault.ErrorId AND 16#0002) <> 0, 'bit1 = cause incoherence');
    ASSERT_FALSE(fb.Fault.Latched, 'cause live non latchee');
END_TEST

TEST 'TC-P09-050 Mesure de vitesse : filtrage fenetre glissante 50ms et robustesse aux perturbations dynamiques (elasticite cable et vibrations)'
    (* 1. Initialisation chaine codeur *)
    hwIn.SlaveOperational := TRUE;
    hwIn.PresetStatusBit := FALSE;
    hwIn.RawPosIn := 100000;
    calib.Homed := TRUE;
    calib.HomingSuspect := FALSE;
    calib.HomingRefRaw := 100000;
    calib.LastKnownRawPos := 100000;

    (* 🎯 Repos initial (Position = 0.0 m, Fenêtre vide) *)
    fb(Enable := TRUE, Reset := FALSE, PointsPerRev := 4096, CableM_PerRev := 0.5,
       PositionMinM := -50.0, PositionMaxM := 50.0, HwIn := hwIn, Calib := calib);
    ASSERT_FALSE(fb.Measurement.SpeedValid, 'Echantillon 1 : Fenetre 50ms pas encore remplie');

    (* 🚀 Montée idéale (+15 mm / 10 ms) — Remplissage 1/5 *)
    ADVANCE_TIME(10000000);
    hwIn.RawPosIn := 100123;
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);

    (* 🚀 Montée idéale (+15 mm / 10 ms) — Remplissage 2/5 *)
    ADVANCE_TIME(10000000);
    hwIn.RawPosIn := 100246;
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);

    (* 🚀 Montée idéale (+15 mm / 10 ms) — Remplissage 3/5 *)
    ADVANCE_TIME(10000000);
    hwIn.RawPosIn := 100369;
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);

    (* 🚀 Montée idéale (+15 mm / 10 ms) — Remplissage 4/5 *)
    ADVANCE_TIME(10000000);
    hwIn.RawPosIn := 100492;
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);

    (* 🚀 50 ms atteintes ➔ Fenêtre pleine & Validée *)
    ADVANCE_TIME(10000000);
    hwIn.RawPosIn := 100614;
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);
    ASSERT_TRUE(fb.Measurement.SpeedValid, '50ms atteintes -> SpeedValid=TRUE');
    ASSERT_NEAR(fb.Measurement.Speed_Mps, 1.50, 0.05, 'Vitesse nominale filtree = 1.50 m/s');
    ASSERT_NEAR(fb.Measurement.SignedSpeed_Mps, 1.50, 0.05, 'Vitesse signee montee = +1.50 m/s');

    (* 🎯 Palier vitesse nominale stabilisée à 1.50 m/s *)
    ADVANCE_TIME(10000000);
    hwIn.RawPosIn := 100737;
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);
    ASSERT_NEAR(fb.Measurement.Speed_Mps, 1.50, 0.05, 'Palier stable 1.50 m/s');

    (* 🎯 Palier vitesse nominale stabilisée à 1.50 m/s *)
    ADVANCE_TIME(10000000);
    hwIn.RawPosIn := 100860;
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);
    ASSERT_NEAR(fb.Measurement.Speed_Mps, 1.50, 0.05, 'Palier stable 1.50 m/s');

    (* 🌊 Ondulation câble (+11 mm au lieu de +15 mm) *)
    ADVANCE_TIME(10000000);
    hwIn.RawPosIn := 100950;
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);

    (* 🌊 Ondulation câble (+19 mm au lieu de +15 mm) *)
    ADVANCE_TIME(10000000);
    hwIn.RawPosIn := 101106;
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);

    (* 🌊 V_inst saute à 1.80 m/s ➔ Mesure stabilisée à 1.500 m/s *)
    ADVANCE_TIME(10000000);
    hwIn.RawPosIn := 101253;
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);
    ASSERT_NEAR(fb.Measurement.Speed_Mps, 1.50, 0.10, 'Pic neutralise');

    (* 🌊 V_inst chute à 1.30 m/s ➔ Mesure amortie à 1.460 m/s *)
    ADVANCE_TIME(10000000);
    hwIn.RawPosIn := 101360;
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);

    (* 🌊 V_inst saute à 1.70 m/s ➔ Mesure amortie à 1.580 m/s *)
    ADVANCE_TIME(10000000);
    hwIn.RawPosIn := 101499;
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);

    (* 🌊 V_inst chute à 1.10 m/s ➔ Mesure amortie à 1.420 m/s *)
    ADVANCE_TIME(10000000);
    hwIn.RawPosIn := 101589;
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);

    (* 🌊 V_inst bondit à 1.90 m/s ➔ Mesure amortie à 1.560 m/s *)
    ADVANCE_TIME(10000000);
    hwIn.RawPosIn := 101745;
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);
    ASSERT_NEAR(fb.Measurement.Speed_Mps, 1.50, 0.10, 'Ondulations absorbees');

    (* 🎯 Retour régime stable (1.50 m/s) *)
    ADVANCE_TIME(10000000);
    hwIn.RawPosIn := 101868;
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);

    (* 🎯 Palier nominal stabilisé (1.50 m/s) *)
    ADVANCE_TIME(10000000);
    hwIn.RawPosIn := 101983;
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);

    (* 🎯 Palier nominal stabilisé (1.50 m/s) *)
    ADVANCE_TIME(10000000);
    hwIn.RawPosIn := 102114;
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);

    (* 🚀 Sursaut mécanique (+24 mm) amorti par le filtre ! *)
    ADVANCE_TIME(10000000);
    hwIn.RawPosIn := 102311;
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);

    (* ⚡ Régime 2.00 m/s perturbé (+18 mm) *)
    ADVANCE_TIME(10000000);
    hwIn.RawPosIn := 102458;
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);

    (* ⚡ Régime 2.00 m/s perturbé (+22 mm) *)
    ADVANCE_TIME(10000000);
    hwIn.RawPosIn := 102638;
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);

    (* ⚡ Régime 2.00 m/s perturbé (+19 mm) *)
    ADVANCE_TIME(10000000);
    hwIn.RawPosIn := 102794;
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);

    (* ⚡ Régime 2.00 m/s stabilisé (2.00 m/s) *)
    ADVANCE_TIME(10000000);
    hwIn.RawPosIn := 102966;
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);
    ASSERT_NEAR(fb.Measurement.Speed_Mps, 2.00, 0.15, 'Regime 2.00 m/s');

    (* 🛑 Arrêt mécanique sec (frein serré) *)
    ADVANCE_TIME(10000000);
    hwIn.RawPosIn := 102991;
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);

    (* 🛑 Rebond élastique câble arrière (-2 mm) absorbé ! *)
    ADVANCE_TIME(10000000);
    hwIn.RawPosIn := 102975;
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);

    (* 🛑 Stabilisation finale (+2 mm) *)
    ADVANCE_TIME(10000000);
    hwIn.RawPosIn := 102991;
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);

    (* 🛑 Immobilisation treuil (vidage de la fenêtre 50 ms) *)
    ADVANCE_TIME(10000000);
    hwIn.RawPosIn := 102991;
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);

    (* 🛑 Immobilisation treuil (vidage de la fenêtre 50 ms) *)
    ADVANCE_TIME(10000000);
    hwIn.RawPosIn := 102991;
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);

    (* 🛑 Arrêt complet stabilisé à 0.000 m/s *)
    ADVANCE_TIME(10000000);
    hwIn.RawPosIn := 102991;
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);
    ASSERT_EQ(fb.Measurement.Speed_Mps, 0.0, 'Arret complet = 0.0 m/s');

    (* 📉 Inversion de sens : Début descente treuil (-15 mm) *)
    ADVANCE_TIME(10000000);
    hwIn.RawPosIn := 102868;
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);

    (* 📉 Descente treuil (-1.50 m/s) *)
    ADVANCE_TIME(10000000);
    hwIn.RawPosIn := 102745;
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);

    (* 📉 Descente treuil (-1.50 m/s) *)
    ADVANCE_TIME(10000000);
    hwIn.RawPosIn := 102622;
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);

    (* 📉 Descente treuil (-1.50 m/s) *)
    ADVANCE_TIME(10000000);
    hwIn.RawPosIn := 102499;
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);

    (* 📉 Descente stabilisée à -1.50 m/s (SignedSpeed négatif) *)
    ADVANCE_TIME(10000000);
    hwIn.RawPosIn := 102376;
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);
    ASSERT_NEAR(fb.Measurement.Speed_Mps, 1.50, 0.05, 'Descente nominale 1.50 m/s');
    ASSERT_TRUE(fb.Measurement.SignedSpeed_Mps < 0.0, 'Descente : SignedSpeed negatif');

    (* ⚡ Rupture bus terrain ➔ Purge atomique de sécurité *)
    hwIn.SlaveOperational := FALSE;
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);
    ASSERT_FALSE(fb.Measurement.SpeedValid, 'Perte bus -> SpeedValid retombe immediatement a FALSE');
    ASSERT_EQ(fb.Measurement.Speed_Mps, 0.0, 'Purge vitesse -> Speed_Mps=0.0');
    ASSERT_EQ(fb.Measurement.SignedSpeed_Mps, 0.0, 'Purge vitesse signee -> SignedSpeed_Mps=0.0');
END_TEST

(* =========================================================================
   Lot CI AF-09 : TC-P09-010.x (Abs), TC-P09-020.x (Homing), TC-P09-030.x
   (Scale/Safety), TC-P09-040.x (Reliability), TC-P09-050.x (Speed).
   Definitions : fiches DOC/AF/AF_Partie-09_Fonction_Encoder/*.md §2.
   ========================================================================= *)

TEST 'TC-P09-010.1 Abs gel sur doute : perte bus -> EncoderAvailable=FALSE, RawPos gele'
    hwIn.SlaveOperational := TRUE;
    hwIn.RawPosIn := 100000;
    calib.Homed := TRUE;
    calib.HomingSuspect := FALSE;
    calib.HomingRefRaw := 100000;
    calib.LastKnownRawPos := 100000;

    (* acquisition nominale *)
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);
    ASSERT_TRUE(fb.Measurement.EncoderAvailable, 'bus OK -> EncoderAvailable=TRUE');
    ASSERT_EQ(fb.Measurement.RawPos, 100000, 'RawPos=RawPosIn');

    (* perte bus -> EncoderAvailable=FALSE, RawPos gele (derniere valeur) *)
    hwIn.SlaveOperational := FALSE;
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);
    ASSERT_FALSE(fb.Measurement.EncoderAvailable, 'perte bus -> EncoderAvailable=FALSE');
    ASSERT_EQ(fb.Measurement.RawPos, 100000, 'RawPos gele (derniere valeur, pas de retour a 0)');

    (* retour bus -> EncoderAvailable=TRUE, RawPos relu *)
    hwIn.SlaveOperational := TRUE;
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);
    ASSERT_TRUE(fb.Measurement.EncoderAvailable, 'retour bus -> EncoderAvailable=TRUE');
END_TEST

TEST 'TC-P09-010.3 Abs acquisition nominale : bus OK -> RawPos=RawPosIn, EncoderAvailable'
    hwIn.SlaveOperational := TRUE;
    hwIn.RawPosIn := 100000;
    calib.Homed := TRUE;
    calib.HomingSuspect := FALSE;
    calib.HomingRefRaw := 100000;
    calib.LastKnownRawPos := 100000;

    fb(Enable := TRUE, PointsPerRev := 8192, HwIn := hwIn, Calib := calib);
    ASSERT_TRUE(fb.Measurement.EncoderAvailable, 'bus OK -> EncoderAvailable=TRUE');
    ASSERT_EQ(fb.Measurement.RawPos, 100000, 'RawPos=RawPosIn (FB_Encoder_Abs.st:116-120)');
END_TEST

TEST 'TC-P09-010.4 Abs preset : front PresetRequest -> PresetTriggerCmd=2'
    hwIn.SlaveOperational := TRUE;
    hwIn.RawPosIn := 100000;
    calib.Homed := FALSE;
    calib.HomingSuspect := FALSE;
    calib.HomingRefRaw := 0;
    calib.LastKnownRawPos := 0;
    cfg.PresetConfirmMode := E_PresetConfirmMode.READBACK_ONLY;

    (* front Home + permit -> homing declenche, PresetRequest pulse vers Abs *)
    fb(Enable := TRUE, HomingPermit := TRUE, HomingAtTargetM := TRUE,
       CfgHomingTargetM := 1.0, HwIn := hwIn, Cfg := cfg, Calib := calib);
    (* scan 2 : Abs voit le front PresetRequest -> PresetSeqStep=1 (PresetTriggerCmd encore 0) *)
    fb(Enable := TRUE, HomingPermit := TRUE, HomingAtTargetM := FALSE,
       CfgHomingTargetM := 1.0, HwIn := hwIn, Cfg := cfg, Calib := calib);
    (* scan 3 : Abs en etape 1 -> PresetTriggerCmd=2 *)
    fb(Enable := TRUE, HomingPermit := TRUE, HomingAtTargetM := FALSE,
       CfgHomingTargetM := 1.0, HwIn := hwIn, Cfg := cfg, Calib := calib);
    ASSERT_EQ(fb.HwOut.PresetTriggerCmd, 2, 'front PresetRequest + EncoderAvailable -> PresetTriggerCmd=2 (FB_Encoder_Abs.st:128,134)');
END_TEST

TEST 'TC-P09-020 Homing : sequence nominale complete (front Home + capteur haut) -> Homed'
    hwIn.SlaveOperational := TRUE;
    hwIn.RawPosIn := 100000;
    calib.Homed := FALSE;
    calib.HomingSuspect := FALSE;
    calib.HomingRefRaw := 0;
    calib.LastKnownRawPos := 0;
    cfg.PresetConfirmMode := E_PresetConfirmMode.READBACK_ONLY;

    (* front Home + front TopPositionSensor (nominal) -> homing declenche *)
    fb(Enable := TRUE, HomingPermit := TRUE, HomingAtTargetM := TRUE,
       TopPositionSensor := TRUE, CfgTopSensorPosM := 8.5, HwIn := hwIn, Cfg := cfg, Calib := calib);
    ASSERT_FALSE(fb.Homed, 'homing en cours : pas encore Homed');
    ADVANCE_TIME(600000000);
    fb(Enable := TRUE, HomingPermit := TRUE, HomingAtTargetM := FALSE,
       TopPositionSensor := TRUE, CfgTopSensorPosM := 8.5, HwIn := hwIn, Cfg := cfg, Calib := calib);
    ASSERT_TRUE(fb.Homed, 'homing nominal reussi -> Homed=TRUE');
    ASSERT_FALSE(fb.HomingSuspect, 'homing nominal : pas de suspicion');
END_TEST

TEST 'TC-P09-020.1 Homing nominal : front Home + capteur haut -> cible CfgTopSensorPosM'
    hwIn.SlaveOperational := TRUE;
    hwIn.RawPosIn := 100000;
    calib.Homed := FALSE;
    calib.HomingSuspect := FALSE;
    calib.HomingRefRaw := 0;
    calib.LastKnownRawPos := 0;
    cfg.PresetConfirmMode := E_PresetConfirmMode.READBACK_ONLY;

    (* front Home pendant que le capteur haut est deja actif -> homing nominal *)
    fb(Enable := TRUE, HomingPermit := TRUE, HomingAtTargetM := TRUE,
       TopPositionSensor := TRUE, CfgTopSensorPosM := 8.5, HwIn := hwIn, Cfg := cfg, Calib := calib);
    ADVANCE_TIME(600000000);
    fb(Enable := TRUE, HomingPermit := TRUE, HomingAtTargetM := FALSE,
       TopPositionSensor := TRUE, CfgTopSensorPosM := 8.5, HwIn := hwIn, Cfg := cfg, Calib := calib);
    ASSERT_TRUE(fb.Homed, 'homing nominal (capteur haut) -> Homed=TRUE');
    ASSERT_NEAR(fb.Measurement.CablePosM, 8.5, 0.01, 'position cable = CfgTopSensorPosM (8.5m)');
END_TEST

TEST 'TC-P09-020.2 Homing unitaire : front Home seul -> cible CfgHomingTargetM'
    hwIn.SlaveOperational := TRUE;
    hwIn.RawPosIn := 100000;
    calib.Homed := FALSE;
    calib.HomingSuspect := FALSE;
    calib.HomingRefRaw := 0;
    calib.LastKnownRawPos := 0;
    cfg.PresetConfirmMode := E_PresetConfirmMode.READBACK_ONLY;

    (* front Home seul (pas de capteur) -> homing unitaire vers CfgHomingTargetM *)
    fb(Enable := TRUE, HomingPermit := TRUE, HomingAtTargetM := TRUE,
       CfgHomingTargetM := 1.0, HwIn := hwIn, Cfg := cfg, Calib := calib);
    ADVANCE_TIME(600000000);
    fb(Enable := TRUE, HomingPermit := TRUE, HomingAtTargetM := FALSE,
       CfgHomingTargetM := 1.0, HwIn := hwIn, Cfg := cfg, Calib := calib);
    ASSERT_TRUE(fb.Homed, 'homing unitaire reussi -> Homed=TRUE');
    ASSERT_NEAR(fb.Measurement.CablePosM, 1.0, 0.01, 'position cable = CfgHomingTargetM (1.0m)');
END_TEST

TEST 'T198-001 Commande BtnHome : cible haute explicite meme sans capteur'
    hwIn.SlaveOperational := TRUE;
    hwIn.RawPosIn := 100000;
    calib.Homed := FALSE;
    calib.HomingSuspect := FALSE;
    calib.HomingRefRaw := 0;
    calib.LastKnownRawPos := 0;
    cfg.PresetConfirmMode := E_PresetConfirmMode.READBACK_ONLY;

    (* PRG_02 transmet CfgTopSensorPos_M comme cible libre de BtnHome. *)
    fb(Enable := TRUE, HomingPermit := TRUE, HomingAtTargetM := TRUE,
       TopPositionSensor := FALSE, CfgHomingTargetM := 8.5,
       CfgTopSensorPosM := 8.5, HwIn := hwIn, Cfg := cfg, Calib := calib);
    ADVANCE_TIME(600000000);
    fb(Enable := TRUE, HomingPermit := TRUE, HomingAtTargetM := FALSE,
       TopPositionSensor := FALSE, CfgHomingTargetM := 8.5,
       CfgTopSensorPosM := 8.5, HwIn := hwIn, Cfg := cfg, Calib := calib);
    ASSERT_TRUE(fb.Homed, 'BtnHome : homing reussi');
    ASSERT_NEAR(fb.Measurement.CablePosM, 8.5, 0.01,
                'BtnHome sans capteur conserve la cible 8.5m');
END_TEST

TEST 'T198-002 Commande BtnHomingAtZero : cible zero explicite'
    hwIn.SlaveOperational := TRUE;
    hwIn.RawPosIn := 100000;
    calib.Homed := FALSE;
    calib.HomingSuspect := FALSE;
    calib.HomingRefRaw := 0;
    calib.LastKnownRawPos := 0;
    cfg.PresetConfirmMode := E_PresetConfirmMode.READBACK_ONLY;

    (* PRG_02 inclut BtnHomingAtZero dans Home et transmet la cible 0.0m. *)
    fb(Enable := TRUE, HomingPermit := TRUE, HomingAtTargetM := TRUE,
       TopPositionSensor := FALSE, CfgHomingTargetM := 0.0,
       CfgTopSensorPosM := 0.0, HwIn := hwIn, Cfg := cfg, Calib := calib);
    ADVANCE_TIME(600000000);
    fb(Enable := TRUE, HomingPermit := TRUE, HomingAtTargetM := FALSE,
       TopPositionSensor := FALSE, CfgHomingTargetM := 0.0,
       CfgTopSensorPosM := 0.0, HwIn := hwIn, Cfg := cfg, Calib := calib);
    ASSERT_TRUE(fb.Homed, 'BtnHomingAtZero : homing reussi');
    ASSERT_NEAR(fb.Measurement.CablePosM, 0.0, 0.01,
                'BtnHomingAtZero reference exactement 0m');
END_TEST

TEST 'TC-P09-020.3 Homing dynamique : front UseDynamicTarget -> cible DynamicHomingTargetM'
    hwIn.SlaveOperational := TRUE;
    hwIn.RawPosIn := 100000;
    calib.Homed := FALSE;
    calib.HomingSuspect := FALSE;
    calib.HomingRefRaw := 0;
    calib.LastKnownRawPos := 0;
    cfg.PresetConfirmMode := E_PresetConfirmMode.READBACK_ONLY;

    (* front UseDynamicTarget -> homing dynamique vers DynamicHomingTargetM *)
    fb(Enable := TRUE, HomingPermit := TRUE, UseDynamicTarget := TRUE,
       DynamicHomingTargetM := 2.0, HwIn := hwIn, Cfg := cfg, Calib := calib);
    ADVANCE_TIME(600000000);
    fb(Enable := TRUE, HomingPermit := TRUE, UseDynamicTarget := TRUE,
       DynamicHomingTargetM := 2.0, HwIn := hwIn, Cfg := cfg, Calib := calib);
    ASSERT_TRUE(fb.Homed, 'homing dynamique reussi -> Homed=TRUE');
    ASSERT_NEAR(fb.Measurement.CablePosM, 2.0, 0.01, 'position cable = DynamicHomingTargetM (2.0m)');
END_TEST

TEST 'TC-P09-020.4 Homing cible hors plage : cible > 99m -> refuse, pas d ecriture'
    hwIn.SlaveOperational := TRUE;
    hwIn.RawPosIn := 100000;
    calib.Homed := FALSE;
    calib.HomingSuspect := FALSE;
    calib.HomingRefRaw := 0;
    calib.LastKnownRawPos := 0;
    cfg.PresetConfirmMode := E_PresetConfirmMode.READBACK_ONLY;

    (* front Home avec cible 150m (> 99) -> TargetOutOfRangeError (latch pose en §4) *)
    fb(Enable := TRUE, HomingPermit := TRUE, HomingAtTargetM := TRUE,
       CfgHomingTargetM := 150.0, HwIn := hwIn, Cfg := cfg, Calib := calib);
    (* scan suivant : le socle instFault (§1) voit le latch -> Error leve *)
    fb(Enable := TRUE, HomingPermit := TRUE, HomingAtTargetM := FALSE,
       CfgHomingTargetM := 150.0, HwIn := hwIn, Cfg := cfg, Calib := calib);
    ASSERT_TRUE(fb.Measurement.HomingFault.Error, 'cible hors plage -> Error leve');
    (* NB : la fiche dit bit4, le code FB_Encoder_Homing.st:140-142 utilise instCauses[1] -> bit1 *)
    ASSERT_TRUE((fb.Measurement.HomingFault.ErrorId AND 16#0002) <> 0, 'bit1 : cible hors plage (code)');
    ASSERT_FALSE(fb.Homed, 'pas de referencement (cible hors plage)');
END_TEST

TEST 'TC-P09-020.5 Coherence boot : ecart RawPos/LastKnown > tolerance -> HomingSuspect, leve par ConfirmCoherence+Permit'
    hwIn.SlaveOperational := TRUE;
    hwIn.RawPosIn := 100000;
    calib.Homed := TRUE;
    calib.HomingSuspect := FALSE;
    calib.HomingRefRaw := 100000;
    calib.LastKnownRawPos := 50000;  (* ecart 50000 > tolerance 1000 *)

    (* premier scan Enable : coherence boot detecte l ecart -> HomingSuspect=TRUE, Homed=FALSE *)
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);
    ASSERT_TRUE(fb.HomingSuspect, 'ecart boot > tolerance -> HomingSuspect=TRUE');
    ASSERT_FALSE(fb.Homed, 'Homed=FALSE tant que suspect');

    (* re-injecte l etat suspect (IN_OUT non round-trip) puis front ConfirmCoherence + permit -> leve *)
    calib.HomingSuspect := TRUE;
    fb(Enable := TRUE, ConfirmCoherence := TRUE, HomingPermit := TRUE, HwIn := hwIn, Calib := calib);
    ASSERT_FALSE(fb.HomingSuspect, 'front ConfirmCoherence + permit -> HomingSuspect=FALSE');
    ASSERT_TRUE(fb.Homed, 'Homed=TRUE apres confirmation');
END_TEST

TEST 'TC-P09-020.6 Capteur haut absent : mode nominal ne declenche pas, seul unitaire/dynamique'
    hwIn.SlaveOperational := TRUE;
    hwIn.RawPosIn := 100000;
    calib.Homed := FALSE;
    calib.HomingSuspect := FALSE;
    calib.HomingRefRaw := 0;
    calib.LastKnownRawPos := 0;
    cfg.PresetConfirmMode := E_PresetConfirmMode.READBACK_ONLY;

    (* front Home SANS capteur haut -> homing unitaire declenche (nominal exige le capteur) *)
    fb(Enable := TRUE, HomingPermit := TRUE, HomingAtTargetM := TRUE,
       TopPositionSensor := FALSE, CfgTopSensorPosM := 8.5, HwIn := hwIn, Cfg := cfg, Calib := calib);
    ADVANCE_TIME(600000000);
    fb(Enable := TRUE, HomingPermit := TRUE, HomingAtTargetM := FALSE,
       TopPositionSensor := FALSE, CfgTopSensorPosM := 8.5, HwIn := hwIn, Cfg := cfg, Calib := calib);
    ASSERT_TRUE(fb.Homed, 'sans capteur haut : homing unitaire declenche (nominal exige le capteur, FB_Encoder_Homing.st:206-207)');
END_TEST

TEST 'TC-P09-020.7 Homing sans permit : front Home sans HomingPermit -> HomingModeError, pas d ecriture'
    hwIn.SlaveOperational := TRUE;
    hwIn.RawPosIn := 100000;
    calib.Homed := FALSE;
    calib.HomingSuspect := FALSE;
    calib.HomingRefRaw := 0;
    calib.LastKnownRawPos := 0;
    cfg.PresetConfirmMode := E_PresetConfirmMode.READBACK_ONLY;

    (* front Home SANS HomingPermit -> HomingModeError (latch pose en §4) *)
    fb(Enable := TRUE, HomingPermit := FALSE, HomingAtTargetM := TRUE,
       CfgHomingTargetM := 1.0, HwIn := hwIn, Cfg := cfg, Calib := calib);
    (* scan suivant : le socle instFault (§1) voit le latch -> Error leve *)
    fb(Enable := TRUE, HomingPermit := FALSE, HomingAtTargetM := FALSE,
       CfgHomingTargetM := 1.0, HwIn := hwIn, Cfg := cfg, Calib := calib);
    ASSERT_TRUE(fb.Measurement.HomingFault.Error, 'homing sans permit -> Error leve');
    ASSERT_TRUE((fb.Measurement.HomingFault.ErrorId AND 16#0001) <> 0, 'bit0 : HomingModeError');
    ASSERT_FALSE(fb.Homed, 'pas de referencement sans permit');
END_TEST

TEST 'TC-P09-020.8 HomingSuspect RETAIN : stocke dans Calib -> persiste (FB_Encoder_Homing.st:185)'
    hwIn.SlaveOperational := TRUE;
    hwIn.RawPosIn := 100000;
    calib.Homed := TRUE;
    calib.HomingSuspect := TRUE;  (* etat RETAIN suspect *)
    calib.HomingRefRaw := 100000;
    calib.LastKnownRawPos := 100000;

    (* FB active : HomingSuspect RETAIN est expose tel quel *)
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);
    ASSERT_TRUE(fb.HomingSuspect, 'HomingSuspect RETAIN expose');
    ASSERT_FALSE(fb.Homed, 'Homed=FALSE tant que suspect RETAIN');
END_TEST

TEST 'TC-P09-030.1 Scale : RawPos=HomingRefRaw+4096 (1/2 tour) -> CablePosM=1.0'
    hwIn.SlaveOperational := TRUE;
    hwIn.RawPosIn := 100000;
    calib.Homed := TRUE;
    calib.HomingSuspect := FALSE;
    calib.HomingRefRaw := 95904;  (* RawPos - 4096 *)
    calib.LastKnownRawPos := 100000;

    fb(Enable := TRUE, PointsPerRev := 8192, CableM_PerRev := 2.0, HwIn := hwIn, Calib := calib);
    ASSERT_NEAR(fb.Measurement.CablePosM, 1.0, 0.001, 'RawPos=HomingRefRaw+4096, 2.0m/tour, 8192pts -> CablePosM=1.0');
END_TEST

TEST 'TC-P09-030.2 Scale : RawPos < HomingRefRaw -> CablePosM negative (sous l eau)'
    hwIn.SlaveOperational := TRUE;
    hwIn.RawPosIn := 100000;
    calib.Homed := TRUE;
    calib.HomingSuspect := FALSE;
    calib.HomingRefRaw := 110000;  (* RawPos < HomingRefRaw *)
    calib.LastKnownRawPos := 100000;

    fb(Enable := TRUE, PointsPerRev := 8192, CableM_PerRev := 2.0, HwIn := hwIn, Calib := calib);
    ASSERT_TRUE(fb.Measurement.CablePosM < 0.0, 'RawPos < HomingRefRaw -> CablePosM negative');
END_TEST

(* TC-P09-030.3 (PointsPerRev=0 -> CablePosM=0.0) NON TESTABLE via la facade FB_Encoder :
   PointsPerRev=0 declenche RawPos MOD 0 / RawPos / 0 dans FB_Encoder_Abs (instAbs) ->
   division par zero, crash du binaire (STATUS_INTEGER_DIVIDE_BY_ZERO). La garde de
   FB_Encoder_Scale (IF PointsPerRev > 0) n est pas atteignable sans faire planter Abs.
   A tester en boite blanche sur FB_Encoder_Scale seul (hors harnais facade). *)

TEST 'TC-P09-030.4 Safety bornage : CablePosM hors [Min;Max] -> EncoderIncoherent, auto-efface'
    hwIn.SlaveOperational := TRUE;
    hwIn.RawPosIn := 100000;
    calib.Homed := TRUE;
    calib.HomingSuspect := FALSE;
    calib.HomingRefRaw := 0;  (* CablePosM = 100000*2/8192 = 24.4m, dans plage *)
    calib.LastKnownRawPos := 100000;

    (* position dans plage -> pas incoherent *)
    fb(Enable := TRUE, PositionMinM := -99.0, PositionMaxM := 99.0, HwIn := hwIn, Calib := calib);
    ASSERT_FALSE(fb.Measurement.EncoderIncoherent, 'CablePosM dans plage -> pas incoherent');

    (* position hors plage haute -> incoherent *)
    hwIn.RawPosIn := 500000;  (* CablePosM = 500000*2/8192 = 122m > 99 *)
    fb(Enable := TRUE, PositionMinM := -99.0, PositionMaxM := 99.0, HwIn := hwIn, Calib := calib);
    ASSERT_TRUE(fb.Measurement.EncoderIncoherent, 'CablePosM > Max -> EncoderIncoherent=TRUE');
    ASSERT_TRUE(fb.Fault.Error, 'hors bornage -> Error leve');
    ASSERT_TRUE((fb.Fault.ErrorId AND 16#0002) <> 0, 'bit1 : incoherence (facade)');

    (* retour en plage -> auto-efface *)
    hwIn.RawPosIn := 100000;
    fb(Enable := TRUE, PositionMinM := -99.0, PositionMaxM := 99.0, HwIn := hwIn, Calib := calib);
    ASSERT_FALSE(fb.Measurement.EncoderIncoherent, 'retour en plage -> auto-efface');
END_TEST

TEST 'TC-P09-030.5 Safety HomingSuspect : HomingSuspect=TRUE -> EncoderIncoherent, tant que non confirme'
    hwIn.SlaveOperational := TRUE;
    hwIn.RawPosIn := 100000;
    calib.Homed := TRUE;
    calib.HomingSuspect := TRUE;  (* suspect -> Safety bit1 *)
    calib.HomingRefRaw := 100000;
    calib.LastKnownRawPos := 100000;

    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);
    ASSERT_TRUE(fb.Measurement.EncoderIncoherent, 'HomingSuspect=TRUE -> EncoderIncoherent=TRUE');
    ASSERT_TRUE((fb.Fault.ErrorId AND 16#0002) <> 0, 'bit1 : incoherence (facade)');
END_TEST

TEST 'TC-P09-030.6 Safety BypassGlobal : TRUE neutralise bornage+coherence, retour FALSE -> causes reactives'
    hwIn.SlaveOperational := TRUE;
    hwIn.RawPosIn := 500000;  (* CablePosM = 122m > 99 -> hors bornage *)
    calib.Homed := TRUE;
    calib.HomingSuspect := TRUE;  (* suspect -> coherence *)
    calib.HomingRefRaw := 0;
    calib.LastKnownRawPos := 100000;

    (* BypassGlobal=TRUE -> neutralise les 2 causes *)
    fb(Enable := TRUE, BypassGlobal := TRUE, HwIn := hwIn, Calib := calib);
    ASSERT_FALSE(fb.Measurement.EncoderIncoherent, 'BypassGlobal=TRUE -> pas incoherent');

    (* retour BypassGlobal=FALSE -> causes reactives au scan suivant *)
    fb(Enable := TRUE, BypassGlobal := FALSE, HwIn := hwIn, Calib := calib);
    ASSERT_TRUE(fb.Measurement.EncoderIncoherent, 'BypassGlobal=FALSE -> incoherent reactif');
END_TEST

TEST 'TC-P09-030.7 Safety CablePosMSafe : = CablePosM toujours (jamais gelee)'
    hwIn.SlaveOperational := TRUE;
    hwIn.RawPosIn := 100000;
    calib.Homed := TRUE;
    calib.HomingSuspect := FALSE;
    calib.HomingRefRaw := 95904;
    calib.LastKnownRawPos := 100000;

    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);
    ASSERT_NEAR(fb.Measurement.CablePosMSafe, 1.0, 0.001, 'CablePosMSafe = CablePosM (1.0)');
    ASSERT_NEAR(fb.Measurement.CablePosM, fb.Measurement.CablePosMSafe, 0.001, 'CablePosMSafe = CablePosM toujours');
END_TEST

TEST 'TC-P09-030.8 Scale garde DINT : conversion DINT avant soustraction -> pas de depassement'
    hwIn.SlaveOperational := TRUE;
    hwIn.RawPosIn := 0;
    calib.Homed := TRUE;
    calib.HomingSuspect := FALSE;
    calib.HomingRefRaw := 100000;
    calib.LastKnownRawPos := 0;

    fb(Enable := TRUE, PointsPerRev := 8192, CableM_PerRev := 2.0, HwIn := hwIn, Calib := calib);
    (* RawDiff = DINT(0) - DINT(100000) = -100000 (signe, pas de sous-debordement UDINT) *)
    ASSERT_TRUE(fb.Measurement.CablePosM < 0.0, 'soustraction DINT signee : CablePosM negative, pas de depassement');
END_TEST

TEST 'TC-P09-030.9 Scale : RawPos=HomingRefRaw -> CablePosM=0.0'
    hwIn.SlaveOperational := TRUE;
    hwIn.RawPosIn := 100000;
    calib.Homed := TRUE;
    calib.HomingSuspect := FALSE;
    calib.HomingRefRaw := 100000;
    calib.LastKnownRawPos := 100000;

    fb(Enable := TRUE, PointsPerRev := 8192, CableM_PerRev := 2.0, HwIn := hwIn, Calib := calib);
    ASSERT_EQ(fb.Measurement.CablePosM, 0.0, 'RawPos=HomingRefRaw -> CablePosM=0.0');
END_TEST

TEST 'TC-P09-040.1 Reliability : EncoderAvailable=TRUE, Homed=FALSE, Incoherent=FALSE -> EncoderFault=FALSE'
    hwIn.SlaveOperational := TRUE;
    hwIn.RawPosIn := 100000;
    calib.Homed := FALSE;
    calib.HomingSuspect := FALSE;
    calib.HomingRefRaw := 100000;
    calib.LastKnownRawPos := 100000;

    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);
    ASSERT_FALSE(fb.EncoderFault, 'non-reference != incoherent : EncoderFault=FALSE');
END_TEST

TEST 'TC-P09-040.2 Reliability : meme cas -> HomedAndReliable=FALSE (gate stricte exige Homed)'
    hwIn.SlaveOperational := TRUE;
    hwIn.RawPosIn := 100000;
    calib.Homed := FALSE;
    calib.HomingSuspect := FALSE;
    calib.HomingRefRaw := 100000;
    calib.LastKnownRawPos := 100000;

    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);
    ASSERT_FALSE(fb.HomedAndReliable, 'gate stricte exige Homed : HomedAndReliable=FALSE');
END_TEST

TEST 'TC-P09-040.3 Reliability : EncoderAvailable=FALSE -> EncoderFault=TRUE quel que soit Homed'
    hwIn.SlaveOperational := FALSE;
    hwIn.RawPosIn := 100000;
    calib.Homed := TRUE;
    calib.HomingSuspect := FALSE;
    calib.HomingRefRaw := 100000;
    calib.LastKnownRawPos := 100000;

    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);
    ASSERT_TRUE(fb.EncoderFault, 'EncoderAvailable=FALSE -> EncoderFault=TRUE');
    ASSERT_FALSE(fb.HomedAndReliable, 'HomedAndReliable=FALSE');
END_TEST

TEST 'TC-P09-040.4 Reliability : table de verite des 2 gates sur 8 combos'
    (* Combo 1 : A=T, H=T, I=F -> EF=F, HAR=T *)
    hwIn.SlaveOperational := TRUE; hwIn.RawPosIn := 100000;
    calib.Homed := TRUE; calib.HomingSuspect := FALSE; calib.HomingRefRaw := 100000; calib.LastKnownRawPos := 100000;
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);
    ASSERT_FALSE(fb.EncoderFault, 'A=T,H=T,I=F : EncoderFault=FALSE');
    ASSERT_TRUE(fb.HomedAndReliable, 'A=T,H=T,I=F : HomedAndReliable=TRUE');

    (* Combo 2 : A=T, H=F, I=F -> EF=F, HAR=F *)
    calib.Homed := FALSE;
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);
    ASSERT_FALSE(fb.EncoderFault, 'A=T,H=F,I=F : EncoderFault=FALSE');
    ASSERT_FALSE(fb.HomedAndReliable, 'A=T,H=F,I=F : HomedAndReliable=FALSE');

    (* Combo 3 : A=T, H=T, I=T (bornage) -> EF=T, HAR=F *)
    calib.Homed := TRUE; calib.HomingRefRaw := 0; hwIn.RawPosIn := 500000;  (* CablePosM=122m > 99 -> incoherent *)
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);
    ASSERT_TRUE(fb.EncoderFault, 'A=T,H=T,I=T : EncoderFault=TRUE');
    ASSERT_FALSE(fb.HomedAndReliable, 'A=T,H=T,I=T : HomedAndReliable=FALSE');

    (* Combo 4 : A=T, H=F, I=T -> EF=T, HAR=F *)
    calib.Homed := FALSE; calib.HomingRefRaw := 0;
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);
    ASSERT_TRUE(fb.EncoderFault, 'A=T,H=F,I=T : EncoderFault=TRUE');
    ASSERT_FALSE(fb.HomedAndReliable, 'A=T,H=F,I=T : HomedAndReliable=FALSE');

    (* Combo 5 : A=F, H=T, I=F -> EF=T, HAR=F *)
    hwIn.SlaveOperational := FALSE; hwIn.RawPosIn := 100000;
    calib.Homed := TRUE; calib.HomingSuspect := FALSE; calib.HomingRefRaw := 100000; calib.LastKnownRawPos := 100000;
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);
    ASSERT_TRUE(fb.EncoderFault, 'A=F,H=T,I=F : EncoderFault=TRUE');
    ASSERT_FALSE(fb.HomedAndReliable, 'A=F,H=T,I=F : HomedAndReliable=FALSE');

    (* Combo 6 : A=F, H=F, I=F -> EF=T, HAR=F *)
    calib.Homed := FALSE;
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);
    ASSERT_TRUE(fb.EncoderFault, 'A=F,H=F,I=F : EncoderFault=TRUE');
    ASSERT_FALSE(fb.HomedAndReliable, 'A=F,H=F,I=F : HomedAndReliable=FALSE');

    (* Combo 7 : A=F, H=T, I=T -> EF=T, HAR=F *)
    hwIn.RawPosIn := 500000; calib.Homed := TRUE; calib.HomingSuspect := FALSE; calib.HomingRefRaw := 0;
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);
    ASSERT_TRUE(fb.EncoderFault, 'A=F,H=T,I=T : EncoderFault=TRUE');
    ASSERT_FALSE(fb.HomedAndReliable, 'A=F,H=T,I=T : HomedAndReliable=FALSE');

    (* Combo 8 : A=F, H=F, I=T -> EF=T, HAR=F *)
    calib.Homed := FALSE; calib.HomingRefRaw := 0;
    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);
    ASSERT_TRUE(fb.EncoderFault, 'A=F,H=F,I=T : EncoderFault=TRUE');
    ASSERT_FALSE(fb.HomedAndReliable, 'A=F,H=F,I=T : HomedAndReliable=FALSE');
END_TEST

TEST 'TC-P09-040.5 Reliability : EncoderIncoherent -> EncoderFault=TRUE et HomedAndReliable=FALSE'
    hwIn.SlaveOperational := TRUE;
    hwIn.RawPosIn := 500000;  (* CablePosM=122m > 99 -> incoherent *)
    calib.Homed := TRUE;
    calib.HomingSuspect := FALSE;
    calib.HomingRefRaw := 0;
    calib.LastKnownRawPos := 100000;

    fb(Enable := TRUE, HwIn := hwIn, Calib := calib);
    ASSERT_TRUE(fb.EncoderFault, 'EncoderIncoherent -> EncoderFault=TRUE');
    ASSERT_FALSE(fb.HomedAndReliable, 'EncoderIncoherent -> HomedAndReliable=FALSE');
END_TEST

TEST 'TC-P09-050.5 Speed : fenetre <50ms -> Valid=FALSE sans purge (essai SITE - stub logique)'
    (* La fenetre glissante exige 6 echantillons espaces de SamplePeriod (10ms) -> la fenetre
       minimale pour 6 echantillons est exactement 50ms. Le cas "fenetre <50ms" (Valid=FALSE sans
       purge, FB_Encoder_SpeedMeasure.st:128-132) n est pas atteignable avec la config par defaut
       (SamplePeriod=10ms) : la branche ne se prend jamais. Invariant minimal : a 50ms exactement,
       Valid=TRUE (borne). *)
    hwIn.SlaveOperational := TRUE;
    hwIn.RawPosIn := 100000;
    calib.Homed := TRUE;
    calib.HomingSuspect := FALSE;
    calib.HomingRefRaw := 100000;
    calib.LastKnownRawPos := 100000;

    fb(Enable := TRUE, PointsPerRev := 4096, CableM_PerRev := 0.5, HwIn := hwIn, Calib := calib);
    ADVANCE_TIME(10000000); hwIn.RawPosIn := 100123; fb(Enable := TRUE, HwIn := hwIn, Calib := calib);
    ADVANCE_TIME(10000000); hwIn.RawPosIn := 100246; fb(Enable := TRUE, HwIn := hwIn, Calib := calib);
    ADVANCE_TIME(10000000); hwIn.RawPosIn := 100369; fb(Enable := TRUE, HwIn := hwIn, Calib := calib);
    ADVANCE_TIME(10000000); hwIn.RawPosIn := 100492; fb(Enable := TRUE, HwIn := hwIn, Calib := calib);
    ADVANCE_TIME(10000000); hwIn.RawPosIn := 100614; fb(Enable := TRUE, HwIn := hwIn, Calib := calib);
    ASSERT_TRUE(fb.Measurement.SpeedValid, 'borne : 6 ech. sur 50ms -> Valid=TRUE');
END_TEST

TEST 'TC-P09-050.6 Speed : SignedSpeed=(P[5]-P[0])/WindowElapsed, Speed=ABS'
    hwIn.SlaveOperational := TRUE;
    hwIn.RawPosIn := 100000;
    calib.Homed := TRUE;
    calib.HomingSuspect := FALSE;
    calib.HomingRefRaw := 100000;
    calib.LastKnownRawPos := 100000;

    (* montee +15mm/10ms -> 1.50 m/s *)
    fb(Enable := TRUE, PointsPerRev := 4096, CableM_PerRev := 0.5, HwIn := hwIn, Calib := calib);
    ADVANCE_TIME(10000000); hwIn.RawPosIn := 100123; fb(Enable := TRUE, HwIn := hwIn, Calib := calib);
    ADVANCE_TIME(10000000); hwIn.RawPosIn := 100246; fb(Enable := TRUE, HwIn := hwIn, Calib := calib);
    ADVANCE_TIME(10000000); hwIn.RawPosIn := 100369; fb(Enable := TRUE, HwIn := hwIn, Calib := calib);
    ADVANCE_TIME(10000000); hwIn.RawPosIn := 100492; fb(Enable := TRUE, HwIn := hwIn, Calib := calib);
    ADVANCE_TIME(10000000); hwIn.RawPosIn := 100614; fb(Enable := TRUE, HwIn := hwIn, Calib := calib);
    ASSERT_NEAR(fb.Measurement.Speed_Mps, 1.50, 0.05, 'SignedSpeed=(P[5]-P[0])/0.05 = 1.50 m/s');
    ASSERT_NEAR(fb.Measurement.SignedSpeed_Mps, 1.50, 0.05, 'SignedSpeed positive (montee)');
    ASSERT_EQ(fb.Measurement.Speed_Mps, fb.Measurement.SignedSpeed_Mps, 'Speed=ABS(SignedSpeed)');
END_TEST
