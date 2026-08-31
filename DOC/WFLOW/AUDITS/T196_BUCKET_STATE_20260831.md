# Audit T196 — état benne et confirmation de référencement

Date : 2026-08-31  
Criticité : C2 — H_TREUILS_BENNE  
Statut : implémenté, vérification hors ligne réalisée

## Conclusion opérationnelle

`GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnConfirmOpenPos` n'est pas un setter de
`IsOpen`. La confirmation IHM est un front opérateur consommé par
`FB_MachineHomingCycle`, puis transformée en commit atomique après succès du
référencement M1 + M2. `FB_Bucket` ignore volontairement ses entrées legacy
`ConfirmOpenPosition`/`ConfirmClosePosition` afin qu'une commande forcée ne
puisse pas déclarer une position mécanique sans mesure qualifiée.

Pour être acceptée, la confirmation doit satisfaire simultanément :

1. `Mode = E_Mode.MAINT_N2` ;
2. `TopPositionActive = TRUE` (entrée physique : `NOT M1M2_TopPositionFree_DI`) ;
3. `WinchesMechanicallyStopped = TRUE` (contacteurs retombés, freins appliqués,
   vitesses M1/M2 inférieures à 0,02 m/s) ;
4. front montant unique du bouton ; une valeur déjà forcée à `TRUE` ne recrée
   pas de front tant qu'elle n'est pas repassée à `FALSE`.

Si une condition manque, le cycle reste dans son guide (`NEED_TOP_POSITION`,
`NEED_MECHANICAL_STOP` ou `AWAIT_BUCKET_CONFIRM`) et aucun commit n'est émis.

## Chaîne vérifiée

| Étape | Producteur → consommateur | Preuve |
|---|---|---|
| Confirmation | `GVL_IHM...BtnConfirmOpenPos` → `PRG_02` → `FB_MachineHomingCycle.ConfirmOpenPosition` | `PRG_02_Acquisition.st:404-418` |
| Référencement | `FB_MachineHomingCycle` → `Data.MachineHoming.SetPosBucketOpen/Close` | `PRG_02_Acquisition.st:419-426` |
| État mécanique | commit → `FB_Bucket.MachineHomingCommitOpen/Close` | `PRG_04_Treuils_Benne.st:272-288` |
| Publication | `FB_Bucket` → `PRG_04.Data.BucketState` → GVL IHM | `PRG_04_Treuils_Benne.st:1217-1218,1375`; `PRG_07_Supervision.st:393` |

## Corrections appliquées

- Détection de mémorisation incohérente au premier cycle : ni `IsOpen` ni
  `IsClosed`, **ou les deux simultanément**, positionne `StateIncoherent` et
  invalide l'offset actif (`FB_Bucket.st:198-206`).
- Le banc de simulation expose `GVL_Simulation.SimTopPositionActive` et génère
  la polarité matérielle correcte `M1M2_TopPositionFree_DI := NOT
  SimTopPositionActive` (`FB_SimBench.st:63,215`, `GVL_Simulation.st:26`).

## Vérification

- `FB_MachineHomingCycle` : **18/18 PASS**, compilation STruCpp, chronogramme
  et rapport générés.
- Lint statique : `FB_Bucket`, `FB_MachineHomingCycle`, `FB_SimBench` propres,
  aucun type non résolu.
- `FB_Bucket` : le JSON post-traité du runner indique **24/24 PASS**. Le
  texte produit par la première exécution STruCpp affiche encore 3 échecs de
  copie `VAR_IN_OUT` avant le post-traitement automatique ; ces échecs sont
  éliminés dans l'exécutable copy-out et ne doivent pas être interprétés comme
  des défauts du FB.
- Le test global `FB_SimBench` reste non concluant : la compilation du banc
  rencontre des types de diagnostic absents du registre et un fichier joystick
  hors périmètre T196. Le lint et le test de polarité ciblé restent valides.

## Procédure de test en ligne

1. Passer en maintenance N2.
2. Immobiliser M1 et M2 : commandes relâchées, contacteurs retombés, freins
   appliqués, vitesses nulles.
3. Amener les deux treuils au capteur haut commun ; vérifier
   `GVL_IHM.Commun.TopPositionSensorActive = TRUE`.
4. Forcer le bouton choisi à `FALSE`, puis à `TRUE` pendant un seul cycle.
5. Vérifier `MachineHomingActive`, puis le commit et enfin
   `Bucket.State.MechState.IsOpen` (ou `IsClosed`) dans la GVL IHM.

Une confirmation refusée doit être expliquée par
`Bucket.State.MachineHomingInstruction`; aucun forçage direct de `IsOpen` ou
`IsClosed` n'est acceptable en production.

## Addendum de validation hors CODESYS — 2026-08-31 04:34

Cette section remplace le verdict provisoire de la section « Vérification ».

- `FB_Bucket` : **24/24 PASS** avec STruCpp. `T196-001` et `T196-002`
  prouvent l'écriture de `BucketState.IsClosed` / `IsOpen` uniquement après
  atteinte de la position physique. `T181-21` prouve le copy-out réel du
  `VAR_IN_OUT` partagé.
- `FB_MachineHomingCycle` : **18/18 PASS**. Les cas `TC-T185-020` à `091`
  couvrent la fenêtre N2, capteur haut, arrêt mécanique, front de confirmation,
  commit exclusif et perte de qualification.
- `FB_SimBench` : **22/22 PASS**, dont `T196-003` :
  `M1M2_TopPositionFree_DI := NOT SimTopPositionActive`.
- Lint ST propre sur `FB_Bucket`, `FB_MachineHomingCycle` et `FB_SimBench`.

Garde-fou de banc ajouté : chaque processus STruCpp utilise désormais son
répertoire `TEMP` isolé. Avant cela, deux tests lancés simultanément pouvaient
sélectionner le runner temporaire d'un autre FB et afficher un résultat
erroné. Le test concurrent `FB_Bucket` + `FB_SimBench` a désormais confirmé
respectivement **24/24** et **22/22**.

La validation finale reste un test humain CODESYS de la chaîne réellement
compilée : commande benne, atteinte d'offset, publication IHM, puis séquence
de confirmation au capteur haut. Aucun bundle exporté non frais ni
`Device.export` n'a été utilisé comme preuve.
