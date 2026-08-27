# FB_Encoder_Safety — Spec composant (v1.1)

> Rôle machine : [`AF_Partie-09_Fonction_Encoder_v2.2.md`](../AF_Partie-09_Fonction_Encoder_v2.2.md)
> §6 — couvre `F09.05`.
> Rôle de **ce** document : bornage physique et relais de cohérence redémarrage.
> Source code : `CODE/E_CODEURS/FB_Encoder_Safety.st` · sous-instance `instSafety` de `FB_Encoder`.

## 🧭 Sommaire

1. 🎯 Rôle et profil
2. 🧪 Points de validation (détail)
3. 🔌 Interface
4. 🛡️ Bornage & relais cohérence
5. 📊 `ErrorId`
6. ⚠️ Alertes et écarts
7. 📚 Documents liés

## 1 · 🎯 Rôle et profil

Contrat `standard` (AF03) — remonte défaut bornage/cohérence. Ne calcule pas la position
(reçue de `FB_Encoder_Scale`), ne décide pas de fiabilité globale (`FB_EncoderReliability` en
aval) : ce FB **verrouille** la mesure sûre et relaie l'alerte cohérence.

## 2 · 🧪 Points de validation (détail)

Décline `TC-P09-030` (chapô) :

> **Etat** ? `V` valid?, impl?mentation non v?rifi?e ? `V-I` valid? et impl?ment? ? `NV` non valid?, non impl?ment? ? `NV-I` code pr?sent mais non valid? ? `R` refus? ? `NA` non applicable.

| ID | Comportement attendu | Type | Réf | Etat |
|---|---|---|---|---|
| <nobr><code>TC-P09-030.4</code></nobr> | `CablePosM` hors `[PositionMinM;PositionMaxM]` (déf. ±99m) → `EncoderIncoherent=TRUE`, bit0, auto-effacé au retour en plage | <nobr><code>💻 AUTO</code></nobr> | §4 | `NV` |
| <nobr><code>TC-P09-030.5</code></nobr> | `HomingSuspect=TRUE` → `EncoderIncoherent=TRUE`, bit1, tant que non confirmé | <nobr><code>💻 AUTO</code></nobr> | §4 | `NV` |
| <nobr><code>TC-P09-030.6</code></nobr> | `BypassGlobal=TRUE` → neutralise les 2 causes (mise en service) | <nobr><code>💻 AUTO</code></nobr> | §4 | `NV` |
| <nobr><code>TC-P09-030.7</code></nobr> | `CablePosMSafe` = `CablePosM` toujours (jamais gelée — distinct du gel `RawPos` côté Abs) | <nobr><code>💻 AUTO</code></nobr> | §4 | `NV` |

## 3 · 🔌 Interface

### Entrées (`VAR_INPUT`)

| Port | Type | Rôle |
|---|---|---|
| `Enable` / `Reset` | `BOOL` | Standard |
| `CablePosM` | `REAL` | Position calculée (`FB_Encoder_Scale`) |
| `HomingSuspect` | `BOOL` | Alerte incohérence redémarrage (`FB_Encoder_Homing`) |
| `PositionMinM` / `PositionMaxM` | `REAL` | Bornage physique (déf. ±99.0m) |
| `BypassGlobal` | `BOOL` | Neutralise les 2 défauts (mise en service) |

### Sorties (`VAR_OUTPUT`)

| Port | Type | Rôle |
|---|---|---|
| `Ready` | `BOOL` | FB prêt |
| `Status` | `ST_Status` | Statut (ErrorId bitfield, rempli à plat) — type legacy, cible `Fault : ST_Fault` via `FB_FaultCore` (AF03 §3), migration T164-5 |
| `CablePosMSafe` | `REAL` | Position transmise (toujours réelle, non figée) |
| `EncoderIncoherent` | `BOOL` | Incohérence ou hors bornes (`= Status.Error`) |

## 4 · 🛡️ Bornage & relais cohérence

| Mécanisme | Détection | Effet |
|---|---|---|
| Bornage physique (bit0) | Hors `[PositionMinM;PositionMaxM]` | `EncoderIncoherent=TRUE`, auto-effacé au retour |
| Relais cohérence (bit1) | `HomingSuspect=TRUE` | `EncoderIncoherent=TRUE`, tant que non confirmé côté Homing |
| `BypassGlobal` | — | Neutralise les 2 causes ci-dessus |

`CablePosMSafe` **n'est jamais gelée** ici — c'est la transmission continue de la mesure. Le gel
sur perte de disponibilité a déjà eu lieu en amont, côté `FB_Encoder_Abs` (`RawPos`).

## 5 · 📊 `ErrorId`

| Bit | Cause | Catégorie |
|---|---|---|
| 0 | Hors bornage `[PositionMinM;PositionMaxM]` | Auto-effaçable |
| 1 | `HomingSuspect=TRUE` | Auto-effaçable (suit l'état Homing, pas latché ici) |

## 6 · ⚠️ Alertes et écarts

Aucun écart identifié — FB simple, conforme au code vérifié.

## 7 · 📚 Documents liés

| Doc | Lien |
|---|---|
| AF09 (chapô) | Rôle machine, façade `FB_Encoder` |
| AF03 | Contrat `standard` |
| Code | `CODE/E_CODEURS/FB_Encoder_Safety.st` |
