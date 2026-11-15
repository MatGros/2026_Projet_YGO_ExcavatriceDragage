# Politique des alertes du Superviseur (proposition à challenger)

Statut : proposition. Aucun code n'est modifié.

## Règle

- Warning : information. L'agent est prévenu d'une ligne, sans blocage. Il décide lui-même de prioriser ou non, selon ce qui se passe sur le moment.
- Alarm (rouge) : signal fort de risque. L'agent doit arrêter le plus possible les actions à risque, expliquer l'écart, et attendre une décision humaine pour clore. Ce n'est pas un blocage mécanique aveugle : le jugement reste à l'agent, et l'humain tranche.

## Ce qui est proposé

1. Warning : une ligne d'information au tour suivant (hook UserPromptSubmit), sans empêcher l'action.
2. Alarm : une ligne plus visible, plus une consigne d'arrêt des écritures à risque (Edit, Write, MultiEdit, Bash mutant), avec le motif. La lecture reste permise.
3. Pas d'interrupteur global dans l'interface avant les mesures (latence, taux de faux positifs).

## Ce qui n'est pas réglé

- Le blocage mécanique (code 2) n'est pas retenu : un faux positif bloquerait du travail légitime.
- Les agents sans hook (Codex, AGY, Ollama) ne sont pas couverts.
- Qui clôt une alarme : l'humain, uniquement.

## Mesures avant décision

- Latence réelle du hook vers le Superviseur, sur la machine cible.
- Taux de faux positifs des alarmes, sur un échantillon.
- Part des écritures réellement arrêtées après une alarme, par CLI.
