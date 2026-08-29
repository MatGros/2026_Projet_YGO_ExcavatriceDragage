# FB_EncoderReliability — Spec composant (v1.0)

> Rôle machine : [`AF_Partie-09_Fonction_Encoder_v2.2.md`](../AF_Partie-09_Fonction_Encoder_v2.2.md)
> §6 — couvre `F09.06`.
> Rôle de **ce** document : les 2 gates de fiabilité de la chaîne codeur.
> Source code : `CODE/E_CODEURS/FB_EncoderReliability.st` · sous-instance `instRel` de `FB_Encoder`.

## 🧭 Sommaire

1. 🎯 Rôle et profil
2. 🧪 Table des points de validation (détail)
3. 🔌 Interface
4. 🔒 Les 2 gates
5. ⚠️ Alertes et écarts
6. 📚 Documents liés

## 1 · 🎯 Rôle et profil

Calcul combinatoire **pur, sans mémoire ni machine d'état**. Synthétise en un seul endroit « le
codeur est fiable », pour éviter que chaque consommateur recompose sa propre formule
(responsabilité scindée : Homing = référencement, Safety = cohérence, ce FB = synthèse).

⚠️ **Classification AF03 non tranchée** : ce FB n'a ni `Enable`, ni `Ready`, ni `Reset` — il ne
respecte donc pas même le contrat `light` (qui exige au minimum `Enable`+`Ready`, AF03 §2). Il
correspond au profil `🔧 Brique technique` d'AF03 §2 (« contrat minimal propre à son rôle »),
mais AF03 §2 dit aussi que *« tout FB relève de l'un des 2 contrats socle light/standard »* —
ces deux passages ne sont pas réconciliés dans AF03 lui-même. Voir §5.

## 2 · 🧪 Table des points de validation (détail)

Décline `TC-P09-040` (chapô) :

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
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P09-040.1</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Non-référencé</b><br>≠ incohérent</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : <code>EncoderAvailable=TRUE</code>, <code>Homed=FALSE</code>, <code>EncoderIncoherent=FALSE</code><br>
        🚀 <b>Étape 1</b> : Évaluation <code>EncoderFault := NOT Available OR Incoherent</code><br>
        ⚡ <b>Étape 2</b> : <code>Available=TRUE</code> et <code>Incoherent=FALSE</code> → <code>EncoderFault=FALSE</code><br>
        ✅ <b>Étape 3</b> : Non-référencé (<code>Homed=FALSE</code>) n'affecte pas <code>EncoderFault</code>
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§4</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P09-040.2</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Gate stricte</b><br>exige Homed</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : Même cas (<code>Available=TRUE</code>, <code>Homed=FALSE</code>, <code>Incoherent=FALSE</code>)<br>
        🚀 <b>Étape 1</b> : Évaluation <code>HomedAndReliable := Available AND Homed AND NOT Incoherent</code><br>
        ⚡ <b>Étape 2</b> : <code>Homed=FALSE</code> → gate stricte FALSE<br>
        ✅ <b>Étape 3</b> : <code>HomedAndReliable=FALSE</code> (gate stricte exige <code>Homed</code>)
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§4</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P09-040.3</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Bus KO</b><br>→ Fault</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : <code>EncoderAvailable=TRUE</code>, état nominal<br>
        🚀 <b>Étape 1</b> : <code>EncoderAvailable=FALSE</code> (perte bus/esclave)<br>
        ⚡ <b>Étape 2</b> : <code>EncoderFault=TRUE</code> quel que soit <code>Homed</code>/<code>EncoderIncoherent</code><br>
        ✅ <b>Étape 3</b> : <code>HomedAndReliable=FALSE</code> (gate stricte exige <code>Available</code>)
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§4</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P09-040.4</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Table</b><br>vérité 8</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : 8 combinaisons <code>(Available, Homed, Incoherent)</code> à tester<br>
        🚀 <b>Étape 1</b> : Évaluation des 2 gates sur chaque combo<br>
        ⚡ <b>Étape 2</b> : Vérification exhaustive <code>EncoderFault</code> et <code>HomedAndReliable</code><br>
        ✅ <b>Étape 3</b> : Table de vérité complète validée (<code>FB_EncoderReliability.st:30,34</code>)
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§4</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P09-040.5</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><b>Incohérent</b><br>→ Fault</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        💤 <b>Étape 0</b> : <code>EncoderAvailable=TRUE</code>, <code>Homed=TRUE</code><br>
        🚀 <b>Étape 1</b> : <code>EncoderIncoherent=TRUE</code> (hors bornes ou suspect)<br>
        ⚡ <b>Étape 2</b> : <code>EncoderFault=TRUE</code> et <code>HomedAndReliable=FALSE</code><br>
        ✅ <b>Étape 3</b> : Incohérence fait tomber les 2 gates (<code>FB_EncoderReliability.st:30,34</code>)
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§4</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>NV-I</code></small></td>
    </tr>
  </tbody>
</table>

## 3 · 🔌 Interface

### Entrées (`VAR_INPUT`)

| Port | Type | Rôle |
|---|---|---|
| `EncoderAvailable` | `BOOL` | Codeur opérationnel sur bus (`FB_Encoder_Abs`) |
| `Homed` | `BOOL` | Codeur référencé (`FB_Encoder_Homing`) |
| `EncoderIncoherent` | `BOOL` | Incohérence ou hors bornes (`FB_Encoder_Safety`) |

### Sorties (`VAR_OUTPUT`)

| Port | Type | Rôle |
|---|---|---|
| `EncoderFault` | `BOOL` | Gate général fiabilité (sans `Homed`) |
| `HomedAndReliable` | `BOOL` | Gate stricte (disponible ET référencé ET pas incohérent) |

## 4 · 🔒 Les 2 gates

```text
EncoderFault     := NOT EncoderAvailable OR EncoderIncoherent
HomedAndReliable := EncoderAvailable AND Homed AND NOT EncoderIncoherent
```

| Gate | Usage | Distinction clé |
|---|---|---|
| `EncoderFault` | Fiabilité de mesure (vitesse, mouvements) | **Sans** `Homed` — un codeur jamais référencé n'est pas "en défaut", juste non calibré |
| `HomedAndReliable` | Interlock strict (ex. hauteur M3) | Exige les 3 conditions — réservé aux décisions qui ont besoin d'une position **connue** |

Ne jamais recomposer ces formules chez un consommateur — lire directement `EncoderFault`/
`HomedAndReliable` produits ici.

## 5 · ⚠️ Alertes et écarts

| # | Gravité | Point | Action |
|---|---|---|---|
| 1 | 🔴 à trancher | Ce FB n'a ni `Enable`/`Ready`/`Reset` — sous le plancher du contrat `light` (AF03 §2). Correspond au profil `🔧 Brique technique` (AF03 §2, liste des profils), mais AF03 dit aussi que tout `FB_*` relève de `light`/`standard` — les deux passages d'AF03 ne sont pas réconciliés. **Ni un défaut de ce FB ni de cette fiche** : question d'arbitrage sur AF03 lui-même. | Arbitrage humain requis avant de modifier AF03 ou d'ajouter `Enable`/`Ready` au code sans raison fonctionnelle |

## 6 · 📚 Documents liés

| Doc | Lien |
|---|---|
| AF09 (chapô) | Rôle machine, façade `FB_Encoder` |
| AF06 | Agrégation `EncoderFault` M1/M2 (`ST_EncoderMeasurements`, consommateurs Modes/Safety) |
| Code | `CODE/E_CODEURS/FB_EncoderReliability.st` |
