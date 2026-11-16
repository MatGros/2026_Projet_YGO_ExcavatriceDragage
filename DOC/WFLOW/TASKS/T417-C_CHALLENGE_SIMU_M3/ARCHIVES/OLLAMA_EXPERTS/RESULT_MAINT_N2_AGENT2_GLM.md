🟡 **ADVISORY** — Audit du verrouillage `MAINT_N2` (M1/M2 solo/couplé) livré : inventaire exhaustif des verrous + patchs ST rédigés. Aucune preuve mécanique exécutée ici (pas d'accès dépôt) → mise sous tension réelle interdite avant compilation + matrice de simulation passée. Durée/Horodatage : n/a (analyse statique).

Note unique : aucun accès dépôt ni `AGENTS.md` dans cette session ; l'analyse repose exclusivement sur les extraits verbatim fournis (Étapes A–F). Tout « ✅ » ci-dessous = preuve statique de lecture d'extrait, pas d'exécution.

---

## Niveau 1 — Invariants

1. `[✅ PASS]` **Inventaire exhaustif des verrous établi et classé** (28 items, détail en Niveau 2) : arbitrage sélection A1–A2, descente B1 (+D6), conditions d'exécution C1–C7, permis processus D1–D5, causes SafeStop/PowerCutOff E, coupures sortie F1–F7.
2. `[✅ PASS]` **Verrous qui bloquent déjà MAINT_N2 aujourd'hui** : A1 (M3 à trémie force `WinchSel:=2`, M1/Both impossible), A2 (séquence benne force M2 seul, Both impossible), B1+D6 (M3 pas à P1/AtMaintenance → descente M1 **et** M2 forcée FALSE), D1 (Kobold latched), D2 (benne plongée pas ouverte), D3 (ExtractionAssist), D1-variante cable-limit/LimitLegal/slack, C4 (bucket block), C5 (défaut synchro → direction bloquée), E défauts actifs sans bypass (encoder, thermal, phase, meca, op-comm), C6 deadman (voulu).
3. `[✅ PASS]` **Séparation conforme à votre exigence** : auto-lift dès N2 = tout verrou *processus/mode* (A1, A2, B1, D1–D4, slack/cable-limit/LimitLegal, C3–C4, C5 en solo). Bypass **explicite** (panneau `Bypass.*` déjà câblé)= encoder, thermal moteur/frein, phase rotation, meca A–E, `TopPositionSensor`, `MecaD`, op-comm, sync (déjà `Bypass.Global`).
4. `[✅ PASS]` **Barrières non négociables conservées même en N2** : AU physique `PowerContactorEngaged_DI`, deadman joystick (C6), `RequestConflict`/`CauseOppositeDirActive` (C1/E), `ContactorStuckLatched` (F6), timeout frein 500 ms (F4), `RestartInhibit` (F5), SafeStop croisé en couplé (D7-l.1103), discordance sync en couplé (F7), pas de mouvement combiné avec la benne (C7).
5. `[❌ FAIL]` **Exigence littérale « dans n'importe quel défaut, sans condition »** : partiellement contre-indiquée. Auto-relâcher *thermal / meca / stuck contacteur / timeout frein* pendant qu'on pilote des contacteurs à la main supprime la seule protection au moment de la manœuvre manuelle. Recommandation ferme : bypass par panneau (déjà existant) au lieu d'auto-lift — décision opérateur D2. Tant que D2 n'est pas tranchée, aucun patch « tout forcer » n'est délivré.
6. `[❌ FAIL]` **Garantie « solo M1 / solo M2 / Both en N2 » en l'état du code** : non tenue (voir invariant 2). Tenue après application P1–P4, sauf défaut *matériel* sur le treuil sélectionné (alors : opérer l'autre en solo, voir D3).
7. `[⚪ N/A]` **Patchs compilés/exécutés** : non fait ici (pas d'accès dépôt). P1–P5 sont des proposals à ancrer sur diff réel, compile, puis simulation.
8. `[⚪ N/A]` **Inconnues repo à lever avant mise en service** : U1 source exacte de `Enable` (étape F, l.153-244) ; U2 termes tronqués « `AND ...` » des permis M2 ; U3 lieu de construction de `Context.{BucketBusy, WinchBothMotionBlockedByBucket, SyncBlocks*, M*MotionBlocked}` ; U4 source de `BothIntent.Active` ; U5 effet des variantes `BypassM1*Eff` (mode-gated ?) ; U6 `SyncActive`/`SyncBlocks` actifs en solo ou seulement couplé ; U7 existence d'un écran dédié « test contacteurs ».
9. `[✅ PASS]` **MAINT_N1 inchangé** par les patchs (le bloc N1+N2 mutualisé est scindé ; comportement N1 recopié tel quel) — décision D5 à confirmer.
10. `[✅ PASS]` **Couplé avec un treuil en défaut matériel reste bloqué après patch** (permis croisés l.1103-1114 conservés volontairement) : c'est cohérent avec le besoin (l'opérateur sélectionne alors le treuil sain en solo).

## Niveau 1 bis — Argumentaire technique

La chaîne n'interdit pas MAINT_N2 en soi : le bloc arbitrage (Étape A) *écrase* la sélection (force `2`), la séquence benne *verrouille la phase* sur M2, et `WinchDescentAuth_M3` (Étape B) coupe en cascade les permis de descente des deux treuils (Étape D l.1083). Corriger au niveau des permis un par un serait fragile : le point de coupure amont unique est l'arbitrage (A) et `WinchDescentAuth_M3` (B). Un signal unique `Auth.MaintN2DirectControl := (Auth.Mode = E_Mode.MAINT_N2)` publié par `FB_Modes` devient l'unique facteur de release process, consommé en B (OR), en D (OR sur permis process), et en F (OR sur `Enable`) — un seul point de définition, zéro duplication de mode. Les défauts machine (Étape E) ne sont pas modifiés : le panneau `Bypass.*` existant est précisément le mécanisme prévu pour « travailler en défaut », il suffit de garantir qu'aucun autre verrou amont ne l'empêche d'agir. Les protections contacteur (stuck, timeout frein, contradiction, restart) sont indépendantes du mode et ne bloquent qu'une machine déjà défaillante : les garder satisfait « réserve AU + homme-mort » de votre exigence sans brûler de contacteurs pendant une manœuvre manuelle.

## Niveau 2 — Plan d'action chirurgical

**P1 — `CODE/F_MODES/FB_Modes.st`** — Ancre : l.364 `IF (Auth.Mode = E_Mode.MAINT_N1) OR ...` — Action : scinder N1/N2 ; en N2 : selection libre + neutralisation phase benne :
```iecst
IF Auth.Mode = E_Mode.MAINT_N2 THEN
    Auth.CoupledBucketPhaseLocked      := FALSE;
    BucketSeqSatisfied                 := FALSE;
    Auth.JoystickWinchSelectArbitrated := JoystickWinchSelectRequest;
ELSIF Auth.Mode = E_Mode.MAINT_N1 THEN
    // recopier l'ancien bloc (M3AtTremie / séquence / ELSE) tel quel
ELSE
    Auth.JoystickWinchSelectArbitrated := 0;
    BucketSeqSatisfied                 := FALSE;
END_IF;
Auth.MaintN2DirectControl := (Auth.Mode = E_Mode.MAINT_N2);
```
Ajouter `MaintN2DirectControl : BOOL` à la sortie de `FB_Modes` (DUT/struct `Auth`). — Outil : `rg -n "JoystickWinchSelectArbitrated|CoupledBucketPhaseLocked" CODE/F_MODES/FB_Modes.st` avant/après. — Risque si ignoré : A1/A2 continuent d'écraser la sélection en N2 (M1/Both impossibles à la trémie).

**P2 — `CODE/M_MAIN/PRG_03_Modes_Cycle.st`** — Ancre : l.511-516 — Action :
```iecst
Data.SequenceState.WinchDescentAuth_M3 :=
    Data.Auth.MaintN2DirectControl
    OR NOT GVL_IHM.Commun.Cfg.TglEnableWinchDescentLock_M3
    OR GVL_IHM.M3Translation.State.AtP1
    OR GVL_IHM.M3Translation.State.AtMaintenance
    OR GVL_IHM.M3Translation.Bypass.LimitSwitch
    OR GVL_IHM.M3Translation.Bypass.Global;
```
— Outil : `rg -n "WinchDescentAuth_M3" CODE/` (repérer aussi les autres consommateurs, U8). — Risque si ignoré : descente M1/M2 forcée FALSE en N2 dès que M3 n'est pas à P1/AtMaintenance.

**P3 — `CODE/M_MAIN/PRG_04_Treuils_Benne.st`** — Ancre : l.771-799 — Action : renommer chaque permis existant en `_Raw` puis relâcher par le facteur unique (aucun terme tronqué modifié) :
```iecst
MaintN2ReleaseProcess := PRG_03_Modes_Cycle.Data.Auth.MaintN2DirectControl;
ProcessPermitM1_Descend_Raw := <ligne existante 771>;
ProcessPermitM1_Descend     := ProcessPermitM1_Descend_Raw OR MaintN2ReleaseProcess;
// idem ProcessPermitM1_Ascent_Raw/Released
// idem ProcessPermitM2_Descend_Raw/Released (termes tronqués U2 intacts)
// idem ProcessPermitM2_Ascent_Raw/Released
```
**P3b** — ancre `rg -n "BucketBusy|WinchBothMotionBlockedByBucket" CODE/H_TREUILS_BENNE CODE/M_MAIN` : à la construction du `Context` (U3), ajouter `AND NOT MaintN2ReleaseProcess` aux contributions *process* de `BucketBusy` et `WinchBothMotionBlockedByBucket`. — **P3c** : `SyncBlocksAscent := SyncBlocks_Raw AND NOT (MaintN2DirectControl AND NOT BothIntent.Active);` (idem Descent) — release sync **en solo uniquement** ; en Both, sync conservée (équilibrage de charge). — Risque si ignoré : Kobold/benne-ouverte/ExtractionAssist/couple-sync bloquent N2.

**P4 — `CODE/M_MAIN/PRG_04_Treuils_Benne.st`** — Ancre : l.1083 — Action (redondance défensive) :
```iecst
IF NOT PRG_03_Modes_Cycle.Data.SequenceState.WinchDescentAuth_M3
   AND NOT PRG_03_Modes_Cycle.Data.Auth.MaintN2DirectControl THEN
```
— Risque si ignoré : tout autre falsificateur futur de `WinchDescentAuth_M3` réintroduirait le blocage descente.

**P5 — `CODE/M_MAIN/PRG_06_Outputs.st`** — Ancre : l.153-244 — Action (pattern identique, aucun autre critère de coupure touché) :
```iecst
Enable_Raw := <expression existante>;   // U1 : localiser exactement
Enable     := Enable_Raw OR PRG_03_Modes_Cycle.Data.Auth.MaintN2DirectControl;
```
— **Ne pas toucher** : `SafeStop`, `PermitFinalBlocked` (résolu amont), `Error` (frein 500 ms), `RestartInhibit`, `ContactorStuckLatched`, `instSyncContactorFinal` (discordance couplé conservée, sauf `Bypass.Global` existant). — Risque si ignoré : `Enable` false en N2 coupe les sorties malgré permits libérés.

**Variante B (déconseillée — décision D2 obligatoire, feature-flag dédié `MaintN2ForceAllFaults`)** : ajouter `OR (MaintN2DirectControl AND MaintN2ForceAllFaults)` uniquement aux entrées `Bypass*Eff` encoder/thermal/phase/mecaA–E/op-comm (l.941, 972-991). Jamais sur : `TopPositionSensor`, `MecaD`, OppositeDir, NoMovement, Stuck, timeout frein, sync-mismatch couplé.

**Preuves à produire (coordonnateur, ordre obligatoire)** : (1) `rg` ci-dessus + diff réel relu ; (2) compile complète ; (3) simulation HIL — matrice 3 sélections {M1, M2, Both} × {sain ; codeur HS + bypass posé ; Kobold latched ; M3 ailleurs + lock actif ; défaut synchro (attendu : Both bloqué, solo OK) ; slack câble ; thermal + bypass posé} en MAINT_N2 : la commande doit atteindre les bobines contacteur sous réserve du keep-list (invariant 4) ; (4) régression modes NORMAL/N1 sur la même matrice : blocages intacts ; (5) machine réelle : uniquement après autorisation + procédure écrite (AU vérifiée, deadman vérifié par manœuvre, premier essai en solo, impulsions courtes, une personne aux arrêts). Ne jamais prendre une sim pour preuve terrain.

**Décisions opérateur requises** : D1 valider le keep-list (invariant 4) ; D2 variante B oui/non (recommandation : **non**) ; D3 Both avec un treuil en défaut matériel → recommandé : opérer le treuil sain en solo ; D4 boutons IHM M1/M2 : exiger un maintien appuyé (hold-to-run) équivalent homme-mort si absent (U7) ; D5 confirmer MAINT_N1 inchangé ; D6 `NoMovement` conservé en N2 (recommandé) — il bloquera un test contacteur freins serrés, prévoir frein levé pour ce test.

**Inconnues repo (blocants avant mise en service)** : U1 source de `Enable` ; U2 lignes complètes des permis M2 ; U3 construction `Context.*` ; U4 `BothIntent.Active` ; U5 sémantique `*Eff` ; U6 `SyncBlocks` en solo ; U7 écran test contacteurs ; U8 autres consommateurs de `WinchDescentAuth_M3`.

Verdict par critère : critère 1 (inventaire) PASS ; critère 2 (séparation) PASS avec 1 réserve (D2) ; critère 3 (patchs) livré non compilé → ADVISORY ; garantie terrain sous réserve de D2/D4 et matrice de simulation passée. Décision recommandée : appliquer P1–P5 sans variante B, trancher D2 en réunion sécurité, puis run de la matrice HIL.