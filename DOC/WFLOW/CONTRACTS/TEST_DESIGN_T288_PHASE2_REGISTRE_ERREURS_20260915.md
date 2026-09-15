# T288 phase 2 - Design essais C4

| ID | Stimulus | Attendu |
|---|---|---|
| TD-01 | Commande active, retour collectif repos, codeur immobile | Discordance contacteurs apres delai ; SafeStop ; pas de PowerCutOff. |
| TD-02 | Commande active, retour collectif repos, codeur en mouvement | Meme discordance apres delai ; le codeur ne masque pas le defaut E/S. |
| TD-03 | Commande active, retour confirme, codeur immobile | Absence mouvement seule apres son delai ; aucune discordance contacteurs. |
| TD-04 | Commande inactive, retour collectif repos | Etat nominal ; aucun defaut. |
| TD-05 | Discordance disparue puis Reset | Cause latchee effacee uniquement sur front Reset ; aucune reprise automatique. |
| TD-06 | Retour collectif defectueux sans moyen d'identifier l'organe | Message unique de discordance, sans attribution direction/vitesse/frein. |
| TD-07 | `Enable=FALSE` puis `Enable=TRUE` | Le registre est neutralise selon le contrat, mais un defaut latche non acquitte ne disparait pas silencieusement. |
| TD-08 | `BypassGlobal=TRUE` | Les causes et latches sont purges conformement au contrat ; aucune alarme residuelle ni redemarrage automatique. |
| TD-09 | Front `Reset` alors que la cause reste active | Le latch est acquitte, mais la cause live reste visible et se relatte si elle persiste. |
| TD-10 | Deux causes simultanees (absence mouvement + discordance) | Deux identites restent tracables ; le carrousel IHM peut prioriser sans fusionner les causes. |
| TD-11 | Codeur indisponible, commande + retour repos | La discordance contacteurs reste detectable ; elle ne depend pas de `EncoderAvailable`. |
| TD-12 | Codeur en mouvement, commande + retour repos | La discordance reste detectable ; le mouvement ne valide pas le retour contacteurs. |

> Injection simulation a concevoir : une ecriture ou un Force sur `HwIn` n'est pas recevable, car l'aiguillage Acquisition le reecrit a chaque scan.

## Decision d'architecture issue de la revue

Retenir un registre canonique dedie aux erreurs treuils, avec un producteur unique dans
`FB_Safety_Winch`, puis une projection vers `ST_SafetyWinch` et l'IHM. Conserver
`ST_Fault/FB_FaultCore` pour la compatibilite des defauts existants pendant la migration.
Ne pas creer un 17e bit cache ni etendre le socle global dans cette tache.
