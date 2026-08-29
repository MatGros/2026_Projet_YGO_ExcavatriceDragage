# FB_Sim_Translation — Spec composant (v1.0)

> Rôle machine (vague) : [`AF_Partie-13_Fonction_Simulation_v2.4.md`](../AF_Partie-13_Fonction_Simulation_v2.4.md) §4.
> Rôle de **ce** document : modèle simulé des 5 capteurs de position M3 par progression continue —
> et **catalogue unique** des `TC-P13-040...`.
> Source code : `CODE/L_SIMULATION/FB_Sim_Translation.st` · instance `FB_SimBench.instSimTranslation`.

## 🧭 Sommaire

1. Rôle et profil
2. Interface
3. Modèle de progression
4. Documents liés

## 🧪 Table des points de validation (détail)

> Propriétaire unique du catalogue détaillé de la plage indiquée (`TC-P13-040...`) — ce catalogue fait foi ; le chapô AF ne le recopie pas.

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
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P13-040</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Progression Trémie→Maintenance : chaque intervalle <code>[0;5[</code>, <code>[5;15[</code>, <code>[15;20[</code>, <code>[20;30[</code> publie un seul mot thermomètre valide (<code>11111→00000</code>), aucune zone transitoire à cheval sur deux mots (FB_Sim_Translation.st:104-124)</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P13-041</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;"><code>Direction=+1</code> progresse vers Trémie, <code>-1</code> vers Maintenance, <code>0</code> maintient la position</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P13-042</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Position bornée <code>[Trémie, Maintenance]</code> — jamais de dépassement</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P13-043</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;"><code>Enable=FALSE</code> réinitialise sur la Trémie (0 m) — état de départ propre (REX 2026-08-21, était P2)</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
  </tbody>
</table>

---

## 1. Rôle et profil

🎯 Produit les cinq capteurs de position M3 par progression continue de Trémie vers Maintenance,
à une vitesse dérivée de `SpeedTgt_Pct`/`FullTravelTimeS`. Le modèle ne publie que les six mots
valides attendus par `FB_Translation_PositionDecoder` (Partie 11) — jamais un mot incohérent, ce
FB simule un capteur sain, pas un défaut câblage.

📏 **Convention position (REX 2026-08-21)** : `PositionProgress` interne en **mètres**,
`0 m = Trémie` … `30 m = Maintenance`. Seuils capteurs aux positions réelles, **distances
non-linéaires** : Trémie(0)→PV(5)=5 m, PV(5)→P2(15)=10 m, P2(15)→P1(20)=5 m, P1(20)→Maintenance(30)=10 m.

🔒 Source d'entrée confinée derrière `HwIn` : ne pilote aucune sortie réelle. Un éventuel override
manuel (`SimM3SensorsWordOverrideActive`) est appliqué par `FB_SimBench`, pas par ce FB — séparation
stricte entre le modèle dynamique et l'injection ponctuelle opérateur.

---

## 2. Interface

| Entrée | Type | Sens |
|---|---|---|
| `Enable` | BOOL | Modèle actif |
| `Direction` | INT | `+1` = vers Trémie, `-1` = vers Maintenance, `0` = maintien |
| `SpeedTgt_Pct` | REAL | Magnitude commande 0..100 %, bornée avant calcul |
| `FullTravelTimeS` | REAL | Temps complet Trémie→Maintenance à 100 % (simulation seulement, défaut 8.0s) |

| Sortie | Type | Sens |
|---|---|---|
| `PosTremie`/`PosPV`/`PosP2`/`PosP1`/`PosMaintenance` | BOOL | Bits 4→0 du mot capteurs (cumulatif thermomètre) |

---

## 3. Modèle de progression

Position interne `PositionProgress` (REAL, **mètres**, 0=Trémie … 30=Maintenance), incrémentée/
décrémentée chaque scan selon `SpeedPctBounded` et `FullTravelTimeS` (`FB_CycleTime` pour le pas
réel). À 100 %, le modèle parcourt les **30 m** de distance totale en `FullTravelTimeS`. Chaque
intervalle délimité par les positions réelles `[0;5[`, `[5;15[`… correspond à un seul mot
thermomètre valide — aucune zone transitoire à cheval sur deux mots. **Init déterministe sur la
Trémie (0 m)** au démarrage et sur `Enable=FALSE`.

Protection division : sous `CST_MinFullTravelTimeS` (0.1s), le modèle n'a plus de dynamique
(`PositionIncrement := 0.0`) plutôt qu'une division qui exploserait.

---

## 4. Documents liés

| Doc | Lien |
|---|---|
| AF13 (chapô) | Frontière simulation, stimuli `SimM3SensorsWordOverrideActive` |
| AF11 / FB_Translation_PositionDecoder | Consommateur réel des 5 capteurs, table des 6 mots valides |
| Code | `CODE/L_SIMULATION/FB_Sim_Translation.st` |
