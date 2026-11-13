# Mission 3 — Audit Modele Physique SimBench M3 (Lecture Seule)

Tu es un Expert Cinématique / Physique Industrielle & Simulation Temps Reel.
Regle : prouve par les equations du code fourni. Zero approximation.

## Probleme etudie
Le chariot M3 reel depasse parfois la butee electrique a petite vitesse jusqu'au choc mecanique.
Or la simulation actuelle s'arrete proprement avant le choc.

## Code reel FB_Sim_TranslationBrake.st
```iecst
1: (* DOC: DOC/AF/AF_Partie-13_Fonction_Simulation_v2.5.md
2:    Chaine bobine, effet mecanique et contact frein M3. *)
3: FUNCTION_BLOCK PUBLIC FB_Sim_TranslationBrake
4: VAR_INPUT
5:     Enable : BOOL;
6:     ReleaseCmd : BOOL;
7:     ActualFrequency_Hz : REAL;
8:     OpenDelay_S : REAL := 0.10;
9:     CloseDelay_S : REAL := 0.09;
10:     ContactDelay_S : REAL := 0.01;
11:     CycleTime_S : REAL := 0.01;
12:     (* Branche de FAUTE EXPLICITE — defaut FALSE : chemin nominal strictement inchange.
13:        Rejoue le defaut terrain « cause 6 instantanee » : contact frein ferme alors que le
14:        variateur retourne encore de la vitesse (trace 2026-09-04, 26,437 s, 10,00 Hz,
15:        State.ErrorId=64). La garde nominale CST_StopFrequency_Hz est CONSERVEE telle quelle :
16:        elle est validee par la meme trace (frein ouvert a 0,60 Hz, ferme a 0,00 Hz). *)
17:     FaultCloseWhileRunning : BOOL := FALSE;
18:     FaultCloseDelay_S : REAL := 0.0;
19:     (* L3 — FREIN PHYSIQUE (2026-10-28). FALSE = historique : la retombee mecanique attend
20:        f <= 0,5 Hz (garde qui recopiait la logique PLC dans l'usine simulee). TRUE = frein a
21:        manque de courant reel : retombe CloseDelay_S apres la coupure bobine, QUELLE QUE SOIT
22:        la vitesse. *)
23:     PhysicalBrakeActive : BOOL := FALSE; (* defaut FB = historique ; la simulation M3 passe TRUE via GVL_Simulation (source unique) *)
24: END_VAR
25: VAR_OUTPUT
26:     Ready : BOOL;
27:     CoilEnergized : BOOL;
28:     MechanicallyOpen : BOOL;
29:     ContactOpen : BOOL;
30:     FaultCloseActive : BOOL;   (* <-- [DIAG] Branche de faute effectivement appliquee ce scan *)
31: END_VAR
32: VAR
33:     MechanicalTimer_S : REAL;
34:     ContactTimer_S : REAL;
35:     FaultTimer_S : REAL;
36: END_VAR
37: VAR CONSTANT
38:     CST_StopFrequency_Hz : REAL := 0.5;
39: END_VAR
40: 
41: IF NOT Enable THEN
42:     Ready := FALSE;
43:     CoilEnergized := FALSE;
44:     MechanicallyOpen := FALSE;
45:     ContactOpen := FALSE;
46:     FaultCloseActive := FALSE;
47:     MechanicalTimer_S := 0.0;
48:     ContactTimer_S := 0.0;
49:     FaultTimer_S := 0.0;
50:     RETURN;
51: END_IF;
52: 
53: (* Faute explicite : chronometre propre, remis a zero des que le stimulus retombe. *)
54: IF FaultCloseWhileRunning THEN
55:     FaultTimer_S := FaultTimer_S + CycleTime_S;
56: ELSE
57:     FaultTimer_S := 0.0;
58: END_IF;
59: FaultCloseActive := FaultCloseWhileRunning AND (FaultTimer_S >= MAX(0.0, FaultCloseDelay_S));
60: 
61: (* La faute fait retomber la bobine : l'etat electrique publie reste coherent avec la
62:    fermeture mecanique observee (jamais « bobine energisee ET frein serre »). *)
63: CoilEnergized := ReleaseCmd AND NOT FaultCloseActive;
64: IF CoilEnergized THEN
65:     IF NOT MechanicallyOpen THEN
66:         MechanicalTimer_S := MechanicalTimer_S + CycleTime_S;
67:         IF MechanicalTimer_S >= MAX(0.0, OpenDelay_S) THEN
68:             MechanicallyOpen := TRUE;
69:             MechanicalTimer_S := 0.0;
70:         END_IF;
71:     ELSE
72:         MechanicalTimer_S := 0.0;
73:     END_IF;
74: ELSIF FaultCloseActive OR PhysicalBrakeActive OR (ActualFrequency_Hz <= CST_StopFrequency_Hz) THEN
75:     IF MechanicallyOpen THEN
76:         MechanicalTimer_S := MechanicalTimer_S + CycleTime_S;
77:         IF MechanicalTimer_S >= MAX(0.0, CloseDelay_S) THEN
78:             MechanicallyOpen := FALSE;
79:             MechanicalTimer_S := 0.0;
80:         END_IF;
81:     ELSE
82:         MechanicalTimer_S := 0.0;
83:     END_IF;
84: ELSE
85:     MechanicalTimer_S := 0.0;
86: END_IF;
87: IF MechanicallyOpen <> ContactOpen THEN
88:     ContactTimer_S := ContactTimer_S + CycleTime_S;
89:     IF ContactTimer_S >= MAX(0.0, ContactDelay_S) THEN
90:         ContactOpen := MechanicallyOpen;
91:         ContactTimer_S := 0.0;
92:     END_IF;
93: ELSE
94:     ContactTimer_S := 0.0;
95: END_IF;
96: Ready := TRUE;
```

## Code reel FB_Sim_TranslationDrive.st
```iecst
1: (* DOC: DOC/AF/AF_Partie-13_Fonction_Simulation_v2.5.md
2:    Dynamique reduite du variateur M3, sans commande metier. *)
3: FUNCTION_BLOCK PUBLIC FB_Sim_TranslationDrive
4: VAR_INPUT
5:     Enable : BOOL;
6:     FrequencyTgt_Hz : REAL;
7:     AccelRate_HzPerS : REAL := 20.0;
8:     DecelRate_HzPerS : REAL := 20.0; // Pente d'arret relevee sur trace reelle MES (-20.0 Hz/s)
9:     TimeConstant_S : REAL := 0.03;   // Reponse dynamique AC600 en boucle fermee (30 ms)
10:     LoadAngularVelocity_RadPerS : REAL;
11:     LoadFrequencyDroopGain_Hz : REAL := 0.50;
12:     CycleTime_S : REAL := 0.01;
13: END_VAR
14: VAR_OUTPUT
15:     Ready : BOOL;
16:     FrequencyCmd_Hz : REAL;
17:     ElectricalFrequency_Hz : REAL;
18:     ActualFrequency_Hz : REAL;
19:     ResponseAlpha : REAL;
20: END_VAR
21: VAR
22:     FrequencyDelta_Hz : REAL;
23:     FrequencyStep_Hz : REAL;
24: END_VAR
25: VAR CONSTANT
26:     CST_MinTime_S : REAL := 0.001;
27:     CST_StopFrequency_Hz : REAL := 0.5; // seuil nominal de fin de rampe variateur
28:     CST_MaxFrequency_Hz : REAL := 50.0; // plafond variateur reel (GVL_PERSISTENT._TranslationMaxFreq_Hz)
29: END_VAR
30: 
31: IF NOT Enable THEN
32:     Ready := FALSE;
33:     FrequencyCmd_Hz := 0.0;
34:     ElectricalFrequency_Hz := 0.0;
35:     ActualFrequency_Hz := 0.0;
36:     ResponseAlpha := 0.0;
37:     RETURN;
38: END_IF;
39: 
40: FrequencyDelta_Hz := LIMIT(0.0, FrequencyTgt_Hz, CST_MaxFrequency_Hz) - FrequencyCmd_Hz;
41: IF FrequencyDelta_Hz >= 0.0 THEN
42:     FrequencyStep_Hz := MAX(0.0, AccelRate_HzPerS) * CycleTime_S;
43: ELSE
44:     FrequencyStep_Hz := MAX(0.0, DecelRate_HzPerS) * CycleTime_S;
45: END_IF;
46: FrequencyCmd_Hz := FrequencyCmd_Hz + LIMIT(-FrequencyStep_Hz, FrequencyDelta_Hz, FrequencyStep_Hz);
47: IF TimeConstant_S > CST_MinTime_S THEN
48:     ResponseAlpha := CycleTime_S / (TimeConstant_S + CycleTime_S);
49: ELSE
50:     ResponseAlpha := 1.0;
51: END_IF;
52: ElectricalFrequency_Hz := ElectricalFrequency_Hz
53:     + ResponseAlpha * (FrequencyCmd_Hz - ElectricalFrequency_Hz);
54: (* Retour AC600 : frequence electrique de sortie. La charge est appliquee par le
55:    modele mecanique ; elle ne doit pas biaiser le retour publie au PLC. *)
56: ActualFrequency_Hz := MAX(0.0, ElectricalFrequency_Hz);
57: IF (FrequencyTgt_Hz <= 0.0) AND (FrequencyCmd_Hz <= 0.0)
58:     AND (ActualFrequency_Hz <= CST_StopFrequency_Hz) THEN
59:     ElectricalFrequency_Hz := 0.0;
60:     ActualFrequency_Hz := 0.0;
61: END_IF;
62: Ready := TRUE;
```

## Code reel FB_Sim_Translation.st (lignes 240-420 : dynamique + butee)
```iecst
240: END_IF;
241: 
242: IF Enable THEN
243:     DirectionSign := 0.0;
244:     IF ReqTremie AND NOT ReqMaintenance THEN
245:         DirectionSign := -1.0;
246:     ELSIF ReqMaintenance AND NOT ReqTremie THEN
247:         DirectionSign := 1.0;
248:     END_IF;
249: 
250:     FrequencyTarget_Hz := LIMIT(0.0, ABS(SpeedTgt_Pct) * MaxFreq_Hz / 100.0, MaxFreq_Hz);
251:     IF DirectionSign = 0.0 THEN
252:         FrequencyTarget_Hz := 0.0;
253:     END_IF;
254:     instDrive(Enable := TRUE, FrequencyTgt_Hz := FrequencyTarget_Hz,
255:         AccelRate_HzPerS := AccelRate_HzPerS, DecelRate_HzPerS := DecelRate_HzPerS,
256:         TimeConstant_S := DriveTimeConstantS,
257:         LoadAngularVelocity_RadPerS := instSuspendedLoad.AngularVelocity_RadPerS,
258:         LoadFrequencyDroopGain_Hz := LoadFrequencyDroopGain_Hz, CycleTime_S := CycleTimeS);
259:     FrequencyCmd_Hz := instDrive.FrequencyCmd_Hz;
260:     ElectricalFrequency_Hz := instDrive.ElectricalFrequency_Hz;
261:     SpeedFactorApplied := LIMIT(1.0, SpeedFactor, 5.0);
262:     ActualFrequency_Hz := instDrive.ActualFrequency_Hz * SpeedFactorApplied;
263:     instBrake(Enable := TRUE, ReleaseCmd := BrakeReleaseCmd,
264:         ActualFrequency_Hz := instDrive.ActualFrequency_Hz, OpenDelay_S := BrakeOpenDelayS,
265:         CloseDelay_S := BrakeCloseDelayS, ContactDelay_S := BrakeContactDelayS,
266:         CycleTime_S := CycleTimeS,
267:         FaultCloseWhileRunning := BrakeFaultCloseWhileRunning,
268:         FaultCloseDelay_S := BrakeFaultCloseDelay_S,
269:         PhysicalBrakeActive := BrakePhysicalActive);
270:     BrakeCoilEnergized := instBrake.CoilEnergized;
271:     BrakeMechanicallyOpen := instBrake.MechanicallyOpen;
272:     BrakeContactOpen := instBrake.ContactOpen;
273:     BrakeFaultCloseActive := instBrake.FaultCloseActive;
274: 
275:     (* Sens memorise (C3). Regles, dans cet ordre :
276:        1. un ordre simple valide (re)memorise le sens ;
277:        2. deux ordres contradictoires neutralisent immediatement le sens — aucune
278:           excitation inventee (preserve TC-T300-MEC-030) ;
279:        3. commande retiree : le sens est CONSERVE tant que le variateur retourne de la
280:           vitesse (deceleration libre), puis purge des que la vitesse est nulle. *)
281:     IF ReqTremie AND NOT ReqMaintenance THEN
282:         TravelDirection := -1.0;
283:     ELSIF ReqMaintenance AND NOT ReqTremie THEN
284:         TravelDirection := 1.0;
285:     ELSIF ReqTremie AND ReqMaintenance THEN
286:         TravelDirection := 0.0;
287:     ELSIF ABS(instDrive.ActualFrequency_Hz) <= CST_StopFrequency_Hz THEN
288:         TravelDirection := 0.0;
289:     END_IF;
290: 
291:     PreviousVelocity_Mps := VelocityTrue_Mps;
292:     IF BrakeMechanicallyOpen THEN
293:         (* Source unique : meme gain que l'estimateur machine (vitesse = gain x frequence). *)
294:         VelocityTarget_Mps := TravelDirection * MAX(0.0, GainMetersPerHzSec) * ActualFrequency_Hz;
295:     ELSE
296:         VelocityTarget_Mps := 0.0;
297:     END_IF;
298:     (* L4 : le variateur tient le chariot tant qu'il est commande ou que sa SORTIE electrique
299:        alimente encore le moteur (rampe + reponse) ; ensuite, plus aucun couple.
300:        Reprise de commande en roue libre : pas de reprise a la volee (le variateur repart de 0 Hz). *)
301:     DriveTorqueActive := (DirectionSign <> 0.0) OR (instDrive.ElectricalFrequency_Hz > CST_StopFrequency_Hz);
302:     ObsCartFree := CartFreeActive AND BrakeMechanicallyOpen AND NOT DriveTorqueActive;
303:     IF ObsCartFree THEN
304:         (* Poussee de la benne (angle du scan precedent) + pente - frottement oppose au mouvement. *)
305:         (* Pendule sur chariot libre : x'' = m_benne / m_chariot x g x theta = r / (1 - r) x g x theta. *)
306:         FreeAccel_Mps2 := (LIMIT(0.0, LoadMassRatio, 0.9) / (1.0 - LIMIT(0.0, LoadMassRatio, 0.9)))
307:                           * 9.81 * instSuspendedLoad.Angle_Rad + Slope_Mps2;
308:         IF ABS(VelocityTrue_Mps) < 0.001 THEN
309:             (* Adherence statique au repos : ne decolle que si la poussee depasse le frottement statique *)
310:             IF ABS(FreeAccel_Mps2) <= MAX(0.0, StaticFriction_Mps2) THEN
311:                 FreeAccel_Mps2 := 0.0;
312:                 VelocityTrue_Mps := 0.0;
313:             ELSIF FreeAccel_Mps2 > 0.0 THEN
314:                 FreeAccel_Mps2 := FreeAccel_Mps2 - MAX(0.0, StaticFriction_Mps2);
315:             ELSE
316:                 FreeAccel_Mps2 := FreeAccel_Mps2 + MAX(0.0, StaticFriction_Mps2);
317:             END_IF;
318:             VelocityTrue_Mps := VelocityTrue_Mps + FreeAccel_Mps2 * CycleTimeS;
319:         ELSE
320:             (* La force externe peut inverser le mouvement ; le frottement ne peut
321:                que reduire sa vitesse, au plus jusqu'a zero. *)
322:             FreeVelocity_Mps := VelocityTrue_Mps + FreeAccel_Mps2 * CycleTimeS;
323:             FrictionStep_Mps := MAX(0.0, RollingFriction_Mps2) * CycleTimeS;
324:             IF (((VelocityTrue_Mps > 0.0) AND (FreeVelocity_Mps <= 0.0))
325:                 OR ((VelocityTrue_Mps < 0.0) AND (FreeVelocity_Mps >= 0.0)))
326:                 AND (ABS(FreeAccel_Mps2) <= MAX(0.0, StaticFriction_Mps2)) THEN
327:                 (* Passage par zero pendant le pas : l'adherence interdit un redemarrage
328:                    sous le seuil statique, meme si la force est opposee au mouvement. *)
329:                 VelocityTrue_Mps := 0.0;
330:             ELSIF FreeVelocity_Mps > 0.0 THEN
331:                 VelocityTrue_Mps := MAX(0.0, FreeVelocity_Mps - FrictionStep_Mps);
332:             ELSE
333:                 VelocityTrue_Mps := MIN(0.0, FreeVelocity_Mps + FrictionStep_Mps);
334:             END_IF;
335:         END_IF;
336:     ELSIF BrakeMechanicallyOpen THEN
337:         (* Vitesse suivant directement le variateur (deja filtre par instDrive) sans double PT1 *)
338:         VelocityTrue_Mps := VelocityTarget_Mps;
339:     ELSIF BrakePhysicalActive THEN
340:         (* L3 : frein serre -> deceleration sur le frein jusqu'a l'arret, puis chariot bloque. *)
341:         IF VelocityTrue_Mps > 0.0 THEN
342:             VelocityTrue_Mps := MAX(0.0, VelocityTrue_Mps - MAX(0.0, BrakeDecel_Mps2) * CycleTimeS);
343:         ELSE
344:             VelocityTrue_Mps := MIN(0.0, VelocityTrue_Mps + MAX(0.0, BrakeDecel_Mps2) * CycleTimeS);
345:         END_IF;
346:     ELSE
347:         VelocityTrue_Mps := 0.0;   (* historique : arret instantane *)
348:     END_IF;
349:     ObsSpeedBeforeStop_Mps := VelocityTrue_Mps;
350:     HardStopTremieActive := FALSE;
351:     HardStopMaintenanceActive := FALSE;
352:     PositionCandidate_M := PositionTrue_M + VelocityTrue_Mps * CycleTimeS;
353:     IF PositionCandidate_M < EndStopTremie_M THEN
354:         PositionTrue_M := EndStopTremie_M;
355:         VelocityTrue_Mps := 0.0;
356:         HardStopTremieActive := TRUE;
357:     ELSIF PositionCandidate_M > EndStopMaintenance_M THEN
358:         PositionTrue_M := EndStopMaintenance_M;
359:         VelocityTrue_Mps := 0.0;
360:         HardStopMaintenanceActive := TRUE;
361:     END_IF;
362:     CartAcceleration_Mps2 := (VelocityTrue_Mps - PreviousVelocity_Mps) / CycleTimeS;
363:     instSuspendedLoad(Enable := TRUE, BrakeMechanicallyOpen := BrakeMechanicallyOpen,
364:         CartAcceleration_Mps2 := CartAcceleration_Mps2, Length_M := SuspendedLoadLength_M,
365:         Damping := SuspendedLoadDamping, ReactionGain_Mps2 := LoadReactionGain_Mps2,
366:         CycleTime_S := CycleTimeS);
367:     LoadAngle_Rad := instSuspendedLoad.Angle_Rad;
368:     IF HardStopTremieActive OR HardStopMaintenanceActive THEN
369:         RecoilMax_M := MIN(MAX(0.0, EndStopRecoilMax_M), EndStopMaintenance_M - EndStopTremie_M);
370:         IF (RecoilMax_M > 0.0) AND BrakeMechanicallyOpen THEN
371:             (* Recul autorise UNIQUEMENT en s'eloignant de la butee touchee, borne par
372:                EndStopRecoilMax_M : jamais plus loin dans la butee, jamais de saut cache. *)
373:             VelocityTrue_Mps := VelocityTrue_Mps + instSuspendedLoad.VelocityReaction_Mps;
374:             (* Contre une butee, l'entrainement DECROCHE : il ne maintient pas une consigne de
375:                vitesse dans l'obstacle. Sans cette purge, la consigne de vitesse ecrasait en
376:                permanence la reaction de charge et le chariot ne pouvait jamais ressortir de
377:                la zone capteur (recul alors impossible, quelle que soit la charge). *)
378:             TravelDirection := 0.0;
379:             IF HardStopTremieActive THEN
380:                 VelocityTrue_Mps := MAX(0.0, VelocityTrue_Mps);
381:                 PositionCandidate_M := LIMIT(EndStopTremie_M,
382:                     PositionTrue_M + VelocityTrue_Mps * CycleTimeS,
383:                     EndStopTremie_M + RecoilMax_M);
384:             ELSE
385:                 VelocityTrue_Mps := MIN(0.0, VelocityTrue_Mps);
386:                 PositionCandidate_M := LIMIT(EndStopMaintenance_M - RecoilMax_M,
387:                     PositionTrue_M + VelocityTrue_Mps * CycleTimeS,
388:                     EndStopMaintenance_M);
389:             END_IF;
390:             PositionTrue_M := PositionCandidate_M;
391:         ELSE
392:             VelocityTrue_Mps := 0.0;
393:         END_IF;
394:     ELSE
395:         IF NOT ObsCartFree THEN
396:             (* Reaction historique (negligeable) ; en mode libre la poussee est deja integree (L4). *)
397:             VelocityTrue_Mps := VelocityTrue_Mps + instSuspendedLoad.VelocityReaction_Mps;
398:         END_IF;
399:         PositionCandidate_M := PositionTrue_M + VelocityTrue_Mps * CycleTimeS;
400:         IF PositionCandidate_M < EndStopTremie_M THEN
401:             PositionTrue_M := EndStopTremie_M;
402:             VelocityTrue_Mps := 0.0;
403:             HardStopTremieActive := TRUE;
404:         ELSIF PositionCandidate_M > EndStopMaintenance_M THEN
405:             PositionTrue_M := EndStopMaintenance_M;
406:             VelocityTrue_Mps := 0.0;
407:             HardStopMaintenanceActive := TRUE;
408:         ELSE
409:             PositionTrue_M := PositionCandidate_M;
410:         END_IF;
411:     END_IF;
412: END_IF;
413: 
414: IF Enable AND (ABS(LoadAngle_Rad) > 0.0001) THEN
415:     SensorNoiseState := 3.91 * SensorNoiseState * (1.0 - SensorNoiseState);
416:     SensorNoise_M := (2.0 * SensorNoiseState - 1.0) * SensorJitterAmplitude_M;
417: ELSE
418:     SensorNoise_M := 0.0;
419: END_IF;
420: (* Les capteurs sont fixes au rail et observent le chariot. Le balancier agit
```

## Livrable attendu (concis, structure TDAH-friendly)
1. **Calcul exact de distance d'arret du modele actuel** en petite vitesse (5 Hz et 10 Hz, avec `Gain=0.02 m/(Hz.s)`, `DecelRate=25 Hz/s`, `CloseDelay=0.09 s`, `BrakeDecel=2.0 m/s^2`, `EndStopMargin=0.5 m`). Montre pourquoi la simu s'arrete proprement loin de la butee.
2. **Pourquoi `ObsCartFree` (chariot libre) ne se declenche pas ou s'arrete trop tot** dans le scenario de coupure en butee.
3. **Registre des hypotheses physiques manquantes ou sur-idealisees** (max 6 hypotheses classees par impact probable sur un depassement a petite vitesse : ex. retard ouverture/fermeture frein, couple de freinage reel, inertie/glissement rail, maintien ordre marche, latence capteur/scan, pente/charge suspendue).
