(* =======================================================================
   test_fb_winchdirectioninterlock.st — T181-18 D11 : macro TC FB_WinchDirectionInterlock
   ======================================================================= *)

SETUP
VAR
    fb : FB_WinchDirectionInterlock;
END_VAR
END_SETUP

TEST 'TC-P10-T181-18a Premier sens depuis le neutre : adoption immediate'
    fb(Enable := TRUE, EnableRising := FALSE, Reset := FALSE, ReqDirection := 1, ChangeDelayUp := T#900ms, ChangeDelayDown := T#400ms);
    ASSERT_EQ(fb.CommandedDirection, 1, 'Adoption immediate du premier sens');
    ASSERT_FALSE(fb.DirectionChangePending, 'Pas de pending');
END_TEST

TEST 'TC-P10-T181-18b Reprise du meme sens apres neutre : immediate'
    fb(Enable := TRUE, EnableRising := FALSE, Reset := FALSE, ReqDirection := 1, ChangeDelayUp := T#900ms, ChangeDelayDown := T#400ms);
    fb(Enable := TRUE, EnableRising := FALSE, Reset := FALSE, ReqDirection := 0, ChangeDelayUp := T#900ms, ChangeDelayDown := T#400ms);
    ASSERT_EQ(fb.CommandedDirection, 0, 'Retour au neutre');
    fb(Enable := TRUE, EnableRising := FALSE, Reset := FALSE, ReqDirection := 1, ChangeDelayUp := T#900ms, ChangeDelayDown := T#400ms);
    ASSERT_EQ(fb.CommandedDirection, 1, 'Reprise du meme sens : immediate');
    ASSERT_FALSE(fb.DirectionChangePending, 'Pas de pending');
END_TEST

TEST 'TC-P10-T181-18c Reprise du sens oppose : adoption seulement apres le delai'
    fb(Enable := TRUE, EnableRising := FALSE, Reset := FALSE, ReqDirection := 1, ChangeDelayUp := T#900ms, ChangeDelayDown := T#400ms);
    fb(Enable := TRUE, EnableRising := FALSE, Reset := FALSE, ReqDirection := 0, ChangeDelayUp := T#900ms, ChangeDelayDown := T#400ms);
    fb(Enable := TRUE, EnableRising := FALSE, Reset := FALSE, ReqDirection := -1, ChangeDelayUp := T#900ms, ChangeDelayDown := T#400ms);
    ASSERT_EQ(fb.CommandedDirection, 0, 'Pas encore adopte (pending)');
    ASSERT_TRUE(fb.DirectionChangePending, 'Pending actif avant le delai');
    ADVANCE_TIME(400000000);
    fb(Enable := TRUE, EnableRising := FALSE, Reset := FALSE, ReqDirection := -1, ChangeDelayUp := T#900ms, ChangeDelayDown := T#400ms);
    ASSERT_EQ(fb.CommandedDirection, -1, 'Sens oppose adopte apres ChangeDelayDown');
    ASSERT_FALSE(fb.DirectionChangePending, 'Pending termine');
END_TEST

TEST 'TC-P10-T181-18d ReqDirection=0 force le neutre'
    fb(Enable := TRUE, EnableRising := FALSE, Reset := FALSE, ReqDirection := 1, ChangeDelayUp := T#900ms, ChangeDelayDown := T#400ms);
    fb(Enable := TRUE, EnableRising := FALSE, Reset := FALSE, ReqDirection := 0, ChangeDelayUp := T#900ms, ChangeDelayDown := T#400ms);
    ASSERT_EQ(fb.CommandedDirection, 0, 'Neutre commande');
    ASSERT_FALSE(fb.DirectionChangePending, 'Pas de pending au neutre');
END_TEST
