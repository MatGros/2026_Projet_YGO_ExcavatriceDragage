# T419 — Benne SimBench : roulis d’ouverture M2

Statut : plan autorisé par l'utilisateur le 2026-10-15. Checkpoint préalable : `f4db569d`.

## Faits mesurés — trace Suivi_94

`Suivi_94` couvre AX6 à AX18. En AX14, M1=7,8547 m, M2=22,7925 m,
Delta=14,9377 m et ouverture=0,415 % : la benne reste fermée après AX10.
En AX15B (step 16), M2 descend seul. Le cycle passe à AX18 lorsque Delta
atteint environ 1,264 m (91,6 %). Après roulis, la mesure se stabilise à
Delta≈1,004 m (93,31 %), juste hors de la bande ouverte de 1,0 m.

## Cause établie par le rapprochement code / trace

`FB_Bucket` coupe l'ouverture à `OffsetOpenM + OpenAnticipationM` (1,3 m par
défaut), puis publie `Done`/`IsOpen`. Le cycle peut alors passer à AX18. Le
modèle `FB_Sim_Encoder` prolonge ensuite le mouvement selon `CoastDistanceM`;
le profil courant M2 utilise environ 0,26–0,35 m, pas les 1,3 m d'anticipation.
Suivi_94 confirme que la benne reste autour de 1,0 m d'écart au repos.

Le défaut démontré est donc le roulis simulé trop court après la coupure
anticipée. L'hypothèse de perte AX10→AX14 est réfutée par cette trace. Le
rattrapage accumulé peut être grand en général, mais n'explique pas cette
séquence fermée puis ouverte; le relevé Suivi_94 ne contient pas ses variables
internes, donc il ne permet pas d'en évaluer la contribution scan par scan.

## Correction prévue — SimBench uniquement

Pendant l'étape AX15B avec ouverture M2 seule, le SimBench arme le roulis
quand l'écart atteint `OffsetOpenM + OpenAnticipationM`. Il transmet alors au
codeur le plus petit de l'anticipation configurée et de l'écart restant vers la
butée ouverte : l'ouverture atteint sa cible sans la dépasser. Un jog manuel,
un arrêt automatique avant cette zone, M1, montée M2, descente couplée, roulis
général et accumulation de couplage gardent leur profil actuel. Le déclencheur
est l'étape publique AX15B (pas le ReqOpen partagé avec le homing) et la mesure
M2 utilisée en P02 est avancée du déplacement correspondant à un scan pour
compenser le retard d'acquisition. Aucun état brut n'est forcé.

## Hors périmètre

`FB_CycleSemiAuto`, `FB_Bucket`, `FB_Joystick`, homing et réglages persistants
restent inchangés. `PRG_02_Acquisition` ne reçoit qu'un raccordement en entrée
du FB simulateur.
