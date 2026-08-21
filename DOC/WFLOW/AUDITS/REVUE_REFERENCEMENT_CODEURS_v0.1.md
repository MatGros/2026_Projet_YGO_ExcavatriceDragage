# 🧭 T146 — Référencement / Homing des codeurs : état incohérent, suspect & référencé — Revue critique (v0.1)

> 📄 Statut : **ÉTUDE (lecture seule, zéro code)** · 📅 2026-08-21 · 🧠 Challenge par DSH-02
> 🎯 Objectif : mettre à plat la machine à états référencement des codeurs M1/M2, identifier doublons/excès,
> et proposer un **bit unique « mesure fiable »** + **bits « au-dessus limite »** pour simplifier les comparaisons.
> 🔗 Source : `CODE/E_CODEURS/*.st`, câblage `CODE/M_MAIN/PRG_02_Acquisition.st §4`, `AF_Partie-09/10`.

---

## 1. 🏗️ Chaîne codeur (par treuil, ex. M1) — pipeline

```
FB_Encoder_Abs ─ RawPos ─┬→ FB_Encoder_Scale ─ CablePosM ─→ FB_Encoder_Safety ─ CablePosMSafe ─┬→ FB_Encoder_SpeedMeasure
      │ (bus EtherCAT)    │        (points→mètres)                  │ (bornage + suspect)          │
      │ EncoderAvailable  │                                        │ EncoderIncoherent            │
      └───────────────────┼→ FB_Encoder_Homing ─ Homed/HomingSuspect/HomingRefRaw ─┐               │
                          └──────────────────────────────────────────────────────────┴→ (Safety lit HomingSuspect)
```

| # | FB | Rôle | Sorties clés |
|---|---|---|---|
| 1 | `FB_Encoder_Abs` | Accès bus, extraction brute, preset | `EncoderAvailable` (bus+esclave OK), `RawPos` |
| 2 | `FB_Encoder_Homing` | Référencement nominal/unitaire/dynamique + contrôle cohérence boot | `Homed`, `HomingSuspect`, `HomingRefRaw`, `Calib` (RETAIN) |
| 3 | `FB_Encoder_Scale` | `CablePosM = (RawPos − HomingRefRaw) / 4096` | `CablePosM` |
| 4 | `FB_Encoder_Safety` | Bornage physique + relais suspect | `CablePosMSafe`, `EncoderIncoherent` |
| 5 | `FB_Encoder_SpeedMeasure` | Vitesse fenêtre 50 ms | `Speed_Mps`, `Valid` |

---

## 2. 📊 États & leurs sources (per treuil)

| État | Définition | Source | RETAIN |
|---|---|---|---|
| `EncoderAvailable` | bus EtherCAT + esclave opérationnels, pas d'alarme | `FB_Encoder_Abs` (bit0) | non |
| `Calib.Homed` | un référencement a **déjà réussi** | `ST_Encoder_Calib` | ✅ oui |
| `Calib.HomingSuspect` | **incohérence détectée au redémarrage** (dérive > tolérance) | `FB_Encoder_Homing` §3.7 | ✅ oui |
| `Homed` (sortie) | **référencé ET pas suspect** = `Calib.Homed AND NOT Calib.HomingSuspect` | `FB_Encoder_Homing` | — (dérivé) |
| `HomingSuspect` (sortie) | `Calib.HomingSuspect` (miroir) | `FB_Encoder_Homing` | — (dérivé) |
| `EncoderIncoherent` | **hors bornes [-99,+99] OU HomingSuspect** | `FB_Encoder_Safety` | non |
| `CablePosMSafe` | ⚠️ **passthrough** de `CablePosM` (NON validé malgré le nom) | `FB_Encoder_Safety` | non |

---

## 3. 🚦 Cas de démarrage — tableau exhaustif

| # | Cas | `Calib.Homed` | Dérive>tol | `HomingSuspect` | `Homed` | `EncoderIncoherent` | Position **fiable** ? |
|---|---|---|---|---|---|---|---|
| 1 | **Jamais homé, dans bornes** | FALSE | — | FALSE | FALSE | FALSE | ❌ **crue à tort** (défaut fail-safe) |
| 2 | **Jamais homé, hors bornes** | FALSE | — | FALSE | FALSE | TRUE | ❌ rejetée |
| 3 | **Homé, cohérent** | TRUE | non | FALSE | TRUE | FALSE | ✅ fiable |
| 4 | **Homé, suspect** (dérive au boot) | TRUE | oui | TRUE | FALSE | TRUE | ❌ rejetée → `BtnConfirmCoherence` requis |

> 🔴 **Cas 1 = le trou** : un codeur jamais homé mais dont le brut tombe dans les bornes donne
> `EncoderIncoherent = FALSE` → les consommateurs qui ne vérifient QUE `NOT EncoderIncoherent`
> (ex. interlock hauteur M3) **croient la position**. C'est le défaut relevé à la revue T146.

---

## 4. 🔍 Doublons, excès & incohérences identifiés

| # | Problème | Détail |
|---|---|---|
| D1 | **`CablePosMSafe` est un nom trompeur** | Il **passe la valeur brute même incohérente** — le suffixe `Safe` laisse croire qu'elle est validée. C'est un passthrough pur. |
| D2 | **La « fiabilité » est éclatée** | Chaque consommateur **recompose** sa propre condition : `EncoderAvailable AND NOT EncoderIncoherent` (speed), `Homed` (FB_Winch/Bucket/Sync), `NOT EncoderIncoherent` (interlock hauteur M3). Risque d'incohérence entre eux. |
| D3 | **`Homed` et `EncoderIncoherent` se recouvrent** | Tous deux intègrent `HomingSuspect` : si suspect, `Homed=FALSE` **et** `EncoderIncoherent=TRUE`. Redondant mais cohérent — à conserver tel quel, pas à fusionner aveuglément. |
| D4 | **`HomingSuspect` est exposé 2×** | `Calib.HomingSuspect` (RETAIN) + sortie `HomingSuspect` (miroir). Un seul suffit si on expose via struct. |
| D5 | **Le cas « jamais homé » n'est pas un état explicite** | Il n'existe aucun bit « **référencé** » au sens large ; `Homed` (sortie) est le seul, mais il n'est pas consommé par l'interlock hauteur. |

---

## 5. 💡 Proposition — un bit « mesure fiable » + bits « au-dessus limite »

### 5.1 Bit unique `HomedAndReliable` (par treuil)

Consolider la fiabilité de la valeur numérique en **un seul bit**, produit par un **helper pur `FB_EncoderReliability`**
(prend `EncoderAvailable` + `Homed` + `EncoderIncoherent` en entrée, sort le bit — scinde les responsabilités :
Homing = référencement, Safety = cohérence, helper = « le codeur est fiable »). Exposé dans `ST_EncoderMeasurement` :

```iecst
HomedAndReliable := EncoderAvailable AND Homed AND NOT EncoderIncoherent;
```

- `Homed` (= référencé ET pas suspect) → ferme le **trou du cas 1** (jamais homé ⇒ non fiable).
- `NOT EncoderIncoherent` → exclut hors bornes + suspect (défense en profondeur).
- `EncoderAvailable` → exclut bus perdu.

⚠️ **Bypass** : si `FB_Encoder_Safety` est bypassé, `EncoderIncoherent=FALSE` → le helper peut sortir « fiable »
même si le bornage est neutralisé. Acceptable pour l'interlock hauteur (`Bypass.MinHeight` couvre l'opérateur),
mais **à documenter** (un bypass Safety ≠ « mesure fiable » sans alerte).

**Effet** : chaque consommateur lit `M1_HomedAndReliable` au lieu de recomposer les conditions.
L'interlock hauteur M3 devient :

```iecst
M3_HeightInterlockOk := Bypass.MinHeight
                        OR (PRG_02_Acquisition.Data.M1_HomedAndReliable
                            AND PRG_02_Acquisition.Data.M2_HomedAndReliable
                            AND M1_AboveMinHeight
                            AND M2_AboveMinHeight);
```

### 5.2 Bits « au-dessus limite » (par seuil métier)

Remplacer les `CablePosM >= X` dispersés par un bit calculé une seule fois (fiabilité incluse) :

```iecst
M1_AboveMinHeight := M1_HomedAndReliable AND CablePosM1 >= _TranslationMinHeightM1M2_M;
M2_AboveMinHeight := M2_HomedAndReliable AND CablePosM2 >= _TranslationMinHeightM1M2_M;
```

→ La comparaison devient lisible : « le treuil est au-dessus de la limite, point. »

### 5.3 Assainissement

- **Retirer / renommer `CablePosMSafe`** (trompeur) : soit `CablePosM` simple, soit le rendre réellement
  « safe » (gel à la dernière valeur fiable). À trancher.
- **Exposer la fiabilité dans `ST_EncoderMeasurement`** (`HomedAndReliable`) et supprimer les
  recompositions locales.

---

## 6. ⚖️ Challenges & questions ouvertes

| # | Question | Impact |
|---|---|---|
| C1 | Faut-il exiger `Homed` dans `HomedAndReliable` ? | **✅ VALIDÉ (utilisateur)** : fail-safe. ⚠️ **Correction** : l'interlock hauteur M3 ne lit **que** `NOT EncoderIncoherent` (jamais `Homed`) — donc aujourd'hui un codeur jamais homé dans bornes est **cru**. Passer à `HomedAndReliable` le bloque (plus restrictif). Le doute se lève via `BtnConfirmCoherence`, dispo en **MAINT_N1 OU MAINT_N2** (`FB_Encoder_Homing` l.143). |
| C2 | `HomedAndReliable` doit-il inclure le hors-bornes (`EncoderIncoherent`) ? | Oui — un codeur homé qui dérive hors bornes en marche serait sinon cru (`Homed` reste TRUE, `HomingSuspect` ne couvre que le boot). |
| C3 | `CablePosMSafe` : renommer ou rendre réellement safe ? | Décision à prendre (convention / blast radius). |
| C4 | Où exposer `HomedAndReliable` ? | `ST_EncoderMeasurement` (par treuil) + `Data` bus de PRG_02. |
| C5 | Faut-il un FB helper (`FB_EncoderReliability`) ou une simple expression dans `PRG_02` ? | **✅ RÉSOLU (utilisateur)** : helper pur `FB_EncoderReliability` (testable, scinde les responsabilités). |

---

## 7. 🏁 Verdict provisoire

- La chaîne codeur est **saine mais la « fiabilité » est éclatée** et **un cas fail-safe est ouvert** (jamais homé dans bornes).
- **Recommandation** : ajouter `HomedAndReliable` (bit unique par treuil, helper `FB_EncoderReliability`) + bits `AboveXxxLimit`,
  renommer `CablePosMSafe`, et réécrire l'interlock hauteur M3 sur ces bits.
- **Phase étude — zéro code** tant que la décision C3 (`CablePosMSafe`) n'est pas validée par l'humain. C1 (exiger `Homed`) est **validé**.

---

📖 Liens : [`../PLAN_TASK.md`](../PLAN_TASK.md) → **T146** · [`TRACE_ACTIONS_T146_REFERENCEMENT_CODEURS.md`](TRACE_ACTIONS_T146_REFERENCEMENT_CODEURS.md) · [`REVUE_SYNCHRO_TREUILS_v0.1.md`](REVUE_SYNCHRO_TREUILS_v0.1.md) (volet D-P10). Dépendance : correctif d'écriture `M3_HeightInterlockOk` (Homed vs Incoherent).
