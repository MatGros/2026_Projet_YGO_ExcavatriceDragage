# POC — alerte dans une session Codex interactive ouverte

## Protocole et critères fixés avant essai

1. Créer dans le répertoire temporaire système une **nouvelle** session synthétique Codex en lecture seule, dont l'UUID est extrait de l'événement JSON `thread.started`. L'invite demande uniquement `PRET` et interdit tout outil.
2. Reprendre cet UUID dans le terminal interactif Codex et confirmer que le processus demeure actif ; ne pas utiliser de session préexistante de l'utilisateur.
3. Envoyer au même UUID une seule alerte synthétique portant un marqueur unique par `codex queue --thread <UUID> --message <texte>`. Observer la sortie de la commande et la session interactive sans envoyer manuellement le marqueur dans le terminal.
4. **Livraison prouvée** seulement si un événement ou une réponse de la session active cite le marqueur et que l'identité de la session est établie. Un succès de `queue` seul est insuffisant. Un échec, délai dépassé ou observation inaccessible reste un résultat distinct, sans nouvelle tentative automatique.

Les sorties brutes, heures et limites sont conservées sous ce dossier. L'essai peut consommer des tokens Codex et crée une session et un répertoire temporaires qui ne sont pas supprimés. Il ne valide ni Claude ni AGY.

Pour créer la session : `python -B TOOLS/AGENT_SUPERVISOR/poc/routage_actif/create_session.py`. Les étapes interactives sont réalisées par le terminal de l'orchestrateur et leurs résultats sont conservés séparément.

## Résultat du 5 novembre 2026

La création `creation_1db814f64e7643d9aff2e5791177b982.json` donne la session synthétique `01a1a9c8-0743-7550-9cd0-3668d3ecde62` et `PRET`. Cette session a ensuite été ouverte en terminal interactif (`codex resume --no-alt-screen -s read-only <UUID>`), où son historique et le prompt disponible étaient visibles.

À 03:37:48.639 UTC, `codex queue --thread <UUID> --message <alerte synthétique>` a répondu avec le même UUID et le code 0, **sans option `--resume`**. Dans le terminal interactif resté ouvert, le message est apparu et Codex a lancé un nouveau tour puis répondu `POC_ALERTE_ACTIF_8D145B17`. Le fichier `pty_evidence_1db814f64e7643d9aff2e5791177b982.json` conserve les captures brutes et leur état ; la capture après l'envoi est partiellement tronquée par la limite de sortie du terminal, mais la réponse complète est visible vers sa fin.

La preuve indépendante `transcript_evidence_1db814f64e7643d9aff2e5791177b982.json` provient uniquement du transcript de cet UUID synthétique : message utilisateur à 03:37:50.521 UTC, réponse assistant exacte à 03:37:52.238 UTC, même thread et même tour. Elle est vérifiable tant que le transcript synthétique existe par :

```powershell
python -B TOOLS/AGENT_SUPERVISOR/poc/routage_actif/validate_transcript.py 01a1a9c8-0743-7550-9cd0-3668d3ecde62 POC_ALERTE_ACTIF_8D145B17
```

Verdict : livraison et réponse prouvées dans **une session Codex interactive déjà ouverte**, sur un essai synthétique. La mise en file a déclenché un nouveau tour automatiquement : une intégration devra tenir compte de cet effet. Cela ne prouve ni Claude/AGY, ni le comportement pendant un tour déjà en cours, ni déduplication ou autorisations côté Veilleur.

Une fois la preuve capturée et le tour terminé, le terminal synthétique a été fermé par Ctrl+C, avec un code de sortie 0. Le CLI a signalé sa déconnexion ; la session, son transcript et les preuves restent conservés.
