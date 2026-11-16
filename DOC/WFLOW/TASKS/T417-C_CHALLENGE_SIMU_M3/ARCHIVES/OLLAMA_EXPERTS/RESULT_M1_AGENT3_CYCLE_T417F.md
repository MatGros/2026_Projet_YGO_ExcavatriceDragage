🟡 ADVISORY  
Verdict : 2 variantes ST proposées, cohérentes sur le papier, non compilées ni testées.  
Impact : F1 est réalisable sans risque majeur ; F2 est conditionnée à un axe Y dédié et à un bypass explicite de `M3AtTremie`.  
Durée/Horodatage : analyse statique, non exécutée / à l’émission.

1. Invariants de conception  
1. [✅ PASS] `CfgPauseBeforeDump_S = 0.0` : comportement transparent si le timer est court-circuité.  
2. [✅ PASS] `CfgPauseBeforeDump_S > 0.0` : délai supplémentaire avant autorisation d’ouverture en `AX15A/B`.  
3. [✅ PASS] F2 ne s’active que si `TglAllowDumpInPV = TRUE` et `Translation_PosPV = TRUE`.  
4. [✅ PASS] F2 autorise le passage vers `AX18_DONE_SYNC` sans `Translation_At_Tremie`, via un latch `PvDumpActive`.  
5. [❌ FAIL] L’axe Y / bouton d’ouverture benne n’est pas prouvé distinct de `JoystickPush`. Si `JoystickPush` contient l’axe X translation, F2 est dangereux.  
6. [⚪ N/A] `PRG_04_Treuils_Benne.st:1083` : à vérifier sur le texte réel. Si `WinchDescentAuth_M3` contient déjà `OR ReqProgram.ReqBucket.ReqOpen`, aucune modification n’est nécessaire.  
7. [❌ FAIL] `FB_Modes.st:372` : si `M3AtTremie := Translation_At_Tremie;` seul, F2 sera bloqué. Il faut un signal `DumpInPvActive` / `PvDumpActive`.  
8. [⚪ N/A] Compilation, analyse de régression et essai terrain non exécutés.

1 bis. Argumentaire technique  
- F1 se traite au même endroit que l’arrêt : timer `TON` démarré à l’entrée de `AX15A` ou d’un état `AX15_PAUSE`, avec bypass si `<= 0.0`.  
- F2 ne doit pas tester `Translation_PosPV` au moment de `Benne_IsOpen` seul : le chariot peut sortir de PV pendant l’ouverture. Il faut latch `PvDumpActive` au moment de la demande d’ouverture en PV.  
- Le joystick X translation et le joystick Y ouverture ne doivent pas être fusionnés. En `AX14`, `JoystickPush` générique ouvrirait la benne sur simple poussée de translation.  
- `M3AtTremie` est probablement utilisé ailleurs que pour le retour cycle. Ne pas le forcer globalement sans vérifier les consommateurs ; préférer un signal dédié `DumpInPvActive`.

2. Variante A — compacte, sans nouvel état  
Principe : timer dans `AX15A`, latch `PvDumpActive` dans `AX14`, réutilisation de `AX15B`.

Déclarations à ajouter dans `FB_CycleSemiAuto` :
```st
VAR
    CfgPauseBeforeDump_S : REAL := 0.0;   // IHM, secondes
    TglAllowDumpInPV     : BOOL := FALSE; // IHM

    PauseBeforeDumpTimer : TON;
    PvDumpActive         : BOOL;          // latch cycle : dump demandé en PV
    JoystickBucketOpen   : BOOL;          // axe Y / bouton dédié ouverture benne
END_VAR
```

Mapping axe, une fois par scan avant le `CASE` :
```st
// À REMPLACER par le signal réel.
// Si JoystickPush = OR(axe X, axe Y), cette ligne doit utiliser un signal Y séparé.
JoystickBucketOpen := JoystickY_Push;

PauseBeforeDumpTimer(
    IN := (State = AX15A_DUMP_ARRIVE) AND (CfgPauseBeforeDump_S > 0.0),
    PT := DINT_TO_TIME(
            REAL_TO_DINT(
                LIMIT(0.0, CfgPauseBeforeDump_S, 60.0) * 1000.0 + 0.5)));
```

`AX14_TRANSLATE_DUMP` :
```st
AX14_TRANSLATE_DUMP:
    TranslationCmd.PositionTgt := 1;
    TranslationCmd.ReqStart := TranslationTremiePermit;

    // F2 : latch uniquement si la demande d'ouverture est faite en zone PV
    IF TglAllowDumpInPV AND Translation_PosPV AND
       (Benne_IsOpen OR (DeadmanArmed AND JoystickBucketOpen)) THEN
        PvDumpActive := TRUE;
    END_IF;

    // F2 : ouverture possible en PV, mais uniquement avec l'axe Y / bouton dédié
    BucketCmd.ReqOpen := PvDumpActive AND DeadmanArmed AND JoystickBucketOpen;

    // F2 : fin de cycle sans M3 si la benne est ouverte après demande en PV
    IF PvDumpActive AND Benne_Done AND Benne_IsOpen THEN
        TranslationCmd.ReqStart := FALSE;
        State := AX18_DONE_SYNC;
    ELSIF Translation_At_Tremie AND TranslationStopTimer.Q THEN
        State := AX15A_DUMP_ARRIVE;
    END_IF;
```

`AX15A_DUMP_ARRIVE` :
```st
AX15A_DUMP_ARRIVE:
    TranslationCmd.ReqStart := FALSE;

    // Si l'ouverture a déjà été autorisée en PV, la poursuite reste possible.
    BucketCmd.ReqOpen := PvDumpActive AND DeadmanArmed AND JoystickBucketOpen;

    IF PvDumpActive AND Benne_Done AND Benne_IsOpen THEN
        State := AX18_DONE_SYNC;
    ELSIF SeenNeutralAfterArrival
       AND ((CfgPauseBeforeDump_S <= 0.0) OR PauseBeforeDumpTimer.Q)
       AND DeadmanArmed
       AND JoystickBucketOpen THEN
        State := AX15B_DUMP_OPEN;
    END_IF;
```

`AX15B_DUMP_OPEN` :
```st
AX15B_DUMP_OPEN:
    BucketCmd.ReqOpen := DeadmanArmed AND JoystickBucketOpen;

    IF Benne_Done AND Benne_IsOpen THEN
        State := AX18_DONE_SYNC;
    END_IF;
```

Reset obligatoire du latch :
```st
// Sur reset cycle / entrée état initial, et pas à la sortie de PV.
IF CycleReset THEN
    PvDumpActive := FALSE;
END_IF;
```

3. Variante B — séquencée, avec états explicites  
Principe : ajout de `AX14B_DUMP_IN_PV` et `AX15_PAUSE_DUMP`. Plus de code, mais comportement lisible et testable.

Ajouter dans l’énumération d’états :
```st
AX14B_DUMP_IN_PV,
AX15_PAUSE_DUMP,
```

Mêmes déclarations que Variante A, avec timer appelé sur `AX15_PAUSE_DUMP` :
```st
JoystickBucketOpen := JoystickY_Push; // à remplacer par le signal réel

PauseBeforeDumpTimer(
    IN := (State = AX15_PAUSE_DUMP) AND (CfgPauseBeforeDump_S > 0.0),
    PT := DINT_TO_TIME(
            REAL_TO_DINT(
                LIMIT(0.0, CfgPauseBeforeDump_S, 60.0) * 1000.0 + 0.5)));
```

`AX14_TRANSLATE_DUMP` :
```st
AX14_TRANSLATE_DUMP:
    TranslationCmd.PositionTgt := 1;
    TranslationCmd.ReqStart := TranslationTremiePermit;
    BucketCmd.ReqOpen := FALSE;

    IF TglAllowDumpInPV AND Translation_PosPV THEN
        State := AX14B_DUMP_IN_PV;
    ELSIF Translation_At_Tremie AND TranslationStopTimer.Q THEN
        State := AX15_PAUSE_DUMP;
    END_IF;
```

`AX14B_DUMP_IN_PV` :
```st
AX14B_DUMP_IN_PV:
    TranslationCmd.PositionTgt := 1;
    TranslationCmd.ReqStart := TranslationTremiePermit;

    IF TglAllowDumpInPV AND Translation_PosPV AND
       (Benne_IsOpen OR (DeadmanArmed AND JoystickBucketOpen)) THEN
        PvDumpActive := TRUE;
    END_IF;

    BucketCmd.ReqOpen := PvDumpActive AND DeadmanArmed AND JoystickBucketOpen;

    IF PvDumpActive AND Benne_Done AND Benne_IsOpen THEN
        TranslationCmd.ReqStart := FALSE;
        State := AX18_DONE_SYNC;
    ELSIF Translation_At_Tremie AND TranslationStopTimer.Q THEN
        State := AX15_PAUSE_DUMP;
    ELSIF NOT TglAllowDumpInPV AND NOT Translation_At_Tremie THEN
        State := AX14_TRANSLATE_DUMP;
    END_IF;
```

`AX15_PAUSE_DUMP` :
```st
AX15_PAUSE_DUMP:
    TranslationCmd.ReqStart := FALSE;

    // Si F2 a déjà autorisé l'ouverture en PV, ne pas couper la commande.
    BucketCmd.ReqOpen := PvDumpActive AND DeadmanArmed AND JoystickBucketOpen;

    IF PvDumpActive AND Benne_Done AND Benne_IsOpen THEN
        State := AX18_DONE_SYNC;
    ELSIF (CfgPauseBeforeDump_S <= 0.0) OR PauseBeforeDumpTimer.Q THEN
        State := AX15A_DUMP_ARRIVE;
    END_IF;
```

`AX15A_DUMP_ARRIVE` :
```st
AX15A_DUMP_ARRIVE:
    TranslationCmd.ReqStart := FALSE;
    BucketCmd.ReqOpen := PvDumpActive AND DeadmanArmed AND JoystickBucketOpen;

    IF PvDumpActive AND Benne_Done AND Benne_IsOpen THEN
        State := AX18_DONE_SYNC;
    ELSIF SeenNeutralAfterArrival
       AND DeadmanArmed
       AND JoystickBucketOpen THEN
        State := AX15B_DUMP_OPEN;
    END_IF;
```

`AX15B_DUMP_OPEN` :
```st
AX15B_DUMP_OPEN:
    BucketCmd.ReqOpen := DeadmanArmed AND JoystickBucketOpen;

    IF Benne_Done AND Benne_IsOpen THEN
        State := AX18_DONE_SYNC;
    END_IF;
```

Reset du latch : identique à Variante A, uniquement au reset cycle.

4. Analyse des transitions joystick  
1. En `AX14`, l’axe X sert à la translation. Si `JoystickPush` est un OR des axes, l’utiliser pour `BucketCmd.ReqOpen` ouvre la benne pendant la translation. C’est un défaut fonctionnel et sécurité.  
2. `JoystickBucketOpen` doit être l’axe Y seul ou un bouton dédié. Sans ce signal, `TglAllowDumpInPV` doit rester à `FALSE`.  
3. En `AX15A`, `SeenNeutralAfterArrival` reste nécessaire pour le dump normal : il garantit que l’axe X est revenu au neutre avant l’ouverture.  
4. En F2 / `AX14B`, ne pas exiger `SeenNeutralAfterArrival` : l’opérateur peut maintenir X pour continuer la translation et pousser Y pour ouvrir.  
5. `DeadmanArmed` reste obligatoire dans toutes les commandes `BucketCmd.ReqOpen`.  
6. Si F2 déclenche `AX18_DONE_SYNC`, forcer `TranslationCmd.ReqStart := FALSE` dans la transition ou dans `AX18`, sinon la translation peut continuer après la fin de cycle.

5. Interaction `PRG_04_Treuils_Benne.st:1083` et `FB_Modes.st:372`  
1. `PRG_04_Treuils_Benne.st:1083` : si l’expression réelle contient déjà `OR ReqProgram.ReqBucket.ReqOpen`, F2 est déjà couvert pour `WinchDescentAuth_M3`. Ne pas ajouter de doublon. Vérifier que `ReqOpen` reste vrai assez longtemps pendant l’ouverture en PV.  
2. `FB_Modes.st:372` : si `M3AtTremie` est affecté uniquement par `Translation_At_Tremie`, F2 sera bloqué. Solution recommandée : exposer `PvDumpActive` du `FB_CycleSemiAuto` vers `FB_Modes` sous forme `DumpInPvActive`, puis :
```st
M3AtTremie := Translation_At_Tremie OR DumpInPvActive;
```
3. Ne pas utiliser `Translation_PosPV` seul dans `M3AtTremie` : le chariot peut quitter la zone PV avant que `Benne_IsOpen` ne devienne vrai.  
4. Si `M3AtTremie` est consommé par d’autres séquences, ne pas le forcer globalement. Créer plutôt un signal local `M3AtTremie_Cycle` utilisé uniquement par la condition de retour / `AX18`. Risque sinon : d’autres modes croient être à la trémie alors que le chariot n’y est pas.

6. Recommandation  
1. Variante A si contrainte de diff minimal et pas de modification d’énumération/HMI.  
2. Variante B si mise en service avec besoin de diagnostic clair : `AX14B_DUMP_IN_PV` isole F2 et `AX15_PAUSE_DUMP` matérialise F1.  
3. Choix recommandé : Variante B pour une mise en service industrielle, sous réserve de l’axe Y dédié et du bypass `M3AtTremie`. Variante A reste acceptable en correctif chaud si le latch est strictement reseté au cycle.

7. Plan d’action chirurgical  
1. Localisation : `FB_CycleSemiAuto.st`, déclarations + `CASE`. Ancre : `AX14_TRANSLATE_DUMP`, lignes 1475-1501. Action : ajouter `CfgPauseBeforeDump_S`, `TglAllowDumpInPV`, `PauseBeforeDumpTimer`, `PvDumpActive`, `JoystickBucketOpen`. Outil : revue de code + compilation. Risque si ignoré : variables non déclarées, timer non appelé.  
2. Localisation : `AX15A_DUMP_ARRIVE`, lignes 1503-1534. Action : ajouter la condition `(CfgPauseBeforeDump_S <= 0.0) OR PauseBeforeDumpTimer.Q`. Outil : test unitaire ST / simulation. Risque : F1 inactif ou pause non transparente à 0.  
3. Localisation : `AX15B_DUMP_OPEN`, lignes 1536-1565. Action : conserver `DeadmanArmed AND JoystickBucketOpen`, pas `JoystickPush` générique. Outil : revue des signaux joystick. Risque : ouverture benne sur axe X.  
4. Localisation : `AX14_TRANSLATE_DUMP`. Action : latcher `PvDumpActive` uniquement sur demande d’ouverture en PV, puis l’utiliser pour `AX18`. Outil : simulation scénario PV + sortie PV avant `Benne_IsOpen`. Risque : retour bloqué ou autorisé hors PV.  
5. Localisation : `FB_Modes.st:372`. Action : `M3AtTremie := Translation_At_Tremie OR DumpInPvActive;` ou signal cycle dédié. Outil : `rg -n "M3AtTremie"` pour vérifier tous les consommateurs. Risque : F2 bloqué ou faux état trémie.  
6. Localisation : `PRG_04_Treuils_Benne.st:1083`. Action : vérifier l’exemption `ReqProgram.ReqBucket.ReqOpen`. Outil : `rg -n "WinchDescentAuth_M3|ReqBucket.ReqOpen"`. Risque : descente non autorisée malgré benne ouverte.  
7. Localisation : reset cycle. Action : `PvDumpActive := FALSE` au reset / état initial uniquement. Outil : test de deux cycles consécutifs. Risque : dump anticipé hérité du cycle précédent.  
8. Localisation : compilation projet. Action : compiler, puis simuler F1=0, F1=0.5, F2=FALSE, F2=TRUE avec ouverture en PV, F2=TRUE avec sortie PV avant `Benne_IsOpen`. Outil : compilateur ST / banc. Risque : code non prouvé.