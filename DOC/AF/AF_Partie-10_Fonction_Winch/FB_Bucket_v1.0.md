# FB_Bucket — Spec composant (v1.0)

> Rôle machine (vague) : [`AF_Partie-10_Fonction_Winch_v2.1.md`](AF_Partie-10_Fonction_Winch_v2.1.md) §1.
> Rôle de **ce** document : ouverture/fermeture benne par désynchronisation M1/M2, protection
> glissement, assistants maintenance — et **catalogue unique** des `TC-P10-023` à `TC-P10-034`.
> **Sous-fonction du domaine Treuils** (AF10) — aucune I/O ni programme propre.
> Source code : `CODE/H_TREUILS_BENNE/BENNE/*.st` (FB + `_TYPES/`) · instance unique `instBucket`
> dans `PRG_04_Treuils_Benne.st`.
>
> ⚠️ **Réaligné T339 (2026-09-20)** sur le code RÉEL, après 9 tests CI hors-sujet : sémantique du
> watchdog de timeout (§2 / `TC-P10-046.1`), mapping `ErrorId` exact (index de cause,
> `FB_FaultCore.st:49-57`), interface réelle (`ReqAscent`/`ReqDescend`, `EffectivePermitBucket_*`),
> et suppression de l'état benne latché (`TC-P10-030`, `TC-P10-047.1/.2`). Les écarts de CODE restants
> sont escaladés en §8 — **aucun fichier `CODE/` n'a été modifié par ce réalignement**.

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
        🚀 <b>Étape 1</b> : Demande <code>CmdClose_IHM</code> + sens <code>ReqAscent</code><br>
        ⚡ <b>Étape 2</b> : Permis de fermeture <code>EffectivePermitBucket_Close</code> ABSENT → aucun ordre M2<br>
        ✅ <b>Étape 3</b> : Ordre M2 émis seulement si <code>MotionRequestActive</code> ET <code>ReqAscent</code> ET <code>EffectivePermitBucket_Close</code> (<code>FB_Bucket.st:524</code>) — vitesse lente P1
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
        🚀 <b>Étape 1</b> : Demande <code>CmdOpen_IHM</code> + sens <code>ReqDescend</code><br>
        ⚡ <b>Étape 2</b> : Permis d'ouverture <code>EffectivePermitBucket_Open</code> ABSENT → aucun ordre M2<br>
        ✅ <b>Étape 3</b> : Ordre M2 émis seulement si <code>MotionRequestActive</code> ET <code>ReqDescend</code> ET <code>EffectivePermitBucket_Open</code> (<code>FB_Bucket.st:540</code>)
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§2</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-025</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Anti-</b><br>traversée</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : <code>State=READY</code>, entrée manœuvre benne<br>
        🚀 <b>Étape 1</b> : Demande <code>CmdOpen</code>/<code>CmdClose</code> avec <code>M1_Busy</code> OR <code>M2_Busy</code><br>
        ⚡ <b>Étape 2</b> : Refus de la demande benne (aucun latch de <code>CloseReq</code>/<code>OpenReq</code>, aucun <code>Busy</code>)<br>
        ✅ <b>Étape 3</b> : Refus porté par <code>FB_Bucket.st:484</code>/<code>:488</code> — refus à l'ENTRÉE seulement : une manœuvre DÉJÀ engagée n'est jamais avortée par <code>Mx_Busy</code> (le treuil agit alors sous l'ordre benne, <code>:520-558</code>)
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§2</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-026</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Glissement</b><br>M1 couche 1</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : Manœuvre benne (<code>State=BUSY</code>)<br>
        🚀 <b>Étape 1</b> : Glissement M1 &gt;1.0m pendant BUSY<br>
        ⚡ <b>Étape 2</b> : <code>ErrorId</code> bit 3 (valeur 8) + <code>M1SlipDetected</code> levés, coupe M2<br>
        ✅ <b>Étape 3</b> : Protection couche 1 active (dérive M1), défaut <b>latché</b>
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§3</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV-I</code></small></td>
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
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Recul</b><br>sous commande</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : Manœuvre benne engagée (<code>Busy</code>), position de départ mémorisée (<code>M2StartPosM</code>)<br>
        🚀 <b>Étape 1</b> : Recul (sens inverse : <code>ReqDescend</code> pendant une fermeture) sous commande toujours engagée<br>
        ⚡ <b>Étape 2</b> : Sens inverse honoré (permis opposé requis, <code>FB_Bucket.st:528</code>) : <code>M2_ReqDescend=TRUE</code>, <code>M2_ReqAscent=FALSE</code>, palier P1<br>
        ✅ <b>Étape 3</b> : Recul commandé, sans coupure parasite — ⚠️ la borne « jamais au-delà de <code>M2StartPosM</code> » a été RETIRÉE du code le 2026-09-05 (commit <code>2a307b5b</code>) : voir alerte §8 et <code>TC-P10-029.1</code> (rouge)
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§2</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-030</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Confirmer</b><br>position</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : Machine arrêtée, mode <code>MAINT_N1</code>/<code>MAINT_N2</code><br>
        🚀 <b>Étape 1</b> : Front <code>ConfirmOpenPosition</code>/<code>ConfirmClosePosition</code><br>
        ⚡ <b>Étape 2</b> : Effet <b>durable</b> = référence benne <code>BucketState.BucketReferenced</code>, acceptée en <code>MAINT_N2</code> SEUL et à l'arrêt (<code>FB_Bucket.st:339-357</code>, latch <code>:382-398</code>)<br>
        ✅ <b>Étape 3</b> : <code>MAINT_N1</code> et <code>SEMI_AUTO</code> → aucune référence ; ⚠️ <code>IsOpen</code>/<code>IsClosed</code> ne sont PAS latchés par la confirmation : depuis T247 ils sont re-classés à chaque scan sur la mesure (voir §2)
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§2</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-031</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Codeur</b><br>non réf.</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : Codeur (M1 ou M2) non référencé (<code>Homed=FALSE</code>)<br>
        🚀 <b>Étape 1</b> : Évaluation des besoins position benne<br>
        ⚡ <b>Étape 2</b> : <code>ErrorId</code> bit 4 (valeur 16) levé — <b>uniquement sur mouvement demandé</b> (<code>FB_Bucket.st:274-279</code>)<br>
        ✅ <b>Étape 3</b> : Cause LIVE (non latchée) : retombe sans <code>Reset</code> dès que M1 ET M2 sont référencés
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§3</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV-I</code></small></td>
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
        💤 <b>Étape 0</b> : Manœuvre benne (<code>Lifecycle.Busy</code>) SOUS commande opérateur engagée<br>
        🚀 <b>Étape 1</b> : Mouvement bloqué, commande maintenue sans progression<br>
        ⚡ <b>Étape 2</b> : Budget de <code>CfgTimeoutDuration</code> (défaut 60 s) épuisé → <code>ErrorId</code> bit 2 (valeur 4) + latch<br>
        ✅ <b>Étape 3</b> : Le budget ne compte QUE le <b>temps de commande réellement engagée</b> (<code>Lifecycle.Busy</code> ET <code>MotionRequestActive</code>, <code>FB_Bucket.st:210-259</code>) : il est <b>GELÉ</b> (pas remis à zéro) dès que l'opérateur relâche, puis <b>CUMULÉ</b> — une pause opérateur légitime ne produit donc plus de faux défaut (T295). Remise à zéro du cumul : fin de manœuvre + <code>Reset</code> sur front
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§2</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-047.1</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Boot</b><br>classification</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : 1er cycle, benne non référencée (<code>BucketReferenced=FALSE</code>)<br>
        🚀 <b>Étape 1</b> : Évaluation de l'état par la MESURE <code>Delta = M2 - M1</code><br>
        ⚡ <b>Étape 2</b> : L'état franc est publié en continu (<code>IsOpen</code>/<code>IsClosed</code>/<code>IsIntermediate</code>, <code>FB_Bucket.st:428-448</code>) et <code>ActiveOffsetValid=FALSE</code> tant que la benne n'est pas référencée (<code>:745-748</code>)<br>
        ✅ <b>Étape 3</b> : ⚠️ <b>Détection d'incohérence boot RETIRÉE par T247</b> (commit <code>509e0eb1</code>, 2026-09-04) — <code>StateIncoherent</code> ne subsiste QUE pour la neutralisation avec manœuvre engagée (<code>:300-303</code>). Voir alerte §8
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§2</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-047.2</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Boot</b><br>état écrasé</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : 1er cycle, état mémorisé CONTRADICTOIRE (<code>IsOpen=TRUE</code> ET <code>IsClosed=TRUE</code>)<br>
        🚀 <b>Étape 1</b> : Évaluation de l'état par la MESURE<br>
        ⚡ <b>Étape 2</b> : La mesure franche écrase les deux drapeaux (<code>FB_Bucket.st:428-448</code>)<br>
        ✅ <b>Étape 3</b> : ⚠️ <b>AUCUN diagnostic</b> n'est publié pour cette contradiction — et avec une <code>CoherenceLimitM</code> ≥ (<code>OffsetCloseM</code> − <code>OffsetOpenM</code>)/2 les deux bandes se recouvrent et <code>IsOpen=IsClosed=TRUE</code> sont publiés simultanément sans aucun signal (la cause 0 ne teste que <code>OffsetOpenM &lt; OffsetCloseM</code>, <code>:176-179</code>). Écart de spec signalé §8
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
- **Fermeture** : M2 enroule (monte) → sens demandé `ReqAscent`, ordre `M2_ReqAscent`
- **Ouverture** : M2 déroule (descend) → sens demandé `ReqDescend`, ordre `M2_ReqDescend`
- ⚠️ **Plus d'entier de direction** : l'interface porte **deux entrées BOOL** `ReqAscent`/`ReqDescend`
  (source unique de `MotionRequestActive`, `FB_Bucket.st:162-163`) et **deux sorties BOOL**
  `M2_ReqAscent`/`M2_ReqDescend` (`:68-69`). `MotionDirection` (INT) et `M2_Direction` n'existent plus.
- Cible : `CablePosM2 >= CablePosM1 + OffsetCloseM` (fermeture) ou `<= CablePosM1 + OffsetOpenM` (ouverture)

**Offsets réels (RETAIN)** : `OffsetOpenM=0.0` (référence neutre, M2=M1) ; `OffsetCloseM=15.0` (⚠️ doc legacy dit 10.0, non validé en charge — voir §8).

---

## 2. FB_Bucket

| Entrée | Type | Sens |
|---|---|---|
| `ReqAscent` / `ReqDescend` | BOOL | Demande de sens **déjà arbitrée** (joystick/IHM, axe Y) — `MotionRequestActive = (ReqAscent OR ReqDescend) AND NOT conflit` est calculé **en interne** (`FB_Bucket.st:162-163`) et **n'est PAS une entrée** : le passer en argument nommé est un argument MORT (garde-fou `G512`) |
| `EffectivePermitBucket_Open` / `_Close` | BOOL | Permis de sécurité : **sans eux, aucun ordre M2 ne sort** (`:524`, `:540`) |
| `CmdOpen_IHM` / `CmdClose_IHM` | BOOL | Demande IHM, latcheé à l'entrée si `NOT Busy AND NOT M1_Busy AND NOT M2_Busy` |
| `CablePosM1/M2`, `HomedM1/M2` | — | Sortie Encodeurs |
| `HomedAndReliableM1/M2` | BOOL | Datum fiable — condition de pose de la référence benne |
| `M1_Busy`/`M2_Busy` | BOOL | Anti-traversée : refuse une **nouvelle** demande (`:484`, `:488`) |
| `M1SlipToleranceM` :=1.0 | REAL | Tolérance glissement (couche 1) |
| `CfgTimeoutDuration` := `T#60s` | TIME | Budget du watchdog de timeout (§2 / <nobr><code>TC-P10-046.1</code></nobr>) |
| `ConfirmOpenPosition`/`ConfirmClosePosition` | BOOL (front) | Référencement manuel — **MAINT_N2 seul**, à l'arrêt |
| `Config` (ST_fbBucket_Config) | — | `OffsetOpenM`, `OffsetCloseM`, `CoherenceLimitM` — ⚠️ **aucun défaut dans le type** : valeurs de production posées par `GVL_PERSISTENT.st:66-70` (`OffsetOpenM=0.0`, `OffsetCloseM=15.0`, `CoherenceLimitM=1.0`) |

**Sorties** : `Ready`, `ActiveOffsetValid`, `Fault` (`ST_Fault` : `Error`/`ErrorId` latches), `Lifecycle` (`Busy`/`Done`), `M1SlipDetected`, `ActiveOffsetM`, `DeltaPosition_M`, `RemainingTravelM`, `M2_RunRequest` (ordre marche M2), `M2_ReqAscent`/`M2_ReqDescend` (sens, BOOL) et `M2_BucketJogLimit` (plafond palier 1).

**`ErrorId` — mapping RÉEL** (bitfield `SHL(WORD#1, i)` sur l'index de cause, `FB_FaultCore.st:49-57` ; causes déclarées `FB_Bucket.st:172-291`) :

| Bit | Valeur | Cause | Latch |
|---|---|---|---|
| 0 | 1 | `instCauses[0]` — Configuration géométrie benne invalide (`OffsetOpenM >= OffsetCloseM` ou `< -2.0`) | oui |
| 1 | 2 | `instCauses[1]` — Dépassement écart maximum autorisé (`M2-M1` hors plage, confirmé 500 ms) | oui |
| 2 | 4 | `instCauses[2]` — **Timeout de commande de déplacement benne** (temps de commande engagée ; <nobr><code>TC-P10-046.1</code></nobr>) | oui |
| 3 | 8 | `instCauses[3]` — Glissement treuil M1 pendant manœuvre benne | oui |
| 4 | 16 | `instCauses[4]` — Codeurs treuils non référencés pour séquence benne (sur mouvement demandé) | **non** (live) |

> ⚠️ Correction T339 : la version précédente de cette fiche annonçait « bit0 Timeout, bit1 incohérence boot, bit2 limites dépassées, bit3 codeur non référencé, bit4 glissement M1 » — **tout était décalé d'un rang** (et « incohérence boot » n'est plus une cause du tout, cf. §8).

**Machine d'état** :
- **DISABLED** si `NOT Enable OR NOT PowerContactorEngaged` : neutralisation complète (`Ready := FALSE`, `ActiveOffsetValid := FALSE`, `ActiveOffsetM := 0.0` pour comparaison M1/M2 stricte sans fuite d'offset périmé vers Méca E, `DeltaPosition_M := 0.0`, `RemainingTravelM := 0.0`, ordres M2 relâchés, `M1SlipDetected := FALSE`, réinitialisation des requêtes). `StateIncoherent := TRUE` **si et seulement si** une manœuvre était engagée (`Busy`/`CloseReq`/`OpenReq`, `:300-303`).
- **READY** : accepte une nouvelle requête seulement si `NOT M1_Busy AND NOT M2_Busy` (anti-traversée, `:484`/`:488`)
- **BUSY** : pilote M2 seul, vitesse forcée lente (P1) ; ordre émis seulement sous `MotionRequestActive` ET sens ET **permis adapté au sens** ; sens inverse (recul) honoré sous le permis opposé — ⚠️ **la borne à la position de départ n'existe PLUS** depuis le 2026-09-05 (commit `2a307b5b`) : `LeftStartSinceArm` est encore affecté (`:561`) mais **jamais lu** (cf. §8, alerte 5)
- **DONE** : attend relâchement demande pour repasser READY
- **État publié** (`IsOpen`/`IsClosed`/`IsIntermediate`/`TooOpen`/`TooClosed`) : **classification continue** sur `Delta = M2 - M1` à chaque scan dès que M1 ET M2 sont référencés (`:428-448`) — plus d'état latché depuis T247 (commit `509e0eb1`)

**Watchdog de timeout de manœuvre** (`TC-P10-046.1` à `.4`, T295) : budget `CfgTimeoutDuration` consommé **uniquement** pendant une commande réellement engagée (`TimeoutEngaged := Lifecycle.Busy AND MotionRequestActive`, `:221`) ; **gelé** — jamais remis à zéro — hors engagement (`:233-236`), **cumulé** au réengagement (`:239`), remis à zéro en fin de manœuvre (`Busy` retombe, `:256-259`) et sur `Reset` **sur front** (`:226-230`). Conséquence : une pause opérateur légitime (relâchement du joystick en `AX3_OPEN_BUCKET` / `AX15B_DUMP_OPEN`) ne produit plus de faux `[BENNE] ErrorID:03`.

---

## 3. Protection glissement M1 — 2 couches

| Couche | Condition | Conséquence |
|---|---|---|
| **1** (`FB_Bucket`, bit 3 = valeur 8) | `Lifecycle.Busy` ET `\|CablePosM1-M1RefPosM\| > 1.0m` | Coupe M2 (SevereError interne), `M1SlipDetected` exposé — **consommé** par Treuils : force SafeStop M1 |
| **2** (`FB_Safety_Winch`, Méca C bit9, AF10) | `BenneHoldStillActive` (M1 seul, câblé sur `instBucket.Busy`) | Dérive M1 > **2.0m** ⇒ **PowerCutOff** |

Défense en profondeur : si couche 1 (SafeStop M2, 1.0m) ne suffit pas à arrêter M1 physiquement (roue libre, contacteur collé), couche 2 coupe la puissance amont à 2.0m.

---

## 4. FB_DiveSearch (assistant MAINT_N1/N2)

> ⛔ **COMPOSANT RETIRÉ DU CODE** (constat T339, 2026-09-20) : `FB_DiveSearch.st` et
> `FB_ExtractionAssist.st` **n'existent plus** dans `CODE/` — « assistants retires (legacy, jamais
> actives) » (`PRG_03_Modes_Cycle.st:176`, `:413`, `FB_TroubleshootingView.st:371`). Les §4 et §5
> ci-dessous sont conservés comme **archive de spec** et ne décrivent AUCUN code actif ; le
> `TC-P10-032` associé ne peut plus être testé en boîte noire (voir alerte §8).

Qualification Kobold avant descente : `WAIT_PRECONDITIONS → READY_TO_DESCEND → SEARCHING_IMMERSION → SEARCHING_BOTTOM → BOTTOM_CONFIRMED`.

- Précondition : `BucketIsOpen`, positions valides, Kobold non immergé.
- `SEARCHING_IMMERSION` : front montant Kobold **dans fenêtre** `[ImmersionLower_M;ImmersionUpper_M]` sur M1 **et** M2.
- `SEARCHING_BOTTOM` : front descendant Kobold → `BottomTouchConfirmed`.
- Lit `BucketIsOpen` en entrée seule — **ne pilote jamais** la benne.

---

## 5. FB_ExtractionSequence (assistant MAINT_N1/N2)

> ⛔ **COMPOSANT RETIRÉ DU CODE** — voir l'encadré §4. Archive de spec, aucun code actif.

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

**Consommateurs `instBucket.Busy/Done`** : Treuils (arbitrage), Safety (`BenneHoldStillActive`, Méca E), `FB_Joystick` (désarmement), Supervision (IHM). (L'ancien consommateur `FB_ExtractionSequence` est retiré du code — cf. §5.)

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
| 2 | P1 | DiveSearch/ExtractionSequence cités §4/§5 mais **retirés du code** (`PRG_03_Modes_Cycle.st:176`) — <nobr><code>TC-P10-032</code></nobr> non testable en boîte noire | Encadrés ⛔ posés §4/§5 ; suppression des sections = décision humaine |
| 3 | P2 | T57 : possible doublon logique limite haute M2 | Non vérifié en profondeur — TBD |
| 4 | info | T27/T89 : cinématique/offset jamais essayés en charge réelle | TBD terrain |
| **5** | 🔴 **P1 (ESCALADÉ T339)** | **Perte de la borne de recul** : les deux branches d'arrêt à `M2StartPosM` ont été retirées le 2026-09-05 (commit `2a307b5b`, « suppression des coupures parasites ») ; `LeftStartSinceArm` reste **affecté** (`FB_Bucket.st:561`) mais n'est **plus jamais lu** (code mort) | ⛔ **Aucune correction dans le lot T339 (C2, zéro fichier `CODE/`)**, aucun arbitrage humain tracé. Conséquence : sous commande de fermeture toujours engagée, un recul (`ReqDescend`) n'est plus borné par `FB_Bucket` — seul le retour à la cible de fermeture l'arrête. **Arbitrage orchestrateur requis : restaurer la borne, ou acter la perte et supprimer le témoin mort + cet écart.** Preuve vivante : <nobr><code>TC-P10-029.1</code></nobr> (ROUGE, assertion `Recul a M2StartPosM -> M2_StartStop=FALSE`) |
| **6** | 🟠 **P2 (ESCALADÉ T339)** | **Plus aucune détection d'état contradictoire** : depuis T247 (commit `509e0eb1`, 2026-09-04) `StateIncoherent` n'est plus posé que sur neutralisation avec manœuvre engagée (`:300-303`) ; il n'y a plus de garde contre `IsOpen=IsClosed=TRUE` ni contre un recouvrement des bandes (`CoherenceLimitM >= (OffsetCloseM-OffsetOpenM)/2`, la cause 0 ne teste que `OffsetOpenM < OffsetCloseM`, `:176-179`). Or `StateIncoherent` conditionne encore `ActiveOffsetValid` (`:747`) | ⛔ Signalé, non corrigé (lot T339 = tests + doc). Options : restaurer une détection contradictoire (CODE), ou borner `CoherenceLimitM` à la config (cause 0). <nobr><code>TC-P10-047.2</code></nobr> documente le comportement réel |
| **7** | info (T339) | Mapping `ErrorId` de cette fiche **faux depuis l'origine** (décalage d'un rang) + sémantique du watchdog de timeout, interface (`MotionRequestActive`/`MotionDirection` présentés comme entrées) et état latché (<nobr><code>TC-P10-030</code></nobr>) désalignés du code | ✅ Réaligné dans ce document (§1, §2, catalogue <nobr><code>TC-P10-023</code></nobr> à <nobr><code>TC-P10-031</code></nobr>, <nobr><code>TC-P10-046.1</code></nobr>, <nobr><code>TC-P10-047.1</code></nobr>) ; 9 tests CI réécrits + garde-fou `G512` (arguments nommés morts) |
| **8** | info (T339) | ⚠️ Le harnais STruCpp **ne remet pas à zéro** les entrées non repassées entre deux appels d'un test (instance C++ persistante) : un test peut hériter du scan précédent | Piège documenté dans `test_fb_bucket.st` (<nobr><code>TC-P10-029</code></nobr> / <nobr><code>TC-P10-029.1</code></nobr>) |

---

## 9. Documents liés

| Doc | Lien |
|---|---|
| AF10 (chapô) | Rôle machine, intégration programme |
| AF10 / FB_Safety_Winch | Méca C couche 2 (bit9) |
| AF09 | Encodeurs — position/Homed consommés |
| AF04 | Cycle SEMI_AUTO — séquence dragage |
| AF05 | Modes — MAINT_N2 requis pour le référencement benne |
| Code | `CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st` + `_TYPES/` · tests `TOOLS/TEST_AUTO_CI/RESULTS/H_TREUILS_BENNE/tests/test_fb_bucket.st` · garde-fou `TOOLS/AGENT_WORKFLOW/scripts/G512_check_dead_ci_test_arguments.py` |
| ~~`FB_DiveSearch` / `FB_ExtractionSequence`~~ | ⛔ **retirés du code** (legacy jamais actifs) — voir §4/§5 et alerte 2 |
