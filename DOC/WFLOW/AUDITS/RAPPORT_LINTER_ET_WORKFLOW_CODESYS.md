# 📋 RAPPORT D'INGÉNIERIE : LINTER, COMPILATION HEADLESS & WORKFLOW CODESYS 3.5

**Projet** : Excavatrice de Dragage (`2026_Projet_YGO_ExcavatriceDragage`)  
**Auteur** : Antigravity (Google DeepMind Agentic Team)  
**Date** : 12 Août 2026  
**Cible d'implémentation** : Orchestrateurs, Agents de Workflow & CI/CD  

---

## 🎯 1. Contexte & Objectifs

L'objectif de cette session de travail était de fournir une solution complète, fiable et performante pour :
1. **Linter et vérifier la syntaxe CODESYS** avant tout export/import manuel dans le logiciel CODESYS 3.5.
2. **Fournir un mode d'export granulaire** sous forme d'arborescence miroir XML pour importer facilement n'importe quel POU/PRG de manière isolée sans devoir manipuler le gros bundle monolithique.
3. **Automatiser le test de compilation native** en tâche de fond avec le vrai moteur CODESYS (`codesys.exe --noUI`) tout en conservant le contexte matériel et les déclarations globales d'un projet `.project` de référence.
4. **Obtenir des retours de compilation clairs, pédagogiques et explicites** (avec explication des codes `C0xxx`, diagnostics et actions correctives suggérées).

---

## 🏗️ 2. Réalisations & Nouveaux Outils Développés

### A. Dossier Miroir PLCopenXML : `CODE_XML/`
* **Emplacement** : `CODE_XML/` à la racine du dépôt.
* **Principe** : Reproduit 100% de l'arborescence du dossier `CODE/`. Chaque fichier source `.st` possède son pendant granulaire `.xml` immédiatement utilisable.
* **Fonctionnalité clé** : Chaque fichier XML individuel généré dans `CODE_XML/` embarque automatiquement la fermeture transitive de ses dépendances (les types `DUT`, les structures et les sous-blocs fonctionnels requis).
* **Commande de mise à jour / régénération** :
  ```powershell
  python -m generator.cli --code-dir CODE --out-dir CODE_XML
  ```
* **Procédure d'import CODESYS** : Clic droit sur le nœud `Application` dans CODESYS $\rightarrow$ `Importer PLCopen XML...` $\rightarrow$ Choisir le fichier dans `CODE_XML/`.

---

### B. Outil de Diagnostic & Explication Pédagogique : `codesys_compilation_diag.py`
* **Fichier** : `TOOLS/AGENT_WORKFLOW/scripts/codesys_compilation_diag.py`
* **Principe** : Analyse les logs de build bruts ou les erreurs capturées et traduit les codes d'erreurs CODESYS (`C0037`, `C0013`, `C0009`, `C0046`, `C0018`, `C0062`, `C0190`, etc.) en français explicite.
* **Structure du rapport produit** :
  * **Code & Ligne** : Identification précise du numéro de ligne et de la sévérité (Erreur/Avertissement).
  * **Titre & Explication** : Décodage vulgarisé du problème technique.
  * **Action requise** : Recommandation concrète pour corriger le code.
* **Utilisation** :
  ```powershell
  # Analyse d'un fichier journal de compilation
  python TOOLS/AGENT_WORKFLOW/scripts/codesys_compilation_diag.py --log build.log

  # Analyse explicative d'un texte d'erreur brut
  python TOOLS/AGENT_WORKFLOW/scripts/codesys_compilation_diag.py --text "C0037: 'MyVar' est un identificateur non défini"
  ```
* **Intégration Gate** : Directement câblé dans `G500_check_codesys_compile.py` (Gate 6).

---

### C. Runner de Compilation Headless CODESYS : `test_codesys_compile.py`
* **Fichier** : `TOOLS/AGENT_WORKFLOW/scripts/test_codesys_compile.py`
* **Principe** : Automatise l'exécution du compilateur natif CODESYS 3.5 en tâche de fond (sans IHM) pour tester l'intégrité d'un POU ou PRG granulaire.
* **Déroulement de l'exécution** :
  1. **Autodétection** : Détecte l'exécutable CODESYS (`C:\Program Files\CODESYS 3.5.19.10\CODESYS\Common\CODESYS.exe`) et le profil d'environnement (`CODESYS V3.5 SP19 Patch 1`).
  2. **Génération granulaire** : Génère le XML temporaire pour l'objet demandé (ex: `PRG_06_Outputs_Provisoire`) avec ses dépendances (`CODE/AU/`).
  3. **Isolation** : Copie un projet `.project` de référence (`PRJ_CODESYS/v0.6.00_RepriseApres20260807.project`) dans le dossier Temp système afin de ne **jamais** modifier ni verrouiller le projet principal.
  4. **Exécution CLI sans conflit** : Lance CODESYS avec les paramètres CLI stricts `--profile="..." --noUI --multipleinstances` afin d'éviter tout conflit avec l'IHM CODESYS déjà ouverte sur la machine de l'utilisateur.
  5. **Import & Syntax Check** : Exécute un script IronPython interne qui importe le XML et déclenche `proj.check_syntax()`.
* **Utilisation** :
  ```powershell
  python TOOLS/AGENT_WORKFLOW/scripts/test_codesys_compile.py PRG_06_Outputs_Provisoire
  ```

---

## ✅ 3. Validations & Tests Effectués

| Fonctionnalité | Statut | Résultat des tests |
|---|---|---|
| **Génération granulaire XML** | ✅ VALIDÉ | Testé sur `PRG_06_Outputs_Provisoire`. Le XML inclut automatiquement `FB_Safety_EmergencyManagement*` et toutes les structures `ST_Safety_Emergency_*`. |
| **Création du miroir `CODE_XML/`** | ✅ VALIDÉ | Arborescence miroir générée avec succès (13 sous-dossiers, tous les fichiers XML miroirs créés). |
| **Parsing & Traduction des erreurs C0xxx** | ✅ VALIDÉ | Validé sur les erreurs `C0037` (variable non définie), `C0013` (type mismatch), `C0009` (jeton inattendu), etc. |
| **Autodétection Profil CODESYS CLI** | ✅ VALIDÉ | Profile `CODESYS V3.5 SP19 Patch 1` détecté et formaté correctement. |
| **Compatibilité IHM CODESYS ouverte** | ✅ VALIDÉ | Testé avec l'IHM CODESYS (PID 19092) ouverte simultanément sur le PC via `--multipleinstances`. |

---

## 📌 4. Recommandations pour le Prochain Agent / Orchestrateur

Pour intégrer pleinement ces avancées dans le workflow permanent du projet :

1. **Intégration dans `run_all_gates.py`** :
   Ajouter une étape optionnelle ou automatique qui valide la mise à jour du dossier `CODE_XML/` lors de la génération du bundle.
2. **Hook Git Pre-commit / Pre-push** :
   Possibilité de déclencher `codesys_compilation_diag.py` si un fichier `.log` de build est détecté pour informer le développeur en français lisible.
3. **Conservation du miroir `CODE_XML/`** :
   Maintenir la commande `python -m generator.cli --code-dir CODE --out-dir CODE_XML` dans la séquence de livraison pour garantir que le dossier `CODE_XML/` reste toujours synchronisé avec `CODE/`.

---
*Fin du rapport technique d'ingénierie.*
