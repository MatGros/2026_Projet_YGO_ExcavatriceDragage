🟡 ADVISORY  
Verdict : analyse cohérente avec les extraits fournis, mais non vérifiée par accès dépôt/exécution dans cette session.  
Impact : le défaut SEMI_AUTO vient de la disparition trop précoce de `ReqTremieSemantic` et de `PositionTgt` au scan N+1 ; S1 corrige le comportement iso-MANU, S2/S3 ajoutent des verrous de sécurité.  
Durée/Horodatage : analyse statique, 2026-05-09.

## Niveau 1 — invariants

1. `[✅ PASS]` Hypothèse de cycle 10 ms reprise du brief : `CaptorDebounceTon` à 100 ms = 10 scans.
2. `[✅ PASS]` En MANU, le joystick maintient `ReqTremieSemantic` TRUE pendant 30 à 50 scans, donc `EffectiveSafeStop`, `M3_TremieHardStopActive` et `M3_TargetCodeSel` restent actifs jusqu’à l’armement de `ArrivalLock`.
3. `[✅ PASS]` En SEMI_AUTO, l’écriture de `ReqStart := FALSE` et `PositionTgt := 0` au scan N+1 coupe la requête, la rampe rapide, le hard stop PRG_06 et la sélection de cible avant la fin du debounce 100 ms.
4. `[✅ PASS]` Sur AX2/P1, la mise à `0` de `PositionTgt` fait tomber `M3_PositionSensorTarget` avant `CaptorDebounceTon.Q`, donc `ArrivalLock` ne s’arme pas.
5. `[❌ FAIL]` Ambiguïté à lever dans le code réel : `Translation_At_P1` est décrit comme `M3_AtP1Stable`, donc potentiellement déjà post-debounce. Si c’est vrai, la conséquence (d) du brief ne peut pas être expliquée par ce seul signal ; il faut vérifier si `M3_PositionSensorTarget` est bien la condition d’entrée du `CaptorDebounceTon`.
6. `[✅ PASS]` S1 fournie : maintien de `ReqStart` et `PositionTgt` pendant une durée > `CaptorDebounceTon.PT`, sur P1 et Trémie.
7. `[✅ PASS]` S2 fournie : latch du hard stop sur premier trou, indépendant de la chute de `ReqTremieSemantic`.
8. `[✅ PASS]` S3 fournie : latch de `EffectiveSafeStop` sur premier trou, indépendant de la chute de `ReqTremie`.
9. `[❌ FAIL]` Aucune compilation, simulation ni trace PLC exécutée dans cette session ; verdict limité à l’analyse statique.

## Niveau 1 bis — chronologie et argumentaire

Hypothèses de lecture : scan N = premier scan où le trou brut `M3_PosTremie_DI` ou `M3_PosP1_DI` est TRUE ; `EffectivePermitM3_Tremie` est FALSE au premier trou ; l’ordre d’exécution est `FB_Translation` puis `PRG_06` puis `FB_CycleSemiAuto` ou équivalent. Si l’ordre diffère, décaler d’un scan.

1. MANU, scan N : trou TRUE, `M3_ReqTremie_Active = TRUE`, `EffectiveSafeStop = TRUE`, `M3_TremieHardStopActive = TRUE`, `DriveControlWord = 0`, `BrakeRelease_RQ = FALSE`, `M3_TargetCodeSel = TRUE`, `CaptorDebounceTon.ET = 0 ms`.
2. MANU, scans N+1 à N+9 : opérateur maintient le joystick ; `CaptorDebounceTon.ET` passe de 10 à 90 ms ; rampe rapide `CfgRampDecelFastRate` ; hard stop et cible maintenus.
3. MANU, scan N+10 : `CaptorDebounceTon.Q = TRUE`, `ArrivalLock = TRUE`. Le hard stop reste actif car `ReqTremieSemantic` est encore TRUE.
4. MANU, scans N+11 à N+29 : `ArrivalLock` armé ; opérateur maintient encore ; chaîne d’arrêt inchangée.
5. MANU, scans N+30 à N+50 : l’opérateur relâche le joystick ; `ReqTremieSemantic` tombe ; `EffectiveSafeStop` et `M3_TremieHardStopActive` retombent ; freinage final par `FB_Translation.Brake` quand `SpeedRamp.Current <= 0.1` et `DelayMotorDecel` écoulé. La position d’arrivée est déjà verrouillée.
6. SEMI_AUTO, scan N : premier trou ; `ReqTremieSemantic = TRUE` ; `EffectiveSafeStop = TRUE` ; hard stop TRUE ; cible active ; debounce démarre.
7. SEMI_AUTO, scan N+1 : `FB_CycleSemiAuto` écrit `TranslationCmd.ReqStart := FALSE` et `TranslationCmd.PositionTgt := 0`. Conséquences immédiates : `ReqTremieSemantic = FALSE`, `EffectiveSafeStop = FALSE`, `M3_TremieHardStopActive = FALSE`, `M3_PositionSensorTarget = FALSE`.
8. SEMI_AUTO, scans N+2 à N+9 : `CaptorDebounceTon.IN` est FALSE ou sa cible a disparu ; le timer ne peut plus aboutir ; `ArrivalLock` reste FALSE ; la rampe repasse sur `CfgRampDecelNormalRate` ; le frein n’est plus forcé par PRG_06.
9. SEMI_AUTO, scan N+10 : 100 ms après le premier trou, mais `CaptorDebounceTon.Q` ne s’arme pas car `PositionTgt` a été annulé au scan N+1. `ArrivalLock` n’est jamais armé.
10. SEMI_AUTO, scans N+11 à N+50 : décélération sur rampe normale ; le frein attend `SpeedRamp.Current <= 0.1` puis `DelayMotorDecel` ; sur P1, la cible à 0 avant debounce provoque le défaut d’arrivée ; sur Trémie, le hard stop et la rampe rapide sont perdus. Le comportement n’est plus iso-MANU.
11. Ambiguïté à vérifier : si `M3_AtP1Stable` est déjà l’image post-debounce de `ArrivalLock`, alors le point 10 doit être réinterprété : le défaut P1 serait plutôt la perte de maintien du hard stop/frein, pas la perte d’armement du debounce. Il faut trancher avec une trace des signaux `M3_PositionSensorTarget`, `CaptorDebounceTon.ET`, `CaptorDebounceTon.Q`, `ArrivalLock`, `M3_AtP1Stable` sur 200 ms.

Combinaison optimale : S1 seule pour un comportement iso-MANU. S1 + S2 si l’on veut garantir le hard stop même si un autre bloc retire la requête. S1 + S2 + S3 si l’on veut aussi garantir la rampe rapide et le frein indépendamment de la durée de vie de la requête. S2 et S3 doivent idéalement être conditionnées au mode SEMI_AUTO si l’on ne veut modifier strictement le comportement MANU.

## Niveau 2 — plan d’action chirurgical

### S1 — Maintien de commande dans `FB_CycleSemiAuto` jusqu’à debounce + marge

Localisation : `FB_CycleSemiAuto.st` AX2 vers ligne 985, AX14 vers ligne 1490.  
Ancre : blocs qui écrivent `TranslationCmd.ReqStart := FALSE; TranslationCmd.PositionTgt := 0;`.  
Action : remplacer le bloc immédiat par un maintien temporisé de 200 ms, supérieur au debounce de 100 ms.  
Outil déterministe associé : revue de code + trace PLC 10 ms.  
Risque si ignoré : `ArrivalLock` ne s’arme jamais en P1 et le hard stop tombe avant le frein.

Déclarations à ajouter dans `FB_CycleSemiAuto` :

```st
P1ArrivalHoldSeen     : BOOL;
TremieArrivalHoldSeen : BOOL;
tonP1ArrivalHold      : TON;
tonTremieArrivalHold  : TON;
```

AX2 / P1, remplacer le bloc de ligne 985 par :

```st
IF Translation_At_P1 AND NOT P1ArrivalHoldSeen THEN
    P1ArrivalHoldSeen := TRUE;
END_IF;

tonP1ArrivalHold(IN := P1ArrivalHoldSeen, PT := T#200MS);

IF P1ArrivalHoldSeen AND NOT tonP1ArrivalHold.Q THEN
    // Maintien iso-MANU : l'opérateur garde le joystick pendant le debounce
    TranslationCmd.ReqStart := TRUE;
    // Ne pas écrire PositionTgt := 0 ici
ELSIF tonP1ArrivalHold.Q THEN
    TranslationCmd.ReqStart := FALSE;
    TranslationCmd.PositionTgt := 0;
    IF NOT Translation_At_P1 THEN
        P1ArrivalHoldSeen := FALSE;
    END_IF;
END_IF;
```

AX14 / Trémie, remplacer le bloc de ligne 1490 par :

```st
IF Translation_At_Tremie AND NOT TremieArrivalHoldSeen THEN
    TremieArrivalHoldSeen := TRUE;
END_IF;

tonTremieArrivalHold(IN := TremieArrivalHoldSeen, PT := T#200MS);

IF TremieArrivalHoldSeen AND NOT tonTremieArrivalHold.Q THEN
    TranslationCmd.ReqStart := TRUE;
    // Ne pas écrire PositionTgt := 0 ici
ELSIF tonTremieArrivalHold.Q THEN
    TranslationCmd.ReqStart := FALSE;
    TranslationCmd.PositionTgt := 0;
    IF NOT Translation_At_Tremie THEN
        TremieArrivalHoldSeen := FALSE;
    END_IF;
END_IF;
```

### S2 — Latch du hard stop dans `PRG_06_Outputs`

Localisation : `PRG_06_Outputs.st:438`.  
Ancre : `M3_TremieHardStopActive := M3_TremieHardStopLatched AND ReqTremieSemantic;`.  
Action : ajouter un latch premier trou qui maintient le hard stop même si `ReqTremieSemantic` tombe au scan N+1.  
Outil déterministe associé : trace `M3_TremieHardStopActive`, `BrakeRelease_RQ`, `ReqTremieSemantic`.  
Risque si ignoré : le frein n’est plus forcé par PRG_06 après 10 ms et attend la rampe normale.

Déclarations à ajouter dans `PRG_06_Outputs` :

```st
M3_FirstHoleHardStopLatch : BOOL;
tonM3FirstHoleHardStopMin : TON;
```

Remplacer la ligne 438 par :

```st
IF ReqTremieSemantic AND (M3_PosTremie_DI OR M3_PosP1_DI) THEN
    M3_FirstHoleHardStopLatch := TRUE;
END_IF;

tonM3FirstHoleHardStopMin(IN := M3_FirstHoleHardStopLatch, PT := T#500MS);

IF M3_FirstHoleHardStopLatch
   AND tonM3FirstHoleHardStopMin.Q
   AND NOT ReqTremieSemantic THEN
    M3_FirstHoleHardStopLatch := FALSE;
END_IF;

M3_TremieHardStopActive :=
    (M3_TremieHardStopLatched AND ReqTremieSemantic)
    OR M3_FirstHoleHardStopLatch;
```

Note : si un signal de fin d’arrêt existe, remplacer la condition de reset par `NOT ReqTremieSemantic AND SpeedRamp.Current <= 0.1` ou le signal de vitesse réellement disponible dans PRG_06.

### S3 — Latch de `EffectiveSafeStop` dans `FB_Translation`

Localisation : `FB_Translation.st:291`.  
Ancre : expression `EffectiveSafeStop := SafeStop OR (ReqTremie AND NOT EffectivePermitM3_Tremie) ...`.  
Action : ajouter un latch premier trou pour conserver la rampe rapide même si `ReqTremie` tombe.  
Outil déterministe associé : trace `EffectiveSafeStop`, `SpeedRamp.Current`, `CfgRampDecelFastRate`.  
Risque si ignoré : la rampe repasse en décélération normale au scan N+1.

Déclarations à ajouter dans `FB_Translation` :

```st
M3_FirstHoleSafeStopLatch : BOOL;
tonM3FirstHoleSafeStopMin : TON;
```

Avant l’affectation de `EffectiveSafeStop`, insérer :

```st
IF ReqTremie AND (M3_PosTremie_DI OR M3_PosP1_DI) THEN
    M3_FirstHoleSafeStopLatch := TRUE;
END_IF;

tonM3FirstHoleSafeStopMin(IN := M3_FirstHoleSafeStopLatch, PT := T#500MS);

IF M3_FirstHoleSafeStopLatch
   AND tonM3FirstHoleSafeStopMin.Q
   AND (SpeedRamp.Current <= 0.1) THEN
    M3_FirstHoleSafeStopLatch := FALSE;
END_IF;
```

Puis modifier l’expression ligne 291 :

```st
EffectiveSafeStop := SafeStop
    OR M3_FirstHoleSafeStopLatch
    OR (ReqTremie AND NOT EffectivePermitM3_Tremie)
    OR ...;
```

### Vérifications minimales à exécuter sur banc

1. Forcer `M3_PosP1_DI` en SEMI_AUTO à t=0 et tracer sur 500 ms : `ReqTremieSemantic`, `EffectiveSafeStop`, `M3_TremieHardStopActive`, `M3_PositionSensorTarget`, `CaptorDebounceTon.ET`, `CaptorDebounceTon.Q`, `ArrivalLock`, `SpeedRamp.Current`, `BrakeRelease_RQ`.
2. Vérifier `ArrivalLock = TRUE` au scan N+10 et non FALSE.
3. Vérifier `M3_TremieHardStopActive = TRUE` de N à au moins N+10, et `BrakeRelease_RQ = FALSE` sur la même fenêtre.
4. Refaire le test sur `M3_PosTremie_DI`.
5. Rejouer le test MANU avec relâchement joystick à 300 et 500 ms : vérifier absence de régression et reset des latches.
6. Vérifier qu’aucun latch ne reste bloqué après un cycle complet sans premier trou.