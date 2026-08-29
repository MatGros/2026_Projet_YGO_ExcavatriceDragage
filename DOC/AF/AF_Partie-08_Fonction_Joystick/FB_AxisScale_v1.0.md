# FB_AxisScale — Spec composant (v1.0)

> Rôle machine : [`AF_Partie-08_Fonction_Joystick_v2.5.md`](../AF_Partie-08_Fonction_Joystick_v2.5.md)
> §4 — couvre `F08.02` (codes du chapô). `TC-P08-010` reste **au chapô** (macro partagé avec
> `F08.01`/`FB_Joystick`, règle guide 3-6 TC macro) — pas de nouvel identifiant ici.
> Rôle de **ce** document : le détail technique — interface complète, formule, contrat — que le
> chapô ne portait pas avant v2.4/v1.0 (écart constaté lors d'un mini-audit AF08 vs code, 2026-08-26).
> Source code : `CODE/D_JOYSTICK/FB_AxisScale.st` · instancié deux fois dans `FB_Joystick`
> (`ScaleX`/`ScaleY`).

## 🧭 Sommaire

1. [🎯 Rôle et profil](#1-rôle-et-profil)
2. [🧪 Table des points de validation (détail)](#2-table-des-points-de-validation-détail)
3. [🔌 Interface](#3-interface)
4. [⚙️ Formule — mise à l'échelle asymétrique](#4-formule-mise-à-léchelle-asymétrique)
5. [📚 Documents liés](#5-documents-liés)

## 1 · 🎯 Rôle et profil

Calculateur pur, instancié deux fois dans `FB_Joystick` (`ScaleX`/`ScaleY`) — convertit une valeur
brute ADC en consigne d'axe signée, avec zone morte et saturation.

**Pas de contrat `light`** au sens strict d'AF03 §3 : ni `Enable` ni `Ready` propres. Justification :
un pur calcul sans état interne et sans défaut à remonter n'a rien à neutraliser ni à recopier —
il est neutralisé **indirectement** par le gate de son appelant (`FB_Joystick` : `NOT Enable OR
BusLost` → `RETURN` avant même l'appel à `ScaleX`/`ScaleY`, voir `FB_Joystick.st` §2). Une brique
technique de ce type (AF03 §3 « Brique technique ») ne reçoit pas artificiellement un cycle de vie
dont elle n'a pas l'usage.

## 2 · 🧪 Table des points de validation (détail)

> Décline `TC-P08-010` (macro chapô, partagé `F08.01`+`F08.02`) en étapes numérotées — pas de
> nouvel identifiant racine (`GUIDE_EDITION_AF_v1.0.md` §4, `FB_SPEC_TEMPLATE.md` §2).

> **État** — `V` validé, implémentation non vérifiée · `V-I` validé et implémenté · `NV` non validé, non implémenté · `NV-I` code présent mais non validé · `R` refusé · `NA` non applicable.

<table style="width: 100%; table-layout: fixed; border-collapse: collapse; font-size: 14px;">
  <colgroup>
    <col style="width: 40px;">
    <col style="width: calc(100% - 310px);">
    <col style="width: 90px;">
    <col style="width: 140px;">
    <col style="width: 40px;">
  </colgroup>
  <thead>
    <tr style="border-bottom: 2px solid #475569; text-align: left;">
      <th style="padding: 4px 1px; text-align: center;"><small><b>ID</b></small></th>
      <th style="padding: 4px 8px;">Comportement attendu</th>
      <th style="padding: 4px 1px; text-align: center;"><small>Type</small></th>
      <th style="padding: 4px 1px; text-align: center;"><small>Réf</small></th>
      <th style="padding: 4px 1px; text-align: center;"><small>État</small></th>
    </tr>
  </thead>
  <tbody>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P08-010.1</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Échelle proportionnelle asymétrique : <code>RawX=9000</code> (neutre 5000) → <code>80%</code> ; <code>RawY=300</code> (neutre 5000) → <code>-94%</code> — pas seulement aux bornes</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>§4</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P08-010.2</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Deadband centrée sur le neutre : <code>|RawIn−Neutral| ≤ DeadbandRaw</code> ⇒ <code>OutPct=0.0</code> ; borne exacte : <code>RawIn=Neutral±DeadbandRaw</code> → 0.0, <code>RawIn=Neutral±(DeadbandRaw+1)</code> → <code>|OutPct|&gt;0</code></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>§4</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P08-010.3</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Saturation stricte : <code>RawIn=10000</code> (neutre 5000) → +100.0 ; <code>RawIn=0</code> → −100.0 ; toute sortie de plage <code>RawIn</code> ne produit jamais <code>|OutPct|&gt;100.0</code> (<code>LIMIT(−100,OutPct,100)</code>)</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>§4</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P08-010.4</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Échelle asymétrique neutre≠5000 : normalisation indépendante de chaque demi-plage</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>§4</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV-I</code></small></td>
    </tr>
  </tbody>
</table>

## 3 · 🔌 Interface

| Sens | Port | Type | Rôle |
|---|---|---|---|
| IN | `RawIn` | `INT` | Valeur brute ADC (0..10000) |
| IN | `Neutral` | `INT` | Point neutre calibré (`NeutralXMem`/`NeutralYMem`, fourni par `FB_Joystick`) |
| IN | `DeadbandRaw` | `INT` | Zone morte en points ADC bruts (déf. 300, `GVL_PERSISTENT`) |
| OUT | `OutPct` | `REAL` | Consigne mise à l'échelle, signée (-100.0..+100.0 %) |

## 4 · ⚙️ Formule — mise à l'échelle asymétrique

La demi-plage haute (`Neutral`→10000) et la demi-plage basse (0→`Neutral`) n'ont pas la même
amplitude en points ADC bruts dès que le neutre calibré n'est pas exactement au milieu (`5000`) —
la formule normalise chaque côté indépendamment sur sa propre amplitude :

```text
Si RawIn >= Neutral : OutPct = (RawIn - Neutral) / (10000 - Neutral) * 100.0
Sinon                : OutPct = (RawIn - Neutral) / Neutral * 100.0
Si |RawIn - Neutral| <= DeadbandRaw : OutPct = 0.0   (zone morte)
Saturation stricte finale : OutPct = LIMIT(-100.0, OutPct, 100.0)
```

**Saturation finale** (`LIMIT(-100.0, OutPct, 100.0)`) : garde-fou indépendant de la détection de
défaut capteur `RawOutOfRange` (portée par `FB_Joystick`, pas par `FB_AxisScale` — ce dernier ne
sait pas qu'un `RawIn` hors plage est un défaut, il se contente de saturer le résultat). Protège
les consommateurs aval — notamment `PRG_05_Translation` — même si `RawIn` sort de la plage nominale
avant que `FB_Joystick` n'ait qualifié la valeur.

**Exemple vérifié** (<nobr><code>TC-P08-010.1</code></nobr>) : `RawX=9000` avec neutre à 5000 →
demi-plage haute `(10000-5000)=5000` → `OutPct=(9000-5000)/5000*100=80%`. `RawY=300` avec neutre à
5000 → demi-plage basse `=5000` → `OutPct=(300-5000)/5000*100=-94%`.

## 5 · 📚 Documents liés

| Doc | Lien |
|---|---|
| AF08 (chapô) | Rôle machine, pipeline, intégration `FB_Joystick` |
| AF03 | Profils de composants (`Brique technique`), contrat `light`/`standard` |
| Code | `CODE/D_JOYSTICK/FB_AxisScale.st` |
