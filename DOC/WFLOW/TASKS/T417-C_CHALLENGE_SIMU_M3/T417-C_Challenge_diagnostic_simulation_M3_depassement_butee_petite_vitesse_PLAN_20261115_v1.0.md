---
plan_project:
  schema: 1
  task_id: T417-C
  updated_at: 2026-11-15
  milestones:
    - id: M0
      title: "Mise en conformité dossier, contrat C2 et plan"
      done_when: "Dossier DOC/WFLOW/TASKS/T417-C_CHALLENGE_SIMU_M3/ créé, contrat TASK_CONTRACT_T417-C.yaml PASS"
      execution: DONE
      execution_by: "AGY03"
      evidence: "check_task_contract.py PASS (0 erreur) + arborescence DOC/WFLOW/TASKS/T417-C_CHALLENGE_SIMU_M3/ créée"
      execution_comment: "Migration depuis T000-AGY02_GEMINI_4_HYDRO_CHALLENGE_SIMU_M3 effectuée sans perte"
      validation: NOT_REVIEWED
      validated_by: ""
      validated_at: ""
      validation_comment: ""
      comments: []
    - id: M1
      title: "Tri historique, cartographie M3, sandbox et challenge des hypothèses"
      done_when: "4 livrables T417-C_*.md et sandbox AGY02_T417_M3_SANDBOX produits en lecture seule CODE/"
      execution: DONE
      execution_by: "AGY02"
      evidence: "T417-C_HISTORIQUE_TRIE_ECHANTILLON_20261113_v1.0.md, T417-C_CARTOGRAPHIE_M3_REGISTRE_HYPOTHESES_20261113_v1.0.md, T417-C_ORACLES_EXPERTS_PHASE2_20261113_v1.0.md, T417-C_CHALLENGE_HYPOTHESES_20261113_v1.0.md"
      execution_comment: "Phase 1/2 achevées avant reprise sous T417-C-AGY03"
      validation: NOT_REVIEWED
      validated_by: ""
      validated_at: ""
      validation_comment: ""
      comments: []
    - id: M2
      title: "Arbitrage exploitant et dossier de passation (patch + guard ou bascule C3/C4)"
      done_when: "Choix d'hypothèse validé par l'humain et dossier de passation approuvé"
      execution: IN_PROGRESS
      execution_by: "AGY03"
      evidence: "T417-C_SYNTHESE_ETUDE_M3_20261115_v1.0.md + plan_abc_matrix.py + be_dynamic_study.py"
      execution_comment: "Plans A/B/C, matrice sandbox et protocole de test prêts pour validation humaine au retour"
      validation: NOT_REVIEWED
      validated_by: ""
      validated_at: ""
      validation_comment: ""
      comments: []
---

# T417-C — Challenge & diagnostic simulation M3 (depassement butee petite vitesse)

> Plan de travail unique. `DONE` décrit l'exécution ; seule une validation explicite avec auteur et date compte comme validée.

## 1. Besoin et résultat attendu

Diagnostiquer et reproduire en simulation isolée le dépassement de butée petite vitesse M3 (`PRG_05`/`PRG_06`/`FB_Translation` vs `L_SIMULATION`), puis produire un dossier de validation (`patch + guard`) ou préparer une bascule `C3/C4` si `CODE/` doit être modifié.

## 2. Périmètre et dépendances

- **Inclus :** `DOC/WFLOW/TASKS/T417-C_CHALLENGE_SIMU_M3/**`, `DOC/WFLOW/TASKS/T417-C_CHALLENGE_SIMU_M3/CONTRACTS/TASK_CONTRACT_T417-C.yaml`, `TOOLS/TEST_AUTO_CI/RESULTS/_TROUBLESHOOTING/AGY02_T417_M3_SANDBOX/**`.
- **Exclus :** toute écriture dans `CODE/**` sans contrat C3/C4 et GO explicite, `Device.export`.
- **Dépendances / décisions attendues :** tâche parente `T417` (`SimBench M3`), arbitrage exploitant sur les 3 hypothèses réalistes (`M2`).

## 3. Jalons

Suivi structuré dans `plan_project.milestones` ci-dessus.

## 4. Journal des décisions et commentaires

Consigner les arbitrages datés et attribués dans le champ `comments` du jalon concerné.
