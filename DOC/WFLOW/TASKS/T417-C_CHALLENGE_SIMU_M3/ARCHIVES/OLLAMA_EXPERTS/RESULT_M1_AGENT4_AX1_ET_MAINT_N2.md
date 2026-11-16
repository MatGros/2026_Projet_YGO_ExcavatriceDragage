🟡 **ADVISORY** — Patchs `AX1_INIT` (F3) et levée des verrous `MAINT_N2` rédigés sur la base des extraits cités ; **aucun PASS revendiqué** : pas d'accès fichier dans cette session, donc verrous 2/3 non relus au caractère près et énumération exhaustive `PRG_04`/`PRG_06` impossible. 2 sous-gates **🔴 BLOCK** s'appliquent à l'**application** (sécurité collision M1/M3, nature SIL des limit switches).

---

## Niveau 1 — Invariants

1. **Part 1 — 3 messages distincts, chacun < 70 car. (G408)** — `[✅ PASS (comptage manuel)]` : 23 / 27 / 48 caractères. **Gate G408 non exécuté** (voir inv. 9).
2. **Part 1 — bit IHM `TglRelaxSemiAutoStart`** — `[🟡 ADVISORY]` : déclaration + câblage proposés, mais nom de la GVL IHM existante (`GVL_HMI`) non vérifié.
3. **Part 1 — logique `AX1_INIT` assouplie (fenêtre + dispense benne) sans toucher au terme M3** — `[✅ PASS (design)]` ; valeur `CST_CycleInitWindowMRelax` à valider exploitant `[🟡]`.
4. **Part 1 — chemin encodeur M2** — `[⚪ N/A]` : le code d'origine ne lit que `EncoderM1`. Je conserve à l'identique, aucune invention de `EncoderM2`.
5. **Part 2 — Verrou 1 (`FB_Modes.st:364-396`)** — `[✅ PASS (citation exacte disponible)]` : override confirmé, patch fourni.
6. **Part 2 — Verrou 2 (`WinchDescentAuth_M3`, `PRG_03:511-516`)** — `[🟡 ADVISORY]` patch gabarit (substitution requise) + `[🔴 BLOCK sécurité]` : c'est vraisemblablement un anti-collision M1/M3 ; bypass = risque machine.
7. **Part 2 — Verrou 3 (`ProcessPermitM1/M2_Descend`, `PRG_04:771-799`)** — `[🟡 analyse]` + `[🔴 BLOCK application]` : `KoboldBottomTouchLatched` / `ManualBucketLimitsActive` à classer **sécurité (SIL)** vs **process** avant tout bypass.
8. **Part 2 — autres verrous `PRG_04`/`PRG_06`** — `[🔴 BLOCK]` : non énumérables sans lecture fichier ; commande de balayage fournie (inv. technique).
9. **Exécution déterministe (G200 / G408 / G521 / pytest)** — `[🟡 non exécutée]` : aucune preuve mécanique produite, verdict limité.

---

## Niveau 1 bis — Argumentaire technique

**Inv. 1 (messages)** — Les 3 chaînes respectent la contrainte G408 sans dépendre d'une règle de troncature. Toutefois G408 est un *gate*, pas un comptage manuel : il doit être relancé pour PASS mécanique. Priorité d'affichage : M3 → zone haute → benne (l'ordre des `ELSIF` définit laquelle des 3 raisons est montrée si plusieurs bloquent).

**Inv. 2/3 (assouplissement)** — Le patch sépare bien `WinchesAtTopOk` (physique) de `BucketQualified` (qualification), puis n'assouplit **que** la dispense benne et l'élargissement de fenêtre, sous `TglRelaxSemiAutoStart AND WinchesAtTopOk`. Le terme M3 (`NOT M3_AtMaintenanceStable`) est **laissé intact** : il n'entre pas dans le périmètre de relaxation demandé. La publication `GVL_CycleDiag.*` alimente les 3 messages du FB sans recalcul divergent.

**Inv. 5 (verrou 1)** — Le quote est exact et suffisant : `MAINT_N1` et `MAINT_N2` partagent la branche, et les deux overrides forcent `JoystickWinchSelectArbitrated := 2`. La correction minimale est d'ajouter le prédicat `Auth.Mode = E_Mode.MAINT_N1` aux deux branches d'override, laissant N2 retomber sur l'arbitrage par défaut (`JoystickWinchSelectRequest`).

**Inv. 6/7 (verrous 2/3)** — Je ne dispose que des **descriptions**, pas des lignes exactes : les patchs sont des **gabarits** à substituer. Surtout, `WinchDescentAuth_M3` (nom = autorisation corrélée position M3) et `KoboldBottomTouchLatched` ressemblent à des **interlocks de sécurité/anti-collision**, pas de simple process. Lever `KoboldBottomTouchLatched` peut provoquer mou de câble/écrasement ; lever `WinchDescentAuth_M3` peut provoquer collision benne/translation. **Ces deux points ne sont pas « process » par défaut** → nécessitent arbitrage exploitant + HAZOP avant application.

**Inv. 8 (exhaustivité)** — « tout autre verrou dans `PRG_04`/`PRG_06` » exige une passe grep déterministe (ci-dessous). Sans exécution, la complétude ne peut pas être affirmée ; une revendication d'exhaustivité serait une hallucination.

**Inv. 9** — Pas de PASS sur vérification non exécutée (règle du brief). Tous les verdicts ✅ sont « sur extrait cité / comptage manuel », jamais « gate exécuté ».

---

## Niveau 2 — Plan d'action chirurgical

**1. Part 1 — 3 messages distincts**
- *Localisation :* `FB_CycleSemiAuto.st:952`
- *Ancre :* `OperatorAction := 'AX1 - Posture depart incorrecte (M3, FDC haut M1 ou benne).';`
- *Action exacte :* remplacer par le bloc `IF/ELSIF` ci-dessous, **dans le bloc conditionnel existant** qui déclenche déjà le message (ne pas changer la condition d'entrée).
```iecst
IF GVL_CycleDiag.AX1_BlkM3 THEN
    OperatorAction := 'AX1 - M3 en Maintenance';                         // 23 car.
ELSIF GVL_CycleDiag.AX1_BlkWinchHigh THEN
    OperatorAction := 'AX1 - M1/M2 hors zone haute';                     // 27 car.
ELSIF GVL_CycleDiag.AX1_BlkBucket THEN
    OperatorAction := 'AX1 - Benne non qualifiee (ni ouverte ni fermee)';// 48 car.
ELSE
    OperatorAction := 'AX1 - Posture depart incorrecte';
END_IF
```
- *Outil déterministe :* `python3 -c "import sys;[print(len(m),len(m)<70) for m in ['AX1 - M3 en Maintenance','AX1 - M1/M2 hors zone haute','AX1 - Benne non qualifiee (ni ouverte ni fermee)']]"` puis relancer **G408**.
- *Risque si ignoré :* régression gate G408 si une chaîne dépasse 70 ; message ambigu persistant.

**2. Part 1 — bit IHM + logique `AX1_INIT`**
- *Localisation :* GVL IHM (ex. `GVL_HMI`) + `PRG_03_Modes_Cycle.st:174-182`
- *Ancre :* bloc `CycleWinchesAtTopOk := ... AND (...IsClosed OR ...IsOpen); CycleInitPositionOk := ...`
- *Action exacte :* déclarer `TglRelaxSemiAutoStart : BOOL := FALSE;` en `VAR_GLOBAL`, puis :
```iecst
WinchHighZoneWinM := CST_CycleInitWindowM;
IF GVL_HMI.TglRelaxSemiAutoStart THEN
    WinchHighZoneWinM := CST_CycleInitWindowMRelax;   // fenêtre élargie (valeur à valider)
END_IF

WinchesAtTopOk :=
    PRG_04_Treuils_Benne.Data.WinchM1Safety.CableLimitAscent
    OR PRG_04_Treuils_Benne.Data.WinchM2Safety.CableLimitAscent
    OR (ABS(PRG_02_Acquisition.Data.EncoderM1.Measurement.CablePosM
            - _CommunCfgPersist.CfgCableLimitAscent_M) <= WinchHighZoneWinM);

BucketQualified :=
       PRG_04_Treuils_Benne.Data.BucketState.MechState.IsClosed
    OR PRG_04_Treuils_Benne.Data.BucketState.MechState.IsOpen;

IF GVL_HMI.TglRelaxSemiAutoStart AND WinchesAtTopOk THEN
    BucketQualified := TRUE;   // dispense qualification benne
END_IF

CycleWinchesAtTopOk := WinchesAtTopOk AND BucketQualified;
M3StableOk := NOT PRG_05_Translation.Data.M3_AtMaintenanceStable;      // INCHANGÉ
CycleInitPositionOk := M3StableOk AND CycleWinchesAtTopOk;

GVL_CycleDiag.AX1_BlkM3        := NOT M3StableOk;
GVL_CycleDiag.AX1_BlkWinchHigh := NOT WinchesAtTopOk;
GVL_CycleDiag.AX1_BlkBucket    := NOT BucketQualified;
```
- *Outil déterministe :* `grep -n "CST_CycleInitWindowM\|GVL_HMI\|M3_AtMaintenanceStable" PRG_03_Modes_Cycle.st` pour confirmer constantes/GVL avant compilation ; build CODESYS + G200.
- *Risque si ignoré :* `GVL_CycleDiag` inexistante → erreur compile ; démarrage cycle benne mal qualifiée si toggle activé (acceptation exploitant requise).

**3. Part 2 — Verrou 1 (`WinchSel` en `MAINT_N2`)**
- *Localisation :* `FB_Modes.st:364-396`
- *Ancre :* `IF M3AtTremie AND NOT AllowWinchMoveAtTremie THEN` et `ELSIF CoupledBucketSeqEnable AND (JoystickWinchSelectRequest = 0) ...`
- *Action exacte :* préfixer les **deux** conditions d'override par `(Auth.Mode = E_Mode.MAINT_N1) AND ` ; si un `ELSE` affecte déjà `JoystickWinchSelectArbitrated := JoystickWinchSelectRequest`, ne rien ajouter ; sinon ajouter :
```iecst
ELSE
    // MAINT_N2 (et N1 hors overrides) : sélection opérateur 0/1/2 respectée telle quelle
    Auth.JoystickWinchSelectArbitrated := JoystickWinchSelectRequest;
END_IF
```
- *Outil déterministe :* `grep -n "JoystickWinchSelectArbitrated\|JoystickWinchSelectRequest\|CoupledBucketSeqEnable" FB_Modes.st`.
- *Risque si ignoré :* `MAINT_N2` continue de forcer M2 seul → exigence exploitant non satisfaite.

**4. Part 2 — Verrou 2 (`WinchDescentAuth_M3`)  🔴 gate sécurité**
- *Localisation :* `PRG_03_Modes_Cycle.st:511-516`
- *Ancre :* affectation de `WinchDescentAuth_M3` (lignes non relues).
- *Action exacte (gabarit, substitution obligatoire) :*
```iecst
IF <Mode_Actif> = E_Mode.MAINT_N2 THEN
    WinchDescentAuth_M3 := TRUE;              // descente M1/M1+M2 débridée en N2
ELSE
    WinchDescentAuth_M3 := <expression_origine_511_516>;
END_IF
```
- *Outil déterministe :* `sed -n '505,525p' PRG_03_Modes_Cycle.st` pour extraire l'expression d'origine et le nom du var de mode.
- *Risque si ignoré (ou appliqué à l'aveugle) :* collision benne/translation M3. **Ne pas appliquer sans HAZOP exploitant.**

**5. Part 2 — Verrou 3 (`ProcessPermitM1/M2_Descend`)  🔴 gate sécurité**
- *Localisation :* `PRG_04_Treuils_Benne.st:771-799`
- *Ancre :* `ProcessPermitM1_Descend`, `ProcessPermitM2_Descend` (lignes non relues).
- *Action exacte (gabarit, conditionnée à la classification) :*
```iecst
IF <Mode> = E_Mode.MAINT_N2 THEN
    // Lever UNIQUEMENT les verrous de PROCESS ; conserver les limites de SÉCURITÉ
    ProcessPermitM1_Descend := NOT <SafetyM1Only>;
    ProcessPermitM2_Descend := NOT <SafetyM2Only>;
ELSE
    ProcessPermitM1_Descend := <expression_origine>;
    ProcessPermitM2_Descend := <expression_origine>;
END_IF
```
- *Outil déterministe :* `sed -n '765,805p' PRG_04_Treuils_Benne.st` pour isoler quels termes sont « latched/limits » et vérifier s'ils sont aussi traités dans la chaîne Safety SIL (`GVL_Safety`/FSoE).
- *Risque si ignoré (ou appliqué à l'aveugle) :* mou de câble / sur-course si `KoboldBottomTouchLatched` est un fin de course sécurité. **Classer avant d'appliquer.**

**6. Part 2 — Énumération « tout autre verrou » `PRG_04`/`PRG_06`**
- *Action exacte :* exécuter la passe déterministe et joindre la sortie :
```bash
grep -nE "MAINT_N[12]|ProcessPermit|Descend|Latched|ManualBucketLimits|WinchDescentAuth|JoystickWinchSelect|Kobold|CoupledBucketSeq" PRG_04_Treuils_Benne.st PRG_06*.st
```
- *Outil déterministe :* grep ci-dessus ; classer chaque hit `process` vs `sécurité`.
- *Risque si ignoré :* exigence « sans blocage process » partiellement satisfaite, verrou résiduel non détecté.

---

**Décision recommandée au coordinateur :** fusionner Partie 1 (items 1–2) après relecture GVL + relance **G408** ; sur Partie 2, appliquer **uniquement le Verrou 1** (process pur, sûr) et **geler Verrous 2 & 3** tant que la classification sécurité/process et le HAZOP M1/M3 ne sont pas actés. Fournir les sorties `sed`/`grep` des items 4–6 pour lever les deux 🔴.