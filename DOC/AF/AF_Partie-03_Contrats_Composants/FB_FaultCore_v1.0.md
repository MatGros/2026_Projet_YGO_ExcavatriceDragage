# FB_FaultCore — Spec composant (v1.0)

> Rôle machine (contrat) : [`AF_Partie-03_Contrats_Composants_v2.3.md`](../AF_Partie-03_Contrats_Composants_v2.3.md)
> §4.1 — couvre le socle transverse du contrat `standard` (§3).
> Rôle de **ce** document : le détail technique — interface complète, types `ST_Fault` et
> `ST_FaultCause`, vue live vs vue latchée, câblage minimal, catalogue de tests — que le chapô ne
> porte plus depuis la v2.3.
> Source code : `CODE/A_COMMUN/FB_FaultCore.st`, `CODE/A_COMMUN/_TYPES/ST_Fault.st`,
> `CODE/A_COMMUN/_TYPES/ST_FaultCause.st`, `CODE/A_COMMUN/_TYPES/ST_Lifecycle.st` · consommateur confirmé :
> `CODE/D_JOYSTICK/FB_Joystick.st` (`instFault` + `instCauses`).

## 🧭 Sommaire

1. [🎯 Rôle et profil](#1--rôle-et-profil)
2. [🧪 Table des points de validation (détail)](#2--table-des-points-de-validation-détail)
3. [🔌 Interface](#3--interface)
4. [⚙️ Comportement — vue live, armement du latch, acquittement](#4--comportement--vue-live-armement-du-latch-acquittement)
5. [🚨 Changement de convention fail-safe (ex-`IsWarning` → `Latching`)](#5--changement-de-convention-fail-safe-ex-iswarning--latching)
6. [⚠️ Limites connues](#6--limites-connues)
7. [📜 Suivi historique](#7--suivi-historique)
8. [📚 Documents liés](#8--documents-liés)

---

## 1 · 🎯 Rôle et profil

Brique socle transverse qui **remplit `Fault : ST_Fault`** pour le compte des FB `standard`, à
partir d'une **liste de causes en clair** (`Causes : ARRAY[0..15] OF ST_FaultCause`), sans que
chaque FB métier ré-implémente sa propre logique de latch / acquittement.

Ce **n'est pas** un FB métier : pas de machine d'état, pas de brique warning séparée, pas de
texte IHM. Il porte `Enable` / `Reset` en entrée (il **relaie** ceux du FB porteur) et
`Ready` / `Fault` en sortie.

**Où il se place** : instancié **dans** le FB `standard` qui expose `Fault : ST_Fault` (jamais un
programme séparé). Le FB porteur remplit sa liste `instCauses[i]` (`Active` / `Latching` / `Texte`),
appelle l'instance, puis recopie `Fault := instFault.Fault` — le socle est **source de vérité** du
défaut. Forme cible du contrat `standard` (AF03 §3), destinée à se généraliser à tout FB `standard`
du projet.

**Composition** : `Fault : ST_Fault` en sortie de FB. Si le FB porteur a une **machine d'état à
cycle** (organe, séquenceur), il ajoute `Lifecycle : ST_Lifecycle` (`Busy` / `Done`) — struct
distincte, remplie par le FB porteur lui-même, **hors périmètre de FB_FaultCore**. Un FB synchrone
(conditionneur, filtre, joystick) ne porte pas `Lifecycle`.

## 2 · 🧪 Table des points de validation (détail)

> Catalogue `TC-P03-008` à `TC-P03-013` — **propriétaire unique de cette fiche**, pas dupliqué dans
> le chapô AF03 (`GUIDE_EDITION_AF_v1.0.md` §4, pattern déjà appliqué par `FB_Bucket` sur AF10).
> `TC-P03-001` à `007` restent au chapô (règles générales du socle Cause/Ack, §4 AF03, pas
> spécifiques à `FB_FaultCore`).

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
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P03-008</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Cumul de plusieurs causes latchées : 2 <code>Causes[i]</code> distincts (<code>Active AND Latching</code>) apparus à des instants différents s'accumulent dans <code>LatchedId</code> ; un seul front <code>Reset</code> les acquitte ensemble. Cas concret : 2 causes (<code>Causes[2]</code> puis <code>Causes[5]</code>, <code>Active AND Latching</code>) à scans différents → <code>LatchedId=0x0024</code> ; relâcher sans <code>Reset</code> → reste <code>0x0024</code> ; un front <code>Reset</code> → <code>LatchedId=0</code>, <code>Latched=FALSE</code>.</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>§4</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P03-009</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Cause live (<code>Latching=FALSE</code>) + cause latchée (<code>Latching=TRUE</code>) simultanées : la live alimente <code>ErrorId</code> et retombe seule quand <code>Active</code> repasse <code>FALSE</code> ; la latchée arme <code>LatchedId</code> et reste jusqu'au front <code>Reset</code>. Cas concret : cause live (<code>Causes[1]</code>, <code>Latching=FALSE</code>) → <code>ErrorId</code> bit1, retombe seule ; cause latchée (<code>Causes[3]</code>) → <code>LatchedId</code> bit3, reste ; front <code>Reset</code> → <code>LatchedId=0</code>. Indépendance des vues live/latchée.</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>§4</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P03-010</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Bornes de la liste <code>Causes[0..15]</code> : <code>Causes[0]</code> et <code>Causes[15]</code> correctement mappés sur le bit 0 et le bit 15 (<code>SHL(WORD#1, i)</code>), pas d'off-by-one</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>§3</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P03-011</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;"><code>Reset</code> sans historique de défaut : aucun effet parasite, <code>LatchedId</code> reste <code>0</code>, <code>Latched</code> reste <code>FALSE</code></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>§4</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P03-012</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;"><code>Reset</code> maintenu (niveau haut) sans nouveau front pendant qu'une cause latchée disparaît puis réapparaît : pas d'acquittement silencieux (le clear n'agit que sur le front <code>R_TRIG</code>) ; la cause réapparue <code>Active AND Latching</code> <b>ré-arme</b> son bit (ré-alarme) — faille T148 <b>non applicable</b> à cette brique</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>§6</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV-I</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P03-013</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;"><code>Enable=FALSE</code> : la vue LIVE n'est pas évaluée (<code>ErrorId=0</code>, <code>Error=FALSE</code>) mais la vue LATCHÉE <b>reste publiée</b> — un défaut laté non acquitté ne disparaît pas sur bascule <code>Enable</code> OFF→ON sans <code>Reset</code></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>§4</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV-I</code></small></td>
    </tr>
  </tbody>
</table>

Exécution : 🆕 `TOOLS/TEST_AUTO_CI/RESULTS/A_COMMUN/tests/test_fb_faultcore.st` (créé 2026-08-29, T174 — l'ancien
`test_fb_fbstatus.st` visait `FB_FBSTATUS`/`ST_FBCAUSE` supprimés au commit `51fccce6` et ne compilait plus).
**Preuve : 6/6 TC PASS** (harnais STruCpp, rapport daté `RESULTS/A_COMMUN/reports/FB_FaultCore.json|html` du
2026-08-29) — scénarios multi-scans, causes injectées via `Causes[i].Active` / `Causes[i].Latching` (aucune source
bitfield `WORD`, aucun tableau de textes indexé par bit).

## 3 · 🔌 Interface

### Entrées (`VAR_INPUT`)

| Port | Type | Rôle |
|---|---|---|
| `Enable` | `BOOL` | Autorisation générale du FB porteur — `FALSE` → `Ready=FALSE`, vue LIVE non évaluée ; le latch des défauts est **conservé** (§4) |
| `Reset` | `BOOL` | Front d'acquittement (`R_TRIG` interne), **jamais conditionné** par un état externe (AF03 §4, std §9) — agit même `Enable=FALSE` |
| `Causes` | `ARRAY[0..15] OF ST_FaultCause` | Liste des causes en **clair**, fournies par le FB porteur — remplace tout bitfield `WORD` + tableaux de textes |

### Sorties (`VAR_OUTPUT`)

| Port | Type | Rôle |
|---|---|---|
| `Ready` | `BOOL` | Recopie de `Enable` |
| `Fault` | `ST_Fault` | Brique défaut complète (vue live + vue latchée) — mappée 1:1 sur la sortie `Fault` du FB porteur |

### Type `ST_Fault` (brique défaut — 2 vues, sans brique warning séparée)

| Champ | Type | Rôle |
|---|---|---|
| `Error` | `BOOL` | Vue **LIVE** : au moins une cause `Active` maintenant. Retombe seule à `FALSE`. `Error := (ErrorId <> 0)` |
| `ErrorId` | `WORD` | Bitfield des causes `Active` maintenant (0 si aucune) — non évalué si `Enable=FALSE` |
| `Latched` | `BOOL` | Vue **LATCHÉE** : défaut non acquitté, reste jusqu'au front `Reset`. `Latched := (LatchedId <> 0)` |
| `LatchedId` | `WORD` | Bitfield figé à l'apparition de chaque cause `Active AND Latching`, effacé au front `Reset` |

> Texte IHM **non stocké** dans `ST_Fault` : dérivé côté IHM depuis `LatchedId` / `ErrorId` (le
> champ `Texte` de chaque `ST_FaultCause` sert de libellé source côté mapping IHM).

### Type `ST_FaultCause` (cause élémentaire en clair, sans bitfield ni masque)

| Champ | Type | Rôle |
|---|---|---|
| `Active` | `BOOL` | Cause brute — `TRUE` = cause présente. **Interlock toujours sur `Active`** (cause brute), jamais sur l'acquittement |
| `Latching` | `BOOL` | `TRUE` = la cause **arme la vue latchée** (défaut à acquitter, reste jusqu'au `Reset`, re-arme si la cause revient) ; `FALSE` = la cause **n'alimente que la vue live** (retombe seule, aucun acquittement) |
| `Texte` | `STRING` | Libellé prêt IHM de la cause (non stocké dans `ST_Fault`, consommé côté IHM) |

### Type `ST_Lifecycle` (optionnel — FB porteur à machine d'état seulement)

| Champ | Type | Rôle |
|---|---|---|
| `Busy` | `BOOL` | `1` = action à cycle en cours — **rempli par le FB porteur**, pas par `FB_FaultCore` |
| `Done` | `BOOL` | `1` = action à cycle terminée avec succès — idem `Busy` |

## 4 · ⚙️ Comportement — vue live, armement du latch, acquittement

- **§1 Reset (front, toujours effectif)** : `ResetEdge(CLK := Reset)` ; sur `ResetEdge.Q`, tous les
  bits de latch sont remis à `FALSE`. Jamais conditionné par un état externe, agit **même
  `Enable=FALSE`** (std §9). `Ready := Enable`.
- **§2 Vue LIVE (`Error` / `ErrorId`)** : bitfield des `Causes[i].Active` **maintenant**. Retombe
  seule à `0` quand les causes disparaissent. **Non évaluée si `Enable=FALSE`** (pas de lecture de
  cause hors autorisation) → `ErrorId=0`, `Error=FALSE`. `Error := (ErrorId <> 0)`.
- **§3 Armement des latches** : une cause **`Active AND Latching`** arme son bit ; le bit reste
  jusqu'au front `Reset` (§1), **même si la cause disparaît**. Réapparition de la cause ⇒
  ré-armement du bit (**ré-alarme**). Armement **non évalué si `Enable=FALSE`**.
- **§4 Vue LATCHÉE (`Latched` / `LatchedId`)** : **toujours publiée**, y compris `Enable=FALSE` —
  un défaut non acquitté reste visible (pas d'effacement silencieux sur bascule `Enable` OFF→ON
  sans `Reset`). `Latched := (LatchedId <> 0)`.
- **Interlock** : tout interlock de sécurité se base **toujours** sur la cause brute
  (`Causes[i].Active`, ou `Fault.Error` / `Fault.ErrorId`), **jamais** sur l'acquittement
  (`Latched`) — l'acquittement n'ouvre jamais un interlock par lui-même (std §9).
- **Pas de redémarrage auto** : l'acquittement ne relance jamais une action. Une nouvelle demande
  explicite est requise (AF03 §4).
- **Hors périmètre** : pas de `State` / `StateAtError`, pas de `Warning` / `WarningId`, pas de
  génération de texte. Un FB porteur avec sa **propre** machine d'état capture son état au défaut
  lui-même (comme `FB_Modes.st`), il ne passe pas par ce socle pour ça.

### Câblage minimal (à copier tel quel dans un nouveau FB `standard`)

```st
VAR
    instFault  : FB_FaultCore;
    instCauses : ARRAY[0..15] OF ST_FaultCause;
END_VAR

// Remplir instCauses[i] selon la logique metier du FB (exemple : 1 cause capteur hors plage)
instCauses[0].Active   := (RawValue < MinValue) OR (RawValue > MaxValue);
instCauses[0].Latching := FALSE;  // cause LIVE seulement : retombe seule, aucun acquittement
instCauses[0].Texte    := 'Capteur hors plage';

instCauses[1].Active   := CalibFail;
instCauses[1].Latching := TRUE;   // cause A ACQUITTER : arme Fault.Latched jusqu'au front Reset
instCauses[1].Texte    := 'Echec calibration';

instFault(Enable := Enable, Reset := Reset, Causes := instCauses);
Ready := instFault.Ready;
Fault := instFault.Fault;          // source de verite = socle
```

Exemple réel équivalent : `CODE/D_JOYSTICK/FB_Joystick.st` (`instFault` + `instCauses`, §1
« CAUSES + SOCLE »).

## 5 · 🚨 Changement de convention fail-safe (ex-`IsWarning` → `Latching`)

> ⚠️ **Changement de convention assumé, à ne pas glisser en douce.** L'ancien socle
> (`FB_FbStatus` / `ST_FbCause`, supprimé du code au commit `51fccce6`) et le nouveau
> (`FB_FaultCore` / `ST_FaultCause`) n'ont **pas la même polarité par défaut** quand une cause
> n'est pas classifiée :

| Socle | Champ de classement | Cause laissée à `FALSE` / non renseignée | Conséquence |
|---|---|---|---|
| **Ancien** (`ST_FbCause`) | `IsWarning` | classée **Fault** (latchée, à acquitter) | sécurité maximale : tout défaut non classé exige un acquittement |
| **Nouveau** (`ST_FaultCause`) | `Latching` | **live seulement** (vue `Error`/`ErrorId`, retombe seule) | la cause reste **visible** mais **n'est pas latchée** : pas d'acquittement tant que `Latching=TRUE` n'est pas déclaré explicitement |

- Le sens de sécurité est **préservé au niveau de la visibilité** : une cause `Active` non classée
  reste toujours vue (`Fault.Error`), et **tout interlock se base sur cette cause brute**, pas sur
  le latch — le fail-safe d'interdiction de mouvement n'est donc pas affaibli.
- Ce qui **change** : le caractère **acquittable** d'une cause est désormais un **choix explicite
  par cause** (`Latching := TRUE`), il n'est plus la valeur par défaut. Toute cause qui doit
  survivre à sa propre disparition et exiger un geste opérateur **doit** porter `Latching := TRUE`
  à la conception du FB porteur — c'est un point de revue obligatoire à la création d'un FB
  `standard`.

## 6 · ⚠️ Limites connues

| # | Gravité | Point | Action |
|---|---|---|---|
| 1 | ✅ résolu (T147) | Le latch d'un défaut ne survivait pas à un cycle `Enable=FALSE` | Résolu : §4 — la vue LATCHÉE est publiée même `Enable=FALSE`, seul un front `Reset` l'efface |
| 2 | ✅ non applicable (T148) | `Reset` **maintenu** (niveau haut, pas de nouveau front) pendant que la cause disparaît : acquittement silencieux | Non applicable à `FB_FaultCore` : le clear n'agit que sur le front `R_TRIG` (`ResetEdge.Q`). Un `Reset` maintenu sans nouveau front n'efface rien de plus ; une cause réapparue `Active AND Latching` ré-arme son bit |

## 7 · 📜 Suivi historique

| Version | Date | Changement |
|---|---|---|
| v1.0 | 2026-08-27 | Réécriture complète sur le socle `FB_FaultCore` / `ST_Fault` / `ST_FaultCause` (T164-3). Remplace l'ancienne fiche du socle `FB_FbStatus` / `ST_FbStatus` / `ST_FbCause` (supprimés du code au commit `51fccce6` ; décisions (a)/(b)/(c), champs `Warning*` et textes agrégés — abandonnés). Changement de convention fail-safe documenté en §5 (`IsWarning` absent ⇒ Fault → `Latching` absent ⇒ live seulement). Catalogue de tests §2 réécrit sur les 2 vues (live / latchée). Fichier renommé (ancien nom : `FB_FbStatus` + suffixe `_v1.0.md`) → `FB_FaultCore_v1.0.md`. |

## 8 · 📚 Documents liés

| Doc | Lien |
|---|---|
| AF03 (chapô) | [`AF_Partie-03_Contrats_Composants_v2.3.md`](../AF_Partie-03_Contrats_Composants_v2.3.md) — contrats socle `light` / `standard`, périmètre du socle (§3, §4.1) |
| `DOC/STDS/CODE_QUALITY_STANDARDS.md` | §2quinquies (interfaces socle), §3 / §3bis (types `ST_Fault` / `ST_FaultCause`, socle `FB_FaultCore`), §9 (pattern Cause/Ack, `Reset` jamais conditionné) |
| AF08 (Joystick) | Consommateur confirmé (`instFault` + `instCauses`) |
| Code | `CODE/A_COMMUN/FB_FaultCore.st`, `CODE/A_COMMUN/_TYPES/ST_Fault.st`, `CODE/A_COMMUN/_TYPES/ST_FaultCause.st`, `CODE/A_COMMUN/_TYPES/ST_Lifecycle.st` |
| Tests | 🆕 `TOOLS/TEST_AUTO_CI/RESULTS/A_COMMUN/tests/test_fb_faultcore.st` (TC-P03-008..013 — 6/6 PASS, rapport 2026-08-29) ; ⚠️ l'ancien `test_fb_fbstatus.st` visait un FB supprimé (remplacé) |
</content>
</invoke>
