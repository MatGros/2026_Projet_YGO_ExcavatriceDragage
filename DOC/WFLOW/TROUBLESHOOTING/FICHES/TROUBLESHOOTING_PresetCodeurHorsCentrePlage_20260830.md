# 🔴 TROUBLESHOOTING — Preset codeur hors centre-plage : perte de la sécurité anti-dépassement

> **Date** : 2026-08-30 (v2, approfondie) · **Auteur** : Claude (orchestrateur) · **Statut** : ⚠️ Rapport d'analyse, **aucune modification de code faite**
> **Composants** : `FB_Encoder_Homing`, `FB_Encoder_Abs`, `FB_Bucket`, `PRG_02_Acquisition`, `FB_Sim_Encoder`
> **Criticité** : 🔴 C0 — sécurité mesure position treuils M1/M2, tous chemins de référencement
> **Destinataire** : agent en charge du codage des fonctions encoder (T146/T164 historique)

---

## 1 · Résumé exécutif

**Thèse vérifiée et confirmée** : *tout* référencement codeur — nominal capteur haut, forcé (`BtnHomingAtZero`, unitaire MAINT_N2), **et surtout le référencement dynamique benne M2 à chaud** — doit écrire au codeur une valeur **proche du centre de sa plage de résolution totale** (2^25 = 0..33 554 432 pts), jamais sa position physique du moment. C'était l'intention du design d'origine (commit `26217dd9`), **perdue le jour même** (commit `73fa758d`) au profit d'un preset « neutre » (`PresetValue := RawPos`).

L'enquête approfondie révèle **3 couches de problèmes** :

1. **Le risque de bord** (confirmé) : aucun chemin de référencement ne contrôle la distance du compteur aux bornes ; un référencement benne forcé au démarrage peut laisser le codeur sur un bord → wrap-around → `CablePosM` aberrant (~±8192 m) en pleine manœuvre.
2. **Le verrou preset est devenu auto-réussi** (découverte v2) : avec le neutre, `RawPos = PresetValueOut` *par construction* — la séquence `FB_Encoder_Abs` Ack **sans que le codeur ait rien fait**. Le verrou matériel ne teste plus rien de réel.
3. **Le design d'origine « centre-plage » était lui-même incohérent** (découverte v2) : il écrivait le centre au codeur mais calculait `HomingRefRaw` sur la position physique — si le codeur avait réellement appliqué le preset, la mesure aurait sauté de ~8000 m. Il ne « marchait » que parce que rien n'appliquait réellement le preset. **Le neutre n'est donc pas une régression simple : c'est le pansement d'un bug plus ancien, qui a détruit la sécurité au passage.**

La restauration propre (option A) est mathématiquement définie au §8 — mais elle exige 4 adaptations non négociables, dont la validation **que le codeur réel accepte le preset**.

---

## 2 · La règle d'ingénierie attendue (formalisation de la thèse)

> **Règle** : le preset codeur place le compteur au **centre de sa plage** (16 777 216 pts = (8192 × 4096)/2), quel que soit le mode de référencement. La sémantique mètres est portée **uniquement** par la référence applicative `HomingRefRaw` (RETAIN), jamais par la valeur brute du compteur.

Pourquoi le centre et pas « n'importe où au milieu » :

| Course physique réelle | ~20 m ≈ 40 tours ≈ 327 680 pts ≈ **1%** de la plage 2^25 |
|---|---|
| Marge offerte par le centre | ±16,7 M pts ≈ ±4096 m **chaque sens** — dépassement **physiquement impossible** |
| Marge si référencé sur position physique quelconque | 0 à ±4096 m **aléatoire** — non maîtrisé |

M1 et M2, même politique — le codeur ne sait pas « où en est » la mécanique ; c'est à la chaîne de référencement d'imposer un référentiel sûr, systématiquement.

---

## 3 · État des 4 chemins de référencement (audit complet)

| Chemin | Déclencheur | Cible (m) | `PresetValue` écrit au codeur | Contrôle distance aux bornes ? |
|---|---|---|---|---|
| **Nominal capteur haut** (M1+M2) | Front `Home` + front `M1M2_TopPositionFree_DI` | `CfgTopSensorPosM` (déf. 8.5) | `RawPos` (neutre) — *code inchangé* | ❌ Aucun |
| **Forcé zéro** (mise en service) | `BtnHomingAtZero` | 0.0 (forcée par façade `FB_Encoder.st:140`) | `RawPos` (neutre) | ❌ Aucun |
| **Unitaire MAINT_N2** | `BtnHome` | `CfgHomingTarget_M` (libre) | `RawPos` (neutre) | ❌ Aucun |
| **Dynamique benne M2** (à chaud) | `BtnConfirmOpenPos` / `BtnConfirmClosePos` (`PRG_02_Acquisition.st:409-418`) | `CablePosM1` (ouvert) / `CablePosM1 + OffsetCloseM` (fermé) | `RawPos` (neutre) | ❌ Aucun — **pire cas** |

Code commun fautif (`FB_Encoder_Homing.st:229-233`) :

```st
TargetPoints        := REAL_TO_DINT(TargetPositionM * PointsPerRev / CableM_PerRev);
PendingHomingRefRaw := DINT_TO_UDINT(UDINT_TO_DINT(RawPos) - TargetPoints);
PresetValue         := RawPos;      // ← neutre : le compteur reste où il est, bord inclus
```

**Le pire cas est exactement celui décrit par l'exploitant** : le référencement dynamique benne arrive **à chaud, à un instant quelconque**, après manipulation benne. La position brute M2 à ce moment-là dépend de tout l'historique mécanique — le forçage « tu es ouverte / tu es fermée » ne recentre **jamais** le compteur. Un forçage au démarrage (codeur près d'un bord suite à rotation lente/manuelle du tambour pendant l'arrêt) laisse le défaut en place, validé par un `Homed=TRUE` rassurant.

---

## 4 · Scénario de défaut complet (wrap-around)

Hypothèse : référencement M2 (dynamique benne) alors que le compteur COD2 est proche de la borne basse (ex. `RawPos ≈ 40 000 pts` ≈ 10 m au-dessus du zéro de comptage), puis manœuvre d'ouverture (M2 descend).

| # | Étape | État | Conséquence |
|---|---|---|---|
| 1 | Forçage `BtnConfirmOpenPos` à chaud | `Homed=TRUE`, `HomingRefRaw = RawPos − cible` | Référence posée près de la borne — rien ne l'a signalé |
| 2 | Ouverture benne (M2 descend ~15 m) | `RawPos → 0` puis **wrap** `→ 33 554 432` | Compteur enroulé |
| 3 | `FB_Encoder_Scale:34` | `RawDiff := +33,5 M pts` | `CablePosM ≈ +8192 m` (aberrant) |
| 4 | `FB_Encoder_Safety:53` | hors ±99 m | `EncoderIncoherent=TRUE` — arrêt machine **en pleine manœuvre**, cause réelle (wrap) masquée derrière « incohérence » |
| 5 | `FB_Encoder_Homing` §3 (boot suivant) | écart vs `LastKnownRawPos` > 1000 pts | Faux `HomingSuspect` — le doute persiste au redémarrage |
| 6 | `FB_SyncDeviation` / `FB_Bucket` / `FB_Safety_Winch` | positions/vitesses fausses | Défauts en cascade (écart M1/M2 critique, glissement, mouvement non commandé) |

Scénario symétrique près de la borne haute. Probabilité non quantifiée mais **non nulle et non maîtrisée** — c'est précisément ce que la règle du §2 élimine.

---

## 5 · Découvertes v2 — trois aggravations non couvertes par la v1

### 5.1 · Le verrou preset `FB_Encoder_Abs` est auto-réussi

Séquence Abs (`FB_Encoder_Abs.st:131-158`) : étape 1 attend `ABS(RawPos − PresetValueOut) ≤ 10 pts` pour Ack. Avec le neutre, **`PresetValueOut = RawPos` par construction** → l'écart est ≤ tolérance dès le premier scan → maintien 500ms cosmétique → **Ack garanti, même si le codeur physique ignore complètement l'ordre preset**. Le verrou « succès preset » ne prouve plus rien du matériel — il prouve seulement que le codeur répond sur le bus. Conséquence : une régression du chemin preset matériel (PDO Rx non câblé, fonction désactivée dans le codeur) serait **invisible** — tous les homings continueraient de « réussir ».

### 5.2 · Le design d'origine « centre-plage » était lui-même incohérent

Reconstruction du commit `26217dd9` (21/08, lignes ~185-203) :

```st
Calib.HomingRefRaw := RawPos - TargetPoints;   // référence dans le référentiel PHYSIQUE actuel
...
PresetValueCalc := (PointsPerRev * MultiTurnRevsMax) / 2;   // mais preset écrit au CENTRE (16 777 216)
PresetRequest := TRUE;
```

Si le codeur **applique** ce preset : `RawPos` saute à 16 777 216, alors que `HomingRefRaw` a été calculé sur l'ancienne position physique → `CablePosM = (16 777 216 − ancienne_ref)` ≈ **±8000 m aberrant**. Le §4 de suivi (`PresetAck` → `Done := TRUE`) ne recalcule **pas** `HomingRefRaw` — le bug est avéré dans la version d'origine.

**Lecture historique corrigée** : le centre-plage d'origine n'a probablement « marché » que parce que **rien n'appliquait réellement le preset** (pas de gestion preset dans la simu d'alors ; matériel non validé). Le commit `73fa758d` (même jour, soir) introduit la gestion preset dans `FB_Sim_Encoder` — et pour que la simu reste cohérente après application du preset, le « calcul inverse » retombe mathématiquement sur `PresetValue = RawPos` (le neutre). **Le neutre n'est donc pas une régression de la sécurité par négligence : c'est la conséquence directe d'un bug de cohérence de référence plus ancien, réparé par abandon de la sécurisation.** Le commit ne mentionne ni ce bug, ni la perte — aucun breadcrumb.

### 5.3 · Le forçage d'état benne n'a aucune gate de fiabilité codeur

Deux usages partagent les **mêmes boutons** `BtnConfirmOpenPos`/`BtnConfirmClosePos` :

| Usage | Code | Gates |
|---|---|---|
| Forçage état benne (ouvert/fermé) | `FB_Bucket.st:203-217` | Mode MAINT_N1/N2 + `NOT Lifecycle.Busy` — **pas de `HomedAndReliable`, pas de `EncoderFault=FALSE`** |
| Référencement dynamique M2 | `PRG_02_Acquisition.st:409-418` | Mode MAINT + treuils non busy — pas de gate de fiabilité non plus |

De plus, `FB_Bucket.st:207/215` mémorise `LastPosM2Open/Close := CablePosM2` — **positions potentiellement invérifiables** (codeur non homé, incohérent, ou près d'un bord) qui deviennent des références de manœuvre (`RemainingTravelM`, anticipations ouverture/fermeture). Et `ST_HomingChecklist.st:24` documente explicitement ce forçage comme usage **« sans codeur »** (mise en service) : le scénario « quelqu'un force l'état benne au démarrage et se retrouve sur un bord » est donc un **usage prévu et non gardé-fou**.

Le référencement M2 via ces boutons (`PRG_02:431` : `HomingAtTargetM := BtnHome OR M2BucketRefRequested`) hérite du même défaut : il est accepté quel que soit l'état brut du compteur.

### 5.4 · La simulation masque structurellement le défaut

| Écart simu vs réel | Code | Effet |
|---|---|---|
| **Clamp au lieu de wrap** | `FB_Sim_Encoder.st:111-116` : `IF RawPos >= Increment THEN RawPos := RawPos − Increment ELSE RawPos := 0` | Le banc **ne peut pas reproduire** le wrap — un codeur réel UDINT enroule 0→33 554 432, la simu s'arrête à 0 |
| Départ simu à 1 M pts | `GVL_PERSISTENT.st:148-149` | 3% de la plage — aucune descente de course normale (~20 m) n'atteindra la borne |

Le wrap-around est donc **intestable sur le banc actuel** — aucun TC CI ne peut le couvrir tant que la simu clampe. Correction requise si l'on veut le garde-fou `fix:`+`guard:` (§9).

---

## 6 · Chronologie corrigée (git)

| Date | Commit | Événement | État de la sécurité |
|---|---|---|---|
| 2026-08-21 | `26217dd9` | Naissance FB_Encoder (T146 C4). Preset **centre-plage** AU codeur, mais `HomingRefRaw` calculé sur position physique | ⚠️ Intention saine, **exécution incohérente** (§5.2) — cohérent seulement si le preset n'est jamais appliqué |
| 2026-08-21 | `73fa758d` | Gestion preset dans `FB_Sim_Encoder` + « calcul inverse » → **neutre** `PresetValue = RawPos` | ❌ Sécurité centre-plage **abandonnée** silencieusement ; cohérence rétablie par construction |
| 2026-08-22 | `2e93edab` | Fix sélection cible nominale (8.5 m) | Sans effet sur le sujet |
| 2026-08-23 | `55f2f72a` | Transaction preset T164-4C : `PendingHomingRefRaw`, readback ±0.010 m, commit RETAIN après confirmation | ⚠️ **Verrouille le neutre** : le readback `CandidateCablePosM` est calculé avec `PendingHomingRefRaw` — cohérent avec neutre, **incohérent si on restaure naïvement le centre-plage** (le readback échouerait systématiquement → `PresetConfirmationFailed` permanent) |
| 2026-08-24 | `a1843f0d` | Migration `Fault:ST_Fault` | Sans effet |
| Aujourd'hui | — | Neutre en production, centre-plage disparu, docs muettes, `MultiTurnRevsMax` port mort, verrou Abs auto-réussi, simu clampante | 🔴 État audité par ce rapport |

---

## 7 · Consommateurs impactés en cascade

Si le wrap survient : `FB_SyncDeviation` (écart M1/M2 critique) · `FB_Bucket` (course, glissement M1, `RemainingTravelM`) · `FB_Safety_Winch` (mouvement non commandé, vitesse) · interlocks hauteur M3 (`HomedAndReliable` gate stricte) · IHM/SCADA (position affichée ±8192 m). Le défaut dépasse largement l'affichage — il touche le **pilotage benne et la sécurité treuil**.

---

## 8 · Options de résolution (à trancher avec l'agent codeur)

> ⚠️ Aucune appliquée. Analyse uniquement.

### Option A — Restauration centre-plage **cohérente** (recommandée)

La mathématique complète, qui corrige à la fois le bug d'origine (§5.2) et le neutre :

```st
CentrePts          := (PointsPerRev * MultiTurnRevsMax) / 2;        // 16 777 216 — réutilise le port mort
PresetValue        := CentrePts;                                     // le codeur charge le centre
PendingHomingRefRaw := CentrePts - TargetPoints;                     // référence DANS LE RÉFÉRENTIEL post-preset
```

Vérification de cohérence de bout en bout : après application, `RawPos = CentrePts` →
`CandidateCablePosM = (CentrePts − (CentrePts − TargetPoints)) × k = cible` ✓ (readback T164-4C **reste valide tel quel**), et la convergence Abs devient un **vrai test matériel** (le codeur doit réellement charger et relire le centre) ✓.

**4 adaptations obligatoires** (sinon l'option A casse autre chose) :

| # | Adaptation | Pourquoi |
|---|---|---|
| A1 | `PendingHomingRefRaw` dans le référentiel post-preset (ci-dessus) | Sans ça : readback T164-4C en échec permanent (§6, commit `55f2f72a`) |
| A2 | Geler/évincer les consommateurs pendant la **fenêtre de saut** (le compteur passe de `RawPos_ancien` à `CentrePts` en quelques cycles) | `FB_SyncDeviation`/`FB_Bucket` verraient un `CablePosM` aberrant pendant la transaction ; la vitesse se purge seule (`PositionValid=FALSE`) mais Sync/Bucket non. NB : le chapô AF09 §13 dit explicitement que le treuil ne passe **pas** en référencement de sécurité pendant cette phase — à revoir |
| A3 | **Valider sur le codeur réel** que le preset (PDO Rx `PresetTriggerCmd=2` + valeur) est réellement supporté et appliqué | Si le matériel l'ignore : Nak systématique → **plus aucun homing possible** (c'est peut-être la raison de fond du neutre — à demander à l'agent codeur). Le verrou Abs actuel auto-réussi (§5.1) nous a rendus aveugles sur cette question |
| A4 | Simu : wrap au lieu du clamp + TC CI « homing près de borne + descente → pas d'aberration » | Garde-fou `fix:`+`guard:` ; aujourd'hui intestable (§5.4) |

### Option B — Neutre conservé + garde anti-bord

Garder `PresetValue := RawPos` ; au déclenchement homing, exiger `marge ≤ RawPos ≤ 33 554 432 − marge` (marge = course physique + coeff, ex. 2 M pts) ; sinon refuser (`ErrorId` dédié) ou re-centrer. Pansement : ne protège que l'instant du homing, pas les mouvements ultérieurs si la marge était déjà entamée ; ne restaure pas le verrou matériel ; laisse le double référentiel en place.

### Option C — Statu quo documenté

Déconseillé : transfère le risque à l'exploitant sans l'informer — et le forçage benne « sans codeur » (§5.3) reste un piège documenté comme procédure normale.

---

## 9 · Questions ouvertes pour l'agent codeur

1. **La bascule `73fa758d` était-elle voulue** (choix assumé motivé par le bug §5.2 / le matériel) ou **un effet de bord** de la mise au point simu ? Le message du commit ne parle que de simu.
2. **Le codeur réel accepte-t-il le preset** `PresetTriggerCmd=2` + `PresetValue` (PDO Rx) ? Réponse déterminante pour A3 — et si non, pourquoi le chemin preset existe-t-il ?
3. Le **forçage benne sans gate de fiabilité** (§5.3) : gate `HomedAndReliable` à ajouter, ou usage « sans codeur » assumé en mise en service avec procédure dédiée ?
4. Faut-il exiger la **même politique M1/M2** (centre-plage des deux côtés) — recommandé, cf. §2 ?

## 10 · Suivi

- Charger en tâche `TASKS.yaml` (C0 — sécurité mesure) après décision avec l'agent codeur.
- Règle `fix:`+`guard:` : le patch **et** le garde-fou (TC CI wrap après correction simu, ou gate G4xx vérifiant `PresetValue` dans `[marge; plage−marge]`).
- Docs à mettre à jour après décision : AF09 §4/§5/§13 (choix de référentiel + fenêtre de transaction), sous-fiche `FB_Encoder_Homing`, `ST_HomingChecklist` (usage forçage).

## 11 · Preuves référencées (vérifiables)

```powershell
git show 26217dd9:CODE/E_CODEURS/FB_Encoder_Homing.st    # centre-plage + référence physique (incohérence §5.2)
git show 73fa758d -- CODE/E_CODEURS/FB_Encoder_Homing.st # bascule neutre
git show 73fa758d -- CODE/L_SIMULATION/FB_Sim_Encoder.st # naissance de la gestion preset simu
```

| Localisation | Contenu |
|---|---|
| `CODE/E_CODEURS/FB_Encoder_Homing.st:229-233` | Formule neutre actuelle |
| `CODE/E_CODEURS/FB_Encoder_Homing.st:39` + `FB_Encoder.st:147` | `MultiTurnRevsMax` port mort |
| `CODE/E_CODEURS/FB_Encoder_Abs.st:131-158` | Séquence preset — auto-réussie en neutre (§5.1) |
| `CODE/E_CODEURS/FB_Encoder_Homing.st:243-249` | Readback T164-4C (cohérent neutre uniquement) |
| `CODE/M_MAIN/PRG_02_Acquisition.st:409-437` | Référencement dynamique M2 benne, sans gate fiabilité |
| `CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st:203-217` | Forçage état benne + mémorisation positions non vérifiées |
| `CODE/L_SIMULATION/FB_Sim_Encoder.st:106,111-116` | Simu : applique preset, **clampe au lieu de wrapper** |
| `CODE/GVL_PERSISTENT.st:148-149` | Départ simu 1 M pts (3% plage) |
| `CODE/E_CODEURS/FB_Encoder_Safety.st:53` | Bornage ±99 m (filet de sécurité, pas une protection de compteur) |
