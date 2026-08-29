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
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-001</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Méca A</b><br>roue libre</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : Contrôleurs+frein coupés, joystick neutre, hors homing<br>
        🚀 <b>Étape 1</b> : Injection dérive position &gt;2.0m (canal position, <code>DriftGuardA</code>)<br>
        ⚡ <b>Étape 2</b> : Détection Méca A, bit7 levé<br>
        ✅ <b>Étape 3</b> : <code>SafeStop</code>+<code>PowerCutOff</code> — 🆕 <b>mono-canal assumé</b> (2026-08-29) : seuil vitesse <code>UncommandedSpeedThresholdMps</code> déclaré mais non utilisé, pas de croisement Cat.3 logiciel
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§3</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-002</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Méca B</b><br>non-conf. arrêt</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : Arrêt commandé, <code>FwdRevSpeedFeedbackOff</code> attendu<br>
        🚀 <b>Étape 1</b> : Maintien de la non-confirmation 3s (<code>PostRampTimeout</code>)<br>
        ⚡ <b>Étape 2</b> : Détection Méca B, bit8 levé<br>
        ✅ <b>Étape 3</b> : <code>SafeStop</code>+<code>PowerCutOff</code>
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§3</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-003</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Méca C</b><br>gliss. M1</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : <code>BenneHoldStillActive</code> (M1 seul), maintien<br>
        🚀 <b>Étape 1</b> : Dérive M1 &gt;2.0m en maintien<br>
        ⚡ <b>Étape 2</b> : Détection Méca C, bit9 levé<br>
        ✅ <b>Étape 3</b> : <code>SafeStop</code>+<code>PowerCutOff</code>
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§3</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-004</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Méca D</b><br>capteur haut</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : Capteur/limite haut atteint, hors homing, montée<br>
        🚀 <b>Étape 1</b> : Maintien sans arrêt confirmé 3s<br>
        ⚡ <b>Étape 2</b> : Détection Méca D, bit11 levé (marge +0.10m)<br>
        ✅ <b>Étape 3</b> : <code>SafeStop</code>+<code>PowerCutOff</code>
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§3</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-005</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Méca E</b><br>sync bit12</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : <code>SyncEnable</code>, hors benne/homing<br>
        🚀 <b>Étape 1</b> : Écart M1/M2 &gt;2m (<code>CriticalSyncToleranceM</code>=2.5m)<br>
        ⚡ <b>Étape 2</b> : Détection Méca E bit12<br>
        ✅ <b>Étape 3</b> : <code>SafeStop</code> seul (pas <code>PowerCutOff</code>) — escalade par bit13
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§3</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-006</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Méca E</b><br>sync bit13</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : Bit12 levé (SafeStop seul), écart persistant<br>
        🚀 <b>Étape 1</b> : Non-confirmation 3s après bit12<br>
        ⚡ <b>Étape 2</b> : Détection Méca E bit13<br>
        ✅ <b>Étape 3</b> : Escalade → <code>PowerCutOff</code> ajouté au <code>SafeStop</code>
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§3</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-007</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Méca F</b><br>sens opposé</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : Mouvement commandé, hors homing<br>
        🚀 <b>Étape 1</b> : Signe vitesse mesurée opposé à la commande<br>
        ⚡ <b>Étape 2</b> : Confirmé 500ms (seuil 0.02 m/s)<br>
        ✅ <b>Étape 3</b> : Détection Méca F, bit14 → <code>SafeStop</code> seul
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§3</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-008</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Méca G</b><br>absence mvmt</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : Mouvement commandé, hors homing<br>
        🚀 <b>Étape 1</b> : Vitesse mesurée sous seuil malgré commande<br>
        ⚡ <b>Étape 2</b> : Maintien 3s<br>
        ✅ <b>Étape 3</b> : Détection Méca G, bit15 → <code>SafeStop</code> seul
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§3</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-009</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Masque</b><br>PowerCutOff</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : Évaluation combinatoire des bits ErrorId<br>
        🚀 <b>Étape 1</b> : Vérification du masque <code>16#2F84</code> (bits 2,7,8,9,10,11,13)<br>
        ⚡ <b>Étape 2</b> : Comparaison <code>PowerCutOff = (ErrorId AND 16#2F84) ≠ 0</code><br>
        ✅ <b>Étape 3</b> : Masque exact vérifié — aucun bit hors liste ne déclenche <code>PowerCutOff</code>
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§4</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-010</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>SafeStop</b><br>mou câble</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : <code>SyncEnable=FALSE</code>, mou câble (bit3) actif<br>
        🚀 <b>Étape 1</b> : Vérification du masque <code>SafeStop = NOT PowerContactorEngaged OR (ErrorId AND 16#FF97)</code><br>
        ⚡ <b>Étape 2</b> : Bit3 exclu du <code>SafeStop</code> (mou câble = <code>DescendPermit:=FALSE</code> seul)<br>
        ✅ <b>Étape 3</b> : Masque <code>SafeStop</code> corrigé (bit3 exclu) quand <code>SyncEnable=FALSE</code>
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§4</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-036.1</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Warmup</b><br>3s</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : Après <code>Enable=TRUE</code>, fenêtre warmup 3s (<code>TonStartupWarmup</code>)<br>
        🚀 <b>Étape 1</b> : Perte com opérateur (cause 0) dans les 3 premières s<br>
        ⚡ <b>Étape 2</b> : Aucun <code>SafeStop</code> pendant les 3s (anti-faux-défaut au démarrage)<br>
        ✅ <b>Étape 3</b> : Après 3s → <code>SafeStop</code> déclenché sur perte com
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§3</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-037.1</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Gate</b><br>Enable</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : <code>Enable=FALSE</code><br>
        🚀 <b>Étape 1</b> : <code>SafeStop</code>/<code>Permit</code>/<code>PowerCutOff</code> forcés FALSE, <code>Ready=FALSE</code><br>
        ⚡ <b>Étape 2</b> : Latches (<code>MecaAFaultLatched</code>…) préservés<br>
        ✅ <b>Étape 3</b> : Re-<code>Enable</code> exige un <code>Reset</code> front
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§1</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-044.1</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Mou câble</b><br>permit</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : <code>SyncEnable=FALSE</code>, mou câble détecté<br>
        🚀 <b>Étape 1</b> : <code>DescendPermit:=FALSE</code> (blocage descente), <code>AscentPermit</code> autorisé palier 1<br>
        ⚡ <b>Étape 2</b> : Opérateur enroule pour retendre / fermer la benne<br>
        ✅ <b>Étape 3</b> : Dès <code>M2_TensionedCable_DI=TRUE</code>, blocage descente levé
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§3</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-051.1</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Chaîne</b><br>PowerCutOff</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : Demande <code>PowerCutOff</code> émise par <code>PRG_04</code><br>
        🚀 <b>Étape 1</b> : Agrégation dans <code>PRG_06</code><br>
        ⚡ <b>Étape 2</b> : Propagation → coupure AU<br>
        ✅ <b>Étape 3</b> : Chaîne bout-en-bout validée (pas seulement le masque <code>16#2F84</code>)
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>⚡ AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§6</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
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
