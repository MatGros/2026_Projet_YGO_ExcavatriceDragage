# 🔍 Audit de cohérence documentaire — Excavatrice de Dragage (v1.0)

> **Nature** : audit de la documentation `DOC/` (specs AF) + fichiers de contexte croisés
> (`CLAUDE.md`, `README.md`, skill `codesys-workflow.md`, `CODE/PRG_JOY1.st`).
> **Périmètre** : cohérence documentaire, cohérence de conception machine/automate/supervision,
> construction des Function Blocks. **Aucune modification de code ni de spec** dans cet exercice.
> **Objectif de conception rappelé** : POO **partielle par composition**, **sans méthode ni property**.
>
> 📅 Établi le 2026-07-01. Décisions intégrées suite à arbitrage utilisateur (voir §2).
> 🔄 Révision : ajout **D12→D22** (interface FB, variable **`StartStop`**, modèle d'arrêt, précédence ;
> **`SafeStop` par métier**, **`SafetyOk`→`EmergencyStopOk`**, **suppression `FB_Watchdog`** et du
> **workflow XML `extract/inject`**). Q1→Q5 et Q8→Q10 résolues ; restent Q6/Q7 (TBD) + Q11.

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
| D17 | **Granularité `SafeStop` (Q1)** | **1 `SafeStop` par métier** (chaque bloc safety métier surveille des choses différentes → sa propre sortie `SafeStop`, consommée par le/les FB de mouvement de son domaine). Pas de `SafeStop` global unique. |
| D18 | **`SafetyOk` → `EmergencyStopOk` (Q2)** | L'entrée standard `SafetyOk` est **renommée `EmergencyStopOk`** : information de la **chaîne de sécurité AU** **ou** du **contacteur de puissance** (**source à définir**). Résout le `EStopOk` fautif de la Partie 8 (B2). |
| D19 | **Workflow `CODE/` (Q3)** | **Plus de script `extract`/`inject`.** L'utilisateur **exporte manuellement** depuis CODESYS → `Device.export` (analyse du projet complet), puis **colle manuellement** le code **ST** et exécute des **procédures manuelles** de mise à jour. `CODE/` = fichiers **`.st`**. → `README.md` (workflow XML round-trip) **à corriger** (m6). |
| D20 | **Interface réduite briques (Q4bis)** | Les briques **E/S** (`FB_Input_Digital`, `FB_Output_Relay`) et **diag** (`FB_Diag*`) **n'ont pas** de `StartStop` : elles ont **leurs propres types de données** (interface dédiée). Confirme l'exemption au template complet. |
| D21 | **`FB_Watchdog` supprimé (Q5)** | `FB_Watchdog` est **retiré** : le chien de garde est déjà assuré par la **fonction système** (task watchdog CODESYS). Le seuil 200 ms = **configuration tâche**, pas un FB. → nettoyer P2 (arborescence §3, §2, §4, §7, §9), P5 §5, `CLAUDE.md`. |
| D22 | **`INIT` & priorités tâches (Q6/Q7)** | **TBD** — reportés (séquence `INIT` fine, priorités EtherCAT/CAN/Main). |

---

## 📋 3. Registre des incohérences (statut après arbitrage)

Légende statut : ✅ **Résolu** (décision prise) · 🛠️ **À corriger** (correction mécanique, sans décision) · ❓ **Ouvert** (voir §5).

### 🔴 Sévérité BLOQUANTE

| Réf | Localisation | Constat | Statut |
|-----|--------------|---------|--------|
| B1 | `AF_Partie8` §3/§4/§5/§7 ; `CODE/PRG_JOY1.st:20` | `SafeStop` traité comme **entrée-commande qui force les sorties à 0** | ✅ Recadré par **D1** : `SafeStop` = **sortie** safety (info arrêt sûr), pas une entrée qui zérote. Le FB Joystick réagit via **retrait d'`Enable`**. |
| B2 | `AF_Partie8` §7 | `SafetyOk := NOT SafeStop AND EStopOk` → réintroduit **`EStopOk`** (censé absorbé par `SafetyOk`, P3 §1) | ✅ **D18** : `SafetyOk` **renommé `EmergencyStopOk`** (chaîne AU / contacteur puissance, source à définir). `EStopOk` disparaît. |
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
| m6 | `README.md` (structure `CODE/`, workflow) | Décrit `CODE/*.xml` + `extract/inject` round-trip, alors que `CODE/` contient un `.st` et la skill impose la **copie manuelle `.st`** | ✅ **D19** : workflow XML **supprimé** ; export manuel `Device.export` + copie ST manuelle. Corriger README (structure `CODE/`, section « Workflow Édition », `extract.bat`/`inject.bat`, `tools/`). |
| m7 | `AF_Partie3` (« **tout** FB respecte le contrat ») vs `AF_Partie6` briques + `FB_Diag*` | Briques E/S & diag n'ont pas l'interface complète (`Enable/Reset/SafetyOk/Mode/State/StateAtError`) | ✅ **D12 + D20** : FB de mouvement = interface standard + `StartStop` ; briques E/S & diag = **types de données propres** (pas de `StartStop`). |
| m8 | `AF_Partie2` §9 (ordre) vs §7 (schéma) | `FB_Watchdog()` appelé **après** `FB_Safety()` alors qu'il l'alimente (`ErrorId`) → 1 cycle de retard | ✅ **Sans objet (D21)** : `FB_Watchdog` supprimé (fonction système). Retirer toutes ses références. |
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

### Autres révisions transverses actées
- **`SafetyOk` → `EmergencyStopOk`** (D18) : entrée standard renommée dans P3 §1, et partout
  (P8, `CODE/PRG_JOY1.st`, `NAMING_CONVENTION.md`, `CLAUDE.md`, README).
- **Suppression `FB_Watchdog`** (D21) : retirer de P2 (arborescence §3, tableau §2, §4, §7, §9),
  P5 §5 et `CLAUDE.md` ; le watchdog 200 ms devient une **config tâche système**.
- **`SafeStop` par métier** (D17) : P1/P2/P3/P5 doivent parler de **plusieurs** `SafeStop`
  (un par bloc safety métier), pas d'un signal unique.
- **Workflow `CODE/`** (D19) : réécrire `README.md` (plus de `.xml`, `extract/inject`, `tools/`).

---

## ❓ 5. Questions en suspens (à instruire)

| Q | Question | Enjeu |
|---|----------|-------|
| Q6 | **Séquence `INIT`** (`AF_Partie4` §2, marquée *TBD*) : à spécifier maintenant ou laisser ouverte ? | Bloc fonctionnel encore incomplet. **→ TBD (D22).** |
| Q7 | **Priorités des tâches** (EtherCAT/CAN/Main, « à définir ») : figer maintenant ou plus tard ? | Config CODESYS. **→ TBD (D22).** |
| Q11 | **Source de `EmergencyStopOk`** : chaîne de sécurité AU **ou** retour du **contacteur de puissance** ? (marquée « à définir » en D18) | Fige l'origine de l'info sécurité consommée par les FB. |

> ✅ **Q1→Q5, Q8→Q10 résolues** → actées en **D14…D21** (§2). Ne restent ouvertes que **Q6/Q7** (TBD) et **Q11** (source `EmergencyStopOk`, à définir).

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

## 📚 Documents audités (état initial)

`DOC/NAMING_CONVENTION.md` · `DOC/AF_Partie1_..._v1.1` · `DOC/AF_Partie2_..._v2.4` ·
`DOC/AF_Partie3_..._v1.1` · `DOC/AF_Partie4_..._v1.0` · `DOC/AF_Partie5_..._v1.0` ·
`DOC/AF_Partie6_..._v1.0` · `DOC/AF_Partie8_..._v1.0` · `CLAUDE.md` · `README.md` ·
`.claude/skills/codesys-workflow.md` · `CODE/PRG_JOY1.st` · `Plan_Action_Excavatrice_Detaillee.md`.

---

## 🚀 7. Implémentation des décisions (2026-07-01)

Toutes les décisions **D1→D21** (D22 = TBD assumé) ont été répercutées dans les specs. Les
anciennes versions ont été déplacées vers `DOC/Archives/` (gitignoré, non versionné) conformément
à la règle de versionnement stricte de la skill `codesys-workflow`.

| Fichier | Ancienne version | Nouvelle version | Changements clés |
|---------|-------------------|-------------------|-------------------|
| `DOC/NAMING_CONVENTION.md` | (sans version) | édité en place | `SafeStop` reclassé sortie safety métier, `StartStop` ajouté, `EmergencyStopOk` ajouté, `ErrorId` en `WORD`, exemple `E_Error` retiré |
| `AF_Partie1_Analyse_Fonctionnelle` | v1.1 | **v1.2** | Suppression `CoupeEnable`, flux `SafeStop`/`StartStop`, explication init codeurs (m10) |
| `AF_Partie2_Architecture_Programme` | v2.4 | **v2.5** | Suppression `CoupeEnable` et `FB_Watchdog` ; modèle `SafeStop` (par métier) / `StartStop` ; `EmergencyStopOk` ; interlock godet/synchro documenté ; composition pipeline joystick précisée (m3) |
| `AF_Partie3_Template_FB_Commun` | v1.1 | **v1.2** | Nouveau §1bis (profils d'interface FB standard / mouvement / briques réduites) ; `EmergencyStopOk` ; précédence `Enable`>`SafeStop`>`StartStop` ; §7/§9 réécrits |
| `AF_Partie4_Cycle_Sequenceur` | v1.0 | **v1.1** | §0 réécrit (`StartStop:=FALSE`, pas retrait Enable) ; nouveau §3bis (suspension `FB_WinchSync` en phase godet, M3) ; `ERROR_HOLD` déclenché par `SafeStop` |
| `AF_Partie5_Modes_Maintenance` | v1.0 | **v1.1** | Pseudo-code §2 corrigé (limite légale hors `FB_Safety`, M1) ; §4/§5 réécrits (`SafeStop` par métier, watchdog système) |
| `AF_Partie6_IO_Conditioning` | v1.0 | **v1.1** | §5 corrigé (pas de coupure sèche de sortie relais, M2) ; terminologie `PRG_IO` retirée (M5) |
| `AF_Partie8_Fonction_Joystick` | v1.0 | **v1.1** | `SafeStop` retiré de l'interface (B1) ; `EStopOk`/`SafetyOk` → `EmergencyStopOk` (B2) ; lien mort corrigé (m5) ; `FB_FilterPT1` (m2) ; nouveau §6bis (écarts avec `CODE/PRG_JOY1.st` actuel) |
| `CLAUDE.md` | — | édité en place | Guardrails, arborescence, liens de version, cas d'arrêt mis à jour |
| `README.md` | — | édité en place | Workflow XML `extract/inject` remplacé par export/copie manuelle (D19, m6) ; liens de version |
| `.claude/skills/codesys-workflow.md` | — | édité en place | Référence v2.3→v2.5 corrigée (m4) ; exemple `SafeStop`/`EmergencyStopOk` mis à jour |
| `Plan_Action_Excavatrice_Detaillee.md` | — | édité en place | `FB_Safety_<Metier>`, limite légale déplacée sous `FB_Modes`, `FB_Watchdog` retiré, « Auto » → « Semi-auto » (m11) |

### ⚠️ Hors périmètre (non modifié)
- **`CODE/PRG_JOY1.st`** : non touché — reste **hors périmètre** d'un audit documentaire (le code
  CODESYS s'édite via le workflow `codesys-workflow` avec validation utilisateur explicite). Les
  écarts entre ce fichier et la Partie 8 v1.1 sont listés dans `AF_Partie8_..._v1.1.md` §6bis
  (câblage `SafeStop`/`SafetyOk` à corriger, nom `PRG_JOY1` à faire évoluer).
- **Q6/Q7/Q11** (séquence `INIT` fine, priorités tâches, source exacte de `EmergencyStopOk`) :
  restent **TBD**, non spécifiées dans cette passe.

---

## 🚀 8. Décisions terminologiques + sécurité treuil (2026-07-02, session nouvel export I/O réel)

**Contexte** : nouvel export `Device.export` reçu (I/O Mapping réel pour la majorité des signaux
M1/M2 winch + capteur position haute commun + nouveaux signaux thermique/mou de câble). En
parallèle, l'utilisateur a tranché deux renommages métier en attente depuis le retour arrière
partiel du 2026-07-02 (`f194b2d`/`9fd9627`).

| # | Sujet | Décision |
|---|-------|----------|
| D23 | **Godet→Grappin** | Terme métier définitif : **Grappin** (ouverture/fermeture, prévention gravats). `Bucket`/`Godet` retirés du vocabulaire des specs. `FB_Grappin`, `ST_GrappinConfig`/`ST_GrappinState` (aspirationnels, non codés). |
| D24 | **Translation→Chariot** | Terme métier définitif : **Chariot** (axe transversal M3, objet métier qui se déplace) — conserve **Plongée/Extraction** pour les treuils (inchangé). `FB_Chariot`, `FB_Safety_Chariot`, `E_ChariotCommMode`, `GVL_Chariot_M3_Stub`, `ST_ChariotIO`. Préfixe I/O physique **M3 inchangé** (mapping matériel), `E_CycleStep.TRANSLATION_MOVE` renommé **`CHARIOT_MOVE`**. |
| D25 | **I/O réel M1/M2 winch** | `RelayFwd/Rev`, `SpeedContactor_1..4` (renommé, ex `Contactor1..4`), `BrakeCmd`, `ContactorFeedbackFwd/Rev` désormais câblés en I/O Mapping réel → stubs `GVL_Winch_M1/M2_Stub` réduits à `BrakeFeedback` seul (dernier signal non câblé). |
| D26 | **Capteur position haute réel** | `M1_M2_TopPositionSensor` (I/O réel, commun M1+M2) — résout la clarification terminologique laissée ouverte en Partie10 v1.3. `GVL_Homing_Stub` **supprimé**. |
| D27 | **Mou de câble → `ForbidDescent`** | Nouveau signal `M1_M2_SlackCableSwitch` (I/O réel, commun). Ne peut **pas** être porté par `SafeStop` (arrête les 2 sens) : nouvelle sortie dédiée `FB_Safety_Winch.ForbidDescent`, masque **uniquement** `RelayRev` (descente) — `RelayFwd` (montée) reste libre pour vérification câblage. Défaut visible IHM (`ErrorId` bit3), reset front standard. Pattern **spécifique à ce cas**, pas une généralisation du contrat Partie3. |
| D28 | **Thermique moteur → `SafeStop`** | `M1/M2_ThermalFeedback` (I/O réel, par treuil) → nouveau bit `ErrorId` (bit2) dans `FB_Safety_Winch`, participe à `SafeStop` (arrêt total classique, protection moteur). |
| D29 | **Capteurs position Chariot** | 4 capteurs réels (`PosiFosse1`/`PosFosse2`/`PosMaintenance`/`PosTremie`) câblés, mais sélection de cible normale différée à `FB_Cycle` (non codé). Sélecteur **STUB maintenance** (`StubChariotPositionSelect_IHM`) ajouté pour tester chaque capteur individuellement dès ce lot. |
| D30 | **Nouveaux équipements (convoyeur, grille, casque, hydraulique)** | **Hors périmètre explicite** de ce lot (décision utilisateur : "pour l'instant, il n'y a rien à faire") — non traités, ni en code ni en doc. |

### Fichiers impactés (2026-07-02)
- **CODE/** : `FB_Chariot.st` (ex-`FB_Translation`), `FB_Safety_Chariot.st`, `E_ChariotCommMode.st`,
  `GVL_Chariot_M3_Stub.st` (renommés + M3_BrakeCmd retiré, sélecteur position ajouté),
  `FB_Safety_Winch.st`/`FB_Winch.st` (ThermalFeedback/SlackCableDetected/ForbidDescent),
  `GVL_Winch_M1/M2_Stub.st` (réduits à BrakeFeedback), `GVL_Homing_Stub.st` (supprimé),
  `PRG_MAIN.st` (câblage complet), + mentions croisées (`FB_Brake`, `FB_Encoder_*`,
  `FB_Joystick`, `FB_Input_Digital`, `FB_Output_Relay`, `ST_AxisCmd`, `ST_EncoderCalib`).
- **DOC/** : Partie1 v1.3→**v1.4**, Partie2 v2.6→**v2.7**, Partie3 v1.2→**v1.3**,
  Partie4 v1.1→**v1.2**, Partie5 v1.1→**v1.2**, Partie6 v1.1→**v1.2**, Partie8 v1.1→**v1.2**,
  Partie9 v1.0→**v1.1**, Partie10 v1.3→**v1.4**, Partie11 (renommé) v1.1→**v1.2**,
  `NAMING_CONVENTION.md`/`CLAUDE.md` édités en place. Anciennes versions → `DOC/Archives/`.
