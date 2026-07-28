---
name: codesys-change
description: Prépare et exécute une modification ciblée CODESYS en respectant les specs DOC, le scope, les gates et la validation humaine. Utiliser pour modifier CODE/ ou le programme automate.
---

# Modification CODESYS

1. Lire `TASK_CONTEXT`, `CODE_WRITING_POLICY.md`, `DOC_WRITING_POLICY.md` et les specs actives pertinentes.
2. Vérifier le scope avec `check_structure.py` et `check_code_style.py`.
3. Cartographier avant le plan : propriétaire de chaque donnée, producteur unique, interface publique,
   consommateurs et arbitrage des commandes. Refuser tout accès nouveau aux internes d’une instance,
   calcul dupliqué, canal GVL caché ou fusion anarchique de sources par `OR`.
4. Pour C3/C4, safety, SafeStop ou PowerCutOff : exiger un `TASK_CONTEXT` avec tests PLC automatiques, puis exécuter `check_task_test_contract.py <TASK_CONTEXT>` avant le plan. Une simulation manuelle seule ne ferme jamais l'acceptation.
5. Présenter un plan court si le besoin n'est pas déjà validé. Il décrit aussi les flux
   `producteur → interface → consommateurs`, les structures éventuelles et les fichiers de test,
   puis associe chaque critère d'acceptation à un test.
6. Modifier uniquement les fichiers autorisés. Toute nouvelle donnée dérivée est calculée une seule
   fois par l’objet propriétaire et exposée par une interface minimale ; les paramètres safety ne
   sont pas rendus réglables de l’extérieur sans exigence validée.
7. **Si au moins un fichier `CODE/**/*.st` a changé : générer obligatoirement `CODE/CODE_Bundle.xml`** via `TOOLS/ST_PLCOPENXML_GENERATOR` avant toute restitution. Ce n'est pas une option et il ne faut jamais proposer un import fichier-par-fichier.
8. Exécuter obligatoirement `check_bundle_freshness.py <project_root>` après génération ; un bundle absent ou stale bloque la restitution.
9. Pour C3/C4/safety, exécuter `check_task_test_contract.py <TASK_CONTEXT> --release`. Sans tests `implemented` et preuve d'exécution, le lot est **incomplet**, même si CODESYS compile.
10. Lancer les autres gates et signaler les limites.
11. Ne jamais committer sans validation utilisateur.

## Commande bundle obligatoire

Depuis la racine projet :

```powershell
python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .
```

Ce point d'entrée unique exécute le générateur puis `check_bundle_freshness.py`.

La réponse finale d'une tâche qui touche `CODE/` doit donner le chemin exact `CODE/CODE_Bundle.xml` et les résultats de ces deux validations.

Pour safety/normes/redondance : Ponytail interdit, review read-only obligatoire.
