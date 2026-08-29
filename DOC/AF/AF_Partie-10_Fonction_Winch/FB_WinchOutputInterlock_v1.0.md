# FB_WinchOutputInterlock — Spec composant (v1.0)

> Rôle machine (vague) : [`AF_Partie-10_Fonction_Winch_v2.1.md`](AF_Partie-10_Fonction_Winch_v2.1.md) §6.
> Rôle de **ce** document : barrière finale, watchdog frein, machine d'état, anti-redémarrage —
> et **catalogue unique** des `TC-P10-012`, `013`, `020`.
> Source code : `CODE/H_TREUILS_BENNE/FB_WinchOutputInterlock.st` · instances dans `PRG_06_Outputs`.

## 🧭 Sommaire

1. Rôle et profil
2. Interface
3. Machine d'état
4. Séquence hausse palier
5. Anti-redémarrage
6. Alertes et écarts
7. Documents liés

## 🧪 Table des points de validation (détail)

> Propriétaire unique du catalogue détaillé de la plage indiquée (`TC-P10-012/013/020/021/022`) — ce catalogue fait foi ; le chapô AF ne le recopie pas.

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
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-012</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Watchdog</b><br>frein</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : <code>BrakeCmd=TRUE</code>, <code>BrakeFeedback=FALSE</code>, <code>RestartInhibit=FALSE</code> — watchdog armé<br>
        🚀 <b>Étape 1</b> : Maintien 500ms sans confirmation frein<br>
        ⚡ <b>Étape 2</b> : <code>ErrorId</code> bit0, <code>RestartInhibit:=TRUE</code>, <code>Reason:=BRAKE_COMMAND_NOT_CONFIRMED</code>, FAULT<br>
        ✅ <b>Étape 3</b> : Pas de faux défaut au <code>RestartRequired</code> — <code>BrakeCmd</code> retenu par <code>RestartRequired</code> (jusqu'à 1000ms) n'arme PAS le watchdog (armé sur <code>BrakeCmd</code> final, jamais sur <code>RequestedRelayFwd/Rev</code>)
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>⚡ AUTO_PLC</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§3</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-013</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Latch</b><br>défaut</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : État nominal, aucun défaut<br>
        🚀 <b>Étape 1</b> : Provoquer un défaut (timeout frein) → <code>ErrorId</code>/<code>RestartInhibit</code>/<code>ResetRequired</code> latches<br>
        ⚡ <b>Étape 2</b> : Couper <code>Enable</code> (ou AU) → sorties FALSE, MAIS <code>ErrorId</code>/<code>RestartInhibit</code>/<code>ResetRequired</code> préservés<br>
        ✅ <b>Étape 3</b> : Réautorisation = cause disparue + front Reset + demande neutre + nouvelle demande distincte → <code>RestartInhibit:=FALSE</code>
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>⚡ AUTO_PLC</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§5</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-020</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Watchdog</b><br>terrain</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : Essai réel, frein + contacteur/bobine sur le banc<br>
        🚀 <b>Étape 1</b> : Injecter un défaut de confirmation frein<br>
        ⚡ <b>Étape 2</b> : Mesurer le comportement watchdog réel (times, contacteur/bobine)<br>
        ✅ <b>Étape 3</b> : Watchdog frein validé sur le terrain
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>🟢 SITE</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§3</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-021</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Temps mort</b><br>même sens</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : Arrêt commandé, <code>MotorRequest=FALSE</code><br>
        🚀 <b>Étape 1</b> : Nouvelle demande dans le même sens avant expiration<br>
        ⚡ <b>Étape 2</b> : Temps mort <code>DeadTimeSameDir</code> (défaut 1s) respecté après arrêt<br>
        ✅ <b>Étape 3</b> : Redémarrage même sens bloqué tant que le temps mort n'est pas écoulé
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§5</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-022</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Temps mort</b><br>inversion</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : Arrêt commandé, <code>MotorRequest=FALSE</code><br>
        🚀 <b>Étape 1</b> : Nouvelle demande en sens inverse avant expiration<br>
        ⚡ <b>Étape 2</b> : Temps mort <code>DeadTimeOppositeDir</code> (défaut 1s, &gt; même sens) — en sus du délai d'inversion 200ms FB_Winch<br>
        ✅ <b>Étape 3</b> : Inversion bloquée tant que le temps mort n'est pas écoulé
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§5</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P10-039.1</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Frein</b><br>couplé direct</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : Tout état machine (Error/RestartInhibit/RestartRequired)<br>
        🚀 <b>Étape 1</b> : Calcul <code>BrakeCmd</code> :=\: <code>RelayFwd</code> OR <code>RelayRev</code><br>
        ⚡ <b>Étape 2</b> : Vérification sur tous les états<br>
        ✅ <b>Étape 3</b> : Jamais de divergence frein/mouvement — frein suit directement la commande de sens
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§2bis</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV-I</code></small></td>
    </tr>
  </tbody>
</table>

---

## 1. Rôle et profil

Profil **barrière finale** (Partie3 §2) : reçoit la demande sortie typée (`ST_WinchFinalInterlockRequest`),
applique les interlocks ultimes, produit **seule** la commande physique autorisée (Q réelles).
2 instances : `instWinchOutputInterlockM1`, `instWinchOutputInterlockM2`, dans `PRG_06_Outputs`.

`FB_Winch`/`ST_SpeedStepTable` restent propriétaires du **mapping** palier→contacteurs ; cette
barrière **autorise ou masque** la demande, ne la reconstruit jamais.

---

## 2. Interface

| Entrée | Sens |
|---|---|
| `Enable/Reset/PowerContactorEngaged` | Standard |
| `SafeStop` | Reçu de `FB_Winch` (déjà arbitré) |
| `BrakeReleaseRequest`/`BrakeCommandOpenConfirmed` | Demande + confirmation frein |
| `FwdRevSpeedFeedbackOff` | Confirmation arrêt réel |
| `RequestedRelayFwd/Rev`, `RequestedContactor1..4`, `RequestedStep` | Demande brute `ST_WinchFinalInterlockRequest` |

**Sorties** : `RelayFwd/Rev`, `Contactor1..4`, `BrakeCmd` (Q physiques), `State`, `Reason`
(`E_WinchFinalInterlockReason`), `AuthorizedStep`, `RestartInhibit`, `ErrorId`.

---

## 3. Machine d'état (`E_WinchFinalInterlockState`)

```text
DISABLED(0) → READY(1) → WAIT_BRAKE_COMMAND_CONFIRMATION(2) → WAIT_STEP_DELAY(3)
                                                              → WAIT_RESTART_DELAY(4)
                                                              → FAULT(5)
```

**Watchdog frein** : `T#500ms` fixe (câblé en dur) — armé si `BrakeReleaseRequest AND NOT
BrakeCommandOpenConfirmed AND NOT RestartInhibit`. Timeout ⇒ bit0 `ErrorId`, `RestartInhibit:=TRUE`,
`Reason:=BRAKE_COMMAND_NOT_CONFIRMED`, état FAULT.

**Gate final (double condition obligatoire)** : `RelayFwd/Rev`+`Contactor1..4` autorisés
**seulement si** `MovementRequested AND BrakeReleaseRequest AND BrakeCommandOpenConfirmed`.

---

## 5. Anti-redémarrage et temps mort de redémarrage

`RestartDelay` = **900ms** (paramétrable) après `FwdRevSpeedFeedbackOff` confirmé.

**Nouveau : temps mort de redémarrage après arrêt** — distinct du redémarrage post-faute :
- **Redémarrage même sens** : temps mort paramétrable `DeadTimeSameDir` (défaut **1s**) après `MotorRequest=FALSE` → nouvelle demande.
- **Redémarrage inversion sens** : temps mort paramétrable `DeadTimeOppositeDir` (défaut **1s**, > temps mort même sens) — **en sus** du délai d'inversion 200ms FB_Winch.

Ces temps morts s'appliquent **dans la barrière finale** (cette FB), supérieurs aux délais internes FB_Winch (inversion 200ms + palier 1s250ms).

---

## 5. Séquence hausse palier

`StepDelay` = **1s250ms** — l'`AuthorizedStep` progresse un par un, invalidé si la cible change.

⚠️ **Écart vérifié** : ce délai (1s250ms, barrière finale) est **distinct** du délai métier
`BusinessStepDelay` = **1s500ms** dans `FB_Winch` — les deux se cumulent en cascade (~2.75s total
possible par montée de 2 paliers). Non documenté comme volontaire dans le code — voir AF10 §9bis.

---

## 5. Anti-redémarrage

`RestartDelay` = 900ms après `FwdRevSpeedFeedbackOff` confirmé. Réautorisation complète exige :
cause disparue + front Reset + demande neutre observée + nouvelle demande **distincte** avant de
réarmer `RestartInhibit`.

---

## 6. Alertes et écarts

| # | Gravité | Point | Action |
|---|---|---|---|
| 1 | P1 | Double délai palier (1s500 FB_Winch + 1s250 barrière) empilé, jamais clarifié voulu | Voir AF10 §9bis |
| 2 | P2 | **Temps mort redémarrage (même sens / inversion sens) absent des specs actuelles** | Ajouté §4, à valider terrain |

---

## 7. Documents liés

| Doc | Lien |
|---|---|
| AF10 (chapô) | Rôle machine, intégration programme |
| AF10 / FB_Winch | Producteur de la demande (`ST_WinchFinalInterlockRequest`) |
| AF03 | Profil barrière finale |
| Code | `CODE/H_TREUILS_BENNE/FB_WinchOutputInterlock.st` |
