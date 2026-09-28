# T408 — UDP natif dans la copie Control Win

## Ce que mesure ce POC

`PRG_TwinBenchNativeUdpMulti` est un ping UDP natif sans M3, SimBench ni E/S. Il
doit etre execute dans une **nouvelle tache 10 ms** de la copie TwinBench.
La mesure utilise le serveur echo `127.0.0.1:29031`.

## Import dans la copie uniquement

1. Ouvrir `TwinBench_ControlWin.project`, jamais le projet source.
2. Ajouter ces bibliotheques systeme dans le Library Manager : **SysSocket**
   et **SysTypes2 Interfaces**. `CmpErrors2 Interfaces` peut rester installee,
   mais n est pas necessaire au POC.
3. Ajouter un objet Program ST `PRG_TwinBenchNativeUdpMulti` et coller le contenu du
   fichier `.st`.
4. Creer une tache `TwinBenchUdpTask` a 10 ms et y ajouter ce programme.
5. Lancer `Start_T408_UdpEcho.ps1`, puis telecharger dans Control Win local.
6. Mettre `Enable := TRUE` dans Watch, laisser les mesures tourner 75 s, puis copier les trois rapports.
7. Mettre `Enable := FALSE` avant logout : le socket est ferme explicitement.

## Regles absolues

- si la bibliotheque `SysSocket` est absente ou ne compile pas : **stop**, ne pas
  remplacer par OPC UA ou modifier le projet source ; copier le message ici ;
- le POU ne doit jamais etre ajoute au MainTask de production ;
- aucun resultat de T408 n autorise encore l injection de l image M3.

Le flux rapide tourne a 10 ms, le cyclique a 50 ms et l evenementiel est emis
sur front de `EventTrigger`. Faire une premiere mesure sans front, puis actionner
`EventTrigger` plusieurs fois pendant la seconde mesure.
