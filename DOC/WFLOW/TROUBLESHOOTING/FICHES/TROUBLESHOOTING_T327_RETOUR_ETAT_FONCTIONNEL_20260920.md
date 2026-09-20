# T327 — Retour à un état fonctionnel (preuve terrain 2026-09-20)

## Statut

🟢 **Jalon terrain validé** : la régression qui interdisait la descente couplée en MAINT et
bloquait le cycle SEMI_AUTO en AX4 est levée dans la version essayée par Mathieu.

⚠️ Ce jalon ne clôt pas T327 : la latence avant activation de la benne en `WinchSel=0` reste
présente et doit être diagnostiquée séparément.

## Régression constatée

Le commit `73949276` avait élargi `ManualBucketLimitsActive` au-delà du JOG M2 unitaire en
remplaçant le verrou historique `JoystickWinchSelectArbitrated = 2` par une condition fondée
sur `NOT instBucket.Lifecycle.Busy`.

Avec `TglManualBucketLimits=TRUE` et la benne ouverte, la borne d'ouverture rendait
`ProcessPermitM2_Descend=FALSE`. Le couplage atomique M1/M2 propageait alors cette interdiction
aux deux treuils : descente impossible en MAINT couplé et cycle bloqué en AX4.

Preuves : snapshots `061037`, `061122`, `061219` et essai terrain où la désactivation temporaire
du toggle rétablissait immédiatement la descente.

## Modification ayant rétabli le fonctionnement

Le périmètre des bornes manuelles a été ramené au JOG M2 arbitré (`Arbitrated=2`) et exclut la
phase T248. La phase JOG T248 possède une borne séparée, alignée sur `CoherenceLimitM`, qui devient
caduque dès le retour de l'arbitrage à `0`.

Résultat terrain rapporté par Mathieu :

- ouverture de la benne puis plongée : **fonctionne de nouveau** ;
- MAINT/couplé et SEMI_AUTO AX4 : retour à un état d'exploitation correct ;
- le toggle IHM n'est plus utilisé comme contournement permanent.

## Réserves avant validation T327

- conserver l'exclusion `NOT instBucket.Lifecycle.Busy` afin que les bornes du JOG libre ne se
  superposent pas à un cycle géré par `instBucket` ;
- expliquer et traiter la latence observée avant activation de la benne en `WinchSel=0` : le
  handoff T248 contient déjà un arrêt volontaire de 300 ms, mais environ 1 s est observée ;
- fournir des tests comportementaux MAINT, AX4, T248 ouverture/fermeture et relâche joystick ;
- corriger le contrat T327, qui contient encore des variantes abandonnées (timeout/nouveau FB) ;
- régénérer bundle complet + diff bundle puis fournir G200 et gates sur le diff stabilisé.

## Anomalie AX12 — séparée de T327

L'arrêt anticipé M1 observé en AX12 correspond probablement à T291-B : passage individuel de M1
en P1 dans sa zone haute tandis que M2 reste en P5, puis neutralisation des deux demandes par
`WinchBothFinalRequestsCoherent`. Le FDC logiciel nominal M1 est `7.5 m` ; la valeur `0.0 m` est
la cible de référencement, pas le FDC de montée. Une capture AX12 fraîche reste nécessaire pour
confirmer ce diagnostic sur l'essai du 20/09.

## Décision orchestrateur

Le retour à l'état fonctionnel est mémorisé comme **jalon validé**, mais la livraison T327 reste
en revue tant que les réserves ci-dessus ne sont pas levées. Aucun élargissement vers un timeout,
un nouveau FB safety ou T329 n'est autorisé dans ce correctif minimal.
