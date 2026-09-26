# 📋 BRIEF T383 — MICRO-STEP de séquençage benne à la trémie (AX15D)
## v1 — PRÊT À TRANSMETTRE AUX AGENTS DE L'EXPLOITANT

> 📅 2026-09-22 · 🏷️ Orchestrateur rédacteur : **DSH01** · ⚡ Criticité **C4** (plan humain obligatoire + **double revue parallèle**)
> 🎯 **Tâche** : **T383** (`DOC/WFLOW/TASKS.yaml`), parent **T331** · 📄 GEL de référence : `DOC/WFLOW/AUDITS/GEL_GRAFCET_SEMIAUTO_20260903.md`
> ⛔ **Aucun code ne doit être écrit avant la validation humaine de la PHASE 0.**

---

## 0. PRÉAMBULE OBLIGATOIRE (source : `TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md` — à lire en entier)

Automate **CODESYS 3.5**, machine de dragage en carrière noyée. Code ST dans `CODE/`, appliqué **manuellement** par l'exploitant dans CODESYS. **Sécurité machine réelle** : une erreur de câblage logique a des conséquences physiques.

**Persona** : Expert Senior Automatisme Industriel / Sécurité Machine (ISO 13849) / CI-CD. **Challengeur anti-Yes-Man** : ce brief n'est pas parole d'évangile — s'il est faux, le dire AVANT d'agir. Distinguer **faits / hypothèses / incertitudes**. Répondre en **français**, direct et synthétique.

**Interdits absolus**
- ⛔ **Aucun commit, aucun push** sans accord humain explicite et distinct.
- ⛔ **Toute modification de fichier exige une validation préalable** (voir les ARRÊTS du phasage §4).
- ⛔ Ne jamais modifier `PRJ_CODESYS/…/Device.export` · aucun scratch à la racine · aucune suppression/déplacement d'artefact.
- ⛔ **Élargir le scope = signaler, jamais décider.**

**Cas d'arrêt** (demander au lieu de coder) : spec incomplète ou ambiguë · nommage indécidable · interface FB incomplète · `Reset` hors front · **redémarrage automatique après défaut** · `SafeStop`/`StartStop` sur un FB qui n'est pas un FB de mouvement.

**Devoir d'alerte** : toute incohérence, bug préexistant, risque hors scope ou doute de sécurité remonte **immédiatement**, jamais à la fin, jamais silencieusement.

**Vérification mécanique — minimum à CHAQUE livraison de code**
```powershell
python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .
python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_diff_bundle.py . <fichiers .st touches>
python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py --report          # BLOQUANT
python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --palier C
```
⛔ Un bundle bien formé ou des tests verts **ne prouvent jamais** qu'une fonction est reliée : seul `G200_check_linkage.py` le prouve, et son bloc `Auto-vérification liaison` doit être **collé dans la restitution**.

**Traçabilité d'impact AVANT de coder** (`DOC/STDS/CODE_QUALITY_STANDARDS.md §3ter`) : qui **produit** la donnée → qui la **route** → qui la **consomme**. Vérifier que la modification atteint le **consommateur final**.

**Heartbeat** : `python TOOLS/AGENT_WORKFLOW/scripts/agent_heartbeat.py record <SESSION> <ETAPE> <etat> --agent <CC01|AGY01|CDX01|DSH01|OPC01> --msg "<résumé>"`

---

## 1. OBJECTIF (en une phrase)

À la **trémie**, l'opérateur doit pouvoir **ouvrir ET refermer la benne sur place** — sans que le GRAFCET quitte la phase de vidage — et disposer, si nécessaire, d'une **échappatoire explicite et déclarée** vers la remontée ; **aucune transition non déclarée au GEL ne doit subsister**.

## 2. LE PROBLÈME, PROUVÉ (vérifier, ne pas croire)

### 2.1 Le GEL déclare 2 sorties pour AX15B — et **pas** de saut vers AX10
`GEL_GRAFCET_SEMIAUTO_20260903.md`, lignes **108-112** :

| Rep. | Contenu **GELÉ** |
|---|---|
| `AX15B_DUMP_OPEN` (16) | *« vidage : ouverture benne au-dessus de la trémie, treuils 0 · M1+M2 **0** · `ReqOpen := CycleMotionPermit` »* |
| `AT15B-c` *(option)* | `RepositionRequest` → **AX15C** |
| `AT15B` | `JoystickDeflected AND Benne_Done AND Benne_IsOpen` → `ReqOpen := FALSE` → **AX18** |
| `AT15C` *(retour)* | `NOT RepositionRequest` → **AX15B** |

### 2.2 Le code fait un SAUT ARRIÈRE non déclaré
```text
FB_CycleSemiAuto.st:1567   IF DeadmanArmed AND JoystickPull THEN
FB_CycleSemiAuto.st:1568       BucketCmd.ReqOpen := FALSE;
FB_CycleSemiAuto.st:1569       State := E_AutoCycleStep.AX10_CLOSE_BUCKET;   ⛔ 6 etapes EN ARRIERE
```
Origine : commit **`31c9db0d`** (T331, 2026-09-20, **`[NON TESTE MACHINE]`**), **sans amendement du GEL**.

### 2.3 Mesure d'ensemble (à rejouer)
- **39** affectations `State := AX…` dispersées dans les corps d'étapes vs **22** transitions déclarées au GEL.
- **2** seuls sauts arrière : `AX18 → AX2_TRANSLATE_P1` = **rebouclage nominal déclaré** (GEL L114) ✅ ; `AX15B → AX10` = **le seul non déclaré** ⛔.
- ⚠️ **Il n'existe AUCUNE table de transitions** dans le code : rien n'interdit structurellement un saut.
- ⚠️ **Piège de comparaison** : le GEL écrit les cibles en **forme courte** (`→ **AX14**`), le code en **nom complet** (`AX14_TRANSLATE_DUMP`) ⇒ une comparaison sur le **libellé** produit des **faux positifs en masse**. **Comparer sur le NUMÉRO d'étape.**

### 2.4 Exigence de l'exploitant (verbatim)
> « un grafcet a des transitions définies, il ne peut pas faire de saut »
> « si c'est plus simple et sûr d'intégrer une micro step de séquençage j'avais dit pas de problème … en plus on peut ajouter un message utilisateur pour expliquer »

---

## 3. LA SOLUTION RETENUE : UNE MICRO-STEP DÉCLARÉE (pas une distorsion d'AX15B)

**Nouveau step** : `AX15D_DUMP_BUCKET_JOG` *(nom d'usage ; le nom final doit respecter `NAMING_CONVENTION.md` et la logique de numérotation du GEL — voir §5 arbitrage 4)*.

| Aspect | Spécification |
|---|---|
| **Entrée** | depuis `AX15B_DUMP_OPEN`, sur un **geste opérateur EXPLICITE et distinct** (à trancher : bouton IHM dédié **ou** geste maintenu avec confirmation — §5 arbitrage 1) |
| **Contenu** | **treuils M1+M2 à 0**, **translation 0** (aucun mouvement de treuil) · `ReqOpen := <geste ouvert>` · `ReqClose := <geste fermé>` · **neutre = les deux à FALSE** — la benne se module **sur place**, au-dessus de la trémie |
| **Sortie 1** | retour **`AX15B`** (reprendre le vidage) |
| **Sortie 2** | **`AX18_DONE_SYNC`** (contenu vidé confirmé — même logique que `AT15B` du GEL) |
| **Sortie 3** *(phase 3, sur arbitrage safety)* | **échappatoire explicite** vers la chaîne de remontée (`AX10_CLOSE_BUCKET`) déclenchée par un **geste distinct**, **déclarée au GEL** |
| **Messages opérateur** | un message **par état** (`OperatorAction` + bandeau), **≤ 70 caractères** (contrainte G408), non trompeur : il dit ce que la machine fait **et** ce qu'elle va faire (rester dans le vidage / quitter) |

**Conservation impérative** : `AX15B` reste conforme au GEL (ouverture seule) · `AX15C` inchangé · **aucune** modification de la logique de sécurité, des permis, des interlocks ni des temporisations moteur/frein.

---

## 4. PHASAGE (5 phases — 5 contrats, 1 seul import final)

```text
PHASE 0 — AMENDEMENT DU GEL (doc seul, AUCUN code, risque nul)
   Livrable : GEL amende = nouveau step + TOUTES ses transitions + les messages, via le
              mecanisme d'arbitrage du GEL (section Q).
   ⛔ ARRET HUMAIN : validation de l'amendement AVANT toute ligne de code.

PHASE 1 — MICRO-STEP MINIMUM (code)
   Livrable : enum + step + entree + sorties 1 et 2 + messages. PAS d'echappatoire.
   Preuves : CI ciblee ROUGE avant / VERT apres, bundle + diff bundle + G200 --report, palier C.

PHASE 2 — RETRAIT DE LA DEVIATION
   Livrable : suppression de FB_CycleSemiAuto.st:1568-1569 (AX15B -> AX10).
   Preuve : git diff + garde-fou GEL<->code PASS (sinon le saut reste).

PHASE 3 — ECHAPPATOIRE EXPLICITE (sur arbitrage safety)
   Livrable : transition declaree vers la chaine de remontee, geste distinct, message dedie
              + decision TRACEE sur la qualification de la surveillance de synchronisme.
   ⛔ ARRET HUMAIN : decision safety avant code.

PHASE 4 — GARDE-FOU GEL <-> CODE + RE-MESURE
   Livrable : gate qui extrait les transitions CODEES et les DECLAREES, compare sur le NUMERO
              d'etape, FAIL NOMME sur toute non declaree (+ signale les declarees non implementees),
              --selftest par mutation. Puis re-mesure de TOUTES les entrees CI touchees.
```
**Chaque phase** : contrat écrit + validé par `check_task_contract.py` **avant** sa première ligne, **challenge** du plan puis **revue indépendante** du diff (`BLOCK/MAJOR/MINOR/PASS`). **Une seule campagne d'essais** à la fin (un import).

---

## 5. ARBITRAGES À RENDRE PAR L'EXPLOITANT (une salve, avant la phase 1)

| # | Question | Impact si non tranché |
|---|---|---|
| 1 | **Geste d'entrée** en AX15D : **bouton IHM dédié** (le plus explicite) ou **geste maintenu avec confirmation** ? | on ne peut pas coder l'entrée ni la tester |
| 2 | **Geste de sortie 1** (retour au vidage) : relâchement, ou geste dédié ? | idem |
| 3 | **Sortie 3 (échappatoire)** : la conserver ? Par quel geste distinct ? | décide si la phase 3 existe |
| 4 | **Nom + valeur d'énumération** du nouveau step (`AX15D_*` ? valeur 23 ?) — lien **T324** qui régularise les steps spéciaux hors GEL | nommage non décidable = cas d'arrêt |
| 5 | **Exclusion de la surveillance de synchronisme** pendant la fermeture à la trémie : acceptée (comme `AX10` aujourd'hui) | décision **safety** — jamais improvisée par un agent |

---

## 6. CRITÈRES TESTABLES
Voir **T383** dans `DOC/WFLOW/TASKS.yaml` (**AC1 → AC8**), un par un, avec la preuve exigée. Un AC sans preuve observable **n'est pas un AC** : le signaler, ne pas deviner.

## 7. CE QUE L'ORCHESTRATEUR VÉRIFIERA SUR LE RAPPORT RENVOYÉ

1. **Lecture du `git diff` réel** (jamais la restitution de l'agent) : fichiers touchés, additivité, **aucune suppression inexpliquée**.
2. **Rejeu des preuves** : ROUGE avant / VERT après (assertions fonctionnelles), `G200 --report` recollé, palier C, garde-fou PASS + `--selftest` par mutation.
3. **AC un par un**, avec refus si une preuve manque.
4. **Périmètre** : `git diff --numstat` **VIDE** sur `B_AU_SECURITE/**`, `FB_Safety_Winch.st`, `FB_WinchOutputInterlock.st`, `FB_Winch.st`, `GVL_IHM.st`, `_TYPES/**` (AC8).
5. **GEL** : le code livré ne contient **aucune** transition absente du GEL amendé.
6. **Visa** dans le contrat de tâche (`validation:`) ou **REJET motivé** — jamais d'acceptation de complaisance.

> ⛔ **Ce brief n'est pas un GO.** Il cadre le travail ; le GO est la validation humaine de la **phase 0**.
