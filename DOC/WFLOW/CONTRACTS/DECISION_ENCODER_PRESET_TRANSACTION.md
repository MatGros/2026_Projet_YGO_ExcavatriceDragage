# 🧭 Décision requise — Preset codeur : transaction matérielle ou echo ?

> **Statut** : **DÉCIDÉE — variante C** · **Visa humain consigné** : 2026-08-27
> · **Précondition PRE1 levée** pour `TASK_CONTRACT_ENCODER_INTERFACE_CONFORMANCE.yaml` (lot E1)
> **Décideur** : humain avec connaissance du codeur absolu EtherCAT réel (pas un agent)
> **Créé** : 2026-08-27 · Origine : revue façade `FB_Encoder` (agent externe) + audit orchestrateur

---

## Le fait

`FB_Encoder_Homing` pose `Calib.Homed := TRUE` (référence validée, écrite en RETAIN)
**avant** d'avoir la confirmation matérielle du preset (`instAbs.PresetAck`). Les sorties
`instAbs.PresetAck` / `PresetNak` **existent** mais ne sont consommées par personne pour
gater le commit RETAIN. `AF_Partie-09 §4 / §5 / F09.01` décrit une « séquence d'écriture
preset (déclenchement, tolérance, timeout) » sans dire si son **succès** conditionne
`Homed`.

Conséquence du flou : un homing peut inscrire une référence en mémoire persistante alors
que le preset matériel a échoué → **mauvaise position absolue qui survit au reboot**, sans
alarme.

## La question

**Le preset SDO/PDO vers le codeur est-il une vraie transaction dont le succès est requis,
ou un simple aller optionnel dont on ignore le retour ?**

## Options

| # | Décision | Ce que ça implique dans le code |
|---|---|---|
| **A** | **Vraie transaction** — le succès du preset est requis | `Calib.Homed := TRUE` **uniquement** sur `PresetAck` (dans la fenêtre timeout). `PresetNak` (ou timeout) → homing refusé, `ErrorId` bit dédié, `Homed` inchangé. `Calib.HomingRefRaw` committé au même instant que `Homed`, jamais avant. |
| **B** | **Echo optionnel** — le retour n'est pas fiable / pas utilisé | Supprimer la pseudo-transaction : retirer `PresetAck`/`PresetNak` de l'interface `ST_EncoderHw` (→ `ST_fbEncoder_HwIn`), retirer le séquencement timeout de `FB_Encoder_Abs`, documenter en clair que `Homed` repose sur le calcul interne seul (`RawPos` lu, pas confirmé côté device). |
| **C** | **Autre** — préciser | (décrire) |

## Impact aval selon la réponse

- **A** : lot E1 ajoute un état d'attente de confirmation dans `FB_Encoder_Homing` +
  1 bit `ErrorId`. `CodeSeqTriggerCmd` (aujourd'hui à 0 par construction, `AF-09 §11 TBD`)
  reste à trancher séparément.
- **B** : lot E1 simplifie — moins de ports, moins d'états, interface publique réduite.
- Dans **les deux cas** : `Homed`/`HomingSuspect`/`HomingRefRaw` restent ré-exposés depuis
  `Calib` quand `Enable=FALSE` (déjà corrigé, `AF-09 §4`).

## Réponse

```
Décision retenue : C  (variante de A — transaction réelle, confirmation par relecture mesure)
Par : utilisateur (connaissance hardware)   Date : 2026-08-27
```

**Précision — mécanisme retenu :**

Le preset EST une transaction réelle (le succès conditionne `Calib.Homed`), MAIS la
confirmation ne passe **pas** par un bit d'accusé du codeur : elle se fait par **relecture
de la valeur mesurée**.

1. Référencement (front capteur haut **ou** bouton IHM) → charge la valeur preset calculée
   dans le port de sortie + **front montant** sur le bit de commande preset.
2. Après le front, `RawPos` change ; laisser passer N cycles (`PresetLatencyCycles`, déjà
   présent) pour que la valeur se propage → `CablePosM` recalculée par la chaîne.
3. **Vérification boucle fermée** : `ABS(CablePosM − cibleAttendueM) <= CST_HomingVerifyToleranceM`
   (quelques mm, valeur à caler site — défaut proposé `0.010` m).
   - OK → `Calib.Homed := TRUE`, `Calib.HomingRefRaw` committé au même instant.
   - Écart trop grand après N cycles → preset échoué : `Homed` **inchangé**,
     `HomingSuspect := TRUE` + bit `ErrorId` dédié (nouveau).

### Extension prévue — bit du mot d'état codeur (site)

La relecture mesure fonctionne **sans matériel réel** (banc). Sur site, un bit du **mot
d'état** du codeur pourra confirmer le preset directement. Le programme doit permettre d'y
basculer **sans refonte** :

- Entrée optionnelle `PresetStatusBit : BOOL` dans `ST_fbEncoder_HwIn` — **non câblée
  aujourd'hui** (laissée à `FALSE`), destinée à recevoir le bit extrait du mot d'état.
- Sélecteur dans `Cfg : ST_fbEncoder_Cfg` : `PresetConfirmMode : E_PresetConfirmMode`
  (nouvel ENUM) = `READBACK_ONLY` (défaut) | `READBACK_AND_STATUSBIT` | `STATUSBIT_ONLY`.
- Logique de confirmation dans `FB_Encoder_Homing` :
  - `okReadback := (ABS(CablePosM - cibleAttendueM) <= CST_HomingVerifyToleranceM)` après N cycles.
  - `READBACK_ONLY`        → `presetConfirmed := okReadback`
  - `READBACK_AND_STATUSBIT` → `presetConfirmed := okReadback AND PresetStatusBit`
  - `STATUSBIT_ONLY`       → `presetConfirmed := PresetStatusBit`
  - `presetConfirmed=FALSE` après N cycles → `Homed` inchangé + `HomingSuspect` + bit `ErrorId`.
- Sur site : câbler `PresetStatusBit` depuis le mot d'état + changer `Cfg.PresetConfirmMode`.
  Aucun autre code à toucher.

## Invariants obligatoires de la transaction

Ces invariants rendent la variante C non ambiguë pour T164-4C :

1. `Calib.Homed` et `Calib.HomingRefRaw` forment un **commit atomique** : ils
   sont écrits ensemble, uniquement après confirmation du preset. Une tentative
   en cours ne modifie ni l'un ni l'autre.
2. Après la temporisation historique de commande, si la confirmation échoue (relecture
   hors tolérance ou mode `PresetStatusBit` non satisfait), l'ancienne valeur de
   `Calib.Homed` est conservée, l'ancienne référence brute est conservée,
   `Calib.HomingSuspect` passe à `TRUE` et le fait public
   `PresetConfirmationFailed` ainsi que son bit `ErrorId` dédié sont publiés.
3. Le front `Reset` acquitte la vue latchée du défaut ; il ne valide jamais un
   preset, ne remet pas `Homed` à `TRUE` et ne réécrit pas `HomingRefRaw`. Une
   confirmation explicite ou une nouvelle tentative réussie est nécessaire.
4. `READBACK_ONLY` reste le mode par défaut. `PresetStatusBit` est optionnel et
   vaut `FALSE` tant qu'il n'est pas câblé ; aucun signal matériel absent ne peut
   confirmer implicitement le preset.

### Clarification de la relecture avant commit

Avant le commit, la mesure publique `CablePosM` continue légalement à utiliser
`Calib.HomingRefRaw` **ancien**. Elle ne peut donc pas être comparée directement
à la cible sans rendre le commit non atomique. La confirmation `READBACK_ONLY`
doit calculer localement la mesure candidate à partir de la relecture `RawPos`
et de `PendingHomingRefRaw` :

`CandidateCablePosM := (RawPos - PendingHomingRefRaw) × CableM_PerRev / PointsPerRev`.

Cette candidate est une preuve de relecture du matériel ; elle n'est pas publiée
vers les consommateurs. Au succès seulement, le commit atomique rend ensuite
`CablePosM` publique cohérente avec la cible. `Calib.Homed` reste inchangé en
échec ; la sortie publique `Homed` conserve sa règle safety existante
`Calib.Homed AND NOT Calib.HomingSuspect` et retombe donc à `FALSE` sur doute.

### Temporisation de transaction

`PresetLatencyCycles` n'existe pas dans le code de référence et ne doit pas être
inventé. La transaction conserve la temporisation existante `T#500MS` qui maintient
la commande preset ; la vérification candidate ne démarre qu'après cette même durée.
`PresetTimeout := T#2s` reste inchangé dans l'interface legacy de l'Abs, sans
introduire de nouvelle valeur, seuil ou polarité.

Le statut « DÉCIDÉE » concerne la décision d'architecture. L'implémentation et
les tests restent dans les lots T164-4B/4C et exigent leur propre validation.

**Conséquences pour `TASK_CONTRACT_ENCODER_INTERFACE_CONFORMANCE.yaml` (T164-4) :**

- `ST_EncoderHw.PresetNak` : **supprimé** (pas de bit d'échec fiable ; l'échec = mesure hors
  tolérance après N cycles, ou `PresetStatusBit` absent selon le mode).
- `ST_EncoderHw.PresetAck` : **remplacé** par l'entrée optionnelle `PresetStatusBit`
  (sémantique « bit du mot d'état », pas « pulse d'accusé »), non câblée aujourd'hui.
- `FB_Encoder_Abs` : la séquence preset garde chargement valeur + front commande + latence ;
  perd l'attente d'ack. Extrait le `PresetStatusBit` du mot d'état si un bit est identifié
  (sinon le laisse à `FALSE`).
- `FB_Encoder_Homing` : ajoute l'étape de vérification (§3 + modes ci-dessus) + 1 bit
  `ErrorId` « preset non confirmé ».
- Nouveaux : `CST_HomingVerifyToleranceM : REAL := 0.010` (VAR CONSTANT, à caler site),
  ENUM `E_PresetConfirmMode`, champ `Cfg.PresetConfirmMode` (défaut `READBACK_ONLY`).
- `CodeSeqTriggerCmd` (déjà à 0 par construction, `AF-09 §11 TBD`) : reste hors périmètre.
- `AF_Partie-09 §4 / §5 / F09.01` + `§11` : mettre à jour la séquence preset (relecture +
  option mot d'état).

→ Précondition **PRE1 levée** pour T164-4. Reste PRE2 (chantier #3 / T164-3).
