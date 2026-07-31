# FB_Safety_Winch — Spec composant (v1.0)

> Rôle machine (vague) : [`AF_Partie-10_Fonction_Winch_v2.0.md`](AF_Partie-10_Fonction_Winch_v2.0.md) §3.
> Rôle de **ce** document : interface, 7 mécanismes A-G, masques, écarts — et **catalogue unique**
> des `TC-P10-001` à `TC-P10-010` (ne pas les recopier dans le chapô AF10).
> Source code : `CODE/TREUILS/FB_Safety_Winch.st` · instances `Safety (CFC).instSafetyWinchM1/M2`.
> Extraction : `DOC/CHECKLISTS/EXTRACTIONS/FB_Winch_Extraction_Code_v1.0.md`.

## 🧭 Sommaire

1. Rôle et profil
2. Interface
3. 7 mécanismes de sécurité (A-G)
4. Masques de sortie
5. Bypass
6. Alertes et écarts
7. Documents liés

## 🧪 Points de validation (`TC-P10-001` à `010` — propriétaire unique)

| ID | Intention / Comportement attendu | Type |
|---|---|---|
| TC-P10-001 | Méca A (bit7) : dérive>2m ou v>0.02m/s arrêt ➔ SafeStop+PowerCutOff | `💻 AUTO` |
| TC-P10-002 | Méca B (bit8) : non-confirmation arrêt 3s ➔ SafeStop+PowerCutOff | `💻 AUTO` |
| TC-P10-003 | Méca C (bit9) : dérive M1>2m en maintien M1 ➔ SafeStop+PowerCutOff | `💻 AUTO` |
| TC-P10-004 | Méca D (bit11) : capteur haut sans arrêt 3s ➔ SafeStop+PowerCutOff | `💻 AUTO` |
| TC-P10-005 | Méca E bit12 : écart>2m ➔ SafeStop seul (pas PowerCutOff) | `💻 AUTO` |
| TC-P10-006 | Méca E bit13 : bit12 non confirmé 3s ➔ escalade PowerCutOff | `💻 AUTO` |
| TC-P10-007 | Méca F (bit14) : sens mesuré opposé au sens commandé 500ms ➔ SafeStop | `💻 AUTO` |
| TC-P10-008 | Méca G (bit15) : vitesse nulle malgré commande 3s ➔ SafeStop seul | `💻 AUTO` |
| TC-P10-009 | `PowerCutOff` = exactement bits 2,7,8,9,10,11,13 (masque 16#2F84) | `💻 AUTO` |
| TC-P10-010 | `SafeStop` exclut bit3 (mou câble) si `SyncEnable=FALSE` | `💻 AUTO` |

---

## 1. Rôle et profil

Bloc safety **métier** du domaine treuil (Partie3 §2 : profil FB safety domaine). Surveille des
faits qualifiés (position, vitesse, contacteurs, frein, com) et produit les interlocks du domaine
(`SafeStop`, `ForbidDescent`, `ForbidAscent`, `PowerCutOff`). Ne devient pas propriétaire des
mesures surveillées (codeurs, contacteurs restent produits ailleurs).

2 instances : `instSafetyWinchM1`, `instSafetyWinchM2` — une par treuil, indépendantes.

---

## 2. Interface

**Entrées clés** (hors standard Enable/Reset/PowerContactorEngaged/Mode) :

| Port | Sens |
|---|---|
| `FwdRevSpeedFeedbackOff`/`BrakeFeedback` | Confirmation arrêt réel (contacteurs+frein) |
| `CablePosM`/`Homed`/`HomingSuspect` | Position et référencement (sortie Encodeurs) |
| `MeasuredSpeedMps`/`SignedMps`/`Valid` | Vitesse mesurée (sortie Encodeurs) |
| `InReferencingMode` | Neutralise Méca D pendant homing |
| `BenneHoldStillActive` | Arme Méca C (M1 seulement, câblé sur `instBucket.Busy`) |
| `SyncEnable`/`ExpectedOtherWinchPosM` | Arme Méca E |
| `JoystickYNeutral` | Arme Méca B (variante neutre) |
| `PhaseRotationOk`/`BrakeThermalFeedback` | Bits socle (rotation, thermique) |

**Sorties** : `SafeStop`, `ForbidDescent`, `ForbidAscent`, `PowerCutOff`, `ErrorId` (WORD, 16 bits), `Error`.

---

## 3. 7 mécanismes de sécurité (A-G)

| Méca | Bit | Armement | Déclenchement | Conséquence | Seuils |
|---|---|---|---|---|---|
| **A** Roue libre | 7 (0080) | contacteurs+frein confirmés coupés, hors homing | dérive>tolérance OU vitesse>seuil | SafeStop+**PowerCutOff** | `UncommandedDriftToleranceM`=2.0m, `UncommandedSpeedThresholdMps`=0.02 |
| **B** Pilotage sans commande | 8 (0100) | perte CAN OU joystick neutre | non confirmé arrêté sous délai | SafeStop+**PowerCutOff** | `PostRampTimeout`=3s |
| **C** Glissement M1/benne | 9 (0200) | `BenneHoldStillActive` (M1 seul) | dérive M1 > tolérance | SafeStop+**PowerCutOff** | `BenneSlipToleranceM`=2.0m |
| **D** Capteur haut non confirmé | 11 (0800) | capteur/limite log. atteint, hors homing, montée | non confirmé arrêté sous délai | SafeStop+**PowerCutOff** | `PostRampTimeout`=3s, marge +0.10m |
| **E** Sync critique (2 bits) | 12/13 (1000/2000) | SyncEnable, hors benne/homing | écart>tolérance (bit12) puis non confirmé (bit13) | bit12: SafeStop seul ; bit13: +**PowerCutOff** | `CriticalSyncToleranceM`=2.0m |
| **F** Sens opposé | 14 (4000) | mouvement commandé, hors homing | signe vitesse opposé, confirmé | SafeStop seul | seuil 0.02 m/s, délai 500ms |
| **G** Absence mouvement | 15 (8000) | idem F | vitesse sous seuil malgré commande | SafeStop seul | délai 3s |

**Autres bits (socle)** :
| Bit | Cause | Conséquence |
|---|---|---|
| 0 | Perte com opérateur | SafeStop |
| 1 | Perte codeur treuil | SafeStop |
| 2 | Surchauffe moteur | SafeStop+PowerCutOff |
| 3 | Mou câble | SafeStop (sauf `SyncEnable=FALSE`→ForbidAscent seul) |
| 4 | Rotation phase incorrecte | SafeStop |
| 5 | Fin de course haut | ForbidAscent |
| 6 | Limite basse câble | ForbidDescent |
| 10 | Thermique frein commun | SafeStop+PowerCutOff |

**Défense en profondeur Méca C** (lien Benne, AF11) : couche 1 (`FB_Bucket`, 1.0m) coupe M2 en
premier ; Méca C (2.0m) coupe la puissance amont si la couche 1 ne suffit pas.

---

## 4. Masques de sortie (vérifiés code)

```text
SafeStop      = NOT PowerContactorEngaged OR (ErrorId AND 16#FF9F)  [SyncEnable=TRUE]
              = NOT PowerContactorEngaged OR (ErrorId AND 16#FF97)  [SyncEnable=FALSE, exclut bit3]
PowerCutOff   = (ErrorId AND 16#2F84) <> 0   → bits 2,7,8,9,10,11,13
ForbidDescent = bit6 OR NOT PowerContactorEngaged
ForbidAscent  = bit5 OR (capteur haut hors homing) OR (bit3 ET NOT SyncEnable)
```

---

## 5. Bypass

| Bypass | Portée |
|---|---|
| `BypassGlobal` | Force `ErrorId=0`, ignore tout |
| `BypassSafety` | Groupe PowerCutOff (bits 2,7,8,9,10,11,13) |
| `BypassProcess` | Groupe SafeStop/Forbid (bits 0,1,3,4,5,6,12,14,15) |
| `BypassMecaA..E`, `BypassTopLimitSwitch`, `BypassCableLimitSwitch`, `BypassOperatorComm`, `BypassPhaseRotation`, `BypassBrakeThermal` | Individuels par méca/cause |

🚫 **Règle projet (NAMING_CONVENTION)** : ne jamais forcer manuellement une sortie de commande
(`SafeStop`, `PowerCutOff`) — toujours forcer le **capteur amont** pour un test banc.

---

## 6. Alertes et écarts

| # | Gravité | Point | Action |
|---|---|---|---|
| 1 | info | "5 mécanismes" annoncé initialement — code+doc legacy en comptent **7 (A-G)** | Corrigé ce doc |
| 2 | info | Numérotation legacy Méca F/G non nommée explicitement dans les commentaires code (nommée dans doc legacy uniquement) | Clarifié ici |

---

## 7. Documents liés

| Doc | Lien |
|---|---|
| AF10 (chapô) | Rôle machine, intégration programme |
| AF01 | AU/PowerCutOff — chaîne électrique |
| AF03 | Profil FB safety domaine |
| AF09 | Encodeurs — position/vitesse/Homed consommés |
| AF11 | Benne — Méca C couche 2 |
| Code | `CODE/TREUILS/FB_Safety_Winch.st` |
