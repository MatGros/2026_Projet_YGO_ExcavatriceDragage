# POC : reprise Claude pendant une session interactive active

## Contrat fixé avant l'essai

Créer une session Claude synthétique neuve dans le répertoire temporaire système, en lecture seule avec outils désactivés. Ouvrir cette session dans un terminal interactif, puis exécuter une seule reprise non interactive ciblant le même UUID et transmettant un marqueur synthétique. Attendu : distinguer le retour de la reprise de l'affichage et de la réception réelle dans le terminal déjà ouvert. Un succès du nouveau processus ne démontre pas à lui seul l'injection dans le terminal initial ; création d'une copie, identité différente, absence de preuve, délai dépassé et erreur sont consignés séparément. Aucune session préexistante utilisateur ne doit être visée.

Les commandes, sorties et éventuels transcripts portent exclusivement sur cette session d'essai. Les sessions et dossiers temporaires sont conservés. Aucun fichier du produit, catalogue ou configuration n'est modifié.

## Résultat : indéterminé

La création non interactive a réussi : preuve `creation_4e3b2e097c974463b031c5a111209b3e.json`, identifiant synthétique `97593465-800a-4352-bece-caa4f68dc0bf`. La reprise interactive, lancée dans le même dossier temporaire, a affiché un dialogue demandant de déclarer ce dossier fiable. Le choix par défaut « No, exit » a été confirmé afin de respecter l'interdiction de modifier les configurations. Le processus s'est terminé avec le code 1 ; aucun marqueur n'a été envoyé. Détail : `evidence_trust_gate.json`.

Ce résultat ne permet pas de conclure sur l'envoi dans une fenêtre Claude déjà ouverte. L'aide locale documente `--resume`, mais ne documente pas une commande équivalente à `codex queue` ; absence de mention dans l'aide n'est pas une preuve d'impossibilité. Les sorties de création ont été enregistrées par `python -B TOOLS/AGENT_SUPERVISOR/poc/claude_actif/create_session.py`. L'étape interactive nécessite un terminal ; elle n'est pas automatisée par ce script.

La capture brute de la sortie interactive n'a pas été enregistrée dans un fichier : `evidence_trust_gate.json` est une transcription synthétisée de l'observation, et non une trace brute rejouable. La preuve de création contient les sorties brutes de l'étape non interactive.

## Essai complémentaire dans le dépôt déjà approuvé

À la demande du responsable, la même session synthétique a été reprise en TUI depuis le dépôt avec `--tools ' ' --setting-sources user --strict-mcp-config`. Aucun dialogue de confiance n'est apparu et la TUI a affiché l'échange initial `PRET`. Pendant qu'elle restait ouverte, `concurrent_resume.py` a lancé une reprise non interactive avec le marqueur `POC_ALERTE_ACTIF_8C69612A87`. La réponse JSON brute de ce second processus, conservée dans `concurrent_a1d2c1df03964e93b10e945bf8a76a75.json`, retourne le même UUID et le marqueur exact.

Deux lectures successives de la sortie du terminal initial pendant environ dix secondes n'ont retourné aucun nouvel affichage. La TUI a été fermée par Ctrl+C sans lui transmettre de message. Cette observation, issue des sorties du terminal d'orchestration et non enregistrée en capture brute ici, ne permet pas de prouver une propagation à la TUI ; elle ne démontre pas non plus que cette propagation serait impossible. La reprise non interactive a exécuté un nouveau tour distinct. Le CLI peut écrire ses propres traces de session ; aucune modification de configuration n'a été demandée ni aucun dialogue de confiance accepté pendant cet essai.

## Rejeu avec capture brute du terminal

Une nouvelle session synthétique `37f8630e-59e5-4a25-988f-bbe9559d44ae` a été créée avec `create_session.py`. La TUI ouverte depuis le dépôt a affiché l'échange initial sans dialogue de confiance. Pendant qu'elle restait active, `concurrent_resume.py <preuve-de-création>` a envoyé le marqueur à une reprise non interactive du même UUID ; sa réponse exacte et son UUID sont conservés dans `concurrent_bb9b2dea9ea244be9d8e48f1f0db48c9.json`.

La sortie brute de la TUI avant, pendant et après l'appel ainsi que les heures de lecture et le code de fermeture 0 sont conservés dans `pty_evidence_dcad13b6.json`. Le marqueur n'apparaît dans aucune trame de la TUI recueillie entre 03:45:20 et 03:46:26 UTC ; les lectures après réponse sont vides. La TUI a été fermée proprement par Ctrl+C. Ce résultat établit l'absence d'affichage du marqueur **dans cette fenêtre et pour cette méthode de reprise** : il ne prouve pas qu'une autre interface d'injection soit impossible. La capture est la sortie du terminal, pas une capture de pixels.
