# FB_Encoder_Safety — Spec composant (v1.0)

> Rôle machine : [`AF_Partie-09_Fonction_Encoder_v2.0.md`](../AF_Partie-09_Fonction_Encoder_v2.0.md) §4.  
> Rôle de **ce** document : bornage de la position dans l'enveloppe de sécurité et détection d'incohérence/dépassement.  
> Source code : `CODE/CODEURS/FB_Encoder_Safety.st` · instances `instEncoderSafetyM1/M2` dans `Acquisition (CFC)`.  

## 🧭 Sommaire

1. Rôle et profil
2. Interface
3. Bornage et levée d'alarme
4. Alertes et écarts
5. Documents liés

## 🧪 Points de validation (`TC-P09-010/011/012` — propriétaire unique)

| ID | Intention / Comportement attendu | Type |
|---|---|---|
| TC-P09-010 | Bornage [-99;+99] m dépassé ➔ position gelée + `EncoderIncoherent = TRUE` | `💻 AUTO` |
| TC-P09-011 | `EncoderFaultPresent = TRUE` interdit la bascule en mode `SEMI_AUTO` | `⚡ AUTO_PLC` |
| TC-P09-012 | Méca D (Capteur haut sans arrêt) ➔ `SafeStop` + `PowerCutOff` après 3s | `🟢 SITE` |

---

## 1. Rôle et profil

Brique de **sécurité et de qualification de mesure** : vérifie que la position mesurée reste dans l'enveloppe physique acceptable (intervalle `[-99.0 ; +99.0]` mètres) et qualifie les défauts codeur qui doivent interdire le mode automatique.

---

## 2. Interface

| Port entrée | Type | Rôle |
|---|---|---|
| `Enable/Reset` | BOOL | Standard |
| `CablePosM` | REAL | Position mesurée issue de `FB_Encoder_Scale` |
| `EncoderAvailable` | BOOL | Disponibilité bus issue de `FB_Encoder_Abs` |
| `Homed` | BOOL | État de référencement issu de `FB_Encoder_Homing` |
| `HomingSuspect` | BOOL | État de doute au boot issu de `FB_Encoder_Homing` |

**Sorties** :
- `CablePosMSafe : REAL` : Position bornée et sécurisée transmise à l'automate.
- `EncoderIncoherent : BOOL` : `TRUE` si la position franchit l'enveloppe `[-99; +99]` m.
- `EncoderFaultPresent : BOOL` : Synthèse de défaut (`NOT EncoderAvailable OR EncoderIncoherent OR HomingSuspect`).

---

## 3. Bornage et levée d'alarme

- Si la position mesurée dépasse `+99.0` m ou `-99.0` m, `CablePosMSafe` est **gelée** à la dernière valeur valide et `EncoderIncoherent` est activé.
- `EncoderFaultPresent` est consommé par la logique des modes (`PRG_04_Modes`) pour refuser ou débrayer immédiatement le mode `SEMI_AUTO` en cas de doute ou de panne codeur.

---

## 4. Alertes et écarts

- Le gel de position empêche des dérives catastrophiques dans la machine d'état du cycle en cas de rupture de signal codeur.

---

## 5. Documents liés

- [`AF_Partie-09_Fonction_Encoder_v2.0.md`](../AF_Partie-09_Fonction_Encoder_v2.0.md)
