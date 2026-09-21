# 🧭 PLAN T334 Phase 3 — l'axe M3 possède son arrêt (arbitrage Q1→Q6)

> 🎫 Contrat parent : `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T334_AUTO_CYCLE_M3_OVERSHOOT.yaml` (C3, `strategy: patch`)
> 🏷️ Acteur : **DSH07** · Orchestrateur : **CC01** · 📅 2026-09-20
> 🚦 **Statut : CONCEPTION SEULE. AUCUN CODE.** Zéro fichier `CODE/`, zéro test, zéro gate, zéro bundle, zéro commit.
> 🔒 **Décision fondatrice (CC01, 2026-09-20)** : c'est **l'axe** qui possède son arrêt (`FB_Translation.ArrivalLock`), **jamais** la porte de transition AX2/AX14. Le lot « Phase 2 — uniformiser AX2/AX14 sur AX3 » est **ARRÊTÉ** : verdict challenger §10bis, confirmé sur le code par le porteur (§ cf. journal).

---

## 🎯 0 · Ce que ce plan tranche, et ce qu'il ne tranche pas

| | |
|---|---|
| ✅ Tranche | les **6 questions Q1→Q6** du contrat parent (§1), le **modèle cible** (§2), le **séquencement des lots** (§3), les **AC à ajouter** (§4), les **preuves** (§5) |
| ⛔ Ne tranche pas | les **5 décisions humaines** de §8 (bypass, config morte, coupure dure Trémie, sort du neutre, séquencement T331) |
| ⛔ N'autorise pas | d'écrire une ligne de `CODE/` : chaque lot de §3 exige un GO explicite + la révision figée (§0.1) |

### 0.1 ⚠️ Préalable bloquant — figer la révision avant de coder

`CODE/G_CYCLE/FB_CycleSemiAuto.st` est **modifié non commité** (+20 / −5) par le chantier concurrent **T331/DSH09** (écriture du 20/09 18:13:32 ; verrou d'écriture sur ce fichier depuis 17:57). Conséquence mesurée par le challenger (§10bis A.0) et revérifiée ici :

| État | Règle de numérotation |
|---|---|
| `HEAD` = `fd12dc0` | les références **du contrat parent** (ex. AX14 `:1386`, `:1387`, `:1395`) sont exactes **à HEAD** |
| Arbre de travail (WT) au 2026-09-20 | **toute ligne > :1224 est décalée de +4** (insertion T331 en AX10) |

📌 **Convention du présent plan** : `fichier:ligne (WT)` = arbre de travail, `(HEAD)` = commit `fd12dc0`. Les deux sont données là où l'écart existe.

🚫 **Interdit** : ouvrir un lot `CODE/` avant que la révision ne soit figée (commit, ou gel explicite du fichier) — sinon chaque `fichier:ligne` du contrat devient faux à l'édition concurrente suivante.

### 0.2 Corrections de citation vérifiées (exigées par §10bis F)

| Référence d'origine | Vérification faite ici | Statut |
|---|---|---|
| Contrat FAIT 5 : `PRG_07_Supervision.st:230-235` (restauration boot des bypass) | **FAUX** → la restauration RETAIN → IHM est en **`PRG_07_Supervision.st:336-346`** (bloc Translation `:341-346`). `:230-235` traite la logique T330 TOP/FdC, sans rapport. *(Le challenger citait `:331-341` : limite haute de section ; la valeur exacte relevée ici est `:336-346`.)* | 🔴 corrigé au contrat |
| Contrat FAIT 5 : doctrine bypass « MAINT_N2 uniquement » | ✅ `ST_BypassTranslation.st:4-5` (lu) | ✅ |
| Contrat FAIT 4 : asymétrie AX14 (`PositionTgt := 0`) | ✅ `FB_CycleSemiAuto.st:1391 (WT)` / `:1387 (HEAD)` | ✅ |
| Contrat FAIT 2 : arrêt manuel latché + relâchement sens inverse | ✅ `FB_Translation.st:179-183`, `:190-200`, `:202-204` (lus) | ✅ |
| Q5 : écart spec/code escalade | ✅ spec `AF_Partie-11_v2.4.md:346-351` (0 / 2,5 s / 5 s) ; code `FB_Safety_Translation.st:202` (`PT := T#1S500MS`) + `:268` (`PowerCutOff := (Fault.ErrorId AND 16#00F8) <> 16#0000`, **immédiat**, sans gradation) | ✅ |
| H4 ≠ vecteur du défaut frein T287 | ✅ `FB_Translation.st:271-272` : le frein **reste desserré** tant que `ABS(fAct) > 0,5 Hz` (fenêtre 2 s) ⇒ la roue libre H4 **ne commande pas** le frein | ✅ |
| Escalade cause 6 **avec demande vivante** | ✅ `FB_Safety_Translation.st:200-201` (`LimitSwitchTremie AND ReqTremie AND …`) et `FB_Translation.st:123-124` (`CommandedTremie AND LimitSwitchTremie AND ABS(fAct)>0,5`) : **les deux voies lisent la demande** | ✅ |
| Coupure dure Trémie | ✅ `PRG_06_Outputs.st:431-432` (`M3_PosTremie_DI AND ReqTremieSemantic`) puis `:442-450` (frein + mot + fréquence forcés à 0 **au même scan**) | ✅ |
| Veto d'étape SEMI_AUTO | ✅ `PRG_05_Translation.st:656-662` : hors AX2/AX14, frein + mot + fréquence + sémantique Trémie **forcés à zéro** au **changement d'étape** | ✅ |

---

## ⚖️ 1 · Arbitrage Q1 → Q6

> Règle de lecture : **Décision** = ce qui est tranché · **Preuve** = le fait de code qui porte la décision · **Conséquence** = ce que le lot doit faire.

### 🟢 Q1 — Autorité de l'arrêt : **OUI, l'axe arme l'arrêt sur la seule détection d'arrivée, indépendamment de la présence d'une demande**

| | |
|---|---|
| **Décision** | `ArrivalLock` (`FB_Translation.st:179-183`) est armé par la **seule** détection d'arrivée qualifiée (front du capteur cible, `:175-177`, debounce `T#100ms`). Il **n'est jamais levé par la disparition de la demande**. Relâchement : **demande explicite de sens inverse uniquement** (`:202-204`) — **inchangé, acquis à conserver** (`must_survive`). |
| **Preuve** | Manuel/MAINT fonctionne déjà ainsi (un seul `FB_Translation`, appelé une fois : `PRG_05:537`). En cycle, l'arrêt est **délégué au retrait de la demande** par le séquenceur (`FB_CycleSemiAuto.st:899 (WT)` AX2, `:1390 (WT)` AX14) ⇒ l'arrêt est **re-armable** : toute perte du jeton ré-arme `ReqStart` (`:913`, `:1387 (WT)`). |
| **Pourquoi c'est LA correction** | Avec le verrou **dans l'axe**, un rebond de capteur ne peut plus créer de mouvement : même si le demandeur recrée sa demande, `RampTargetPct := 0.0` (`FB_Translation.st:251`, terme `ArrivalLock`) interdit toute rampe. **C'est la neutralisation de H1 à la racine** — et non le retour au neutre, qui n'en était qu'un pansement gestuel. |
| **Conséquence** | Lot **L1** : rendre la détection d'arrivée indépendante de la demande, et publier un fait d'arrêt confirmé consommable par le demandeur. **Aucune** modification de la porte de transition AX2/AX14 dans ce mouvement. |

### 🔴 Q2 — Cible : **NON à l'uniformisation « la cible suit le sens commandé partout »** ; la cible d'étape reste la cible d'arrêt

| | |
|---|---|
| **Décision** | On **rejette** la recommandation §7.2-2 du comparatif. En `SEMI_AUTO`, la cible d'arrêt reste **celle de l'étape** (`SelTarget := ReqTranslation.PositionTgt`, `FB_TranslationCmdArbitrationM3.st:65` → `PRG_05:408-412`). La sélection par **sens commandé** (`PRG_05:413-428`) reste la voie du mode **manuel** (`SelTarget = 0`). |
| **Preuve** | `FB_CycleSemiAuto.st:905-906` documente l'intention (« AX2 accepte les deux sens … si Maintenance=1 et P1=0, cela permet de se dégager d'un dépassement ») et la **branche de récupération existe** (`:1549-1557` : retour gauche qui traverse P1, arrêt attendu **à P1**). Or `M3_AtP1Stable` s'arme sur **les deux fronts** de son capteur (`FB_Translation_PositionDecoder.st:116`). ⇒ Rendre la cible dépendante du sens en AX2 ferait **disparaître l'arrêt à P1** lors du retour de dégagement : **on détruirait un chemin de récupération existant**. |
| **Reformulation retenue** | Ce qui doit changer n'est pas **quelle** cible est sélectionnée, mais le fait que **la perte de la demande efface la détection** de cette cible (`PRG_05:427` : `M3_PositionSensorTarget := FALSE` dès que le sens retombe) ⇒ c'est **Q1 + Q3** qui corrigent le défaut, pas Q2. |
| **Conséquence** | La « contradiction de commentaires » (D02) se règle en **commentaire** (dire que la cible d'étape est la cible d'arrêt en SEMI_AUTO, et que la voie directionnelle est celle du manuel) — dans les fichiers autorisés du contrat, sans changement de comportement. |

### 🟢 Q3 — Retrait de la demande : **le demandeur CONSERVE sa demande jusqu'à la confirmation d'arrêt** (option a) ; l'option « la barrière commande l'arrêt » est **rejetée**

| | |
|---|---|
| **Décision** | Le séquenceur **ne retire plus** sa demande **ni** sa cible sur le jeton d'arrivée : il les conserve jusqu'à ce que l'axe ait **(i)** armé `ArrivalLock` **et** **(ii)** confirmé l'arrêt physique ; il retire **ensuite**, et alors seulement, demande + cible. |
| **Preuve (5 faits vérifiés)** | ① mot 0 = **roue libre** cote variateur (`FB_Translation.st:297-303` avec `:229-233` : `CommandedTremie/Maintenance` tombent dès `NOT (ReqTremie OR ReqMaintenance)`) — c'est **H4 à P1** ; ② **les deux voies de la cause 6 lisent la demande** (`FB_Translation.st:123-124` et `FB_Safety_Translation.st:200-201`) ⇒ le retrait **désarme l'escalade** à l'arrivée ; ③ la **coupure dure Trémie** exige `ReqTremieSemantic` (`PRG_06:431-432`) ⇒ désarmée à l'arrivée ; ④ les **verrous bistables de FdC** ne se libèrent que sur demande de sens inverse (`PRG_05:162-190`) ⇒ la direction de demande est le pivot de toute l'architecture ; ⑤ le **veto d'étape** (`PRG_05:656-662`) force frein + mot 0 **au changement d'étape** ⇒ avancer avec une demande vivante entre dans la classe de faute frein de T287. |
| **Option rejetée** | « la barrière COMMANDE l'arrêt au lieu de mettre le mot à 0 » : dupliquerait la fonction d'arrêt dans la barrière (`AF_Partie-02:502` « une commande unique par mouvement », `CODE_QUALITY_STANDARDS §5` producteur unique) **et** ne restaurerait pas les escalades ② ③, qui lisent la **demande**, pas le mot. |
| **Garde obligatoire** | L'attente d'arrêt doit être **bornée** : timeout **armé** → repli `AX_STAB` + défaut latche, **jamais** un maintien indéfini (leçon A14 : `DiveStartTimeoutTimer(IN := FALSE, …)` est déclaré mais désarmé). |
| **⚠️ Tension à traiter** | À la Trémie, garder la demande vivante **maintient armée** la coupure dure (`PRG_06:431-432`) ⇒ voir **Q7** (§6). |

### 🟡 Q4 — Bypass : **OUI, gater à la consommation sur le mode (MAINT_N2)**, sans toucher au stockage RETAIN

| | |
|---|---|
| **Décision** | Le bypass FdC est **filtré par le mode à son point de consommation** : `PRG_05:571` (`FB_Translation.BypassLimitSwitch`) et `PRG_05:468` (`FB_Safety_Translation.BypassLimitSwitch`). Doctrine appliquée : **MAINT_N2 uniquement** (`ST_BypassTranslation.st:4-5`). Le `Bypass.Global` est gaté de la même façon. **`PRG_07` n'est PAS touché** (interdit au contrat) — et devient inutile : un bit RETAIN restauré ne peut plus agir hors MAINT_N2. |
| **Preuve** | Un seul bypass neutralise **trois** barrières : verrou d'arrivée (`FB_Translation.st:190`), cause 6 du FB (`:123`), cause 6 safety (`FB_Safety_Translation.st:199`). Il est **restauré au boot depuis le RETAIN** (`PRG_07_Supervision.st:336-346`) et consommé **sans garde de mode**. |
| **Conséquence** | Lot **L1** (fichier `PRG_05_Translation.st`). ⚠️ Retire des capacités de mise en service hors MAINT_N2 ⇒ **décision humaine D1** (§8). |
| **Alerte maintenue (hors lot)** | Le RETAIN reste un piège si la machine **reboote en MAINT_N2** : toutes les sécurités M3 sont alors neutralisées sans geste conscient. Tâche dédiée. |

### ⛔ Q5 — Escalade aux butées : **HORS LOT (confirmé)**

| | |
|---|---|
| **Décision** | **Hors périmètre T334.** Contrat dédié (sécurité, C3/C4). |
| **Preuve** | `FB_Safety_Translation.st` est **interdit** au contrat T334 (scope.forbidden) ⇒ structurellement impossible ici. L'écart est réel et chiffré : spec `AF_Partie-11_v2.4.md:346-351` (0 → <2,5 s arrêt directionnel seul ; ≥2,5 s `SafeStop` + `ErrorLimitSwitch` ; ≥5,0 s `PowerCutOff` latché) vs code `FB_Safety_Translation.st:202` (**1,5 s**) + `:268` (**`PowerCutOff` immédiat** dès que bit 6 actif, sans gradation). La section de spec porte d'ailleurs déjà le titre « (T287) ». |
| **Conséquence** | Transmis tel quel ; à ouvrir par le porteur T287 ou un contrat dédié. Aucune ligne de ce plan n'en dépend. |

### ⛔ Q6 — Config morte `_TranslationAutoSpeedCap_Pct` : **HORS LOT + recommandation SUPPRIMER**

| | |
|---|---|
| **Décision** | **Hors périmètre T334** (`CODE/GVL_PERSISTENT.st` et `CODE/J_SUPERVISION/` sont interdits au contrat). Tâche dédiée. **Recommandation : supprimer** la variable persistante **et** son champ IHM. |
| **Preuve** | `GVL_PERSISTENT.st:97` `_TranslationAutoSpeedCap_Pct := 40.0` (« Plafond vitesse SEMI_AUTO »), **0 lecteur** (grep dépôt : seule occurrence = la déclaration) alors que le cycle commande **`SpeedPct := 100.0` fixe** (`FB_TranslationCmdArbitrationM3.st:74`). ⇒ l'IHM expose un plafond qui n'existe pas : **information opérateur fausse** (`CODE_QUALITY_STANDARDS:507-513`, code/config mortes). |
| **Bémol à trancher** | H3 (§9bis) chiffre un **aggravant** : à 100 % vs 40 % le manuel, la distance d'arrêt croît en v² (≈ +56 %). Réactiver le plafond serait donc une **mitigation**, pas la cause racine. Si l'humain la veut, alors : (a) `CODE/GVL_PERSISTENT.st` sort de la liste interdite, (b) un AC dédié est ajouté, (c) décision tracée au contrat. **Décision humaine D2** (§8). |

### 📌 Synthèse

| Question | Décision | Lot | Fichier(s) |
|---|---|---|---|
| Q1 autorité de l'arrêt | 🟢 OUI — verrou armé par la seule détection, relâchement = sens inverse seul | L1 | `FB_Translation.st`, `PRG_05_Translation.st` |
| Q2 cible / sens | 🔴 NON — cible d'étape conservée ; correction par Q1+Q3 (+ commentaires) | L1 | idem |
| Q3 retrait de la demande | 🟢 OUI — demande conservée jusqu'à l'arrêt confirmé, timeout armé | L2 | `FB_CycleSemiAuto.st` (verrou T331) |
| Q4 bypass | 🟡 OUI — garde de mode à la consommation (D1) | L1 | `PRG_05_Translation.st` |
| Q5 escalade butées | ⛔ HORS LOT (contrat dédié, section spec déjà « T287 ») | — | `FB_Safety_Translation.st` (interdit) |
| Q6 config morte | ⛔ HORS LOT, recommandation suppression (D2) | — | `GVL_PERSISTENT.st` (interdit) |

---

## 🧱 2 · Modèle cible — 7 invariants

| # | Invariant | Porté par |
|---|---|---|
| **I1** | L'arrêt d'arrivée est **possédé par l'axe** : armé par la seule détection qualifiée, jamais levé par la perte de la demande, relâché **uniquement** par une demande explicite de sens inverse | `FB_Translation` |
| **I2** | Le demandeur **conserve** demande + cible jusqu'à `ArrivalLock` **et** arrêt confirmé ; le mot de commande ne tombe **jamais** à 0 pendant un mouvement | `FB_CycleSemiAuto` (+ manuel inchangé) |
| **I3** | La **perte** de la demande ne peut plus effacer la détection d'arrivée (debounce 100 ms) | `PRG_05_Translation` |
| **I4** | **Aucune logique d'arrêt nouvelle dans le séquenceur** : `JoystickPushOnly` (`:718`) et `NOT JoystickDeflected` (`:1395 (WT)`) **restent en place** (ne pas défaire T319 sans garde équivalente) | — |
| **I5** | La confirmation d'arrêt n'est pas **vacuaire** : `ABS(fAct) ≤ 0,5 Hz` (`PRG_05:817`) **+** un fait mécanique de frein ; la vacuité au banc est **écrite** dans l'AC | `FB_Translation`, tests |
| **I6** | Les protections restent **armables à l'arrivée** : cause 6 (les 2 voies), coupure dure Trémie, verrous bistables FdC, escalade `PowerCutOff` | vérifié par AC |
| **I7** | Tout timeout d'attente est **armé** (jamais déclaré seul) et sanctionne par un repli sûr | `FB_CycleSemiAuto` |

---

## 🧩 3 · Lots séquencés

| Lot | Objet | Périmètre | Préalable |
|---|---|---|---|
| **L0** | **Prouver** (read-only + procédure) : run de trace 10 ms humain (protocole A/B/C) **enrichi** des signatures concurrentes — `PRG_06.M3_TremieHardStopActive` (§B.2), `BrakeCmd` interne vs `M3_BrakeIsOpen_DI`, `BrakeTimeoutElapsed` et `Brake.ContactorCheck` (§B.4) ; corriger la matrice §5 ; requalifier le lien T287 **sur le mécanisme frein** (§D) ; re-référencer toute la fiche sur la **révision figée** | fiche, procédure, CSV | aucun (run humain) |
| **L1** | **L'axe possède son arrêt** : détection indépendante de la demande (I1/I3), `ArrivalLock` non levé par la perte de demande, publication d'un fait public d'arrêt confirmé (`VAR_OUTPUT` à déclarer), garde de mode des bypass (Q4) | `CODE/I_TRANSLATION/FB_Translation.st`, `CODE/M_MAIN/PRG_05_Translation.st`, tests `I_TRANSLATION` + `M_MAIN` | **GO humain** + §8 D1 |
| **L2** | **La demande survit à l'arrêt** : chronologie AX2/AX14 (retirer demande + cible **après** confirmation, pas sur le jeton), timeout d'attente armé | `CODE/G_CYCLE/FB_CycleSemiAuto.st`, tests `G_CYCLE` | **L1 prouvé** + **verrou T331 libéré** + §8 D5 |
| **L3** | **Sort du neutre** — OPTIONNEL : réévaluer `JoystickPushOnly` / `NOT JoystickDeflected` **seulement** si L1+L2 sont prouvés et tracés ; sinon **documenter** l'asymétrie (message opérateur cohérent) | `FB_CycleSemiAuto.st`, IHM | L1+L2 prouvés + §8 D4 |
| **L4** | Hors lot ici : Q5 (escalade), Q6 (config morte), A13 (délai de collage frein jamais appliqué), A14 (timeout AX3 désarmé), A15 (commentaire faux sur la libération des jetons), T287 (frein), RETAIN bypass | — | contrats dédiés |

> 🔗 **Ordre imposé par la preuve** (challenger §E, retenu) : **prouver (L0) → l'axe possède l'arrêt (L1) → le demandeur s'aligne (L2) → alors seulement, et éventuellement, relâcher le neutre (L3).**
> ⛔ `L3` **ne peut pas** être mené seul : c'est exactement le lot P2 arrêté, dont le mécanisme de boucle (tempo d'arrêt à 500 ms **continus** + ré-armement immédiat de la demande, `FB_CycleSemiAuto.st:334-338` / `:913`) a été confirmé sur le code.

---

## ✅ 4 · Critères d'acceptation à ajouter (AC11 → AC16)

| ID | Énoncé (ce que la **machine** fait) | Preuve |
|---|---|---|
| **AC11** | Capteur d'arrivée **intermittent ~1 s** avec geste maintenu : **aucun** front montant de `M3_CommandWord` **ni** de `M3_SetpointFrequencyHz` après l'armement du verrou d'arrêt (le réarmement de la demande ne produit aucun mouvement) | test CI + trace, colonnes mot/fréquence/verrou |
| **AC12** | Le mot de commande reste **non nul pendant toute la décélération d'arrivée** : aucun passage à 0 avant confirmation `ABS(fAct) ≤ 0,5 Hz` (fin de H4 à P1) | trace 10 ms, colonnes `M3_CommandWord`, `M3_SetpointFrequencyHz`, `fAct` |
| **AC13** | À P1 (où la coupure dure n'existe pas), la **cause 6 reste armable** avec la demande vivante : dépassement soutenu 1,5 s ⇒ `ErrorLimitSwitch` puis `PowerCutOff` | test CI sur `FB_Translation`/`FB_Safety_Translation` + trace |
| **AC14** | Parité manuel / cycle : écart ≤ **1 échantillon de 10 ms** entre le front capteur et l'extinction du mot, sur les 3 scénarios (A/B cycle, C manuel) | comparaison des CSV wide |
| **AC15** | Test CI **rouge avant / vert après**, portant sur les **sorties publiques** de l'axe, **avec `Translation_Busy` injecté à TRUE** (sinon l'assertion est vacuaire) ; la restitution **écrit** qu'un PASS banc ne vaut pas preuve terrain | sortie `run_tests.py` avant/après |
| **AC16** | L'attente d'arrêt est **bornée** : aucun maintien indéfini — timeout ⇒ repli `AX_STAB` + défaut latche | test CI (leçon A14) |

> ⚠️ **Faisabilité au banc** (exigence §10bis F) : au banc `M3_ActualFrequencyHz = 0` constamment ⇒ `Translation_Busy := (ABS(fAct) > 0,5) = FALSE` **permanent**. Tout AC fondé sur cette donnée est **vacuaire en simulation** : il doit être joué en **CI avec entrées injectées** et **validé sur trace terrain**.

---

## 📦 5 · Preuves requises (par lot)

`trace_10ms_analyse` · `ci_before_after` · `check_linkage` (`G200_check_linkage.py --report`, **bloquant**) · `run_all_gates.py --palier C` · bundle complet + **diff bundle** · `git diff` réel relu par l'orchestrateur. Les AC structurels AC8/AC9 du contrat parent (nom de fichier = nom de POU, suffixe = langage du bundle) restent exigés pour toute écriture `CODE/M_MAIN/`.

---

## 🚨 6 · Questions ouvertes & alertes (hors Q1→Q6)

| # | Sujet | État |
|---|---|---|
| **Q7** 🆕 | **Arrivée nominale Trémie vs coupure dure.** `M3_TremieHardStopActive := M3_PosTremie_DI AND ReqTremieSemantic` (`PRG_06:431-432`) force frein fermé + mot/fréquence à 0 **au même scan**. La coupure dure est **voulue** (commentaire `:428-430`) mais son armement est **couplé à la demande** : dès que le chariot touche le capteur Trémie en demandant, on entre dans la classe de faute frein de T287 (désaccord commande/retour ≥ 800 ms, `FB_Brake`). Aujourd'hui, c'est **le retrait de demande du cycle** qui la désarme 1 scan plus tard. ⇒ Conserver la demande jusqu'à l'arrêt (Q3/I2) **prolonge** cette exposition à la Trémie. **À trancher sur trace (L0)** avant L2. | 🔴 ouvert — décision humaine **D3** |
| **A13** | `TonDecel.Q` jamais lu (`FB_Brake.st:72,93,103-104`) : `BrakeDelayMotorDecel = T#2s` sans effet ⇒ config morte sur la chaîne frein. **Périmètre T287**, hors T334 | signalé, non corrigé |
| **A14** | `DiveStartTimeoutTimer(IN := FALSE, …)` : le timeout de repli du modèle AX3 est **désarmé** ⇒ le modèle qu'on envisage de généraliser porte lui-même une garde non armée | signalé (AC16) |
| **A15** | `PRG_05:197-201` affirme que les jetons sont libérés « uniquement sur mouvement confirmé soutenu ≥1,5 s » ; l'implémentation les RAZ sur **changement du mot capteurs** (`:275-277`) et `TonM3ConfirmedMoving.Q` n'est **jamais lu** ⇒ commentaire **faux**, et c'est précisément la bascule de H1 | signalé, hors lot |
| **A16** | Conflit AF-09 / Graphe 7 (`UseDynamicTarget`) : le code porte le REX de l'incident de synchronisme (`FB_CycleMachineHoming.st:412-420`) ⇒ question mal cadrée côté T336 | hors T334 |
| **A18** | `CODE/G_CYCLE/FB_CycleSemiAuto.st` sous **verrou d'écriture T331/DSH09** : L2/L3 **cassent** la règle « un seul agent écrit dans un même périmètre » s'ils démarrent avant libération | 🔴 séquencement **D5** |

---

## ⛔ 7 · Ce que ce plan ne fait pas

- Aucune ligne de `CODE/`, aucun test, aucun gate, aucun bundle, aucun commit.
- **Aucune** modification de la porte de transition AX2/AX14 telle que demandée en Phase 2 (lot **arrêté**) : le neutre **n'est pas** retiré. Il n'est réévalué qu'en L3, après preuve.
- Aucune correction de T287 (frein), T300/T301/T333, Q5 (escalade), Q6 (config morte), A13-A16, IHM, `Device.export`.
- Le dépassement **reste un défaut tracé**, jamais un comportement admis.

---

## 🙋 8 · Décisions humaines requises avant d'ouvrir L1/L2

| # | Question | Recommandation |
|---|---|---|
| **D1** | Q4 — gater les bypass M3 sur **MAINT_N2** à la consommation (retire la capacité de mise en service hors N2) ? | 🟢 **OUI** (doctrine `ST_BypassTranslation.st:4-5`) ; alternative : MAINT_N1+N2 |
| **D2** | Q6 — **supprimer** la config morte `_TranslationAutoSpeedCap_Pct` (information IHM fausse) ou la **réactiver** comme mitigation du dépassement (élargit le périmètre) ? | 🟢 **supprimer** dans un contrat dédié ; la mitigation éventuelle se décide **sur trace** |
| **D3** | Q7 — accepter que l'arrivée nominale Trémie arme la **coupure dure** (frein forcé fermé en mouvement), ou découpler la coupure dure de la demande ? | 🟡 **à trancher sur trace (L0)** — ne pas découpler sans mesure |
| **D4** | L3 — **abandonner** l'uniformisation du neutre, ou la différer après L1+L2 prouvés ? | 🟢 **abandonner** (l'asymétrie est une décision T319 + garde mécanique du modèle AX3) ; documenter pour l'opérateur |
| **D5** | L2 — séquencer l'écriture `FB_CycleSemiAuto.st` **après libération du verrou T331/DSH09** | 🟢 **OUI** (aucune exception) |

---

## 📝 9 · Journal

- 2026-09-20 (session T334, acteur **DSH07**) : arbitrage Q1→Q6 rédigé **sans aucun code**. Toutes les références de ce plan ont été relues **directement** dans les sources (`FB_Translation.st`, `FB_Safety_Translation.st`, `PRG_05_Translation.st`, `PRG_06_Outputs.st`, `PRG_07_Supervision.st`, `FB_Brake` via fiche, `FB_CycleSemiAuto.st`, `GVL_PERSISTENT.st`, `ST_BypassTranslation.st`, `AF_Partie-11_v2.4.md`), jamais recopiées d'une analyse antérieure. Deux citations du contrat parent corrigées (FAIT 5 / `PRG_07`), une nuance ajoutée à la valeur citée par le challenger (`:336-346` et non `:331-341`).
- Le lot « Phase 2 — uniformiser AX2/AX14 sur AX3 » est **ARRÊTÉ** sur verdict challenger §10bis, confirmé côté porteur par un mécanisme vérifié : `TranslationStopTimer` exige **500 ms continus** de `At_P1 ∧ ¬Busy` (`FB_CycleSemiAuto.st:334-338`) tandis que le ré-armement de la demande est **immédiat** (`:913` / `:1387 (WT)`, permis `:716-717`) ⇒ sous capteur qui rebondit, la transition ne peut **jamais** s'armer et la demande se ré-arme à chaque rebond : le neutre était la **seule** soupape. Aucune correction n'est proposée pour cette porte : c'est **l'axe** qui doit posséder l'arrêt (Q1/I1).
- `git status --short` : aucun fichier `CODE/` écrit par cette session ; seules modifications présentes = chantiers concurrents.
