# FB_Translation_PositionDecoder — Spec composant (v1.0)

> Rôle machine (vague) : [`AF_Partie-12_Fonction_Translation_v2.0.md`](../AF_Partie-12_Fonction_Translation_v2.0.md) §2.
> Rôle de **ce** document : décodage 5 capteurs TOR → mot de progression + butées extrêmes —
> et **catalogue unique** des `TC-P12-001`, `TC-P12-002`.
> Source code : `CODE/TRANSLATION/FB_Translation_PositionDecoder.st` · instance `Acquisition.instPositionDecoder`.

## 🧭 Sommaire

1. Rôle et profil
2. Interface
3. Table de cohérence
4. Alertes et écarts
5. Documents liés

## 🧪 Points de validation (`TC-P12-001/002` — propriétaire unique)

| ID | Attendu | Type |
|---|---|---|
| TC-P12-001 | 6 mots capteurs valides acceptés (11111→00000) ; tout autre ⇒ `Incoherent` | AUTO |
| TC-P12-002 | Mot incohérent ⇒ `Incoherent=TRUE` → bit7 Safety ⇒ SafeStop+PowerCutOff | AUTO_PLC |

---

## 1. Rôle et profil

🧩 Brique réduite (Partie3 §1bis) : **pure logique combinatoire**, pas de Enable/Reset/Mode/State.
Décode 5 capteurs TOR en mot de progression, dérive les butées extrêmes et détecte toute
combinaison incohérente (défense en profondeur M3).

Instance : `Acquisition.instPositionDecoder`, exécutée **avant** Safety — les butées extrêmes
et l'incohérence sont consommées par `FB_Safety_Translation`.

---

## 2. Interface

| Entrée | Type | Sens |
|---|---|---|
| `SensorTremie` | BOOL | Capteur extrême Trémie |
| `SensorPV` | BOOL | Capteur pré-ralentissement (Point de Vitesse) |
| `SensorP2` | BOOL | Capteur zone travail P2 |
| `SensorP1` | BOOL | Capteur zone travail P1 |
| `SensorMaintenance` | BOOL | Capteur extrême Maintenance |

| Sortie | Type | Sens |
|---|---|---|
| `LimitSwitchFwd` | BOOL | Extrême Trémie confirmé (mot=11111) |
| `LimitSwitchRev` | BOOL | Extrême Maintenance confirmé (mot=00000) |
| `Incoherent` | BOOL | Mot hors 6 combinaisons valides |
| `SensorsWord` | BYTE | Diagnostic (bit4=Trémie…bit0=Maintenance) |

---

## 3. Table de cohérence (6 mots valides)

| Mot (bin) | Zone |
|---|---|
| `11111` | Extrême Trémie |
| `01111` | Entre Trémie et PV |
| `00111` | P2 |
| `00011` | P1 |
| `00001` | Entre P1 et Maintenance |
| `00000` | Extrême Maintenance |

Tout autre mot ⇒ `Incoherent=TRUE`. Butées extrêmes dérivées **seulement** sur mot valide
(évite butée fantôme sur incohérence câblage).

---

## 4. Alertes et écarts

Aucun écart — comportement conforme, logique combinatoire pure, pas d'état interne.

---

## 5. Documents liés

| Doc | Lien |
|---|---|
| AF12 (chapô) | Rôle machine, intégration programme |
| AF12 / FB_Safety_Translation | Consommateur `Incoherent`, `LimitSwitchFwd/Rev` |
| AF06 | 5 capteurs TOR M3 (E/S physiques) |
| Code | `CODE/TRANSLATION/FB_Translation_PositionDecoder.st` |