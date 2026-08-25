# 🗂️ DOC/WFLOW/TEMPLATE — Gabarits & standards projet

> Décision **T150-G (2026-08-24)** : les **gabarits de projet** (et non les gabarits d'outillage
> d'agent) vivent ici, sous `DOC/WFLOW/`, rattachés au pilotage projet — **pas** dans
> `TOOLS/AGENT_WORKFLOW/templates/`.

## 📌 Règle de placement (anti-doublon)

| Contenu | Où il vit |
|---|---|
| **Gabarits / standards projet** (en-têtes ST `fb_header`, spec AF, bannière skill, fiche...) | **`DOC/WFLOW/TEMPLATE/`** ou `DOC/STDS/` |
| **Gabarits d'outillage d'agent** (task_contract, structure de gate, README d'outil) | `TOOLS/AGENT_WORKFLOW/templates/` |
| **Méthodes de skill** (source unique) | `TOOLS/AGENT_WORKFLOW/skills/<skill>/SKILL.md` |
| **Déclencheurs de skill** (stub court) | `.claude/skills/<skill>/SKILL.md` · `.dsh/skills/<skill>/SKILL.md` |

Règle d'or : **un gabarit/standard s'écrit une seule fois** et est référencé, jamais dupliqué
(cf. `AGENTS.md` — une règle écrite deux fois dérive toujours).

## 📛 Contenu

- [`SKILL_BANNER_TEMPLATE.md`](SKILL_BANNER_TEMPLATE.md) — **gabarit unique** des bannières de
  déclenchement (format 60 `=`, émoji + titre, 1 ligne d'action). Appliqué par `task-planner`,
  `troubleshooting` et le briefing session `AGENTS.md`.
- [`AF_SPEC_TEMPLATE.md`](AF_SPEC_TEMPLATE.md) — squelette de fiche AF (famille Fonctions métier,
  08+), conforme à `DOC/STDS/GUIDES/GUIDE_EDITION_AF_v1.0.md`.
- [`FB_HEADER_TEMPLATE.st`](FB_HEADER_TEMPLATE.st), [`GVL_HEADER_TEMPLATE.st`](GVL_HEADER_TEMPLATE.st),
  [`MOTION_FB_HEADER_TEMPLATE.st`](MOTION_FB_HEADER_TEMPLATE.st),
  [`PROGRAM_HEADER_TEMPLATE.st`](PROGRAM_HEADER_TEMPLATE.st),
  [`TYPE_HEADER_TEMPLATE.st`](TYPE_HEADER_TEMPLATE.st) — cartouches d'en-tête standard `CODE/*.st`
  par type de composant (`FUNCTION_BLOCK`, GVL, FB de mouvement, `PRG_`, `TYPE`).

📌 **Migration T150-H (2026-08-25)** : ces 6 fichiers vivaient dans
`TOOLS/AGENT_WORKFLOW/templates/` — reliquat de la migration `T150-G` (2026-08-24), qui n'avait en
réalité déplacé que `SKILL_BANNER_TEMPLATE.md` malgré sa propre règle de placement. Renommés en
`NOM_TEMPLATE.ext` pour homogénéité.
