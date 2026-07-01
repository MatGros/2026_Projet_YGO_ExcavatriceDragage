# 🔍 Audit de cohérence documentaire — Excavatrice de Dragage (v1.0)

> **Nature** : audit de la documentation `DOC/` (specs AF) + fichiers de contexte croisés
> (`CLAUDE.md`, `README.md`, skill `codesys-workflow.md`, `CODE/PRG_JOY1.st`).
> **Périmètre** : cohérence documentaire, cohérence de conception machine/automate/supervision,
> construction des Function Blocks. **Aucune modification de code ni de spec** dans cet exercice.
> **Objectif de conception rappelé** : POO **partielle par composition**, **sans méthode ni property**.
>
> 📅 Établi le 2026-07-01. Décisions intégrées suite à arbitrage utilisateur (voir §2).
> 🔄 Révision : ajout **D12→D16** (interface FB standard, variable **`StartStop`**, modèle d'arrêt
> `StartStop`/`SafeStop`, précédence `Enable`>`SafeStop`>`StartStop`, source `FB_Cycle`+IHM ;
> abandon de la formule `Enable := ordre AND NOT SafeStop` de la 1ʳᵉ passe). Q8/Q9/Q10 résolues.

---

## 🎯 1. Verdict global

Documentation **solide et de bonne facture industrielle** : paradigme de sécurité clair
(AU physique / `SafeStop` / `PowerCutOff`), contrat FB (Partie 3) bien posé, **objectif
« POO partielle sans méthode/property » correctement tenu** (composition d'instances,
tables de données séparées du code, 1 FB = 1 responsabilité).

Restent des **incohérences réelles** à répercuter, désormais **tranchées** par l'utilisateur
(§2), et un lot de **questions en suspens** (§5) à instruire avant mise à jour des specs.

---

## 🧭 2. Décisions actées (arbitrage utilisateur)

| # | Sujet | Décision de référence |
|---|-------|-----------------------|
| D1 | **`SafeStop`** | **Conservé** comme **sortie** des blocs safety (`FB_Safety` / safety métier), **consommée en entrée** par les FB de mouvement. Il **ne force pas les sorties à 0** : il déclenche un **arrêt sur rampe rapide** (voir D12), le FB **restant `Enable`**. |
| D2 | **`CoupeEnable`** | **N'existe pas** comme variable. **Tout le vocabulaire `CoupeEnable` doit disparaître des specs.** ⚠️ Correction : `Enable := (ordre) AND NOT SafeStop` (formulé en v1.0) est **abandonné** — `SafeStop` ne retire **pas** l'`Enable` (voir D12). |
| D3 | **AU (arrêt d'urgence)** | AU physique (coup-de-poing / câble « position haute extrême ») coupe la **puissance** via gros contacteur. **Seul l'AU coupe brutalement.** Automate **jamais coupé** (surveillance permanente). Une **info automate « machine en AU »** existe → alimente `SafetyOk`. |
| D4 | **Arrêt sûr (hors AU)** | Pas de coupure sèche : arrêt des **relais vitesse + sens Av/AR** sur une **rampe plus rapide que l'accélération**, puis collage frein. Déclenché par `SafeStop` (voir D12). |
| D5 | **Limite légale** | **Hors safety.** C'est un **arrêt géré par `FB_Modes`**, pas par `FB_Safety`. |
| D6 | **Synchro treuils / godet** | Pendant la **phase godet**, **pas de mouvement M1** → `FB_WinchSync` **inutile** (aucun conflit). À documenter comme **suspension explicite** de la surveillance synchro en phase godet. |
| D7 | **Cadencement joystick** | Communication CAN **20 ms** ; **code de traitement dans MainTask 10 ms**. |
| D8 | **Architecture POU** | **1 seul POU `main`** exécute les FB **séquentiellement**. **Plus de `PRG_*`** séparés (`PRG_MODES`, `PRG_IO`, `PRG_JOY1` à retirer du vocabulaire des specs). |
| D9 | **`ErrorId`** | **`WORD`** partout (set de bits). |
| D10 | **Filtre PT1** | Nom standard unique : **`FB_FilterPT1`** (sans underscore). |
| D11 | **Blocs joystick** | `FB_CycleTime` = base de temps pour filtrage ; `FB_Joystick` **obligatoire**, appelé dans le **POU main**. |
| D12 | **Interface FB & modèle d'arrêt** | **Tous les FB** ont l'interface standard de base, dont **`Enable`**. `Enable = FALSE` = **FB désactivé = coupure de toutes ses sorties** (neutralisation dure). Pour les **FB de mouvement** : entrée **`StartStop`** (BOOL) → `TRUE` = **rampe d'accélération** vers consigne, `FALSE` = **rampe de décélération normale** (arrêt) ; **`SafeStop`** (entrée, issue du bloc safety) = **rampe de décélération rapide** (FB reste `Enable`). |
| D13 | **Guardrail « arrêt sûr » (CLAUDE.md)** | Le guardrail « arrêt sûr = retrait de l'`Enable` » est **remplacé** : arrêt sûr = **`SafeStop` → rampe rapide** (Enable maintenu) ; `Enable` off = **coupure des sorties** (neutralisation, cas distinct). |
| D14 | **Précédence (Q8)** | Hiérarchie confirmée **`Enable` > `SafeStop` > `StartStop`**. Défaut process → **`SafeStop`** (rampe rapide, `Enable` maintenu). `Enable = FALSE` réservé à la **neutralisation** (déjà à l'arrêt / mode non sélectionné). |
| D15 | **Arrêt = `StartStop := FALSE` (Q9)** | L'arrêt d'un mouvement se fait par **`StartStop := FALSE`** (décélération normale), **pas** par retrait d'`Enable`. ⚠️ `AF_Partie4` §0 (« passage à une étape sans mouvement = retrait `Enable` → rampe ») est **à réécrire**. |
| D16 | **Source de `StartStop` (Q10)** | `StartStop` est commandé par **`FB_Cycle`** (semi-auto) et par les **commandes IHM** (manuel/maintenance), via la **source légitime arbitrée par `FB_Modes`**. |

---

## 📋 3. Registre des incohérences (statut après arbitrage)

Légende statut : ✅ **Résolu** (décision prise) · 🛠️ **À corriger** (correction mécanique, sans décision) · ❓ **Ouvert** (voir §5).

### 🔴 Sévérité BLOQUANTE

| Réf | Localisation | Constat | Statut |
|-----|--------------|---------|--------|
| B1 | `AF_Partie8` §3/§4/§5/§7 ; `CODE/PRG_JOY1.st:20` | `SafeStop` traité comme **entrée-commande qui force les sorties à 0** | ✅ Recadré par **D1** : `SafeStop` = **sortie** safety (info arrêt sûr), pas une entrée qui zérote. Le FB Joystick réagit via **retrait d'`Enable`**. |
| B2 | `AF_Partie8` §7 | `SafetyOk := NOT SafeStop AND EStopOk` → réintroduit **`EStopOk`** (censé absorbé par `SafetyOk`, P3 §1) | ❓ Ouvert (Q2) : formule exacte de `SafetyOk` à figer selon relation `SafeStop`/`SafetyOk`. |
| B3 | `NAMING_CONVENTION.md:35` | `SafeStop` listé en « entrée de commande » | 🛠️ À reclasser : `SafeStop` = **sortie** safety (D1), pas entrée de commande. |

### 🟠 Sévérité MAJEURE

| Réf | Localisation | Constat | Statut |
|-----|--------------|---------|--------|
| M1 | `AF_Partie5` §2 vs §3 | Le pseudo-code override met la limite légale dans `FB_Safety.CheckLimitLegal`, alors que §3 dit « **pas `FB_Safety`**, c'est `FB_Modes` » | ✅ **D5** : limite légale = `FB_Modes`. Corriger le pseudo-code §2. |
| M2 | `AF_Partie6` §5 (`:163`) vs `AF_Partie4` §7 / `AF_Partie5` §5 | `Command := ordre AND NOT CoupeEnable` sur la sortie relais = **coupure sèche**, contredit la « rampe non destructive » | ✅ **D2+D4** : pas de `CoupeEnable` ; arrêt = **rampe sur relais vitesse/sens**, pas coupure de sortie. Reformuler §5. |
| M3 | `AF_Partie4` §3 vs §6 | `FB_WinchSync` (`ΔPos>SyncStop`→arrêt) vs désynchro **volontaire** M2 pour le godet → risque de faux défaut synchro | ✅ **D6** : phase godet = pas de mouvement M1 → **sync suspendue**. Documenter l'interlock. |
| M4 | `AF_Partie2` §2/§9 vs `AF_Partie8` §7 | Traitement joystick en `CanTask` (20 ms) **ou** `MainTask` (10 ms) ? Ambigu | ✅ **D7** : comm 20 ms, **traitement 10 ms** (MainTask). |
| M5 | `AF_Partie2` §0 vs `AF_Partie5` §1, `AF_Partie6` §5, `AF_Partie8` | Terminologie flottante : `PLC_PRG_MAIN` unique vs `PRG_MODES`/`PRG_IO`/`PRG_JOY1` séparés | ✅ **D8** : **1 POU main**, plus de `PRG_*`. Nettoyer le vocabulaire. |
| M6 | `AF_Partie4` §0 | « passage à une étape sans mouvement = retrait `Enable` → arrêt sur rampe » | ✅ **D15** : arrêt = **`StartStop := FALSE`** (décélération normale), pas retrait d'`Enable`. Réécrire §0. |

### 🟡 Sévérité MINEURE

| Réf | Localisation | Constat | Statut |
|-----|--------------|---------|--------|
| m1 | `NAMING_CONVENTION.md:121` (`ST_WinchIO`) | `ErrorId : INT` | ✅ **D9** : `WORD`. |
| m2 | `AF_Partie2` (_COMMON) / `CLAUDE.md` vs `AF_Partie8` §2 / `CODE` / `README` | `FB_FilterPT1` vs `FB_Filter_PT1` (2 identifiants) | ✅ **D10** : `FB_FilterPT1`. |
| m3 | `AF_Partie8` §2/§7 vs `AF_Partie2` arborescence | `FB_AxisScale`, `FB_Ramp`, `FB_CycleTime` absents de l'architecture | ✅ **D11** (partiel) : préciser dans P2 (sous-composants de `FB_Joystick` / base de temps). |
| m4 | `.claude/skills/codesys-workflow.md:25` | Référence `AF_Partie2_..._v2.3.md` (périmé, actif = v2.4) | 🛠️ À corriger (pointe vers version active). |
| m5 | `CODE/PRG_JOY1.st:13` | Lien vers `DOC/AF_Partie4_Fonction_Joystick_v1.0.md` (renuméroté **Partie 8**) | 🛠️ Lien mort → Partie 8. |
| m6 | `README.md` (structure `CODE/`, workflow) | Décrit `CODE/*.xml` + `extract/inject` round-trip, alors que `CODE/` contient un `.st` et la skill impose la **copie manuelle `.st`** | ❓ Ouvert (Q3) : quel workflow fait foi ? |
| m7 | `AF_Partie3` (« **tout** FB respecte le contrat ») vs `AF_Partie6` briques + `FB_Diag*` | Briques E/S & diag n'ont pas l'interface complète (`Enable/Reset/SafetyOk/Mode/State/StateAtError`) | ✅ **D12** : tous les FB portent l'interface **standard de base** (dont `Enable`). Reste à confirmer le périmètre exact des briques réduites (Q4bis). |
| m8 | `AF_Partie2` §9 (ordre) vs §7 (schéma) | `FB_Watchdog()` appelé **après** `FB_Safety()` alors qu'il l'alimente (`ErrorId`) → 1 cycle de retard | ❓ Ouvert (Q5) : réordonner Watchdog **avant** Safety. |
| m9 | `NAMING_CONVENTION.md` (ex. `E_Error`) vs `AF_Partie3` §3 | Exemple d'enum `E_Error` alors que design = bitfield **sans mnémonique** | 🛠️ Harmoniser l'exemple. |
| m10 | `AF_Partie1` §Initialisation | « preset codeurs à une valeur **positive** » puis « **Affichage 0 m** » au plan d'eau — logique correcte mais **non expliquée** (risque de lecture contradictoire) | 🛠️ Ajouter une phrase d'explication (offset brut vs échelle 0). |
| m11 | `Plan_Action` / `CLAUDE.md` (« Auto ») vs `AF_Partie5` (`SEMI_AUTO`) | Vocabulaire « Auto » vs « semi-auto » | 🛠️ Harmoniser (« semi-auto »). |

---

## 🧱 4. Impact transverse de la décision D2 (suppression `CoupeEnable`)

`CoupeEnable` est **omniprésent** dans la v2.4 et les fichiers de tête. Sa suppression (D2)
impose une révision coordonnée (à faire lors d'une mise à jour de specs, hors du présent audit) :

- `AF_Partie1` : §Interactions, §Sécurité (flux `Safety ──CoupeEnable──►`).
- `AF_Partie2` : §0 (décision 4), §4, §5, §6 (titre + tableau), §7, §9.
- `AF_Partie3` : §1 (note v2.4), §2, §7, §9.
- `AF_Partie4` : §0, §1 (`E_CycleStep.ERROR_HOLD`, transitions), §7.
- `AF_Partie5` : §1, §4, §5 (titre + flux).
- `AF_Partie6` : §2 (note feedback), §5.
- `CLAUDE.md`, `README.md`, skill : nombreuses occurrences.

➡️ **Motif de remplacement** (révisé par D12/D13) : supprimer `CoupeEnable` **sans** le
remplacer par un retrait d'`Enable`. Deux mécanismes **distincts** à documenter :
- **Arrêt sûr** = `SafeStop` (entrée des FB de mouvement, issue du bloc safety) → **rampe rapide**, `Enable` maintenu.
- **Neutralisation** = `Enable = FALSE` → **coupure des sorties** du FB (état `DISABLED`).

⚠️ Le guardrail `CLAUDE.md` « arrêt sûr = retrait de l'`Enable` » et la formule
`Enable := (ordre) AND NOT FB_Safety.CoupeEnable` sont **à réécrire** en conséquence.
`PowerCutOff` (coupure puissance amont sur contacteur collé) **reste inchangé**.

---

## ❓ 5. Questions en suspens (à instruire)

| Q | Question | Enjeu |
|---|----------|-------|
| Q1 | **Granularité de `SafeStop`** : une info **globale unique**, ou **plusieurs sorties** (par bloc safety métier / par axe M1, M2, M3) ? | Détermine le câblage vers les FB de mouvement (global vs par axe). |
| Q2 | **Relation `SafeStop` (sortie) ↔ `SafetyOk` (entrée FB)** : complémentaires ou redondants ? Formule de `SafetyOk` (ex. `SafetyOk := (AU réarmé) AND (conditions OK)`), et faut-il **garder `SafetyOk`** ? | Corrige B2 (`EStopOk`) et fige l'interface P3 §1. |
| Q3 | **Workflow `CODE/`** : round-trip **XML** (`extract/inject`, README) **ou** copie manuelle **`.st`** (skill/`CLAUDE.md`) — lequel fait foi ? | Deux workflows contradictoires cohabitent (m6). |
| Q4bis | **Périmètre de l'interface réduite** : confirmer que **briques E/S** (`FB_Input_Digital`, `FB_Output_Relay`) et **diag** (`FB_Diag*`) portent une interface **réduite** (pas de `Start`/`Mode`/`State`/`StateAtError`), le `Start`/`SafeStop` (D12) ne concernant que les **FB de mouvement** ? | Précise D12 (m7). |
| Q5 | **Ordre d'appel** : déplacer `FB_Watchdog()` **avant** `FB_Safety()` (pour alimenter la sécurité le même cycle) ? | Évite 1 cycle (10 ms) de retard (m8). |
| Q6 | **Séquence `INIT`** (`AF_Partie4` §2, marquée *TBD*) : à spécifier maintenant ou laisser ouverte ? | Bloc fonctionnel encore incomplet. |
| Q7 | **Priorités des tâches** (EtherCAT/CAN/Main, « à définir ») : figer maintenant ou plus tard ? | Config CODESYS. |

> ✅ **Q8, Q9, Q10 résolues** → actées en **D14, D15, D16** (§2).

---

## ✅ 6. Points forts confirmés

- **POO partielle sans méthode/property** : respectée et explicite (composition d'instances
  `LIN_TRAFO`/`RAMP_REAL`/`HYSTERESIS`, `ST_SpeedStepTable` masque 4 bits = données ≠ code).
- **Sécurité électrique** : automate jamais coupé + surveillance collage (`ST_ContactorCheck`)
  + `PowerCutOff` amont indépendant — séparation AU / arrêt sûr / coupure puissance correcte.
- **Séquence frein manque-courant** (P4 §4) : temporisations physiques + double vérif feedback,
  conforme aux règles de l'art levage.
- **Reset sur front + pas de redémarrage auto** (P3 §5-6) : robuste (« mains dans le moteur »).
- **Réutilisation libs `Util`** imposée (P1, P3 §0) : pas de réinvention de briques standard.

---

## 📚 Documents audités

`DOC/NAMING_CONVENTION.md` · `DOC/AF_Partie1_..._v1.1` · `DOC/AF_Partie2_..._v2.4` ·
`DOC/AF_Partie3_..._v1.1` · `DOC/AF_Partie4_..._v1.0` · `DOC/AF_Partie5_..._v1.0` ·
`DOC/AF_Partie6_..._v1.0` · `DOC/AF_Partie8_..._v1.0` · `CLAUDE.md` · `README.md` ·
`.claude/skills/codesys-workflow.md` · `CODE/PRG_JOY1.st` · `Plan_Action_Excavatrice_Detaillee.md`.
