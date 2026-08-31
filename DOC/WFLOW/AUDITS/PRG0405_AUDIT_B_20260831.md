# 🔍 PRG_04 / PRG_05 — Contre-audit indépendant B (2026-08-31)

> **Position** : Review impartial, pas alarmiste. Expert Senior Automatisme Industriel /
> POO IEC 61131-3 / Sécurité machine (ISO 13849).
> **Objet** : challenge de l'audit A (charge, lisibilité, restructuration pour débogage sur
> site) sur `PRG_04_Treuils_Benne` et `PRG_05_Translation`. Recherche d'opportunités
> complémentaires. Vérification de l'impact **safety** de toute restructuration.
> **Sources relues** : PRG_04 (1260 l), PRG_05 (450 l), `FB_Winch`, `FB_BucketCmdArbitration`,
> `FB_TranslationCmdArbitrationM3`, `FB_Translation`, `FB_Modes`, `E_Mode`, `CODE_QUALITY_STANDARDS`,
> AF-10, AF-11, `PLAN_GEL_TREUIL_T181`, `AUDIT_STRUCTS_MAPPING_20260827`.

---

## ⚖️ 0 · Verdict en bref

| Question | Réponse |
|---|---|
| L'audit A est-il pertinent ? | ✅ Oui sur la **charge** (PRG_04 1260 l) et la **duplication M1/M2**. |
| L'audit A est-il à jour ? | ⚠️ **Semble basé sur une version cible antérieure au code actuel.** Plusieurs extractions qu'il propose (« extraire direction-interlock, step-shaper ») sont **déjà implémentées** dans `FB_Winch` courant. Risque réel de proposer du « déjà fait ». |
| Risque safety ? | 🟢 **Aucun réordonnement dangereux identifié si les lags 1 scan documentés sont préservés.** Les 3 lags structurels (§2, §5bis PRG_04, §1bis PRG_05) sont explicitement documentés et sûrs. |
| Point safety que l'audit A aurait pu manquer | 🔴 `FB_WinchRateInterlock` (T181-01) **n'existe pas** dans le code alors que `SpeedGuardEnable := FALSE` (PRG_04 :896/944) y est justifié (« la gouvernance passe par... »). **Garde-fou vitesse mesurée hors service** en attendant un FB absent. |
| Robustesse POO | 🟢 Bonne (composition, producteur unique via `Data`, Reset sur front). ⚠️ 2 points : écriture directe `GVL_IHM.*` depuis PRG_04, états `FBState := E_State.READY` figés. |

**Verdict** : PRG_04/05 sont **sûrs et lisibles par régions** pour une machine en site. La restructuration est une **option de C3 (confort/qualité)**, pas une obligation. Elle doit se faire **sans réordonner les appels** ni toucher `FB_Safety_*`. La seule dette qui touche la **sécurité** est la référence à `FB_WinchRateInterlock` inexistant — à trancher avant tout refactor.

---

## 🧾 1 · Le contenu réel des fichiers (base factuelle)

### PRG_04_Treuils_Benne.st — 1260 lignes

| Région | Rôle | Lignes |
|---|---|---|
| §1 | Intention maintenance & assistants (both, extraction) | 211–256 |
| §2 | Commande benne (`instBucket`) + dégradations | 258–327 |
| §3 | Arbitrage consignes M1/M2 (`instArbM1/M2`) | 329–430 |
| §3bis | ArmingPermit (Option B) | 432–442 |
| §4 | Synchronisation (`instWinchSync`) | 444–482 |
| §5 | Couplage croisé & sécurités (permit M1/M2) | 484–571 |
| §5-0 | Matrice maintenance N1/N2, bypass effectifs, override FDC | 573–639 |
| §5bis | Sécurité treuils (`instSafetyWinchM1/M2`) | 641–801 |
| §5ter | Agrégateur clamp de palier | 803–839 |
| §6 | Exécution `instWinchM1/M2` + estimateurs | 841–967 |
| §7 | Publication demandes brutes | 969–1006 |
| §8 | Publication états IHM | 1008–1259 |

**Origine de la charge** : la duplication structurale **M1 ↔ M2**. Chaque bloc M1 est quasi
dupliqué en M2 :
- `instSafetyWinchM1` (≈58 l, :646–704) ≈ `instSafetyWinchM2` (:706–760)
- `instWinchM1` + assemblage `M1DriveRequest/M1WinchSensors/M1WinchCfg` (≈45 l) ≈ M2
- Publication `WinchM1State` (≈50 l) ≈ `WinchM2State`

Cette duplication est **impossible à factoriser par une boucle** (CODESYS n'a ni table
d'instances ni générique), mais **factorisable par fonction de remplissage** (voir §3).

### PRG_05_Translation.st — 450 lignes

| Région | Rôle | Lignes |
|---|---|---|
| §0 | Décodage position M3 (`instPosDecoderM3`) | 69–96 |
| §0 | Interlock hauteur M1/M2 | 98–115 |
| §0bis/0ter/0quater | Coupure dure, stabilisation bistable Fdc, mémorisation dernier point | 117–171 |
| §1 | Arbitrage cible & direction (`instArbM3`) + SafeStop input module | 173–238 |
| §1bis | Sécurité M3 (`instSafetyTranslationM3`) | 240–283 |
| §2 | Pilotage translation (`instTranslationM3`) + estimateur | 285–352 |
| §3 | Publication demande brute | 354–367 |
| §4 | Publication état IHM | 369–449 |

PRG_05 est **bien plus léger et lisible** que PRG_04. Les régions §0bis→§0quater forment
cependant une petite machine d'état inline (verrous bistables) qui est un candidat
d'extraction secondaire.

---

## 🔄 2 · Contre-analyse des propositions de l'audit A

> ⚠️ **Pas de document « audit A » dédié trouvé sur disque.** Les propositions de
> restructuration formelles les plus proches sont celles de la **« Revue experte #1 »** de
> `PLAN_GEL_TREUIL_T181_v0.1.md` (et `FB_WinchStepShaper`/`AF10_INTERFACE_TREUIL_CIBLE_T181`).
> Le contre-audit porte donc sur ces propositions et sur les thèmes demandés
> (charge / lisibilité / restructuration débogage).

### 2.1 Propositions vs état réel du code

| Proposition audit A | État dans `FB_Winch.st` actuel | Verdict contre-audit |
|---|---|---|
| « Extraire l'interlock de changement de sens » | ✅ **Déjà fait** : `FB_WinchDirectionInterlock` instancié `VAR` et appelé §4 (:189–196). | ⚠️ Proposition **périmée** — déjà réalisée. |
| « Extraire le step-shaper / cadencement de palier » | ✅ **Déjà fait** : `FB_WinchStepShaper` instancié `VAR` et appelé §5 (:259–263). | ⚠️ Proposition **périmée** — déjà réalisée. Voir `AF10_INTERFACE_TREUIL_CIBLE_T181`. |
| « Délais d'interlock direction détournés en tempo de rampe » | ✅ Corrigé dans le code courant : cadence distincte `StepRampDelayAscent/Descending` (:254–258), plus aucune réutilisation des délais d'interlock. | 🟢 Résolu. |
| « `SEL` direction nommé à l'envers » | ✅ Disparu : le sens est décodé par un `IF CommandedDirection = -1` clair (:254). | 🟢 Résolu. |
| « `ContactorStuck` dupliqué » | ✅ Commentaire explicite : detection déplacée vers `FB_Safety_Winch` (T181-08), `FB_Winch` ne produit plus ce défaut (:114–119). | 🟢 Résolu. |
| « Entrées mortes `Mode`/`CycleTimeCalc` » | ✅ L'interface `FB_Winch` actuelle n'a **plus** `Mode`/`CycleTimeCalc`. | 🟢 Corrigé. |

**Conclusion 2.1** : L'audit A, tel qu'il transparaît dans la revue experte #1 / plan T181,
décrit la **cible d'une refactorisation déjà aboutie**. Un nouvel audit A doit être re-calé sur
**le code d'aujourd'hui**, sous peine de ré-ouvrir des tickets inutiles ou de créer des diff
de confusion. **Le contre-audit recommande : ne pas ré-proposer ces extractions.**

### 2.2 Risques des propositions de regroupement (génériques)

Les trois risques demandés — analysés :

- **Impact safety** : toute extraction d'un bloc **qui consomme un state du PRG amont** doit
  préserver l'**ordre d'appel**. Aujourd'hui `instSafetyWinchM1/M2` (§5bis) sont appelés **avant**
  `instWinchM1/M2` (§6) pour lire `RelayFwd/Rev` du **scan précédent** (documenté :644–645).
  Un refactor qui regrouperait safety+winch dans un FB composite changerait ce lag → **ne pas faire**.
- **Lag 1 scan** : 3 lags **documentés et assumés** dans le code sont à protéger :
  1. PRG_04 §2 :294–295 — `M1/M2LogicRequestDirection` consommé avant son calcul §3.
  2. PRG_04 §2 :301–302 — `instSafetyWinchM1/M2.ErrorId` lu avant l'exécution §5bis.
  3. PRG_05 §1bis :242–245 — safety M3 lit `BrakeReleaseRequest`/`BrakeCmd` du scan précédent.
  Tous sont bénins (≤1 scan 10 ms). **Une restructuration qui « optimiserait » ces lags
  changerait le comportement de la barrière finale → interdit sans re-qualification TC.**
- **Producteur unique** : le bus `Data : ST_WinchInterPrg` (PRG_04) et
  `Data : ST_TranslationInterPrg` (PRG_05) est écrit **une seule fois**, en fin de POU. Aucun
  point de double écriture identifié. ⚠️ Seule exception : `GVL_IHM.Commun.Kobold*` écrit par
  PRG_04 (:1225–1226) — voir §6.1.

---

## 🧱 3 · Autres regroupements proposés (complémentaires à l'audit A)

Opportunités **non** couvertes par l'audit A, classées par gain/risque.

### Recommandé (C3, faible risque, fort gain lisibilité)

**A. Fonction de remplissage des structs M1/M2.** Factoriser en `FUNCTION FC_RemplirDriveRequest`
/ `FC_RemplirSensors` le ~45 l de câblage `M1DriveRequest`/`M2DriveRequest` aujourd'hui dupliqué
(:872–899 et :919–949). Signe/axe passé en paramètre. → supprime ~80 l dupliquées. **Sans impact
safety** (pur remplissage, même valeurs).

**B. Fonction de publication des états M1/M2.** Factoriser `WinchM1State`/`WinchM2State`
(:1013–1124) en un helper prenant (instWinchMx, encodeurMx, PRG_06 interlock) → dest
`ST_WinchState` par référence. → supprime ~100 l dupliquées. Lecture seule : zéro impact conduite.

**C. Regrouper la taxonomie permit dans un struct par axe.** Les 16 booléens
`*Permit{1,2}_{Ascent,Descend}` + `EffectivePermit*` (:117–132) pourraient vivre dans un
`ST_EffectivePermit` (Safety / Process / S&P / Effective × 2 sens) pour faciliter le debug
et l'IHM, SANS changer la logique OU/AND.

### Secondaire (C3, à peser)

**D. Extraction des verrous bistables PRG_05 §0bis–§0quater** (M3_LimitSwitch*Stable,
M3_AtXxxStable, TonM3ConfirmedMoving) dans un petit FB `FB_PositionLatch`. Gain lisibilité clair.
⚠️ Risque faible mais réel de changement de temporisation si mal extrait → exiger **bit-identical**
(TC « même mot capteur → même sortie sur N scans »).

**E. Candidat NEGATIF (ne PAS faire)** : regrouper §5bis+§6 PRG_04 en un FB composite
safety+conduite. **Cela casserait le lag 1 scan safety ↔ treuils** (cf. §2.2). Refuser.

---

## 🛠️ 4 · Diagnostic terrain (débogage sur site)

### Forces actuelles
- ✅ `FinalInterlockReason`/`ErrorId` remontés dans `ST_WinchInterPrg`/`ST_TranslationInterPrg`
  et consommés par `FB_TroubleshootingView` → bonne boucle IHM.
- ✅ Taxonomie permit (D-P1..D-P11, `NAMING_CONVENTION :426`) bien documentée.
- ✅ Régions `§N` numérotées et alignées `{region}` (standard §2bis) dans les DEUX PRG.

### Faiblesses à corriger pour le site

| # | Constat | Impact terrain | Suggestion |
|---|---|---|---|
| 1 | **`FBState := E_State.READY` / `FinalInterlockState := E_State.READY` figés** (PRG_04 :1020/1036, PRG_05 :371/408) : `FBState` est **forcé à READY** quelles que soient les conditions réelles. | L'IHM ne peut pas distinguer « en défaut », « neutralisé », « en marche » → **diagnostic aveugle**. | Publier le **vrai** état (`Ready/Busy/Done/Error`), pas une constante. |
| 2 | **Pas de struct « pourquoi bloqué » consolidé** : les 16 permit + SafeStop sources sont des booléens épars, pas un raison de blocage unique. | Opérateur égrène 8+ bits pour trouver le blocage. | Exporter une raison de blocage prioritaire (`E_WinchBlockReason`) calculée en PRG_04 §5. |
| 3 | **`GVL_IHM.Commun.KoboldImmersionConfirmed` / `KoboldBottomTouchLatched` écrits directement par PRG_04** (:1225–1226). | Écriture IHM depuis un PRG de procédé = canal informel (contraire à la règle « PRG produit via `Data`, pas via `GVL_IHM.Cmd` »). | Passer par le bus `Data` / une struct état, puis miroir en supervision. |
| 4 | **Horodatage / dernière cause absent** au niveau PRG. | Pas de « dernier blocage à 14:32 » pour le post-traitement. | Ajouter `LastBlockingReason` + timestamp (1 scan, mémoire). |

### Trace recommandée
Suggérer une **struct de trace** (`ST_TraceWinch`, `ST_TraceTranslation`) publiée dans `Data` et
consommée par `FB_TroubleshootingView`, contenant : permit effectifs par sens, cause de blocage
prioritaire (enum), état SafeStop source (input module vs safety vs sync), dernier
changement d'état horodaté. **C'est le levier n°1 pour le dépannage sur site** — plus utile
qu'une nouvelle extraction.

---

## 🧩 5 · Robustesse POO

| Critère | État | Note |
|---|---|---|
| 1 FB = 1 responsabilité | 🟢 Bon | `FB_Winch` directeur + `FB_WinchDirectionInterlock`/`StepShaper` extraits. |
| Producteur unique | 🟢 Bon (`Data` VAR_OUTPUT) | ⚠️ cf. §6.1 pour `GVL_IHM.Commun.Kobold*`. |
| Composition > héritage | 🟢 Bon | `FB_Translation` compose `FB_Brake` réutilisé. |
| `Reset` sur front | 🟢 Bon | `ResetEdge` R_TRIG partout (`FB_Winch`, `FB_Translation`, PRG). |
| Jamais de redémarrage auto | 🟢 Bon | défauts latchés, re-homing obligatoire (PRG_04 :629–638). |
| Internes privés / contrat interface | 🟢 Bon | structs `ST_fbWinch_*`, aucun accès interne sauvage. |
| États figés dans les PRG | 🔴 **Faible** | §4 #1 — `FBState` forcé READY. |
| Garde-fou vitesse `SpeedGuardEnable := FALSE` | 🔴 **Dette safety** | §6.2. |

**Verdict POO** : architecture **fiable**. Les FB sont propres, la composition est saine. Les
deux points faibles ne sont pas structurels (données mal publiées / une constante figée), pas
des défauts d'encapsulation.

---

## ⚠️ 6 · Points que l'audit A aurait pu manquer

### 6.1 Écriture `GVL_IHM.*` depuis un PRG de procédé
PRG_04 écrit `GVL_IHM.Commun.KoboldImmersionConfirmed/KoboldBottomTouchLatched` (:1225–1226).
La règle `GUIDE_VISUALISATION_CODESYS` : « Une variable `GVL_IHM.*.Cmd` n'est écrite que depuis
la Visu; le PLC écrit `*.State` ». Ici, un **PRG métier écrit directement dans une GVL IHM** —
canal informel. À réorienter via `Data`.

### 6.2 ⛔ Dette safety : `FB_WinchRateInterlock` absent mais référencé
- PRG_04 :895–896 : `M1WinchSensors.SpeedGuardEnable := FALSE` justifié par
  « la gouvernance nominale du palier passe par FB_WinchRateInterlock (T181-01), pas par cette bande ».
- **Vérification (glob)** : `FB_WinchRateInterlock` **n'existe pas** dans `CODE/`.
- **Conséquence** : le garde-fou de **vitesse mesurée** (2ᵉ étage) est **hors service** et le
  relais annoncé (« RateInterlock ») n'est **pas livré**. Si T181-01 n'est pas planifié au
  prochain gel, il faut soit le créer, soit **re-mapper la gouvernance** (par ex. re-activer la
  bande correctement configurée), soit **acter explicitement** le risque en documentation.
  C'est le seul point où une dette documentaire touche à la sécurité.

### 6.3 `SEMI_AUTO` — cohérence à re-valider
`AUDIT_STRUCTS_MAPPING_20260827` signale `E_Mode.SEMI_AUTO` « jamais assignée » côté `FB_Modes`.
Le code courant `FB_Modes` gère bien `SEMI_AUTO` (repli N1 :203–211, gates :132–138) et `FB_Cycle`
est le producteur des demandes en SEMI_AUTO. → Probablement corrigé entre-temps, mais **à
re-confirmer par un test** (le mode semi-automatique de la translation M3 et du cycle benne
dépend de cette valeur).

### 6.4 Champs « morts » dans `ST_fbBucket_State`
`AUDIT_STRUCTS_MAPPING_20260827` liste `M2StartStop`, `M2Direction`, `M2ForceSlowSpeed`,
`RemainingTravel_M`, `M2PositionCorrected` comme **MORTs (jamais lus)**. Nettoyage possible,
mais ⚠️ certains peuvent être relus par `FB_TroubleshootingView` — **re-vérifier par linkage
G200 avant suppression**.

---

## 🎯 7 · Actions recommandées (priorisées)

| # | Action | Criticité | Effort | Type |
|---|---|---|---|---|
| A1 | **Recaler l'audit A sur le code courant** : marquer comme « déjà fait » direction-interlock, step-shaper, SEL, entrées mortes. | C3 | Faible | Audit |
| A2 | **Trancher la dette `FB_WinchRateInterlock`** : créer OU re-mapper la gouvernance `SpeedGuardEnable`, OU acter le risque explicitement. | **C3→C2 safety** | Moyen | Conception |
| A3 | Publier le **vrai état** (`FBState`, `FinalInterlockState`) au lieu de `E_State.READY` figé. | C3 | Faible | Code |
| A4 | **Struct de trace terrain** `ST_TraceWinch`/`ST_TraceTranslation` (+ dernière cause horodatée) → `Data` → Troubleshooting. | C3 | Moyen | Code |
| A5 | **Factoiser les remplissages/publications M1/M2** (FC helpers). Bit-identique. | C3 | Moyen | Code |
| A6 | Réorienter `GVL_IHM.Commun.Kobold*` via `Data`. | C3 | Faible | Code |
| A7 | (**Refuser**) FB composite safety+treuil — préserver le lag 1 scan. | — | — | Non-action |
| A8 | Re-valider `SEMI_AUTO` et champs morts par linkage G200 avant suppression. | C2 | Faible | Test |

> Toute restructuration doit passer par : lecture standards (AF-10/11, AF-02, NAMING) → plan
> validé humain → implémentation **bit-identique** → bundle PLCopenXML → `G200_check_linkage.py`
> (bloquant) → `run_all_gates.py`. Aucun changement de comportement safety sans TC dédié.

---

*Fichier généré — contre-audit indépendant B. Sources relues listées en tête. Aucune
modification de `CODE/` effectuée lors de cet audit.*
