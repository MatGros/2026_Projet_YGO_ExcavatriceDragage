---
name: codesys-workflow
description: Workflow obligatoire pour toute modification du programme automate CODESYS 3.5 (Device.export). Impose lecture des règles DOC, analyse architecture, plan groupé par concept, génération ST commentée FR, note d'application manuelle, et retour d'expérience versionné. Déclencher dès que l'utilisateur demande de modifier/créer/analyser FB, PRG, variables, ou "le programme automate". Déclencher AUSSI dès que l'utilisateur demande de déléguer/confier/envoyer ce travail à Gemini (agent d'exécution) — la skill aiguille alors vers la procédure de délégation (§Aiguillage) au lieu d'exécuter directement.
---

# 🏗️ Workflow CODESYS — Excavatrice de Dragage

Procédure **stricte et itérative** pour modifier le programme automate.
L'utilisateur applique **manuellement** chaque modif dans CODESYS 3.5 (copie du code ST).

---

## 🚦 Aiguillage préalable — Qui exécute ?

**Avant l'Étape 0**, déterminer QUI fait le travail :

- **Utilisateur dit "délègue à Gemini" / "utilise l'agent Gemini" / "confie/envoie ça à Gemini"** (ou toute formulation équivalente, même approximative) → **Claude n'exécute PAS lui-même.** Aller directement à la section **§ Délégation à Gemini** plus bas, ignorer les Étapes 0-6 (elles décrivent ce que GEMINI doit suivre, répliquées dans `DOC/AGENT_HANDOFF/GEMINI_BRIEF.md` — Claude les traduit en contraintes copiées dans le fichier tâche, il ne les applique pas lui-même).
- **Sinon (cas normal)** → Claude exécute directement, Étapes 0 à 6 ci-dessous s'appliquent à lui.

⚠️ Cet aiguillage ne concerne QUE le pathway Gemini — l'usage normal de l'outil `Agent` (subagents Claude, forks) reste libre et indépendant de cette skill.

---

## ⛔ RÈGLE D'OR

**NE JAMAIS faire ce qui n'est pas spécifié.**
Spec incomplète ou ambiguë → **STOP + demander clarification.** Jamais d'approximation, jamais de refactor caché.

---

## 📚 Étape 0 — Charger les règles (OBLIGATOIRE avant tout)

Lire et appliquer **systématiquement** :
- `DOC/NAMING_CONVENTION.md` → PascalCase, préfixes, pas de hongrois
- `DOC/AF_Partie-03_Template_FB_Commun_v1.2.md` → contrat FB (Enable/Reset/EmergencyStopOk/Mode/Ready/Error… ; profils d'interface §1bis : FB standard vs FB de mouvement `StartStop`/`SafeStop` vs briques réduites ; précédence Enable > SafeStop > StartStop) + réutilisation libs
- `DOC/AF_Partie-02_Architecture_Programme_v2.6.md` → architecture, tâches, flux
- `DOC/AF_Partie-01_Analyse_Fonctionnelle_v1.3.md` → équipements & fonctions

⚠️ Toujours utiliser la **version la plus récente** (suffixe `_vX.X` le plus élevé). Anciennes versions dans `DOC/Archives/`.

✋ Si une règle DOC contredit la demande → signaler avant de coder.

🚫 **`DOC/Archives/` = versions PÉRIMÉES** : ne jamais lire ni prendre en compte ce dossier (gitignoré). Toujours la version active (suffixe `_vX.Y` le plus élevé à la racine de `DOC/`).

---

## 🔍 Étape 1 — Comprendre l'architecture

Lire `PRJ_CODESYS/PROJ_Full_ImportExport/Device.export` (⚠️ ~89k lignes → **analyse ciblée par grep**, jamais en entier).

Objectif : architecture générale + **devices de communication** (EtherCAT, CANopen…).
Repérer : tâches, mapping E/S, devices bus.

---

## 🔬 Étape 2 — Analyser l'existant

Avant toute modif, cartographier :
- **Variables** concernées (GVL, déclarations FB/PRG)
- **Programmes** (PRG_*) et **Function Blocks** (FB_*) impactés
- Dépendances / appelants

But : se préparer à une modif **chirurgicale**, sans casser le reste.

---

## 🧩 Étape 3 — Plan groupé par concept

- Regrouper les modifs **par concept fonctionnel** (pas fichier par fichier)
- ❌ **Pas de refactor global** sauf si réellement utile **ET validé par l'utilisateur**
- Présenter le plan → **attendre validation explicite** avant de coder

---

## 💻 Étape 4 — Génération code ST + note d'application

Après validation du plan :

1. **Code ST** respectant le contrat FB et le nommage
2. **Commentaires superbien détaillés, en français, avec emoji** 🎯
   - Bloc d'en-tête : rôle, entrées, sorties, sécurité
   - Commentaire sur chaque section logique
3. **Note d'application CODESYS 3.5 détaillée** : où coller, quel POU, quelles déclarations, ordre des étapes — car l'utilisateur applique **tout à la main**.

📁 **Double sortie obligatoire** :

1. 📂 **Code ST à copier → dossier `CODE/`** (jamais ailleurs).
   - Tout code que l'utilisateur doit copier/créer dans CODESYS est écrit comme **fichier `.st` brut** dans `CODE/`.
   - Nom = nom du POU, ex. `CODE/PRG_JOY1.st`, `CODE/FB_Winch.st`.
   - C'est ce fichier que l'utilisateur copie-colle dans CODESYS.

2. 📄 **Doc métier + note d'application → dossier `DOC/`** (série AF).
   - `AF_PartieN_Fonction_<Metier>_vX.Y.md`, **N ≥ 8** (ex. `AF_Partie-08_Fonction_Joystick_v1.1.md`, `AF_Partie-09_Fonction_Winch_v1.0.md`).
   - Structure : rôle métier → pipeline/blocs → interface → sécurité → mapping E/S → **référence au(x) fichier(s) `CODE/*.st`** → note d'application CODESYS 3.5 → REX.
   - Versionner `vX.Y`, anciens dans `DOC/Archives/`.

🧭 **Règle anti-doublon (STRICTE)** : le **corps/implémentation** ST n'existe **qu'une seule fois**, dans `CODE/*.st`.
- ✅ `DOC/` PEUT contenir : l'**interface IN/OUT** (tableaux des entrées/sorties, types, rôles), le mapping E/S, le pipeline.
- ❌ `DOC/` ne recopie **JAMAIS** le **corps** du POU (logique, appels, calculs) — il **référence** `CODE/xxx.st`.
`CODE/` = source unique exécutable à copier ; `DOC/` = métier + interface IN/OUT + mode d'emploi qui pointe vers `CODE/`.

Style commentaires :
```
(* ═══════════════════════════════════════════════
   🎮 FB_Joystick — Acquisition + traitement Hall
   ───────────────────────────────────────────────
   📥 Enable          : autorisation traitement ; FALSE = neutralisation (sorties coupées)
   📤 Ready            : valeurs valides disponibles
   🛡️ EmergencyStopOk  : conditions globales OK (chaîne AU réarmée)
   ⚠️ FB de mouvement uniquement (pas FB_Joystick) : StartStop (rampe normale),
      SafeStop en entrée (sortie du bloc safety métier concerné → rampe rapide, Enable maintenu)
   ═══════════════════════════════════════════════ *)
```

---

## 📦 Étape 4bis — Génération du bundle PLCopenXML (Optionnelle)

À la fin de l'écriture du code (Étape 4) et avant que l'utilisateur ne procède à l'intégration, lui **demander explicitement** s'il souhaite générer le bundle PLCopenXML (`CODE_Bundle.xml`) regroupant toutes les modifications pour un import automatique dans CODESYS.

### ❓ Quand exécuter cette étape ?
- À la fin de toute modification/création de fichiers `.st` dans le dossier `CODE/`.
- Uniquement si l'utilisateur valide l'action (poser la question).

### 🛠️ Comment exécuter la génération ?
Si l'utilisateur accepte, exécuter la commande Python suivante.

* **Répertoire de travail (Cwd) obligatoire :** `C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\PLCOPENXML_TOOLING`
* **Commande exacte :**
  ```powershell
  python -c "from generator.cli import main; import sys; sys.exit(main(['--bundle', 'CODE_Bundle', '--project-name', '<version>']))"
  ```
  *(Remplacer `<version>` par la version actuelle du projet CODESYS présente dans le nom du fichier `.project` actif du dossier `PRJ_CODESYS/`, par exemple `Programme MGS_v0.3.11` ou `MGS_v0.3.11`)*

### 🔍 Exemple concret avec la version `MGS_v0.3.11` :
```powershell
python -c "from generator.cli import main; import sys; sys.exit(main(['--bundle', 'CODE_Bundle', '--project-name', 'MGS_v0.3.11']))"
```

### 📥 Méthode d'import dans CODESYS :
Une fois le fichier généré dans `PLCOPENXML_TOOLING/generated/CODE_Bundle.xml` :
1. Dans l'arbre du projet CODESYS 3.5, sélectionner le nœud parent cible (généralement `Application`).
2. Cliquer sur **Project** ➔ **Import PLCopenXML...**.
3. Sélectionner `C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\PLCOPENXML_TOOLING\generated\CODE_Bundle.xml`.
4. Cocher les éléments voulus et valider (l'arborescence définie dans `ProjectStructure` sera recréée relativement au nœud parent sélectionné).

---

## 🔁 Étape 5 — Retour d'expérience (si validé fonctionnel)

Quand l'utilisateur confirme que ça marche :
- **Review** : capitaliser la connaissance acquise
- Proposer mise à jour des specs `DOC/` pour accumuler le savoir
- ⚠️ **Versionning obligatoire** : nouveau nom de fichier `vX.X` (ne jamais écraser, ex. `_v2.2` → `_v2.3`)

---

## 🔄 Étape 6 — Rebouclage

Attendre le **nouvel export** utilisateur (Device.export régénéré depuis CODESYS) → reprendre à l'étape 1.

---

## 🤝 Délégation à Gemini (si aiguillé ici en tête de skill)

⛔ **Règle d'or de cette section** : je ne fais PAS le travail moi-même, je le prépare pour Gemini.

> 🔔 **Prérequis côté Gemini** : Gemini doit avoir lancé `PLCOPENXML_TOOLING/push_server.py` (port 9090) en début de session, en écoute. Procédure complète → `DOC/AGENT_HANDOFF/GEMINI_BRIEF.md` §Push Notifications.
>
> ⚡ **Réveil = découplé du commit (REX 2026-07-15)** : le hook git `post-commit` ne suffit pas à
> lui seul (délai/fiabilité). **Dès que `QUEUE.md`/le fichier tâche est édité ET validé par
> l'utilisateur**, j'appelle **directement** `curl -s -X POST http://localhost:9090/wake` — pas
> besoin d'attendre ou de faire un commit pour déclencher le réveil. Le commit reste soumis à la
> règle habituelle (jamais sans validation), il arrive **après** le retour Gemini (`REVIEW`) et
> la validation finale de l'utilisateur, pas pour déclencher le réveil.

🔒 **Garde-fous automatiques (Hooks CLI)** : Un hook système global (`~/.gemini/config/hooks.json` → `PLCOPENXML_TOOLING/guardrails.py`) intercepte et valide automatiquement chaque action de Gemini si le workflow multi-agent est actif. Il bloque les commits directs de Gemini et les modifications de fichiers hors-scope.

1. **Comprendre la demande** — si le scope n'est pas clair (quels fichiers, quel comportement attendu), demander avant de créer la tâche. Ne jamais deviner un scope flou dans une tâche qui partira vers un agent qui n'a pas le contexte de cette conversation.
2. **Déterminer le prochain ID** — lire `DOC/AGENT_HANDOFF/QUEUE.md` + lister `DOC/AGENT_HANDOFF/tasks/`, trouver le dernier `TASK-00NN`, incrémenter. Jamais réutiliser un ID.
3. **Créer `DOC/AGENT_HANDOFF/tasks/TASK-00NN-slug.md`** depuis `TASK-0000-template.md`, rempli **intégralement et de façon autonome** :
   - Objectif : contexte métier/utilisateur réel (le POURQUOI), pas juste "modifier X"
   - Scope : fichiers exacts + ce qui est explicitement HORS scope
   - Contraintes **copiées-collées** (pas de simple lien) — reprendre les MÊMES règles que l'Étape 0/2 ci-dessus : `NAMING_CONVENTION.md`, contrat FB `AF_Partie-03` (précédence `Enable > SafeStop > StartStop`, `Reset` = front), doc métier `AF_PartieN` concerné
   - Critères d'acceptation concrets et vérifiables
   - `Status: TODO`, `Assigned: Gemini`
4. **Ajouter la ligne dans `DOC/AGENT_HANDOFF/QUEUE.md`**.
5. **Demander validation utilisateur** sur le fichier tâche + la ligne `QUEUE.md` (règle habituelle de validation fichier).
6. **Une fois validé → réveiller Gemini directement** : `curl -s -X POST http://localhost:9090/wake` (pas de commit nécessaire pour ça, voir note ci-dessus). Rien d'autre à faire côté Claude tant que `Status` n'est pas `REVIEW`.
7. **Jamais de commit** de cette création de tâche sans validation (même règle que tout le reste) — le commit peut attendre le retour Gemini, il n'est plus le déclencheur du réveil.

### Quand l'utilisateur revient avec un résultat Gemini (`Status: REVIEW`)
Relire le `Log` de la tâche + le diff réel (`git diff`/`git status`), vérifier les critères d'acceptation, régénérer le bundle PLCopenXML (Étape 4bis ci-dessus) si du ST a été touché, **puis seulement** passer `Status: DONE` dans le fichier tâche ET `QUEUE.md`. Ne jamais passer `DONE` sur la seule confiance du `Log` rempli par Gemini.

💡 **La lecture du diff peut être déléguée à un subagent Claude** (fork, ou agent `code-reviewer`/`general-purpose` via l'outil `Agent` — usage libre, pas concerné par l'aiguillage Gemini) pour garder ce contexte propre — utile en particulier sur un gros diff Gemini. Mais **la décision finale `REVIEW → DONE` reste toujours prise par Claude orchestrateur lui-même**, jamais déléguée plus loin : lire le résultat du subagent, pas juste lui faire confiance aveuglément.

### Cycle de vie / nettoyage des tâches (voir aussi `DOC/AGENT_HANDOFF/QUEUE.md` §Cycle de vie)
Une fois `DONE` (ou abandon explicite) : déplacer la ligne de `QUEUE.md` vers son archive, puis **supprimer** le fichier détaillé `tasks/TASK-00NN-slug.md` — jamais avant que le commit correspondant soit validé par l'utilisateur (la trace git doit exister avant que le fichier de travail disparaisse). Tâches `TODO`/`IN_PROGRESS`/`BLOCKED`/`REVIEW` : jamais supprimées.

---

## ✅ Checklist rapide

- [ ] Règles DOC lues + appliquées
- [ ] Spec complète ? (sinon STOP)
- [ ] Architecture + devices compris
- [ ] Existant analysé (variables/PRG/FB)
- [ ] Plan groupé par concept **validé**
- [ ] Code ST à copier commenté FR + emoji **écrit dans `CODE/*.st`**
- [ ] Proposition de génération du bundle PLCopenXML faite et exécutée si demandée
- [ ] Doc métier + note d'application CODESYS 3.5 **dans `DOC/AF_PartieN_Fonction_*`**
- [ ] REX + specs versionnées `vX.X`
