# 🎮 Architecture d'Intention — Geste Joystick → Action (v0.2)

> 🎯 **Objet** : architecture en **2 blocs** — le **geste joystick** (physique) puis l'**action** (fonctionnelle).
> 📅 Session 2026-08-19 · 🔍 Phase conception — **zéro code**.
> 📄 Références : `AF_Partie-08` (joystick), `AF_Partie-10` (winch/paliers), `AF_Partie-11` (translation),
> `AF_Partie-04` (cycle), `PLAN_TASK.md` T130/T131/T135.

---

## 🏗️ 1. L'architecture — 2 blocs bien séparés

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  🕹️ JOYSTICK (X/Y) + homme-mort                                              │
└──────────────────────────┬──────────────────────────────────────────────────┘
                           │
                           ▼
        ┌──────────────────────────────────────────────┐
        │  BLOG 1 — FB_GestureIntention (GESTE)          │
        │  « Que fait l'opérateur avec le joystick ? »   │
        │  • PUR joystick : AUCUN bouton, AUCUN état     │
        │  • sort : geste physique + %                   │
        └──────────────────┬───────────────────────────┘
                           │  GstPull / GstPush / GstLeft / GstRight + Pct
                           ▼
        ┌──────────────────────────────────────────────┐
        │  BLOG 2 — FB_ActionIntention (ACTION)         │
        │  « Que doit faire la machine ? »              │
        │  • geste + boutons IHM + état programme       │
        │  • sort : action concrète                     │
        └──────────────────┬───────────────────────────┘
                           │  ActDescentOpen / ActAscentClose / ActBucketOpen / ...
                           ▼
        ┌──────────────────────────────────────────────┐
        │  CONSOMMATEURS (PRG_04 / PRG_05 / FB_Cycle)   │
        │  • appliquent permis/interlocks               │
        │  • pilotent les actionneurs                  │
        └──────────────────────────────────────────────┘
```

---

## 🧩 2. Bloc 1 — `FB_GestureIntention` (GESTE)

> **Responsabilité** : traduire le **geste joystick** en **direction physique + %**.
> **PUR** : ne connaît **ni boutons IHM, ni état programme** (mode, sélection, benne).

### Entrées
```pascal
VAR_INPUT
    Enable                  : BOOL;            // --> [CMD] Activation pipeline
    DeadmanArmed            : BOOL;           // --> [CMD] Homme-mort arme
    CfgDualAxis           : BOOL;           // --> [CFG] 0=Mono (defaut), 1=Bi-axe
    AxisCmdX                : ST_Joystick_AxisCmd;  // --> [CMD] Axe X (translation)
    AxisCmdY                : ST_Joystick_AxisCmd;  // --> [CMD] Axe Y (treuils)
END_VAR
```

> ℹ️ **Pas de `PowerContactorEngaged` ni `Mode`** : ce sont des gates aval (PRG_04/05 les
> vérifient déjà). Bloc 1 = décodeur pur, ne multiplie pas les causes de blocage.

### Sorties (geste physique)
```pascal
VAR_OUTPUT
    GstPull     : BOOL;  GstPullPct    : REAL;  // tirer le joystick = treuil montee
    GstPush     : BOOL;  GstPushPct    : REAL;  // pousser le joystick = treuil descente
    GstLeft     : BOOL;  GstLeftPct    : REAL;  // joystick gauche = translation -> tremie
    GstRight    : BOOL;  GstRightPct   : REAL;  // joystick droite = translation -> maintenance
END_VAR
```

### Règles
- **Mono-axe** : premier axe enclenché prioritaire. `CfgDualAxis=1` → bi-axe futur.
- **Neutre** : bit + % à 0 instantanément (coupure structurelle).
- **% = intention** (déviation joystick), **pas** vitesse finale.
- **Mapping Fwd/Rev ↔ Left/Right** interne : `Fwd`=+1=trémie=`Left` · `Rev`=-1=maintenance=`Right`.
- **Simulation** : en amont (produit un `AxisCmdX/Y` simulé), jamais dans le bloc.

---

## 🎯 3. Bloc 2 — `FB_ActionIntention` (ACTION)

> **Responsabilité** : combiner le **geste** + les **boutons IHM** + l'**état programme** pour
> produire l'**action concrète**.
> **Mapping pur** : ne fait **aucune** sécurité (permis/interlocks restent en aval).

### Entrées
```pascal
VAR_INPUT
    // Geste (sortie Bloc 1)
    GstPull / GstPush / GstLeft / GstRight : BOOL
    GstPullPct / GstPushPct / GstLeftPct / GstRightPct : REAL

    // Contexte d'action (produit en amont, deja traite)
    Ctx : ST_ActionContext
END_VAR
```

### Sorties (action concrète)
```pascal
VAR_OUTPUT
    ActDescentOpen   : BOOL;  // descendre les treuils + ouvrir la benne
    ActAscentClose   : BOOL;  // monter les treuils + fermer la benne
    ActBucketOpen    : BOOL;  // ouvrir la benne seule
    ActBucketClose   : BOOL;  // fermer la benne seule
    ActBothUp         : BOOL;  // monter les 2 treuils
    ActBothDown       : BOOL;  // descendre les 2 treuils
    ActM1Up / ActM1Down / ActM2Up / ActM2Down : BOOL  // treuil unitaire
    ActTransLeft / ActTransRight : BOOL  // translation
    // + % par action
END_VAR
```

### Règles
- **Mapping** : `geste + contexte → action`. Le contexte est **déjà traité** en amont (PRG_03/04).
- **Zéro safety** : les permis/interlocks sont appliqués par les consommateurs (PRG_04/05).
- **Un seul bloc** centralise le mapping → **fini les millions de conditions**.

---

### `ST_ActionContext` (produit en amont, déjà traité)
```pascal
TYPE ST_ActionContext :
STRUCT
    // Treuils (benne incluse — couplée au sens)
    WinchIntentPossible  : BOOL;   // 0 = pas d'action treuil, 1 = possible
    WinchSelect          : INT;    // 0=both, 1=M1, 2=M2 (si possible)
    BucketOnlyMode       : BOOL;   // TRUE = commander benne seule (sans treuil)

    // Translation
    TranslationIntentPossible : BOOL;  // 0 = pas d'action translation, 1 = possible

    // Assist / cas particuliers
    DiveActive           : BOOL;   // plongée (2 treuils + benne ouverte)
    ExtractionActive     : BOOL;   // extraction (2 treuils + benne fermée)
    DumpAtTremieActive   : BOOL;   // à la trémie : descendre = ouvrir benne
END_STRUCT
END_TYPE
```

---

## 🎯 3bis. Matrice complète des intentions d'action

> **Entrées** : geste (Bloc 1) + `ST_ActionContext` (produit en amont).
> Chaque ligne = un cas d'intention d'action possible.

### A. Domaine Treuil (benne incluse)

| # | Contexte (français) | Contexte (variables) | Geste | Action (français) | Action (variables) |
|---|---|---|---|---|---|
| A1 | Treuils couplés (both), benne couplée au sens | `WinchIntentPossible` + `WinchSelect=both` + `BucketOnlyMode=FALSE` | Push | Descendre les 2 treuils + ouvrir la benne | `ActBothDown` + `ActBucketOpen` |
| A2 | idem | idem | Pull | Monter les 2 treuils + fermer la benne | `ActBothUp` + `ActBucketClose` |
| A3 | Treuil M1 seul, benne couplée | `WinchSelect=M1` + `BucketOnlyMode=FALSE` | Push | Descendre M1 seul | `ActM1Down` |
| A4 | idem | idem | Pull | Monter M1 seul | `ActM1Up` |
| A5 | Treuil M2 seul, benne couplée | `WinchSelect=M2` + `BucketOnlyMode=FALSE` | Push | Descendre M2 seul | `ActM2Down` |
| A6 | idem | idem | Pull | Monter M2 seul | `ActM2Up` |
| A7 | Benne seule (sans treuil) | `BucketOnlyMode=TRUE` | Push | Ouvrir la benne seule | `ActBucketOpen` |
| A8 | idem | idem | Pull | Fermer la benne seule | `ActBucketClose` |
| A9 | Plongée (assist) | `DiveActive` | Push | Plongée : descendre 2 treuils + ouvrir benne | `ActBothDown` + `ActBucketOpen` |
| A10 | Extraction (assist) | `ExtractionActive` | Pull | Extraction : monter 2 treuils + fermer benne | `ActBothUp` + `ActBucketClose` |
| A11 | À la trémie (vidage) | `DumpAtTremieActive` | Push | Ouvrir la benne (au lieu de descendre le treuil) | `ActBucketOpen` |

### B. Domaine Translation

| # | Contexte (français) | Contexte (variables) | Geste | Action (français) | Action (variables) |
|---|---|---|---|---|---|
| B1 | Translation possible | `TranslationIntentPossible` | Left | Translation vers la trémie | `ActTransLeft` |
| B2 | idem | idem | Right | Translation vers la maintenance | `ActTransRight` |

### C. Cas SEMI_AUTO (cycle)

| # | Étape cycle | Contexte (français) | Contexte (variables) | Geste | Action (français) | Action (variables) |
|---|---|---|---|---|---|---|
| C1 | X4 (plongée) | Plongée | `DiveActive` | Push | Descendre 2 treuils + ouvrir benne | `ActBothDown` + `ActBucketOpen` |
| C2 | X6/X7 (remontée) | Extraction | `ExtractionActive` | Pull | Monter 2 treuils + fermer benne | `ActBothUp` + `ActBucketClose` |
| C3 | X10 (→ trémie) | Translation possible | `TranslationIntentPossible` | Left/Right | Translation vers trémie/maintenance | `ActTransLeft`/`ActTransRight` |
| C4 | X11 (vidage) | À la trémie | `DumpAtTremieActive` | Push | Ouvrir la benne | `ActBucketOpen` |

> ℹ️ **Le contexte est produit en amont** (PRG_03/04) à partir du mode, de la sélection, de la
> benne, des assists et de l'étape cycle. Bloc 2 ne fait que `geste + contexte → action`.

---

## 🔀 4. Flux dans le programme

```
PRG_02_Acquisition
  ├─ FB_Joystick ─► AxisCmdX/Y (réel OU simulé)
  └─ FB_GestureIntention (Bloc 1) ─► Gst* + Pct
        │
        ▼
PRG_03_Modes_Cycle
  └─ FB_ActionIntention (Bloc 2) ─► Act* + Pct
        │
        ├──► FB_Cycle (garde direction, ne force pas)
        ├──► PRG_04_Treuils_Benne (arbitrage + interlocks)
        └──► PRG_05_Translation (pilotage variateur)
```

---

## 🛡️ 5. Frontières de responsabilité

| Bloc | Fait | Ne fait PAS |
|---|---|---|
| **Bloc 1 (Geste)** | Décoder joystick → geste physique + % | Boutons, état programme, sécurité, palier, gates aval (power/mode) |
| **Bloc 2 (Action)** | Geste + boutons + état → action concrète | Sécurité, permis, interlocks |
| **Consommateurs** | Appliquer permis/interlocks, piloter actionneurs | Re-décoder le geste |

---

## ✅ 6. Décisions actées

| # | Décision |
|---|---|
| D1 | **2 blocs** : Geste (`FB_GestureIntention`) → Action (`FB_ActionIntention`) |
| D2 | **Bloc 1 pur joystick** : AUCUN bouton, AUCUN état programme |
| D3 | **Bloc 2 mapping pur** : zéro safety (permis en aval) |
| D4 | **Boutons IHM** entrent dans Bloc 2 (action), pas Bloc 1 |
| D5 | **Simulation** en amont (jamais dans les blocs) |
| D6 | **Palier** dans `FB_SpeedStep` (inchangé) ; **Hz** translation (inchangé) |
| D7 | **Préfixe** : `Gst*` (geste) / `Act*` (action) |

---

## ❓ 7. Points ouverts

| # | Question |
|---|---|
| Q1 | **Entrées d'état de Bloc 2** : exactement quelles entrées (mode, sélection, benne) ? |
| Q2 | **Sorties Bloc 2** : liste exacte des actions (bucket seul, both, unitaire M1/M2) ? |
| Q3 | **% par action** : chaque action porte-t-elle son % (comme Bloc 1) ? |
| Q4 | **Emplacement Bloc 2** : dans `PRG_03_Modes_Cycle` ou `PRG_04` ? |

---

## 📊 8. Effort estimé

| Bloc | Effort |
|---|---|
| Bloc 1 (Geste) | 0.5-1 j |
| Bloc 2 (Action) | 1-2 j |
| Câblage + tests | 1-2 j |
| **Total** | **~3-5 j** |
