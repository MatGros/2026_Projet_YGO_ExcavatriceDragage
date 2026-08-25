# FB_TranslationOutputInterlock — Spec composant (v1.1)

> Rôle machine (vague) : [`AF_Partie-11_Fonction_Translation_v2.2.md`](../AF_Partie-11_Fonction_Translation_v2.2.md) §5.
> Rôle de **ce** document : barrière finale M3 (watchdog frein, gate double condition,
> anti-redémarrage, mot AC600) — et **catalogue unique** des `TC-P11-006` à `TC-P11-009`.
> Source code : `CODE/I_TRANSLATION/FB_TranslationOutputInterlock.st` · instance `PRG_06_Outputs.instTranslationOutputInterlockM3`.

## 🧭 Sommaire

1. Rôle et profil
2. Interface
3. Watchdog frein
4. Gate final double condition
5. Anti-redémarrage
6. Mot AC600
7. Alertes et écarts
8. Documents liés

## 🧪 Points de validation (`TC-P11-006` à `009` — propriétaire unique)

| ID | Intention / Comportement attendu | Type |
|---|---|---|
| <nobr><code>TC-P11-006</code></nobr> | Watchdog frein 500ms sans confirmation ➔ FAULT + Inhibit | `⚡ AUTO_PLC` |
| <nobr><code>TC-P11-007</code></nobr> | Réautorisation post-timeout : Cause + Reset + Mot 0 + Nouvelle demande | `⚡ AUTO_PLC` |
| <nobr><code>TC-P11-008</code></nobr> | Gate final : Mot/fréquence nuls sans confirmation frein simultanée | `⚡ AUTO_PLC` |
| <nobr><code>TC-P11-009</code></nobr> | Mot 7 (reset AC600) autorisé pendant `RestartInhibit` (sans levée inhibition) | `⚡ AUTO_PLC` |

---

## 1. Rôle et profil

⚡ Profil **barrière finale** (Partie3 §2) : reçoit la demande sortie typée
(`ST_TranslationFinalInterlockRequest`), applique les interlocks ultimes, produit **seule**
la commande physique autorisée (mot AC600 + frein). 1 instance dans `PRG_06_Outputs`.

`FB_Translation` reste propriétaire du **calcul** mot/fréquence ; cette barrière
**autorise ou masque**, ne reconstruit jamais.

---

## 2. Interface

| Entrée | Sens |
|---|---|
| `Enable/Reset/PowerContactorEngaged` | Standard |
| `SafeStop` | Reçu de `FB_Translation` (déjà arbitré) |
| `BrakeReleaseRequest`/`BrakeCommandOpenConfirmed` | Demande + confirmation frein |
| `RequestedDriveControlWord` | Mot AC600 (0/1/2/7) |
| `RequestedDriveFreqHz` | Fréquence demandée (Hz) |

**Sorties** : `DriveControlWord` (WORD), `DriveFreqCmd_Hz` (REAL), `BrakeCmd` (Q physiques),
`State`, `Reason` (`E_TranslationFinalInterlockReason`), `RestartInhibit`, `ErrorId`.

---

## 3. Watchdog frein

`T#500ms` **fixe** (câblé en dur) — armé si `BrakeReleaseRequest AND NOT BrakeCommandOpenConfirmed
AND NOT RestartInhibit`. Timeout ⇒ bit0 `ErrorId`, `RestartInhibit:=TRUE`,
`Reason:=BRAKE_COMMAND_NOT_CONFIRMED`.

---

## 4. Gate final double condition obligatoire

`DriveControlWord`+`DriveFreqCmd_Hz` autorisés **seulement si** :
`MovementRequested AND BrakeReleaseRequest AND BrakeCommandOpenConfirmed`

Si une seule des deux conditions manque : `State=INIT` (attente confirmation), **sans** défaut
tant que < 500ms.

---

## 5. Anti-redémarrage

Après timeout :
1. `RestartInhibit:=TRUE` — frein coupé, mouvement interdit.
2. Acquittement : `ResetEdge.Q AND BrakeCommandOpenConfirmed` → efface bit0.
3. Réautorisation : `NOT Error AND NOT ResetRequired` + **mot 0 vu** (`NeutralRequestSeen`)
   puis **nouvelle demande** 1 ou 2.

**Mot 7** (reset AC600) reste autorisé pendant `RestartInhibit`, toujours fréquence nulle,
**ne lève pas** `RestartInhibit`.

`Reset` échantillonné **avant** le gate Enable — un Reset maintenu pendant une neutralisation
ne devient jamais un acquittement implicite.

---

## 6. Mot AC600

| Sortie barrière | Condition |
|---|---|
| 0 (None) | Error, RestartInhibit, ou pas de demande |
| 7 (Reset) | `RequestedDriveControlWord=7` (toujours autorisé, fréquence nulle) |
| 1 (Fwd) / 2 (Rev) | Gate double condition OK |

---

## 7. Alertes et écarts

Aucun écart — comportement conforme, structure parallèle à `FB_WinchOutputInterlock`.

---

## 8. Documents liés

| Doc | Lien |
|---|---|
| AF11 (chapô) | Rôle machine, intégration programme |
| AF11 / FB_Translation | Producteur de la demande (`ST_TranslationFinalInterlockRequest`) |
| AF03 | Profil barrière finale |
| Code | `CODE/I_TRANSLATION/FB_TranslationOutputInterlock.st` |
