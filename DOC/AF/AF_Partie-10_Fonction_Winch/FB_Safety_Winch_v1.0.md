# FB_Safety_Winch — Spec composant (v1.0)

> Rôle machine (vague) : [`AF_Partie-10_Fonction_Winch_v2.1.md`](AF_Partie-10_Fonction_Winch_v2.1.md) §3.
> Rôle de **ce** document : interface, 7 mécanismes A-G, masques, écarts — et **catalogue unique**
> des `TC-P10-001` à `TC-P10-010` (ne pas les recopier dans le chapô AF10).
> Source code : `CODE/H_TREUILS_BENNE/FB_Safety_Winch.st` · instances `PRG_04_Treuils_Benne.instSafetyWinchM1/M2`.

## 🧭 Sommaire

1. Rôle et profil
2. Interface
3. 7 mécanismes de sécurité (A-G)
4. Masques de sortie
5. Bypass
6. Alertes et écarts
7. Documents liés

## 🧪 Table des points de validation (détail)

> Propriétaire unique du catalogue détaillé de la plage indiquée (`TC-P10-001` à `010`) — ce catalogue fait foi ; le chapô AF ne le recopie pas.

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
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-001</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Armer Méca A (contacteurs+frein coupés, joystick neutre, hors homing). Injecter dérive position >2.0m (canal position, <code>DriftGuardA</code>) → <code>SafeStop</code>+<code>PowerCutOff</code>. 🆕 <b>Mono-canal assumé</b> (décision 2026-08-29) : la détection s'appuie sur le canal position seul ; le seuil vitesse (<code>UncommandedSpeedThresholdMps</code>) reste déclaré mais non utilisé et <b>n'est plus exigé</b> — pas de croisement Cat.3 logiciel sur ce socle.</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-002</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Méca B (bit8) : non-confirmation arrêt 3s ➔ SafeStop+PowerCutOff</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-003</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Méca C (bit9) : dérive M1>2m en maintien M1 ➔ SafeStop+PowerCutOff</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-004</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Méca D (bit11) : capteur haut sans arrêt 3s ➔ SafeStop+PowerCutOff</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-005</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Méca E bit12 : écart>2m ➔ SafeStop seul (pas PowerCutOff)</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-006</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Méca E bit13 : bit12 non confirmé 3s ➔ escalade PowerCutOff</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-007</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Méca F (bit14) : sens mesuré opposé au sens commandé 500ms ➔ SafeStop</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-008</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Méca G (bit15) : vitesse nulle malgré commande 3s ➔ SafeStop seul</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-009</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;"><code>PowerCutOff</code> = exactement bits 2,7,8,9,10,11,13 (masque 16#2F84)</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-010</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;"><code>SafeStop</code> exclut bit3 (mou câble) si <code>SyncEnable=FALSE</code></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-036.1</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Warmup 3s : après Enable, perte com opérateur (cause 0) ne déclenche PAS pendant les 3 premières s (<code>TonStartupWarmup</code>) ; après 3s → <code>SafeStop</code>.</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-037.1</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Gate Enable=FALSE : <code>SafeStop</code>/<code>Permit</code>/<code>PowerCutOff</code> forcés FALSE, <code>Ready</code>=FALSE, mais latches (<code>MecaAFaultLatched</code>…) préservés ; re-Enable exige Reset front.</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-044.1</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Mou câble : <code>SyncEnable</code>=FALSE → <code>DescendPermit</code>=FALSE (blocage descente) mais <code>AscentPermit</code> autorisé palier 1 ; dès <code>M2_TensionedCable_DI</code>=TRUE, blocage levé.</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-051.1</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Chaîne <code>PowerCutOff</code> bout-en-bout : demande <code>PRG_04</code> → agrégation <code>PRG_06</code> → coupure AU (bout-en-bout, pas seulement le masque 16#2F84).</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>⚡ AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
  </tbody>
</table>

---

## 1. Rôle et profil

Bloc safety **métier** du domaine treuil (Partie3 §2 : profil FB safety domaine). Surveille des
faits qualifiés (position, vitesse, contacteurs, frein, com) et produit les interlocks du domaine
(`SafeStop`, `DescendPermit`, `AscentPermit`, `PowerCutOff`). Ne devient pas propriétaire des
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

**Sorties** : `SafeStop`, `DescendPermit`, `AscentPermit`, `PowerCutOff`, `ErrorId` (WORD, 16 bits), `Error`.

---

## 3. 7 mécanismes de sécurité (A-G)

| Méca | Bit | Armement | Déclenchement | Conséquence | Seuils |
|---|---|---|---|---|---|
| **A** Roue libre | 7 (0080) | contacteurs+frein confirmés coupés, hors homing | dérive>tolérance (mono-canal 🆕) | SafeStop+**PowerCutOff** | `UncommandedDriftToleranceM`=2.0m (`UncommandedSpeedThresholdMps`=0.02 déclaré, non branché — mono-canal assumé) |
| **B** Pilotage sans commande | 8 (0100) | perte CAN OU joystick neutre | non confirmé arrêté sous délai | SafeStop+**PowerCutOff** | `PostRampTimeout`=3s |
| **C** Glissement M1/benne | 9 (0200) | `BenneHoldStillActive` (M1 seul) | dérive M1 > tolérance | SafeStop+**PowerCutOff** | `BenneSlipToleranceM`=2.0m |
| **D** Capteur haut non confirmé | 11 (0800) | capteur/limite log. atteint, hors homing, montée | non confirmé arrêté sous délai | SafeStop+**PowerCutOff** | `PostRampTimeout`=3s, marge +0.10m |
| **E** Sync critique (2 bits) | 12/13 (1000/2000) | SyncEnable, hors benne/homing | écart>tolérance (bit12) puis non confirmé (bit13) | bit12: SafeStop seul ; bit13: +**PowerCutOff** | `CriticalSyncToleranceM`=2.5m |
| **F** Sens opposé | 14 (4000) | mouvement commandé, hors homing | signe vitesse opposé, confirmé | SafeStop seul | seuil 0.02 m/s, délai 500ms |
| **G** Absence mouvement | 15 (8000) | idem F | vitesse sous seuil malgré commande | SafeStop seul | délai 3s |

**Autres bits (socle)** :
| Bit | Cause | Conséquence |
|---|---|---|
| 0 | Perte com opérateur | SafeStop |
| 1 | Perte codeur treuil | SafeStop |
| 2 | Surchauffe moteur | SafeStop+PowerCutOff |
| 3 | Mou câble | SafeStop (sauf `SyncEnable=FALSE` $\rightarrow$ `DescendPermit := FALSE` seul) |
| 4 | Rotation phase incorrecte | SafeStop |
| 5 | Fin de course haut | `AscentPermit := FALSE` |
| 6 | Limite basse câble | `DescendPermit := FALSE` |
| 10 | Thermique frein commun | SafeStop+PowerCutOff |

**Défense en profondeur Méca C** (lien Benne, fiche [`FB_Bucket_v1.0.md`](FB_Bucket_v1.0.md)) : couche 1 (`FB_Bucket`, 1.0m) coupe M2 en
premier ; Méca C (2.0m) coupe la puissance amont si la couche 1 ne suffit pas.

---

## 4. Masques de sortie (vérifiés code)

```text
SafeStop      = NOT PowerContactorEngaged OR (ErrorId AND 16#FF9F)  [SyncEnable=TRUE]
              = NOT PowerContactorEngaged OR (ErrorId AND 16#FF97)  [SyncEnable=FALSE, exclut bit3]
PowerCutOff   = (ErrorId AND 16#2F84) <> 0   → bits 2,7,8,9,10,11,13
DescendPermit = NOT (bit6 OR (bit3 ET NOT SyncEnable) OR NOT PowerContactorEngaged OR ...)
AscentPermit  = NOT (bit5 OR (capteur haut physique atteint) OR (limite haute atteinte) OR ...)
```

---

## 5. Bypass

| Bypass | Portée |
|---|---|
| `BypassGlobal` | Force `ErrorId=0`, ignore tout |
| `BypassSafety` | Groupe PowerCutOff (bits 2,7,8,9,10,11,13) |
| `BypassProcess` | Groupe SafeStop/Permit (bits 0,1,3,4,5,6,12,14,15) |
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
| AF10 / [FB_Bucket](FB_Bucket_v1.0.md) | Benne — Méca C couche 2 |
| Code | `CODE/H_TREUILS_BENNE/FB_Safety_Winch.st` |
