# T417 — Audit A/B du harnais et du workflow

## Test rapide effectué

`py -3.13 TOOLS/PLC_CSV_SNAPSHOT/codesys_console/T423_IHM/T423_remote_client.py`

Résultat : pas de réponse au ping. Aucun processus IDE CODESYS ni endpoint UDP local 29035 détecté. **Prérequis absent ; fonctionnement du pont non validé.** Aucune écriture PLC ni ouverture IDE dans cet audit.

## Conclusions des deux missions indépendantes

| Mission | Constat vérifiable | Action proposée |
|---|---|---|
| A — harnais | `T423_engine.py:98` accepte l'application primaire connectée sans qualifier copie/cible. PONG ne prouve que le serveur UDP. | Qualifier identité projet, Simulation IDE et session avant toute écriture. |
| A — erreurs | `safe_read` renvoie N/A ; le pont peut répondre OK avec cette valeur. Le parseur numérique T417 renvoie zéro sur erreur. | Retourner une erreur explicite ; une donnée illisible invalide le critère concerné. |
| A — commandes | Écriture sans relecture générale ; STOP ne restaure pas les commandes. | Confirmer par relecture et restaurer les commandes du scénario dans finally. |
| B — pilotage | Réutilisation et réexamen après deux essais déjà prescrits dans le plan, mais non matérialisés. | Compteur d'expériences non discriminantes et rappel non bloquant. |
| B — méthode | Choix libre de canal puis snapshot unique imposé dans troubleshooting ; pont non décrit. | Documenter le canal autorisé par le contexte et sa qualification. |
| B — conservation | Skill demande nettoyage ; AGENTS interdit suppression automatique. | Aligner la skill sur conservation et nettoyage humain explicite. |

## Modification minimale recommandée — non implémentée

1. Un verrou local au pont de simulation sur les écritures : copie/cible/session qualifiées. Ping et lectures disponibles.
2. Erreurs de lecture explicites ; aucune conversion silencieuse en zéro.
3. Relecture et restauration des commandes d'essai.
4. Deux rappels non bloquants : après deux essais non discriminants ; après chaque expérience pour mettre à jour le tableau courant.
5. Corriger les contradictions de la skill canonique ; ne pas dupliquer les règles dans AGENTS.

## Critère du prochain test court

Session IDE disponible : PING, identité de la copie/cible, lecture connue valide, lecture inexistante retournant une erreur explicite. Les quatre doivent réussir avant un scénario de mouvement. Le pont actuel ne possède pas encore toute cette qualification.

Workflow de cet audit : skill projet troubleshooting ; missions A/B en lecture seule. Aucun hook global ajouté, aucun commit.
