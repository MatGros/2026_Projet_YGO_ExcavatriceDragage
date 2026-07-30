# Analyse Fonctionnelle — Partie 12 : Fonction Translation M3 (v2.0)

> Rôle : positionnement chariot/pont (AC600 EtherCAT), sécurité mouvement, barrière finale.
> Domaine autonome (contrairement à Benne) : PRG propre (`PRG_07`), `FB_Safety_Translation` dédié.
> Source code : `CODE/TRANSLATION/*.st` · instances dans `PRG_07_TranslationControl`, `PRG_03_Safety`, `PRG_10_Outputs_LD`.
> Extraction : `DOC/CHECKLISTS/EXTRACTIONS/FB_Translation_Extraction_Code_v1.0.md`.
> v1.13 archivée : `ARCHIVES/Doc/AF_Partie-11_Fonction_Translation_v1.13.md`.

## 🧭 Sommaire

1. Composition et rôle
2. FB_Translation_PositionDecoder — 5 capteurs
3. FB_Safety_Translation — safety métier
4. FB_Translation — mouvement
5. FB_TranslationOutputInterlock_LD — barrière finale
6. DUT et bus
7. Intégration programme
8. Alertes et écarts
9. Documents liés

## 🧪 Points de validation

| ID | Attendu | Type |
|---|---|---|
| TC-P12-001 | 6 mots capteurs valides acceptés (11111→00000) ; tout autre ⇒ `Incoherent` | AUTO |
| TC-P12-002 | Mot incohérent ⇒ bit7 Safety ⇒ SafeStop+PowerCutOff | AUTO_PLC |
| TC-P12-003 | `Enable=FALSE` coupe tout indépendamment de SafeStop/StartStop | AUTO_PLC |
| TC-P12-004 | Ralentissement PV actif **seulement** Direction=1 (vers Trémie) ET SlowdownSensor | AUTO_PLC |
| TC-P12-005 | Interlock sens : bascule directe si vitesse=0, sinon délai 200ms | AUTO_PLC |
| TC-P12-006 | Watchdog frein 500ms fixe : sans confirmation ⇒ FAULT, RestartInhibit | AUTO_PLC |
| TC-P12-007 | Réautorisation après timeout : cause disparue + Reset + mot 0 vu + nouvelle demande | AUTO_PLC |
| TC-P12-008 | Gate final : mot/fréquence nuls tant que `BrakeReleaseRequest AND BrakeCommandOpenConfirmed` non simultanés | AUTO_PLC |
| TC-P12-009 | Mot 7 (reset AC600) autorisé pendant RestartInhibit, fréquence nulle, ne lève pas l'inhibition | AUTO_PLC |
| TC-P12-010 | Méca A (bit5) : arrêt commandé mais fréquence>0.5Hz pendant >1.0s ⇒ SafeStop+PowerCutOff | AUTO_PLC |
| TC-P12-011 | Méca B (bit4) : incohérence arrêt >3.0s ⇒ SafeStop+PowerCutOff ; variante si perte IHM | AUTO_PLC |
| TC-P12-012 | Cible Maintenance refusée hors MAINT_N2 | AUTO_PLC |
| TC-P12-013 | Boutons IHM en MAINT exigent `DeadmanArmed=TRUE` même sans joystick | AUTO_PLC |
| TC-P12-014 | `BypassGlobal` force ErrorId=0, coupe les 2 TON, Reset reste fonctionnel | AUTO_PLC |
| TC-P12-015 | Terrain : 5 capteurs réels, watchdog 500ms mesuré, temps réponse variateur | SITE |

---

## 1. Composition et rôle

```text
FB_Translation_PositionDecoder ──► FB_Safety_Translation ──► FB_Translation ──► FB_TranslationOutputInterlock_LD
   (5 capteurs → mot, PRG_00)         (safety, PRG_03)         (mouvement, PRG_07)   (barrière finale, PRG_10)
```

Un seul axe M3 — pas d'instances ×2 comme Winch.

---

## 2. FB_Translation_PositionDecoder (brique réduite, pas de contrat standard)

**Entrées** : 5 BOOL `SensorTremie|PV|P2|P1|Maintenance`. Pas de Enable/Reset/Mode — logique combinatoire pure.

**Table de cohérence (6 mots valides)** :
| Mot | Zone |
|---|---|
| `11111` | Extrême Trémie |
| `01111` | Entre Trémie et PV |
| `00111` | P2 |
| `00011` | P1 |
| `00001` | Entre P1 et Maintenance |
| `00000` | Extrême Maintenance |

Tout autre mot ⇒ `Incoherent=TRUE`. `LimitSwitchFwd/Rev` dérivés **seulement** sur mot valide (évite Fdc fantôme).

Instance : `PRG_00_Inputs.instPositionDecoder`, position 0, **avant** `PRG_03_Safety`.

---

## 3. FB_Safety_Translation

**ErrorId** :
| Bit | Cause | Délai |
|---|---|---|
| 0 | Perte com opérateur (CAN/heartbeat) | instantané |
| 1 | Perte com variateur EtherCAT | instantané |
| 2 | Rotation phase incorrecte | instantané |
| 3 | Surchauffe frein | instantané |
| 4 | **Méca B** — incohérence arrêt persistant | `PostRampTimeout`=3s (constante interne, ⚠️ non paramétrable) |
| 5 | **Méca A** — mouvement non commandé | 1s (constante interne, câblée en dur) |
| 6 | Fin de course (Fdc) | instantané |
| 7 | Mot capteurs incohérent | instantané |

**Détail Méca B** : si `HeartbeatIhmOk=FALSE`, condition élargie (surveillance perte IHM) ; sinon condition standard arrêt commandé sans confirmation.

**Sorties** : `SafeStop = Error OR NOT PowerContactorEngaged` ; `PowerCutOff = (ErrorId AND 16#00F8) <> 0` → bits 3,4,5,6,7 (**pas** bits 0/1/2 : com/rotation ⇒ SafeStop seul, jamais PowerCutOff).

`BypassGlobal` force ErrorId=0 et coupe les 2 TON ; `Reset` reste fonctionnel sous bypass.

---

## 4. FB_Translation (mouvement, Partie3 §1bis)

**Réglages RETAIN réellement câblés** (⚠️ liste exhaustive, voir §8 A4) :
```
_TranslationMaxFreq_Hz=60.0, _TranslationRampAccelRate_Pct=20.0,
_TranslationRampDecelNormal_Pct=40.0, _TranslationRampDecelFast_Pct=100.0,
_TranslationAutoSpeedCap_Pct=40.0, _TranslationSetFreq_Hz=0.0
```
`ApproachSpeedPct`(20%), `CaptorDebounce`(100ms), `DirectionInterlockDelay`(200ms) : **restent au défaut du FB**, aucune variable PERSISTENT dédiée.

**Pipeline** :
1. Gate `Enable/PowerContactorEngaged` → neutralisation totale.
2. Debounce `PositionSensorTarget` (100ms) → `TargetReached`.
3. Précédence Enable>SafeStop>StartStop pour la rampe.
4. **Ralentissement PV** : seulement `Direction=1` (vers Trémie) ET `SlowdownSensor` → plafond `ApproachSpeedPct`. Jamais en sens Maintenance.
5. Arrêt exact sur capteur : verrouille à 0 tant que cible atteinte dans le même sens.
6. Interlock sens : délai 200ms si vitesse non nulle avant bascule.
7. Mot AC600 : `0`=None, `1`=Fwd, `2`=Rev, `7`=Reset. Priorité Reset>Error>mouvement>neutre.
8. Coupure immédiate si Fdc atteint dans le sens commandé.

`FB_Translation` **ne décide pas** la frontière finale : SafeStop produit une rampe rapide, Enable maintenu — jamais une coupure sèche transformée ici.

---

## 5. FB_TranslationOutputInterlock_LD (barrière finale, dans PRG_10)

Watchdog frein **500ms fixe** (câblé en dur, pas paramétrable).

**Séquence après timeout** : bit0 → `RestartInhibit` → réautorisation exige cause disparue + Reset + **mot 0 vu** puis nouvelle demande mouvement. Mot 7 (reset AC600) reste autorisé pendant l'inhibition, toujours fréquence nulle, **ne lève pas** RestartInhibit.

**Gate final double condition obligatoire** : mot/fréquence autorisés **seulement si** `MovementRequested AND BrakeReleaseRequest AND BrakeCommandOpenConfirmed`.

`Reset` échantillonné **avant** le gate Enable — un Reset maintenu pendant une neutralisation ne devient jamais un acquittement implicite.

---

## 6. DUT et bus

| DUT | Producteur | Consommateur |
|---|---|---|
| `ST_TranslationFinalInterlockRequest` | `PRG_07_TranslationControl` | `PRG_10_Outputs_LD` |
| `ST_TranslationCmd` | IHM | `PRG_07` |
| `ST_TranslationState` | `PRG_09_Supervision` | IHM |
| `ST_SafetyTranslation` | `PRG_09_Supervision` | IHM |
| `ST_BypassTranslation` | IHM RETAIN | `PRG_03`, `PRG_07` |
| `ST_HwTranslation` | `PRG_00_Inputs` | `PRG_00` (HwIn) |
| `E_TranslationFinalInterlockReason` | `FB_TranslationOutputInterlock_LD` | IHM, Troubleshooting |

---

## 7. Intégration programme

```text
PRG_00  instPositionDecoder (position 0, AVANT Safety)
PRG_01  instJoystick (AxisCmdX, DeadmanArmed)
PRG_03  instSafetyTranslationM3 — Enable inconditionnel, lit M3_Direction_Active de PRG_07 (1 scan de retard)
PRG_04  MaintenanceM3TargetEnable (Mode=MAINT_N2)
PRG_05  CmdTranslationM3_Start/Target (SEMI_AUTO)
PRG_07  instTranslationM3 → publie TranslationFinalInterlockRequest
PRG_10  instTranslationOutputInterlock_LD (Q finales)
```

**Arbitrage PRG_07** :
- **SEMI_AUTO** : cible/vitesse depuis Cycle, `StartStop` exige `DeadmanArmed AND AxisCmdX.StartStop` (homme-mort actif même en auto).
- **MAINT_N1/N2** : boutons IHM OU joystick (`TglJoystickMaster`) — `DeadmanArmed` exigé **même pour boutons IHM** (REX 2026-07-19, corrige un écart sécurité).
- Cible Maintenance (4) refusée hors MAINT_N2.
- `InvertDirection` inverse le sens après arbitrage, tous modes.

---

## 8. Alertes et écarts

| # | Gravité | Point | Action |
|---|---|---|---|
| 1 | info | `PowerCutOff M3 codé en dur FALSE` cité par audits historiques — **faux aujourd'hui**, calcul réel | Ne pas citer ces audits comme référence |
| 2 | P2 | `PostRampTimeout`(3s)/Méca A(1s) non paramétrables, non documenté avant | Comblé §3 |
| 3 | P2 | Variante Méca B (perte IHM) non documentée avant | Comblé §3 |
| 4 | P2 | Doc legacy dit `ApproachSpeedPct` etc. "câblés RETAIN" — **faux**, restent au défaut FB | Corrigé §4 |
| 5 | info | Dépendance croisée PRG_03↔PRG_07 (1 scan retard) | Clarifié §7 |
| 6 | info | `SetFreq_Hz=0` → défaut 30% codé en dur | Vestige mise en service |

---

## 9. Documents liés

| Doc | Lien |
|---|---|
| AF01 | AU/PowerCutOff |
| AF03 | Contrat FB mouvement |
| AF05 | Modes — MAINT_N2 |
| AF06 | 5 capteurs TOR M3 |
| Code | `CODE/TRANSLATION/*.st`, `CODE/MAIN/PRG_07_TranslationControl.st` |
