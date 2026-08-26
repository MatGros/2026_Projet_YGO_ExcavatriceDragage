# FB_EncoderReliability — Spec composant (v1.0)

> Rôle machine : [`AF_Partie-09_Fonction_Encoder_v2.2.md`](../AF_Partie-09_Fonction_Encoder_v2.2.md)
> §6 — couvre `F09.06`.
> Rôle de **ce** document : les 2 gates de fiabilité de la chaîne codeur.
> Source code : `CODE/E_CODEURS/FB_EncoderReliability.st` · sous-instance `instRel` de `FB_Encoder`.

## 🧭 Sommaire

1. 🎯 Rôle et profil
2. 🧪 Points de validation (détail)
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

## 2 · 🧪 Points de validation (détail)

Décline `TC-P09-040` (chapô) :

| ID | Comportement attendu | Type | Réf |
|---|---|---|---|
| <nobr><code>TC-P09-040.1</code></nobr> | `EncoderAvailable=TRUE`, `Homed=FALSE`, `EncoderIncoherent=FALSE` → `EncoderFault=FALSE` (non-référencé ≠ incohérent) | <nobr><code>💻 AUTO</code></nobr> | §4 |
| <nobr><code>TC-P09-040.2</code></nobr> | Même cas → `HomedAndReliable=FALSE` (gate stricte exige `Homed`) | <nobr><code>💻 AUTO</code></nobr> | §4 |
| <nobr><code>TC-P09-040.3</code></nobr> | `EncoderAvailable=FALSE` → `EncoderFault=TRUE` quel que soit `Homed`/`EncoderIncoherent` | <nobr><code>💻 AUTO</code></nobr> | §4 |

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
