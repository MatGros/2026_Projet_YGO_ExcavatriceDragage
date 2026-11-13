🟡 ADVISORY — Aucun mécanisme exécutable de lecture forcée au démarrage n’est établi avant 2026-11-03. Le seul garde-fou de lecture est conditionnel aux écritures dans `CODE/`.

FAITS (cités)
- `.claude/settings.json` : hooks PreToolUse (`hook_pre_edit.py`), PostToolUse (`hook_post_edit.py`), Stop (`hook_stop.py`). Aucun hook SessionStart ni UserPromptSubmit. Identique au 2026-08-01 et aujourd’hui.
- `git log -S 'SessionStart'` et `git log -S 'UserPromptSubmit'` : vides.
- `hook_pre_edit.py` : ne bloque que les écritures dans `CODE/` ; exige des Read de `CODE_QUALITY_STANDARDS.md`, `NAMING_CONVENTION.md` et `AF_Partie-NN` selon le dossier CODE. Transcript illisible => `return 0` (laisse passer).
- `hook_stop.py` et `hook_post_edit.py` : modifiés le 2026-08-24 et le 2026-08-30 ; contenu non lu.
- Commit `24a8e518` (2026-07-29) : message « docs(workflow): mise a jour du workflow agents, des hooks de verification et des garde-fous » ; contenu non lu.

RÉPONSE
1. Non : aucun mécanisme de lecture au démarrage n’est prouvé avant 2026-11-03.
2. Emplacement exact : aucun. Point le plus proche = `hook_pre_edit.py`, mais il agit à l’écriture, pas au démarrage. Trace historique possible = commit `24a8e518`, non vérifié.
3. Donc : aucun mécanisme de ce type n’est identifié dans les preuves fournies.

HYPOTHÈSES
- Le remplacement était probablement procédural (workflow agents/documentation), non exécutoire ; non prouvé.
- Les hooks et le commit non lus pourraient contenir une règle de lecture, mais pas un hook SessionStart/UserPromptSubmit ; leur existence ne prouve pas un forçage au démarrage.

LIMITE
- Les contenus non lus de `hook_stop.py`, `hook_post_edit.py` et `24a8e518` empêchent d’exclure formellement une règle cachée. Le verdict est « non prouvé », pas « inexistence absolue ».