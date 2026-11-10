# Plan T289 — Égouttage AX13 configurable en secondes

> Statut : proposition technique avant implémentation · Criticité C2 · Stratégie : patch incrémental

## 1. Résultat attendu

L'opérateur configure l'égouttage AX13 avec un entier en secondes et visualise son temps écoulé avec un entier en secondes, sans modifier la TON métier ni la transition `AX13 -> AX14`.

Chaîne cible :

```text
IHM DrainTime_S (INT, autorite unique)
  -> LIMIT 1..3600 / conversion explicite DINT_TO_TIME
  -> CfgDrainTime (TIME)
  -> FB_CycleSemiAuto.DrainTimeEff
  -> DrainingTimer(IN := AX13, PT := DrainTimeEff)
  -> DrainingElapsed (TIME)
  -> conversion TIME_TO_DINT / 1000
  -> IHM DrainTimeElapsed_S (INT)
```

## 2. Décisions proposées

### 2.1 Nommage

- Consigne IHM : `DrainTime_S : INT` dans `ST_CycleCfg`.
- Mesure IHM : `DrainTimeElapsed_S : INT` dans `ST_CycleState`.
- Sortie métier native : `DrainTimeElapsed : TIME` dans `FB_CycleSemiAuto` et le bus public.

Justification : `NC-030` impose le suffixe d'unité avec underscore ; `_S` reste cohérent avec `_Ms`. La conversion IHM reste à la frontière, tandis que le FB métier conserve le type IEC `TIME`.

### 2.2 Autorité entre ancien TIME et nouvel INT

- `DrainTime_S` est l'unique autorité de consigne, avec un défaut de 5 s.
- Toute écriture IHM est bornée dans `1..3600` ; 0 et les valeurs négatives deviennent 1 s, 3601 devient 3600 s.
- L'ancien champ `DrainTime : TIME` est supprimé de `ST_CycleCfg` : il n'a plus de rôle de configuration et son maintien créerait un faux paramètre.
- Le tag IHM existant `Cfg.DrainTime` doit être remplacé par `Cfg.DrainTime_S` lors de l'import.

### 2.3 Bornes et conversion

- Plage métier validée : `1..3600 s`.
- Aller : `DINT_TO_TIME(INT_TO_DINT(DrainTimeEff_S) * DINT#1000)`, avec `DrainTimeEff_S` déjà borné.
- Retour : borner le `TIME` à `T#3600s`, appliquer `TIME_TO_DINT(...) / DINT#1000`, puis `DINT_TO_INT`.
- Le temps écoulé IHM est saturé dans `0..3600 s`.
- Affichage par secondes entières écoulées, arrondi inférieur (`ET / 1000 ms`).
- Ces expressions doivent être prouvées par compilation avec la cible CODESYS du projet.

## 3. Phasage testable et réversible

### Phase A — Contrat et garde structurel, sans comportement

1. Corriger le scope du contrat T289 : ajouter `ST_CycleState`, `ST_SequencePublicState`, `PRG_03_Modes_Cycle`, `PRG_07_Supervision`, `GVL_PERSISTENT`, le pont de persistance et les tests ciblés.
2. Ajouter un garde automatique T289 contrôlant : noms, types, suppression de `DrainTime`, absence de modification de la transition AX13 et conversions bornées.
3. Valider le contrat avec `check_task_contract.py`.

Critère d'arrêt : aucune modification du comportement PLC ; contrat et garde validés.

### Phase B — Mini-lot importable : consigne INT

1. Remplacer `DrainTime : TIME` par `DrainTime_S : INT := 5` dans `ST_CycleCfg`.
2. Borner toutes les saisies `DrainTime_S` à 1..3600.
3. Dans `PRG_03`, convertir `DrainTime_S` et alimenter l'entrée existante `CfgDrainTime`.
5. Compiler et livrer un diff XML minimal pour essai immédiat de saisie IHM.

Critère d'arrêt : l'utilisateur peut écrire 1..3600 s et constater la durée AX13 correcte. Aucun second paramètre TIME n'est exposé.

### Phase C — Publier le temps écoulé

1. Ajouter `DrainTimeElapsed_S : INT := 0` à `ST_CycleState`.
2. Dans `FB_CycleSemiAuto`, publier `DrainTimeElapsed := DrainingTimer.ET`.
3. Propager le `TIME` dans `PRG_03.Data.SequenceState`, avec neutralisation explicite à `T#0s` dans les branches maintenance et disable.
4. Dans `PRG_07_Supervision`, convertir et saturer vers `GVL_IHM.CycleSemiAuto.State.DrainTimeElapsed_S`.
5. Hors AX13, conserver le comportement naturel de la TON : valeur remise à zéro, y compris au scan suivant un Skip.

Critère d'arrêt : la valeur IHM progresse de 0 à la consigne pendant AX13 et revient à 0 hors AX13.

### Phase D — Tests et livraison

1. Étendre les tests `FB_CycleSemiAuto` : tempo 1 s, tempo configurée, repli 0, bouton Skip, remise à zéro hors AX13.
2. Ajouter les tests de bornes `-1, 0, 1, 5, 3599, 3600, 3601, 32767`, redémarrage chaud et redémarrage froid.
3. Tester Skip avant Q, Skip maintenu (front unique), sortie/réentrée AX13, changement de mode et valeur elapsed non stale.
4. Lancer le garde T289, les tests ciblés, le bundle complet, le diff bundle, G200 puis le palier C.
5. Fournir le mapping IHM :
   - entrée `GVL_IHM.CycleSemiAuto.Cfg.DrainTime_S` ;
   - sortie `GVL_IHM.CycleSemiAuto.State.DrainTimeElapsed_S` ;
   - ancien `GVL_IHM.CycleSemiAuto.Cfg.DrainTime` absent.

## 4. Non-régression obligatoire

- `DrainingTimer` reste un `TON` natif `TIME`.
- `IN := (State = AX13_DRAIN_PAUSE)` reste inchangé.
- `PT := DrainTimeEff` reste inchangé.
- `DrainingTimer.Q OR SkipDrainEdge.Q` reste la seule transition vers AX14.
- Aucun impact sur T291-A, les commandes treuils, les sécurités ou les modes manuel/maintenance.
- Aucun accès à `Device.export`.

## 5. Points à challenger par l'expert

1. La modification de la consigne pendant AX13 reste-t-elle appliquée en direct comme aujourd'hui, ou faut-il la figer à l'entrée ? Proposition : conserver le comportement direct pour ne pas élargir T289.
2. Le temps écoulé revient à zéro hors AX13, identique à `TON.ET` : décision à confirmer.
3. La rupture du tag IHM `Cfg.DrainTime` est assumée : il doit être remplacé par `Cfg.DrainTime_S`.

## 6. Arrêt humain avant code

Après intégration du challenge expert, présenter les corrections du plan et les éventuelles décisions ouvertes. Ne modifier aucun fichier `CODE/` avant validation humaine explicite du plan final.
