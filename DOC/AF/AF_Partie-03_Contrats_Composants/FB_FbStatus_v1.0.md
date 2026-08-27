# FB_FbStatus — Spec composant (v1.0)

> Rôle machine (contrat) : [`AF_Partie-03_Contrats_Composants_v2.3.md`](../AF_Partie-03_Contrats_Composants_v2.3.md)
> §4.1 — couvre le socle transverse du contrat `standard` (§3).
> Rôle de **ce** document : le détail technique — interface complète, type `ST_FbCause`, décisions
> (a)/(b)/(c), câblage minimal, catalogue de tests — que le chapô ne porte plus depuis la v2.3.
> Source code : `CODE/A_COMMUN/FB_FaultCore.st`, `CODE/A_COMMUN/ST_Status.st`,
> `CODE/A_COMMUN/ST_FaultCause.st` · consommateur confirmé : `CODE/D_JOYSTICK/FB_Joystick.st`
> (`instFault`).

## 🧭 Sommaire

1. [🎯 Rôle et profil](#1--rôle-et-profil)
2. [🧪 Points de validation (détail)](#2--points-de-validation-détail)
3. [🔌 Interface](#3--interface)
4. [⚙️ Comportement — classification et acquittement](#4--comportement--classification-et-acquittement)
5. [⚠️ Limites connues](#5--limites-connues)
6. [📚 Documents liés](#6--documents-liés)

---

## 1 · 🎯 Rôle et profil

Socle transverse **contrat `light`** (`Enable` en entrée, `Ready` en sortie — pas de `Reset`
propre au socle lui-même, il relaie celui du FB appelant) qui **implémente** le contrat `standard`
pour le compte des FB métier : il remplit `Status : ST_FbStatus` à partir d'une liste de causes en
clair, sans que chaque FB métier ré-implémente sa propre logique d'acquittement/latch.

**Où il se place** : instancié **dans** le FB métier qui expose `Status : ST_FbStatus` (jamais un
programme séparé). Le FB métier fournit sa liste de causes (`Causes : ARRAY[0..15] OF ST_FbCause`)
et recopie `Status := instFbStatus.Status`. Forme cible du contrat `standard` (AF03 §3), destinée à
se généraliser aux autres FB `standard` du projet.

## 2 · 🧪 Points de validation (détail)

> Catalogue `TC-P03-008` à `TC-P03-013` — **propriétaire unique de cette fiche**, pas dupliqué dans
> le chapô AF03 (`GUIDE_EDITION_AF_v1.0.md` §4, pattern déjà appliqué par `FB_Bucket` sur AF10).
> `TC-P03-001` à `007` restent au chapô (règles générales du socle Cause/Ack, §4 AF03, pas
> spécifiques à `FB_FbStatus`).

> **Etat** ? `V` valid?, impl?mentation non v?rifi?e ? `V-I` valid? et impl?ment? ? `NV` non valid?, non impl?ment? ? `NV-I` code pr?sent mais non valid? ? `R` refus? ? `NA` non applicable.

| ID | Comportement attendu | Type | Réf | Etat |
|---|---|---|---|---|
| <nobr><code>TC-P03-008</code></nobr> | Cumul de plusieurs Fault latchés : 2 `Causes[i]` distincts apparus à des instants différents s'accumulent dans `ErrorId`, `Reset` les acquitte ensemble | <nobr><code>💻 AUTO</code></nobr> | §4 | `NV-I` |
| <nobr><code>TC-P03-009</code></nobr> | Fault + Warning simultanés : texte IHM = première cause active (index le plus bas) ; le warning reste dans `WarningIdTxt`, jamais dans `ErrorId` | <nobr><code>💻 AUTO</code></nobr> | §4 | `NV-I` |
| <nobr><code>TC-P03-010</code></nobr> | Bornes de la liste `Causes[0..15]` : `Causes[0]` et `Causes[15]` correctement gérés, pas d'off-by-one | <nobr><code>💻 AUTO</code></nobr> | §3 | `NV-I` |
| <nobr><code>TC-P03-011</code></nobr> | `Reset` sans historique de défaut : aucun effet parasite, `ResetRequested` reste `FALSE` | <nobr><code>💻 AUTO</code></nobr> | §4 | `NV-I` |
| <nobr><code>TC-P03-012</code></nobr> | `Reset` maintenu (niveau haut) pendant que la cause disparaît : acquittement silencieux, sans confirmation au moment réel — ⚠️ faille T148 prouvée, pas validée comme cible | <nobr><code>💻 AUTO</code></nobr> | §5 | `NV-I` |
| <nobr><code>TC-P03-013</code></nobr> | Texte IHM pour un bit actif sans texte configuré (`Texte=''`) : chaîne vide, pas de plantage ni de texte résiduel d'un autre bit | <nobr><code>💻 AUTO</code></nobr> | §4 | `NV-I` |

Exécution : `TOOLS/TEST_AUTO_CI/RESULTS/A_COMMUN/tests/test_fb_fbstatus.st` — 11 scénarios
multi-scans, causes injectées via `Causes[i].Active`/`IsWarning`/`Texte` (plus de source bitfield
`WORD` ni tableau de textes indexé par bit).

## 3 · 🔌 Interface

### Entrées (`VAR_INPUT`)

| Port | Type | Rôle |
|---|---|---|
| `Enable` | `BOOL` | Autorisation générale — `FALSE` neutralise les sorties (`Ready=FALSE`) ; le latch des défauts est **conservé** (décision (b), §4) |
| `Reset` | `BOOL` | Front d'acquittement, jamais conditionné par un état externe (AF03 §4) |
| `Causes` | `ARRAY[0..15] OF ST_FbCause` | Liste des causes en **clair**, fournies par le FB métier — remplace l'ancien couple bitfield `WORD` + tableaux de textes |

### Sorties (`VAR_OUTPUT`)

| Port | Type | Rôle |
|---|---|---|
| `Ready` | `BOOL` | Recopie de `Enable` |
| `Status` | `ST_FbStatus` | Statut complet — mappé 1:1 sur la sortie `Status` du FB métier appelant |

### Type `ST_FbCause` (cause élémentaire en clair, sans bitfield ni masque)

| Champ | Type | Rôle |
|---|---|---|
| `Active` | `BOOL` | Cause brute — `TRUE` = cause présente. **Interlock toujours sur `Active`** (cause brute), jamais sur l'acquittement |
| `IsWarning` | `BOOL` | `TRUE` = warning **auto-effacé** (ne lève jamais `Error`) ; `FALSE` = fault à acquitter (laté). Fail-safe : toute cause sans `IsWarning=TRUE` est classée Fault |
| `Texte` | `STRING` | Libellé IHM de la cause |

### Type `ST_FbStatus` (sortie agrégée — 11 membres, forme cible du contrat `standard`)

| Champ | Type | Rôle |
|---|---|---|
| `Busy` | `BOOL` | *(historique, non géré par le socle — à la charge du FB métier appelant selon son cycle)* |
| `Done` | `BOOL` | *(historique, non géré par le socle — idem `Busy`)* |
| `Error` | `BOOL` | `TRUE` = défaut à acquitter (laté jusqu'au `Reset`) — `Error := (ErrorId <> 0)` |
| `ErrorId` | `WORD` | Code défaut bitfield cumulatif — réservé aux vrais défauts (décision (a)) |
| `State` / `StateAtError` | `E_State` | Remplis par le socle à `READY` par défaut (décision (c) pour `StateAtError`) — un FB avec sa **propre** machine d'état (ex. `FB_Modes`) gère sa capture lui-même, sans passer par ce socle |
| `Warning` | `BOOL` | `TRUE` = warning actif (auto-effacé, aucun acquittement) |
| `WarningId` | `WORD` | Code warning courant (bitfield) |
| `WarningIdTxt` | `STRING` | Texte généré depuis `WarningId` (prêt IHM) |
| `ErrorIdTxt` | `STRING` | Texte généré depuis `ErrorId` |
| `ResetRequested` | `BOOL` | `TRUE` = un `Reset` est nécessaire / en cours |

## 4 · ⚙️ Comportement — classification et acquittement

- Une cause est classée Fault ou Warning par **`IsWarning`** (jamais les deux). `IsWarning=TRUE` →
  warning **auto-effacé** avec la cause (ne lève jamais `Error`) ; `IsWarning=FALSE` → défaut
  **laté** à acquitter, qui se re-latche si la cause revient. Fail-safe : toute cause sans
  `IsWarning=TRUE` est classée Fault.
- **Décision (a)** : un warning n'est **jamais** écrit dans `ErrorId` — `ErrorId` est réservé aux
  **vrais défauts** (à acquitter). Un warning va dans `WarningId`/`WarningIdTxt`. `Error :=
  (ErrorId <> 0)` ne voit donc jamais de faux défaut.
- **Décision (b)** : le latch d'un défaut est **conservé** quand `Enable=FALSE` — un défaut non
  acquitté ne disparaît pas silencieusement ; seul un `Reset` l'efface. Résout l'ancienne limite
  T147 (avant : le latch était remis à zéro au cycle `Enable=FALSE`).
- **Décision (c)** : `StateAtError` est capturé **au premier défaut** puis **gelé** jusqu'au
  `Reset` (`StateAtErrorArmed`) — jamais réécrit par une cause ultérieure.
- Sélection du texte IHM : **parcours de liste** (`FOR` sur `Causes[i].Active` → `Causes[i].Texte`),
  première cause active d'index le plus bas — plus aucun `WHILE`, ni masque, ni `SHR` pour la
  sélection. Un warning actif s'affiche via un second parcours (`WarningIdTxt`), séparé des défauts.

### Câblage minimal (à copier tel quel dans un nouveau FB `standard`)

```st
VAR
    instFbStatus : FB_FbStatus;
    Causes       : ARRAY[0..15] OF ST_FbCause;
END_VAR

// Remplir Causes[i] selon la logique metier du FB (exemple : 1 cause capteur hors plage)
Causes[0].Active    := (RawValue < MinValue) OR (RawValue > MaxValue);
Causes[0].IsWarning := FALSE; // Fault : necessite Reset
Causes[0].Texte     := 'Capteur hors plage';

instFbStatus(Enable := Enable, Reset := Reset, Causes := Causes);
Ready  := instFbStatus.Ready;
Status := instFbStatus.Status;
```

Exemple réel équivalent : `CODE/D_JOYSTICK/FB_Joystick.st` (`instFbStatus`).

## 5 · ⚠️ Limites connues

| # | Gravité | Point | Action |
|---|---|---|---|
| 1 | ✅ résolu (T147) | Le latch d'un défaut ne survivait pas à un cycle `Enable=FALSE` | Résolu par décision (b), §4 |
| 2 | P2 (T148) | `Reset` simplement **maintenu** (niveau haut, pas de nouveau front) pendant que la cause disparaît acquitte silencieusement le défaut, sans confirmation au moment réel de la disparition — prouvé par <nobr><code>TC-P03-012</code></nobr> | Comportement actuel prouvé, pas validé comme cible — décision à trancher (exiger un nouveau front strict ?), voir TBD chapô AF03 §9 |

## 6 · 📚 Documents liés

| Doc | Lien |
|---|---|
| AF03 (chapô) | Contrat `light`/`standard`, périmètre du socle |
| `DOC/STDS/CODE_QUALITY_STANDARDS.md §2quinquies/§9` | Pattern Cause/Ack générique, interfaces socle |
| AF08 (Joystick) | Consommateur confirmé (`instFbStatus`) |
| Code | `CODE/A_COMMUN/FB_FaultCore.st`, `ST_Status.st`, `ST_FaultCause.st` |
| Tests | `TOOLS/TEST_AUTO_CI/RESULTS/A_COMMUN/tests/test_fb_fbstatus.st` |
