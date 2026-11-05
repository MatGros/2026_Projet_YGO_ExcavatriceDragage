# Veilleur — rapport courant

## État au 4 novembre 2026

| Phase | Preuve | Résultat / limite |
|---|---|---|
| J0 — Référence | État Git initial et revues indépendantes | Modifications préexistantes conservées ; aucun nettoyage. |
| J1 — Service | Tests de verrou, accès local, port occupé et relais Task Manager | Réussis sur processus isolés. Service utilisateur v2 actif sur `127.0.0.1:8082`. |
| J2 — Affectation et interface | Tests DOM de l'interface servie, ID absent/ambigu, collage invalide | Réussis en simulation DOM. Revue visuelle navigateur non réalisée : accès à la fenêtre refusé par l'environnement. |
| J3 — Mémoire et alertes | Tests de citations, reprise, isolation, pivots et résultats périmés | Réussis avec juges simulés. Le sens d'une alerte reste à vérifier humainement. |
| J4 — Scénarios synthétiques | `tests/run_scenarios.py --model qwen3:8b` | Dernier passage : 6 résultats attendus sur 7 et 1 indéterminé. Cela ne mesure pas une fiabilité générale. |
| J4 — Claude réel | `tests/run_claude_live.py`, session synthétique explicite | Lecture active, réponse détectée, aucune alerte injustifiée ; 18,36 s de bout en bout. Un seul scénario réel. |

La dernière campagne automatisée regroupée a donné **82 tests réussis**. Le modèle réel
et les scénarios à juge simulé sont distingués ci-dessus. Une première exécution du
modèle réel avait détecté l'absence de preuve avec une citation inexacte ; elle était
refusée par le service. Une seule nouvelle tentative de citation a été ajoutée, sans
convertir automatiquement une alerte non citée en absence d'anomalie.

## Coût mesuré de l'intégrité

Sur des fichiers JSONL synthétiques, lectures du préfixe après mise en cache : environ
1,1 ms pour 1 Mo, 9,3 ms pour 10 Mo et 51 ms pour 50 Mo. Ces chiffres dépendent de la
machine et du stockage. Le contrôle d'intégrité complet reste actif.

## Réserves et suite

- La conversation CC-T217 a été retrouvée par correspondance avec le bloc exact fourni
  par l'utilisateur puis suivie. Un extrait partiel a été vérifié et des alertes ont été
  produites. Elle n'était plus affectée à la dernière relance ; la cause reste à confirmer.
  Une sauvegarde antérieure de ses données existe ; aucune restauration n'a été imposée.
- Le service utilisateur actuellement actif charge la version indiquée par `/health`.
  Une modification du code après son lancement nécessite un redémarrage du Veilleur.
- L'historique d'une session se lit à la demande ; la collecte temps réel commence à
  l'attachement. Le chat par carte s'adresse au Veilleur, jamais automatiquement à
  l'agent observé. La destination d'un éventuel envoi direct reste à clarifier.
- Une vue locale de la dernière requête tentée vers Ollama, y compris messages et
  consigne système, est implémentée et testée. La précédente version ne permet pas de
  reconstituer exactement les requêtes antérieures à son installation.
- Le chat de l'ancien service a été sauvegardé avant migration ; l'instantané au moment
  de l'opération contenait zéro message. La sauvegarde est conservée dans
  `%LOCALAPPDATA%/ExcavatriceDragage/supervision-backups/`.
- Les changements préexistants hors périmètre restent présents, notamment dans les
  gates et les documents de pilotage. Aucun commit ni push n'a été fait.
