# 🧹 PLAN T194 — Optimisations interfaces treuils/benne : paramètres morts & homogénéité FB

> **Type** : Plan de lot (design) · **Criticité** : C2 · **Stratégie** : patch (bit-identique)
> **Contrat** : `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T194.yaml`
> **Domaine** : `H_TREUILS_BENNE` (+ rattachement `I_TRANSLATION`, `J_SUPERVISION`)
> **Source constats** : `DOC/WFLOW/AUDITS/INTERFACES_AUDIT_A_20260831.md` (O1/O3/O4/S2),
>   `…/INTERFACES_AUDIT_B_20260831.md` (O1/O3/O5)
> **Référentiels** : `DOC/STDS/CODE_QUALITY_STANDARDS.md §2quinquies, §4, §9` · `NAMING_CONVENTION.md NC-090/NC-110`
>   · `DOC/STDS/NAMING_CONVENTION.md` · `AF_Partie-03_Contrats_Composants_v2.3.md §3`

---

## ⚠️ Résultat REBASELINE main courant (lu avant plan — 0 modification faite)

> **Découverte structurante** : l'arbre `main` **porte déjà l'essentiel de O1/O3/O4/O5**.
> Le travail réel restant est donc **plus réduit** que la description catalogue. Chaque sous-lot
> commence par une **vérification grep** avant toute écriture, et **⛔ ARRET VALIDATION** si l'écart
> constaté vs description est confirmé (éviter une réimplémentation superflue).

| Constat | État main courant (vérifié) | Réf | Verdict plan |
|---|---|---|---|
| **O1** `SpeedStepTable` morte sur `FB_WinchCmdArbitrationM1/M2` | **Déjà retirée** des 2 FB : `grep SpeedStepTable` → 0 dans les 2 fichiers ; seule la table vit via `FB_Winch Config.SpeedStepTable` | `FB_WinchCmdArbitrationM1.st` / `M2.st` (VAR_INPUT : aucun champ table) · `FB_Winch.st:133,214,288` | ⚠️ déjà appliqué → **Phase 0 = confirmer & verrouiller**, pas d'edition |
| **O2** `Mode : E_Mode` morte sur `FB_Translation` | **ENCORE PRÉSENTE** : `FB_Translation.st:22` + câblage `PRG_05_Translation.st:256,351` | `FB_Translation.st:22` · `PRG_05_Translation.st:256,351` | ✅ **réel travail restant** |
| **O3** `FB_WinchOutputInterlock` défaut plat → `ST_Fault` | **Déjà homogénéisé** : expose `Fault : ST_Fault` via `instFault:FB_FaultCore`, §6bis2 (bit0 = timeout frein) | `FB_WinchOutputInterlock.st:53,124,490-501,124` | ⚠️ déjà appliqué → Phase 0 confirme |
| **O4** config `FB_Translation` ~13 scalaires → struct `Cfg` | **Déjà regroupée** : `Cfg : ST_fbTranslation_Cfg` (source GVL_PERSISTENT via `PRG_05`) | `FB_Translation.st:48` · `I_TRANSLATION/_TYPES/ST_fbTranslation_Cfg.st` | ⚠️ déjà appliqué → Phase 0 confirme |
| **O5** `ST_fbModes_Autorisations` → `ST_Modes_Autorisations` | **Déjà renommé** dans tout `CODE/` : `grep fbModes_Autorisations` → 0 | `J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/ST_Modes_Autorisations.st` | ⚠️ déjà appliqué → Phase 0 confirme |

➡️ **Conséquence** : le lot réel = **O2 (retrait `Mode`)** en premier plan, **+ verrouillage/confirmation
documentée des constats déjà appliqués** (O1/O3/O4/O5) sans réécriture. Toute trace résiduelle détectée
en Phase 0 bascule l'action concernée active. C'est conforme au devoir d'alerte du contrat.

---

## 🎯 Objectifs testables (repris du contrat, TASK_CONTRACT_T194.yaml)

1. **G001** — `FB_Translation` ne déclare plus `Mode` ; `PRG_05` ne câble plus `Mode` sur `instTranslationM3` (**AC1/AC2**).
2. **G002** — Contrat de défaut homogène `Fault:ST_Fault` sur les 2 barrières finales (formé confirmé, **AC3**).
3. **G003** — Config plate `FB_Translation` regroupée en `Cfg : ST_fbTranslation_Cfg` (formé confirmé, **AC4**).
4. **G004** — Bus multi-consommateurs nommé `ST_Modes_Autorisations` (formé confirmé, **AC5**).
5. **G005** — Aucune régression liaison (G200 PASS), 21 gates PASS, bundle frais (**AC6-AC8**).
6. **G006** — Critères structurels CODE/MAIN respectés (nom fichier=POU, ST pur) (**AC9-AC10**).

---

## 🪜 Découpage en phases (dépendances `bloque_par`)

> Chaque phase = gate de fin obligatoire. Les phases 1/2 sont séquentielles ; les phases 3/4 sont
> **parallélisables** entre elles **après** Phase 1 (aucune dépendance croisée, fichiers disjoints).

| # | Phase | Contenu | `bloque_par` | Gate de fin |
|---|---|---|---|---|
| **P0** | **Rebaseline & verrouillage** | Relire les 5 constats O1-O5 (état main courant), produire la preuve grep de l'état réel, trancher "déjà fait vs à faire", verrouiller la périmètre actif réel | — | Note de rebaseline validée (visa orchestrateur) |
| **P1** | **Retrait `Mode` sur `FB_Translation`** (le seul constat ouvert) | Supprimer `VAR_INPUT Mode` (`FB_Translation.st:22`), retirer le câblage `Mode :=` sur `instTranslationM3` (`PRG_05_Translation.st:256,351`). Aucun changement de logique | P0 | G200 pass + diff revu |
| **P2** | **Câblage & liaison inter-PRG** | Bundle regénéré, `G200_check_linkage.py --report`, vérif absence `Mode` référencé (grep) | P1 | G200 PASS |
| **P3** | **Tests de non-régression translation** | Harness `FB_Translation` : mêmes sorties avant/après retrait `Mode` (rampe, cibles, frein) | P1 | tests harness verts |
| **P4** | **Homogénéité & renommages confirmés** (O1/O3/O4/O5 déjà en place) | Preuves documentaires grep + mise à jour éventuelle des notes de spec AF si écart ; **aucune réécriture** | P0 | grep 0 + AF cohérent |
| **P5** | **Gates palier & restitution** | `run_all_gates.py --palier C` (puis complet), bandeau restitution, commit 2-temps | P2, P3, P4 | 21 gates PASS |

---

## 🧪 Plan de TEST

### Cas à couvrir (focus O2, bit-identique)
| TC | Cible | Entrée/condition | Sortie attendue (inchangée) |
|---|---|---|---|
| TC-T194-01 | `FB_Translation` | Mode=SEMI_AUTO, StartStop=TRUE, Direction=+1, SpeedTgt=50 % | `RequestedDriveControlWord=1`, `RequestedDriveFreqHz` = rampe nominale (aucun effet Mode) |
| TC-T194-02 | `FB_Translation` | SafeStop=TRUE | décélération RAPIDE (Cfg), aucun changement |
| TC-T194-03 | `FB_Translation` | Inversion de sens (Direction -1→+1) | rampe forcée à 0 + `DirectionChangeDelay` (Cfg) |
| TC-T194-04 | `FB_Translation` | Défaut variateur (DriveStatusWord.4) | `Fault.Error` latched, sorties coupées, Reset front |
| TC-T194-05 | `FB_Translation` | Fin de course / arrivée cible | `TargetReached`, arrêt exact |

> ✅ **Verdict** : le retrait de `Mode` ne doit produire **aucune différence** sur ces sorties —
> c'est la preuve qu'il s'agissait bien d'un paramètre mort (bit-identique).

### TCs/outils existants mobilisés
- Harness par FB : `TOOLS/TEST_AUTO_CI/` (pattern déjà utilisé pour `FB_Translation`, cf. T188/T181 série).
- Liaison : `python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py --report` (BLOQUANT).
- Bundle : `python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .`
- Gates : `python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --palier C` puis complet.

---

## 🔩 Plan CI / gates

| Étape | Commande | Palier | Attend |
|---|---|---|---|
| Après P1 | bundle + G200 | B | bundle OK, G200 0 erreur |
| Après P2 | `run_all_gates.py --palier B` | B | gates B verts |
| Après P3 | `run_all_gates.py --palier C` + harness | C | harness verts + gates C verts |
| Fin de lot | `run_all_gates.py` (complet) + G200 `--report` | C→complet | 100 % PASS |

> Paliers = `GUIDE_GATES_ET_TESTS.md §2` (A=structure, B=liaison, C=comportement/CI, D=release).

---

## 🤝 Assignation AGENT (prévision)

| Rôle | Acteur suggéré | Périmètre |
|---|---|---|
| **Implémenteur** | DSH (DeepSeek) — agent de lot | P1/P2 (retrait `Mode`, câblage, bundle) |
| **Revue indépendante** | Claude Code (Orchestrateur) ou sous-agent sur `omni/cx/gpt-5.6-terra` | lecture `git diff` réel, vérif AC1/AC2, non-régression |
| **Rédacteur tests harness** | Sous-agent délégué (avec `subagent_preamble.md`) | TC-T194-01..05, P3 |
| **Validateur humain** | Utilisateur | visa P0 rebaseline + visa fin de lot (ARRET VALIDATION) |

> ⚠️ Règle délégation (AGENTS.md) : coller `TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md` en tête de
> chaque sous-tâche déléguée. Validation finale = orchestrateur, jamais l'agent qui a produit le diff.

---

## 📄 Modifications DOC à prévoir

| Doc | Type | Nature |
|---|---|---|
| `DOC/AF/AF_Partie-11_Fonction_Translation_v2.3.md` | spec AF | retirer `Mode` de l'interface `FB_Translation` (le conserver dans le flux d'arbitrage amont) |
| `DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md` | spec AF | confirmer l'interface `FB_WinchCmdArbitrationM1/M2` **sans** `SpeedStepTable` (aligner si une trace subsiste) |
| `DOC/AF/AF_Partie-05_Modes_Maintenance_v2.1.md` | spec AF | confirmer bus `ST_Modes_Autorisations` (renommé) |
| `DOC/STDS/NAMING_CONVENTION.md` | **HORS SCOPE** (forbidden) | ne pas modifier — cité en référence seulement |
| `DOC/WFLOW/TASKS.yaml` | registre | après exécution : passer T194 ⏳/✅, remplir `contrat:` → `TASK_CONTRACT_T194.yaml`, horodatage |
| `DOC/WFLOW/AUDITS/DESIGN/` | design | ce plan + note de rebaseline P0 |

---

## 🖐️ Arrêts de validation humaine (C0/C4 — mentions ARRET VALIDATION)

- ⛔ **ARRET VALIDATION — Phase 0 (C2, obligatoire)** : la rebaseline conclut que O1/O3/O4/O5 sont
  **déjà appliqués** dans main. Toute décision de **réimplémenter** un de ces constats (ou au contraire
  de **documenter seulement**) exige un **visa humain explicite** avant d'écrire la moindre ligne CODE/.
- ⛔ **ARRET VALIDATION — fin de lot** : visa humain sur le `git diff` réel + bandeau restitution avant
  tout commit (aucun commit sans validation humaine, AGENTS.md).
- ⛔ **ARRET VALIDATION — si régression** : tout écart de sortie FB observé aux TCs (bit-identique
  cassé) => stop immédiat, remontée à l'orchestrateur, pas de palliatif.

---

*Fin du plan T194. Prêt pour l'exécution après visa Phase 0.*
