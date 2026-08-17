---
name: codesys-change
description: Prépare et exécute une modification ciblée CODESYS en respectant les specs DOC, le scope, les gates et la validation humaine. Utiliser pour modifier CODE/ ou le programme automate.
---

# Modification CODESYS

1. Lire `TASK_CONTEXT`, `CODE_WRITING_POLICY.md`, `DOC_WRITING_POLICY.md` et les specs actives pertinentes.
2. Vérifier le scope avec `G300_check_structure.py` et `G100_check_code_style.py`.
3. Cartographier avant le plan : propriétaire de chaque donnée, producteur unique, interface publique,
   consommateurs et arbitrage des commandes. Refuser tout accès nouveau aux internes d’une instance,
   calcul dupliqué, canal GVL caché ou fusion anarchique de sources par `OR`.
4. Pour C3/C4, safety, SafeStop ou PowerCutOff : exiger un `TASK_CONTEXT` avec `human_validation_required: true` et des critères d'acceptation vérifiables. Test PLC automatique optionnel (décision 2026-08-01, plus d'obligation) — si déclaré (`tests_automated_required: true`), exécuter `check_task_test_contract.py <TASK_CONTEXT>` avant le plan pour le tenir à sa parole.
5. Pour C3 et C4, collecter avant le plan les avis read-only exigés par
   `docs/MODEL_ROUTING.md` via Pi Subagents, puis en synthétiser les accords, divergences et
   risques. Les sous-agents ne modifient ni ne commitent.
6. Présenter un plan court : flux `producteur → interface → consommateurs`, structures
   éventuelles, fichiers de test et correspondance critères d'acceptation → tests. **Arrêt
   obligatoire : attendre la validation explicite de l'utilisateur avant toute écriture CODE/DOC.**
7. Modifier uniquement les fichiers autorisés. Toute nouvelle donnée dérivée est calculée une seule
   fois par l’objet propriétaire et exposée par une interface minimale ; les paramètres safety ne
   sont pas rendus réglables de l’extérieur sans exigence validée. Vérifier avant toute écriture si
   un POU XML natif/CFC est concerné et préserver la cohérence des noms, interfaces et références
   avec les sources ST.
8. **Si au moins un fichier `CODE/**/*.st` a changé : générer obligatoirement `CODE_XML/CODE_Bundle.xml`** via `TOOLS/ST_PLCOPENXML_GENERATOR` avant toute restitution. Ce n'est pas une option et il ne faut jamais proposer un import fichier-par-fichier. Si un POU XML natif/CFC est concerné, le conserver comme source métier et ne jamais éditer le XML final du bundle à la main.
9. Exécuter obligatoirement `G390_check_bundle_freshness.py <project_root>` après génération ; un bundle absent ou stale bloque la restitution.
10. Pour C3/C4/safety, la validation humaine (Watch/forçage CODESYS avant chargement) est obligatoire, même si CODESYS compile. Si un test PLC automatique a été déclaré (`tests_automated_required: true`), exécuter aussi `check_task_test_contract.py <TASK_CONTEXT> --release` — sans `implemented` + preuve d'exécution, le lot reste **incomplet**.
11. Si ST2PY est utilisé pour la simulation ou la non-régression, le rapporter comme outil hors-PLC complémentaire ; il ne remplace pas la validation CODESYS ni les essais terrain.
12. Lancer les autres gates et signaler les limites.
13. Ne jamais committer sans validation utilisateur.

## Commande bundle obligatoire

Depuis la racine projet :

```powershell
python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .
```

Ce point d'entrée unique exécute le générateur puis `check_bundle_freshness.py`.

La réponse finale d'une tâche qui touche `CODE/` doit donner le chemin exact `CODE_XML/CODE_Bundle.xml` et les résultats de ces deux validations.

Pour safety/normes/redondance : Ponytail interdit, review read-only obligatoire.
