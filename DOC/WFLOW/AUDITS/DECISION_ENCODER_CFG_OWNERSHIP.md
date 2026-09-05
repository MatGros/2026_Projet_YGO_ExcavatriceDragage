# Décision T164-4A — ownership configuration codeur

> **Statut : DÉCIDÉ POUR LES LOTS 4B–4D · VISA HUMAIN REQUIS AVANT TOUT CODE**
> Date : 2026-08-27 · Périmètre : documentation uniquement
> Références : `TASK_CONTRACT_T164-4A_ENCODER_ARCHITECTURE.yaml`,
> `TASK_CONTRACT_T164-4B_ENCODER_CFG_PERSISTENCE.yaml`,
> `TASK_CONTRACT_T164-4C_ENCODER_PRESET_HW.yaml`,
> `TASK_CONTRACT_T164-4D_ENCODER_FAULT_FACADE.yaml`

## 1. Verdict

1. `ST_fbEncoder_Cfg` est le DUT public de réglage technologique de la façade
   `FB_Encoder` (NC-110). Pour T164-4B, il est volontairement limité à
   `PresetConfirmMode` et `Initialized := FALSE`. Il ne devient pas un second
   propriétaire des réglages métier du treuil.
2. Le propriétaire HMI public commun retenu est `GVL_IHM.Commun.EncoderCfg`
   (`ST_fbEncoder_Cfg`, structure à créer au lot 4B). Le miroir persistant est
   `GVL_PERSISTENT._EncoderCfgPersist`, ajouté en fin de la liste persistante.
   Le seul pont est `FB_CfgPersistBridge_fbEncoder_Cfg`, instancié dans
   `PRG_07_Supervision`, section 2. `PRG_02_Acquisition` est consommateur et ne
   possède aucun pont local.
3. Les cibles homing restent deux réglages métier indépendants :
   `ST_WinchCfg.CfgHomingTarget_M` et `ST_WinchCfg.CfgTopSensorPos_M`, chacun
   dans sa configuration M1/M2. Aucune fusion M1/M2 ni recopie vers une
   persistance codeur commune n'est admise.
4. `PointsPerRev`, `CableM_PerRev`, `PositionMinM` et `PositionMaxM` restent des
   constantes/bornes techniques hors réglage IHM à chaud. Aucun champ `Cfg` ne
   doit les rendre éditables sans décision humaine de sûreté distincte.
5. `Calib` reste séparé du `Cfg`, en `VAR_IN_OUT`, avec `_CalibM1` et `_CalibM2`.
   `Homed`, `HomingRefRaw` et `HomingSuspect` ne sont jamais des écritures IHM.

Cette décision ferme AC1, AC2 et AC6 du contrat T164-4A sous réserve du visa
humain demandé par AC5. Le contrat `TASK_CONTRACT_ENCODER_INTERFACE_CONFORMANCE`
contient encore une formulation qui met les cibles et bornes dans `Cfg` (AC3,
lignes 39–40) ; cette formulation est incompatible avec AC2 et avec le contrat
4B (AC1/AC4). Elle doit être amendée par l'orchestrateur après visa, pas ici.

## 2. Table propriétaire → consommateur

| Donnée | Propriétaire public et persistance | Consommateur autorisé | Règle d'écriture |
|---|---|---|---|
| `PresetConfirmMode`, `Initialized` | `GVL_IHM.Commun.EncoderCfg` → pont `FB_CfgPersistBridge_fbEncoder_Cfg` en `PRG_07` → `GVL_PERSISTENT._EncoderCfgPersist` | `PRG_02` câble le même `Cfg` aux deux façades | Pont seul écrivain ; `PRG_02` lit seulement |
| `CfgHomingTarget_M` M1 | `GVL_IHM.M1TreuilRetenue.Cfg` / `GVL_PERSISTENT._WinchM1CfgPersist` via le bridge Winch M1 | `PRG_02_Acquisition` → `instEncoderM1` | Réglage métier M1, jamais fusionné |
| `CfgHomingTarget_M` M2 | `GVL_IHM.M2TreuilBenne.Cfg` / `GVL_PERSISTENT._WinchM2CfgPersist` via le bridge Winch M2 | `PRG_02_Acquisition` → `instEncoderM2` | Réglage métier M2, jamais fusionné |
| `CfgTopSensorPos_M` M1/M2 | Même propriétaire que la ligne homing correspondante | `PRG_02_Acquisition` → façade M1/M2 | Deux valeurs conservées, même si initialement égales |
| `PointsPerRev`, `CableM_PerRev` | Constantes d'appel `PRG_02_Acquisition` | Façades M1/M2 et chaîne de mesure | Aucun pont IHM, aucune valeur dynamique |
| `PositionMinM`, `PositionMaxM` | Bornes techniques de `FB_Encoder` (défauts `-99.0/+99.0`) | `FB_Encoder_Safety` via la façade | Aucun champ IHM ; toute modification exige une décision safety |
| `Calib.Homed`, `Calib.HomingRefRaw`, `Calib.HomingSuspect` | `_CalibM1` / `_CalibM2` | `FB_Encoder_Homing` via `VAR_IN_OUT`, puis consommateurs publics | Résultat de calibration, jamais un réglage |

### Preuves de l'état actuel

- `ST_WinchCfg` porte bien les deux cibles métier aux lignes 6–16 de
  `CODE/J_SUPERVISION/_TYPES/1_TREUILS_BENNE/ST_WinchCfg.st`.
- Les deux persistances distinctes sont déclarées dans
  `CODE/GVL_PERSISTENT.st:40-55`, et les deux bridges sont appelés en
  `PRG_07_Supervision.st:115-123`.
- `PRG_02_Acquisition.st:345-363` câble les cibles M1 et
  `PRG_02_Acquisition.st:391-409` les cibles M2 ; la cible dynamique est
  réservée à M2 (`:374-404`).
- Les constantes de mesure sont dans `PRG_02_Acquisition.st:56-60`.
  Les bornes par défaut de la façade sont dans `FB_Encoder.st:42-45`.
- La séparation calibration/configuration est déjà matérialisée par
  `FB_Encoder.st:73-76` et `GVL_PERSISTENT.st:12-14`.

## 3. Pont HMI/persistance obligatoire

Le bridge 4B suit exactement le patron public déjà utilisé par le joystick :
`FB_CfgPersistBridge_fbJoystick_Cfg.st:13-26`, appelé depuis
`PRG_07_Supervision.st:135-138`. Au premier cycle où `Hmi.Initialized = FALSE`,
le pont fait `Hmi := Persist` et lève `JustRestored`; ensuite il fait
`Persist := Hmi` à chaque scan. Le même protocole est décrit dans
`PRG_07_Supervision.st:106-113`.

Interdits :

- pont dans `PRG_02_Acquisition` ou dans `FB_Encoder` ;
- écriture directe de `_EncoderCfgPersist` par un appelant métier ;
- canal GVL caché, copie partielle ou second écrivain ;
- ajout des cibles M1/M2 dans `_EncoderCfgPersist`.

Le chemin `GVL_IHM.Commun.EncoderCfg` est une décision d'architecture à
implémenter au lot 4B ; il n'est pas prétendu exister dans l'état courant.

## 4. Constantes, bornes et réglages IHM

| Élément | Valeur/règle figée | Interface IHM |
|---|---|---|
| `PointsPerRev` | `8192` pts/tour | Interdite |
| `CableM_PerRev` | `2.0` m/tour | Interdite |
| `PositionMinM` / `PositionMaxM` | `-99.0 / +99.0` m par défaut | Interdite |
| Cibles homing | bornage `[-99;+99] m` avant écriture | Pas d'édition à chaud ; service/CODESYS seulement |
| `BypassGlobal` | Mise en service, hors `ST_fbEncoder_Cfg` | Exposition existante distincte, ne pas élargir |

La règle de non-modification protège la chaîne `Req → Tgt → Cmd → Act` : une
cible métier (`Cfg...Target_M`) est validée puis consommée par le homing ; elle
ne doit pas être confondue avec un réglage technologique commun ni avec une
mesure (`...Act`). Les bornes et constantes ne sont pas des consignes opérateur.

## 5. Exception G127 — `FB_Encoder_Abs` OK-FIGÉ

L'exception est ciblée, documentée et non une allowlist générale. G127 impose
normalement qu'une sortie écrite après le gate soit affectée dans le gate
(`G127_check_neutralization_completeness.py:8-16`). Sur l'état actuel, le
script signale pour `FB_Encoder_Abs` `AngleRaw`, `PresetAck`, `PresetNak`,
`RawPos` et `TurnCount` comme sorties absentes du gate.

Pour AC3/T164-4C, `RawPos`, `AngleRaw` et `TurnCount` sont **OK-FIGÉ** dans le
gate `NOT Enable` :

- conserver la dernière valeur valide ;
- ne pas écrire `X := X` comme contournement ;
- ne pas remettre ces trois sorties à zéro ;
- ne pas lire `RawPosIn` dans le gate ;
- neutraliser les seuls ordres bus (`PresetTriggerCmd`, `CodeSeqTriggerCmd`,
  `PresetValueOut`) et publier l'état sûr.

Cette exception cesse d'inclure `PresetAck`/`PresetNak`, qui sont supprimés par
la décision preset et ne doivent plus faire partie de l'interface active. Aucun
autre FB ne bénéficie de cette exception ; les autres alertes G127 restent à
traiter dans leurs lots propres. La lecture position actuelle hors gate
(`FB_Encoder_Abs.st:100-108`) confirme que le gel concerne bien la mesure et non
la commande brute.

## 6. Causes publiques de la façade `FB_Encoder`

La façade doit alimenter `FB_FaultCore` uniquement avec des faits publics de ses
sous-FB ou des faits bruts de sa propre interface. Aucun accès à une `VAR` privée
(par exemple `PresetSeqStep`, `TargetPositionM` ou `RawDiff`) n'est admis. Le
socle `FB_FaultCore` impose que l'interlock lise la cause brute et non le latch
(`CODE/A_COMMUN/FB_FaultCore.st:9-15`).

| ID | Cause nommée façade | Source admise (publique) | Vue live | `Latching` / Reset |
|---:|---|---|---|---|
| 0 | `EncoderUnavailable` | `instAbs.EncoderAvailable = FALSE` (sortie publique) ou fait brut `Hw.SlaveOperational/AlarmsIn` | Oui, tant que la communication est KO | `FALSE` ; retombe seule, Reset sans effet |
| 1 | `EncoderPositionIncoherent` | `instSafety.EncoderIncoherent` (sortie publique) | Oui, tant que la mesure est incohérente | `FALSE` ; retour en plage, pas Reset |
| 2 | `HomingSuspect` | `instHoming.HomingSuspect` (sortie publique) | Oui, jusqu'à confirmation explicite | `FALSE` ; `ConfirmCoherence`/nouveau référencement, pas Reset |
| 3 | `HomingTargetOutOfRange` | Fait public nommé `instHoming.TargetOutOfRange` à exposer au lot 4C | Oui pendant le rejet | `FALSE` ; nouvelle évaluation, pas Reset |
| 4 | `PresetConfirmationFailed` | Fait public nommé `instHoming.PresetConfirmationFailed` (événement de séquence) | Oui sur l'échec | `TRUE` ; front Reset efface le latch, sans réécrire `Calib` |

`Status.ErrorId` d'un sous-FB peut rester publié pour compatibilité jusqu'à
T164-5, mais il ne constitue pas une table de causes façade et ne doit pas être
lu comme bitfield fusionné. `EncoderFault` et `HomedAndReliable` restent des
gates de fiabilité publics, pas des causes supplémentaires ; les interlocks
continuent de s'appuyer sur les faits bruts.

Le tableau est fermé : toute nouvelle cause nécessite un nom public, un
propriétaire, une polarité, une politique live/latch et un test avant ajout.
Le pattern `Ready`/`Fault`/`FB_FaultCore` est celui déjà visible dans
`FB_Joystick.st:67-86` et `:118-133`.

## 7. Invariant transactionnel preset (variante C)

La décision `DECISION_ENCODER_PRESET_TRANSACTION.md` est désormais **DÉCIDÉE**
(variante C : transaction réelle, confirmation par relecture). L'invariant à
implémenter au lot 4C est :

1. Front de référencement → valeur preset + front de commande ; attendre la
   latence `PresetLatencyCycles`.
2. Confirmer selon `Cfg.PresetConfirmMode`, avec `READBACK_ONLY` par défaut et
   `ABS(CablePosM - cibleAttendueM) <= CST_HomingVerifyToleranceM`.
3. **Succès uniquement** : écrire atomiquement `Calib.Homed := TRUE` et
   `Calib.HomingRefRaw := nouvelle valeur` au même instant.
4. Après N cycles sans confirmation (ex. écart 50 mm) : conserver la valeur
   antérieure de `Calib.Homed` et de `Calib.HomingRefRaw`, poser
   `Calib.HomingSuspect := TRUE` et publier `PresetConfirmationFailed` + son
   bit `ErrorId` dédié. Un Reset ne transforme pas cet échec en succès.

L'état actuel viole encore cet invariant : `FB_Encoder_Homing.st:181-203`
écrit la calibration avant le retour de preset et `FB_Encoder.st:129-137`
branche encore `PresetAck/PresetNak`. C'est une preuve de travail restant, pas
une autorisation de modifier le code dans T164-4A.

## 8. Devenir des ports `FwdRevSpeedFeedbackOff` / `BrakeFeedback`

**Décision : retirer ces deux ports de `FB_Encoder_Homing` au lot 4C.** Ils ne
font pas partie de la transaction de référencement et ne sont pas consommés
par le corps actuel de ce FB (`FB_Encoder_Homing.st:27-36` ne fait que les
déclarer). Ils ne sont donc ni recâblés vers la façade, ni déplacés dans
`ST_fbEncoder_Cfg`.

Les faits restent traçables dans leur domaine propriétaire :

| Fait brut | Propriétaire/consommateurs conservés | Preuve |
|---|---|---|
| `FwdRevSpeedFeedbackOff` | chaîne safety/mouvement `FB_Safety_Winch`, puis requêtes finales treuil | `PRG_04_Treuils_Benne.st:697-698`, `:753-754`, `:902-903`, `:917-918` |
| `BrakeFeedback` | chaîne safety/mouvement `FB_Safety_Winch` et barrière finale | `FB_Safety_Winch.st:30-31`, `:295-320` |

Si le homing devait un jour exiger une condition d'arrêt supplémentaire, ce
serait une nouvelle exigence métier/safety avec source publique et contrat
dédié ; elle ne doit pas être réintroduite comme port mort ou dépendance
implicite.

## 9. Risques ouverts et conditions de visa

- Le chemin `GVL_IHM.Commun.EncoderCfg` et le type `ST_fbEncoder_Cfg` sont
  décidés ici mais absents du code courant : le visa humain doit confirmer que
  `PresetConfirmMode` est un réglage commun M1/M2. S'il est différent par
  codeur, cette décision est insuffisante et doit être réouverte avant 4B.
- Le contrat interface conformance doit corriger AC3 pour ne pas contredire la
  séparation `ST_WinchCfg`/`ST_fbEncoder_Cfg`.
- `FB_Encoder_Abs` conserve aujourd'hui la forme et les ports legacy ; aucune
  suppression de `ST_EncoderHw` ni migration de code n'est décidée ici.
- Aucun export `Device.export`, bundle ou gate PLC ne constitue une preuve pour
  cette décision documentaire.
