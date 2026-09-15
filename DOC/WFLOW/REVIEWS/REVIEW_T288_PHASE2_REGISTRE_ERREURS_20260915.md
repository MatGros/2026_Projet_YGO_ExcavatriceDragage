# Revue T288 phase 2 — registre d'erreurs treuils

## Verdict

**MAJOR — pas pret a coder.** Recommandation : architecture B, avec un vrai registre
d'erreurs dedie aux treuils. L'extension globale de `ST_Fault/FB_FaultCore` est hors
proportion pour T288 : le socle est partage par au moins 32 consommateurs.

## Points bloquants

- `ErrorID:16` doit rester **absence de mouvement**, fondee sur la position codeur.
- La **discordance commande / retour contacteurs** doit avoir un identifiant et un texte distincts, sans garde codeur.
- Le retour est collectif : aucun message ne doit pretendre identifier direction, vitesse ou frein.
- Le cas incident peut produire simultanement deux causes ; elles ne doivent pas etre fusionnees.
- Le registre doit definir liveness, latch, Reset sur front, Enable, BypassGlobal, SafeStop et PowerCutOff.
- L'IHM doit afficher la discordance sans la conditionner a `EncM1Valid`/`EncM2Valid`.
- Le delai 3 s est conserve provisoirement ; toute reduction attend une mesure terrain.

## Consequence immediate

La modification precedente qui retirait `NOT FwdRevSpeedFeedbackOff` de `TonNoMovement`
ne peut pas etre consideree comme la solution finale T288. Elle devra etre annulee ou
reecrite dans le plan d'implementation afin de separer les deux causes.
