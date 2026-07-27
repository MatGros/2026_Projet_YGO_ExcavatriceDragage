# 🏷️ TABLE DE RENOMMAGE — Variables d'E/S device (v1.0)

> 🎯 Lever les ambiguïtés de polarité **à la source**. Le nom doit répondre à : *que signifie `TRUE` ?*
> 📅 2026-07-27 · 🟢 **APPLIQUÉ ET ALIGNÉ** dans `Device.export` et dans tout `CODE/` (`PRG_00_Inputs`, `PRG_08_AuxiliaryControl`, `PRG_10_Outputs`).
> ⚠️ Déclencheur : bug **C1** (polarité retour frein) — un nom muet sur sa polarité a coûté un vrai défaut.

## ✅ Convention retenue — courte, la fonction principale dans le nom

```
<Domaine>_<ÉtatQuandTRUE>_DI      M1_BrakeIsOpen_DI    → TRUE = frein ouvert
<Domaine>_<ActionCommandée>_RQ    M1_BrakeRelease_RQ   → TRUE = desserrage commandé
```
La traçabilité ancien → nouveau est assurée **par cette table**, pas par un nom à rallonge.

⚠️ **Après chaque renommage, vérifier le nom obtenu** : CODESYS suffixe silencieusement en cas de
collision (c'est ce qui a produit `PosPV_DI_` et cassé le capteur PV).

---

## 1. 📥 ENTRÉES TOR

| # | Nom actuel | `TRUE` signifie | ➜ Nom cible | Prio |
|---|---|---|---|---|
| 1 | `M1_BrakeFeedback_BrakeIsOpen_DI` ¹ | frein **OUVERT** | **`M1_BrakeIsOpen_DI`** | 🔴 |
| 2 | `M2_BrakeFeedback_BrakeIsOpen_DI` ¹ | frein **OUVERT** | **`M2_BrakeIsOpen_DI`** | 🔴 |
| 3 | `M3_BrakeFeedback_BrakeIsOpen_DI` ¹ | frein **OUVERT** | **`M3_BrakeIsOpen_DI`** | 🔴 |
| 4 | `EmergencyStopOk_DI` | contacteur de **puissance engagé** (⚠️ pas la boucle AU) | **`PowerContactorEngaged_DI`** | 🔴 |
| 5 | `M1_M2_TopPositionSensor_DI` | butée haute **LIBRE** (NC) | **`M1M2_TopPositionFree_DI`** | 🔴 |
| 6 | `M2_SlackCableSwitch_DI` | câble **TENDU** (NC) | **`M2_TensionedCable_DI`** | 🔴 |
| 7 | `EmergencyChainOK_DI` | boucle AU **fermée** | **`EmergencyChainClosed_DI`** | 🟠 |
| 8 | `CtrlPhaseRotation_DI` | phases correctes | **`PhaseRotationOk_DI`** | 🟠 |
| 9 | `BrakeThermalFeedback_DI` | temp. frein OK (**commun M1/M2/M3**) | **`BrakeThermalOk_DI`** | 🟠 |
| 10 | `M1_ThermalFeedback_DI` | temp. moteur OK | **`M1_ThermalOk_DI`** | 🟠 |
| 11 | `M2_ThermalFeedback_DI` | temp. moteur OK | **`M2_ThermalOk_DI`** | 🟠 |
| 12 | `M1_FwdRevSpeedFeedbackOff_DI` | **tous** contacteurs sens+vitesse retombés | **`M1_ContactorsReleased_DI`** | 🟠 |
| 13 | `M2_FwdRevSpeedFeedbackOff_DI` | idem | **`M2_ContactorsReleased_DI`** | 🟠 |
| 14 | `ThermHydraulique_DI` | temp. centrale OK | **`HydraulicThermalOk_DI`** | 🟠 |
| 15 | `PosTremie_DI` | position trémie atteinte | **`M3_PosTremie_DI`** | 🟡 |
| 16 | `PosPV_DI` 🐛 | zone PV atteinte | **`M3_PosPV_DI`** ⚠️ voir §3 | 🔴 |
| 17 | `PosFosse2_DI` | position P2 atteinte | **`M3_PosP2_DI`** | 🟡 |
| 18 | `PosFosse1_DI` | position P1 atteinte | **`M3_PosP1_DI`** | 🟡 |
| 19 | `PosMaintenance_DI` | position maintenance atteinte | **`M3_PosMaintenance_DI`** | 🟡 |
| 20 | `KoboldContactFond_DI` | ⚠️ **signal à 3 temps, voir §3bis** | **`M1_M2_KoboldContactFond_DI`** (sert aux 2 treuils) | 🔴 |

¹ passés par une version longue intermédiaire le 27/07, puis raccourcis. ✅ **Tous appliqués.**

## 2. 📤 SORTIES

| # | Nom actuel | `TRUE` commande | ➜ Nom cible | Prio |
|---|---|---|---|---|
| 21 | `M1_BrakeCmd_RQ` | **desserrage** (frein à manque de courant) | **`M1_BrakeRelease_RQ`** | 🔴 |
| 22 | `M2_BrakeCmd_RQ` | idem | **`M2_BrakeRelease_RQ`** | 🔴 |
| 23 | `M3_BrakeCmd_RQ` | idem | **`M3_BrakeRelease_RQ`** | 🔴 |
| 24 | `PowerCutOff_A_RQ` | ⚠️ **puissance MAINTENUE** (fail-safe) | **`PowerKeepAlive_A_RQ`** | 🔴 ² |
| 25 | `PowerCutOff_B_RQ` | idem | **`PowerKeepAlive_B_RQ`** | 🔴 ² |
| 26 | `M3_RelayFwd_DQ` / `M3_RelayRev_DQ` | forcés `FALSE` — M3 piloté par le variateur | 🗑️ **SUPPRIMÉS** (device + `PRG_10:133-134`) | 🔴 |
| 27 | `M1_RelayFwd_DQ` | montée treuil retenue | **`M1_RelayFwd_Up_DQ`** | 🟠 |
| 28 | `M1_RelayRev_DQ` | descente treuil retenue | **`M1_RelayRev_Down_DQ`** | 🟠 |
| 29 | `M2_RelayFwd_DQ` | montée treuil **OU fermeture benne** | **`M2_RelayFwd_Up_Close_DQ`** | 🟠 |
| 30 | `M2_RelayRev_DQ` | descente treuil **OU ouverture benne** | **`M2_RelayRev_Down_Open_DQ`** | 🟠 |
| 31 | `M1/M2_SpeedContactor_1..4_DQ` | palier engagé | *inchangé* ✅ | — |
| 32 | `KoboldContactor_DQ` | **active la mesure de captage du fond** (voir §3bis) | **`M1_M2_KoboldMeasureEnable_DQ`** | 🟠 |
| 33 | `EmergencyArming_RQ` | impulsion de réarmement | *inchangé* ✅ | — |

👉 **Sens des relais M1/M2** ajouté dans le nom (demande utilisateur) : un mainteneur lit
directement l'effet machine, sans avoir à se souvenir que `Fwd` sur M2 signifie aussi
« fermeture benne ».

² 🛑 **À renommer SEUL**, avec revérification de la séquence de réarmement (auto-test A/B).
Jamais dans un lot groupé — c'est la chaîne de sécurité.

## 3. ✅ Cas particulier — capteur PV : **CORRIGÉ le 2026-07-27** (T80)

La voie était mappée sous `PosPV_DI_` (underscore ajouté par CODESYS sur collision) et le
programme lisait `GVL_Translation_M3_Stub.PosPV_DI`, un stub que rien n'écrivait → capteur PV
non relié ⇒ mot incohérent en Trémie ⇒ `SafeStop` + `PowerCutOff`, butées extrêmes inopérantes.

**Correction appliquée** : déclaration retirée du stub · voie renommée `M3_PosPV_DI` ·
`PRG_00_Inputs` lit la variable d'E/S. `StubTranslationPositionSelect_IHM` conservé (consommé).

🧪 **Test terrain restant** : en position Trémie, vérifier `SensorsWord = 11111`,
`SensorWordIncoherent = FALSE`, aucun `SafeStop`/`PowerCutOff`, puis le ralentissement PV.

## 3bis. 🪨 Détecteur de fond Kobold — sémantique réelle (⚠️ information nouvelle 2026-07-27)

Le signal **n'est pas** un simple « contact fond ». C'est un signal à **3 temps**, lié à l'immersion :

| Phase | `M1_M2_KoboldContactFond_DI` |
|---|---|
| Benne **hors de l'eau**, en descente | `0` |
| Benne **immergée**, en eau libre | `1` |
| Benne **posée au fond** | `0` |

👉 **`0` seul ne veut rien dire** : il signifie « hors de l'eau » *ou* « au fond ».

```
Fond détecté  ⟺  retour info = 0  ET  benne immergée
```

L'immersion doit être déduite de la **position des treuils** (ex. profondeur < −0,5 m, seuil à
définir sur site) : il faut donc une **séquence de cohérence position ↔ capteur**.

### 🚨 Conséquence — la logique actuelle est incomplète

`FB_Cycle.st:272` teste `IF CycleMotionPermit AND KoboldContactFond THEN` → transition
`BOTTOM_TOUCH_WAIT`. Le test porte sur l'état `TRUE`, c'est-à-dire **l'immersion**, pas le fond.
👉 À instruire : voir `PLAN_TASK` **T81**.

### 🔌 `KoboldContactor_DQ` — activation de la mesure

Ce contacteur **alimente la mesure de captage du fond**. Sans son activation, **aucune détection
n'est possible** : le capteur reste muet et la benne peut continuer à dérouler du câble alors
qu'elle a déjà touché le fond.

**À prévoir (pas maintenant)** : surveiller l'**absence de changement d'état à l'immersion** →
la mesure n'est pas active ou le capteur est mort → défaut à remonter. 👉 `PLAN_TASK` **T82**.

## 4. ✅ Inchangés (aucune polarité)

`JoyXRaw_ANA1` · `JoyYRaw_ANA2` · `JoyBtnRaw` · `COD1/COD2_PosValue`/`Alarms`/`Warnings`/
`PresettTrigCmd`/`PresetValue`/`CodeSeqTrigCmd` · `M3_StatusWord` · `M3_ActualFrequencyHz` ·
`M3_CommandWord` · `M3_SetpointFrequencyHz`

## 5. 🤝 Méthode

| Qui | Quoi |
|---|---|
| 👤 Toi, CODESYS | Renommer les voies dans l'éditeur de mapping E/S · vérifier chaque nom obtenu |
| 🤖 Moi | `PRG_00` / `PRG_01` / `PRG_02` / `PRG_10` en **une seule passe**, quand tu as terminé |
| ✅ Contrôle | Compilation `0 erreur` — aucune référence ne peut passer au travers |

🚫 **Hors périmètre avant livraison** : les noms métier (`Ready`, `CablePosM`, `TopPositionSensor`
interne…) — ils touchent les interfaces de FB (`PLAN_TASK` §2, chantier nommage).

📄 À aligner ensuite : `AF_Partie-06`, `AF_Partie-01`, `NAMING_CONVENTION.md`, registre MES.
