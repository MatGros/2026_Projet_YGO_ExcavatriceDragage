# FB_XXX — Spec composant (vX.Y)

> 📌 **Squelette de fiche FB** (sous-fiche, famille Fonctions métier 08+). Règles complètes :
> `DOC/STDS/GUIDES/GUIDE_EDITION_AF_v1.0.md` §4 (« Répartition chapô / sous-fiches »). Supprimer ce
> bloc de note avant de committer la fiche réelle.
>
> ⛔ **Anti-duplication** : ne recopie **jamais** ici une interface, une formule ou un `TC-` déjà
> écrit dans le chapô (`AF_Partie-NN_*.md`). Le chapô porte le résumé machine et le catalogue TC
> macro ; cette fiche porte **le détail** que le chapô ne peut pas se permettre de garder lisible.

> Rôle machine : [`AF_Partie-NN_Fonction_XXX_vX.Y.md`](../AF_Partie-NN_Fonction_XXX_vX.Y.md)
> §N — couvre `FNN.0X`, `FNN.0Y` (codes du chapô).
> Rôle de **ce** document : le détail technique — interface complète, formules, séquence,
> réglages persistants — que le chapô ne porte pas.
> Source code : `CODE/.../FB_XXX.st` · instance `PRG_NN_XXX.instXXX`.

## 🧭 Sommaire

1. [🎯 Rôle et profil](#1--rôle-et-profil)
2. [🧪 Table des points de validation (détail)](#2--table-des-points-de-validation-détail)
3. [🔌 Interface](#3--interface)
4. [⚙️ Comportement / logique — un paragraphe par mécanisme notable](#4--comportement--logique)
5. [💾 Réglages RETAIN / persistants](#5--réglages-retain--persistants)
6. [⚠️ Alertes et écarts](#6--alertes-et-écarts)
7. [📚 Documents liés](#7--documents-liés)

## 1 · 🎯 Rôle et profil

[1-2 phrases — profil AF03 (`standard`/`light`), ce que ce FB fait dans la chaîne, ce qu'il ne
fait pas. Renvoi aux codes `FNN.0X` du chapô, pas de redite du rôle machine déjà écrit là-bas.]

## 2 · 🧪 Table des points de validation (détail)

> Décline le(s) TC macro du chapô en étapes numérotées `TC-PNN-0X0.1`, `.2`... — **jamais** un
> nouvel identifiant racine (immutabilité, `CODE_QUALITY_STANDARDS.md §0`). Si le chapô n'a pas
> encore de TC macro pour cette fonction, le signaler plutôt que d'en inventer un ici.

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
      <th style="padding: 4px 8px;">Séquence & Déroulé des étapes (Comportement attendu)</th>
      <th style="padding: 4px 1px; text-align: center;"><small>Type</small></th>
      <th style="padding: 4px 1px; text-align: center;"><small>Réf</small></th>
      <th style="padding: 4px 1px; text-align: center;"><small>État</small></th>
    </tr>
  </thead>
  <tbody>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold;">TC-PNN-0X0.1</span></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small>[Intention<br>courte]</small></td>
      <td style="padding: 6px 8px; line-height: 1.55;">
        ⚡ <b>Étape 1</b> : Stimulus d'entrée ou appel de méthode<br>
        🔍 <b>Étape 2</b> : Évaluation et calcul interne<br>
        🛑 <b>Étape 3</b> : Sanction / Résultat attendu sur les sorties
      </td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>💻 AUTO</code></small></td>
      <td style="padding: 4px 1px; text-align: center;"><small>§N</small></td>
      <td style="padding: 4px 1px; text-align: center;"><small><code>V-I</code></small></td>
    </tr>
  </tbody>
</table>

## 3 · 🔌 Interface

### Entrées (`VAR_INPUT`)

| Port | Type | Rôle |
|---|---|---|
| `XXX` | `BOOL` | [rôle] |

### Sorties (`VAR_OUTPUT`)

| Port | Type | Rôle |
|---|---|---|
| `XXX` | `BOOL` | [rôle] |

## 4 · ⚙️ [Comportement / logique — renommer par mécanisme, ex. "Séquence homing"]

[Formules exactes, machine d'état — le niveau de détail que le chapô n'a pas la place de porter.
Un paragraphe par mécanisme notable, pas un mur de texte unique. Si le FB a un bitfield `ErrorId`
non trivial, lui donner sa **propre sous-section** `📊 ErrorId` (table Bit/Cause/Catégorie) plutôt
que de le noyer dans un paragraphe de logique.

Si le mécanisme est une **séquence temporelle** (armement, palier, homing...), ajouter un
chronogramme texte (`GUIDE_EDITION_AF_v1.0.md §3ter`) : table Instant × Signal, fronts notés
`↑`/`↓` collés à la valeur (`TRUE ↑`), jamais de flèche textuelle ambiguë. Voir
`AF_Partie-08_Fonction_Joystick_v2.5.md §5` pour un exemple appliqué (homme-mort).]

## 5 · 💾 Réglages RETAIN / persistants

[Ce que le chapô résume dans son tableau Cfg, ici en détail complet. **Deux cas** :
- Scalaire nommé directement : `_XxxCfgPersist_YYY = valeur (source, réglable où)`.
- Struct RETAIN partagée reçue en `IN_OUT` (ex. `ST_Encoder_Calib`) : ne pas la re-décrire ici,
  un renvoi au champ + à sa définition (`ST_XXX_Calib.st`) suffit — la struct est déjà documentée
  une fois dans sa propre déclaration, ne pas dupliquer ses champs dans chaque fiche qui la reçoit.
Section facultative si le FB n'a aucun réglage persistant (ex. brique de calcul pur).]

```
_XxxCfgPersist_YYY = valeur   (source, réglable où)
```

## 6 · ⚠️ Alertes et écarts

| # | Gravité | Point | Action |
|---|---|---|---|
| 1 | info/P1/P2/✅ résolu | [constat court] | [action ou statut] |

## 7 · 📚 Documents liés

| Doc | Lien |
|---|---|
| AF_Partie-NN (chapô) | Rôle machine, intégration programme |
| AF03 | Contrat FB |
| Code | `CODE/.../FB_XXX.st` |
