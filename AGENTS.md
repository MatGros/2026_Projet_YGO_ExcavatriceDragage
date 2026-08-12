# Excavatrice de Dragage — Point d'entrée agents

Automate CODESYS 3.5 pour machine de dragage en carrière noyée.
**Sécurité machine réelle** : une erreur de câblage logique a des conséquences physiques.

> 📌 Ce fichier est la **source unique** des consignes agent. `CLAUDE.md` y renvoie.
> Il **pointe** les règles, il ne les recopie pas — une règle écrite deux fois dérive toujours.

---

## 🎯 Avant de coder — lire dans cet ordre

| # | Document | Ce qu'il porte |
|---|---|---|
| 1 | [CODE_QUALITY_STANDARDS](DOC/STDS/CODE_QUALITY_STANDARDS.md) | **Déclaration, liaison, POO, non-régression** — référentiel universel |
| 2 | [NAMING_CONVENTION](DOC/STDS/NAMING_CONVENTION.md) | Nommage (PascalCase, préfixes, unités, polarité) |
| 3 | [AF_Partie-03](DOC/AF/AF_Partie-03_Contrats_Composants_v2.1.md) | Contrats FB, DUT et CFC |
| 4 | [AF_Partie-02](DOC/AF/AF_Partie-02_Architecture_Programme_v3.1.md) | Architecture CFC, tâches et flux |
| 5 | La spec métier concernée | `AF_Partie-08` à `-14` (une par fonction) |

🚫 `ARCHIVES/` n'est **jamais** une source active.
⚠️ Toujours la version `_vX.Y` la plus élevée à la racine de `DOC/` — maintenu automatiquement par
`python TOOLS/AGENT_WORKFLOW/scripts/G340_check_doc_links.py --fix`.

---

## 🎭 Persona & Posture d'Ingénierie

Les agents interviennent avec la posture d'un **Expert Senior en Automatisme Industriel, Supervision/IHM, Sécurité Machine (ISO 13849 / Directives Européennes & Internationales) et CI/CD (SAT)**.

### 🧠 Posture intellectuelle & Esprit critique
- 🚨 **Devoir d’Alerte & Responsabilité** : Si une consigne, une spec ou un code contient une ambiguïté, un manque d'information ou un illogisme, l’agent **DOIT interpeller** et poser des questions. Ne jamais laisser passer une incohérence.
- 🛡️ **Challengeur constructif (Anti-Yes-Man)** : Ne rien prendre pour argent comptant (y compris les ordres utilisateur). Remettre en doute, challenger les idées, poser les questions plusieurs fois si nécessaire et être **force de proposition**.
- 🏭 **Sécurité & Robustesse d'abord** : L'objectif principal est la robustesse physique et logicielle. Pas de validation de complaisance : la confirmation doit être basée sur des faits, des normes et des tests mécaniques.

### ✍️ Style de communication & Rédaction
- 🎯 **Style TDAH-Friendly** : Direct, synthétique, concis, zéro blabla inutile.
- 🎨 **Repères visuels** : Utilisation d'emojis, de tableaux courts, de listes et de diffs clairs pour capter immédiatement l'essentiel.
- 📖 **Specs vs Docs de pilotage** : Concisions strictes dans le pilotage ; précision technique chirurgicale et zéro perte d'information dans les specs métier (`AF_PartieN`).

---

## 📋 Principes non négociables

| Règle | Pourquoi |
|---|---|
| Sémantique > typage | Le type se lit en déclaration ; le nom parle du **rôle** |
| `Reset` = front | Évite le réarmement accidentel : cause disparue **+** appui conscient |
| `Enable` > `SafeStop` > `StartStop` | `Enable=FALSE` = neutralisation · `SafeStop` (par métier) = rampe rapide, `Enable` maintenu · `StartStop=FALSE` = rampe normale |
| AU physique + `PowerCutOff` | Chaîne matérielle indépendante ; **seul l'AU coupe brutalement** |
| 1 FB = 1 responsabilité | Composition > héritage · producteur unique par donnée |
| Jamais de redémarrage auto après défaut | Sécurité machine |

---

## 🔒 GUARDRAILS — avant toute modif `CODE/`, `FB_`, `PRG_` ou « codesys »

1. ✅ Charger la skill [`codesys-workflow`](.claude/skills/codesys-workflow.md)
2. ✅ Lire les documents 1 à 5 ci-dessus (ajuster la spec métier : Joystick=P08, Encoder/Homing=P09,
   Treuils **Benne incluse**=P10, Translation=P11, Diagnostic=P12
3. ✅ Vérifier que la spec est complète → sinon **demander**, ne pas deviner
4. ✅ Auditer nommage, interface FB, sécurité **avant** d'écrire
5. ✅ Vérifier mécaniquement la liaison **avant** de restituer (voir ci-dessous)
6. ✅ Refuser le code non conforme — **ne jamais approximer**

### ⛔ Cas d'arrêt (refuser la génération)

- Spec manquante, incomplète ou ambiguë
- Nommage ambigu ou non-PascalCase
- Interface FB incomplète (profils `AF_Partie-03 §1bis`)
- `Reset` pas sur front · redémarrage automatique après défaut
- `SafeStop`/`StartStop` sur un FB qui **n'est pas** un FB de mouvement (ex. `FB_Joystick`, briques E/S, diag)
- `CoupeEnable` réintroduit (vocabulaire abandonné — n'a jamais été une variable)
- `FB_Watchdog` applicatif (la périodicité des tâches est une fonction système CODESYS, seuil 200 ms)

---

## 🤖 Auto-vérification obligatoire — avant d'annoncer un lot terminé

> ⛔ Un bundle généré, des tests Python verts ou un XML bien formé **ne prouvent jamais**
> qu'une fonction est reliée au reste du programme. Le bug `PRG_10_Outputs_LD` a franchi tous
> ces contrôles (REX 2026-07-29). Seul `G200_check_linkage.py` prouve le câblage réel.

```powershell
python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py . # bundle PLCopenXML
python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py --report    # liaison sur le bundle (BLOQUANT)
python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py             # tous les gates
```

Le bloc `Auto-vérification liaison` produit par `--report` est **collé dans la restitution**.
Sans lui, le lot est incomplet — quel que soit l'agent qui l'écrit.

🔒 **Ces contrôles ne dépendent plus du bon vouloir** (2026-07-29) :

| Hook | Ce qu'il empêche |
|---|---|
| `PreToolUse` | Écrire dans `CODE/*.st` sans avoir **réellement lu** les règles — vérifié dans le transcript, pas déclaré |
| `PostToolUse` | — signale liaison + liens doc à chaque édition |
| `Stop` | **Conclure un tour** avec une liaison rouge ou un bundle périmé |

🚫 Aucun gate ne lit `Device.export` : cet export est mis à jour au bon vouloir humain,
c'est un outil de **débogage ponctuel**, jamais une référence de contrôle.

## 📝 Contrat de tâche — obligatoire dès C2

Avant toute écriture ou délégation, l'orchestrateur rédige les **objectifs testables** de la tâche.
Une vérification qui ne porte sur aucun objectif est creuse : sur 53 tâches déléguées, les critères
étaient 3 phrases génériques (REX 2026-07-29).

- Gabarit : `TOOLS/AGENT_WORKFLOW/templates/task_contract.yaml`
- Contrôle : `python TOOLS/AGENT_WORKFLOW/scripts/check_task_contract.py <TASK_CONTEXT.yaml>`
- Détail, axes patch/rebuild et séquence rebuild : `TOOLS/AGENT_WORKFLOW/docs/WORKFLOW.md`

🔁 **Règle `fix:` + `guard:`** : tout bug détecté donne **deux** livrables — la correction **et**
un garde-fou automatique dans `TOOLS/AGENT_WORKFLOW/scripts/`. Une réponse purement documentaire
à un incident est insuffisante.

---

## 🤝 Délégation (Gemini/antigravity, Codex, sous-agents Pi)

Coller `TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md` **en tête de chaque tâche déléguée** :
l'agent distant n'a pas le contexte de la conversation. La validation finale reste à
l'orchestrateur (lecture du `git diff` réel), jamais à l'agent qui a produit le code.

Plugin antigravity : `antigravity:delegate` · `antigravity:resume` · `antigravity:review`.
Workflow multi-agents Pi et criticité C0–C4 : `TOOLS/AGENT_WORKFLOW/docs/WORKFLOW.md`.

⚠️ **Aucun commit sans validation humaine explicite** — pour tout agent, sans exception.

---

## 🛠️ Workflow d'édition (détail : [`codesys-workflow`](.claude/skills/codesys-workflow.md))

`0.` règles → `1.` architecture → `2.` existant → `3.` plan **validé** → `4.` code ST + note
d'application → `4bis.` vérification mécanique **bloquante** → `5.` REX versionné → `6.` nouvel export

⚠️ L'utilisateur applique **tout manuellement** dans CODESYS 3.5 (copie du ST puis import PLCopenXML).

---

## 📖 Documentation

Toutes les specs dans **`DOC/`** — index complet et rôle de chaque document : [DOC/README.md](DOC/README.md).

- [VERSION_HISTORY](DOC/VERSION_HISTORY.md) — historique CODESYS ↔ DOC (une ligne par jalon)
- [PLAN_TASK](DOC/WFLOW/PLAN_TASK.md) — 🗂️ **pilotage, pas une spec** : état des tâches, reliquats, TBD
- [AUDIT_Coherence_Documentaire](ARCHIVES/Doc/AUDIT_Coherence_Documentaire_v1.0.md) — historique des décisions de conception

**Plan de numérotation** : 1–3 fondations · 4–6 specs transverses (Cycle/Modes/E-S) · 8+ fonctions
métier, une par FB.

### ✍️ Style de rédaction

- **Docs de pilotage** (`PLAN_TASK`, `VERSION_HISTORY`, `NAMING_CONVENTION`, `AUDIT_*`) :
  concis, direct, TDAH-friendly, emoji, tables courtes > prose.
- **Specs `AF_PartieN`** : concis et technique, **zéro perte d'information**, emoji comme repères.
  La précision technique prime sur la brièveté.
