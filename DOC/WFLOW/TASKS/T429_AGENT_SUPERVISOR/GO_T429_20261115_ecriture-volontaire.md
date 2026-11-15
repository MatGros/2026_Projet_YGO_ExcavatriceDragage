# GO T429 — 2026-11-15

- **Émetteur** : exploitant (message « GO j'ai d'autre truc à implémenter », réponse au pied « ➡️ Choix » du tour du 2026-11-15)
- **Portée du GO** : les 3 items proposés au pied :
  1. **M17/R19** — recette de dérive réelle avec agents Ollama : autorisation explicite de l'**écriture hors périmètre volontaire** (le garde doit la refuser ; le chemin et le contenu viennent de la sortie de l'agent Ollama)
  2. **M20/R22** — implémentation du constat mécanique `actor_conflict`
  3. **M18/R20** — commit du diff `upgrade_legacy.py` (livraison T000-CC10, vérifié CC01)
- **Point d'arrêt maintenu** : aucun push ; les poses deny-list, le restart et les visas restent des GO séparés de l'exploitant.
- Le canal : `GO <tâche> <réf. émetteur> <périmètre>` + copie datée au dossier de tâche (protocole T427 § échanges).
