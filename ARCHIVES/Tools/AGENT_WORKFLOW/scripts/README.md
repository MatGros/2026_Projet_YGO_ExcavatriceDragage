# Scripts archivés

## `G220_check_model_routing.py` — archivé 2026-08-17

Lisait `.pi-subagents/artifacts/*_meta.json` (modèle réellement exécuté par Pi Subagents) pour
vérifier qu'un rôle de jugement (`reviewer`/`oracle`/`worker`) n'utilisait pas un modèle rapide.

Abandonné avec Pi/Herdr (2026-08-17) : `.pi-subagents/artifacts/` n'existe plus, le gate tournait
déjà en silence (`PASS (aucun artefact à analyser)`, 0 contrôle réel) depuis l'arrêt de Pi.
Ni antigravity ni Codex ne déposent d'équivalent structuré (modèle/rôle exécuté) dans le dépôt.

Même décision que l'abandon du framework `PLC_TESTS` le 2026-07-26 (voir
`TOOLS/AGENT_WORKFLOW/docs/TASK_CONTEXT.md`) : pas de garde-fou de complaisance qui fait semblant
de vérifier. La garantie "modèle fort obligatoire en C4" repose désormais sur
`human_validation_required` + la double revue A/B (voir `docs/SAFETY_POLICY.md`,
`docs/MODEL_ROUTING.md`), tracée manuellement dans le `TASK_CONTEXT`, sans artefact automatique.

Si un futur outil (antigravity, Codex ou autre) dépose un jour un artefact structuré équivalent,
ce script est réutilisable comme base — sa logique de détection (famille rapide / effort réduit
sur un rôle de jugement) reste valide, seule la source de données (`.pi-subagents/`) est morte.
