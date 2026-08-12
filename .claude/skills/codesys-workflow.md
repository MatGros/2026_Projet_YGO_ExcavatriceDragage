---
name: codesys-workflow
description: Workflow obligatoire pour toute modification du programme automate CODESYS 3.5. Impose lecture des règles, analyse de l'existant, plan validé, code ST commenté FR, vérification mécanique de liaison, bundle PLCopenXML et REX versionné. Déclencher dès que l'utilisateur demande de modifier/créer/analyser un FB, un PRG, des variables, ou « le programme automate » — y compris quand le travail est délégué à un autre agent (Gemini/antigravity, Codex, sous-agent Pi).
---

# 🏗️ Workflow CODESYS — Excavatrice de Dragage

Procédure **stricte et itérative**. L'utilisateur applique **manuellement** chaque modif dans
CODESYS 3.5 (copie du ST).

📖 Les **règles** ne sont pas ici — elles sont dans `DOC/`. Cette skill dit **comment exécuter**,
pas quoi respecter. En cas de doute sur une règle : `DOC/STDS/CODE_QUALITY_STANDARDS.md`.

---

## ⛔ RÈGLE D'OR

**NE JAMAIS faire ce qui n'est pas spécifié.**
Spec incomplète ou ambiguë → **STOP + demander clarification.** Jamais d'approximation,
jamais de refactor caché.

---

## 🚦 Aiguillage — qui exécute ?

- **« délègue à Gemini »** → skill `antigravity:delegate`. Coller d'abord
  `TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md` en tête de la tâche : l'agent distant n'a
  pas le contexte de cette conversation.
- **Sous-agent Pi / agent Claude** → même préambule obligatoire.
- **Sinon** → exécution directe, étapes ci-dessous.

Dans tous les cas, **c'est l'orchestrateur qui valide le résultat** (lecture du `git diff` réel),
jamais l'agent qui l'a produit.

---

## 📚 Étape 0 — Charger les règles

Lire **la version active** (suffixe `_vX.Y` le plus élevé à la racine de `DOC/`) :

- `AGENTS.md` — guardrails et cas d'arrêt
- `DOC/STDS/CODE_QUALITY_STANDARDS.md` — déclaration, liaison, POO, non-régression
- `DOC/STDS/NAMING_CONVENTION.md` — nommage
- `DOC/AF/AF_Partie-03_Contrats_Composants_v2.1.md` — contrats FB, DUT et CFC
- `DOC/AF/AF_Partie-02_Architecture_Programme_v3.1.md` — architecture, tâches et flux
- la spec métier concernée (`AF_Partie-08` à `-14`)

🚫 `ARCHIVES/Doc/` = versions **périmées**, jamais une source active.
✋ Si une règle DOC contredit la demande → signaler **avant** de coder.

💡 Les liens de version sont maintenus automatiquement :
`python TOOLS/AGENT_WORKFLOW/scripts/G340_check_doc_links.py --fix`.

---

## 🔍 Étape 1 — Comprendre l'architecture

`PRJ_CODESYS/PROJ_Full_ImportExport/Device.export` (~89k lignes → **grep ciblé**, jamais en entier) :
tâches, mapping E/S, devices bus (EtherCAT, CANopen).

---

## 🔬 Étape 2 — Analyser l'existant

Cartographier avant de toucher : variables concernées, `PRG_*`/`FB_*` impactés, dépendances et
**appelants**. Objectif : modif chirurgicale.

---

## 🧩 Étape 3 — Plan groupé par concept

- Regrouper **par concept fonctionnel**, pas fichier par fichier
- ❌ Pas de refactor global sans validation explicite
- Présenter le plan → **attendre la validation** avant d'écrire

---

## 🧪 Étape 3bis — Contrat de vérification (C3/C4 & safety)

Sujet `SafeStop`, `PowerCutOff`, AU, frein, contacteur, interlock, limite physique :

📌 **Décision 2026-08-01** : le test PLC automatique n'est plus obligatoire pour C3/C4 —
même coût que le framework `PLC_TESTS` abandonné le 2026-07-26 (RAM, resynchronisation),
pour des preuves jamais réellement exécutées en CODESYS (`CODE/TESTS/` archivé dans
`ARCHIVES/Code/TESTS/`). La garantie repose sur `human_validation_required` seul.

1. `TASK_CONTEXT` déclare `human_validation_required: true` et des critères d'acceptation
   vérifiables (§ci-dessous). Test PLC automatique **optionnel** : si la tâche en écrit un
   quand même, déclarer `tests_automated_required: true` + les fichiers de test.
2. Si `tests_automated_required: true` : `python TOOLS/AGENT_WORKFLOW/scripts/check_task_test_contract.py <TASK_CONTEXT>` avant de coder, pour tenir la déclaration à sa parole.
3. Vérification manuelle exhaustive (Watch/forçage CODESYS) **avant tout chargement** — non
   négociable, que le test automatique existe ou non.
4. Si un test automatique a été déclaré : avant restitution, `... check_task_test_contract.py
   <TASK_CONTEXT> --release`. Sans statut `implemented` + preuve d'exécution → annoncer
   « lot incomplet ».

---

## 💻 Étape 4 — Code ST + note d'application

1. Code ST conforme au contrat FB et au nommage
2. Commentaires **français, détaillés, avec emoji** — en-tête (rôle, doc, sécurité, dépendances)
   + un commentaire par section logique
3. **Note d'application CODESYS 3.5** : où coller, quel POU, quelles déclarations, dans quel ordre

📁 **Double sortie obligatoire** :

1. 📂 **`CODE/<DOSSIER>/<NomDuPOU>.st`** — source unique exécutable que l'utilisateur copie
   (ex. `CODE/JOYSTICK/FB_Joystick.st`, `CODE/TREUILS/FB_Winch.st`).
2. 📄 **`DOC/AF_Partie-N_Fonction_<Metier>_vX.Y.md`** (N ≥ 8) — rôle métier, pipeline, interface
   IN/OUT, mapping E/S, **référence** au fichier `CODE/*.st`, note d'application, REX.

🧭 **Anti-doublon (STRICT)** : le **corps** ST n'existe qu'une fois, dans `CODE/`.
`DOC/` peut porter l'interface IN/OUT et le mapping, **jamais** la logique — il référence.

---

## 🛑 Étape 4bis — Vérification mécanique (BLOQUANTE, tout lot)

> ⛔ Un bundle généré, des tests Python verts ou un XML bien formé **ne prouvent jamais**
> qu'une fonction est reliée au reste du programme. Le bug `PRG_10_Outputs_LD` a franchi
> tous ces contrôles (REX 2026-07-29).

```powershell
python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py --report
python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .
python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py
```

- `G200_check_linkage.py` prouve : instance déclarée là où elle doit vivre, appelée dans le même POU,
  aucune orpheline ailleurs, références croisées valides, `typeName` du bundle = type déclaré,
  programme présent dans la configuration de tâche.
- Le bloc **`Auto-vérification liaison`** produit par `--report` est **collé dans la restitution**.
  Un lot restitué sans ce bloc est incomplet.
- Un échec est **bloquant** : ne pas fournir de procédure d'import, ne pas annoncer le lot prêt.

🩺 **Cascade d'erreurs** : si CODESYS remonte des dizaines d'erreurs, chercher d'abord
l'identificateur non défini commun — jamais corriger erreur par erreur avant d'avoir isolé la racine.

### 📥 Import dans CODESYS

1. Sélectionner le nœud `Application` dans l'arbre CODESYS 3.5
2. **Project → Import PLCopenXML...**
3. Choisir `CODE/CODE_Bundle.xml`
4. Valider les objets proposés

### 📐 Note `_LD.st` → `<LD>` (REX 2026-08)

Les sources `_LD.st` sont converties en `<LD>` Ladder par le générateur.
Règles bloquantes (détail : `DOC/STDS/CODE_QUALITY_STANDARDS.md §11`, `DOC/AF_Partie-03 §6`) :

- **Rung complet obligatoire** : `contact → block(FB) → coil → rightPowerRail`.
  Le générateur rejette les rungs incomplets (sans coil).
- `FB_Input` câble `InputRaw` comme contact principal ; `FB_Output` câble `Command`.
- Chaque block FB doit avoir une **coil reliée à `.State`**.
- `NOT var` produit un contact `negated="true"`, jamais un `inVariable`.
- Une page LD BOOL pure ne contient aucun `inVariable`/`outVariable`.
- Tests : `python -m pytest TOOLS/AGENT_WORKFLOW/tests/test_ld_import_guard.py -v`

---

## 🔁 Étape 5 — REX (si validé fonctionnel)

Quand l'utilisateur confirme que ça marche : capitaliser dans les specs `DOC/`,
**versionner** (`_v2.2` → `_v2.3`, ancien dans `ARCHIVES/Doc/`, jamais d'écrasement).

🔧 **Règle `fix:` + `guard:`** — tout bug détecté donne **deux** livrables : la correction **et**
un garde-fou automatique dans `TOOLS/AGENT_WORKFLOW/scripts/` pour que cette classe d'erreur soit
attrapée seule la prochaine fois. Une réponse purement documentaire à un incident est insuffisante.

---

## 🔄 Étape 6 — Rebouclage

Attendre le **nouvel export** utilisateur (`Device.export` régénéré) → reprendre à l'Étape 1.

---

## ✅ Checklist rapide

- [ ] Règles DOC lues (Étape 0) · spec complète, sinon STOP
- [ ] Architecture + existant analysés (appelants inclus)
- [ ] Plan groupé par concept **validé par l'utilisateur**
- [ ] Code ST commenté FR + emoji dans `CODE/<DOSSIER>/*.st`
- [ ] `G200_check_linkage.py --report` = PASS, bloc collé dans la restitution **(bloquant)**
- [ ] `CODE/CODE_Bundle.xml` régénéré + `run_all_gates.py` = PASS **(bloquant)**
- [ ] Si C3/C4/safety : tests PLC implémentés + exécutés **(bloquant)**
- [ ] Doc métier + note d'application dans `DOC/AF_Partie-N_Fonction_*`
- [ ] REX + specs versionnées · garde-fou `guard:` ajouté si bug rencontré
