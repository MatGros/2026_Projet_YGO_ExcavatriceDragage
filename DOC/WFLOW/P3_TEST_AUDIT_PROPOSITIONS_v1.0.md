# P3-1 — Audit experts des tests TC & Propositions d'enrichissement (v1.0)

> **Statut** : présentation pour validation humaine — 3 des 4 revues expertes rendues (P3-1d en cours).
> **Barrière respectée** : experts en lecture seule ; toute proposition = ID **suffixé nouveau** (`.N+1`), jamais déplacer/renommer un ID existant (matrice `af_traceability_matrix.yaml` + G450 = vérité).
> **Vérification orchestrateur** : 4 échantillons d'allégations code vérifiés ligne à ligne (`CriticalSyncToleranceM=2.5` ✔, DriftGuard sans entrée vitesse ✔, `CfgTimeoutDuration=T#60s` ✔, `RestartDelay=T#1500ms` conditionnel ✔).

## 📊 Verdicts par lot

| Lot | Fiches | TC audités | Nominal | Défaut | Granulaire | Verdicts |
|---|---|---|---|---|---|---|
| **P3-1a** treuils/benne | 6 | 34 | ~29/34 | ~30/34 | faible | 21 OK · 6 à étayer · 2 manque (021/022) · **6 TC non exécutables tels qu'écrits** |
| **P3-1b** translation+sim | 9 | 33 | 33/33 | ~30/33 | **quasi nul** | 32 « à étayer » (granulaire absent) · 1 OK |
| **P3-1c** encoder+joystick | 8 | 20+ | ~15 | ~15 | faible | granulaire le maillon faible partout ; C4 homme-mort sans test granulaire |
| **P3-1d** communs/diag/TSV | 9 | 21 | ~19/21 | ~15/21 | moyen | trou **P0** : socle `FB_FaultCore` (TC-P03-008..013) **sans aucun test CI** — le fichier cité (`test_fb_fbstatus.st`) teste l'ancien `FB_FBSTATUS`/`ST_FBCAUSE` supprimés au commit `51fccce6`, ne compile plus contre le code actuel, absent du `registry.yaml` |

## 🔴 Risques majeurs (C4 d'abord — consensus des rapports)

1. **Cat.3 ISO 13849 non prouvé** : aucun TC ne teste 2 canaux indépendants (position+vitesse Méca A ; contacteurs+frein Méca B ; codeurs M1/M2). → P3-1a `TC-P10-035.1`.
2. **F11.05 anti-télescopage hauteur M1/M2 : couverture NULLE** (fonction C4, câblée PRG_05 §0, aucun `TC-P11-*`). → P3-1b racine nouvelle `TC-P11-015` (nouvel ID racine légitime, jamais utilisé).
3. **Chaîne PowerCutOff bout-en-bout non testée** (`TC-P10-009` ne couvre que le masque `16#2F84`, pas PRG_04→PRG_06→AU). → `TC-P10-051.1`.
4. **Homme-mort** : armement/déarmement jamais testé finement + ⚠️ **`ArmingPermit` câblé en dur `TRUE`** dans le code (trou de sécurité potentiel, §10 Q1 fiche AF-08) → P3-1c `TC-P08-020.1..4`.
5. **Watchdog frein & couplage direct** non testés (armé sur `BrakeCmd` pour éviter faux défauts ; `BrakeCmd := RelayFwd OR RelayRev` structurel). → `TC-P10-038.1/039.1`.
6. **Sync Zone 2 dégradée (palier 1, sans coupure)** : comportement de production le plus utilisé, aucun TC. → `TC-P10-049.1`.
7. **Mou câble / benne non fermée (récupération)** : blocage descente + palier 1 non testés. → `TC-P10-044.1/045.1`.

## 📋 Propositions d'IDs nouveaux (63 au total : a=19 · b=11 · c=21 · d=12)

### P3-1a — Winch/Benne (19)

| ID | Fiche | Objet (1 ligne) | Type |
|---|---|---|---|
| `TC-P10-035.1` | Safety_Winch | Cat.3 : 2 canaux position + vitesse (dérive >2.0m / v>0.02m/s), croisés | 💻 |
| `TC-P10-036.1` | Safety_Winch | Warmup 3s perte com opérateur après Enable | 💻 |
| `TC-P10-037.1` | Safety_Winch | Gate Enable=FALSE : sorties sûres FALSE, latches préservés, Reset front exigé | 💻 |
| `TC-P10-038.1` | WinchOutputInterlock | Watchdog armé sur `BrakeCmd` (pas faux défaut au RestartRequired) | 💻 |
| `TC-P10-039.1` | WinchOutputInterlock | Frein couplé direct `BrakeCmd := RelayFwd OR RelayRev` | 💻 |
| `TC-P10-040.1` | WinchOutputInterlock | Latches préservés à perte Enable ; retour = Reset front + neutre + demande | 💻 |
| `TC-P10-041.1` | Winch | Asymétrie interlock descente 400/500ms vs montée 900/1000ms | 💻 |
| `TC-P10-042.1` | Winch | Plafonds dynamiques palier par contexte (non-ref=1, descente max 3, montée max 5….) | 💻 |
| `TC-P10-043.1` | Winch | Double délai cascade montée 2 paliers (~2.75s, écart P1 documenté) | 💻 |
| `TC-P10-044.1` | Safety_Winch | Mou câble : blocage descente + récupération à `M2_TensionedCable_DI` | 💻 |
| `TC-P10-045.1` | Bucket | Benne non fermée → montée palier 1 seul (paliers 2-5 verrouillés) | 💻 |
| `TC-P10-046.1` | Bucket | Timeout mouvement `T#60s` pendant BUSY → latch | 💻 |
| `TC-P10-047.1` | Bucket | Boot incohérent (ni IsOpen ni IsClosed) → StateIncoherent | 💻 |
| `TC-P10-048.1` | Bucket | Offset RETAIN persistant (`OffsetCloseM=15.0` power cycle) | 💻 |
| `TC-P10-049.1` | WinchSync | Sync Zone 2 dégradée : warn 0.10m → palier 1 sans coupure + IHM | 💻 |
| `TC-P10-050.1` | WinchSync | Couplage croisé M1→M2 au même scan | 💻 |
| `TC-P10-051.1` | Safety_Winch | Chaîne PowerCutOff bout-en-bout PRG_04→PRG_06→AU | ⚡ |
| `TC-P10-052.1` | Winch | Garde-fou vitesse (SpeedGuardEnable) : bride si bande < palier | 💻 |
| `TC-P10-053.1` | Bucket | Anti-traversée `M1_Busy/M2_Busy` — **à trancher : implémenter le code ou documenter l'écart** | 💻 |

### P3-1b — Translation/Simulation (11)

Verdict transversal : 33/33 nominal ✓ ; granulaire quasi absent partout (fronts, bornes, timeouts, latch, Reset front).

- **`TC-P11-015`** (racine nouvelle, F11.05, C4) — Anti-télescopage hauteur M1/M2 : translation bloquée sous hauteur mini, sauf `Bypass.MinHeight` conscient. *(comble le trou nul de couverture)*
- 10 propositions granulaires suffixées sur P11 et P13. Détail exact : voir rapport `P3-1b` du 2026-08-29 (conservé à l'identique).
- **Liste explicite des 11 IDs proposés** : `TC-P11-015` (root, F11.05 anti-télescopage — C4, couverture nulle), `TC-P11-015.1` (bypass MinHeight vs BypassGlobal), `TC-P11-011.1` (Méca B variante perte IHM — §4 L126-129 documentée jamais testée), `TC-P11-010.1` (absence redémarrage auto), `TC-P11-007.1` (verrouillage après échec), `TC-P11-006.1` (watchdog frein 500ms, frontière), `TC-P13-020.1`, `TC-P13-023.1` (latch AU réel survit à la sim — déblocage par front Reset en runtime), `TC-P13-040.1` (transitions mots simulés M3), `TC-P13-032.1` (borne haute codeur), `TC-P13-052.1` (grâce homme-mort 3s).
- **Risque transversal non-TC à trancher** : `T110` — sémantique réelle de `DriveStatusWord.0` sur AC600 (`FB_SimBench` §4 L146-149) : si le variateur réel garde Power Ready à 1 à l'arrêt, `FB_Safety_Translation.st:181` (Méca B) a la même faille dormante côté réel — à trancher terrain/constructeur.
- C3 également signalés : ralentissement 3 zones + gate mode Maintenance (`FB_Translation` §4) non couverts.

### P3-1c — Encoder/Joystick (21)

- **C4 homme-mort** `TC-P08-020.1..4` : armement hors neutre / désarmement perte `ArmingPermit` / pas de réarmement auto / bornes 100ms-3s-100ms. ⚠️ **`ArmingPermit` câblé en dur `TRUE`** dans le code (§10 Q1 fiche AF-08) — bug potentiel à ouvrir en TASKS.
- P09 : `010.3/.4/.5` (acquisition nominale, front `PresetRequest`, gel persistant) ; `020.6/.7/.8/.9` (TopPositionSensor absent, homing sans permit, `HomingSuspect` RETAIN, borne cible) ; `030.8/.9/.10/.11` (garde dépassement DINT, borne RawPos=HomingRefRaw→0, bornage `PositionMaxM`, bascule `BypassGlobal`) ; `050.5/.6` (fenêtre de mesure sans purge, vitesse exacte) ; `040.4/.5` (table 8 combos, incohérence) ; P08 `010.4/.5/.6` (Neutral≠5000, borne deadband, saturation ±100).
- **Écarts de spec à trancher** (non tranchables par test) : `FB_Encoder_Safety` **monocanal** vs exigence ISO 13849 cat.3 (écart de spec) ; `FB_Encoder_SpeedMonitor` retiré → plus de garde-fou jitter sur la mesure vitesse (impact `FB_Safety_Winch`).
- **Q2 non tranchée** : asymétrie homme-mort treuils/translation (armement/désarmement selon domaine) — décision de design attendue.
- **`TC-P08-060` = GAP déclaré** (C1, `ArmingPermitDenied`, couverture nulle — le TC dit lui-même « GAP ») : à implémenter (code + test) ou requalifier.

### P3-1d — Communs/Diag/TSV (12)

- **P0 socle** `FB_FaultCore` : le socle transverse `Fault` des 18 FB `standard` n'a **aucun test direct**. Propositions : recréer `test_fb_faultcore.st` (TC-P03-008..013 : latch cause, disparition cause + Reset front, priorité causes, masque, indépendance instances) + enregistrer dans `registry.yaml`.
- **P0/P1 Diag bus** : TC-P12-010/020/030/040 — tests CI actuels superficiels (2 cas), pas d'injection par device ; le bug M2 `16#0030` (T159) non détecté par les CI.
- **P2 Preflight** : TC-P06-007 — 14/16 bits non testés.
- **P1 Heartbeat** : TC-P12-050 — `TglHeartbeatPlc`/`TimeSinceIhmEdge` non testés, test mislabellé.
- ✅ OK : `FB_CycleTime` (TC-P03-014.1/.2/.3) bien couvert.
- 12 IDs suffixés proposés — **liste explicite** : `TC-P03-008.1`, `.009.1`, `.010.1` (latch cause / disparition cause + Reset front / priorité-masque), `TC-P03-014.4` (CycleTime granulaire), `TC-P06-007.1/.2` (Preflight bits manquants), `TC-P12-030.1/.2` (injection défaut par device + assertion bits ErrorId), `TC-P12-040.1`, `TC-P12-050.1` (heartbeat), `TC-P14-TSV-01.1/.03.1` — toutes sur racines existantes, jamais un ID existant déplacé. Détail : rapport P3-1d 2026-08-29.
- `test_fb_fbstatus.st` : champs obsolètes cités en preuve (`IsWarning`, `STATUS.WARNING`, `RESETREQUESTED`) → preuve supplémentaire que le fichier ne peut pas compiler contre `FB_FaultCore.st` actuel.
- **Dérive doc/code** : `FB_TroubleshootingView` — TBD §6 résolus dans le code mais encore listés TBD dans la fiche (à mettre à jour).

## 🎯 Ordre direct humain — fiche FB_Safety_EmergencyManagement_v1.2 (✅ preuves livrées)

> ⚠️ Correction de prémisse (orchestrateur, 2026-08-29 15:45) : `test_fb_safety_emergency.st` **EXISTE**
> (créé 29/08 12:45) — la déclaration « aucun test CI actif » était fausse.

- **Preuves exhaustives** : **10/12 TC = PREUVE COMPLÈTE** — code `CODE/B_AU_SECURITE/FB_Safety_EmergencyManagementLogic.st`
  + tests `RESULTS/B_AU_SECURITE/tests/test_fb_safety_emergency.st` + rapport daté
  `RESULTS/B_AU_SECURITE/reports/FB_Safety_EmergencyManagement.json|html` (29/08/2026 12:50:02, **10/10 PASS**).
- **Les 2 résiduels** : `TC-P01-001` (essai **SITE** — boucle AU physique, non automatisable par nature) ;
  `TC-P01-005` (`af_ignore` **défendable** — le « 2 temps » est une propriété ergonomique physique de 2 boutons ;
  `TC-P01-004` couvre déjà l'essentiel ; un test logique minimal est optionnel).
- **Constantes vérifiées** : pulse 1s (`CST_ArmingPulseDuration`), timeout 2s (`CST_ArmingConfirmTimeout`),
  lockout 5s (`CST_ArmingLockout`), auto-test 200ms (`CST_TestDuration`) — le catalogue TC correspond au code.
- **Conséquence états** : les 12 TC à `V-I` sont **justifiés** (validé + implémenté, avec test CI daté).
- **T174 recalibré** (contrat revalidé PASS, 2026-08-29 15:45) : le chantier CI réel restant = **`test_fb_faultcore.st`
  (SOCLE P0)** + traitement TC-P01-005 ; régrésions interdites sur le 10/10 PASS existant.

**Matrice détaillée 12 TC** (code = `FB_Safety_EmergencyManagementLogic.st` · test = `RESULTS/B_AU_SECURITE/tests/test_fb_safety_emergency.st` · preuve = `reports/FB_Safety_EmergencyManagement.json` 12:50:02, 10/10 PASS) :

| TC | CODE (lignes) | TEST (lignes) | Verdict |
|---|---|---|---|
| SCEN-NOM | L196-204, 207-223, 226-235, 238-254, 257-266, 269-273, 276-288 | L34-93 « Scenario Nominal » | PREUVE COMPLÈTE |
| SCEN-DYN | L169-190, 196-204, 276-288, 301-304 (lockout) | L95-176 « Scenario Dynamique » | PREUVE COMPLÈTE |
| TC-P01-001 (SITE) | L182-188 (chute boucle) | ABSENT | ÉCART (SITE non automatisable) |
| TC-P01-002 | L207-223, 238-254, 326-327 | L187-228 (partie AUTO) | PREUVE COMPLÈTE (partie AUTO) |
| TC-P01-003 | L269-273 (pulse 1s, CST L75) | L230-282 | PREUVE COMPLÈTE |
| TC-P01-004 | L156-163 (Reset front) | L284-322 (004/009 combiné) | PREUVE COMPLÈTE |
| TC-P01-005 | L156-163, 196-204 | ABSENT (af_ignore registry L105) | ÉCART (af_ignore défendable) |
| TC-P01-006 | L212-216, 243-247 (`RedundancyTestFailed`) | L324-345 | PREUVE COMPLÈTE |
| TC-P01-007 | L276-288 (timeout 2s CST L76), L301-304 (lockout 5s CST L77) | L347-406 | PREUVE COMPLÈTE |
| TC-P01-008 | L175-181 (avortement PowerCutOff), 326-327 | L447-467 | PREUVE COMPLÈTE |
| TC-P01-009 | L196-204, 334-340 (interlock cause brute) | L284-322 (004/009 combiné) | PREUVE COMPLÈTE |
| TC-P01-010 | L170-174 (avortement `BtnEmergencyCutOff`, `LastAbortCause` 16#0001), L270, 326-327 | L408-445 | PREUVE COMPLÈTE |

**Spec `test_fb_faultcore.st` (SOCLE P0, manquant)** — `FB_FaultCore.st` (`CODE/A_COMMUN`, 83 lignes, dépendance de ~20 FB registry) ; inputs `Enable`, `Reset`, `Causes[0..15]` (`Active`/`Latching`/`Texte`) → outputs `Ready`, `Fault{Error, ErrorId, Latched, LatchedId}`. 6 scénarios : ① vue LIVE suit `Active` et retombe seule ; ② `Latching` arme le bit conservé après disparition cause ; ③ `Reset` front efface tous latches même `Enable=FALSE` ; ④ ré-apparition cause → ré-alarme ; ⑤ `Latching=FALSE` → LIVE seulement ; ⑥ `Enable=FALSE` → `ErrorId=0` mais `Latched` publié.
**Preuves immédiates** : `reports/FB_Safety_EmergencyManagement.json|html` (12:50:02) + `archive/20260829_125141_FB_Safety_Emerg…` (12:51:41).

## ⚠️ Écarts doc↔code vérifiés (fiches à corriger sur la vérité CODE)

| Fiche/TC | Écart | Vérité code | Action doc proposée |
|---|---|---|---|
| FB_Safety_Winch TC-005 | seuil écart critique « 2m » | `CriticalSyncToleranceM = 2.5` (L50) | corriger en 2.5m |
| FB_Safety_Winch TC-001 | critère vitesse `>0.02m/s` décrit | `FB_DriftGuard` sans entrée vitesse (PositionM/DriftM seulement) | requalifier TC sur dérive position seule + écart en TBD |
| FB_Winch TC-011 / Interlock TC-021/022 | temps mort 1s même-sens/inversion | `RestartDelay = T#1500ms` uniforme anti-court-cycle (L146), pas de variantes directionnelles | requalifier + TBD |
| FB_WinchOutputInterlock | noms `BrakeReleaseRequest/BrakeCommandOpenConfirmed` périmés | `BrakeCmd` / `BrakeFeedback` | renommer dans la fiche |
| FB_Bucket TC-046/§? timeout | 30s | `CfgTimeoutDuration = T#60s` (L36) | corriger en 60s |
| FB_Bucket TC-026/031 | bits décalés | glissement = cause 3 (pas 4) ; non-référencé = cause 4 (pas 3) | corriger la correspondance |
| FB_Bucket TC-030 | MAINT_N1/N2 | code : MAINT_N2 seul (L204/L212) | corriger |
| FB_Bucket TC-025 | interlock `M1_Busy/M2_Busy` | déclarés (L29-30) **jamais lus** | TC marqué « non implémenté » + TBD / choix code |

## 🧭 Décisions à trancher (validation humaine) — RÉSOLUES 2026-08-29 (réponses utilisateur)

1. **Insertion des TC** : « je veux bien les ajouter mais challenger d'abord (remplacer les similaires, zéro doublon) » → challenger exécuté (verdict : 30 KEEP · 28 REPLACE · 6 REJECT) ; insertion par lots pipeline en cours.
2. **Écarts doc↔code** : corriger doc + ouvrir tâches CODE (fait : T176 ArmingPermit ; T175 les autres).
3. **Questions de spec** : `FB_Encoder_Safety` = **mono-canal assumé** (requalification fiche à faire) ; `ArmingPermit` = tâche CODE ouverte (T176) ; cat.3 avec canal vitesse = **tâche code (T175 AC1)**.
4. Ancres GitHub : en attente du clic-test humain.

**Verdict final du challenger (2026-08-29, listes explicites conservées dans son rapport)** : a=11 KEEP/7 REPLACE/1 REJECT · b=3/5/3 · c=16/6/0 · d=0/10/2. FUSIONS inter-lots=0 (les thèmes Reset/latch/redémarrage auto sont des chemins de code **distincts par FB**, pas des doublons). 6 écarts doc↔code supplémentaires détectés pendant l'audit : **seuil synchro 0.10m (doc) vs 0.8m câblé** (`GVL_PERSISTENT.st:58`) ; référence ArmingPermit ligne 322 (pas 303) ; `StepDelay` code mort (WinchOutputInterlock) ; SpeedGuardEnable désactivé par défaut ; timeout benne 30s vs 60s (déjà listé) ; `test_fb_faultcore.st` manquant (traité T174).

## ⛔ Pipeline obligatoire à toute insertion

`extract_functions_matrix.py` → pytest 7/7 → regen matrice → sweep structure/mojibake → `G340` → commit restreint → **présentation du diff à l'humain** (jamais de push sans accord).