# TASK-0002 — Renommer FdcGrappinOpen/Close en FdcGrappinOpenEnable/CloseEnable

**Status**: REVIEW
**Assigned**: Gemini
**Créé**: 2026-07-15 par Claude

---

## 🎯 Objectif (goal vérifiable — pas une simple consigne)
Les champs `GVL_IHM.IHM_MANU.FdcGrappinOpen` et `FdcGrappinClose` sont des **interrupteurs
d'activation** de la fonction fin-de-course virtuelle grappin (pas un état), mais leur nom actuel
ressemble à un état ("le grappin est ouvert"), ce qui prête à confusion (repéré par l'utilisateur
en testant le grappin le 2026-07-15). Convention `NAMING_CONVENTION.md` : booléen entrée = verbe.
Renommer en `FdcGrappinOpenEnable`/`FdcGrappinCloseEnable` pour lever l'ambiguïté, **sans changer le
comportement** (pur renommage, aucune logique modifiée). `FdcGrappinOpenActive`/`CloseActive`
restent inchangés (déjà correctement nommés — c'est l'état calculé, pas l'activation).

**Pourquoi** : décision utilisateur du 2026-07-15 (session Claude) — confirmé que ces champs ne
sont **pas encore câblés côté IHM du collègue** (donc renommage sûr, ne casse pas le handoff figé
de `ST_IHM_MANU`, voir contrainte ci-dessous).

## 📂 Scope
**Fichiers à toucher** :
- `CODE/SUPERVISION/ST_IHM_MANU.st` (lignes ~59-60) — renommer les 2 déclarations + adapter le
  commentaire (garder l'esprit "🎚️ Activer FDC Ouvert/Fermé...", juste le nom du champ change).
- `CODE/MAIN/PRG_10_Outputs.st` (lignes ~154-155) — mettre à jour les 2 lignes de calcul qui lisent
  `GVL_IHM.IHM_MANU.FdcGrappinOpen`/`FdcGrappinClose` (partie droite de l'assignation
  `FdcGrappinOpenActive`/`CloseActive`, qui elles ne changent PAS de nom).
- `CODE/MAIN/PRG_06_WinchControl.st` (ligne ~70) — commentaire seul, mise à jour cosmétique de la
  référence textuelle `FdcGrappinOpen/CloseActive` si elle nomme le champ d'activation (vérifier le
  texte exact avant de modifier — ne pas toucher si le commentaire ne référence que les `*Active`).
- `DOC/IHM_MANU_Journal_Modifications.md` (ligne ~51, section liste des champs IHM_MANU) — mettre à
  jour `FdcGrappinOpen/Close : BOOL` → `FdcGrappinOpenEnable/CloseEnable : BOOL` dans la description.
- `DOC/VERSION_HISTORY.md` — **ajouter une nouvelle ligne** (jamais éditer une ligne existante),
  format `vX.X_FdcGrappin_Rename`, décrire le renommage et sa raison.

**Explicitement HORS scope** (ne pas toucher même si tentant) :
- `FdcGrappinOpenActive`/`FdcGrappinCloseActive` — noms déjà corrects, ne pas toucher.
- `GrappinDelta` et toute la logique de calcul du delta M1-M2 — aucun changement de comportement.
- Tout autre champ de `ST_IHM_MANU.st` — table figée, voir contrainte ci-dessous, ce renommage est
  une exception explicitement validée par l'utilisateur, pas un blanc-seing pour d'autres modifs.
- `CODE_Bundle.xml` / `PLCOPENXML_TOOLING/generated/CODE_Bundle.xml` — régénérés via le bundler
  (Étape 4bis), ne jamais éditer ces XML à la main.
- Aucune AF_PartieN ne référence ces noms de champs (vérifié par grep) — ne pas en versionner une
  sans raison.

## 🔒 Contraintes (copiées, pas juste référencées)
- **Nommage** : PascalCase strict, aucun hongrois, voir `DOC/NAMING_CONVENTION.md`. Booléen entrée
  = verbe (`Enable`) — c'est exactement la raison de ce renommage.
- **`ST_IHM_MANU.st` est une table FIGÉE** partagée avec un collègue qui construit l'IHM dessus :
  normalement interdiction d'ajouter/renommer/retirer un champ sans instruction explicite. Ici
  l'utilisateur a **explicitement confirmé** (2026-07-15) que `FdcGrappinOpen`/`FdcGrappinClose` ne
  sont **pas encore câblés côté collègue** → renommage exceptionnellement autorisé, mais **ne pas
  toucher aux autres champs** du struct sous prétexte d'être déjà dedans.
- Pur renommage : **zéro changement de logique/comportement**. Le calcul
  `FdcGrappinOpenActive := FdcGrappinOpenEnable AND (GrappinDelta >= 0.0)` doit rester strictement
  identique, seul le nom de la variable de droite change.
- Versionner `DOC/VERSION_HISTORY.md` par ajout de ligne, jamais par édition d'une ligne existante.

## ✅ Critère d'acceptation
- [ ] Compile en CODESYS sans erreur (bundle PLCopenXML généré 0 erreur)
- [ ] `ST_IHM_MANU.st` : `FdcGrappinOpen`/`FdcGrappinClose` renommés `FdcGrappinOpenEnable`/
      `FdcGrappinCloseEnable`, `FdcGrappinOpenActive`/`CloseActive` inchangés
- [ ] `PRG_10_Outputs.st` : les 2 lignes de calcul utilisent les nouveaux noms, résultat logique
      identique à avant (même comportement, juste renommé)
- [ ] Aucune autre variable de `ST_IHM_MANU.st` modifiée (diff limité aux 2 champs ciblés)
- [ ] `DOC/IHM_MANU_Journal_Modifications.md` reflète les nouveaux noms
- [ ] `DOC/VERSION_HISTORY.md` : nouvelle ligne ajoutée, aucune ligne existante modifiée
- [ ] Recherche globale (`grep -r "FdcGrappinOpen\b\|FdcGrappinClose\b"` hors `*Active`) ne renvoie
      plus aucune occurrence de l'ancien nom dans `CODE/*.st` ou `DOC/*.md` (hors historique déjà
      écrit type `VERSION_HISTORY.md` antérieur, qui ne doit pas être réécrit)

## 📝 Log
| Date | Auteur | Note |
|---|---|---|
| 2026-07-15 | Claude | Tâche créée — renommage clarté suite à confusion repérée par l'utilisateur en testant le grappin, confirmé non câblé côté IHM collègue |
| 2026-07-15 | Gemini | Renommage effectué dans ST_IHM_MANU.st, PRG_10_Outputs.st, IHM_MANU_Journal_Modifications.md et VERSION_HISTORY.md (v0.4.10_FdcGrappin_Rename). Bundle PLCopenXML régénéré sans erreur. |
