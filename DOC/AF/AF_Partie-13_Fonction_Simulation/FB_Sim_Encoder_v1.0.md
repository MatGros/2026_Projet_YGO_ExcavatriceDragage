# FB_Sim_Encoder — Spec composant (v1.0)

> Rôle machine (vague) : [`AF_Partie-13_Fonction_Simulation_v2.4.md`](../AF_Partie-13_Fonction_Simulation_v2.4.md) §4.
> Rôle de **ce** document : modèle simulé d'un codeur absolu de treuil — et **catalogue unique**
> des `TC-P13-030...`.
> Source code : `CODE/L_SIMULATION/FB_Sim_Encoder.st` · instances `FB_SimBench.instSimEncoderM1/M2`.

## 🧭 Sommaire

1. Rôle et profil
2. Interface
3. Persistance `RawPos`
4. Documents liés

## 🧪 Points de validation (`TC-P13-030...` — propriétaire unique)

> **État** — `V` validé, implémentation non vérifiée · `V-I` validé et implémenté · `NV` non validé, non implémenté · `NV-I` code présent mais non validé · `R` refusé · `NA` non applicable.

| ID | Intention / Comportement attendu | Type | Etat |
|---|---|---|---|
| <nobr><code>TC-P13-030</code></nobr> | `RelayFwd`/`RelayRev` font compter `RawPos` de `SpeedTgt_Pct * 0.1 * SpeedScaleFactor` par scan | `💻 AUTO` | `NV` |
| <nobr><code>TC-P13-031</code></nobr> | `PresetCmd=TRUE` charge `PresetValue` directement (priorité sur Fwd/Rev) | `💻 AUTO` | `NV` |
| <nobr><code>TC-P13-032</code></nobr> | `RawPos` ne descend jamais sous 0 (borne explicite en soustraction) | `💻 AUTO` | `NV` |
| <nobr><code>TC-P13-033</code></nobr> | `RawPos` survit à un reset froid (via `VAR_IN_OUT` référençant `GVL_PERSISTENT`) | `👁️ MANUEL` | `NV` |

---

## 1. Rôle et profil

🧩 Brique réduite (`AF_Partie-03 §2`) : pas de contrat `Enable/Reset/Error` complet — outil de banc.
Fait « compter » un codeur absolu comme si le treuil tournait réellement, à partir des relais de
sens commandés et de la vitesse rampée courante. Extraction pure d'une logique déjà en place dans
l'ancien `PRG_02_Encoders.st` (bloc « SIMULATION SUR BANC DE TEST ») — aucun changement de
comportement lors de l'extraction, juste dissociation en FB dédié.

Deux instances : une par treuil (M1/M2), câblées depuis `FB_SimBench`.

---

## 2. Interface

| Entrée | Type | Sens |
|---|---|---|
| `Enable` | BOOL | Simulation active (`SimulationModeActive AND NOT BusEncoderMxIsReal`) |
| `RelayFwd`/`RelayRev` | BOOL | Sens commandé (contacteurs de sens du treuil) |
| `SpeedTgt_Pct` | REAL | Vitesse rampée courante (magnitude, %) |
| `PresetCmd` | BOOL | TRUE le cycle où un preset (homing) doit être appliqué |
| `PresetValue` | UDINT | Valeur brute à charger lors du preset |
| `SpeedScaleFactor` | REAL | Multiplicateur confort de test banc (défaut 1.0), `GVL_Simulation.SimEncoderSpeedFactor` |
| `TestOffsetCmd`/`TestOffsetPts` | BOOL / DINT | Front = injecte un vrai saut de position (test Méca E / rattrapage synchro) |

| Sortie/IN_OUT | Type | Sens |
|---|---|---|
| `RawPosOut` | UDINT | Position brute simulée, à aiguiller à la place de la valeur EtherCAT réelle |
| `RawPos` (`VAR_IN_OUT`) | UDINT | Référence `_SimEncoderRawPosM1/M2` dans `GVL_PERSISTENT` |

---

## 3. Persistance `RawPos`

`RawPos` est passé en `VAR_IN_OUT`, référencé depuis `GVL_PERSISTENT` — pas de champ interne au
FB. `PERSISTENT` n'est valide que sur du `VAR_GLOBAL` en CODESYS, pas sur une variable locale de
FB (`VAR RETAIN`/`VAR PERSISTENT RETAIN` locaux testés, aucun ne convient). Un vrai codeur absolu
physique conserve son comptage brut à travers un reset froid, indépendamment de l'automate — le
modèle simulé doit reproduire ce comportement pour rester représentatif d'un test de reprise après
coupure.

---

## 4. Documents liés

| Doc | Lien |
|---|---|
| AF13 (chapô) | Frontière simulation §2 (aiguillage `WinchInputSourceSimulated`) |
| AF09/AF10 | `FB_Encoder_Abs`, `FB_Encoder_Homing` (consommateurs réels de `RawPosOut`) |
| Code | `CODE/L_SIMULATION/FB_Sim_Encoder.st`, `CODE/GVL_PERSISTENT.st` |
