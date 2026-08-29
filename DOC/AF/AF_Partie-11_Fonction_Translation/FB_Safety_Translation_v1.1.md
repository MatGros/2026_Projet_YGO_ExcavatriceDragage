# FB_Safety_Translation — Spec composant (v1.1)

> Rôle machine (vague) : [`AF_Partie-11_Fonction_Translation_v2.3.md`](../AF_Partie-11_Fonction_Translation_v2.3.md) §3.
> Rôle de **ce** document : safety métier M3 (8 bits ErrorId), Méca A/B, masques —
> et **catalogue unique** des `TC-P11-002` à `TC-P11-011`, `TC-P11-014`.
> Source code : `CODE/I_TRANSLATION/FB_Safety_Translation.st` · instance `Safety.instSafetyTranslationM3`.

## 🧭 Sommaire

1. Rôle et profil
2. Interface
3. ErrorId (8 bits)
4. Méca A et Méca B (détail)
5. Masques de sortie
6. Bypass
7. Alertes et écarts
8. Documents liés

## 🧪 Table des points de validation (détail)

> Propriétaire unique du catalogue détaillé de la plage indiquée (`TC-P11-002` à `011`, `014`) — ce catalogue fait foi ; le chapô AF ne le recopie pas.

> **État** — `V` validé, implémentation non vérifiée · `V-I` validé et implémenté · `NV` non validé, non implémenté · `NV-I` code présent mais non validé · `R` refusé · `NA` non applicable.

<table style="width: 100%; table-layout: fixed; border-collapse: collapse; font-size: 14px;">
  <colgroup>
    <col style="width: 40px;">
    <col style="width: calc(100% - 170px);">
    <col style="width: 90px;">
    <col style="width: 40px;">
  </colgroup>
  <thead>
    <tr style="border-bottom: 2px solid #475569; text-align: left;">
      <th style="padding: 4px 1px; text-align: center;"><small><b>ID</b></small></th>
      <th style="padding: 4px 8px;">Intention / Comportement attendu</th>
      <th style="padding: 4px 1px; text-align: center;"><small>Type</small></th>
      <th style="padding: 4px 1px; text-align: center;"><small>État</small></th>
    </tr>
  </thead>
  <tbody>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P11-002</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Mot incohérent ➔ Bit7 ➔ SafeStop+PowerCutOff</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>⚡ AUTO_PLC</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P11-010</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Méca A (bit5) : arrêt commandé mais freq>0.5Hz >1s ➔ SafeStop+PowerCutOff</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>⚡ AUTO_PLC</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P11-010.1</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Absence redémarrage auto : Méca A → latch <code>MecaAFault</code> (FB_Safety_Translation.st:81,95-99,175). Après disparition, défaut reste latché, aucun redémarrage auto — Reset front + nouvelle demande requis</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P11-011</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Méca B (bit4) : incohérence arrêt >3s ➔ SafeStop+PowerCutOff</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>⚡ AUTO_PLC</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P11-011.1</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Méca B variante perte IHM : <code>HeartbeatIhmOk=FALSE</code> → condition élargie : <code>ABS(freq)&gt;0.5 OR DriveStatusWord.0 OR NOT BrakeFeedback</code> (FB_Safety_Translation.st:151-152) → SafeStop+PowerCutOff</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P11-014</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;"><code>BypassGlobal</code> efface <code>ErrorId</code>, coupe TONs, Reset fonctionnel</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>⚡ AUTO_PLC</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
  </tbody>
</table>

---

## 1. Rôle et profil

🛡️ Bloc safety **métier** du domaine Translation (Partie3 §2). Surveille com opérateur, bus
EtherCAT, rotation phase, thermique frein, Méca A/B, butées extrêmes et incohérence capteurs.
Produit `SafeStop` et `PowerCutOff`. 1 instance (`instSafetyTranslationM3`), Enable inconditionnel.

---

## 2. Interface

**Entrées clés** (hors standard Enable/Reset/PowerContactorEngaged/Mode) :

| Port | Sens |
|---|---|
| `JoystickOnline`/`JoystickOperational` | État nœud CAN joystick |
| `HeartbeatIhmOk` | Communication IHM↔PLC |
| `PhaseRotationOk` | Rotation phases électrique |
| `BrakeThermalFeedback` | Thermique frein commun (TRUE=surchauffe) |
| `DriveOnline`/`DriveOperational` | État communication EtherCAT variateur |
| `DriveStatusWord`/`DriveActualFreqHz` | Mot état + fréquence réelle AC600 |
| `BrakeFeedback`/`BrakeCmd` | Retour + commande frein |
| `Direction` | Sens commandé (depuis Translation, 1 scan retard) |
| `LimitSwitchFwd`/`LimitSwitchRev` | Butées extrêmes (depuis PositionDecoder) |
| `SensorWordIncoherent` | Mot capteurs incohérent (depuis PositionDecoder) |

**Sorties** : `SafeStop`, `PowerCutOff`, `ErrorId` (WORD, 8 bits), `Error` + 8 flags décapsulés.

---

## 3. ErrorId (8 bits)

| Bit | Cause | Délai |
|---|---|---|
| 0 | Perte com opérateur (CAN/heartbeat) | instantané |
| 1 | Perte com variateur EtherCAT | instantané |
| 2 | Rotation phase incorrecte | instantané |
| 3 | Surchauffe frein | instantané |
| 4 | **Méca B** — incohérence arrêt persistant | `PostRampTimeout`=3s (constante interne, ⚠️ non paramétrable) |
| 5 | **Méca A** — mouvement non commandé | 1s (constante interne, câblée en dur) |
| 6 | Butée extrême (avant ou arrière) | instantané |
| 7 | Mot capteurs incohérent | instantané |

---

## 4. Méca A et Méca B (détail)

### Méca A (bit5) — mouvement non commandé

**Condition** : `Direction=0 AND NOT BrakeCmd` puis `ABS(DriveActualFreqHz) > 0.5Hz` pendant >1.0s.
**Variateur tourne sans commande** → SafeStop + PowerCutOff.

### Méca B (bit4) — incohérence arrêt persistant

**Condition standard** : `Direction=0 AND NOT BrakeCmd` puis `DriveStatusWord.0 OR NOT BrakeFeedback`
pendant >3.0s. **Contacteur/frein ne confirment pas l'arrêt** → SafeStop + PowerCutOff.

**Variante perte IHM** : si `HeartbeatIhmOk=FALSE`, condition **élargie** :
`ABS(DriveActualFreqHz) > 0.5 OR DriveStatusWord.0 OR NOT BrakeFeedback` (surveillance élargie
en cas de perte communication opérateur — non documenté dans doc legacy, comblé ici).

---

## 5. Masques de sortie (vérifiés code)

```text
SafeStop    = Error OR NOT PowerContactorEngaged
PowerCutOff = (ErrorId AND 16#00F8) <> 0   → bits 3,4,5,6,7
```

⚠️ **Bits 0/1/2** (com opérateur, com variateur, rotation phase) ⇒ **SafeStop seul**,
**jamais PowerCutOff** — ces défauts de communication ne coupent pas la puissance amont.

---

## 6. Bypass

| Bypass | Portée |
|---|---|
| `BypassGlobal` | Force `ErrorId=0`, coupe les 2 TON |
| `BypassSafety` | Groupe PowerCutOff (bits 3,4,5,6,7) |
| `BypassProcess` | Groupe SafeStop (bits 0,1,2) |
| `BypassOperatorComm`/`BypassDriveComm`/`BypassPhaseRotation`/`BypassBrakeThermal`/`BypassMecaA`/`BypassMecaB`/`BypassLimitSwitch`/`BypassSensorIncoherent` | Individuels |

🚫 **Règle projet** : ne jamais forcer manuellement `SafeStop`/`PowerCutOff` — toujours forcer
le **capteur amont** pour un test banc.

---

## 7. Alertes et écarts

| # | Gravité | Point | Action |
|---|---|---|---|
| 1 | P2 | `PostRampTimeout`(3s)/Méca A(1s) = constantes internes non paramétrables | Documenté ici |
| 2 | P2 | Variante Méca B (perte IHM) non documentée dans doc legacy | Comblé §4 |

---

## 8. Documents liés

| Doc | Lien |
|---|---|
| AF11 (chapô) | Rôle machine, intégration programme |
| AF01 | AU/PowerCutOff — chaîne électrique |
| AF03 | Profil FB safety domaine |
| AF11 / FB_Translation_PositionDecoder | Fournit `Incoherent`, `LimitSwitchFwd/Rev` |
| Code | `CODE/I_TRANSLATION/FB_Safety_Translation.st` |
