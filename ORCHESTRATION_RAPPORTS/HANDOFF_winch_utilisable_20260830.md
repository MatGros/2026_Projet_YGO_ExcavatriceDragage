# HANDOFF — « winch utilisable : joystick → contacteurs cohérent AF » — 2026-08-30

> Passation à l'agent suivant. Rédigé par Claude Code. **Rien n'est commité. Rien n'est testé par l'humain.**
> Objectif de session (goal) : *« winch utilisable … commande joystick commande les contacteurs
> de sorties de façons cohérentes comme défini par AF »*.

---

## 1. TL;DR

- La **descente** joystick→contacteurs est cohérente et verte (HARN-10/13b + AU/Enable/watchdog HARN-70/71/72/82, filet HARN-50/52).
- La **montée** est clampée palier 1 dans WINCH_INTEG pour HARN-13a/13c/20 — **cause identifiée** (voir §4), ce n'est **ni** un défaut FB_Winch **ni** le garde-fou vitesse.
- 3 modifs code en cours (§3), dont 1 **revert** de régression que j'avais introduite, et 1 correctif de conformité AF.
- 2 fichiers modifiés **pas par moi** dans le working tree (agent CI concurrent) — à ne pas committer (§6).

---

## 2. Contexte d'entrée

Session reprise sur compaction. Chantier initial = **T181-01 §7** (protocole §3bis `SenseHoldRequest`).
Plan §7 en 5 étapes (DESIGN `DOC/WFLOW/AUDITS/DESIGN/DESIGN_T181-01_PROTOCOLE_3BIS_v0.1.md`) :
1. FB_Winch : sortie `SenseHoldRequest` + garde interne — **fait, additif, CI vert**.
2. FB_WinchOutputInterlock : entrée `SenseHoldRequest` + §4ter consomme l'input — **fait puis REVERTÉ** (régression, §3).
3. `FB_WinchRateInterlock` (nouveau FB) — **draft deepseek produit, NON écrit sur disque** (§5).
4. FB_Safety_Winch : trigger `ContactorStuck` sur T_max — **pas commencé**.
5. Câblage PRG_04 + PRG_06 (même commit que 1-4) — **pas commencé**.

Puis le goal a été élargi à « winch utilisable » → bascule sur l'audit de la chaîne montée.

---

## 3. Modifs code dans le working tree (non commitées)

| Fichier | Nature | État CI | Garder ? |
|---|---|---|---|
| `CODE/H_TREUILS_BENNE/FB_Winch.st` | **T181-01 §7-1** : `VAR_OUTPUT SenseHoldRequest : BOOL` ; `VAR` `SenseHoldTimer:TON` / `SenseHoldActiveInt` / `PrevStepNumber:INT` / `SenseHoldHardCut` ; purge dans la gate `IF NOT Enable` ; région `§5bis` avant `END_FUNCTION_BLOCK` (calcul de `SenseHoldRequest`, `T_hold_internal = T#900ms` commenté PROVISOIRE). **Purement additif.** | `run_tests.py --fb FB_Winch` = **1 PASS / 0 FAIL** | Oui (additif, vert) — mais **non câblé** (aucun consommateur tant que §7-2..5 pas faits). Peut aussi être reverté si on ne finit pas §7. |
| `CODE/H_TREUILS_BENNE/FB_WinchOutputInterlock.st` | **T181-01 §7-2 REVERTÉ**. J'avais : ajouté `VAR_INPUT SenseHoldRequest` + réécrit `SenseHoldRequested := SenseHoldRequest AND …`. → a fait **repasser ROUGE TC-023a/b/c** (la CI ne pilote pas le nouvel input). Reverté aux 2 lignes d'origine + suppression du `VAR_INPUT`. **Le fichier = baseline commit `3b600251`** (seul `§6ter` de la sauvegarde subsiste). | `--fb FB_WinchOutputInterlock` = **7 PASS / 3 FAIL** (013, 021, 022) — artefacts timing STruCpp pré-existants (TON non tické par le harnais), FB conforme spec. 023a/b/c = **verts** à nouveau. | Oui (c'est la baseline). |
| `CODE/M_MAIN/PRG_04_Treuils_Benne.st` lignes ~868 et ~915 | **Correctif conformité AF** : `M1/M2WinchSensors.SpeedGuardEnable := TRUE` → `:= FALSE` + commentaire. AF = garde-fou **désactivé par défaut** (`FB_Winch_v2.1 §9bis`, `FB_Winch_v1.0:158` `:=FALSE`, `FB_SpeedStep_v1.0:33` `:= FALSE`). Le `TRUE` en dur était un **reste de mise en service** (confirmé par l'humain). | **N'a PAS changé** le résultat WINCH_INTEG (le clamp montée n'était pas le garde-fou — voir §4). | Oui (correct sur ses propres mérites, conforme AF). À faire valider par l'humain. |

**Aucun `git add`, aucun commit, aucun push.** Criticité C4 sur toute cette zone → arrêt validation humaine.

---

## 4. Cause racine du clamp montée palier 1 (HARN-13a/13c/20)

**Chaîne** : `PRG_04:789 IF instWinchSync.SyncDeviationWarn THEN CommonMaxStepUp := 1` (+ `CommonMaxStepDown := 1`).
Règle AF assumée : *« SyncDeviationWarn réduit les DEUX treuils »* (`PRG_04:784`).

`instWinchSync` → `FB_WinchSync` → `FB_SyncDeviation` :
```
SignedDeltaPosM := CablePosM1 - CablePosM2 + ActiveOffsetM;   (FB_SyncDeviation:67)
WarnActive := SyncEnable AND HomedAndReliableM1 AND HomedAndReliableM2 AND (DeltaPosM > CfgSyncToleranceM);  (seuil 0.10 m)
```
`ActiveOffsetM` vient de `instBucket.ActiveOffsetM` (`PRG_04:449`) — l'offset naturel benne/retenue,
résolu par FB_Bucket seulement si la benne est **homée / offset valide**.

**HARN-13a/13c/20** seedent `ModelSeedPosM1 := 2.0`, `ModelSeedPosM2 := 17.0` (**écart brut 15 m**),
`BucketSeedOpen := FALSE`, pas de homing benne → `instBucket.ActiveOffsetM ≈ 0` →
`SignedDeltaPosM ≈ 2 - 17 + 0 = -15 m` ≫ 0.10 m → **`SyncDeviationWarn = TRUE`** → `CommonMaxStepUp := 1`
→ montée plafonnée palier 1 quel que soit le % joystick.

**HARN-13b** (descente) passe car il seede **les 2 treuils à 2.0** (Δ = 0, pas de warn).

### Verdict (demande explicite de l'humain : « TC réalistes/cohérents vs AF ? »)
- **FB_Winch + FB_WinchSync + PRG_04 se comportent exactement selon l'AF.** Le garde-fou vitesse
  (`SpeedGuardEnable`) n'a rien à voir : le mettre à FALSE n'a pas bougé le résultat.
- **HARN-13a/13c/20 ne sont PAS auto-cohérents** : ils créent une déviation sync de 15 m
  (M1/M2 à 15 m sans établir `ActiveOffsetM`) **puis** assertent palier 2/5/4 — ce qui contredit
  la règle AF « SyncDeviationWarn → palier 1 » qu'ils sont censés respecter.
- **Correctif attendu côté TC** (au choix) :
  a. seeder la benne homée / `ActiveOffsetM` cohérent avec l'écart M1/M2 (le 15 m devient compensé) ; **ou**
  b. co-localiser M1/M2 comme HARN-13b ; **ou**
  c. asserter palier 1 (et renommer le TC).
- **Question ouverte pour l'humain** : sur la vraie machine, si la benne n'est **pas** homée,
  `ActiveOffsetM` est invalide → tout écart réel M1/M2 (normal, la benne pend sous la retenue)
  déclenche SyncDeviationWarn → montée plafonnée 1. **Est-ce voulu (homing benne = préalable à
  la montée couplée) ou un trou d'intégration ?** → à trancher avant de dire « winch utilisable ».

---

## 5. Étape 3 T181-01 — draft `FB_WinchRateInterlock` (délégué deepseek, NON écrit)

- Prompt : `scratchpad/PROMPT_t181-01_rateinterlock.md`
- Réponse : `scratchpad/REPONSE_rateinterlock.md`
- **4 défauts relevés à la revue**, dont :
  1. utilise `TIME()` (horloge absolue) + `TIME_TO_LREAL` pour la fenêtre glissante → wrap ~49 j non géré, déviation du style maison (tout le reste = `TON`). *Non bloquant gate, mais mauvais choix de conception à ne pas committer tel quel.*
  2. garde Reset défeatée : `CransDansFenetre := 0` **puis** `IF CransDansFenetre <= seuil` → toujours vrai → n'importe quel front Reset efface le latch même si la cadence pompe encore.
  3. `ARRAY[0..31]` + `MOD 32` + `TO 31` en magic numbers dispersés, pas de `VAR CONSTANT`.
  4. branche `NOT Enable` ne re-fixe pas `StepPrev` → 1 cran fantôme au ré-Enable ; `Governing` sans 3ᵉ terme « passive » ; cartouche pas au gabarit ; `StepNumber` marqué `[LOC]` au lieu de `[IN]`.
- **Réécriture proposée (non faite)** : compteur + `TON` de fenêtre (déterministe, pas de wrap,
  conforme style FB_WinchDirectionInterlock), front Reset conditionné à la cadence **réelle**
  calculée avant purge.
- **Seuils PROVISOIRES** (DESIGN §6 Q4, défaut « oui, provisoires assumées ») : `> 4 crans / 2 s`.
  Pas de signature explicite de l'humain cette session sur ces valeurs.
- Interface cible (DESIGN §4) : 2 instances, 2 jeux de constantes DISJOINTS (FB_Winch = safety+marge,
  PRG_06 = safety nu), instance interne FB_Winch **non bypassable**.

---

## 6. Fichiers modifiés PAS par moi (working tree)

Apparus via `git stash pop` — travail d'un agent CI/doc concurrent. **Ne pas les committer, ne pas
les toucher.**

| Fichier | Diff |
|---|---|
| `.markdownlint.json` | ajout de tags HTML autorisés (`b`, `table`, `caption`, `thead`, `tbody`, `tr`, `th`, `td`…) |
| `TOOLS/AGENT_WORKFLOW/scripts/hook_post_edit.py` | rend le hook `PostToolUse` **toujours informatif, jamais bloquant** (`return 0` au lieu de `return 2`) — décision datée « 2026-11 » alignée sur le process d'import Bundle complet de l'humain. |
| `TOOLS/TEST_AUTO_CI/RESULTS/H_TREUILS_BENNE/reports/*` (HTML/JSON) | régénérés par mes runs CI |

---

## 7. État CI (référence)

```
FB_Winch                 : 1 PASS / 0 FAIL
FB_WinchOutputInterlock  : 7 PASS / 3 FAIL  (013, 021, 022 = artefacts timing STruCpp pré-existants ; 023a/b/c VERTS)
WINCH_INTEG              : nombreux HARN rouges — TOUS identiques avec/sans mes modifs (vérifié `git stash`)
                          reds pertinents chaîne montée : HARN-13a/13c/20 (cause §4), HARN-23, HARN-32
                          autres reds explicitement « CIBLE T181-xx / ROUGE baseline » dans leur libellé
```

Commandes :
```
python TOOLS/TEST_AUTO_CI/run_tests.py --fb FB_Winch
python TOOLS/TEST_AUTO_CI/run_tests.py --fb FB_WinchOutputInterlock
python TOOLS/TEST_AUTO_CI/run_tests.py --fb WINCH_INTEG
```

---

## 8. À faire par l'agent suivant (ordre suggéré)

### Mise à jour checkpoint 2026-08-30

- `T181-20 / FB_Winch_Symmetry` vérifié : **3/3 PASS** (`TC-P10-T181-18a/b/c`) avec
  compilation STruCpp et câblage PRG_07/IHM confirmés. Le diagnostic reste passif.
- Revue Ollama locale demandée pour prioriser les lots indépendants ; aucune autorité
  de mouvement supplémentaire ne doit être introduite avant validation humaine.
- `G200` après bundle frais : **FAIL uniquement sur l'orphelin préexistant
  `FB_WinchSpeedLearning` (L13)** ; les avertissements de liaison restants sont hors
  périmètre T181-20/T184 et doivent rester tracés, pas masqués.

1. **Trancher avec l'humain** la question ouverte §4 : homing benne = préalable à la montée couplée,
   ou trou d'intégration `ActiveOffsetM` ? Ça conditionne « winch utilisable ».
2. Selon la réponse : corriger HARN-13a/13c/20 (§4, options a/b/c) **ou** corriger le câblage
   `ActiveOffsetM` / la condition `WarnActive` dans PRG_04/FB_SyncDeviation.
3. Investiguer HARN-23 (`got 1` après homme-mort, seeds co-localisés — pas la cause §4) et
   HARN-32 (`got 0` précondition, descente plongée). Non instruits en profondeur.
4. Décider du sort de `FB_Winch.st §7-1` : finir T181-01 §7 (étapes 2-5 + TC ensemble, jamais
   l'interface seule) ou revert.
5. Si T181-01 §7 repris : réécrire `FB_WinchRateInterlock` proprement (§5), pas le draft deepseek tel quel.
6. Faire valider le correctif `SpeedGuardEnable := FALSE` (PRG_04) par l'humain, puis commit séparé
   (conformité AF, indépendant de T181-01).
7. Ne jamais committer les 2 fichiers §6.

### Mise à jour T185 — 2026-08-30 (refactor et revue contradictoire)

- `FB_ReferenceCycle` est devenu `FB_MachineHomingCycle` ; l'interface utilise l'enum
  `E_MachineHomingStep` et les DUT `ST_fbMachineHomingCycle_*`.
- `PRG_02_Acquisition` publie les statuts M1/M2, applique la condition d'arrêt mécanique
  pour les homings unitaires/at-zero et relaie les demandes de homing et le commit atomique.
- T132 est absorbée : l'IHM propose « benne fermée » par défaut ; aucune position ouverte/fermée
  n'est forcée sans confirmation visuelle explicite de l'opérateur.
- Preuves ciblées : contrôle de schéma du contrat T185 PASS (AC6 globale encore ouverte), G100/G110 PASS sur le périmètre, bundle 216/216,
  rapport `FB_MachineHomingCycle.html` 18/18 PASS avec chronogramme, G200 T185 101 liaisons OK.
- Revue Ollama : T185 est structurellement clôturable et doit rester gelée. Le G200 global reste
  rouge uniquement sur `FB_WinchSpeedLearning` orphelin (T181-15) ; ne pas l'instancier dans PRG_04.
- La livraison projet reste suspendue aux gates externes G200/G340/G430 ; aucune correction de ces
  sujets ne doit être absorbée dans T185.
