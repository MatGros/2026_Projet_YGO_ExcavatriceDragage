# 🔬 REX — [Titre de l'incident / Sujet]

> 📌 **Convention de nommage obligatoire** : `REX_<SujetCourt>_AAAAMMJJ.md` (ex. `REX_PRG06_Import_Error_20260804.md`).

**Date** : AAAA-MM-JJ  
**Auteur / Réf** : [Nom / Agent ID / Réf tâche Txx]  
**Statut** : 🔴 Ouvert / 🟠 En cours d'analyse / ✅ Résolu & Guarded  
**Criticité** : C0 (Doc) / C1 (Diag) / C2 (Métier) / C3 (Safety standard) / C4 (Safety critique)  

---

## 📋 1. Problème & Symptômes observés

- **Ce qui s'est produit** : Description factuelle de l'erreur (messages d'erreur CODESYS, compilation, liaison, crash ou comportement physique inattendu).
- **Contexte** : Machine réelle, simulation, import PLCopenXML, banc d'essai.
- **Log / Trace brute** :
  ```text
  [Coller ici l'erreur exacte, trace de compilation ou log d'exécution]
  ```

---

## 🎯 2. Causes racines (Root Causes)

| # | Cause racine identifiée | Pourquoi elle s'est produite | Détectable comment |
|---|-------------------------|------------------------------|-------------------|
| 1 | ...                     | ...                          | ...               |
| 2 | ...                     | ...                          | ...               |

### ❌ Fausses pistes écartées
- *Fausses hypothèses éliminées lors du dépannage pour éviter de refaire la même erreur d'analyse.*

---

## 🛠️ 3. Résolution & Correctif appliqué

- **Fichiers modifiés** :
  - [`CODE/.../FB_xxx.st`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/)
  - [`DOC/AF/...`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/DOC/AF/)
- **Explication du fix** :
  ```diff
  - ancien code défaillant
  + nouveau code corrigé
  ```

---

## 🛡️ 4. Règle `fix:` + `guard:` (Garde-fou automatique)

> 📌 **Principe non négociable** : Tout bug détecté donne **deux** livrables — la correction **et** un contrôle automatique dans `TOOLS/AGENT_WORKFLOW/scripts/`.

- **Script garde-fou créé / étendu** : `TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py` (ou nouveau script `Gxxx`)
- **Règle de contrôle ajoutée** : ...
- **Vérification** : `python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py` $\to$ **PASS**.

---

## 📚 5. Leçons apprises & Bonnes pratiques

1. ...
2. ...
