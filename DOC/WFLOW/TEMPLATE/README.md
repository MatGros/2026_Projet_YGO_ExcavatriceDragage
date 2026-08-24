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
  `troubleshooting`, `codesys-workflow` et le briefing session `AGENTS.md`.
