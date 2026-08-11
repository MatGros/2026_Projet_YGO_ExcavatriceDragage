# FB_Encoder_Homing — Spec composant (v1.0)

> Rôle machine : [`AF_Partie-09_Fonction_Encoder_v2.1.md`](../AF_Partie-09_Fonction_Encoder_v2.1.md) §3.  
> Rôle de **ce** document : gestion du référencement (homing nominal et unitaire), mémorisation RETAIN et qualification du doute.  
> Source code : `CODE/CODEURS/FB_Encoder_Homing.st` · instances cibles `instHomingM1/M2` dans `PRG_04_Treuils_Benne_CFC`.  

## 🧭 Sommaire

1. Rôle et profil
2. Interface
3. Conditions d'exécution et vérifications
4. Alertes et écarts
5. Documents liés

## 🧪 Points de validation (`TC-P09-003 à 009` — propriétaire unique)

| ID | Intention / Comportement attendu | Type |
|---|---|---|
| <nobr><code>TC-P09-003</code></nobr> | Homing nominal refusé sans capteur haut (hors bypass) ➔ Bit4 | `⚡ AUTO_PLC` |
| <nobr><code>TC-P09-004</code></nobr> | Homing refusé si arrêt non confirmé (contacteurs+frein) ➔ Bit2 | `⚡ AUTO_PLC` |
| <nobr><code>TC-P09-005</code></nobr> | Homing unitaire refusé hors MAINT_N2 ou treuil erroné ➔ Bit0/Bit1 | `💻 AUTO` |
| <nobr><code>TC-P09-006</code></nobr> | Cible hors [-99;+99] m rejetée sans écriture preset | `💻 AUTO` |
| <nobr><code>TC-P09-007</code></nobr> | `HomingRefRaw` conforme ; `CablePosM` = cible post-Done | `⚡ AUTO_PLC` |
| <nobr><code>TC-P09-008</code></nobr> | Écart au reboot ➔ `HomingSuspect`, `Homed` masqué | `⚡ AUTO_PLC` |
| <nobr><code>TC-P09-009</code></nobr> | `BtnConfirmCoherence` lève le doute sans réécrire ref | `⚡ AUTO_PLC` |

---

## 1. Rôle et profil

Brique de **référencement et calibration** : orchestre le preset EtherCAT et calcule la référence
brute (`HomingRefRaw`) pour qu'une hauteur cible donnée (`CfgHomingTargetM`) corresponde exactement
à la cote physique. La mesure position/vitesse reste produite par `PRG_02_Acquisition_CFC` ; ce FB
est placé dans le CFC Treuils/Benne pour rendre l'état de maintenance immédiatement lisible.

### Référence de preset EtherCAT

Le codeur est référencé par son télégramme de preset EtherCAT. La valeur envoyée est le centre de
la plage multitour totale, afin d'empêcher un rebouclage brutal du compteur vers zéro en utilisation :

```text
PointsPerRev       = 8 192 points/tour
MultiTurnRevsMax   = 4 096 tours
MaxRawValue        = 8 192 × 4 096 = 33 554 432 points UL
HomingRefTarget    = MaxRawValue / 2 = 16 777 216 points UL
```

`16 777 216 points UL` est donc la moitié de la **plage multitour totale**, et non la moitié de la
résolution d'un seul tour (`8 192 / 2 = 4 096 points`). Cette marge symétrique évite qu'une position
valide franchisse la limite brute et réapparaisse soudainement près de zéro.

Séquence : `FB_Encoder_Homing` produit `PresetRequest` et `PresetValue`, `FB_Encoder_Abs` les
transmet au télégramme EtherCAT, puis renvoie `PresetAck` ou `PresetNak`. Après acquittement,
`HomingRefRaw` est mémorisé dans `ST_Encoder_Calib` et consommé par `FB_Encoder_Scale`.

---

## 2. Interface (vérifiée `CODE/CODEURS/FB_Encoder_Homing.st`)

| Port entrée | Type | Rôle |
|---|---|---|
| `Enable/Reset` | BOOL | Standard |
| `PowerContactorEngaged` | BOOL | Informations arrêt (n'interdit plus le homing codeur 24V) |
| `Mode` | E_Mode | `MAINT_N1` requis pour le flux nominal |
| `Home` | BOOL (front) | Demande de référencement — **port FB unique**. Calcul de `HomingRefRaw` **instantané et inconditionnel** en logiciel sur front montant, sans attendre l'acquittement SDO drive |
| `UnitaryMode` | BOOL | `TRUE` = flux unitaire à cible libre (`MAINT_N2` uniquement) |
| `WinchSelected` | BOOL | `TRUE` = cette instance est le treuil sélectionné (flux unitaire) |
| `CfgHomingTargetM` | REAL | Cible libre unitaire, `[-99.0 ; +99.0]` m |
| `BtnConfirmCoherence` | BOOL (front) | Lève le doute `HomingSuspect` sans réhoming complet (§3.7) |
| `TopPositionSensor` | BOOL | Capteur haut **unique, commun M1/M2** — voir polarité §3 |
| `CfgTopSensorPosM` | REAL := 8.5 | Cible homing nominal (RETAIN site — valeur réelle 8.0 m, voir §4) |
| `FwdRevSpeedFeedbackOff` | BOOL | Retour "tous contacteurs sens+vitesse retombés" CE treuil |
| `BrakeFeedback` | BOOL | Retour contacteur frein CE treuil (`TRUE` = ouvert/desserré) |
| `RawPos` | UDINT | Sortie `FB_Encoder_Abs` (déjà gelée sur doute) |
| `EncoderAvailable` | BOOL | Sortie `FB_Encoder_Abs` |
| `PresetAck`/`PresetNak` | BOOL (pulse) | Sortie `FB_Encoder_Abs` |
| `PointsPerRev` | UDINT := 8192 | Résolution codeur |
| `MultiTurnRevsMax` | UDINT := 4096 | Tours max multiturn |
| `CableM_PerRev` | REAL := 2.0 | Câble déroulé par tour |
| `BypassGlobal` | BOOL := FALSE | 🌐 Ignore arrêt confirmé (puissance 400V coupée = arrêt mécanique garanti) |

**InOut** : `Calib : ST_Encoder_Calib` (RETAIN — `HomingRefRaw`, `Homed`, `HomingSuspect`,
`LastKnownRawPos`, `RestartCoherenceTolerancePts`).
**Sorties** : `Ready/Busy/Done/Error/ErrorId`, `PresetRequest/PresetValue`, `Homed`, `HomingSuspect`,
`HomingRefRaw`.

---

exige d'être physiquement au contact du capteur haut, donc **`TopPositionSensor = FALSE`** pour
que la condition soit remplie — le code lève `ErrorId` bit4 *(« capteur position haute non
confirmé »)* précisément quand `TopPositionSensor = TRUE` (chariot pas encore arrivé).
⚠️ Ne jamais documenter/câbler `TopPositionSensor = TRUE` comme condition de succès du homing.

En cas de décalage de la position brute au démarrage de l'automate (mouvement hors tension), le
bloc positionne `HomingSuspect := TRUE` et masque `Homed := FALSE` jusqu'à confirmation par
l'opérateur (`BtnConfirmCoherence`).

### 3bis. `BypassGlobal` — doctrine projet (pas spécifique à ce FB)

Mécanisme de mise en service **homogène sur tous les axes** (M1/M2/M3/Benne/Synchro), tranché et
documenté dans `ARCHIVES/Doc/AUDITS/Bypass/AUDIT_BypassGlobal_Homogenization_v1.0.md` : à
l'activation, **tous** les défauts mémorisés du domaine sont purgés immédiatement, y compris dans
les sous-composants. Ici : `BypassGlobal = TRUE` ignore l'arrêt confirmé **et** le capteur haut —
usage mise en service/essais uniquement, jamais un état permanent d'exploitation.

### 3ter. `ErrorId` (bits vérifiés code — message IHM à valider terrain)

| Bit | Message IHM | Cause |
|---|---|---|
| 0 | "Mode non autorisé" | Mode courant n'autorise pas le flux demandé |
| 1 | "Mauvais treuil sélectionné" | Flux unitaire, `WinchSelected = FALSE` |
| 2 | "Arrêt non confirmé" | `FwdRevSpeedFeedbackOff`/`BrakeFeedback` pas au repos, hors bypass |
| 3 | "Codeur indisponible" | `EncoderAvailable = FALSE` |
| 4 | "Cible ou capteur haut non confirmé" | Cible hors plage OU `TopPositionSensor` pas au contact |
| 5 | "Référencement refusé (timeout)" | `PresetNak` reçu de `FB_Encoder_Abs` |
| 9 | "Incohérence position au redémarrage" | Écart `RawPos` vs `LastKnownRawPos` > tolérance, `Homed` était `TRUE` |

⚠️ Bits 6/7/8 (legacy : relecture incohérente, position hors bornage, saut codeur) **non codés**.

---

## 4. Alertes et écarts

- La cote `CfgTopSensorPosM` enregistrée en persistant (8.0 m réel terrain, MES-009) prime sur la
  valeur par défaut déclarée dans le code (8.5 m) — écart connu, RETAIN toujours prioritaire.
- ✅ **Comportement `Homed = FALSE` sans doute (`HomingSuspect = FALSE`)** — tranché : un treuil
  jamais référencé n'est pas une incohérence (rien à mettre en doute), donc il ne lève pas
  `EncoderIncoherent`/`EncoderFaultPresent` et ne bloque pas `SEMI_AUTO` par ce mécanisme. Le
  comportement cible pour cet état est double : **(1)** signalement opérateur — `Homed` est déjà
  exposé à l'IHM via `ST_WinchState` (pas un défaut acquittable, une information) ; **(2)** le
  treuil doit rester manœuvrable en `MAINT_N1` à **vitesse forcée palier 1** pour exécuter le
  cycle de référencement lui-même — même mécanisme que `ForceMinSpeedStep` déjà utilisé par
  `FB_ExtractionSequence` (`PRG_TREUILS_CFC.st`, `SEL(Force..., EffectiveMaxStepAscent, 1)`).
  🔧 **Non encore câblé** : aucune instance actuelle du forçage palier n'est conditionnée par
  `Homed`. Reste du périmètre de migration (lot Winch, cross-ref `AF_Partie-10 §9bis`), pas de
  ce FB directement (`Homed` est ici seulement produit, pas consommé).
- ⚠️ **Portée confirmée M1/M2 uniquement** (décision utilisateur 2026-07-31) : M3/Translation n'a
  pas de mécanisme de homing équivalent, ne pas étendre ce principe à M3 sans nouvelle spec.
- 🟠 **Nommage** : `CfgTopSensorPosM`/`CfgHomingTargetM` sans underscore avant
  le suffixe d'unité `M` — non conforme `NAMING_CONVENTION.md` §Suffixes d'unité (`CfgTopSensorPos_M`
  attendu). `ST_WinchCfg.CfgTopSensorPos_M` (IHM) a déjà l'underscore : 2 formes cohabitent pour la
  même notion. Ne pas renommer au fil de l'eau (voir chapô §6 point 9).

---

## 5. Documents liés

- [`AF_Partie-09_Fonction_Encoder_v2.1.md`](../AF_Partie-09_Fonction_Encoder_v2.1.md)
