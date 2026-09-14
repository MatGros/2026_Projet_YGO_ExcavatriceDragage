SETUP
VAR
    fb : FB_Brake;
END_VAR
END_SETUP

TEST 'BASELINE FB_Brake : maintien, ouverture, fermeture, neutralisation'
    fb(Enable := TRUE, Reset := FALSE, MovementRequested := TRUE,
       ContactorFeedback := FALSE, BypassContactorCheck := TRUE,
       DelayContactClose := T#100ms, DelayMagnetise := T#300ms,
       DelayMotorDecel := T#500ms, FeedbackTimeout := T#1s);
    ASSERT_FALSE(fb.BrakeCmd, 'T0 : frein colle');
    ADVANCE_TIME(300000000);
    fb(Enable := TRUE, Reset := FALSE, MovementRequested := TRUE,
       ContactorFeedback := FALSE, BypassContactorCheck := TRUE,
       DelayContactClose := T#100ms, DelayMagnetise := T#300ms,
       DelayMotorDecel := T#500ms, FeedbackTimeout := T#1s);
    ASSERT_FALSE(fb.BrakeCmd, 'T300ms : frein encore colle');
    ADVANCE_TIME(99000000);
    fb(Enable := TRUE, Reset := FALSE, MovementRequested := TRUE,
       ContactorFeedback := FALSE, BypassContactorCheck := TRUE,
       DelayContactClose := T#100ms, DelayMagnetise := T#300ms,
       DelayMotorDecel := T#500ms, FeedbackTimeout := T#1s);
    ASSERT_FALSE(fb.BrakeCmd, 'T399ms : seuil non atteint');
    ADVANCE_TIME(2000000);
    fb(Enable := TRUE, Reset := FALSE, MovementRequested := TRUE,
       ContactorFeedback := FALSE, BypassContactorCheck := TRUE,
       DelayContactClose := T#100ms, DelayMagnetise := T#300ms,
       DelayMotorDecel := T#500ms, FeedbackTimeout := T#1s);
    ASSERT_TRUE(fb.BrakeCmd, 'T401ms : frein relache');
    ASSERT_TRUE(fb.BrakeCommandOpenConfirmed, 'T401ms : ouverture confirmee');
    fb(Enable := TRUE, Reset := FALSE, MovementRequested := FALSE,
       ContactorFeedback := FALSE, BypassContactorCheck := TRUE,
       DelayContactClose := T#100ms, DelayMagnetise := T#300ms,
       DelayMotorDecel := T#500ms, FeedbackTimeout := T#1s);
    ASSERT_FALSE(fb.BrakeCmd, 'Arret : frein colle immediatement');
    ASSERT_TRUE(fb.Ready, 'Arret : FB reste pret');
    fb(Enable := FALSE, Reset := FALSE, MovementRequested := FALSE,
       ContactorFeedback := FALSE, BypassContactorCheck := TRUE,
       DelayContactClose := T#100ms, DelayMagnetise := T#300ms,
       DelayMotorDecel := T#500ms, FeedbackTimeout := T#1s);
    ASSERT_FALSE(fb.Ready, 'Enable FALSE : FB neutralise');
END_TEST
