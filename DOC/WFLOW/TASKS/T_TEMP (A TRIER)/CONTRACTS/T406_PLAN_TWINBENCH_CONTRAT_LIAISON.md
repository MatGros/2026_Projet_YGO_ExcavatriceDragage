# T406 — Contrat TwinBench M3 : signaux et surete de liaison

Date : 2026-09-28  
Statut : **phase A — contrat documentaire ; aucun runtime contacte**

## 1. Regle de proprietaire unique

```text
PLC CODESYS      : commande, sequence, rampe PLC, interlocks, securites
Passerelle locale: transport, typage, horodatage, validation, journal
OpenModelica     : physique, moteur, frein physique, chariot, capteurs, butees
IHM QML          : affichage, parametrage autorise, traces ; aucune physique
```

`FB_SimBench` reste l enveloppe PLC. Ce contrat ne change aucun programme PLC.

## 2. Images atomiques M3

Une image est acceptee seulement si tous ses champs appartiennent au meme cycle logique.

| Image | Sens | Producteur unique | Contenu minimal |
|---|---|---|---|
| `M3_CommandImage` | PLC → plante | PLC | mot commande, Hz consigne, demande ouverture frein, mode simulation |
| `M3_PlantImage` | plante → PLC | OpenModelica | Hz mesuree, statut variateur, retour frein, capteurs, position, vitesse, butee, defaut simule |
| `M3_LinkHealth` | passerelle → observabilite | passerelle | sequence, timestamps, validite, age, origine, raison de rejet |

Chaque image porte obligatoirement :

- `Sequence` monotone par domaine ;
- `SourceTimestamp` : horodatage de production ;
- `GatewayTimestamp` : horodatage de reception/validation ;
- `IsValid` et `ValidityReason` ;
- `Origin` : `PLC`, `OpenModelica`, `Replay` ou `Stub` ;
- `SchemaVersion`.

Une image partiale n est jamais ecrite vers le PLC.

## 3. Signaux M3 initiaux

| Signal | Sens | Type / unite | Cadence cible | Note |
|---|---|---|---:|---|
| Mot de commande variateur | PLC → plante | `WORD` | evenement + snapshot | Semantique PLC conservee, pas interpretee par l IHM |
| Consigne frequence | PLC → plante | `REAL`, Hz | rapide | 0…50 Hz, provenance PLC |
| Demande ouverture frein | PLC → plante | `BOOL` | evenement + snapshot | Commande PLC, retour distinct |
| Frequence mesuree | plante → PLC | `REAL`, Hz | rapide | Valeur physique simulee, pas une consigne |
| Mot statut variateur | plante → PLC | `WORD` | evenement + snapshot | Contrat bits a figer avant implementation |
| Retour frein applique / ouvert | plante → PLC | `BOOL` | evenement | Etat physique distinct de la commande |
| Capteurs Tremie/PV/P2/P1/Maintenance | plante → PLC | 5 × `BOOL` | evenement + snapshot | Fronts journalises |
| Position / vitesse | plante → trace | `REAL`, m / m/s | lent | Observabilite ; pas requis par le PLC initial |
| Contact butee / defaut simule | plante → PLC | `BOOL` / enumere | evenement | Semantique a traiter par contrat C4 avant boucle fermee |

## 4. Cadences : rapide, cyclique, evenementielle

| Groupe | Contenu | Cible initiale | Regle |
|---|---|---:|---|
| Rapide | commande, Hz, frein, retour frein, Hz mesuree | mesure a faire ; plafond souhaitable 50 ms | Aucun engagement 10 ms Windows sans mesure p99/max |
| Cyclique | image capteurs, statut, health | 50 à 100 ms | Snapshot atomique complet |
| Evenementiel | changement de commande, front capteur, perte/reconnexion | emission immediate + trace | Ne remplace pas le snapshot cyclique |
| Graphique | rendu IHM | 10 à 20 Hz | Ne cadence jamais la physique ni le PLC |

`10 ms FMI` est un pas **simule**, pas une garantie temps reel Windows ni une exigence de transport PLC.

## 5. Validation d une image recue

```text
reception image
  → schema connu ?
  → origine autorisee pour le mode actif ?
  → sequence nouvelle et coherente ?
  → age <= timeout du groupe ?
  → valeurs bornées / types valides ?
  → image entiere ?
  → accepter et journaliser
sinon
  → rejeter, journaliser la raison, publier LinkHealth invalide
```

Regles absolues :

- jamais de *hold last value* silencieux ;
- jamais de melange champs `HwReal` et `HwSim` dans la meme image ;
- jamais de changement d origine sans trace et transition explicite ;
- une reconnexion exige une image complete valide avant reprise.

## 6. Etats de liaison

| Etat | Condition | Sortie autorisee |
|---|---|---|
| `DISCONNECTED` | aucune liaison etablie | aucune ecriture ; health invalide |
| `CONNECTING` | transport ouvert, schema non valide | aucune ecriture ; health invalide |
| `HEALTHY` | image valide, recente, sequence coherente | autorisation uniquement selon mode approuve |
| `STALE` | timeout depasse | rejet ; aucune nouvelle ecriture ; evenement trace |
| `INVALID` | schema/type/bornage/sequence invalide | rejet ; aucune nouvelle ecriture ; raison exposee |
| `RECONNECTING` | retour liaison apres erreur | attendre image complete valide |

Pour un futur banc ferme virtuel, la reaction PLC exacte (`HwSim` neutre ou comportement SimBench ST) sera definie dans un contrat C4 distinct. Elle n est pas devinee ici.

## 7. Essais requis avant toute integration

1. Test local sans CODESYS : schema, serialisation, bornage et sequence.
2. Charge : p50/p95/p99/max, retard, pertes, doublons, reordonnancement et surcharge CPU.
3. Coupure/reconnexion : timeout, rejet, journal et reprise avec image complete.
4. Rejeu deterministe : meme trace d entree, memes sorties a tolerance declaree.
5. Seulement ensuite : lecture seule Control Win ; aucune ecriture avant GO C4 distinct.

## 8. GO / NO-GO de fin de phase A

**GO phase B / C** seulement si ce document est relu et si les decisions suivantes sont valides :

1. Champ, type et signification des bits des deux mots variateur ;
2. Budgets de timeout pour chaque groupe ;
3. Valeur neutre et politique de rejet par mode ;
4. Origines autorisees par `SimulationModeActive` et bit de selection M3 ;
5. Aucun lien direct IHM → PLC/plante.

**NO-GO** si une valeur, un timeout, une origine ou la neutralisation reste ambiguë.
