# POC AGY — disponibilité et ciblage de sessions synthétiques

## Contrat avant essai

Objectif : déterminer si deux nouvelles sessions AGY peuvent être identifiées et reprises séparément. Si leur création réussit, un marqueur synthétique est transmis uniquement à A ; une question identique à A et B doit faire citer le marqueur par A et répondre `AUCUNE` par B. Le retour doit identifier la session visée ; les sorties brutes sont conservées.

L'essai initial vérifie d'abord la disponibilité d'AGY. En cas de quota épuisé, d'erreur d'authentification ou d'indisponibilité, il s'arrête après un appel : le routage est alors **indéterminé**, pas échoué fonctionnellement. Aucune session existante n'est reprise, aucun message n'est envoyé à une personne. L'essai se déroule dans un dossier temporaire hors dépôt, en mode plan avec sandbox, avec instruction explicite de n'utiliser aucun outil.

Commande depuis la racine du dépôt :

```powershell
python -B TOOLS/AGENT_SUPERVISOR/poc/agy_routage/preflight.py
```

Chaque lancement écrit une preuve JSON unique à côté du script et conserve son dossier temporaire. Le CLI et ses services peuvent créer leurs propres traces de session. Le préflight consomme au plus un appel distant. Si la disponibilité est confirmée, une deuxième étape devra identifier formellement les sessions neuves avant tout envoi ciblé ; elle n'est pas supposée acquise par ce script.

## Résultat du 5 novembre 2026

Le préflight `preflight_e0afb6eb9c7d4f569ec6e147df5e90ec.json` a créé la session synthétique A et reçu `PRET`. Le CLI a signalé que `--mode plan` est sans effet avec `--disable-slash-commands` ; les appels suivants ont conservé `--mode plan` et `--sandbox` sans ce dernier paramètre. Aucun outil n'a été demandé dans l'invite ; les réponses JSON ne constituent pas à elles seules un journal détaillé d'appels d'outils.

Ensuite `probe.py` a créé une session synthétique B distincte, repris A avec le marqueur `POC_ALERTE_8B1BFC44EBE9`, puis interrogé les deux. Les quatre sorties et leur identité de conversation sont conservées dans `evidence_5fa43bf4e0a54d8199b372a90121f1e5.json` : `create_B` → `PRET`, `send_A` → `RECU`, `query_A` → marqueur exact, `query_B` → `AUCUNE`. Tous les codes retour sont 0 et les UUID retournés sont ceux visés. Les cinq appels ont pris environ 204 secondes au total. Les compteurs d'utilisation exacts sont dans chaque JSON ; ils ne sont pas un prix facturé.

Rejeu : créer d'abord un **nouveau** préflight, puis passer le chemin JSON qu'il affiche à `python -B TOOLS/AGENT_SUPERVISOR/poc/agy_routage/probe.py <nouveau-preflight.json>`. Cela crée deux nouvelles sessions et transmet des données synthétiques au fournisseur ; les sessions et fichiers temporaires sont conservés. Ne pas réutiliser un ancien préflight : cela reprendrait une session déjà utilisée par un essai antérieur.

Ce résultat démontre une reprise ciblée par UUID en mode non interactif, avec isolation sur ces deux sessions de test. Il ne démontre pas l'injection dans une interface déjà active, une file d'attente ni une intégration au Veilleur.
