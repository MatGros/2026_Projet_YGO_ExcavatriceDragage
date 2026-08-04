# Fiche `FB_DigitalInputFilter` v1.0

> 🎯 Brique minimale de filtrage temporel d'une entrée TOR réelle.
> 📄 Source : `CODE/COMMUN/FB_DigitalInputFilter.st`
> 🔗 Producteur : `PRG_02_Acquisition.HwRealQualified`
> 🛡️ La brique ne commande aucun actionneur et ne porte aucun diagnostic device.

## 1. Responsabilité unique

`FB_DigitalInputFilter` accepte un changement de `InputRaw` uniquement après stabilité pendant
`FilterTime`. La première valeur est prise immédiatement au premier scan afin d'éviter une fausse
transition de démarrage.

Il ne réalise pas :

- d'inversion NO/NC ;
- de normalisation de polarité ;
- de diagnostic de voie ou de carte ;
- de `SafeStop`, d'autorisation ou de commande ;
- de sélection réel/simulé.

## 2. Interface

| Port | Type | Rôle |
|---|---|---|
| `InputRaw` | `BOOL` | Valeur brute du canal réel |
| `FilterTime` | `TIME` | Durée minimale de stabilité |
| `State` | `BOOL` | Valeur filtrée |

## 3. Règles d'utilisation

- Instance appelée dans `PRG_02_Acquisition`, jamais dans un POU métier.
- `FilterTime := T#20MS` pour les 22 TOR de la chaîne actuelle, jusqu'à qualification terrain.
- `HwReal` reste l'image brute pour le diagnostic.
- `HwRealQualified` porte l'image réelle filtrée.
- `HwSim` est déjà normalisée par `FB_SimBench` et ne repasse pas dans ce filtre.
- `HwIn` sélectionne `HwRealQualified` ou `HwSim` selon le domaine simulé.
- La santé des modules reste fournie séparément par `GetDeviceState()` et `InputModuleFault`.

## 4. Critères de test

| ID | Attendu | Vérification |
|---|---|---|
| TC-P06-FILT-01 | Au premier scan, `State = InputRaw` | Watch CODESYS après démarrage |
| TC-P06-FILT-02 | Une impulsion plus courte que `FilterTime` ne change pas `State` | Forçage contrôlé sur banc |
| TC-P06-FILT-03 | Un changement stable pendant `FilterTime` est accepté | Watch + mesure temporelle |
| TC-P06-FILT-04 | Le filtre n'inverse jamais la polarité | Comparer `InputRaw` et `State` |
| TC-P06-FILT-05 | Une entrée simulée n'est pas retardée par ce filtre | Comparer `HwSim` et `HwIn` en simulation |
| TC-P06-FILT-06 | Un défaut module reste publié même si le filtre fonctionne | `InputModuleFault` / `Network.InputModules.Fault` |

## 5. Limites

Cette brique ne prouve ni le câblage, ni la polarité, ni la santé de la carte. Elle ne remplace pas
la validation physique des 22 voies, le test AU, le test frein ou la qualification des SafeStop.
