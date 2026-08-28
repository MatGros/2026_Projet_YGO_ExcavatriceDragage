SETUP
VAR
    fb : FB_Encoder_SpeedMeasure;
END_VAR
END_SETUP

TEST 'TC-T084-001 Mesure dynamique 1.0 m/s et 2.0 m/s sur fenetre glissante 50ms'
    (* Scan 0 : Neutralisation initiale *)
    fb(Enable := FALSE, Reset := FALSE, Position_M := 0.0, PositionValid := FALSE);
    ASSERT_FALSE(fb.Valid, 'Enable=FALSE -> Valid=FALSE');
    ASSERT_EQ(fb.Speed_Mps, 0.0, 'Enable=FALSE -> Speed=0');

    ADVANCE_TIME(10000000); (* +10 ms *)

    (* Scan 1 (t=10ms) : Activation et premier echantillon a 0.0 m *)
    fb(Enable := TRUE, Reset := FALSE, Position_M := 0.0, PositionValid := TRUE);
    ASSERT_FALSE(fb.Valid, 'Echantillon 1 : Fenetre 50ms pas encore remplie');

    ADVANCE_TIME(10000000); (* +10 ms (t=20ms) *)

    (* Scan 2 (t=20ms) : Deplacement a v=1.0 m/s -> pos = 0.01 m (+10mm en 10ms) *)
    fb(Enable := TRUE, Reset := FALSE, Position_M := 0.01, PositionValid := TRUE);
    ASSERT_FALSE(fb.Valid, 'Echantillon 2 : Fenetre 50ms pas encore remplie');

    ADVANCE_TIME(10000000); (* +10 ms (t=30ms) *)

    (* Scan 3 (t=30ms) : pos = 0.02 m *)
    fb(Enable := TRUE, Reset := FALSE, Position_M := 0.02, PositionValid := TRUE);
    ASSERT_FALSE(fb.Valid, 'Echantillon 3 : Fenetre 50ms pas encore remplie');

    ADVANCE_TIME(10000000); (* +10 ms (t=40ms) *)

    (* Scan 4 (t=40ms) : pos = 0.03 m *)
    fb(Enable := TRUE, Reset := FALSE, Position_M := 0.03, PositionValid := TRUE);
    ASSERT_FALSE(fb.Valid, 'Echantillon 4 : Fenetre 50ms pas encore remplie');

    ADVANCE_TIME(10000000); (* +10 ms (t=50ms) *)

    (* Scan 5 (t=50ms) : pos = 0.04 m *)
    fb(Enable := TRUE, Reset := FALSE, Position_M := 0.04, PositionValid := TRUE);
    ASSERT_FALSE(fb.Valid, 'Echantillon 5 : Fenetre 50ms pas encore remplie');

    ADVANCE_TIME(10000000); (* +10 ms (t=60ms) *)

    (* Scan 6 (t=60ms) : pos = 0.05 m -> 6 echantillons couvrant 50ms (t=10ms a t=60ms) *)
    fb(Enable := TRUE, Reset := FALSE, Position_M := 0.05, PositionValid := TRUE);
    ASSERT_TRUE(fb.Valid, '6 echantillons sur 50ms atteints -> Valid=TRUE');
    ASSERT_NEAR(fb.Speed_Mps, 1.0, 0.05, 'Vitesse absolue mesuree = 1.0 m/s');
    ASSERT_NEAR(fb.SignedSpeed_Mps, 1.0, 0.05, 'Vitesse signee montee = +1.0 m/s');

    ADVANCE_TIME(10000000); (* +10 ms (t=70ms) *)

    (* Scan 7 (t=70ms) : Acceleration a 2.0 m/s (+20mm en 10ms) -> pos = 0.07 m *)
    fb(Enable := TRUE, Reset := FALSE, Position_M := 0.07, PositionValid := TRUE);
    ASSERT_TRUE(fb.Valid, 'Fenetre glissante active');
    ASSERT_NEAR(fb.Speed_Mps, 1.2, 0.05, 'Transition glissante vers 2.0 m/s (pos 0.07 - pos 0.01 = 0.06m / 50ms = 1.2 m/s)');

    ADVANCE_TIME(10000000); (* +10 ms (t=80ms) *)

    (* Scan 8 (t=80ms) : Suite a 2.0 m/s -> pos = 0.09 m *)
    fb(Enable := TRUE, Reset := FALSE, Position_M := 0.09, PositionValid := TRUE);
    ASSERT_TRUE(fb.Valid, 'Fenetre glissante active');
    ASSERT_NEAR(fb.Speed_Mps, 1.4, 0.05, 'Transition glissante vers 2.0 m/s (pos 0.09 - pos 0.02 = 0.07m / 50ms = 1.4 m/s)');

    ADVANCE_TIME(10000000); (* +10 ms (t=90ms) *)

    (* Scan 9 (t=90ms) : Descente a -2.0 m/s (-20mm en 10ms) -> pos = 0.07 m *)
    fb(Enable := TRUE, Reset := FALSE, Position_M := 0.07, PositionValid := TRUE);
    ASSERT_TRUE(fb.Valid, 'Fenetre glissante active');

    ADVANCE_TIME(10000000); (* +10 ms (t=100ms) *)

    (* Scan 10 (t=100ms) : Coupure PositionValid=FALSE -> Purge immediate *)
    fb(Enable := TRUE, Reset := FALSE, Position_M := 0.07, PositionValid := FALSE);
    ASSERT_FALSE(fb.Valid, 'Rupture confiance PositionValid=FALSE -> Valid retombe immediatement a FALSE');
    ASSERT_EQ(fb.Speed_Mps, 0.0, 'Purge immediate -> Speed=0.0');
    ASSERT_EQ(fb.SignedSpeed_Mps, 0.0, 'Purge immediate -> SignedSpeed=0.0');
END_TEST
