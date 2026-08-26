# FB_Encoder_Abs — Spec composant (v1.1)

> Rôle machine : [`AF_Partie-09_Fonction_Encoder_v2.2.md`](../AF_Partie-09_Fonction_Encoder_v2.2.md)
> §5 — couvre `F09.01`.
> Rôle de **ce** document : détail acquisition bus EtherCAT + séquence preset SDO.
> Source code : `CODE/E_CODEURS/FB_Encoder_Abs.st` · sous-instance `instAbs` de `FB_Encoder`.

## 🧭 Sommaire

1. 🎯 Rôle et profil
2. 🧪 Points de validation (détail)
3. 🔌 Interface
4. ⚙️ Séquence preset SDO
5. 🔒 Gel sur doute
6. 📊 `ErrorId`
7. ⚠️ Alertes et écarts
8. 📚 Documents liés

## 1 · 🎯 Rôle et profil

Contrat `standard` (AF03) — remonte défaut bus/preset. Sous-instance privée de `FB_Encoder`, pas
appelée directement par un PRG. Ne décide rien : lit le bus EtherCAT, gèle la position sur perte
de disponibilité, exécute une séquence de preset sur demande (venant de `FB_Encoder_Homing`).

## 2 · 🧪 Points de validation (détail)

Décline `TC-P09-010` (chapô) :

> **Etat** ? `V` valid?, impl?mentation non v?rifi?e ? `V-I` valid? et impl?ment? ? `NV` non valid?, non impl?ment? ? `NV-I` code pr?sent mais non valid? ? `R` refus? ? `NA` non applicable.

| ID | Comportement attendu | Type | Réf | Etat |
|---|---|---|---|---|
| <nobr><code>TC-P09-010.1</code></nobr> | `AlarmsIn≠0` OU `NOT SlaveOperational` → `EncoderAvailable=FALSE`, `RawPos`/`AngleRaw`/`TurnCount` gelés (dernière valeur) | <nobr><code>💻 AUTO</code></nobr> | §5 | `NV-I` |
| <nobr><code>TC-P09-010.2</code></nobr> | Preset : écart `abs(RawPos - PresetValueOut) ≤ PresetTolerancePts` → `PresetAck` après 500ms visuel ; sinon timeout `PresetTimeout` → `PresetNak` + `ErrorId` bit1 | <nobr><code>💻 AUTO</code></nobr> | §4 | `NV-I` |

## 3 · 🔌 Interface

### Entrées (`VAR_INPUT`)

| Port | Type | Rôle |
|---|---|---|
| `Enable` | `BOOL` | Autorisation générale |
| `Reset` | `BOOL` | Acquittement défaut (front) |
| `PresetRequest` | `BOOL` | Demande de preset (front) |
| `RawPosIn` | `UDINT` | Position brute EtherCAT |
| `AlarmsIn` | `UINT` | Code alarme brut EtherCAT (seul lu — voir §7) |
| `WarningsIn` | `UINT` | ⚠️ Déclaré, **jamais lu** dans la logique — port mort |
| `SlaveOperational` | `BOOL` | Statut esclave EtherCAT |
| `PointsPerRev` | `UDINT` | Résolution codeur (déf. 8192) |
| `PresetValue` | `UDINT` | Valeur cible de preset |
| `PresetTimeout` | `TIME` | Timeout séquence (déf. 2s) |
| `PresetTolerancePts` | `UDINT` | Tolérance relecture (déf. 10 pts) |

### Sorties (`VAR_OUTPUT`)

| Port | Type | Rôle |
|---|---|---|
| `Ready` | `BOOL` | FB prêt |
| `Status` | `ST_FbStatus` | Statut (Busy/Done/Error/ErrorId — rempli à plat, T137) |
| `RawPos` | `UDINT` | Position brute (gelée si non disponible) |
| `EncoderAvailable` | `BOOL` | Bus/esclave opérationnels |
| `AngleRaw` | `UINT` | Angle sur un tour (`RawPos MOD PointsPerRev`) |
| `TurnCount` | `UDINT` | Nombre de tours (`RawPos / PointsPerRev`) |
| `PresetAck` / `PresetNak` | `BOOL` | Pulse 1 cycle succès/échec preset |
| `PresetTriggerCmd` / `CodeSeqTriggerCmd` | `WORD` | Ordres PDO Rx (`CodeSeqTriggerCmd` jamais piloté, voir §6) |
| `PresetValueOut` | `UDINT` | Valeur de preset transmise au PDO Rx |

## 4 · ⚙️ Séquence preset SDO

| Étape | `PresetSeqStep` | Action | Sortie |
|---|---|---|---|
| IDLE | 0 | Attend front `PresetRequest` (si `EncoderAvailable`) | `PresetTriggerCmd=0` |
| Déclenchement | 1 | `PresetTriggerCmd:=2` (référence à `PresetValueOut`) | Timer `PresetTimeout` armé |
| Succès | 1→0 | `\|RawPos-PresetValueOut\| ≤ PresetTolerancePts` → maintien 500ms visuel puis `PresetAck` | `PresetTriggerCmd=0` |
| Échec | 1→0 | Timeout sans convergence → `PresetNak`, `ErrorId` bit1 | `PresetTriggerCmd=0` |

`CodeSeqTriggerCmd` toujours à `16#0000` — rôle non identifié sur le bus (voir §7).

### Chronogramme — preset réussi

| Instant | `PresetRequest` | `PresetSeqStep` | `PresetTriggerCmd` | `PresetAck` |
|---|---|---|---|---|
| t0 — repos | FALSE | 0 (IDLE) | 0 | FALSE |
| t1 — front demande | TRUE ↑ | 1 | 2 | FALSE |
| t2 — écart ≤ tolérance | TRUE | 1 | 2 | FALSE *(maintien visuel 500ms en cours)* |
| t3 — +500ms | TRUE | 0 | 0 | **TRUE** ↑ *(pulse 1 cycle)* |

Si l'écart ne converge pas avant `PresetTimeout` (déf. 2s) : `PresetNak` à la place de `PresetAck`
à t3, `ErrorId` bit1 levé, retour direct à `PresetSeqStep=0`.

## 5 · 🔒 Gel sur doute

Tant que `NOT EncoderAvailable` (bus/esclave KO), `RawPos`/`AngleRaw`/`TurnCount` **conservent leur
dernière valeur** — aucune écriture, pas de retour à 0. La lecture est gelée, mais **pas** tout le
FB : la séquence preset et l'état continuent d'être évalués (pas de `RETURN` global), pour ne pas
bloquer un preset déjà en cours si le bus revient pendant la séquence.

## 6 · 📊 `ErrorId`

| Bit | Cause | Catégorie |
|---|---|---|
| 0 | Bus/esclave KO (`AlarmsIn≠0` ou `NOT SlaveOperational`) | Auto-effaçable |
| 1 | Preset refusé/timeout | Effacé par `Reset` (front, si séquence IDLE) |

## 7 · ⚠️ Alertes et écarts

| # | Gravité | Point | Action |
|---|---|---|---|
| 1 | P2 | `CodeSeqTriggerCmd` — rôle non identifié sur le bus | Laissé à 0 par construction, ne jamais le piloter tant que non confirmé (commentaire code explicite) |
| 2 | mineur | `WarningsIn` déclaré, jamais lu dans la logique | Port mort, à retirer lors d'un lot dédié (hors périmètre doc) |

## 8 · 📚 Documents liés

| Doc | Lien |
|---|---|
| AF09 (chapô) | Rôle machine, façade `FB_Encoder`, intégration programme |
| AF03 | Contrat `standard`, tolérance T137 |
| Code | `CODE/E_CODEURS/FB_Encoder_Abs.st` |
