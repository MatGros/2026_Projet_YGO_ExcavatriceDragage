# T408 — POC UDP natif Control Win

## But

Remplacer **uniquement pour la mesure** le ScriptEngine T407 par un petit POU
UDP natif, appele par une tache 10 ms dans la copie Control Win. Il ne connait
pas M3, SimBench, GVL ni E/S : c est un ping technique boucle locale.

```text
PRG_TwinBenchNativeUdp (10 ms, copie Control Win)
       | flux UDP non bloquants 127.0.0.1
       v
Serveur echo Python local
       | reponse sequencee
       v
Compteurs et latences observes dans CODESYS
```

## Pourquoi cette voie

- T407 a prouve que le loopback et la plante OpenModelica fonctionnent, mais
  ScriptEngine a cadence a ~217 ms/echange.
- `SysSocket` est une bibliotheque **System** CODESYS ; la documentation 3S
  decrit `SysSockCreateUdp`, `SysSockSendToUdp` et `SysSockRecvFromUdp`.
- L envoi/reception doivent etre non bloquants : aucun `recv` ne peut attendre
  dans la tache PLC 10 ms.

## Regles de surete

1. `127.0.0.1` et ports T408 fixes, aucune configuration reseau.
2. POU isole, import dans la **copie** uniquement ; aucun lien vers le programme
   applicatif ni les images materiel.
3. `Enable=FALSE` ferme le socket et remet les compteurs d etat sans ordre PLC.
4. Un paquet max par scan ; la reception est optionnelle et non bloquante.
5. Les seuils 50 ms sont un verdict de POC, jamais une promesse Windows temps reel.

## Flux a cadences independantes

UDP est sans connexion persistante. On peut donc ouvrir plusieurs sockets/ports
sur le meme runtime, mais ils doivent rester peu nombreux et chacun doit etre
non bloquant. Le POC mesure d abord un seul flux, puis la coexistence suivante :

| Flux | Cadence | Port | Contenu futur |
|---|---:|---:|---|
| Rapide | 10 ms | 29031/29032 | commande et retours dynamiques |
| Cyclique | 50 ms | 29041/29042 | image complete, health, diagnostic |
| Evenement | a front | 29051/29052 | capteur, defaut, reconnexion |

Le flux evenementiel ne tourne pas a vide : il emet seulement a un changement.
Le verdict cle est le delta p99 du flux rapide entre le test seul et le test
multi-flux. Si la coexistence le degrade au-dela du budget, le multiplexage ou
la repartition par taches sera revu avant toute liaison M3.

## Critere de decision

| Resultat trace 60 s | Decision |
|---|---|
| 0 perte, p99 <= 50 ms, max explique et borne | Candidat pour un contrat de liaison M3 separe |
| p99 > 50 ms ou blocage tache | NO-GO ; ne pas injecter M3 |

## Limite Control Win connue

Un retour Forge CODESYS specifique a Control Win signale qu un port UDP peut
rester reserve apres un restart si le socket n est pas ferme. Le POC comporte
donc un arret explicite et une recette stop/start, avant toute mesure de charge.
