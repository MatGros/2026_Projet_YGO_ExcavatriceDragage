# Préambule obligatoire — tout sous-agent qui touche au code

> 📌 **À coller en tête de CHAQUE tâche déléguée** (Pi Subagents worker/reviewer, agent Claude,
> Codex, antigravity). Sans lui, le sous-agent démarre sans les règles du projet et redécouvre
> les mêmes bugs — c'est ce qui s'est produit sur `PRG_10_Outputs_LD` (REX 2026-07-29).
> Le préambule est court **exprès** : il pointe, il ne recopie pas.

---

## Contexte projet

Automate CODESYS 3.5, machine de dragage. Code ST dans `CODE/`, appliqué **manuellement** par
l'utilisateur dans CODESYS. Sécurité machine réelle : une erreur de câblage logique a des
conséquences physiques.

## 📝 Contrat de tâche — ta seule référence de succès

> REX 2026-07-29 : sur 53 tâches déléguées, les critères d'acceptation étaient 3 phrases
> génériques. Un agent rendait donc un rapport « conforme » à **rien**.

Le contrat de tâche fourni avec cette mission porte les **critères testables**. Ils remplacent
tout critère générique d'acceptation. Ta restitution se juge **contre eux**, pas contre
« j'ai bien travaillé ».

- Un critère sans moyen de vérification n'est pas un critère → **le signaler, ne pas deviner**.
- Si aucun contrat n'est fourni sur une tâche de criticité ≥ C2 → **demander**, ne pas commencer.

## 🚨 Devoir d'alerte — non négociable

Tout problème constaté **en cours de route** (incohérence de spec, bug préexistant, risque hors
scope, doute de sécurité) remonte **immédiatement** à l'orchestrateur — pas à la fin, jamais
silencieusement, jamais enterré dans un paragraphe de conclusion.

**Signaler n'est pas élargir le périmètre.** On attend le signalement, pas la correction
spontanée. Continuer en silence sur un doute est la faute ; le signaler ne l'est jamais.

## À lire avant d'écrire (dans cet ordre, aucune exception)

1. `AGENTS.md` — point d'entrée, guardrails et cas d'arrêt
2. `DOC/CODE_QUALITY_STANDARDS.md` — déclaration, liaison, POO, non-régression
3. `DOC/NAMING_CONVENTION.md` — nommage
4. `DOC/AF_Partie-03_Contrats_Composants_v2.0.md` — contrats FB, DUT et CFC (si création/modif de FB)
5. La spec métier concernée (`DOC/AF_Partie-08` à `-14`)

`ARCHIVES/` n'est **jamais** une source active.

## Cas d'arrêt — ne pas produire de code, demander

- Spec incomplète, ambiguë, ou contredite par la doc
- Nommage impossible à décider sans hypothèse
- Interface FB incomplète (profils `AF_Partie-03 §1bis`)
- `Reset` pas sur front · redémarrage automatique après défaut
- `SafeStop`/`StartStop` sur un FB qui n'est pas un FB de mouvement
- `CoupeEnable` ou `FB_Watchdog` applicatif réintroduits

## Vérification mécanique avant de rendre le lot

```powershell
python TOOLS/AGENT_WORKFLOW/scripts/check_linkage.py --report
python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .
python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py
```

⛔ Un bundle généré ou des tests Python verts **ne prouvent pas** qu'une fonction est reliée.
Seul `check_linkage.py` le prouve. Le bloc `Auto-vérification liaison` qu'il produit doit
figurer dans la restitution.

## Format de restitution attendu

```text
Auto-vérification liaison (check_linkage.py) — PASS|FAIL
  OK  <instance> : <FB> — déclarée <fichier>:<ligne> · appelée :<ligne>
  ...
Gates : structure / style / liaison / persistance / bundle / pytest = PASS|FAIL
Fichiers modifiés : ...
Hors scope constaté (devoir d'alerte) : ...
```

## Interdits absolus pour un sous-agent

- Commit, push, reset, rebase — **jamais**, la validation est humaine
- Modifier `PRJ_CODESYS/PROJ_Full_ImportExport/Device.export`
- Élargir le scope au-delà de la tâche : signaler, ne pas décider
- Annoncer « terminé » sans les preuves ci-dessus

---

## Rôle du reviewer (revue read-only)

Vérifier **dans cet ordre** — l'intégration structurelle AVANT la logique métier, car c'est
l'inversion inverse qui a laissé passer le bug :

1. Liaison : instances déclarées/appelées au bon endroit, aucune orpheline, tâche cohérente
2. Contrat FB et nommage
3. Encapsulation : producteur unique, internes non traversés, pas de GVL-canal-caché
4. Logique métier et sécurité (états, temporisations, fronts)
5. Tests présents et exécutés

Verdict : `BLOCK` / `MAJOR` / `MINOR` / `PASS`, avec fichier:ligne et preuve. Aucune édition.
