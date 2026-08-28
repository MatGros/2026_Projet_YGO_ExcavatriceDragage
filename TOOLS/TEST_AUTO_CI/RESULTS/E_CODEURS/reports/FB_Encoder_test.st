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

