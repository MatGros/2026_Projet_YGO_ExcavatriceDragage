# Session de troubleshooting — Treuils M1/M2 : départ asymétrique en commande Both

> Date : 2026-09-01 · Situation : banc simulation · Statut : **analyse ouverte — aucune correction ST autorisée**.

## 1. Risque et invariant à obtenir

En commande opérateur **Both** (M1+M2), un départ d'un seul treuil est interdit, sauf un chemin explicitement identifié comme unitaire (ex. action benne M2) et visible à l'opérateur.

```text
Intention Both + direction D
  -> autorisation commune Both(D)
  -> M1 et M2 commandés ensemble, ou M1=0 et M2=0
  -> deux interverrouillages finaux valident séparément les sorties
```

L'homme-mort n'est pas deux armements : `FB_Joystick.DeadmanArmed` est unique et partagé. Le symptôme rapporté est donc une asymétrie **après** cet homme-mort : commande, permis directionnel ou état final par treuil.

## 2. Faits du snapshot 02:48:41

Source : `TOOLS/PLC_CSV_SNAPSHOT/RESULTS/snapshot/Snapshot_Troubleshooting_20260901_024841.csv` (499/499).

| Élément | Valeur | Lecture fiable |
|---|---:|---|
| Homme-mort brut / armé | TRUE / TRUE | Oui |
| Direction joystick qualifiée | +1 | Oui |
| M1/M2 permis montée effectifs | TRUE / TRUE | Oui |
| M1/M2 permis descente effectifs | FALSE / FALSE | Oui |
| Sorties, palier et direction arbitrée M1/M2 | 0 / arrêt | Oui : snapshot hors symptôme actif |
| Interverrouillage final M1 et M2 | `READY`, raison `NONE`, palier autorisé 0 | Oui : aucun blocage final à l'instant |
| Défaut synchro publié | TRUE | Oui |
| `SyncDelta_M` | +15 m | Oui, écart **corrigé par l'offset benne actif** ; pas assimilable directement à M1-M2 bruts |

Les champs `H_LevageSynchroniseM1M2.Idx201`, `Idx203`, `Idx401`, `Idx402`, `Idx403` ne sont pas câblés par `FB_TroubleshootingView.st:149-151`. Ils ne doivent pas être utilisés comme preuve.

## 3. Chaînes statiques candidates

### A. Gate directionnel synchro asymétrique — candidat principal, à confirmer en dynamique

`PRG_04_Treuils_Benne.st:335-337` produit `SyncBlocksAscent/Descent` seulement si `_SyncSoftStopEnable=TRUE` (valeur persistante par défaut : FALSE).

Les deux arbitres consomment alors volontairement ces mêmes drapeaux en sens inverse :

| Situation Both | M1 | M2 | Résultat actuel si soft-stop actif |
|---|---|---|---|
| `SyncBlocksAscent`, direction +1 | bloqué | autorisé | **M2 seul peut partir** |
| `SyncBlocksDescent`, direction -1 | bloqué | autorisé | **M2 seul peut partir** |
| signe opposé de l'écart | symétrique inverse | symétrique inverse | **M1 seul peut partir** |

Sources : `FB_WinchCmdArbitrationM1.st:93-99`, `FB_WinchCmdArbitrationM2.st:100-106`. Le commentaire de M2 indique lui-même « synchro inversée vs M1 ». Ce mécanisme semble conçu pour un rattrapage directionnel, mais il viole l'invariant Both ci-dessus si le mode Both est maintenu.

**État de preuve :** le chemin existe ; le snapshot montre un défaut synchro mais ne donne pas la valeur runtime de `_SyncSoftStopEnable`, ni l'instant du départ. Il ne prouve donc pas encore que c'est le chemin observé.

### B. Armement global non lié à la direction demandée — défaut de granularité prouvé

`PRG_04_Treuils_Benne.st:832-835` calcule `ArmingPermit` par OR : il suffit qu'une direction de M1, M2 ou M3 soit possible. Il ne dépend ni du sélecteur Both, ni de la direction actuellement demandée.

Ainsi, un homme-mort peut s'armer alors que le mouvement **Both dans le sens demandé** n'est pas entièrement autorisé. C'est compatible avec l'architecture actuelle, mais pas avec l'exigence utilisateur « Both autorisé = deux treuils autorisés dans ce sens ».

### C. Interverrouillages finaux séparés — hypothèse secondaire

`FB_WinchOutputInterlock` est instancié une fois par treuil. Il porte ses propres délais frein/redémarrage et retours matériels. Après une commande commune, un seul treuil peut donc rester en attente si ses états précédents ou retours divergent. Le snapshot hors mouvement montre les deux en `READY` et ne permet pas de l'incriminer ou de l'écarter lors du défaut.

## 4. Impact d'une correction — à valider avant code

| Changement envisagé | Effet recherché | Risque / décision nécessaire |
|---|---|---|
| Gate commun `BothDirectionPermit` en amont des 2 arbitres | Both = deux départs ou aucun | Décider si le rattrapage synchro doit basculer automatiquement hors Both, ou exiger une action opérateur explicite |
| Armement contextuel au sélecteur + direction | Pas d'homme-mort armé pour un Both incomplet | À définir au neutre : l'armement doit-il anticiper les deux sens, ou seulement refuser dès qu'une direction est sollicitée ? |
| Diagnostic couplé final | Expliquer « M1 prêt / M2 attente frein » | Ne doit jamais masquer un blocage : la commande Both doit être annulée pour les deux si l'atomicité est requise |

Les chemins explicitement unitaires restent hors du couplage : sélection M1, sélection M2, et `BucketM2StartStop` pendant l'action benne. Ils devront être nommés et testés comme exceptions.

## 5. Capture décisive demandée

Prendre un snapshot **pendant que l'un part et l'autre non**, sans relâcher le joystick avant la lecture. Les variables minimales à ajouter/lire sont :

- `_SyncSoftStopEnable`, `SyncState.ErrorId`, `SyncState.SyncDeviationWarn`, `BucketState.ActiveOffset_M` ;
- intention Both et sélecteur arbitrés ;
- direction/start-stop/step demandés par M1 et M2 juste après arbitrage ;
- `FinalInterlockState`, `FinalInterlockReason`, `FinalRestartInhibit`, retours frein/contacteurs des deux treuils.

## 6. Recette obligatoire avant toute livraison

1. Both + sens autorisé : M1 et M2 partent ensemble.
2. Both + permis refusé sur l'un : aucun ne part, à toutes vitesses et après manipulation rapide du joystick.
3. Both + défaut synchro avertissement, soft-stop activé/désactivé : comportement choisi explicitement et visible.
4. Sélection unitaire M1/M2 et action benne M2 : comportements légitimes préservés.
5. Historique de frein/délai différent M1/M2 : aucun départ isolé en Both, aucun redémarrage automatique.

