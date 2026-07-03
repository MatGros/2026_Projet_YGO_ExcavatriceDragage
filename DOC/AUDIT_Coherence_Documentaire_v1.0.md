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
| Q11 | **Source de `EmergencyStopOk`** : chaîne de sécurité AU **ou** retour du **contacteur de puissance** ? (marquée « à définir » en D18) | ✅ **Résolue (2026-07-03), partiellement** : I/O réel confirmé = **retour contacteur de puissance géré par l'arrêt d'urgence** (les deux à la fois, en fait — pas un "ou"). Câblé sur `instEncoderAbsM1/M2`/`instHomingM1/M2` (D31). ⚠️ Reste `GVL_DEBUG.DBG_True` sur Joystick/Safety_Winch/Winch/Safety_Chariot/Chariot — même variable réelle à reprendre, pas encore fait sur ces FB. |

> ✅ **Q1→Q5, Q8→Q10 résolues** → actées en **D14…D21** (§2). **Q11 résolue partiellement**
> (2026-07-03, D31 — pipeline codeur seulement). Ne reste ouvert que **Q6/Q7** (TBD).

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

---

## 🚀 9. Correctifs pipeline codeur (2026-07-03, retours mise en service)

| # | Sujet | Décision |
|---|-------|----------|
| D31 | **Sens de comptage codeur** | `InvertDirection` (calcul PLC) **retiré** de `FB_Encoder_Abs` — était buggé (inversait sur la plage `UDINT` 32 bits au lieu de la plage réelle 25 bits du codeur, `PointsPerRev × MultiTurnRevsMax`). Confirmé terrain : objet CoE **`6000h`** (bit0 : `4`→`5`) inverse le sens **côté codeur** (Kübler F58x8), réglé en **Startup Parameter CODESYS** (init automate, pas un paramètre PLC). |
| D32 | **`EmergencyStopOk` réel (Q11, partiel)** | I/O réel confirmé = retour contacteur de puissance géré par l'AU. Câblé sur `instEncoderAbsM1/M2`/`instHomingM1/M2` **uniquement ce lot** — Joystick/Safety_Winch/Winch/Safety_Chariot/Chariot restent sur `GVL_DEBUG.DBG_True` (même câblage à reprendre, prochain lot). |
| D33 | **`Reset` codeur/homing câblé + `GVL_Encoder_Stub`** | `Reset` des FB codeur/homing (`FALSE` figé jusqu'ici — alarmes jamais acquittables) câblé sur `M1/M2_Reset_IHM` (un bouton par codeur, acquitte `instEncoderAbsMx` + `instHomingMx`). Nouveau `CODE/GVL_Encoder_Stub.st` : centralise Reset/`ConfirmCoherence`/`Home`/`TopSensorPositionM` (déplacés depuis `PRG_MAIN`) — un seul endroit à consulter pour le mapping IHM et les paramètres de homing (mètres). |

### Fichiers impactés (2026-07-03)
- **CODE/** : `FB_Encoder_Abs.st` (`InvertDirection` retiré), `GVL_Encoder_Stub.st` (nouveau),
  `PRG_MAIN.st` (câblage `Reset`/`EmergencyStopOk` réel sur les 4 instances codeur/homing,
  déclarations `StubHomeButton_IHM`/`M1_M2_TopSensorPositionM` déplacées), + refs croisées
  (`FB_Encoder_Homing/Scale`, `FB_Safety_Winch`, `ST_EncoderCalib`).
- **DOC/** : Partie10 v1.4→**v1.5**→**v1.6** (2 lots), Partie9 (ref croisée v1.6),
  `CLAUDE.md` (ref croisée v1.6), AUDIT Q11 partiellement résolue.

---

## 🚀 10. `EmergencyStopOk` généralisé via `FB_Input_Digital` (2026-07-03bis)

| # | Sujet | Décision |
|---|-------|----------|
| D34 | **`EmergencyStopOk` réel généralisé (Q11 close)** | Le câblage direct de l'I/O réel `EmergencyStopOk` (D32) est étendu à **tous** les FB métier (Joystick/Safety_Winch M1+M2/Winch M1+M2/Safety_Chariot/Chariot), en plus d'Encoder/Homing. `GVL_DEBUG.DBG_True` **disparaît** de `PRG_MAIN` pour ce signal. |
| D35 | **Intégration `FB_Input_Digital` (Partie6 §0, "en attente")** | Choix tranché **pour `EmergencyStopOk` uniquement** (pas pour tous les I/O) : une instance `instEmergencyStopOk` conditionne le raw I/O (anti-rebond `T#20MS` + `InvertLogic` pour bascule NO/NC en mise en service sans retoucher le câblage) → sortie `EmergencyStopOkCond`, seule variable distribuée aux FB métier. Motivation utilisateur : pouvoir **forcer/inverser facilement** en mise en service sans toucher les GVL. `ChannelOk` laissé au défaut `TRUE` (pas de diagnostic voie/carte disponible ce lot). |

> ✅ **Q11 entièrement résolue** (D32 + D34/D35).

### Fichiers impactés (2026-07-03bis)
- **CODE/** : `PRG_MAIN.st` (`instEmergencyStopOk : FB_Input_Digital`, `EmergencyStopOkCond`,
  remplace `EmergencyStopOk`/`GVL_DEBUG.DBG_True` sur les 11 câblages FB métier).
- **DOC/** : `AF_Partie6_IO_Conditioning` (état d'implémentation — `FB_Input_Digital` intégré pour
  `EmergencyStopOk`), AUDIT Q11 close.

---

## 🚀 11. Généralisation finale — `FB_IO_Machine` (2026-07-03ter)

| # | Sujet | Décision |
|---|-------|----------|
| D36 | **Consolidation en 1 seul FB `FB_IO_Machine` (revient sur D35 "uniquement EmergencyStopOk")** | Après tests successifs (par métier `FB_IO_Winch`/`FB_IO_Chariot`, ou par sens In/Out séparé), choix final utilisateur : **un seul FB, une seule instance** (`instIoMachine`) couvrant TOUT le conditionnement I/O réel de la machine (Commun + Winch M1 + Winch M2 + Chariot M3, entrées ET sorties). Interface volontairement longue (~28 voies) mais **tout au même endroit**, classé par section métier commentée — priorité choisie : lisibilité/maintenabilité (1 seul fichier à ouvrir) plutôt que modularité par FB. `instSafety`/`LocalEmergencyStopTOR` (résidu mort, sorties jamais consommées) retirés de `PRG_MAIN` à cette occasion. |
| D37 | **Appel 2×/cycle d'une même instance (pattern retenu)** | `instIoMachine` est appelée deux fois dans `PRG_MAIN` : 1er appel tout en haut (entrées réelles → `*Cond`, consommées par Homing/Safety_Winch/Winch/Safety_Chariot/Chariot), 2e appel tout en bas (commandes `*Cmd` des FB métier, disponibles seulement à ce point → `*Out` vers I/O Mapping réel). Sans risque sur les timers anti-rebond internes (écart de temps ≈0 entre les 2 appels du même scan). Chariot M3 : seuls les signaux réellement câblés (`PosFosse1/2/Maintenance/Tremie`, `M3_BrakeCmd`) sont conditionnés — `M3_RelayFwd/Rev/RelaySpeedGv` restent STUB logiciel (pas de matériel réel). |

### Fichiers impactés (2026-07-03ter)
- **CODE/** : `FB_IO_Machine.st` (nouveau, remplace `FB_IO_Winch.st`/`FB_IO_Winch_In.st`/
  `FB_IO_Winch_Out.st` supprimés en cours de route), `PRG_MAIN.st` (1 seule instance
  `instIoMachine`, 2 appels ; `instSafety`/`LocalEmergencyStopTOR`/`LocalEthercatOk` retirés).
- **DOC/** : `AF_Partie6_IO_Conditioning` (état d'implémentation mis à jour), AUDIT (ce §11).

---

## 🚀 12. `FB_Modes` (MVP) + `FB_Encoder_Safety` + `FB_WinchSync` — squelettes de liaisons (2026-07-03quater)

| # | Sujet | Décision |
|---|-------|----------|
| D38 | **`FB_Modes` MVP — diffusion du mode uniquement** | Nouveau `FB_Modes` (+ `GVL_Modes_Stub.ModeRequest_IHM` forceable) remplace les **10 `E_Mode.MAINT_N1` codés en dur** dans `PRG_MAIN` (liste confirmée par audit indépendant). Garde-fous : refuse `SEMI_AUTO` si `EncoderFaultPresent` (agrégat `FB_Encoder_Safety` M1/M2, 1 cycle de retard) ; refuse `MAINT_N2` sans `PasswordOk` (stub). Sort `OverrideSync` pour `FB_WinchSync`. **Hors périmètre** : `OverrideGrappin`/limite légale — pas de consommateur (`FB_Grappin`/`FB_Cycle` inexistants), pas de dead code ajouté sans raison. |
| D39 | **`FB_Encoder_Safety` revive — bornage ±99m + relais `HomingSuspect`** | Répond à l'incident `CablePosM≈4096m` (RETAIN `Calib` remis à 0 après refactor structurel). Périmètre limité à Partie10 §3.6 (bornage) + relais §3.7 (`HomingSuspect`, déjà calculé par `FB_Encoder_Homing`, jamais consommé avant ce lot). §3.5 (saut en exploitation, calcul 4ms EtherCAT) **reporté**, lot dédié. `EncoderIncoherent` alimente **`FB_Modes` uniquement** (pas `FB_Safety_Winch`/`SafeStop`) — décision explicite utilisateur : un défaut codeur doit bloquer `SEMI_AUTO`, PAS empêcher de bouger les treuils en MAINT_N1/N2 pour re-référencer. |
| D40 | **`FB_WinchSync` — squelette de surveillance, pas de correction** | Nouveau FB (1 instance), calcule `DeltaPosM`/`SyncWarn` (Partie9 §9 : imposé N1, activable/désactivable N2 via `OverrideSync`, actif par défaut MANUEL/SEMI_AUTO faute de `FB_Cycle`). `SyncWarn` = **avertissement IHM uniquement** (Partie5 §6), pas de `SafeStop` : aucune entrée de correction n'existe sur `FB_Winch` aujourd'hui, rien à piloter automatiquement. Squelette de liaisons volontaire (« même si pas complet à l'intérieur »), pas de logique de régulation inventée. |
| D41 | **`StubWinchEnableN1` → `StubMachineEnableN1`** | Renommage (signalé par audit indépendant) : la variable est utilisée par `FB_Winch` **et** `FB_Chariot`, le nom `Winch` était trompeur. |

### Fichiers impactés (2026-07-03quater)
- **CODE/** : `GVL_Modes_Stub.st` (nouveau), `FB_Modes.st` (nouveau), `FB_Encoder_Safety.st`
  (nouveau, revive), `FB_WinchSync.st` (nouveau), `PRG_MAIN.st` (`instModes`/`instEncoderSafetyM1/2`/
  `instWinchSync`, remplacement des 10 `E_Mode.MAINT_N1`, `WinchSyncToleranceM` RETAIN,
  renommage `StubMachineEnableN1`).
- **DOC/** : `AF_Partie5_Modes_Maintenance` (état d'implémentation `FB_Modes` MVP),
  `AF_Partie9_Fonction_Winch` (§9 `FB_WinchSync` squelette), `AF_Partie10...` (§3.6/§3.7
  `FB_Encoder_Safety` revive), AUDIT (ce §12).
- **Audit indépendant** : un agent spécialisé automatisme a cartographié tous les flux
  inter-FB de `PRG_MAIN` avant ce lot — confirme la liste des 10 `E_Mode.MAINT_N1`, signale
  `StubWinchEnableN1` mal nommé, `FB_Joystick` avec `SafeStop` non conforme Partie3 §1bis
  (dette déjà connue, non traitée ce lot), `CablePosM`/`Homed`/`HomingSuspect` jamais
  consommés avant ce lot (désormais consommés par `FB_Encoder_Safety`/`FB_WinchSync`).

---

## 🚀 13. Limitation couple en descente — `MaxStepDescente` (2026-07-03quinquies)

| # | Sujet | Décision |
|---|-------|----------|
| D42 | **Plafond palier direction-dépendant** | Nouvelle spec terrain : en descente (charge entraînante, image de couple plutôt que vitesse), le palier atteignable ne doit JAMAIS dépasser un plafond (`MaxStepDescente`, défaut 2) même à consigne joystick 100%. Choix d'implémentation (validé utilisateur, vs re-mapping du 0-100%) : **plafond fixe**, pas de rescale de la courbe — `FB_SpeedStep` gagne une entrée `MaxStepNumber` (défaut 5, pas de régression montée), `FB_Winch` fournit `MaxStepDescente` uniquement quand `CommandedDirection=-1`. Logique de décodage centralisée dans `FB_SpeedStep` (pas de duplication de la lecture table dans `FB_Winch`). |

### Fichiers impactés (2026-07-03quinquies)
- **CODE/** : `FB_SpeedStep.st` (`MaxStepNumber`, plafond post-hystérésis), `FB_Winch.st`
  (`MaxStepDescente` + câblage direction-dépendant sur l'appel `SpeedStep`).
- **DOC/** : `AF_Partie9_Fonction_Winch` (REX §8), AUDIT (ce §13).

---

## 🚀 14. Lot A mise en service — diag bus réels, Reset général, PowerCutOff (2026-07-03sexies)

| # | Sujet | Décision |
|---|-------|----------|
| D43 | **Diag EtherCAT réel** | `instDiagEthercat` câblé sur les instances esclaves IoDrvEtherCAT (`COD1_CODEUR`/`COD2_CODEUR`/`AC600_ECAT_Drive` : propriétés `.wState` [ETC_SLAVE_STATE, 8=OP] et `.xError`) — remplace les littéraux `FALSE`/`8` qui rendaient toute perte bus **indétectable** (trou de sécurité n°1 du plan mise en service). ⚠️ Noms de propriétés à confirmer à la compilation (Input Assistant) selon version IoDrvEtherCAT. **CAN joystick** : propriété d'état de `JOY1_JOYSTICK_MCB560_CO4201A` (CANRemoteDevice) non confirmée — littéraux `TRUE` conservés avec TODO explicite (ne pas inventer un nom de propriété). |
| D44 | **Reset général machine** | Nouveau `GVL_Machine_Stub.MachineReset_IHM` (bouton unique, front) distribué à TOUTES les instances — plus aucun `Reset := FALSE` figé dans `PRG_MAIN` (avant : 9 instances inacquittables). Boutons par codeur `M1/M2_Reset_IHM` conservés, OR-és avec le bouton général (Partie3 §5 « bouton général »). |
| D45 | **Point de câblage `PowerCutOff`** | Agrégat `PowerCutOffCmd := OR des 3 PowerCutOff safety` → `GVL_Machine_Stub` (§8 PRG_MAIN). Les 3 sorties restent FALSE (pas de ST_ContactorCheck puissance dans les FB safety, TBD assumé) mais le point de câblage existe : remplacer la variable stub par le canal réel dès que le relais physique sera en I/O Mapping — plus d'oubli silencieux (recommandation audit flux). |

### Fichiers impactés (2026-07-03sexies)
- **CODE/** : `GVL_Machine_Stub.st` (nouveau), `PRG_MAIN.st` (diag réels §0, Reset général
  partout, agrégat PowerCutOff §8).
- **Reste du Lot A (matériel, non codable)** : `BrakeFeedback` M1/M2/M3 réels (câblage
  physique + I/O Mapping), relais physique `PowerCutOff`, propriété d'état CAN joystick.

---

## 🚀 15. Review indépendante Lot A — verdict GO conditionnel (2026-07-03septies)

Agent spécialisé automatisme/PLC, review critique du diff Lot A (§14) avant application CODESYS.

**✅ Conforme** : Reset = front partout (12 FB vérifiés un par un, R_TRIG interne + vérif cause
disparue) ; doute homing NON acquittable par le reset général (`ConfirmCoherence` dédié,
protection contre le masquage) ; instances esclaves `AC600_ECAT_Drive`/`COD1_CODEUR`/
`COD2_CODEUR` confirmées exactes dans `Device.export` ; chemin perte-codeur→SafeStop sans
retard de cycle ; `PowerCutOff` correctement placé (écriture fin de POU = image process, pas
de coût de cycle) ; pas de redémarrage auto malgré `SlaveAutoRestart` maître (latch applicatif
tient jusqu'au Reset).

| # | Sujet | Décision |
|---|-------|----------|
| D46 | **Gel diag EtherCAT sur `xConfigFinished`** | Sans ce gel, la montée du bus (INIT→OP, centaines de ms) fait latcher un défaut à CHAQUE mise sous tension (`xError`/`wState` pas significatifs avant `EtherCAT_Master.xConfigFinished=TRUE`) → SafeStop systématique confondu avec une panne. Corrigé : `WcState := xConfigFinished AND (xError esclave OR xError maître)`, `SlaveState := SEL(xConfigFinished, 16#0008, wState réel)`. |
| D47 | **NO-GO essais réels avec mouvement (2 conditions)** | (1) Sémantique fail-safe de `xError`/`wState` au débranchement PHYSIQUE non garantie selon version stack (latence, ou pire `Online=TRUE` figé) — **test de recette obligatoire** : débrancher COD1 puis COD2 (treuils à l'arrêt), vérifier détection + chronométrer, AVANT tout essai avec mouvement. Aggravant : `KeepInputData=FALSE` au maître → `COD1_PosValue` tombe à 0 au décrochage, valeur qui retombe DANS le bornage ±99m de `FB_Encoder_Safety` (pas de filet automatique). (2) CAN joystick toujours en littéraux `TRUE` — l'homme-mort est aveugle à la perte de liaison, aucun essai avec charge tant que non câblé réel. |
| D48 | **`FB_DiagEthercat.ErrorId` non-bitfield — reporté** | Pré-existant (hors `CODE/*.st`, uniquement dans le projet CODESYS/`Device.export`), devient "vivant" avec ce lot (le diag est maintenant réellement évalué). Codes IHM potentiellement incohérents (bits chevauchants : `16#0011`/`16#0021`/`16#0031`, masques de clear qui se recouvrent). Non bloquant (`Error` résumé reste correct). À traiter si `FB_DiagEthercat` est un jour exporté vers `CODE/*.st` (recommandation audit §11 point 5, toujours en attente). |

### Fichiers impactés (2026-07-03septies)
- **CODE/** : `PRG_MAIN.st` (gel `xConfigFinished` sur les 3 esclaves EtherCAT).
- **DOC/** : AUDIT (ce §15).

> ⚠️ **D46 REVU par D50 (§16 ci-dessous)** : `.xError`/`.wState` retirés — `EnableDiagnosis=False`
> sur les 3 devices dans le projet CODESYS actuel, ces propriétés ne sont pas un canal de
> diagnostic officiel. Retour aux littéraux TODO (sûr) en attendant activation.

---

## 🚀 16. Diagnostic EtherCAT/CAN — procédure d'activation officielle CODESYS (2026-07-03octies)

**Constat** : `.xError`/`.wState` utilisés en D46 ne sont **pas garantis** — vérifié dans
`Device.export`, `EnableDiagnosis = False` sur `COD1_CODEUR`, `COD2_CODEUR`, `AC600_ECAT_Drive`
et les devices CAN (`JOY1_JOYSTICK_MCB560_CO4201A`, `CANbus`, `CANopen_Manager`). Sans ce
diagnostic activé, on ne sait pas si ces propriétés existent/sont fiables — confirmé par
l'utilisateur (« je ne sais pas si c'est autorisé »). Décision : **ne pas approximer** — retour
aux littéraux TODO le temps que l'utilisateur active le vrai canal de diagnostic CODESYS.

**Pourquoi ce n'est probablement PAS un hasard** : chaque device a un `FbNameDiag` déclaré dans
son XML (`ETCSlave_Diag` pour les 3 esclaves EtherCAT, `CANRemoteDevice_Diag` pour le joystick,
`CANbus_Diag`/`CANOpenManager_Diag` pour le bus CAN) — c'est le nom du FB de diagnostic que
CODESYS instancie automatiquement dès que `EnableDiagnosis` passe à `True`. Les noms d'entrée
`WcState`/`SlaveState` de `FB_DiagEthercat` (existant, non modifié) collent exactement à la
terminologie standard de ce canal — cohérent avec l'intention d'origine du FB.

### 📋 Procédure (à faire par l'utilisateur dans CODESYS, PAS applicable via `CODE/*.st`)
1. Dans l'arbre du projet, clic droit sur `COD1_CODEUR` → **Propriétés** (ou double-clic → onglet
   général du device).
2. Chercher la case **« Enable Diagnosis »** / **« Diagnostic »** (parfois sous « Expert Process
   Data » ou un onglet dédié selon la version d'IoDrvEtherCAT) → cocher.
3. Un objet de diagnostic (`COD1_CODEUR_Diag` ou similaire) apparaît dans l'arbre sous le device,
   ou de nouveaux canaux apparaissent dans l'onglet **« I/O Mapping »** du device (ex. `WcState`,
   `State`) — **cocher « Create Variable »** dessus comme pour n'importe quel I/O de ce projet
   (même mécanisme que `PosFosse1`, `COD1_PosValue`, etc.).
4. Répéter pour `COD2_CODEUR`, `AC600_ECAT_Drive`, et le device CAN du joystick
   (`JOY1_JOYSTICK_MCB560_CO4201A` et/ou `CANbus`/`CANopen_Manager`).
5. Compiler → noter les noms EXACTS des variables créées (Input Assistant sur `COD1_CODEUR.` ou
   nom de la variable mappée) → **me les transmettre** pour finaliser le câblage `PRG_MAIN.st`
   §0 (remplacer les 8 littéraux TODO restants par les vrais canaux).

| # | Sujet | Décision |
|---|-------|----------|
| D49 | **Bouton homme-mort joystick (anti-calage)** | `RawButton` était capturé (`Button`) mais jamais exploité — aucun effet sur la commande (trouvé en répondant à la demande utilisateur). Nouveau comportement `FB_Joystick` : le geste doit être ARMÉ par appui bouton PENDANT que le manche est au neutre (`ScaleX/Y.OutPct=0.0`, comparaison exacte sûre — valeur clampée en dur dans `FB_AxisScale`, pas un calcul flottant). Relâcher le bouton en cours de mouvement ne désarme PAS (retour utilisateur : rappel mécanique du manche fait foi de présence). Le retour au neutre désarme (nouveau geste = nouvel appui requis). Empêche de caler le manche en déflexion sans être jamais passé par un appui au neutre. `DeadmanArmed` exposé en sortie. |
| D50 | **Retrait `.xError`/`.wState` non garantis (revient sur D46/D47)** | Confirmé `EnableDiagnosis=False` sur les 3 esclaves EtherCAT + devices CAN dans `Device.export` → retour aux littéraux TODO sûrs. Directive utilisateur : préférer une chaîne de sécurité RÉELLEMENT fonctionnelle (quitte à forcer/débloquer ponctuellement en CODESYS) plutôt qu'un stub qui la masque en permanence — procédure d'activation officielle documentée ci-dessus (§16) pour y arriver correctement, pas d'approximation sur des noms de propriété non confirmés. |

### Fichiers impactés (2026-07-03octies)
- **CODE/** : `PRG_MAIN.st` (retrait `.xError`/`.wState`, retour littéraux TODO §0),
  `FB_Joystick.st` (`DeadmanArmed`, `DeadmanEdge`, restructuration §4bis Scale avant homme-mort,
  gate `RampX`/`RampY`).
- **DOC/** : AUDIT (ce §16), `AF_Partie8_Fonction_Joystick` (à mettre à jour — bouton homme-mort).

---

## 🚀 17. Renforcement homme-mort + scission FB_IO_Machine (2026-07-03decies/nonies)

Review indépendante sur D49 : le mécanisme initial (armé au neutre, relâcher sans effet) ne
protège que le calage AVANT armement — un objet calé APRÈS un armement légitime n'est jamais
détecté (pas conforme EN 574/ISO 13850, présence continue exigée). Choix utilisateur : renforcer
plutôt qu'accepter le risque résiduel documenté.

| # | Sujet | Décision |
|---|-------|----------|
| D51 | **Reconfirmation périodique homme-mort** | Une fois armé et en mouvement, `FB_Joystick` exige un NOUVEL appui bouton (impulsion, pas un maintien continu) toutes les `DeadmanRearmTimeout` (défaut `T#3S`) — sans quoi désarmement automatique (décélération normale via `RampX/Y` gelée à 0, pas un arrêt brutal). Implémenté par un `TON` remis à zéro à chaque front bouton (pattern watchdog standard : `IN` chute une seule fois au cycle de l'appui). Défend contre le calage AVANT et APRÈS armement. |
| D52 | **Scission `FB_IO_Machine` → `FB_InputsMachine` + `FB_OutputsMachine`** | Demande utilisateur : plus clair d'avoir 2 FB distincts (entrées / sorties) que d'appeler 2× la même instance. Résultat : 1 instance de chaque, appelée UNE SEULE FOIS (entrées tôt, sorties tard) — élimine le besoin du double-appel. `FB_IO_Machine.st` supprimé. Note utilisateur : ces 2 FB seront implémentés en LANGAGE LD (Ladder) dans CODESYS pour la maintenance — le ST de `CODE/` reste la référence/spec, à retranscrire. |

### Fichiers impactés (2026-07-03decies/nonies)
- **CODE/** : `FB_Joystick.st` (`DeadmanRearmTimeout`, `DeadmanTimer`, §4quater), `FB_InputsMachine.st`
  (nouveau), `FB_OutputsMachine.st` (nouveau), `FB_IO_Machine.st` (supprimé), `PRG_MAIN.st`
  (`instInputsMachine`/`instOutputsMachine` remplacent `instIoMachine`).
- **DOC/** : `AF_Partie8_Fonction_Joystick` (état d'implémentation mis à jour), AUDIT (ce §17).

---

## 🚀 18. Corrections review + restructuration FB_Input_Digital (2026-07-03undecies)

Review indépendante sur D51/D52 (voir résultat complet dans la conversation) : verdict GO
conditionnel, code ST/câblage confirmés corrects, mais 2 points 🟠 remontés sur l'ergonomie
homme-mort (traité ici en D54) + demande utilisateur simultanée de renommer/restructurer
`FB_Input_Digital`/`FB_InputsMachine`.

| # | Sujet | Décision |
|---|-------|----------|
| D53 | **`FB_Input_Digital.OutputClean` → `State`** | Renommage demandé par l'utilisateur (modifié directement dans son CODESYS) — répercuté dans `CODE/FB_Input_Digital.st` et tous ses consommateurs (`FB_InputsMachine.st`, 13 instances). |
| D54 | **`FB_InputsMachine` référence directement les I/O réels (plus de `*Raw`/`Invert*` depuis `PRG_MAIN`)** | Demande utilisateur : simplifier `PRG_MAIN` (appel `instInputsMachine()` sans paramètre) — `FB_InputsMachine` devient un FB SPÉCIFIQUE machine (référence directement `EmergencyStopOk`, `M1_ContactorFeedbackFwd`, `PosFosse1`, etc. en interne), pas une brique générique réutilisable. `InvertLogic`/`ChannelOk` de chaque sous-instance restent à leur défaut (FALSE/TRUE), forçables directement en vue instance CODESYS (`instInputsMachine.instXxx.InvertLogic`) pour inverser NO/NC en mise en service sans recompiler. `FB_OutputsMachine` INCHANGÉ (les commandes `*Cmd` proviennent d'instances FB_Winch/FB_Chariot locales à `PRG_MAIN`, pas de variable globale à référencer directement). |
| D55 | **Bug watchdog homme-mort corrigé (review D51)** | Le renforcement D51 ne détectait qu'un FRONT bouton (`DeadmanEdge.Q`) — un opérateur qui MAINTIENT le bouton enfoncé en continu (réflexe naturel) ne génère plus de front après le 1er appui → désarmement surprise au bout de 3s malgré présence continue. Corrigé : condition sur `NOT RawButton` (niveau) au lieu de `NOT DeadmanEdge.Q` — maintenir OU réappuyer dans le délai remettent tous les deux le timer à zéro, seul un relâchement prolongé désarme. |

### Fichiers impactés (2026-07-03undecies)
- **CODE/** : `FB_Input_Digital.st` (`State`), `FB_InputsMachine.st` (restructuré, référence I/O
  directe), `FB_Joystick.st` (fix watchdog `NOT RawButton`), `PRG_MAIN.st` (`instInputsMachine()`
  sans paramètre).
- **DOC/** : `AF_Partie6_IO_Conditioning` (état d'implémentation), AUDIT (ce §18).

---

## 🚀 19. Tranchage des 2 points ouverts homme-mort (2026-07-03duodecies)

| # | Sujet | Décision |
|---|-------|----------|
| D56 | **`DeadmanRearmTimeout` : 3s → 10s** | Décision utilisateur : 3s imposait ~20 réappuis/minute sur un mouvement de treuil pouvant durer longtemps — jugé trop contraignant. Porté à `T#10S` (adjustable). |
| D57 | **Neutre TENU (`NeutralHoldTime`, 500ms) au lieu de simple traversée** | Décision utilisateur : ne pas désarmer sur une simple inversion de sens (Fwd↔Rev) qui traverse rapidement le neutre. Nouveau `NeutralHoldTimer` (`TON`, `IN := DeadmanArmed AND AuNeutre`) : le neutre doit être tenu en continu `NeutralHoldTime` avant de désarmer — une traversée rapide (quelques dizaines de ms) ne déclenche jamais le timer jusqu'à son terme. `IN` conditionné par `DeadmanArmed` : n'accumule pas au repos (désarmé), évite un désarmement immédiat juste après un armement suivi d'une hésitation. |

### Fichiers impactés (2026-07-03duodecies)
- **CODE/** : `FB_Joystick.st` (`DeadmanRearmTimeout:=T#10S`, nouveau `NeutralHoldTime`/`NeutralHoldTimer`).
- **DOC/** : `AF_Partie8_Fonction_Joystick` (état d'implémentation), AUDIT (ce §19).

---

## 🚀 20. Correctif review finale — LeftNeutralSinceArm + honnêteté doc timing (2026-07-03terdecies)

Review indépendante sur D56/D57 : GO conditionnel, mais 1 point 🟠 réel trouvé (le filtre neutre
pouvait désarmer AVANT le début du mouvement) + 1 point de documentation trop optimiste.

| # | Sujet | Décision |
|---|-------|----------|
| D58 | **`LeftNeutralSinceArm` — corrige un désarmement prématuré** | `NeutralHoldTimer` comptait dès l'armement si l'opérateur restait au neutre (hésitation avant de bouger) — désarmait après 500ms même sans avoir commencé à bouger, contredisant l'intention D57. Nouveau booléen `LeftNeutralSinceArm` : ne devient `TRUE` qu'après un vrai départ du neutre ; le filtre neutre-tenu ne s'applique qu'ensuite (retour au neutre PENDANT un mouvement établi — le cas réellement visé). |
| D59 | **Doc corrigée : `NeutralHoldTime=500ms` est une hypothèse, pas une garantie** | `ScaleX/Y.OutPct` (utilisé par la logique homme-mort) n'est pas filtré/rampé — le temps passé dans la deadband lors d'une inversion dépend uniquement de la vitesse physique de la main opérateur. Documenté comme point à valider empiriquement sur matériel réel avant essai avec mouvement, pas affirmé comme un fait garanti par le code. |

### Fichiers impactés (2026-07-03terdecies)
- **CODE/** : `FB_Joystick.st` (`LeftNeutralSinceArm`, reset GATE, commentaires corrigés).
- **DOC/** : AUDIT (ce §20).

---

## 🚀 21. Renommage I/O réel `_DI`/`_DQ`/`_RQ` + retours frein réels (2026-07-03quattuordecies)

Nouvel export utilisateur : toutes les variables I/O réel renommées côté device avec suffixe
`_DI` (entrée digitale), `_DQ` (sortie digitale), `_RQ` (sortie relais) — pour les retrouver
facilement dans l'assistant de saisie CODESYS. Bonus : les retours frein M1/M2/M3, encore en
miroir logiciel STUB jusqu'ici, sont désormais réellement câblés.

| # | Sujet | Décision |
|---|-------|----------|
| D60 | **Renommage systématique `_DI`/`_DQ`/`_RQ`** | Toutes les variables I/O réel utilisées dans `PRG_MAIN`/`FB_InputsMachine`/`FB_OutputsMachine` renommées (ex. `EmergencyStopOk`→`EmergencyStopOk_DI`, `M1_SpeedContactor_1`→`M1_SpeedContactor_1_DQ`, `M1_BrakeCmd`→`M1_BrakeCmd_RQ`). Répercuté dans `FB_InputsMachine.st` (référence directe interne) et dans les affectations de sortie de `PRG_MAIN.st`. |
| D61 | **Retours frein M1/M2/M3 réels (`*_BrakeContactorFeedback_DI`)** | Ferme un point ouvert du Lot A mise en service. Remplace les miroirs logiciels `GVL_Winch_M1_Stub`/`GVL_Winch_M2_Stub` (fichiers supprimés, devenus vides) et `M3_BrakeFeedback` de `GVL_Chariot_M3_Stub` (variable retirée, reste du stub Chariot inchangé — relais sens/PV-GV toujours pas de matériel réel). Conditionnés via 3 nouvelles instances `FB_Input_Digital` dans `FB_InputsMachine`. |
| D62 | **Signaux nouveaux non câblés (pas de consommateur)** | Le nouvel export ajoute `ConveyorInfeedReady_DI`, `GridDwn_RQ`/`GridUp_RQ`, `HelmetClose_RQ`/`HelmetOpen_RQ`, `PosCasque_DI`, `PosGrille_DI`, `ThermHydraulique_DI` — probablement pour un futur `FB_Grappin` (inexistant). Volontairement laissés non câblés (pas de logique inventée sans spec ni FB consommateur). |

### Fichiers impactés (2026-07-03quattuordecies)
- **CODE/** : `PRG_MAIN.st` (renommage §0/§7bis, retours frein réels), `FB_InputsMachine.st`
  (renommage interne + 3 nouvelles entrées BrakeFeedback), `GVL_Winch_M1_Stub.st`/
  `GVL_Winch_M2_Stub.st` (supprimés), `GVL_Chariot_M3_Stub.st` (`M3_BrakeFeedback` retiré).
- **DOC/** : AUDIT (ce §21).

---

## 🚀 22. `FB_Output_Relay.State` + `GVL_IN`/`GVL_OUT` (2026-07-03quindecies)

Demande utilisateur, en 2 temps : (1) `FB_OutputsMachine` devrait référencer les I/O réels
directement en interne comme `FB_InputsMachine`, et `FB_Output_Relay.OutputCmd` renommé
`State` (cohérence `FB_Input_Digital.State`) ; (2) finalement, les sorties conditionnées de
`FB_InputsMachine` ET les commandes brutes destinées à `FB_OutputsMachine` passent par des GVL
dédiées plutôt que des `VAR_OUTPUT`/`VAR_INPUT` d'instance — accès par tag global, plus naturel
en LD (1 rung = 1 bobine) qu'un appel de FB à 15 paramètres.

| # | Sujet | Décision |
|---|-------|----------|
| D63 | **`FB_Output_Relay.OutputCmd` → `State`** | Renommage demandé (cohérence avec `FB_Input_Digital.State`), répercuté dans `FB_OutputsMachine.st`. |
| D64 | **`GVL_IN` — sorties conditionnées de `FB_InputsMachine`** | `FB_InputsMachine` n'a plus de `VAR_OUTPUT` : il écrit directement `GVL_IN.Xxx` (noms COURTS, sans suffixe — `GVL_IN.EmergencyStopOk`, pas `EmergencyStopOkState`/`Cond`). Tous les consommateurs (`Homing`/`Safety_Winch`/`Winch`/`Safety_Chariot`/`Chariot`) lisent `GVL_IN.Xxx` directement. Les variables locales `*Cond` de `PRG_MAIN` supprimées. |
| D65 | **`GVL_OUT` — commandes brutes vers `FB_OutputsMachine`** | `FB_OutputsMachine` n'a plus ni `VAR_INPUT` ni `VAR_OUTPUT` : `PRG_MAIN` écrit `GVL_OUT.Xxx` par simples affectations juste après `FB_Winch`/`FB_Chariot` (naturel en LD), puis appelle `instOutputsMachine()` SANS PARAMÈTRE — le FB lit `GVL_OUT.Xxx` et écrit directement les I/O réels (`_DQ`/`_RQ`) en interne. |

⚠️ Écart assumé à Partie2 §0 ("quasi pas de GVL, sauf échange IHM") pour `GVL_IN`/
`GVL_OUT` — choix pragmatique utilisateur pour la lisibilité/maintenabilité en Ladder,
documenté explicitement dans chaque GVL, pas un oubli architectural.

### Fichiers impactés (2026-07-03quindecies)
- **CODE/** : `FB_Output_Relay.st` (`State`), `GVL_IN.st` (nouveau), `GVL_OUT.st`
  (nouveau), `FB_InputsMachine.st` (plus de `VAR_OUTPUT`, écrit `GVL_IN`),
  `FB_OutputsMachine.st` (plus de `VAR_INPUT`/`VAR_OUTPUT`, lit `GVL_OUT`/écrit I/O réels),
  `PRG_MAIN.st` (variables locales `*Cond` supprimées, câblage `GVL_IN`/`GVL_OUT`).

| D66 | **`PowerCutOff_RQ` réel — ferme D45** | Nouvel export : relais coupure puissance amont câblé en I/O Mapping. `GVL_Machine_Stub.PowerCutOffCmd` (stub) retiré, `PRG_MAIN.st` §8 écrit directement `PowerCutOff_RQ := instSafetyWinchM1.PowerCutOff OR instSafetyWinchM2.PowerCutOff OR instSafetyChariotM3.PowerCutOff;`. |
- **DOC/** : AUDIT (ce §22).

---

## 🚀 23. `CtrlPhaseRotation_DI` — contrôle rotation phases électriques (2026-07-03sexdecies)

Demande utilisateur : nouvelle entrée réelle prévue (`CtrlPhaseRotation_DI`, coquille "Pase"
corrigée) pour détecter un défaut de rotation de phase électrique — sens moteur potentiellement
inversé, danger machine entière. Pas de réponse utilisateur aux questions de clarification
(nom/polarité/portée) dans le délai — décision prise par cohérence avec le précédent déjà établi
(généralisation `EmergencyStopOk`, D34/D35), à confirmer/ajuster si besoin.

| # | Sujet | Décision |
|---|-------|----------|
| D67 | **`CtrlPhaseRotation_DI` → `GVL_IN.PhaseRotationOk`** | Nouvelle entrée conditionnée (`FB_Input`, `FilterTime T#20MS`) dans `FB_InputsMachine`, TRUE = rotation correcte. Gardée SÉPARÉE de `GVL_IN.EmergencyStopOk` (pas fusionnée) pour préserver le diagnostic de la cause réelle en cas de défaut. |
| D68 | ⚠️ **SUPERSEDÉ par D71 (§26)** — Portée : combinée en AND partout où `EmergencyStopOk` est câblé | ~~Les 15 sites d'appel reçoivent `EmergencyStopOk := (GVL_IN.EmergencyStopOk AND GVL_IN.PhaseRotationOk)`~~ — revu suite retour utilisateur : la safety doit centraliser les capteurs, pas le métier. Voir D71. |

⚠️ **À CONFIRMER PAR L'UTILISATEUR** avant mise en service : (1) nom exact du tag (`CtrlPhaseRotation_DI` vs autre orthographe déjà créée côté device), (2) polarité (TRUE=OK assumé).

### Fichiers impactés (2026-07-03sexdecies)
- **CODE/** : `FB_InputsMachine.st` (nouvelle instance `instCtrlPhaseRotation`), `GVL_IN.st`
  (`PhaseRotationOk`), `PRG_MAIN.st` (15 sites `EmergencyStopOk :=` combinés en AND).
- **DOC/** : AUDIT (ce §23).

---

## 🚀 24. `SafeStop` retiré de `FB_Joystick` — vestige nettoyé (2026-07-03septdecies)

L'utilisateur a demandé de vérifier si `SafeStop` était toujours utilisé sur `FB_Joystick`.
Vérification (grep `SafeStop` sur `CODE/*.st`) : bien utilisé et correctement câblé sur
`FB_Winch`/`FB_Chariot` (les 2 vrais FB de mouvement) via `FB_Safety_Winch`/`FB_Safety_Chariot`
→ arbitrage rampe rapide/normale. En revanche `FB_Joystick` portait encore une entrée `SafeStop`
câblée sur un stub `GVL_DEBUG.DBG_False` — non conforme Partie3 §1bis/Partie8 §3 (pas un FB de
mouvement), documenté comme tel depuis la doc Partie8 v1.1 mais jamais nettoyé côté code
(§6bis de la doc listait déjà cet écart).

| # | Sujet | Décision |
|---|-------|----------|
| D69 | **`SafeStop` retiré de `FB_Joystick`** | Entrée `VAR_INPUT SafeStop` supprimée, GATE simplifié (`IF NOT Enable OR NOT EmergencyStopOk OR ...`, plus de `SafeStop OR`). `PRG_MAIN.st` : câblage `SafeStop := GVL_DEBUG.DBG_False,` retiré de l'appel `FB_Joystick_0(...)`. Le vestige agissait comme un second `Enable` (coupure immédiate dans le GATE) plutôt qu'une rampe rapide — exactement la confusion que la règle Partie3 §1bis vise à éviter. |

### Fichiers impactés (2026-07-03septdecies)
- **CODE/** : `FB_Joystick.st` (`SafeStop` retiré : VAR_INPUT + GATE), `PRG_MAIN.st` (câblage retiré).
- **DOC/** : `AF_Partie8_Fonction_Joystick_v1.2.md` (§6bis points 1/2 fermés, retex §8 coché),
  AUDIT (ce §24).

---

## 🚀 25. Bypass test banc homme-mort `FB_Joystick` (2026-07-03octodecies)

Demande utilisateur : le comportement homme-mort (§4ter/§4quater `FB_Joystick.st`) pose des
problèmes en essai, pas le temps de déboguer dans l'immédiat. Besoin urgent : pouvoir bouger le
joystick sans maintenir/réappuyer le bouton en permanence, pour continuer les essais en cours.
Hésitation exprimée sur le niveau exact (N1 vs N2 IHM) — pas d'arrêt tranché, traité comme un
bypass générique TEMPORAIRE (même famille que `DBG_EmergencyStopOkBypass_TEST`/
`DBG_TopPositionSensorBypass_TEST`), pas une vraie règle de mode.

| # | Sujet | Décision |
|---|-------|----------|
| D70 | **`GVL_DEBUG.DBG_DeadmanBypass_TEST`** | Nouveau bypass bench : force `DeadmanArmed := TRUE` en permanence, appliqué en dernier (après §4quater, avant que `RampX`/`RampY` ne consomment `DeadmanArmed`). ⚠️ TOUJOURS FALSE en exploitation réelle. **Portée volontairement large** (pas de restriction par Mode) — l'utilisateur a évoqué N1/N2 sans trancher ; à restreindre par `Mode` (probablement `MAINT_N1` seul) dans une prochaine itération, une fois l'arbitrage IHM précisé. |

⚠️ **Point ouvert non résolu** : le bug/comportement gênant de l'homme-mort lui-même n'a PAS été
diagnostiqué ni corrigé — seul un moyen de le contourner temporairement a été ajouté. Reprendre le
débogage du comportement réel dès que le temps le permet (candidats probables : interaction
`NeutralHoldTime`/`LeftNeutralSinceArm` avec le ressort fort du manche, ou timing `ScaleX/Y.OutPct`
non filtré évoqué en D57/D58 — voir §20/§21 de cet AUDIT).

### Fichiers impactés (2026-07-03octodecies)
- **CODE/** : `GVL_DEBUG.st` (`DBG_DeadmanBypass_TEST`), `FB_Joystick.st` (bypass appliqué en
  §4quater).
- **DOC/** : AUDIT (ce §25).

---

## 🚀 26. `PhaseRotationOk` déplacé vers les blocs Safety métier (2026-07-03novodecies)

Retour utilisateur sur D68 (§23) : le AND généralisé de `PhaseRotationOk` dans `EmergencyStopOk`
sur les 15 sites d'appel (`instModes`, Homing, `instWinchSync`, etc.) ne correspond pas à
l'architecture voulue. Principe rappelé par l'utilisateur : **les blocs Safety centralisent les
capteurs et arbitrent selon le mode ; ce sont leurs SORTIES (`SafeStop`/`ForbidDescent`) qui
attaquent les blocs métier** — pas les capteurs bruts injectés partout. Exactement le pattern déjà
en place pour `ThermalFeedback`/`SlackCableDetected` dans `FB_Safety_Winch`.

| # | Sujet | Décision |
|---|-------|----------|
| D71 | **`PhaseRotationOk` intégré à `FB_Safety_Winch`/`FB_Safety_Chariot`** | D68 annulé. Nouvelle entrée `PhaseRotationOk` sur les deux FB Safety métier. `FB_Safety_Winch` : bit4 ErrorId (`NOT PhaseRotationOk`), participe au `SafeStop` total (bits 0/1/2/4, masque `16#0017`) — mou de câble (bit3) reste exclu, comme avant. `FB_Safety_Chariot` : bit2 ErrorId (bit1 réservé EtherCAT variateur), `SafeStop := Error` inchangé (couvre tous les bits). `PRG_MAIN.st` : les 15 `EmergencyStopOk :=` REVERTÉS à `GVL_IN.EmergencyStopOk` seul ; `PhaseRotationOk := GVL_IN.PhaseRotationOk` ajouté UNIQUEMENT sur `instSafetyWinchM1/M2`/`instSafetyChariotM3`. |

### Fichiers impactés (2026-07-03novodecies)
- **CODE/** : `FB_Safety_Winch.st` (`PhaseRotationOk`, bit4, `SafeStop` masque `16#0017`),
  `FB_Safety_Chariot.st` (`PhaseRotationOk`, bit2), `PRG_MAIN.st` (revert AND généralisé,
  câblage restreint aux 3 blocs Safety).

---

## 🚀 27. Mou de câble intégré au SafeStop (inhibé en montée) + polarité `SlackCableSwitch` (2026-07-03vicies)

Demande utilisateur, en 2 temps : (1) `SlackCableSwitch` est câblé en logique SÉCURITÉ (contact
NF/energized-to-run) — `TRUE` = PAS de mou de câble (état sûr), pas `TRUE` = mou détecté comme
supposé précédemment. (2) Le mou de câble doit désormais déclencher une vraie décélération rapide
(comme un `SafeStop`), mais cette décélération doit être INHIBÉE quand on remonte/enroule le
câble (l'opérateur doit pouvoir librement reprendre le mou en remontant).

| # | Sujet | Décision |
|---|-------|----------|
| D72a | **Polarité `SlackCableSwitch` corrigée** | `PRG_MAIN.st` : `SlackCableDetected := NOT GVL_IN.SlackCableSwitch` (les 2 instances `instSafetyWinchM1/M2`) — était câblé sans inversion (bug de polarité, jamais détecté un vrai mou de câble tant que le contact NF reste fermé par défaut). |
| D72b | **`ForbidDescent` intègre une vraie décélération, inhibée en montée** | `FB_Winch.st` : nouvelle variable interne `EffectiveSafeStop := SafeStop OR (ForbidDescent AND (CommandedDirection <> 1))`, utilisée à la place de `SafeStop` brut pour l'arbitrage rampe (cible, `DecelRate`, état `STOPPING`). Le masquage direct `RelayRev := FALSE` sur `ForbidDescent` reste EN PLUS, inconditionnel (filet de sécurité indépendant de la rampe). `FB_Safety_Winch` inchangé : `ForbidDescent` reste bit3, exclu du `SafeStop` qu'il produit lui-même — la logique direction-dépendante est appliquée côté `FB_Winch` (seul FB qui connaît `CommandedDirection`), pas côté Safety (qui ne doit pas connaître le sens de mouvement). |

### Fichiers impactés (2026-07-03vicies, partie 1/2)
- **CODE/** : `PRG_MAIN.st` (polarité `SlackCableDetected`), `FB_Winch.st` (`EffectiveSafeStop`).
- **DOC/** : AUDIT (ce §27).

---

## 🚀 28. Bypass test banc — contrôle contacteur `FB_Winch`/`FB_Chariot` (2026-07-03vicies)

Demande utilisateur : sans contacteurs réels câblés/cohérents en essai, le contrôle
`StuckClosed`/`StuckOpen` (incohérence commande/retour > `ContactorFeedbackTimeout`) se déclenche
à tort et bloque `RelayFwd`/`RelayRev` (via `Error` → coupure forcée en fin de FB). Précision
complémentaire de l'utilisateur : pour le thermique/mou de câble/rotation de phase (simples
variables `GVL_IN`), pas besoin de flag dédié — un **Force** CODESYS direct sur la variable
suffit (le Force prend le dessus sur l'écriture cyclique du programme).

| # | Sujet | Décision |
|---|-------|----------|
| D73 | **`GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST`** | Nouveau bypass bench, même famille que les précédents. `FB_Winch.st`/`FB_Chariot.st` : les blocs `IF FwdContactorCheck.StuckClosed OR ... THEN ErrorId := ErrorId OR 16#0002` (bit1) et bit2 (Rev) sont gardés par `IF NOT GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST THEN ... ELSE ErrorId := ErrorId AND 16#FFF9; END_IF` — bypass actif = bits 1/2 forcés à 0, pas de blocage. ⚠️ TOUJOURS FALSE en exploitation réelle. |

### Fichiers impactés (2026-07-03vicies, partie 2/2)
- **CODE/** : `GVL_DEBUG.st` (`DBG_ContactorFeedbackBypass_TEST`), `FB_Winch.st`/`FB_Chariot.st`
  (bypass appliqué autour des blocs StuckClosed/StuckOpen).
- **DOC/** : AUDIT (ce §28).
- **DOC/** : AUDIT (ce §26).
