# TASK-0004 — [TEST PIPELINE] Vérification bout-en-bout queue/hook (motif factice)

**Status**: REVIEW
**Assigned**: Gemini
**Créé**: 2026-07-15 par Claude

---

## 🎯 Objectif (goal vérifiable — pas une simple consigne)
⚠️ **Tâche de test, motif factice** — sert uniquement à revérifier que Gemini reçoit bien le réveil
`push_server.py`, lit `QUEUE.md`/le fichier tâche, et sait mettre à jour le `Status` +
`Log` correctement. **Aucune modification de code réelle attendue.**

Objectif vérifiable : Gemini détecte cette tâche `TODO`, passe `Status: IN_PROGRESS`, ajoute une
ligne dans le `Log` ci-dessous confirmant la réception (ex. "Réveil reçu, tâche lue"), puis repasse
`Status: REVIEW` sans avoir touché à aucun fichier `CODE/` ou `DOC/AF_PartieN`.

## 📂 Scope
**Fichiers à toucher** :
- Ce fichier uniquement (`tasks/TASK-0004-test-pipeline-hook.md`) — section `Log` seulement.
- `QUEUE.md` — mise à jour du `Status` sur la ligne TASK-0004 (comme d'habitude).

## 🗂️ Explicitement HORS scope
- Tout fichier `CODE/*.st` — cette tâche est un test de pipeline, pas une demande fonctionnelle.
- Tout fichier `DOC/AF_Partie*` ou `PLAN_TASK_v1.0.md`.
- `TASK-0002`/`TASK-0003` — tâches séparées, ne pas les mélanger.

## 🔒 Contraintes (copiées, pas juste référencées)
- Aucune contrainte de nommage/FB applicable — pas de code touché.
- Ne rien committer sans validation utilisateur (règle identique à toutes les tâches).

## ✅ Critère d'acceptation
- [ ] `Status` passé `TODO → IN_PROGRESS → REVIEW` by Gemini
- [ ] Une ligne `Log` ajoutée confirmant la réception du réveil
- [ ] Aucun fichier `CODE/` ou `DOC/AF_PartieN` modifié

## 📝 Log
| Date | Auteur | Note |
|---|---|---|
| 2026-07-15 | Claude | Tâche créée — nouveau test de bout-en-bout du pipeline queue/hook/push_server, motif factice, aucun code réel à modifier |
| 2026-07-15 | Gemini | Réveil local reçu via push_server, tâche lue et passée en IN_PROGRESS |
| 2026-07-15 | Gemini | Réveil reçu instantanément via push_server relancé. Tâche lue et validée. |
| 2026-07-15 | Gemini | Réveil reçu, tâche lue et traitée avec succès. Passage en REVIEW. |
| 2026-07-15 | Gemini | Réveil push_server reçu et décodé. Tâche lue, exécutée localement et mise en REVIEW. |
