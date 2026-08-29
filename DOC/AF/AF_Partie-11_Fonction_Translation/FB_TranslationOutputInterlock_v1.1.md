# FB_TranslationOutputInterlock — Spec composant (v1.1)

> Rôle machine (vague) : [`AF_Partie-11_Fonction_Translation_v2.3.md`](../AF_Partie-11_Fonction_Translation_v2.3.md) §5.
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

## 🧪 Table des points de validation (détail)

> Propriétaire unique du catalogue détaillé de la plage indiquée (`TC-P11-006` à `009`) — ce catalogue fait foi ; le chapô AF ne le recopie pas.

> **État** — `V` validé, implémentation non vérifiée · `V-I` validé et implémenté · `NV` non validé, non implémenté · `NV-I` code présent mais non validé · `R` refusé · `NA` non applicable.

<table style="width: 100%; table-layout: fixed; border-collapse: collapse; font-size: 14px;">
  <colgroup>
    <col style="width: 28px;">
    <col style="width: 50px;">
    <col style="width: calc(100% - 165px);">
    <col style="width: 45px;">
    <col style="width: 26px;">
    <col style="width: 36px;">
  </colgroup>
  <thead>
    <tr style="border-bottom: 2px solid #475569; text-align: left;">
      <th style="padding: 4px 1px; text-align: center;"><small><b>ID</b></small></th>
      <th style="padding: 4px 1px; text-align: center;"><small>Intention</small></th>
      <th style="padding: 4px 8px;">Séquence &amp; Déroulé des étapes (Comportement attendu)</th>
      <th style="padding: 4px 1px; text-align: center;"><small>Type</small></th>
      <th style="padding: 4px 1px; text-align: center;"><small>Réf</small></th>
      <th style="padding: 4px 1px; text-align: center;"><small>État</small></th>
    </tr>
  </thead>
  <tbody>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P11-006</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Watchdog</b><br>frein</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : <code>BrakeReleaseRequest</code>, <code>NOT BrakeCommandOpenConfirmed</code>, <code>NOT RestartInhibit</code> — watchdog armé (FB_TranslationOutputInterlock.st:85-86)<br>
        🚀 <b>Étape 1</b> : Confirmation à 499ms (avant exp.)<br>
        ⚡ <b>Étape 2</b> : Confirmation à 500ms (expiration)<br>
        ✅ <b>Étape 3</b> : Frontière 499ms → pas de défaut ; 500ms → bit0, <code>RestartInhibit</code>, FAULT
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>⚡ AUTO_PLC</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§3</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P11-007</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Anti-</b><br>redémarrage</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : Timeout frein → <code>RestartInhibit:=TRUE</code><br>
        🚀 <b>Étape 1</b> : Acquittement : <code>ResetEdge.Q AND BrakeCommandOpenConfirmed</code> → efface bit0 (FB_TranslationOutputInterlock.st:99-125)<br>
        ⚡ <b>Étape 2</b> : Réautorisation : <code>NOT Error AND NOT ResetRequired</code> + mot 0 vu (<code>NeutralRequestSeen</code>)<br>
        ✅ <b>Étape 3</b> : Nouvelle demande 1/2 → mouvement réautorisé
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>⚡ AUTO_PLC</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§5</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P11-008</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Gate</b><br>final double</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : Demande de mouvement M3 reçue<br>
        🚀 <b>Étape 1</b> : Vérification confirmation frein simultanée<br>
        ⚡ <b>Étape 2</b> : Mot/fréquence nuls sans confirmation<br>
        ✅ <b>Étape 3</b> : Mot/fréquence autorisés seulement si confirmation frein simultanée
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>⚡ AUTO_PLC</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§4</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P11-009</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Reset</b><br>AC600</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : <code>RestartInhibit=TRUE</code> (défaut frein)<br>
        🚀 <b>Étape 1</b> : Envoi du mot 7 (reset AC600)<br>
        ⚡ <b>Étape 2</b> : Vérification que l'inhibition n'est pas levée<br>
        ✅ <b>Étape 3</b> : Mot 7 autorisé pendant <code>RestartInhibit</code> (sans levée d'inhibition)
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>⚡ AUTO_PLC</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§6</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
  </tbody>
</table>

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
