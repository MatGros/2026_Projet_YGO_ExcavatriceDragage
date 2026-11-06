# POC AGY — livraison vers une session interactive active

## Contrat défini avant l'essai

Créer une nouvelle conversation AGY synthétique dans un dossier temporaire isolé, puis l'ouvrir en mode interactif. Pendant que ce processus est encore actif, essayer une reprise non interactive par son identifiant pour délivrer un marqueur synthétique unique. Une livraison dans la fenêtre interactive n'est établie que si l'interface active affiche elle-même le marqueur ou sa réponse après l'envoi. Une réponse obtenue seulement par la seconde instance démontre une reprise distincte, pas la réception dans la fenêtre active.

Le test utilise la sandbox et le mode plan, demande de ne lancer aucun outil, ne cible aucune conversation utilisateur et ne supprime aucun artefact. Conserver l'identifiant, les commandes, les codes de sortie, les réponses et les limites. Ne pas utiliser la méthode de saisie dans une fenêtre dont le focus est inconnu. Un échec de quota ou de disponibilité est classé indéterminé.

## Commande initiale

Depuis la racine du dépôt : `python -B TOOLS/AGENT_SUPERVISOR/poc/agy_actif/create_session.py`. Cette commande envoie un prompt synthétique au fournisseur, crée une nouvelle session et conserve sa trace. Les étapes interactives sont distinctes ; aucune autre conversation ne doit être ciblée.

## Résultat du 5 novembre 2026

La création a réussi : voir `creation_b84c6b1904a341b4be7ac218bd9d4304.json` (UUID nouveau, réponse `PRET`, code 0). L'ouverture interactive de cette même session dans son dossier temporaire a présenté un écran de confiance avant toute conversation. L'écran demande l'autorisation de lire, modifier et exécuter les fichiers de ce dossier. Aucun choix de confiance n'a été donné ; le processus a été arrêté proprement avec deux Ctrl+C, code 0. L'extrait de sortie est conservé dans `terminal_observation.txt`.

**Verdict : indéterminé.** Aucun marqueur n'a été envoyé dans une session interactive et aucune réception dans une fenêtre ouverte n'a été démontrée. L'option CLI `--conversation` documente une reprise, pas une mise en file dans une interface active. La décision de faire confiance au nouveau dossier n'a pas été prise lors de ce POC ; on ne sait pas si elle modifie un réglage persistant. Le préflight prouve seulement la création non interactive, pas la livraison interactive. Durée de création : 40,468 s ; l'usage retourné par AGY figure dans la preuve JSON, sans déduction de coût facturé.

## Essai complémentaire dans le dépôt déjà approuvé

À la demande du coordinateur, la même session synthétique a été ouverte en terminal interactif depuis le dépôt déjà approuvé, sans accepter de nouveau dialogue de confiance. Elle affichait `PRET` et restait ouverte. Depuis le dossier temporaire, `send_probe.py` a alors repris le même UUID en mode non interactif et demandé de répéter le marqueur synthétique. La seconde instance a répondu exactement au marqueur, avec code 0 et le même UUID ; preuve complète : `send_b184ec9702c7461f9f882fa61a680235.json`.

La fenêtre interactive est restée ouverte pendant l'appel et au moins cinq secondes après sa fin. Ses lectures de sortie successives étaient vides : aucun marqueur, réponse ou nouveau tour n'y a été affiché durant cette observation. Deux Ctrl+C l'ont fermée proprement, code 0. L'extrait final et les observations sont dans `terminal_observation.txt`.

**Conclusion limitée :** la reprise non interactive ciblée a fonctionné, mais elle n'a pas produit de mise à jour visible spontanée dans la fenêtre interactive observée. Cela ne démontre pas l'impossibilité d'autres mécanismes ni le comportement après un rafraîchissement ou une nouvelle action dans cette fenêtre. La réponse JSON ne suffit pas à certifier l'absence de tous les appels d'outils côté AGY ; le mode plan/sandbox et l'invite les interdisaient.

Un avertissement préexistant de la CLI signale une règle de permission `unsandboxed(python)` invalide dans sa configuration ; elle est ignorée par la CLI. Aucune configuration n'a été modifiée par cet essai.
