# FB_Bucket — Spec composant (v1.0)

> Rôle machine (vague) : [`AF_Partie-10_Fonction_Winch_v2.1.md`](AF_Partie-10_Fonction_Winch_v2.1.md) §1.
> Rôle de **ce** document : ouverture/fermeture benne par désynchronisation M1/M2, protection
> glissement, assistants maintenance — et **catalogue unique** des `TC-P10-023` à `TC-P10-034`.
> **Sous-fonction du domaine Treuils** (AF10) — aucune I/O ni programme propre.
> Source code : `CODE/TREUILS/BENNE/*.st`, `CODE/G_CYCLE/FB_DiveSearch.st`, `FB_ExtractionSequence.st`.
> Instance unique `instBucket` dans `PRG_04_Treuils_Benne` — fiche FB du domaine Treuils.

## 🧭 Sommaire

1. Rôle et cinématique
2. FB_Bucket — machine d'état, offsets
3. Protection glissement M1 — 2 couches
4. FB_DiveSearch — qualification Kobold
5. FB_ExtractionSequence — fermeture + remontée
6. Bus et intégration programme
7. Pourquoi Benne est une fiche FB de AF10 (pas une Partie séparée)
8. Alertes et écarts
9. Documents liés

## 🧪 Table des points de validation (détail)

> Propriétaire unique du catalogue détaillé de la plage indiquée (`TC-P10-023` à `034`) — ce catalogue fait foi ; le chapô AF ne le recopie pas.

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
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-023</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Fermeture</b><br>conditionnée</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : Benne au repos, <code>State=READY</code><br>
        🚀 <b>Étape 1</b> : Demande <code>CmdClose</code> avec <code>MotionDirection=1</code> ET <code>MotionRequestActive</code><br>
        ⚡ <b>Étape 2</b> : Vérification des 2 conditions obligatoires<br>
        ✅ <b>Étape 3</b> : Fermeture engagée seulement si les 2 conditions réunies
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§2</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-024</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Ouverture</b><br>conditionnée</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : Benne au repos, <code>State=READY</code><br>
        🚀 <b>Étape 1</b> : Demande <code>CmdOpen</code> avec <code>MotionDirection=-1</code> ET <code>MotionRequestActive</code><br>
        ⚡ <b>Étape 2</b> : Vérification des 2 conditions obligatoires<br>
        ✅ <b>Étape 3</b> : Ouverture engagée seulement si les 2 conditions réunies
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§2</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-025</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Anti-</b><br>traversée</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : <code>State=READY</code>, entrée manœuvre benne<br>
        🚀 <b>Étape 1</b> : Demande <code>CmdOpen</code>/<code>CmdClose</code> avec <code>M1_Busy</code> OR <code>M2_Busy</code><br>
        ⚡ <b>Étape 2</b> : Refus de la demande benne<br>
        ✅ <b>Étape 3</b> : ⚠️ État code : <code>M1_Busy</code>/<code>M2_Busy</code> déclarés (<code>FB_Bucket.st</code>:29-30) mais NON utilisés — anti-traversée non câblée (T175)
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§2</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-026</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Glissement</b><br>M1 couche 1</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : Manœuvre benne (<code>State=BUSY</code>)<br>
        🚀 <b>Étape 1</b> : Glissement M1 &gt;1.0m pendant BUSY<br>
        ⚡ <b>Étape 2</b> : <code>ErrorId</code> bit4 + <code>M1SlipDetected</code> levés, coupe M2<br>
        ✅ <b>Étape 3</b> : Protection couche 1 active (dérive M1)
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§3</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-027</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>SafeStop</b><br>sur slip</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : <code>M1SlipDetected=FALSE</code><br>
        🚀 <b>Étape 1</b> : Glissement M1 détecté → <code>M1SlipDetected=TRUE</code><br>
        ⚡ <b>Étape 2</b> : Propagation du signal vers côté Treuils<br>
        ✅ <b>Étape 3</b> : <code>SafeStop</code> forcé sur M1
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§3</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-028</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Glissement</b><br>couche 2</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : Manœuvre benne, couche 1 (SafeStop) active<br>
        🚀 <b>Étape 1</b> : Dérive M1 continue &gt;2.0m (Méca C)<br>
        ⚡ <b>Étape 2</b> : Escalade couche 2<br>
        ✅ <b>Étape 3</b> : <code>PowerCutOff</code> déclenché (défense en profondeur — 2.0m)
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§3</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-029</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Recul</b><br>borné</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : Manœuvre benne, position de départ mémorisée<br>
        🚀 <b>Étape 1</b> : Recul (sens inverse)<br>
        ⚡ <b>Étape 2</b> : Calcul du recul max autorisé<br>
        ✅ <b>Étape 3</b> : Recul borné à la position de départ, jamais au-delà
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§2</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-030</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Confirmer</b><br>position</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : Machine arrêtée, mode <code>MAINT_N1/N2</code><br>
        🚀 <b>Étape 1</b> : <code>ConfirmOpen/ClosePosition</code><br>
        ⚡ <b>Étape 2</b> : Vérification mode MAINT seule acceptée<br>
        ✅ <b>Étape 3</b> : Effet seulement en <code>MAINT_N1/N2</code> arrêtés
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§2</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-031</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Codeur</b><br>non réf.</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : Codeur (M1 ou M2) non référencé (<code>Homed=FALSE</code>)<br>
        🚀 <b>Étape 1</b> : Évaluation des besoins position benne<br>
        ⚡ <b>Étape 2</b> : <code>ErrorId</code> bit3 levé<br>
        ✅ <b>Étape 3</b> : bit3 permanent, indépendant de <code>Reset</code>
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§3</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-032</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Arm. joystick</b><br>préservé</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : Manœuvre benne en cours, fin de fermeture<br>
        🚀 <b>Étape 1</b> : Vérification <code>FB_ExtractionSequence.Busy</code> actif<br>
        ⚡ <b>Étape 2</b> : Préservation armement joystick<br>
        ✅ <b>Étape 3</b> : Armement joystick préservé en fin de benne
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§5</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-033</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Butée haute</b><br>M2 décalée</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : Benne fermée ou en fermeture<br>
        🚀 <b>Étape 1</b> : Calcul butée haute M2<br>
        ⚡ <b>Étape 2</b> : Application du décalage <code>OffsetCloseM</code><br>
        ✅ <b>Étape 3</b> : Butée haute M2 décalée de <code>OffsetCloseM</code> si fermé/en fermeture
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§2</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-034</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Terrain</b><br>cinématique</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : Essai réel en charge<br>
        🚀 <b>Étape 1</b> : Manœuvre benne sur le terrain<br>
        ⚡ <b>Étape 2</b> : Mesure amplitude offset réelle<br>
        ✅ <b>Étape 3</b> : Cinématique en charge validée, amplitude offset validée sur site
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>🟢 SITE</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§2</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-045.1</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Benne</b><br>part. fermée</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : Benne partiellement fermée (<code>NOT IsClosed</code>), demande de montée<br>
        🚀 <b>Étape 1</b> : Vérification état benne<br>
        ⚡ <b>Étape 2</b> : Verrouillage paliers 2-5<br>
        ✅ <b>Étape 3</b> : Remontée autorisée en palier 1 seul — paliers 2-5 verrouillés
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§7.5</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-046.1</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Timeout</b><br>mouvement</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : Manœuvre benne (<code>State=BUSY</code>)<br>
        🚀 <b>Étape 1</b> : Maintien sans fin de manœuvre (<code>CfgTimeoutDuration</code>=60s)<br>
        ⚡ <b>Étape 2</b> : Timeout mouvement déclenché<br>
        ✅ <b>Étape 3</b> : bit timeout + latch (<code>CfgTimeoutDuration</code>=60s, code réel — corrige le 30s documenté)
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§2</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-047.1</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Incoh.</b><br>boot</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : 1er cycle, ni <code>IsOpen</code> ni <code>IsClosed</code><br>
        🚀 <b>Étape 1</b> : Évaluation état benne<br>
        ⚡ <b>Étape 2</b> : <code>StateIncoherent=TRUE</code>, <code>ActiveOffsetValid=FALSE</code><br>
        ✅ <b>Étape 3</b> : Incohérence boot détectée, offset déclaré invalide
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§2</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-048.1</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Offset</b><br>RETAIN</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : <code>OffsetCloseM=15.0</code> configuré, stocké dans <code>_BucketCfgPersist</code> (PERSISTENT)<br>
        🚀 <b>Étape 1</b> : Power cycle (redémarrage PLC)<br>
        ⚡ <b>Étape 2</b> : Restauration <code>OffsetCloseM</code> depuis <code>_BucketCfgPersist</code><br>
        ✅ <b>Étape 3</b> : <code>OffsetCloseM=15.0</code> persiste après power cycle
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§6</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV-I</code></small></td>
    </tr>
  </tbody>
</table>

---

## 1. Rôle et cinématique

Pas de moteur propre — effet de bord de la désynchronisation M1/M2 :
- **Fermeture** : M2 enroule (monte, `Direction=+1`)
- **Ouverture** : M2 déroule (descend, `Direction=-1`)
- Cible : `CablePosM2 >= CablePosM1 + OffsetCloseM` (fermeture) ou `<= CablePosM1 + OffsetOpenM` (ouverture)

**Offsets réels (RETAIN)** : `OffsetOpenM=0.0` (référence neutre, M2=M1) ; `OffsetCloseM=15.0` (⚠️ doc legacy dit 10.0, non validé en charge — voir §8).

---

## 2. FB_Bucket

| Entrée | Type | Sens |
|---|---|---|
| `MotionRequestActive`/`MotionDirection` | BOOL/INT | Intention déjà arbitrée (joystick/IHM, axe Y) |
| `CablePosM1/M2`, `HomedM1/M2` | — | Sortie Encodeurs |
| `M1_Busy`/`M2_Busy` | BOOL | Interlock avant armement demande |
| `M1SlipToleranceM` :=1.0 | REAL | Tolérance glissement (couche 1) |
| `ConfirmOpenPosition`/`ClosePosition` | BOOL (front) | Référencement manuel MAINT_N1/N2 |
| `Config` (ST_fbBucket_Config) | — | `OffsetOpenM`, `OffsetCloseM`, `CoherenceLimitM`(0.05m) |

**Sorties** : `Ready/ActiveOffsetValid/Busy/Done/Error`, `ErrorId` (bit0 Timeout 60s 🆕 correction 2026-08-29, bit1 incohérence boot, bit2 limites dépassées, bit3 codeur non référencé, bit4 glissement M1), `M1SlipDetected`, `ActiveOffsetM`, `DeltaPosition_M`, `RemainingTravelM`, `M2_StartStop`/`Direction`/`ForceSlowSpeed`.

**Machine d'état** :
- **DISABLED** si `NOT Enable OR NOT PowerContactorEngaged` : neutralisation complète (`Ready := FALSE`, `ActiveOffsetValid := FALSE`, `ActiveOffsetM := 0.0` pour comparaison M1/M2 stricte sans fuite d'offset périmé vers Méca E, `DeltaPosition_M := 0.0`, `RemainingTravelM := 0.0`, `M2_StartStop := FALSE`, `M1SlipDetected := FALSE`, réinitialisation des requêtes).
- **READY** : accepte requête seulement si `NOT M1_Busy AND NOT M2_Busy` (anti-traversée)
- **BUSY** : pilote M2 seul, vitesse forcée lente ; sens inverse toléré mais **borné** à la position de départ (`M2StartPosM`)
- **DONE** : attend relâchement demande pour repasser READY

---

## 3. Protection glissement M1 — 2 couches

| Couche | Condition | Conséquence |
|---|---|---|
| **1** (`FB_Bucket`, bit4) | `State=BUSY` ET `\|CablePosM1-M1RefPosM\| > 1.0m` | Coupe M2 (SevereError interne), `M1SlipDetected` exposé — **consommé** par Treuils : force SafeStop M1 |
| **2** (`FB_Safety_Winch`, Méca C bit9, AF10) | `BenneHoldStillActive` (M1 seul, câblé sur `instBucket.Busy`) | Dérive M1 > **2.0m** ⇒ **PowerCutOff** |

Défense en profondeur : si couche 1 (SafeStop M2, 1.0m) ne suffit pas à arrêter M1 physiquement (roue libre, contacteur collé), couche 2 coupe la puissance amont à 2.0m.

---

## 4. FB_DiveSearch (assistant MAINT_N1/N2)

Qualification Kobold avant descente : `WAIT_PRECONDITIONS → READY_TO_DESCEND → SEARCHING_IMMERSION → SEARCHING_BOTTOM → BOTTOM_CONFIRMED`.

- Précondition : `BucketIsOpen`, positions valides, Kobold non immergé.
- `SEARCHING_IMMERSION` : front montant Kobold **dans fenêtre** `[ImmersionLower_M;ImmersionUpper_M]` sur M1 **et** M2.
- `SEARCHING_BOTTOM` : front descendant Kobold → `BottomTouchConfirmed`.
- Lit `BucketIsOpen` en entrée seule — **ne pilote jamais** la benne.

---

## 5. FB_ExtractionSequence (assistant MAINT_N1/N2)

Fermeture benne puis remontée contrôlée : `WAIT_BOTTOM_CONFIRMATION → READY_TO_CLOSE → CLOSING_BUCKET → CONTROL_ASCENT → NOMINAL_ASCENT`.

- `WAIT_BOTTOM_CONFIRMATION` : Kobold (`instDiveSearch.BottomTouchConfirmed`) OU attestation manuelle IHM.
- `CLOSING_BUCKET` : produit `BucketCloseRequest` → `instBucket.CmdClose_IHM`. Transition vers `CONTROL_ASCENT` dès fermé.
- `CONTROL_ASCENT` : force palier 1 (`ForceMinSpeedStep`) sur M1/M2, sort après distance parcourue confirmée sur les deux.

**Lien homme-mort** : `PreserveArmingAfterBucket := instExtractionSequence.Busy` (câblé dans `PRG_02_Acquisition`) — **seule** cette séquence préserve l'armement joystick en fin de fermeture pour enchaîner immédiatement palier 1, sous ses propres interlocks. `FB_DiveSearch` ne bénéficie pas de cette exception.

---

## 6. Bus et intégration programme

**Ordre dans `PRG_04_Treuils_Benne`** (vérifié) :
1. §1 `instBucket` (**appelé en premier**, avant arbitrage M1/M2 — évite fenêtre de commande manuelle parasite)
2. §2/§3 Arbitrage M1/M2 — **Benne prioritaire absolue sur M2** si `instBucket.Busy`
3. §3bis Assistance maintenance (DiveSearch/ExtractionSequence, si benne non busy)
4. §3ter Coupure immédiate M1/M2 au scan exact de fin cycle benne
5. Synchro suspendue pendant `instBucket.Busy`
6. Butée haute M2 décalée de `OffsetCloseM` si fermé/en fermeture

**Consommateurs `instBucket.Busy/Done`** : Treuils (arbitrage), Safety (`BenneHoldStillActive`, Méca E), `FB_ExtractionSequence`, `FB_Joystick` (désarmement), Supervision (IHM).

**Homme-mort** : axe Y joystick, même axe que pilotage normal M1/M2 — pas d'axe dédié.

---

## 7. Pourquoi Benne est une fiche FB de AF10 (pas une Partie séparée)

| Argument | Constat |
|---|---|
| Aucune I/O propre | Réutilise entièrement les Q de `FB_Winch` M2 |
| Couplage bidirectionnel fort | `FB_Bucket` a besoin de position/Homed M1+M2 ; `FB_WinchSync`/`FB_Safety_Winch` ont besoin en retour de `Busy`/`ActiveOffsetM`/`M1SlipDetected` |
| Organisation code déjà ainsi | `H_TREUILS_BENNE/BENNE/`, appelé dans `PRG_04_Treuils_Benne` — jamais remis en cause |
| Contenu propre suffisant | Offsets, Méca C couche 1, cinématique inversée, DiveSearch/ExtractionSequence — mérite sa fiche FB |

**Décision retenue** : FB_Bucket est une **fiche FB de la Partie 10** (Treuils), au même titre que
`FB_WinchSync` — pas une Partie séparée. Contenu suffisant pour sa fiche, mais pas de
programme/Safety propre (contrairement à Translation qui a son propre programme + Safety dédié).

---

## 8. Alertes et écarts

| # | Gravité | Point | Action |
|---|---|---|---|
| 1 | P1 | `OffsetCloseM` : doc legacy 10.0, code réel 15.0, non validé en charge (MES-010) | Corrigé ici, terrain à confirmer |
| 2 | P1 | DiveSearch/ExtractionSequence absents doc v1.4 | Comblé §4/§5 |
| 3 | P2 | T57 : possible doublon logique limite haute M2 | Non vérifié en profondeur — TBD |
| 4 | info | T27/T89 : cinématique/offset jamais essayés en charge réelle | TBD terrain |

---

## 9. Documents liés

| Doc | Lien |
|---|---|
| AF10 (chapô) | Rôle machine, intégration programme |
| AF10 / FB_Safety_Winch | Méca C couche 2 (bit9) |
| AF09 | Encodeurs — position/Homed consommés |
| AF04 | Cycle SEMI_AUTO — séquence dragage |
| AF05 | Modes — MAINT_N1/N2 requis pour assistants |
| Code | `CODE/TREUILS/BENNE/*.st`, `CODE/G_CYCLE/FB_DiveSearch.st`, `FB_ExtractionSequence.st` |
