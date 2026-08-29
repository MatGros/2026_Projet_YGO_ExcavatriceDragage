# FB_CycleTime — Spec composant (v1.0)

> Rôle machine (contrat) : [`AF_Partie-03_Contrats_Composants_v2.3.md`](../AF_Partie-03_Contrats_Composants_v2.3.md)
> §3 — brique technique COMMUN du catalogue « Briques techniques COMMUN ».
> Rôle de **ce** document : le détail technique — interface, règle de bornage du `dt`, consommateurs,
> déclinaison du TC macro `TC-P03-014` — que le chapô ne porte pas.
> Source code : `CODE/A_COMMUN/FB_CycleTime.st` · 5 instances (`FB_Winch`, `FB_Winch_Symmetry`,
> `FB_Translation`, `FB_Translation_PositionEstimator`, `FB_Sim_Translation`).

## 🧭 Sommaire

1. [🎯 Rôle et profil](#1--rôle-et-profil)
2. [🧪 Points de validation (détail)](#2--points-de-validation-détail)
3. [🔌 Interface](#3--interface)
4. [⚙️ Comportement — mesure du dt et double bornage](#4--comportement--mesure-du-dt-et-double-bornage)
5. [📜 Suivi historique](#5--suivi-historique)
6. [📚 Documents liés](#6--documents-liés)

---

## 1 · 🎯 Rôle et profil

**Calcul du dt réel entre deux exécutions successives** de la tâche, publié en secondes
(`CycleTimeS : REAL`). Brique technique COMMUN, profil `light` : aucune machine d'état, aucun
défaut remonté. Utilisée par tout FB qui intègre une grandeur dans le temps (rampe, estimateur
de position, accumulateur).

Ce **n'est pas** un FB métier : pas de `Enable`/`Reset`, pas de `Ready`, pas de `Fault`. Une seule
entrée de configuration (`DefaultValueS`, valeur de secours) et une seule sortie (`CycleTimeS`).

## 2 · 🧪 Points de validation (détail)

> Décline le TC macro `TC-P03-014` du chapô (`AF_Partie-03_Contrats_Composants_v2.3.md` §1) en
> étapes numérotées — **jamais** un nouvel identifiant racine (`CODE_QUALITY_STANDARDS.md §0`).
> Source des tests : `TOOLS/TEST_AUTO_CI/RESULTS/A_COMMUN/tests/test_fb_cycletime.st`.

> **État** — `V` validé, implémentation non vérifiée · `V-I` validé et implémenté · `NV` non validé,
> non implémenté · `NV-I` code présent mais non validé · `R` refusé · `NA` non applicable.

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
      <th style="padding: 4px 1px; text-align: center;"><small>Etat</small></th>
    </tr>
  </thead>
  <tbody>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P03-014.1</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Plage nominale : au 1ᵉʳ appel <code>CycleTimeS = DefaultValueS</code> (aucun <code>dt</code> disponible) ; aux appels suivants, <code>0 &lt; dt ≤ CST_MaxCycleDeltaMs</code> ⟹ <code>CycleTimeS = dt</code> réel (ms→s), quelle que soit la valeur du <code>dt</code> d'un cycle à l'autre, <b>borne <code>dt = CST_MaxCycleDeltaMs</code> incluse</b> (⟹ <code>1.0 s</code>)</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>§4</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P03-014.2</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Borne basse : <code>dt = 0</code> (deux appels dans le même instant horloge) ⟹ <code>CycleTimeS = DefaultValueS</code></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>§4</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P03-014.3</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Borne haute, non latchée : <code>dt &gt; CST_MaxCycleDeltaMs</code> (<b>borne exclue</b> : <code>dt = 1001 ms</code> ⟹ secours ; rebouclage <code>TIME()</code> / reprise) ⟹ <code>CycleTimeS = DefaultValueS</code> ; dès le scan suivant à <code>dt</code> nominal, le <code>dt</code> réel est de nouveau publié</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>§4</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV-I</code></small></td>
    </tr>
  </tbody>
</table>

## 3 · 🔌 Interface

### Entrées (`VAR_INPUT`)

| Port | Type | Rôle |
|---|---|---|
| `DefaultValueS` | `REAL` | Valeur de secours (s), publiée hors plage nominale et au 1ᵉʳ cycle. Défaut `0.004`. |

### Sorties (`VAR_OUTPUT`)

| Port | Type | Rôle |
|---|---|---|
| `CycleTimeS` | `REAL` | `dt` réel du cycle en secondes, borné. Jamais nul, jamais aberrant. |

### Constante interne

| Nom | Type | Valeur | Rôle |
|---|---|---|---|
| `CST_MaxCycleDeltaMs` | `UDINT` | `1000` | Plafond physique du `dt` entre deux scans (ms). |

## 4 · ⚙️ Comportement — mesure du dt et double bornage

`TIME()` est un compteur système **32 bits en millisecondes** depuis le démarrage de l'automate.
Il **n'est pas absolu** : il reboucle à 0 tous les `2^32` ms (**≈ 49,7 jours**). La soustraction
`TimeCurrent - TimeLast` est modulo `2^32` — au passage d'un rebouclage simple, tant que l'écart
réel entre deux scans reste `< 49,7 j` (toujours vrai à 10 ms), `DeltaTimeMs` **reste correct**.
Le rebouclage seul n'est donc **pas** le risque principal.

Le risque est un `DeltaTimeMs` **réellement** `> CST_MaxCycleDeltaMs` : reprise après un
*online-change*, sortie d'un point d'arrêt / pas-à-pas debug, ou fenêtre du rebouclage. Le chien
de garde tâche (200 ms, sensibilité 1) borne déjà les gels **en fonctionnement** ; ce plafond
couvre les cas hors surveillance. Un `dt` aberrant publié tel quel donnerait un `CycleTimeS`
énorme, propagé en un seul scan dans les rampes de vitesse et les intégrateurs de position/frein
⟹ **saut physique**.

**Règle (fail-safe)** — région `§4` du code :

```
IF (DeltaTimeMs > 0) AND (DeltaTimeMs <= CST_MaxCycleDeltaMs) THEN
    CycleTimeS := UDINT_TO_REAL(DeltaTimeMs) / 1000.0;   // plage nominale
ELSE
    CycleTimeS := DefaultValueS;                          // borne basse (dt=0) OU borne haute
END_IF;
```

- Borne basse `dt = 0` (anti-zéro) et borne haute `dt > CST_MaxCycleDeltaMs` (anti-artefact)
  partagent la **même** branche de secours.
- Secours **non latché** : dès que le `dt` redevient nominal, la mesure réelle reprend.
- **Pas de redémarrage automatique**, pas de diagnostic remonté (brique `light`).

**Consommateurs** de `CycleTimeS` (impact d'un bug ici) : rampe de vitesse translation
(`FB_Ramp` via `FB_Translation`), estimateur de position M3 (`FB_Translation_PositionEstimator`),
intégrateurs de temps de frein treuil (`FB_Winch_Symmetry`).

## 5 · 📜 Suivi historique

| Date | Changement |
|---|---|
| 2026-08-29 | Création de la fiche (T088). Ajout du plafond haut `CST_MaxCycleDeltaMs := 1000` : le calcul ne bornait que par le bas (`DeltaTimeMs > 0`). <nobr><code>TC-P03-014</code></nobr> créé, décliné `.1` / `.2` / `.3`. Contrat : `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T088_CYCLETIME_WRAP_GUARD.yaml`. |

## 6 · 📚 Documents liés

| Document | Lien |
|---|---|
| Chapô contrats composants | [`AF_Partie-03_Contrats_Composants_v2.3.md`](../AF_Partie-03_Contrats_Composants_v2.3.md) |
| Étude de conception T088 | `DOC/WFLOW/AUDITS/DESIGN/DESIGN_FB_CYCLETIME_GARDE_FOU_WRAP_v0.1.md` |
| Contrat de tâche T088 | `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T088_CYCLETIME_WRAP_GUARD.yaml` |
| Tests CI | `TOOLS/TEST_AUTO_CI/RESULTS/A_COMMUN/tests/test_fb_cycletime.st` |
