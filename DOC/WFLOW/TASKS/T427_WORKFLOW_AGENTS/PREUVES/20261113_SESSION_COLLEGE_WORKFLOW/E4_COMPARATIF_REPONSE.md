**Comparaison par mécanisme**

1. Briefing intégral auto (§A) vs survol socle (§E) : l'ancien impose un inventaire systématique coûteux [FAIT §A, §F] ; le socle V2 fait ~51 Ko réels, pas 10 [FAIT §E] → **FUSIONNER** : survol léger par défaut, chargement étendu dès action code/contrat [HYPOTHÈSE].
2. Menu d'options à l'ouverture (§A pt.6) vs tri d'intention + 4 voies (§E) : menu récité inutilement [FAIT §C retrait] → **GARDER V2**, conditionné au besoin [HYPOTHÈSE].
3. Anti-récitation/justification NC-xxx + AF (§A pt.5), absent de V2 [FAIT §E muet dessus] : **GARDER ancien** (déclaratif) [HYPOTHÈSE].
4. Hooks Pre/PostToolUse et Stop bloquants (§D, existants et vérifiés) vs fail-closed V2 aux 4 défauts relevés (@import non vu, Bash contourne, fragilité transcript, sans TASK_ID) [FAIT §D, §E] : **GARDER ancien** ; fail-closed V2 = NOUVEAU seulement après correction du faux positif et couverture Bash [HYPOTHÈSE].
5. Contournements connus : Bash hors hook, `--no-verify`, sessions superviseur instables [FAIT §D] ; V2 ne les traite pas [FAIT §E] → **NOUVEAU** : contrôle pre-commit + pointeur d'identification requis [HYPOTHÈSE].
6. TASKS.yaml 725 Ko/231 tâches, résumé 17,7 Ko [FAIT §D] vs summary scripté sans fraîcheur garantie [FAIT §E] : **FUSIONNER** — génération scriptée avec horodatage vérifié avant usage [HYPOTHÈSE].
7. Superviseur par /rename-session (échec réel) vs pointeur par ID natif [FAIT §D, §E] : **GARDER V2**, mais hors `.agent/` (conflit règle T279) [FAIT §E].
8. Assouplissements 2026-11 (« la faire sans question », Ollama par défaut) [FAIT §C] vs questionnement si intention floue (§E) : **FUSIONNER** — agir sans question si local réversible, questionner si périmètre sous contrat ou machine réelle [HYPOTHÈSE].
9. Procédure troubleshooting étapes 0-4ter supprimée, déplacement non vérifié [FAIT §C] : **GARDER ancien** (restaurer la référence canonique) [HYPOTHÈSE].
10. Exemption sous-agent V2 sans marqueur détectable [FAIT §E] : **NOUVEAU** — identifiant de rôle transmis dans le brief de délégation (gabarit §Rôle) [HYPOTHÈSE].

**Socle commun installable (Claude, Codex, Antigravity, DSH)**

11. Vérifiable mécaniquement (à créer/installer) : (a) `check_workflow.py` en pre-commit git — socle lu + résumé frais contrôlés, unique verrou commun car seuls Claude a des hooks, DSH/Antigravity n'en ont aucun [FAIT §D, §E] ; (b) hook Claude consolidé : l'import @AGENTS.md compté comme lecture, G200/G340/Stop inchangés [FAIT §D, §E] ; (c) script de génération du résumé tâches avec horodatage exigé [FAIT §E, HYPOTHÈSE fraîcheur].
12. Déclaratif (non prouvable, aucun hook de démarrage n'a jamais existé) [FAIT §D] : tri d'intention flou/clair, aiguillage 4 voies, anti-récitation, interdiction d'essai machine réelle → à documenter en tête de `AGENTS.md`, lu nativement par Codex, injecté par CLAUDE.md pour Claude ; pour Antigravity/DSH, conformité non garantie [FAIT §D, HYPOTHÈSE].
13. Limite assumée du socle : tout ce qui n'est pas pre-commit/hook/script reste déclaratif ; ne pas promettre l'application sur CLI sans hook [HYPOTHÈSE, FAIT §D].

DÉCISION : **Fusionner** le briefing (survol léger + règles de questionnement + anti-récitation restaurée), **garder** les hooks Claude réels et le summary scripté avec fraîcheur contrôlée, **abandonner** le fail-closed V2 en l'état et le pointeur `.agent/`, **créer** le pre-commit `check_workflow.py` comme unique verrou multi-CLI. Le déclaratif vit en tête d' `AGENTS.md` ; tout surplus de bannière reste supprimé (§C). Vérifiabilité : 3 artefacts mécaniques ; le reste s'assume déclaratif.