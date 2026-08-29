# CONSIGNE D'EXÉCUTION — T175 : écarts code treuils/benne (temps mort directionnel, anti-traversée, MAINT)

**Pour : Codex Terra.** À coller tel quel. Aucun commit — l'orchestrateur relit le `git diff`.
**T175 est BLOQUANTE pour T181-01/02/03** (elle touche le même code) — elle passe EN PREMIER.

---

## 1 · Rôle & règles

- Expert Senior Automatisme CODESYS 3.5 + sécurité machine. FR, concis.
- Lis **d'abord** : `TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md`.
- **Machine de sécurité réelle** : temps mort directionnel = protection contacteurs/moteur. Anti-traversée benne = anti-télescopage câble.
- Blocage / incohérence → **remonter immédiatement** à l'orchestrateur.

## 2 · Contrat (ta seule référence de succès)

`DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T175.yaml` — **AC2, AC3, AC4, AC5** (AC1 = mono-canal DriftGuard, doc only, déjà traité).

## 3 · Documents de référence

| # | Doc | Pour |
|---|---|---|
| 1 | `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T175.yaml` | AC2/AC3/AC4/AC5 |
| 2 | `DOC/WFLOW/P3_TEST_AUDIT_PROPOSITIONS_v1.0.md` | source des écarts (vérifiés ligne à ligne) |
| 3 | `CODE/H_TREUILS_BENNE/FB_WinchOutputInterlock.st` (l.32-33 `DeadTimeSameDir/OppositeDir`, §4bis l.165-205) | **temps mort directionnel** (AC2) |
| 4 | `CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st` (l.29-30 `M1_Busy`/`M2_Busy` déclarés jamais lus) | **anti-traversée benne** (AC3, TC-P10-025) |
| 5 | `CODE/M_MAIN/PRG_04_Treuils_Benne.st` (câblage `M1_Busy`/`M2_Busy` vers `FB_Bucket`) | flux anti-traversée |
| 6 | `CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st` (confirm/ouvre sous mode) + `CADRAGE_T181-11_MATRICE_MAINT.md` §6 | **MAINT_N1/N2** (AC4, TC-P10-030) |
| 7 | `TOOLS/TEST_AUTO_CI/RESULTS/H_TREUILS_BENNE/tests/test_fb_winchoutputinterlock.st` / `test_fb_bucket.st` | les TC à rendre exécutables |
| 8 | `DOC/WFLOW/AUDITS/DESIGN/AF10_INTERFACE_TREUIL_CIBLE_T181.md` §3bis/§3ter | **coordination T181** : ne pas dupliquer le temps mort, ne pas coder la règle §3bis (c'est T181-01) |

## 4 · Objectif mesurable

1. **AC2 — Temps mort directionnel** : `DeadTimeSameDir` / `DeadTimeOppositeDir` (ou équivalent nommé) **distinct** de `RestartDelay` (aujourd'hui `T#1500ms` uniforme). Les TC-P10-021/022 décrivent **1 s par direction** — trancher la valeur (1 s par défaut, modifiable) et la documenter. **Une seule implémentation** — T181-01 la consommera, ne pas laisser 2 minuteurs.
2. **AC3 — Anti-traversée benne** : `FB_Bucket` lit réellement `M1_Busy`/`M2_Busy` (l.29-30, déclarées jamais lues) → une demande benne est **refusée si un treuil agit** (TC-P10-025). Câbler `M1_Busy := (instWinchM1.RelayFwd_Up OR instWinchM1.RelayRev_Down)` (et M2) depuis `PRG_04` — G200 doit voir ces champs produits ET consommés.
3. **AC4 — MAINT_N1/N2 confirm/ouvre benne** : `FB_Bucket` confirme/ouvre sous **MAINT_N1 ET MAINT_N2** (décision cadrage T181-11 §6 : manœuvre de service sans bypass) → TC-P10-030 exécutable. Si l'implémentation ne peut pas, corriger la fiche et tracer la décision.
4. **AC5 — Non-régression** : `python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --palier C` PASS après les 3 patchs.

## 5 · Coordination (ne pas déborder)

- **NE PAS** coder la règle §3bis « sens jamais avant vitesse » (fenêtre `DropConfirmDelay`/`T_max`) → c'est **T181-01**.
- **NE PAS** créer `FB_WinchRateInterlock` ni toucher au `StepDelay` TON → **T181-01**.
- **NE PAS** toucher `FB_Safety_Winch` au-delà de ce que AC3/AC4 exigent (le `ContactorStuck` = T181-02_03).
- Scope strict : `CODE/H_TREUILS_BENNE/**` **et, uniquement pour AC3,**
  `CODE/M_MAIN/PRG_04_Treuils_Benne.st` (producteur des signaux `M1_Busy`/`M2_Busy`).
  Aucun autre fichier `CODE/M_MAIN/**` n'est autorisé.

## 6 · Restitution

- `git diff` complet.
- `python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py --report`
- `python TOOLS/TEST_AUTO_CI/scripts/run_tests.py --fb FB_WinchOutputInterlock --fb FB_Bucket`
- `python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --palier C`
- Note : valeur retenue pour le temps mort directionnel + décision MAINT_N1/N2.
- **Aucun commit.**
