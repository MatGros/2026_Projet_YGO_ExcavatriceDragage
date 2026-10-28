Revue independante read-only, automaticien expert simulation/dynamique pragmatique. Ne propose aucun code a appliquer directement : orchestrateur seul implemente. Pas de recherche ou outils disponibles ici : fonde ton avis sur le code fourni. Contrat : mecanique identique manuel/auto, deceleration pilotee par variateur apres mot0, balancement conserve secondaire, frein suit bobine finale meme fermeture anticipee, aucune distance de depassement cible. Patch unique = supprimer inversion numerique du frottement. Avant patch 8/9 scenarios PASS, seul v+.004 avec mu.1 et dt.1 donne -.006 au lieu arret. Aprespatch9/9PASS sur STreel STruCpp, pas copie Python. Verifie notamment test des deux sens100ms, adherence repos limite, inversion reelle sous pente opposee. Pas exiger calibration terrain indisponible ni refonteCI. Rend en francais <250mots verdict PASS/BLOCK/MAJOR/MINOR avec justification 3pointsmax. Si preuve manque, la nommer sans inventer resultat. Le preambule systeme est injecte automatiquement par runner.

DIFF REEL
diff --git a/CODE/L_SIMULATION/FB_Sim_Translation.st b/CODE/L_SIMULATION/FB_Sim_Translation.st
index 7e0a0c85..9466aedc 100644
--- a/CODE/L_SIMULATION/FB_Sim_Translation.st
+++ b/CODE/L_SIMULATION/FB_Sim_Translation.st
@@ -137,6 +137,8 @@ VAR
     ObsSpeedBeforeStop_Mps : REAL;      (* Vitesse du scan avant le calcul de butee *)
     DriveTorqueActive : BOOL;           (* L4 : variateur commande ou encore en rampe -> chariot tenu *)
     FreeAccel_Mps2 : REAL;              (* L4 : acceleration nette du chariot libre *)
+    FreeVelocity_Mps : REAL;            (* . [LOC] Vitesse apres poussee, avant frottement, m/s *)
+    FrictionStep_Mps : REAL;            (* . [LOC] Impulsion dissipative de frottement sur le pas, m/s *)
     FreeRollStart_M : REAL;             (* L4 : position au debut de l'episode libre *)
     instCycleTime : FB_CycleTime;
     Initialized : BOOL;
@@ -302,22 +304,15 @@ IF Enable THEN
         (* Pendule sur chariot libre : x'' = m_benne / m_chariot x g x theta = r / (1 - r) x g x theta. *)
         FreeAccel_Mps2 := (LIMIT(0.0, LoadMassRatio, 0.9) / (1.0 - LIMIT(0.0, LoadMassRatio, 0.9)))
                           * 9.81 * instSuspendedLoad.Angle_Rad + Slope_Mps2;
-        IF ABS(VelocityTrue_Mps) < 0.001 THEN
-            (* Adherence : ne repart que si la poussee depasse le frottement. *)
-            IF ABS(FreeAccel_Mps2) <= MAX(0.0, RollingFriction_Mps2) THEN
-                FreeAccel_Mps2 := 0.0;
-                VelocityTrue_Mps := 0.0;
-            ELSIF FreeAccel_Mps2 > 0.0 THEN
-                FreeAccel_Mps2 := FreeAccel_Mps2 - MAX(0.0, RollingFriction_Mps2);
-            ELSE
-                FreeAccel_Mps2 := FreeAccel_Mps2 + MAX(0.0, RollingFriction_Mps2);
-            END_IF;
-        ELSIF VelocityTrue_Mps > 0.0 THEN
-            FreeAccel_Mps2 := FreeAccel_Mps2 - MAX(0.0, RollingFriction_Mps2);
+        (* La poussee peut inverser le mouvement ; le frottement ne peut que le dissiper.
+           Au repos, une poussee inferieure au frottement conserve l'adherence. *)
+        FreeVelocity_Mps := VelocityTrue_Mps + FreeAccel_Mps2 * CycleTimeS;
+        FrictionStep_Mps := MAX(0.0, RollingFriction_Mps2) * CycleTimeS;
+        IF FreeVelocity_Mps > 0.0 THEN
+            VelocityTrue_Mps := MAX(0.0, FreeVelocity_Mps - FrictionStep_Mps);
         ELSE
-            FreeAccel_Mps2 := FreeAccel_Mps2 + MAX(0.0, RollingFriction_Mps2);
+            VelocityTrue_Mps := MIN(0.0, FreeVelocity_Mps + FrictionStep_Mps);
         END_IF;
-        VelocityTrue_Mps := VelocityTrue_Mps + FreeAccel_Mps2 * CycleTimeS;
     ELSIF BrakeMechanicallyOpen THEN
         VelocityTrue_Mps := VelocityTrue_Mps + instDrive.ResponseAlpha * (VelocityTarget_Mps - VelocityTrue_Mps);
     ELSIF BrakePhysicalActive THEN

CODE ACTUEL
236:     Initialized := TRUE;
237:     PositionTrue_M := PosP1_M;
238:     TravelDirection := 0.0;
239: END_IF;
240: 
241: IF Enable THEN
242:     DirectionSign := 0.0;
243:     IF ReqTremie AND NOT ReqMaintenance THEN
244:         DirectionSign := -1.0;
245:     ELSIF ReqMaintenance AND NOT ReqTremie THEN
246:         DirectionSign := 1.0;
247:     END_IF;
248: 
249:     FrequencyTarget_Hz := LIMIT(0.0, ABS(SpeedTgt_Pct) * MaxFreq_Hz / 100.0, MaxFreq_Hz);
250:     IF DirectionSign = 0.0 THEN
251:         FrequencyTarget_Hz := 0.0;
252:     END_IF;
253:     instDrive(Enable := TRUE, FrequencyTgt_Hz := FrequencyTarget_Hz,
254:         AccelRate_HzPerS := AccelRate_HzPerS, DecelRate_HzPerS := DecelRate_HzPerS,
255:         TimeConstant_S := DriveTimeConstantS,
256:         LoadAngularVelocity_RadPerS := instSuspendedLoad.AngularVelocity_RadPerS,
257:         LoadFrequencyDroopGain_Hz := LoadFrequencyDroopGain_Hz, CycleTime_S := CycleTimeS);
258:     FrequencyCmd_Hz := instDrive.FrequencyCmd_Hz;
259:     ElectricalFrequency_Hz := instDrive.ElectricalFrequency_Hz;
260:     SpeedFactorApplied := LIMIT(1.0, SpeedFactor, 5.0);
261:     ActualFrequency_Hz := instDrive.ActualFrequency_Hz * SpeedFactorApplied;
262:     instBrake(Enable := TRUE, ReleaseCmd := BrakeReleaseCmd,
263:         ActualFrequency_Hz := instDrive.ActualFrequency_Hz, OpenDelay_S := BrakeOpenDelayS,
264:         CloseDelay_S := BrakeCloseDelayS, ContactDelay_S := BrakeContactDelayS,
265:         CycleTime_S := CycleTimeS,
266:         FaultCloseWhileRunning := BrakeFaultCloseWhileRunning,
267:         FaultCloseDelay_S := BrakeFaultCloseDelay_S,
268:         PhysicalBrakeActive := BrakePhysicalActive);
269:     BrakeCoilEnergized := instBrake.CoilEnergized;
270:     BrakeMechanicallyOpen := instBrake.MechanicallyOpen;
271:     BrakeContactOpen := instBrake.ContactOpen;
272:     BrakeFaultCloseActive := instBrake.FaultCloseActive;
273: 
274:     (* Sens memorise (C3). Regles, dans cet ordre :
275:        1. un ordre simple valide (re)memorise le sens ;
276:        2. deux ordres contradictoires neutralisent immediatement le sens — aucune
277:           excitation inventee (preserve TC-T300-MEC-030) ;
278:        3. commande retiree : le sens est CONSERVE tant que le variateur retourne de la
279:           vitesse (deceleration libre), puis purge des que la vitesse est nulle. *)
280:     IF ReqTremie AND NOT ReqMaintenance THEN
281:         TravelDirection := -1.0;
282:     ELSIF ReqMaintenance AND NOT ReqTremie THEN
283:         TravelDirection := 1.0;
284:     ELSIF ReqTremie AND ReqMaintenance THEN
285:         TravelDirection := 0.0;
286:     ELSIF ABS(instDrive.ActualFrequency_Hz) <= CST_StopFrequency_Hz THEN
287:         TravelDirection := 0.0;
288:     END_IF;
289: 
290:     PreviousVelocity_Mps := VelocityTrue_Mps;
291:     IF BrakeMechanicallyOpen THEN
292:         (* Source unique : meme gain que l'estimateur machine (vitesse = gain x frequence). *)
293:         VelocityTarget_Mps := TravelDirection * MAX(0.0, GainMetersPerHzSec) * ActualFrequency_Hz;
294:     ELSE
295:         VelocityTarget_Mps := 0.0;
296:     END_IF;
297:     (* L4 : le variateur tient le chariot tant qu'il est commande ou que sa SORTIE electrique
298:        alimente encore le moteur (rampe + reponse) ; ensuite, plus aucun couple.
299:        Reprise de commande en roue libre : pas de reprise a la volee (le variateur repart de 0 Hz). *)
300:     DriveTorqueActive := (DirectionSign <> 0.0) OR (instDrive.ElectricalFrequency_Hz > CST_StopFrequency_Hz);
301:     ObsCartFree := CartFreeActive AND BrakeMechanicallyOpen AND NOT DriveTorqueActive;
302:     IF ObsCartFree THEN
303:         (* Poussee de la benne (angle du scan precedent) + pente - frottement oppose au mouvement. *)
304:         (* Pendule sur chariot libre : x'' = m_benne / m_chariot x g x theta = r / (1 - r) x g x theta. *)
305:         FreeAccel_Mps2 := (LIMIT(0.0, LoadMassRatio, 0.9) / (1.0 - LIMIT(0.0, LoadMassRatio, 0.9)))
306:                           * 9.81 * instSuspendedLoad.Angle_Rad + Slope_Mps2;
307:         (* La poussee peut inverser le mouvement ; le frottement ne peut que le dissiper.
308:            Au repos, une poussee inferieure au frottement conserve l'adherence. *)
309:         FreeVelocity_Mps := VelocityTrue_Mps + FreeAccel_Mps2 * CycleTimeS;
310:         FrictionStep_Mps := MAX(0.0, RollingFriction_Mps2) * CycleTimeS;
311:         IF FreeVelocity_Mps > 0.0 THEN
312:             VelocityTrue_Mps := MAX(0.0, FreeVelocity_Mps - FrictionStep_Mps);
313:         ELSE
314:             VelocityTrue_Mps := MIN(0.0, FreeVelocity_Mps + FrictionStep_Mps);
315:         END_IF;
316:     ELSIF BrakeMechanicallyOpen THEN
317:         VelocityTrue_Mps := VelocityTrue_Mps + instDrive.ResponseAlpha * (VelocityTarget_Mps - VelocityTrue_Mps);
318:     ELSIF BrakePhysicalActive THEN
319:         (* L3 : frein serre -> deceleration sur le frein jusqu'a l'arret, puis chariot bloque. *)
320:         IF VelocityTrue_Mps > 0.0 THEN
321:             VelocityTrue_Mps := MAX(0.0, VelocityTrue_Mps - MAX(0.0, BrakeDecel_Mps2) * CycleTimeS);
322:         ELSE
323:             VelocityTrue_Mps := MIN(0.0, VelocityTrue_Mps + MAX(0.0, BrakeDecel_Mps2) * CycleTimeS);
324:         END_IF;
325:     ELSE
326:         VelocityTrue_Mps := 0.0;   (* historique : arret instantane *)
327:     END_IF;
328:     ObsSpeedBeforeStop_Mps := VelocityTrue_Mps;
329:     HardStopTremieActive := FALSE;
330:     HardStopMaintenanceActive := FALSE;
331:     PositionCandidate_M := PositionTrue_M + VelocityTrue_Mps * CycleTimeS;
332:     IF PositionCandidate_M < EndStopTremie_M THEN
333:         PositionTrue_M := EndStopTremie_M;
334:         VelocityTrue_Mps := 0.0;
335:         HardStopTremieActive := TRUE;
336:     ELSIF PositionCandidate_M > EndStopMaintenance_M THEN
337:         PositionTrue_M := EndStopMaintenance_M;
338:         VelocityTrue_Mps := 0.0;
339:         HardStopMaintenanceActive := TRUE;
340:     END_IF;
341:     CartAcceleration_Mps2 := (VelocityTrue_Mps - PreviousVelocity_Mps) / CycleTimeS;
342:     instSuspendedLoad(Enable := TRUE, BrakeMechanicallyOpen := BrakeMechanicallyOpen,
343:         CartAcceleration_Mps2 := CartAcceleration_Mps2, Length_M := SuspendedLoadLength_M,
344:         Damping := SuspendedLoadDamping, ReactionGain_Mps2 := LoadReactionGain_Mps2,
345:         CycleTime_S := CycleTimeS);
346:     LoadAngle_Rad := instSuspendedLoad.Angle_Rad;
347:     IF HardStopTremieActive OR HardStopMaintenanceActive THEN
348:         RecoilMax_M := MIN(MAX(0.0, EndStopRecoilMax_M), EndStopMaintenance_M - EndStopTremie_M);
349:         IF (RecoilMax_M > 0.0) AND BrakeMechanicallyOpen THEN
350:             (* Recul autorise UNIQUEMENT en s'eloignant de la butee touchee, borne par
351:                EndStopRecoilMax_M : jamais plus loin dans la butee, jamais de saut cache. *)
352:             VelocityTrue_Mps := VelocityTrue_Mps + instSuspendedLoad.VelocityReaction_Mps;
353:             (* Contre une butee, l'entrainement DECROCHE : il ne maintient pas une consigne de
354:                vitesse dans l'obstacle. Sans cette purge, la consigne de vitesse ecrasait en
355:                permanence la reaction de charge et le chariot ne pouvait jamais ressortir de
356:                la zone capteur (recul alors impossible, quelle que soit la charge). *)
357:             TravelDirection := 0.0;
358:             IF HardStopTremieActive THEN
359:                 VelocityTrue_Mps := MAX(0.0, VelocityTrue_Mps);
360:                 PositionCandidate_M := LIMIT(EndStopTremie_M,
361:                     PositionTrue_M + VelocityTrue_Mps * CycleTimeS,
362:                     EndStopTremie_M + RecoilMax_M);
363:             ELSE
364:                 VelocityTrue_Mps := MIN(0.0, VelocityTrue_Mps);
365:                 PositionCandidate_M := LIMIT(EndStopMaintenance_M - RecoilMax_M,
366:                     PositionTrue_M + VelocityTrue_Mps * CycleTimeS,
367:                     EndStopMaintenance_M);
368:             END_IF;
369:             PositionTrue_M := PositionCandidate_M;
370:         ELSE
371:             VelocityTrue_Mps := 0.0;
372:         END_IF;
373:     ELSE
374:         IF NOT ObsCartFree THEN
375:             (* Reaction historique (negligeable) ; en mode libre la poussee est deja integree (L4). *)
376:             VelocityTrue_Mps := VelocityTrue_Mps + instSuspendedLoad.VelocityReaction_Mps;
377:         END_IF;
378:         PositionCandidate_M := PositionTrue_M + VelocityTrue_Mps * CycleTimeS;
379:         IF PositionCandidate_M < EndStopTremie_M THEN
380:             PositionTrue_M := EndStopTremie_M;
381:             VelocityTrue_Mps := 0.0;
382:             HardStopTremieActive := TRUE;
383:         ELSIF PositionCandidate_M > EndStopMaintenance_M THEN
384:             PositionTrue_M := EndStopMaintenance_M;
385:             VelocityTrue_Mps := 0.0;
386:             HardStopMaintenanceActive := TRUE;
387:         ELSE
388:             PositionTrue_M := PositionCandidate_M;
389:         END_IF;
390:     END_IF;
SCENARIOS ST REELS
(* Scenarios fonctionnels du ST reel : aucune copie du modele mecanique. *)
SETUP
VAR
    fb : FB_Sim_Translation;
    reverse : FB_Sim_Translation;
    reference : FB_Sim_Translation;
    clockProbe : FB_CycleTime;
    sensor : FB_Sim_PositionSensor;
    frequencyBefore_Hz : REAL;
    positionBefore_M : REAL;
    peakEarly_Rad : REAL;
    peakLate_Rad : REAL;
END_VAR
    fb.Enable := FALSE;
    fb();
    fb.Enable := TRUE;
    fb.ReqMaintenance := TRUE;
    fb.SpeedTgt_Pct := 40.0;
    fb.BrakeReleaseCmd := TRUE;
    fb.BrakeOpenDelayS := 0.0;
    fb.BrakeContactDelayS := 0.0;
    fb.BrakePhysicalActive := TRUE;
    fb.CartFreeActive := TRUE;
    fb.SensorJitterAmplitude_M := 0.0;
END_SETUP

TEST 'M3-DYN-010 Retrait de commande a 20 Hz conserve la deceleration pilotee'
VAR
    i : INT;
END_VAR
    fb.LoadMassRatio := 0.0;
    fb.LoadReactionGain_Mps2 := 0.0;
    fb.LoadFrequencyDroopGain_Hz := 0.0;
    FOR i := 1 TO 250 DO
        fb();
    END_FOR;
    ASSERT_NEAR(fb.ActualFrequency_Hz, 20.0, 0.1, 'Regime etabli a 20 Hz');
    frequencyBefore_Hz := fb.ActualFrequency_Hz;
    positionBefore_M := fb.PositionTrue_M;
    fb.ReqMaintenance := FALSE;
    fb();
    ASSERT_GT(fb.ActualFrequency_Hz, 19.0, 'Le mot nul ne supprime pas le retour frequence');
    ASSERT_GT(fb.PositionTrue_M, positionBefore_M, 'Sens memorise pendant la deceleration');
    ASSERT_FALSE(fb.ObsCartFree, 'Pas de roue libre pendant la rampe variateur');
    FOR i := 1 TO 50 DO
        fb();
    END_FOR;
    ASSERT_LT(fb.ActualFrequency_Hz, frequencyBefore_Hz, 'Frequence decroissante');
    FOR i := 1 TO 300 DO
        fb();
    END_FOR;
    ASSERT_EQ(fb.ActualFrequency_Hz, 0.0, 'Rampe terminee');
    ASSERT_NEAR(fb.VelocityTrue_Mps, 0.0, 0.00001, 'Arret sans oscillation artificielle');
END_TEST

TEST 'M3-DYN-020 Retrait brutal a 50 Hz reste limite par le variateur'
VAR
    i : INT;
END_VAR
    fb.SpeedTgt_Pct := 100.0;
    fb.LoadMassRatio := 0.0;
    fb.LoadReactionGain_Mps2 := 0.0;
    fb.LoadFrequencyDroopGain_Hz := 0.0;
    FOR i := 1 TO 400 DO
        fb();
    END_FOR;
    ASSERT_NEAR(fb.ActualFrequency_Hz, 50.0, 0.1, 'Regime etabli a 50 Hz');
    fb.ReqMaintenance := FALSE;
    positionBefore_M := fb.PositionTrue_M;
    fb();
    ASSERT_GT(fb.ActualFrequency_Hz, 49.0, 'Retour conserve apres retrait');
    ASSERT_GT(fb.PositionTrue_M, positionBefore_M, 'Pas de gel de position au retrait');
    ASSERT_FALSE(fb.ObsCartFree, 'Variateur encore en deceleration');
    FOR i := 1 TO 400 DO
        fb();
    END_FOR;
    ASSERT_EQ(fb.ActualFrequency_Hz, 0.0, 'Frequence finalement nulle');
    ASSERT_NEAR(fb.VelocityTrue_Mps, 0.0, 0.00001, 'Arret final');
    ASSERT_FALSE(fb.HardStopMaintenanceActive, 'Arret observe hors butee');
END_TEST

TEST 'M3-DYN-030 Frottement seul a 100 ms sans inversion dans les deux sens'
    fb.SpeedTgt_Pct := 0.4;
    fb.DriveTimeConstantS := 0.0;
    fb.LoadMassRatio := 0.0;
    fb.LoadReactionGain_Mps2 := 0.0;
    fb.LoadFrequencyDroopGain_Hz := 0.0;
    fb();
    reverse(Enable := TRUE, ReqTremie := TRUE, SpeedTgt_Pct := 0.4,
        BrakeReleaseCmd := TRUE, BrakeOpenDelayS := 0.0, DriveTimeConstantS := 0.0,
        CartFreeActive := TRUE, LoadMassRatio := 0.0,
        LoadReactionGain_Mps2 := 0.0, LoadFrequencyDroopGain_Hz := 0.0);
    ASSERT_NEAR(fb.VelocityTrue_Mps, 0.004, 0.00001, 'Petite vitesse positive initiale');
    ASSERT_NEAR(reverse.VelocityTrue_Mps, -0.004, 0.00001, 'Petite vitesse negative initiale');
    clockProbe();
    fb.ReqMaintenance := FALSE;
    reverse.ReqTremie := FALSE;
    ADVANCE_TIME(100000000);
    clockProbe();
    ASSERT_NEAR(clockProbe.CycleTimeS, 0.1, 0.00001, 'Pas reel de 100 ms');
    fb();
    reverse();
    ASSERT_EQ(fb.VelocityTrue_Mps, 0.0, 'Frottement arrete le sens positif sans inversion');
    ASSERT_EQ(reverse.VelocityTrue_Mps, 0.0, 'Frottement arrete le sens negatif sans inversion');
    ASSERT_TRUE(fb.ObsCartFree, 'Le calcul libre est effectivement exerce');
    ADVANCE_TIME(100000000);
    fb();
    reverse();
    ASSERT_EQ(fb.VelocityTrue_Mps, 0.0, 'Pas de redemarrage numerique positif');
    ASSERT_EQ(reverse.VelocityTrue_Mps, 0.0, 'Pas de redemarrage numerique negatif');
END_TEST

TEST 'M3-DYN-040 Frottement seul a 10 ms sans inversion dans les deux sens'
    fb.SpeedTgt_Pct := 0.04;
    fb.DriveTimeConstantS := 0.0;
    fb.LoadMassRatio := 0.0;
    fb.LoadReactionGain_Mps2 := 0.0;
    fb.LoadFrequencyDroopGain_Hz := 0.0;
    fb();
    reverse(Enable := TRUE, ReqTremie := TRUE, SpeedTgt_Pct := 0.04,
        BrakeReleaseCmd := TRUE, BrakeOpenDelayS := 0.0, DriveTimeConstantS := 0.0,
        CartFreeActive := TRUE, LoadMassRatio := 0.0,
        LoadReactionGain_Mps2 := 0.0, LoadFrequencyDroopGain_Hz := 0.0);
    clockProbe();
    fb.ReqMaintenance := FALSE;
    reverse.ReqTremie := FALSE;
    ADVANCE_TIME(10000000);
    clockProbe();
    ASSERT_NEAR(clockProbe.CycleTimeS, 0.01, 0.00001, 'Pas reel de 10 ms');
    fb();
    reverse();
    ASSERT_EQ(fb.VelocityTrue_Mps, 0.0, 'Immobilite positive conservee');
    ASSERT_EQ(reverse.VelocityTrue_Mps, 0.0, 'Immobilite negative conservee');
END_TEST

TEST 'M3-DYN-050 Adherence au repos et au seuil puis depart sous poussee'
    fb.ReqMaintenance := FALSE;
    fb.LoadMassRatio := 0.0;
    fb.Slope_Mps2 := 0.05;
    fb();
    ASSERT_EQ(fb.VelocityTrue_Mps, 0.0, 'Poussee sous le frottement : immobile');
    fb.Slope_Mps2 := 0.1;
    fb();
    ASSERT_EQ(fb.VelocityTrue_Mps, 0.0, 'Poussee au seuil : immobile');
    fb.Slope_Mps2 := 0.2;
    fb();
    ASSERT_GT(fb.VelocityTrue_Mps, 0.0, 'Poussee suffisante : depart physique');
END_TEST

TEST 'M3-DYN-060 Poussee opposee suffisante autorise une vraie inversion'
    fb.SpeedTgt_Pct := 0.4;
    fb.DriveTimeConstantS := 0.0;
    fb.LoadMassRatio := 0.0;
    fb.LoadReactionGain_Mps2 := 0.0;
    fb.LoadFrequencyDroopGain_Hz := 0.0;
    fb();
    ASSERT_GT(fb.VelocityTrue_Mps, 0.0, 'Vitesse initiale positive');
    fb.ReqMaintenance := FALSE;
    fb.Slope_Mps2 := -0.2;
    ADVANCE_TIME(100000000);
    fb();
    ASSERT_LT(fb.VelocityTrue_Mps, 0.0, 'La correction ne bloque pas une vraie inversion');
END_TEST

TEST 'M3-DYN-070 Frein ferme en mouvement suit la bobine sans attendre les Hz'
VAR
    i : INT;
END_VAR
    FOR i := 1 TO 250 DO
        fb();
    END_FOR;
    ASSERT_GT(fb.VelocityTrue_Mps, 0.3, 'Chariot initialement en mouvement');
    fb.BrakeReleaseCmd := FALSE;
    fb();
    ASSERT_FALSE(fb.BrakeCoilEnergized, 'Coupure bobine immediate');
    ASSERT_TRUE(fb.BrakeMechanicallyOpen, 'Delai mecanique conserve');
    FOR i := 1 TO 60 DO
        fb();
    END_FOR;
    ASSERT_FALSE(fb.BrakeMechanicallyOpen, 'Frein serre malgre frequence non nulle');
    ASSERT_FALSE(fb.BrakeContactOpen, 'Retour frein ferme');
    ASSERT_GT(fb.ActualFrequency_Hz, 10.0, 'La sortie variateur est encore non nulle');
    ASSERT_EQ(fb.VelocityTrue_Mps, 0.0, 'Frein immobilise le chariot');
    ASSERT_EQ(fb.ObsBrakeClosedMovingCount, 1, 'Fermeture en mouvement observable');
END_TEST

TEST 'M3-DYN-080 Balancement conserve secondaire sous controle puis amorti'
VAR
    i : INT;
END_VAR
    reference.Enable := TRUE;
    reference.ReqMaintenance := TRUE;
    reference.SpeedTgt_Pct := 40.0;
    reference.BrakeReleaseCmd := TRUE;
    reference.BrakeOpenDelayS := 0.0;
    reference.SuspendedLoadLength_M := 0.0;
    FOR i := 1 TO 300 DO
        fb();
        reference();
    END_FOR;
    ASSERT_TRUE(ABS(fb.LoadAngle_Rad) > 0.0001, 'Balancement present');
    ASSERT_LT(ABS(fb.PositionTrue_M - reference.PositionTrue_M), 0.05,
        'Contribution secondaire dans ce scenario fixe, sans plafonnement de distance');
    ASSERT_FALSE(fb.ObsCartFree, 'Comparaison effectuee sous controle variateur');
    fb.ReqMaintenance := FALSE;
    fb.BrakeReleaseCmd := FALSE;
    FOR i := 1 TO 800 DO
        fb();
        IF i <= 100 THEN
            peakEarly_Rad := MAX(peakEarly_Rad, ABS(fb.LoadAngle_Rad));
        END_IF;
        IF i > 700 THEN
            peakLate_Rad := MAX(peakLate_Rad, ABS(fb.LoadAngle_Rad));
        END_IF;
    END_FOR;
    ASSERT_GT(peakEarly_Rad, 0.001, 'Pendule excite par le freinage');
    ASSERT_LT(peakLate_Rad, peakEarly_Rad, 'Oscillations amorties');
    ASSERT_EQ(fb.VelocityTrue_Mps, 0.0, 'Pendule ne deplace pas le frein serre');
END_TEST

TEST 'M3-DYN-090 Came spatiale vue perdue retrouvee stable sans blip ajoute'
    sensor(Enable := TRUE, Position_M := 0.2, Threshold_M := 0.0,
        CamDropoutActive := TRUE, CamDropoutStart_M := 0.02, CamDropoutWidth_M := 0.04,
        ElectricalDelayS := 0.0, IntermittenceActive := FALSE, BlipTransitions := 0);
    ASSERT_FALSE(sensor.ElectricalOutput, 'Avant la detection');
    sensor(Position_M := -0.03);
    ASSERT_TRUE(sensor.ElectricalOutput, 'Cible vue');
    sensor(Position_M := -0.06);
    ASSERT_FALSE(sensor.ElectricalOutput, 'Interruption de cible');
    sensor(Position_M := -0.10);
    ASSERT_TRUE(sensor.ElectricalOutput, 'Cible retrouvee');
    sensor();
    ASSERT_TRUE(sensor.ElectricalOutput, 'Etat stable sans intermittence temporelle');
    sensor(Position_M := -0.06);
    ASSERT_FALSE(sensor.ElectricalOutput, 'Zone de perte aussi au retour');
    sensor(Position_M := -0.02);
    ASSERT_TRUE(sensor.ElectricalOutput, 'Cible retrouvee au retour');
    sensor(Position_M := 0.03);
    ASSERT_FALSE(sensor.ElectricalOutput, 'Sortie de cible');
END_TEST
