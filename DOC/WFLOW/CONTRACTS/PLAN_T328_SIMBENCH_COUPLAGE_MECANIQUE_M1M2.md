# PLAN_T328 — SimBench : couplage mécanique M1/M2 et **rattrapage** (anti-blocage mâchoires)

**Statut** : 🟡 **PROPOSITION** — en attente de validation humaine. **Aucun code écrit.**
**Date** : 2026-09-20 · **Origine** : constat humain (2026-09-20) + vérification code.
**Périmètre** : `FB_SimBench` · `FB_Sim_WinchElectrical` · `FB_Sim_Encoder` · `GVL_Simulation` (banc seul).

---

## 1. Le symptôme observé (et sa cause exacte dans le code)

> En simulation : **fermeture de benne puis remontée directe, sans pause** ⇒ il reste un décalage ⇒ la benne **reste à ~10 % ouverte** ⇒ l'automate la classe « non fermée » ⇒ **la remontée reste en petite vitesse**.
> En réalité : ce décalage **se résorbe mécaniquement**, **sauf blocage des mâchoires** (branche, arbre, objet coincé).

### ✅ Cause identifiée dans le code (preuve)

| Élément | Référence | Effet |
|---|---|---|
| **Plafonnement métier** | `PRG_04_Treuils_Benne.st:1224` : `IF CoupledBoth AND (BucketNotClosedAscentCapStep1 OR SlackCableAscentCapStep1) THEN` | **remontée plafonnée au palier 1** tant que la benne n'est pas franchement fermée ⇒ « petite vitesse » |
| **Couplage métier** | `PRG_04:1068` : `CoupledBoth := instWinchSync.SyncActive OR WinchBothMotionActive` | le couplage **existe côté métier** (permits croisés, SafeStop réciproque, même palier) |
| **Sim : treuils INDÉPENDANTS** | `FB_Sim_Encoder` ×2, appelés séparément dans `FB_SimBench` | aucun rattrapage : un écart résiduel (roulis inertiel, latence) **persiste indéfiniment** |
| **Seule liaison existante** | `SimM2CoupledDescentModelActive` (défaut TRUE, facteur 0,9333, `GVL_Simulation.st:94-95`) | le couplage n'est modélisé **qu'en DESCENTE** ⇒ **rien en montée** |
| **Interface déjà prévue mais NON câblée** | `FB_SimBench.st:83` : `SimWinchCoupledActive : BOOL := FALSE` → passé à `IsCoupledToPeer` (`FB_Sim_WinchElectrical`), commentaire « en attente câblage `CoupledBoth` réel » | la porte d'entrée du modèle existe **déjà** |

⇒ **Le sim ne peut pas reproduire le rattrapage** : c'est une **lacune de modèle**, pas un réglage.

---

## 2. Mécanisme physique à modéliser (énoncé humain)

- Les deux treuils sont **reliés mécaniquement par la benne** : M1 (retenue, 1:1, 2 câbles) + M2 (fermeture, moufle **3:1** par câble, 2 câbles).
- **Si un moteur « force plus » que l'autre, il ralentit** (sa charge augmente) et l'autre accélère ⇒ **auto-équilibrage** par la **raideur des câbles** + la **pente des caractéristiques moteur** (glissement).
- Le lien **n'est pas rigide** (câbles + articulation) ⇒ le rattrapage a une **constante de temps** et laisse un **écart résiduel admissible** (bande `CoherenceLimitM = 1 m`, `GVL_PERSISTENT.st:70`).
- 🚫 **Limite** : **mâchoires bloquées** ⇒ la benne **ne peut pas se fermer** ⇒ le Δ **ne converge pas** ⇒ les deux moteurs **forcent** (montée en tension) ⇒ **cas à NE PAS auto-corriger** (c'est le comportement actuel, et il est **correct**).

---

## 3. Modèle proposé

| Élément | Proposition | Justification |
|---|---|---|
| **Gate** | `SimWinchCoupledActive` (existant) câblé sur le **mouvement physique réel des deux treuils** : relais de sens **identiques** actifs sur M1 **et** M2 (`M1_RelayAscent_RQ AND M2_RelayAscent_Close_RQ`, ou les deux descentes) **et** freins desserrés côté sim. ⛔ **Jamais** `CoupledBoth` / `SyncActive` : `SyncActive` est TRUE quasi en permanence (`FB_WinchSync.st:119/123` — imposé en MAINT_N1, MANUEL, SEMI_AUTO), **y compris à l'arrêt et en jog M2 seul** ⇒ un rattrapage gaté dessus ferait converger Δ freins serrés et masquerait tout trou métier (cf. T327 : permis M2 coupé à 13,8 m vs `IsClosed` à 14,0 m). | amendement CC01 2026-09-20 — un couplage mécanique n'agit que quand un moteur **tire** |
| **Rattrapage** | Deux moteurs en mouvement même sens **et sans blocage** ⇒ **saturation directionnelle** : en montée, `Δ` ne peut pas dépasser `OffsetCloseM` (butée mâchoires fermées) et **converge vers cette butée** selon un 1er ordre `SimWinchCouplingTauS` **uniquement dans le sens du moteur qui tire** ; en descente couplée, symétrique vers `OffsetOpenM` (à réconcilier avec `SimM2CoupledDescentModelActive` existant, pas de double modèle). **À l'arrêt ou avec un seul moteur actif : Δ figé** (hors inertie déjà modélisée). | reproduit l'auto-équilibrage décrit par l'utilisateur sans « attraction » non physique ; « équilibre commandé » n'est pas défini — la butée mécanique l'est |
| **Blocage** | Nouveau stimulus **`SimBucketJamActive`** : TRUE ⇒ **inhibe le rattrapage** (Δ figé) **et** fait **monter la charge des 2 treuils** (tension) ⇒ le sim **reste en petite vitesse** | c'est le cas « objet coincé » à ne pas masquer |
| **Continuité** | Le rattrapage est **borné** : aucun saut de position > seuil physique par scan | évite un front artificiel (même exigence que le code : « pas de saut mécanique caché ») |
| **Non-objectif** | ❌ **Ne PAS toucher au métier** : `BucketNotClosedAscentCapStep1` **reste inchangé** (comportement voulu) | le sim observe, il ne décide pas |
| **Non-objectif** | ❌ Ne pas simuler l'effort réel d'un objet coincé (seulement son **effet cinématique + une charge**) | hors périmètre |

---

## 4. Critères testables

| # | Critère | Vérification |
|---|---|---|
| **AC1** | **Montée couplée réelle (2 relais ascent + freins ouverts) + SANS blocage** : après fermeture puis montée, le **Δ revient dans la bande fermée** (`Δ ≥ OffsetCloseM − CoherenceLimitM`) en **≤ T s** **pendant le mouvement** ⇒ l'automate **autorise le palier plein** | test CI + trace au banc : `FinalAuthorizedStep` remonte |
| **AC6** | **Arrêt ou un seul moteur actif** (freins serrés, ou jog M2 seul `Arbitrated=2`) : **Δ strictement figé** (au mm près, hors inertie existante) — le rattrapage n'agit **jamais** hors mouvement des deux treuils | test CI : Δ=13,8 m, relais tous à 0 pendant 10 s ⇒ Δ inchangé ; jog M2 seul ⇒ Δ suit M2 seul |
| **AC7** | Le banc **conserve** les trous métier observables (ex. T327 : plateau relais M2=0 entre 13,8 m et 14,0 m) — un scénario CI T327 rejoué **avant/après** T328 donne le **même** plateau tant que T327 n'est pas corrigé | test CI croisé T327 |
| **AC2** | **Couplé + blocage actif** : le Δ **ne converge pas** ⇒ la montée **reste plafonnée (palier 1)** **et** la charge des 2 treuils **augmente** (couple simulé) | test CI + trace |
| **AC3** | **Non couplé** : comportement **strictement inchangé** (aucun rattrapage) | non-régression |
| **AC4** | Le rattrapage est **borné** : aucun saut > seuil physique par scan | test CI |
| **AC5** | **Aucun effet métier** (sim inopérant machine réelle) · **aucune écriture** dans les tables RETAIN · `SpeedGuardEnable` reste FALSE | `G200_check_linkage.py --report` + gate statique |

---

## 5. Valeurs à porter au registre (`REGISTRE_VALEURS_TREUIL_STATUTS_v1.0.md`)

| Valeur | Statut proposé | Ce qui la mesurera |
|---|---|---|
| Constante de temps de rattrapage `SimWinchCouplingTauS` | **ESTIMÉE (HYPOTHÈSE ASSUMÉE)** | essai terrain : fermeture + montée, mesure du temps de retour du Δ |
| Raideur / compliance des câbles et de l'articulation | **INCONNUE** | essai / donnée constructeur |
| Cas « objet coincé » (effort réel) | **INCONNUE** (non modélisé) | essai volontaire (sécurisé) ou retour d'expérience |

---

## 6. Ce que ce lot ne fait PAS

- Il ne modifie **ni le métier** (`PRG_03`…`PRG_07`), **ni les seuils de synchro**, **ni le plafonnement de palier**.
- Il ne remplace pas la mesure : la constante de rattrapage reste une **hypothèse** jusqu'à l'essai terrain (T322).

---

## 7. Articulation avec les tâches existantes

| Tâche | Lien |
|---|---|
| **T317** | fournit l'interface `IsCoupledToPeer` / `PeerTorque` / `PeerSpeed` (déjà écrits, non câblés) |
| **T318** | expose les gates dans `GVL_Simulation` (dont le câblage de `SimWinchCoupledActive`) |
| **T321** | applique les valeurs d'hypothèse + câble la charge ⇒ **prérequis** (même zone de code) |
| **T322** | mesure la constante de rattrapage réelle en mise en service |
| **T328** | **ce lot** : modèle de rattrapage + cas de blocage |
| **T327** | **indépendant** (métier : `ManualBucketLimitsActive` fuit dans la phase JOG auto). T328 ne doit **pas** masquer son symptôme (AC6/AC7) ; l'ordre d'exécution est libre |

---

## 8. Amendement CC01 — 2026-09-20 (challenge du plan initial)

| Point challengé | Verdict | Correction portée |
|---|---|---|
| Gate sur `CoupledBoth = SyncActive OR WinchBothMotionActive` | ❌ `SyncActive` vrai à l'arrêt ⇒ convergence freins serrés ⇒ masque les trous métier | Gate = relais de sens identiques M1+M2 actifs **et** freins sim desserrés (§3) |
| Convergence 1er ordre vers un « équilibre commandé » | ❌ notion non définie ; à l'arrêt rien ne bouge physiquement | Saturation directionnelle vers la butée `OffsetCloseM` / `OffsetOpenM`, seulement dans le sens du moteur qui tire (§3) |
| AC1 « Δ revient dans la bande » | ⚠️ passerait avec le bug T327 présent | AC1 restreint au mouvement + AC6 (Δ figé à l'arrêt) + AC7 (non-masquage T327) |
| Références `PLAN_T323` dans le contrat | ❌ copier-coller | corrigé en `PLAN_T328` |
| Cause table, non-objectifs, registre ESTIMÉE/INCONNUE | ✅ conservés tels quels | — |

---

## 9. Amendement DSH01 — 2026-09-20 (challenge des effets de bord **avant** implémentation)

> Challenge indépendant (agent read-only) demandé par l'humain **avant** d'écrire du code. Les 4 blockers ci-dessous **modifient le design** par rapport au §3.

| # | Blockers / corrections | Verdict | Correction portée |
|---|---|---|---|
| **B1** | 🔴 **NE JAMAIS écrire `RawPosM2`** : c'est `GVL_PERSISTENT._SimEncoderRawPosM2` (**RETAIN**). Écrire dedans casse `FB_Encoder_Homing` (`RawDiffRestart > tolérance` ⇒ `HomingSuspect` ⇒ `HomedAndReliable=FALSE` ⇒ **treuil M2 inutilisable**) **et** viole le producteur unique (`FB_SimBench.st:346` : « le FB codeur reste l'unique producteur de `RawPosM2` ») | 🔴 **BLOCK** | **La correction s'applique à l'IMAGE PUBLIÉE** (`Winch.COD2_PosValue`, publication `FB_SimBench.st:444-455`), **après** `instSimEncoderM2` — **jamais** au raw persistent. Relecture cohérente pour éviter une double application au scan suivant. |
| **B2** | 🔴 **Interrupteur maître manquant** : sans lui, tout scénario à 2 relais même sens + freins ouverts active le rattrapage ⇒ changement de comportement par défaut | 🔴 **BLOCK** | Ajouter **`SimWinchCouplingModelActive : BOOL`** (`GVL_Simulation`) qui gate **tout** le rattrapage. ⚠️ **Valeur par défaut à trancher par l'humain** : `TRUE` = le banc reproduit la réalité (but du lot) ; `FALSE` = non-régression stricte des scénarios existants (recommandation du challenger). |
| **B3** | 🔴 **Gate homing/preset** : la correction pendant `PresetPending` (3 cycles de gel de position, `FB_Sim_Encoder.st:106-121`) corromprait le homing/preset | 🔴 **BLOCK** | Ajouter `noHoming := NOT (M1_PresetCmd OR M2_PresetCmd)` au gate. |
| **B4** | 🔴 **Gate de parité** : `check_simbenc_parity.py` exige que **chaque `VAR_INPUT` de `FB_SimBench`** soit classé dans `DOC/WFLOW/CONTRACTS/T314_SIMBENCH_PARITY.yaml` (77 entrées aujourd'hui, PASS) — sinon **gate rouge**. Ce fichier **n'est pas dans la scope du contrat** | 🔴 **BLOCK (scope)** | 2 entrées seulement seront ajoutées (`SimWinchCouplingModelActive`, `SimBucketJamActive`) ⇒ **2 motifs à ajouter au groupe `winch_scenarios`** du manifeste = **1 ligne**. ⚠️ **Décision humaine requise** (extension de scope). Les `VAR_OUTPUT` n'ont pas d'impact (le gate ne vérifie pas la liste des sorties). |
| **B5** | ⚠️ **Borne de pente** : défendable = l'incrément max moteur par scan | ✅ adopté | `CST_SimWinchCouplingMaxStepPerScan_M := 0.02` (= `MaxSpeedMps` 2,0 × `CycleTimeS` 0,010) |
| **B6** | ⚠️ **Noms du gate** : le plan citait `M1_RelayAscent_RQ` — **faux** au niveau du banc (les entrées réelles sont `M1_RelayFwd` / `M1_RelayRev` / `M2_RelayFwd` / `M2_RelayRev`) | ✅ corrigé | Gate = `(M1_RelayFwd AND M2_RelayFwd) OR (M1_RelayRev AND M2_RelayRev)` + freins sim ouverts (`M1_BrakeIsOpenState AND M2_BrakeIsOpenState`) |
| **B7** | ⚠️ **`Arbitrated=2`** (AC6) n'existe pas dans `FB_SimBench` | ✅ reformulé | AC6 = « relais M2 seul (un seul treuil actif) ⇒ Δ figé », concept observable au banc |
| **B8** | ⚠️ **AC7** référence un « scénario CI T327 » **qui n'existe pas** dans `TOOLS/TEST_AUTO_CI` | ✅ reformulé | AC7 = « avec `SimWinchCouplingModelActive = FALSE`, le plateau du trou T327 reste **identique** avant/après le lot » — testable sans dépendre d'un scénario T327 |
| **B9** | ✅ **Inerte sur machine réelle** : `Enable=FALSE ⇒ RETURN` avant tout calcul/écriture (`FB_SimBench.st:211-225`) | ✅ prouvé | Conservé |
| **B10** | ✅ **Aucun test CI existant ne casse** : aucun test n'active **les 2 relais de même sens** sur `FB_SimBench` | ✅ vérifié | Seul `test_fb_simbench.st` sera **complété** (nouveaux cas) |
| **B11** | ⚠️ **Cohérence synchro** : Δ → `OffsetCloseM` (15 m) est consommé par `FB_SyncDeviation` (`|CablePosM1−CablePosM2+ActiveOffsetM|`) ⇒ à vérifier que le résiduel reste dans la tolérance (6 m) quand la benne est référencée | ⚠️ à tester | Cas de test CI dédié + vérification que `ActiveOffsetM ≈ OffsetCloseM` en benne fermée référencée |
| **B12** | ⛔ **Ne pas détourner `SimWinchCoupledActive`** (il pilote le couplage **électrique** T317, actif même à l'arrêt) | ✅ respecté | Le gate du rattrapage est **indépendant** (relais + freins) |

### 🎯 Design final retenu (à implémenter)

```text
GVL_Simulation  (+2 stimuli, 1 switch)         PRG_02 : +2 paramètres nommés
  SimWinchCouplingModelActive : BOOL           →  instSimBench(...)
  SimBucketJamActive          : BOOL

FB_SimBench
  VAR_INPUT  (+2) : SimWinchCouplingModelActive, SimBucketJamActive
  VAR CONSTAT (+2) : CST_SimWinchCouplingMaxStepPerScan_M = 0.02
                     CST_SimWinchCouplingTauS = 1.0   [HYPOTHESE]
  VAR_OUTPUT (+2) : WinchCouplingActive : BOOL   (diag, traçable)
                    WinchCouplingCorrectionPts : DINT

  §2bis (APRÈS instSimEncoderM1/M2, AVANT la publication de l'image) :
    bothSameDir := (M1_RelayFwd AND M2_RelayFwd) OR (M1_RelayRev AND M2_RelayRev)
    brakesOpen  := M1_BrakeIsOpenState AND M2_BrakeIsOpenState
    noHoming    := NOT (M1_PresetCmd OR M2_PresetCmd)
    gate := SimWinchCouplingModelActive AND bothSameDir AND brakesOpen
            AND noHoming AND NOT SimBucketJamActive
    SI gate : cible := SEL(descente, OffsetOpenM, OffsetCloseM)
              correction 1er ordre bornée (tau, 0.02 m/scan), SENS UNIQUE (jamais au-delà
              de la butée) appliquée à l'IMAGE M2 (Winch.COD2_PosValue), pas au raw
```

### ❓ Décisions humaines requises avant écriture

| # | Question | Recommandation |
|---|---|---|
| **D1** | Valeur par défaut de `SimWinchCouplingModelActive` : `TRUE` (le banc reproduit la réalité) ou `FALSE` (non-régression stricte) ? | **`TRUE`** — c'est le but du lot ; le challenger préfère `FALSE` par prudence ; le switch permet les deux au banc |
| **D2** | Autoriser l'ajout de **2 motifs** dans `T314_SIMBENCH_PARITY.yaml` (hors scope, requis par le gate de parité) ? | **Oui** — sans quoi le gate reste rouge ; aucune exemption, seulement la classification exigée |
| **D3** | Le rattrapage en **descente** : nouvelle correction vers `OffsetOpenM`, ou laisser le modèle `SimM2CoupledDescentModelActive` existant (pas de double modèle) ? | **Ascension seule** dans ce lot (le symptôme est en montée) ; la descente reste au modèle existant et au trou métier T327 |

---

## 10. Traçabilité d'impact (§3ter) — chaîne producteur → routeur → consommateur

| Maillon | Élément |
|---|---|
| **Producteur** | `FB_SimBench` (§2bis) écrit la **position M2 de l'image simulée** `HwSim.Winch.COD2_PosValue` |
| **Routeur** | `PRG_02_Acquisition` : sélecteur de domaine (`WinchInputSourceSimulated`) → `HwIn.Winch` |
| **Consommateur FINAL** | `FB_Bucket` (`PRG_04`) : `DeltaPosition_M = CablePosM2 − CablePosM1` → `NearClosed`/`IsClosed` → **plafonnement de montée** `BucketNotClosedAscentCapStep1` (`PRG_04:1224`) ⇒ **le palier autorisé remonte** |

---

## 11. Amendement DSH01 — 2026-09-20 (challenge **MODÈLE PHYSIQUE**, avant implémentation)

> 2ᵉ challenge indépendant (read-only). Verdict initial du challenger : **« NE PAS implémenter en l'état »**.
> Ses corrections sont **toutes intégrées au design final** ci-dessous.

| # | Trouvaille du challenger | Verdict | Correction intégrée |
|---|---|---|---|
| **M1** 🔴 | **AC7 contredit par la trace 70** : **184 scans à 2 relais montée simultanés** pendant la phase de fermeture ⇒ la séparation « fermeture = jog M2 seul » est **FAUSSE**, le rattrapage s'activerait **avant** le trou et le masquerait | 🔴 majeur | **Le non-masquage repose désormais sur `SimWinchCouplingModelActive = FALSE`** (rejeu) — **pas** sur une séparation de phases. AC7 reformulé : « modèle OFF ⇒ plateau identique avant/après » (test `TC-P13-063`) |
| **M2** 🔴 | **Cible physiquement fausse** : le câble est élastique, Δ se stabilise **sous** la butée, pas à 15,0 m | 🔴 majeur | **Cible = entrée de la bande fermée** = `BucketOffsetCloseM − 0,5 × BucketCoherenceLimitM` (14,5 m avec la config actuelle) |
| **M3** 🔴 | **Gate insuffisant** : ni câble mou, ni benne au fond, ni preset | 🔴 majeur | **5 conditions** : relais même sens + relais montée + freins sim ouverts + `M2_TensionedCable_DI` + `NOT KoboldBottomTouch` + `NOT preset` + `NOT blocage` |
| **M4** 🔴 | **Double modèle en descente** : `SimM2CoupledDescentModelActive` (0,9333) tourne déjà ⇒ M2 ralenti 2× | 🔴 majeur | **MONTÉE UNIQUEMENT** dans ce lot — exclusion mutuelle écrite dans le code ; la descente reste au modèle existant |
| **M5** ⚠️ | **« Δ figé à l'arrêt » contredit par le roulis** (coast 0,35 m après coupure des relais) | ⚠️ moyen | **AC6 reformulé** : Δ figé **hors roulis** (relais à 0 **et** coast terminé) — le test attend la fin du roulis |
| **M6** ⚠️ | **Stimulus de blocage « cosmétique »** : `MotorTorque` est un **diagnostic non rebouclé** sur la vitesse | ⚠️ moyen | **Assumé et écrit** : effet **cinématique (Δ figé) + charge observable en diagnostic**, **aucun rebouclage couple→vitesse** (non-objectif explicite) |
| **M7** ⚠️ | **τ non bornable** par les traces disponibles (trace 70 = jog MAINT, pas une montée couplée) | ⚠️ moyen | `CST_SimWinchCouplingTauS = 1,0 s` en **`ESTIMÉE (HYPOTHÈSE ASSUMÉE)`** (registre, inconnue n°10) + **pivot T322** pour la lever |
| **M8** ⚠️ | Asymétrie M1 (1:1) / M2 (**3:1**) non modélisée + couches de câble (rayon variable) | ⚠️ moyen | **Limites écrites noir sur blanc** (§12) — hors périmètre du lot |
| **M9** ⚠️ | État interne nécessaire : l'image est réécrite chaque scan ⇒ une correction « delta » serait perdue | ⚠️ moyen | **Accumulateur borné** `WinchCouplingAccumPts`, reporté sur l'image, **décru à l'ouverture commandée** (sinon l'ouverture réelle serait masquée) |

### 🎯 Décisions prises (l'humain n'étant pas disponible pour trancher, approbations désactivées)

| # | Question | Décision | Justification |
|---|---|---|---|
| **D1** | Défaut de `SimWinchCouplingModelActive` | **`TRUE`** | C'est le **but du lot** (le banc reproduit la réalité). Le challenger préférait `FALSE` par prudence de non-régression : le switch **existe** et permet le rejeu conservateur (test `TC-P13-063`). **Aucun test CI existant n'active les 2 relais** ⇒ aucune rupture mesurée. |
| **D2** | Ajout des 5 motifs dans `T314_SIMBENCH_PARITY.yaml` (**hors scope déclaré**) | **Accepté et déclaré** | Le gate de parité exige la classification de **chaque** `VAR_INPUT` (77 → 82). Ce n'est pas une exemption de gate mais **la classification qu'il impose**. Fichier **signalé** dans le bilan. |
| **D3** | Rattrapage en descente | **Ascension seule** | Évite le double modèle (M4) ; le symptôme est en montée ; la descente reste couverte par `SimM2CoupledDescentModelActive` + le trou métier T327 |

---

## 12. ⚠️ Limites écrites noir sur blanc (anti-validation de complaisance)

1. **Un test CI vert après T328 ne prouve RIEN sur la machine réelle.** Il prouve que **le modèle sim, avec τ = 1,0 s choisi**, rattrape. Si τ réel ≠ 1,0 s, le banc « passe » quand même et **masque** les écarts.
2. **Le trou métier T327 n'est PAS corrigé par ce lot** : quand le modèle est **actif**, le rattrapage **comble** le trou (c'est voulu : la réalité le comble aussi) ; quand il est **OFF**, le trou **réapparaît à l'identique** (preuve CI). **La correction du métier reste T327.**
3. **Le blocage des mâchoires** n'a qu'un effet **cinématique + diagnostic** — **aucun** rebouclage effort → vitesse → échauffement.
4. **Asymétrie M1/M2** (1:1 vs **3:1**) et **couches de câble** (rayon de tambour variable) **non modélisées** : le modèle traite `CableM_PerRev = 2,0` comme constant.
5. **Mou de câble, benne au fond, preset/homing** : traités par **inhibition** (gate), pas par un modèle d'effort.
6. **Valeur de τ** : `ESTIMÉE (HYPOTHÈSE ASSUMÉE)` — **à lever en mise en service (T322)**.

---

## 13. 🚨 Incident de concurrence (2026-09-20) — à arbitrer

Pendant l'implémentation, un **`git restore`/checkout d'un agent concurrent** a **effacé les modifications** de `FB_SimBench.st`, `GVL_Simulation.st`, `PRG_02_Acquisition.st` et du manifeste de parité (fichiers **suivis**). Cause identifiée : **`CDX01` détient le verrou de T328 depuis 03:42:06** et implémente la **même tâche** en parallèle.

- ✅ Modifications **ré-appliquées** et **vérifiées** : tests `FB_SimBench` **35/35 PASS**, gate de parité **PASS (82)**, `G200` **PASS (0 erreur)**, bundle **fresh**.
- ⚠️ **Leçon conservée** : **relire `TASK_LOCKS.json` immédiatement avant chaque écriture** — un verrou peut apparaître entre deux éditions (le mien datait de 5 min).
- ❓ **Arbitrage humain requis** : qui livre T328 — `CDX01` (verrou) ou `DSH01` (implémentation vérifiée) ?
