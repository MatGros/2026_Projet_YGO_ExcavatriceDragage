🟡 ADVISORY — **Verdict : AUDIT PARTIEL, CERTIFICATION SÉCURITÉ IMPOSSIBLE SUR CE DIFF**

Impact : le cœur du GRAFCET (états HX0→HX4) n'est pas dans le diff fourni — seules les liaisons PRG/FB périphériques sont auditables ; 3 risques majeurs restent à lever avant validation.

Durée/Horodatage : analyse statique du diff fourni, ~n files. Aucune exécution (pas d'accès dépôt/machine).

---

### Niveau 1 — Invariants vérifiés

1. Auditabilité D1-D7 / HX0-HX4 (M3 verrou N1/SEMI, verrou MachineHomed, séquences HX1..HX4) — ❌ **FAIL (périmètre)** : le fichier `FB_CycleMachineHoming.st` n'apparaît pas dans le diff. Les conditions des 5 étapes (couple 2s, preset 8.5m, TOP coupe montée sans preset, 4s descente accumulée, attente HomingDone & NOT HomingBusy) ne sont donc **pas vérifiables**. Seul le câblage l'est.

2. Non-latch du bypass soft-limits (`SoftLimitsBypassed`) — ❌ **RISQUE MAJEUR** : `SoftLimitsBypassed := MachineHoming.SoftLimitsOff` transmis **sans garde `AND MachineHoming.Active`** (`PRG_04:~1001/1071`, consommé `FB_Safety_Winch:321/343/568/584`). Si `SoftLimitsOff` n'est pas remis à FALSE à l'abandon/échec du homing, la machine tourne en SEMI_AUTO **butées soft désactivées** → survitesse/dépassement (seules barrières restantes : TOP matériel + Méca D).

3. Mouvement benne pendant homing (purge + ReqBucket=0) — ❌ **RISQUE (blocage silencieux)** : `FB_Bucket:~487` force `CloseReached := FALSE` à chaque scan si `MachineHomingActive`, et `PRG_03:~488` force `ReqOpen/ReqClose := FALSE`. Si HX4 « CommitClose » attend `CloseReached`/fin de fermeture physique, l'étape **ne peut jamais se terminer** → deadlock sans diagnostic. À vérifier contre le FB.

4. `PowerCutOff` N2 — ⚠ **CHANGEMENT COMPORTEMENTAL** : `PRG_04:~1706/1727`, suppression de `AND NOT MaintN2`. Tout `instSafetyWinch.PowerCutOff` coupe désormais le contacteur **même en N2** (incl. homing N2). Plus sûr, mais risque d'arrêts intempestifs pendant les jogs/homing N2. Non documenté dans le diff.

5. Mode boot basé sur `Homed` — ⚠ **RISQUE RÉGRESSION** : `PRG_03:~77` lit `Data.MachineHoming.Homed` au 1er scan. Si `Homed` n'est pas reconstruit depuis le datum absolu persistant avant ce scan (ou dépend d'un cycle de homing complet), la machine boote **systématiquement en MAINT_N1** même datum intact → perte d'exploitation SEMI_AUTO.

6. Couplage sortie `WinchOutputCoupled` — ⚠ **RISQUE MAPPING** : `PRG_06:~262` n'exclut le couplage que pour `SeqStep = 1` **ou** `4`. Suppose une indexation SeqStep 0..4 = HX0..HX4 et que les étapes solo sont exactement HX1/HX4. Toute autre étape solo (ou décalage d'index) → couplage actif à tort. Non vérifiable sans le FB + struct.

7. Bypass sim retire Safety/TopLimitSwitch — ⚠ **RISQUE BANC** : `PRG_07:~386`, `Bypass.Safety` et `Commun.Bypass.TopLimitSwitch` ne sont plus armés en simulation. Les essais banc qui comptaient sur ces bypass vont désormais déclencher Méca D / TOP → faux positifs de test.

8. Pas de nouveau bug de scan IEC (TON / fronts / glitch 1-scan) dans le périmètre visible — ✅ **PASS** : aucun nouveau TON ni détection de front introduit ; `TonDatumUnreliable` ne fait que recevoir un `IN` étendu ; `SimBypassRise` préexistant. Variables ajoutées (`BrakeForceAllowedM1/M2`, `HomingFreeMoveBlockedN1`) écrites avant lecture dans le même scan. `VAR_INPUT ... := FALSE` conforme CODESYS V3.5.

9. Chaînes littérales ASCII sans accent dans les ajouts — ✅ **PASS** : `'[HOMING] Echec ou abandon referencement machine - Reset'`, `'[M1] Defaut commande ou barriere finale treuil'`, `'[CODEUR] ...'`, `'[JOYSTICK] Defaut joystick latche - Reset'` — ASCII.

10. Types stricts — ⚪ **N/A (à vérifier)** : `SeqStep = 1 / = 4` (`PRG_06`) et `LatchedId <> 16#0000` (`PRG_07`) supposent `SeqStep: INT` et `LatchedId: WORD/INT`. Si `SeqStep` est une énumération, comparaison au littéral = écart de type strict. Définitions `ST_MachineHoming` hors diff.

11. Références nouvelles GVL/HwIn — ⚪ **N/A (risque de compilation)** : `GVL_IHM.MaintenanceN2.Cmd.BtnBothBrakeRelease/BtnM1BrakeRelease/BtnM2BrakeRelease` et `HwIn.Operator.JoyBtnRaw` sont référencés sans déclaration dans le diff → compilation KO si absentes du commit complet.

---

### Niveau 1 bis — Argumentaire technique

Point 1 (déterminant) : une refonte sécurité « homing 5 étapes » ne peut être certifiée sans le bloc séquentiel lui-même. Tout le reste n'est que plomberie d'autorisations ; une erreur d'état (ex : HX2 sans preset, HX3 descente 4 s, HX4 attente `HomingDone & NOT HomingBusy`) resterait invisible ici. Impossible d'écrire « CLEAN » sans ce fichier.

Point 2 (sécurité) : les butées soft sont une barrière de survitesse. Le pattern correct est `SoftLimitsBypassed := MachineHoming.SoftLimitsOff AND MachineHoming.Active`. En l'état, la sécurité repose entièrement sur un reset correct de `SoftLimitsOff` côté FB — non prouvé. C'est le risque le plus grave du périmètre visible.

Point 3 : `CloseReached := FALSE` forcé à chaque scan pendant le homing, couplé à `ReqOpen/ReqClose := FALSE`, neutralise toute manœuvre benne par le chemin standard. Si « CommitClose » est une simple écriture de référence (pas une fermeture physique), c'est acceptable ; sinon deadlock. À trancher sur le FB.

Points 4-7 : changements de comportement réels (PowerCutOff N2, boot N1, couplage ciblé steps 1/4, bypass banc réduit) qui ne sont pas des bugs prouvés mais des régressions potentielles à valider par essai (banc + terrain). Aucune preuve mécanique fournie dans le diff.

Points 8-9 : conformité CODESYS OK sur le visible. Point 10-11 : zones grises hors diff, à confirmer par compilation (`build` CODESYS) + inspection `ST_MachineHoming`.

---

### Niveau 2 — Plan d'action chirurgical

1. Localisation : fournir/joindre `CODE/.../FB_CycleMachineHoming.st`. Ancre : états HX0..HX4 + `AllowAscent/AllowDescend/SoftLimitsOff/SeqStep`. Action : réauditer contre D1-D7. Outil : `G340`/`diff` du fichier. Risque si ignoré : certification sécurité impossible.

2. Localisation : `PRG_04_Treuils_Benne.st:~1001` et `:~1071`. Ancre : `SoftLimitsBypassed := ...`. Action : remplacer par `... := PRG_02_Acquisition.Data.MachineHoming.SoftLimitsOff AND PRG_02_Acquisition.Data.MachineHoming.Active`. Outil : `G200` (grep pattern) + revue. Risque si ignoré : butées soft perdues en exploitation.

3. Localisation : `PRG_03_Modes_Cycle.st:~488` + `FB_Bucket.st:~487`. Ancre : `ReqOpen/ReqClose := FALSE` et `CloseReached := FALSE`. Action : confirmer avec le FB que « CommitClose » n'exige pas `CloseReached` ; sinon router `CmdBucketClose` vers `ReqClose` en HX4 uniquement. Outil : revue FB + test scénario HX4. Risque si ignoré : deadlock homing benne.

4. Localisation : `PRG_04_Treuils_Benne.st:~1706/1727`. Ancre : `PowerCutOff := instSafetyWinchX.PowerCutOff;`. Action : documenter l'intention ou restaurer `AND NOT MaintN2` selon décision safety-case. Outil : revue + essai N2. Risque si ignoré : arrêts intempestifs N2.

5. Localisation : `PRG_03_Modes_Cycle.st:~77`. Ancre : lecture `MachineHoming.Homed` au 1er scan. Action : vérifier ordre de tâche PRG_02→PRG_03 et que `Homed` est reconstruit du datum persistant avant ce scan. Outil : trace/`G521`. Risque si ignoré : boot N1 permanent.

6. Localisation : `PRG_06_Outputs.st:~262`. Ancre : exclusion `SeqStep = 1 OR 4`. Action : vérifier mapping SeqStep↔HX0..HX4 et source du couplage (SyncActive/BothIntent) pendant HX2/HX3. Outil : revue FB + `G200`. Risque si ignoré : désynchro câbles ou absence de couplage.

7. Localisation : `PRG_07_Supervision.st:~386`. Action : inventaire des tests banc dépendant de `Bypass.Safety`/`TopLimitSwitch`, réexécuter. Outil : `pytest`/suite simulée. Risque si ignoré : faux positifs de test masqués.