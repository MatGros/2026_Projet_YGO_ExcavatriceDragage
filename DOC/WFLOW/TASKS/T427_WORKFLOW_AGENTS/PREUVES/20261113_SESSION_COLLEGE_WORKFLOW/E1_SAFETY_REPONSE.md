**Garanties perdues de l'ancien workflow — classement (§A/§C)**

1. **GARDER** — Arrêt obligatoire de validation humaine avant écriture code [FAIT §A.4] : tampon humain irremplaçable sur logique de commande sécurité (validation indépendante, ISO 13849).
2. **GARDER (à durcir)** — Gates bloquantes (G200, 21 Gates) [FAIT §A.4] : encore réelles pour Claude uniquement ; Bash non couvert, Codex/Antigravity sans hook, `--no-verify` contourne pre-commit [FAIT §D] ⇒ garantie à porter dans un pre-commit git commun, agent-agnostique.
3. **GARDER (forme mécanique)** — Preuve de lecture des piliers STDS/AF/TOOLS [FAIT §A.3] : l'utilisateur constate que les agents ne lisent plus au démarrage [FAIT §F] ; mais fail-closed naïf est traversable (@import invisible comme Read, transcript illisible laisse passer) [FAIT §D/§E].
4. **GARDER** — Protocole obligatoire avant toute écriture TASKS.yaml, supprimé [FAIT §C] : risque d'écrasement concurrent sur 150 tâches ouvertes [FAIT §D] ; déjà repris côté délégation, à réclamer dans task-planner.
5. **FUSIONNER** — Procédure troubleshooting (contexte figé, arbre des causes, SNAPSHOT, test CI ad hoc) retirée, destination réelle non vérifiée [FAIT §C] : restaurer dans la SKILL canonique après vérification de `prompts/troubleshooting.md`.
6. **FUSIONNER** — Suppression de « l'agent DOIT interpeller » [FAIT §C] : sans question seulement si action réellement locale et réversible ; question obligatoire dès que CODE/, catalogue ou périmètre sous contrat — sinon la notion de « réversible » devient un passe-droit.
7. **GARDER** — Anti-récitation : justification par règle citée (NC-xxx, sémantique Req→Tgt→Cmd→Act) [FAIT §A.5] : traçabilité des choix sur code machine.
8. **ABANDONNER** — Bannière rituelle, résumé des skills, snapshot, menu 4 options [FAIT §A.0-6] : coût tokens documenté [FAIT §F], aucune garantie mécanique (aucun hook de démarrage n'a jamais existé [FAIT §D]) ; rituel ≠ contrôle.
9. **GARDER (règle ancienne)** — Délégation Ollama passée « sur demande explicite » → « par défaut » [FAIT §C] : rétablir la demande explicite, la délégation par défaut retire le contrôle humain en amont.
10. **FUSIONNER** — Traçabilité orchestration : perte d'affectation T427, session parasite T000-CC10, /rename-session défaillant [FAIT §D] : conserver un registre par ID natif de session (§E), abandonner les commandes manuelles.

**DÉCISION :** Invariants à rétablir : arrêt humain pré-code, gates bloquantes relogées en pre-commit commun, preuve de lecture mécanique corrigée (fail-closed sans passe-droit), protocole TASKS.yaml, seuil de question hors zone réversible, délégation sur demande explicite.
Abandonner le rituel de briefing (bannière/menu, zéro garantie mécanique) ; fusionner la méthode troubleshooting et le registre ID natif dans les SKILL canoniques.
Prérequis : vérifier où est passée la procédure troubleshooting [FAIT §C] avant toute considération de suppression.