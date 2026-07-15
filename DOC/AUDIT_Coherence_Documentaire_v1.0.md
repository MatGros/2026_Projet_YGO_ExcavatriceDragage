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
| D15 | **Arrêt = `StartStop := FALSE` (Q9)** | L'arrêt d'un mouvement se fait par **`StartStop := FALSE`** (décélération normale), **pas** par retrait d'`Enable`. ⚠️ `AF_Partie-04` §0 (« passage à une étape sans mouvement = retrait `Enable` → rampe ») est **à réécrire**. |
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
| B1 | `AF_Partie-08` §3/§4/§5/§7 ; `CODE/PRG_JOY1.st:20` | `SafeStop` traité comme **entrée-commande qui force les sorties à 0** | ✅ Recadré par **D1** : `SafeStop` = **sortie** safety (info arrêt sûr), pas une entrée qui zérote. Le FB Joystick réagit via **retrait d'`Enable`**. |
| B2 | `AF_Partie-08` §7 | `SafetyOk := NOT SafeStop AND EStopOk` → réintroduit **`EStopOk`** (censé absorbé par `SafetyOk`, P3 §1) | ✅ **D18** : `SafetyOk` **renommé `EmergencyStopOk`** (chaîne AU / contacteur puissance, source à définir). `EStopOk` disparaît. |
| B3 | `NAMING_CONVENTION.md:35` | `SafeStop` listé en « entrée de commande » | 🛠️ À reclasser : `SafeStop` = **sortie** safety (D1), pas entrée de commande. |

### 🟠 Sévérité MAJEURE

| Réf | Localisation | Constat | Statut |
|-----|--------------|---------|--------|
| M1 | `AF_Partie-05` §2 vs §3 | Le pseudo-code override met la limite légale dans `FB_Safety.CheckLimitLegal`, alors que §3 dit « **pas `FB_Safety`**, c'est `FB_Modes` » | ✅ **D5** : limite légale = `FB_Modes`. Corriger le pseudo-code §2. |
| M2 | `AF_Partie-06` §5 (`:163`) vs `AF_Partie-04` §7 / `AF_Partie-05` §5 | `Command := ordre AND NOT CoupeEnable` sur la sortie relais = **coupure sèche**, contredit la « rampe non destructive » | ✅ **D2+D4** : pas de `CoupeEnable` ; arrêt = **rampe sur relais vitesse/sens**, pas coupure de sortie. Reformuler §5. |
| M3 | `AF_Partie-04` §3 vs §6 | `FB_WinchSync` (`ΔPos>SyncStop`→arrêt) vs désynchro **volontaire** M2 pour le godet → risque de faux défaut synchro | ✅ **D6** : phase godet = pas de mouvement M1 → **sync suspendue**. Documenter l'interlock. |
| M4 | `AF_Partie-02` §2/§9 vs `AF_Partie-08` §7 | Traitement joystick en `CanTask` (20 ms) **ou** `MainTask` (10 ms) ? Ambigu | ✅ **D7** : comm 20 ms, **traitement 10 ms** (MainTask). |
| M5 | `AF_Partie-02` §0 vs `AF_Partie-05` §1, `AF_Partie-06` §5, `AF_Partie-08` | Terminologie flottante : `PLC_PRG_MAIN` unique vs `PRG_MODES`/`PRG_IO`/`PRG_JOY1` séparés | ✅ **D8** : **1 POU main**, plus de `PRG_*`. Nettoyer le vocabulaire. |
| M6 | `AF_Partie-04` §0 | « passage à une étape sans mouvement = retrait `Enable` → arrêt sur rampe » | ✅ **D15** : arrêt = **`StartStop := FALSE`** (décélération normale), pas retrait d'`Enable`. Réécrire §0. |

### 🟡 Sévérité MINEURE

| Réf | Localisation | Constat | Statut |
|-----|--------------|---------|--------|
| m1 | `NAMING_CONVENTION.md:121` (`ST_WinchIO`) | `ErrorId : INT` | ✅ **D9** : `WORD`. |
| m2 | `AF_Partie-02` (_COMMON) / `CLAUDE.md` vs `AF_Partie-08` §2 / `CODE` / `README` | `FB_FilterPT1` vs `FB_Filter_PT1` (2 identifiants) | ✅ **D10** : `FB_FilterPT1`. |
| m3 | `AF_Partie-08` §2/§7 vs `AF_Partie-02` arborescence | `FB_AxisScale`, `FB_Ramp`, `FB_CycleTime` absents de l'architecture | ✅ **D11** (partiel) : préciser dans P2 (sous-composants de `FB_Joystick` / base de temps). |
| m4 | `.claude/skills/codesys-workflow.md:25` | Référence `AF_Partie-02_..._v2.3.md` (périmé, actif = v2.4) | 🛠️ À corriger (pointe vers version active). |
| m5 | `CODE/PRG_JOY1.st:13` | Lien vers `DOC/AF_Partie-04_Fonction_Joystick_v1.0.md` (renuméroté **Partie 8**) | 🛠️ Lien mort → Partie 8. |
| m6 | `README.md` (structure `CODE/`, workflow) | Décrit `CODE/*.xml` + `extract/inject` round-trip, alors que `CODE/` contient un `.st` et la skill impose la **copie manuelle `.st`** | ✅ **D19** : workflow XML **supprimé** ; export manuel `Device.export` + copie ST manuelle. Corriger README (structure `CODE/`, section « Workflow Édition », `extract.bat`/`inject.bat`, `tools/`). |
| m7 | `AF_Partie-03` (« **tout** FB respecte le contrat ») vs `AF_Partie-06` briques + `FB_Diag*` | Briques E/S & diag n'ont pas l'interface complète (`Enable/Reset/SafetyOk/Mode/State/StateAtError`) | ✅ **D12 + D20** : FB de mouvement = interface standard + `StartStop` ; briques E/S & diag = **types de données propres** (pas de `StartStop`). |
| m8 | `AF_Partie-02` §9 (ordre) vs §7 (schéma) | `FB_Watchdog()` appelé **après** `FB_Safety()` alors qu'il l'alimente (`ErrorId`) → 1 cycle de retard | ✅ **Sans objet (D21)** : `FB_Watchdog` supprimé (fonction système). Retirer toutes ses références. |
| m9 | `NAMING_CONVENTION.md` (ex. `E_Error`) vs `AF_Partie-03` §3 | Exemple d'enum `E_Error` alors que design = bitfield **sans mnémonique** | 🛠️ Harmoniser l'exemple. |
| m10 | `AF_Partie-01` §Initialisation | « preset codeurs à une valeur **positive** » puis « **Affichage 0 m** » au plan d'eau — logique correcte mais **non expliquée** (risque de lecture contradictoire) | 🛠️ Ajouter une phrase d'explication (offset brut vs échelle 0). |
| m11 | `Plan_Action` / `CLAUDE.md` (« Auto ») vs `AF_Partie-05` (`SEMI_AUTO`) | Vocabulaire « Auto » vs « semi-auto » | 🛠️ Harmoniser (« semi-auto »). |

---

## 🧱 4. Impact transverse de la décision D2 (suppression `CoupeEnable`)

`CoupeEnable` est **omniprésent** dans la v2.4 et les fichiers de tête. Sa suppression (D2)
impose une révision coordonnée (à faire lors d'une mise à jour de specs, hors du présent audit) :

- `AF_Partie-01` : §Interactions, §Sécurité (flux `Safety ──CoupeEnable──►`).
- `AF_Partie-02` : §0 (décision 4), §4, §5, §6 (titre + tableau), §7, §9.
- `AF_Partie-03` : §1 (note v2.4), §2, §7, §9.
- `AF_Partie-04` : §0, §1 (`E_CycleStep.ERROR_HOLD`, transitions), §7.
- `AF_Partie-05` : §1, §4, §5 (titre + flux).
- `AF_Partie-06` : §2 (note feedback), §5.
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
| Q6 | **Séquence `INIT`** (`AF_Partie-04` §2, marquée *TBD*) : à spécifier maintenant ou laisser ouverte ? | Bloc fonctionnel encore incomplet. **→ TBD (D22).** |
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

`DOC/NAMING_CONVENTION.md` · `DOC/AF_Partie-01_..._v1.1` · `DOC/AF_Partie-02_..._v2.4` ·
`DOC/AF_Partie-03_..._v1.1` · `DOC/AF_Partie-04_..._v1.0` · `DOC/AF_Partie-05_..._v1.0` ·
`DOC/AF_Partie-06_..._v1.0` · `DOC/AF_Partie-08_..._v1.0` · `CLAUDE.md` · `README.md` ·
`.claude/skills/codesys-workflow.md` · `CODE/PRG_JOY1.st` · `Plan_Action_Excavatrice_Detaillee.md`.

---

## 🚀 7. Implémentation des décisions (2026-07-01)

Toutes les décisions **D1→D21** (D22 = TBD assumé) ont été répercutées dans les specs. Les
anciennes versions ont été déplacées vers `ARCHIVES/Doc/` (gitignoré, non versionné) conformément
à la règle de versionnement stricte de la skill `codesys-workflow`.

| Fichier | Ancienne version | Nouvelle version | Changements clés |
|---------|-------------------|-------------------|-------------------|
| `DOC/NAMING_CONVENTION.md` | (sans version) | édité en place | `SafeStop` reclassé sortie safety métier, `StartStop` ajouté, `EmergencyStopOk` ajouté, `ErrorId` en `WORD`, exemple `E_Error` retiré |
| `AF_Partie-01_Analyse_Fonctionnelle` | v1.1 | **v1.2** | Suppression `CoupeEnable`, flux `SafeStop`/`StartStop`, explication init codeurs (m10) |
| `AF_Partie-02_Architecture_Programme` | v2.4 | **v2.5** | Suppression `CoupeEnable` et `FB_Watchdog` ; modèle `SafeStop` (par métier) / `StartStop` ; `EmergencyStopOk` ; interlock godet/synchro documenté ; composition pipeline joystick précisée (m3) |
| `AF_Partie-03_Template_FB_Commun` | v1.1 | **v1.2** | Nouveau §1bis (profils d'interface FB standard / mouvement / briques réduites) ; `EmergencyStopOk` ; précédence `Enable`>`SafeStop`>`StartStop` ; §7/§9 réécrits |
| `AF_Partie-04_Cycle_Sequenceur` | v1.0 | **v1.1** | §0 réécrit (`StartStop:=FALSE`, pas retrait Enable) ; nouveau §3bis (suspension `FB_WinchSync` en phase godet, M3) ; `ERROR_HOLD` déclenché par `SafeStop` |
| `AF_Partie-05_Modes_Maintenance` | v1.0 | **v1.1** | Pseudo-code §2 corrigé (limite légale hors `FB_Safety`, M1) ; §4/§5 réécrits (`SafeStop` par métier, watchdog système) |
| `AF_Partie-06_IO_Conditioning` | v1.0 | **v1.1** | §5 corrigé (pas de coupure sèche de sortie relais, M2) ; terminologie `PRG_IO` retirée (M5) |
| `AF_Partie-08_Fonction_Joystick` | v1.0 | **v1.1** | `SafeStop` retiré de l'interface (B1) ; `EStopOk`/`SafetyOk` → `EmergencyStopOk` (B2) ; lien mort corrigé (m5) ; `FB_FilterPT1` (m2) ; nouveau §6bis (écarts avec `CODE/PRG_JOY1.st` actuel) |
| `CLAUDE.md` | — | édité en place | Guardrails, arborescence, liens de version, cas d'arrêt mis à jour |
| `README.md` | — | édité en place | Workflow XML `extract/inject` remplacé par export/copie manuelle (D19, m6) ; liens de version |
| `.claude/skills/codesys-workflow.md` | — | édité en place | Référence v2.3→v2.5 corrigée (m4) ; exemple `SafeStop`/`EmergencyStopOk` mis à jour |
| `Plan_Action_Excavatrice_Detaillee.md` | — | édité en place | `FB_Safety_<Metier>`, limite légale déplacée sous `FB_Modes`, `FB_Watchdog` retiré, « Auto » → « Semi-auto » (m11) |

### ⚠️ Hors périmètre (non modifié)
- **`CODE/PRG_JOY1.st`** : non touché — reste **hors périmètre** d'un audit documentaire (le code
  CODESYS s'édite via le workflow `codesys-workflow` avec validation utilisateur explicite). Les
  écarts entre ce fichier et la Partie 8 v1.1 sont listés dans `AF_Partie-08_..._v1.1.md` §6bis
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
  `NAMING_CONVENTION.md`/`CLAUDE.md` édités en place. Anciennes versions → `ARCHIVES/Doc/`.

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
- **DOC/** : `AF_Partie-06_IO_Conditioning` (état d'implémentation — `FB_Input_Digital` intégré pour
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
- **DOC/** : `AF_Partie-06_IO_Conditioning` (état d'implémentation mis à jour), AUDIT (ce §11).

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
- **DOC/** : `AF_Partie-05_Modes_Maintenance` (état d'implémentation `FB_Modes` MVP),
  `AF_Partie-09_Fonction_Winch` (§9 `FB_WinchSync` squelette), `AF_Partie-10...` (§3.6/§3.7
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
- **DOC/** : `AF_Partie-09_Fonction_Winch` (REX §8), AUDIT (ce §13).

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
- **DOC/** : AUDIT (ce §16), `AF_Partie-08_Fonction_Joystick` (à mettre à jour — bouton homme-mort).

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
- **DOC/** : `AF_Partie-08_Fonction_Joystick` (état d'implémentation mis à jour), AUDIT (ce §17).

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
- **DOC/** : `AF_Partie-06_IO_Conditioning` (état d'implémentation), AUDIT (ce §18).

---

## 🚀 19. Tranchage des 2 points ouverts homme-mort (2026-07-03duodecies)

| # | Sujet | Décision |
|---|-------|----------|
| D56 | **`DeadmanRearmTimeout` : 3s → 10s** | Décision utilisateur : 3s imposait ~20 réappuis/minute sur un mouvement de treuil pouvant durer longtemps — jugé trop contraignant. Porté à `T#10S` (adjustable). |
| D57 | **Neutre TENU (`NeutralHoldTime`, 500ms) au lieu de simple traversée** | Décision utilisateur : ne pas désarmer sur une simple inversion de sens (Fwd↔Rev) qui traverse rapidement le neutre. Nouveau `NeutralHoldTimer` (`TON`, `IN := DeadmanArmed AND AuNeutre`) : le neutre doit être tenu en continu `NeutralHoldTime` avant de désarmer — une traversée rapide (quelques dizaines de ms) ne déclenche jamais le timer jusqu'à son terme. `IN` conditionné par `DeadmanArmed` : n'accumule pas au repos (désarmé), évite un désarmement immédiat juste après un armement suivi d'une hésitation. |

### Fichiers impactés (2026-07-03duodecies)
- **CODE/** : `FB_Joystick.st` (`DeadmanRearmTimeout:=T#10S`, nouveau `NeutralHoldTime`/`NeutralHoldTimer`).
- **DOC/** : `AF_Partie-08_Fonction_Joystick` (état d'implémentation), AUDIT (ce §19).

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
- **DOC/** : `AF_Partie-08_Fonction_Joystick_v1.2.md` (§6bis points 1/2 fermés, retex §8 coché),
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

---

## 🚀 29. `GVL_IN.PhaseRotationOk` initialisé à TRUE — SafeStop bloqué à tort (2026-07-03unvicies)

Diagnostic en direct avec l'utilisateur (`instWinchM1.SafeStop=TRUE`, `ForbidDescent=FALSE`,
rampe/relais totalement bloqués malgré `StartStop`/`SpeedRefPct` corrects) : `FB_Safety_Winch`
bit4 (`PhaseRotationOk`) levé en permanence, car `GVL_IN.PhaseRotationOk` n'a jamais été
initialisé — un `BOOL` non initialisé démarre à `FALSE` (IEC 61131-3), et tant que
`CtrlPhaseRotation_DI` n'existe pas en I/O Mapping, `FB_InputsMachine` n'écrit jamais cette
variable. Résultat : `SafeStop` bloqué à `TRUE` en permanence sur M1/M2/Chariot sans aucun vrai
défaut. Principe rappelé par l'utilisateur : **toute information de sécurité doit démarrer à
l'état OK/nominal tant qu'elle n'est pas réellement câblée** (même logique que la polarité
`SlackCableSwitch`, D72a).

| # | Sujet | Décision |
|---|-------|----------|
| D74 | **`GVL_IN.PhaseRotationOk : BOOL := TRUE`** | Initialisation ajoutée dans `GVL_IN.st`. Si `instCtrlPhaseRotation` (FB_InputsMachine) n'est pas encore appliqué/câblé chez l'utilisateur, la variable reste à `TRUE` (OK) au lieu de `FALSE` (défaut) — ne bloque plus `SafeStop`. Dès que le vrai DI sera câblé et que `FB_InputsMachine` écrira réellement cette variable chaque cycle, l'init n'a plus d'effet (écrasée par la vraie valeur). |

⚠️ Nuance importante : cette init ne protège que le cas « variable jamais écrite ». Si
`CtrlPhaseRotation_DI` existe déjà et que `FB_InputsMachine` l'écrit réellement, une vraie
mauvaise rotation de phase désarmera bien `SafeStop` normalement (l'init ne masque pas un vrai
défaut, seulement l'absence de câblage).

### Fichiers impactés (2026-07-03unvicies)
- **CODE/** : `GVL_IN.st` (init `PhaseRotationOk := TRUE`), `PRG_MAIN.st` (note header).
- **DOC/** : AUDIT (ce §29).

---

## 🚀 30. Bypass dédiés `PhaseRotationOk`/`SlackCableSwitch` créés par l'utilisateur (2026-07-03duovicies)

L'utilisateur avait déjà créé lui-même 2 bypass dans son `GVL_DEBUG` réel avant même que je
propose l'init `:= TRUE` (D74) : `DBG_CtrlPhaseRotation_Bypass_TEST` et
`DBG_SlackCableSwitch_TEST`. Préférence exprimée : garder le pattern OR-bypass uniforme
(`EmergencyStopOk`/`TopPositionSensor`/`CtrlPhaseRotation`/`SlackCableSwitch`, tous OR'és sur le
signal brut dans `FB_InputsMachine`) plutôt qu'une init `:= TRUE` isolée sur une seule variable.

| # | Sujet | Décision |
|---|-------|----------|
| D75 | **`GVL_IN.PhaseRotationOk := TRUE` retiré** | D74 annulé/superседé. Retour à `PhaseRotationOk : BOOL;` simple (pas d'init), cohérent avec `EmergencyStopOk`/`TopPositionSensor` (aucun des deux n'a d'init `GVL_IN` non plus). |
| D76 | **2 bypass utilisateur intégrés au code de référence** | `GVL_DEBUG.DBG_CtrlPhaseRotation_Bypass_TEST` et `DBG_SlackCableSwitch_TEST` ajoutés à `GVL_DEBUG.st`, câblés en OR sur le signal brut dans `FB_InputsMachine.st` (`CtrlPhaseRotation_DI OR ...`, `M1_M2_SlackCableSwitch_DI OR ...`) — même pattern que les bypass existants. |

⚠️ **Note observée** (pas une action requise, juste un rappel) : dans le `GVL_DEBUG` réel de
l'utilisateur au moment de cet échange, **tous les bypass sont à `TRUE`** (banc de test complet :
homme-mort, contrôle contacteur, mou de câble, rotation de phase, AU, capteur position haute) —
cohérent avec une phase d'essai sans aucun capteur/contacteur réel câblé. Rappel déjà documenté
partout : TOUS remettre à `FALSE` avant tout essai avec un risque réel (charge, mouvement motorisé).

### Fichiers impactés (2026-07-03duovicies)
- **CODE/** : `GVL_IN.st` (retrait init), `GVL_DEBUG.st` (2 nouveaux bypass), `FB_InputsMachine.st`
  (câblage OR sur `SlackCableSwitch`/`CtrlPhaseRotation`), `PRG_MAIN.st` (note header).
- **DOC/** : AUDIT (ce §30).

---

## 🚀 31. Incident diagnostic — `instWinchM1.SafeStop` forcé manuellement à TRUE (2026-07-03duovicies)

Séance de mise en service en direct : mouvement M1 totalement bloqué (`RampTargetPct`/
`SpeedRamp.Current` restaient à 0 malgré `StartStop`/`SpeedRefPct` corrects). Diagnostic pas à pas
(`EffectiveSafeStop`→`SafeStop`→`ForbidDescent`→câblage `PRG_MAIN.st` vérifié ligne par ligne,
identique à la référence) a fini par révéler la cause : `instSafetyWinchM1.SafeStop` calculait bien
`FALSE` (`ErrorId=0`, aucun défaut), mais **l'utilisateur avait lui-même forcé manuellement
`instWinchM1.SafeStop` à `TRUE`** dans CODESYS, croyant — par analogie avec la convention
"capteur de sécurité = TRUE=OK" établie plus tôt dans la session (D72a/D74/§27/§29) — qu'un
"organe de sécurité" devait rester à `1` en permanence.

**Cause racine de la confusion** : `SafeStop` n'est PAS un capteur de sécurité (convention
TRUE=OK) mais une **sortie de commande calculée** par `FB_Safety_Winch` — convention inverse,
`TRUE` = déclenche activement la décélération rapide. Les deux familles ont des polarités
opposées et portent toutes les deux le mot "sécurité" dans leur contexte, d'où la confusion.

| # | Sujet | Décision |
|---|-------|----------|
| D77 | **Convention à 3 familles documentée** | `NAMING_CONVENTION.md` §"Polarité des booléens I/O" étendue : capteur sécurité (TRUE=OK) / information classique (FALSE=repos) / **sortie de commande Safety** (TRUE=déclenche — `SafeStop`/`ForbidDescent`/`PowerCutOff`), avec règle explicite : ne jamais forcer manuellement une sortie de commande, seulement bypasser l'entrée capteur en amont. |

**Résolution** : Force retiré par l'utilisateur sur `instWinchM1.SafeStop`, raccordement normal
rétabli (`SafeStop := instSafetyWinchM1.SafeStop`, déjà correct dans le code — aucune modification
de fichier `.st` nécessaire, uniquement une action côté CODESYS runtime).

### Fichiers impactés (2026-07-03duovicies, partie 2)
- **DOC/** : `NAMING_CONVENTION.md` (3ᵉ famille + avertissement forçage), AUDIT (ce §31).
- **CODE/** : aucun — le bug n'était pas dans le code, uniquement un Force runtime côté utilisateur.

---

## 🚀 32. Prise en compte du bypass contacteur dans le retour frein FB_Brake (2026-07-03trivicies)

**Contexte** : Sur banc de test, bien que `DBG_ContactorFeedbackBypass_TEST` soit à TRUE pour contourner les contrôles contacteurs de direction dans `FB_Winch`, `FB_Brake` n'intégrait pas ce bypass. Faute de retour frein physique, `FB_Brake` levait un défaut (ErrorId=1) après 1.4s, verrouillant les sorties relais.

| # | Sujet | Décision |
|---|-------|----------|
| D78 | **Bypass diagnostic frein dans `FB_Brake`** | `FB_Brake.st` intègre désormais la vérification de `GVL_DEBUG.DBG_ContactorFeedbackBypass_TEST` dans son diagnostic de retour. Si actif, le défaut de retour de frein (bit 0) est forcé à 0 et les erreurs de collage/non-collage sont effacées, évitant le verrouillage des sorties treuil/chariot sur banc. |

### Fichiers impactés (2026-07-03trivicies)
- **CODE/** : `FB_Brake.st` (intégration du bypass dans l'étape 4).
- **DOC/** : `AUDIT_Coherence_Documentaire_v1.0.md` (ce §32).

---

## 🚀 33. Revue de cohérence et correctifs de la fonction Grappin (2026-07-03quadravicies)

**Contexte** : Suite à un audit approfondi de la fonction Grappin, deux points d'amélioration ont été identifiés et résolus : (1) Une faille de sécurité dans `FB_Grappin` permettait d'acquitter le défaut d'incohérence mécanique de démarrage sans recalage réel, et (2) Plusieurs variables de configuration et d'état contenaient des tirets du bas, enfreignant `NAMING_CONVENTION.md`.

| # | Sujet | Décision |
|---|-------|----------|
| D79 | **Sécurisation du Reset Grappin, PascalCase & Correction de Compilation** | 1. Suppression du forçage de `GrappinState.StateIncoherent` à FALSE dans le bloc Reset de `FB_Grappin.st` (le recalage reste obligatoire). <br> 2. Suppression de tous les tirets du bas dans les variables de `ST_GrappinConfig.st` et `ST_GrappinState.st` pour respecter strictement la convention de nommage. <br> 3. Passage de `GrappinState` en `VAR_IN_OUT` pour résoudre l'erreur CODESYS C0037 (écriture sur variable de sortie non autorisée). |

### Fichiers impactés (2026-07-03quadravicies)
- **CODE/** : `FB_Grappin.st`, `ST_GrappinConfig.st`, `ST_GrappinState.st`, `PRG_MAIN.st`.
- **DOC/** : `AF_Partie-12_Fonction_Grappin_v1.0.md` (mise à jour des interfaces documentées), `AUDIT_Coherence_Documentaire_v1.0.md` (ce §33).

---

## 🚀 34. Révision comportement mou de câble + OverrideSync étendu (2026-07-04)

**Contexte** : Retour utilisateur après analyse terrain — le scénario physique du mou de câble
est différent de celui documenté en v1.1 (D27). Le capteur `M1_M2_SlackCableSwitch` est
**physiquement localisé sur le tambour M2 uniquement** (grappin). Le mou se forme lors d'une
**remontée** (grappin se ferme mal, câble continue de s'enrouler sans tension), et non en
descente comme supposé initialement. Par ailleurs, le rôle d'`OverrideSync` est clarifié et
étendu : il est applicable à la fois en MAINT_N1 et MAINT_N2 (pas restreint à N2).

| # | Sujet | Décision |
|---|-------|----------|
| D80 | **D_SLACK_1 — Comportement mou de câble revu (SafeStop total en mode normal)** | En mode **NORMAL / SEMI_AUTO / MAINT_N1 sans OverrideSync** : un mou de câble déclenche un **SafeStop M1 ET M2** (arrêt total des 2 sens, rampe rapide) + **alarme IHM acquittable** — ce n'est plus un simple `ForbidDescent` (D27). En mode **MAINT avec OverrideSync activé** : le SafeStop câble est **levé** ; `ForbidAscent` (montée interdite sur M1 ET M2) remplace le blocage directionnel ; la descente reste autorisée pour rattraper le câble sur le tambour. L'opérateur pilote M1 et M2 indépendamment. Le capteur est physiquement sur le tambour M2 uniquement. |
| D81 | **D_SLACK_2 — Procédure de récupération grappin bloqué** | En SEMI_AUTO : mou de câble → SafeStop → cycle **suspendu en mémoire** (non réinitialisé). L'opérateur doit passer en MAINT_N1 ou MAINT_N2. La réouverture du grappin est **manuelle** depuis l'IHM (`CmdOpen` sur `FB_Grappin`). Séquence de récupération typique : (a) MAINT_N2 + OverrideSync, (b) redescendre M2 pour rattraper câble, (c) redescendre M1 si grappin vraiment bloqué, (d) ouvrir grappin (CmdOpen IHM), (e) remonter en position connue, (f) désactiver OverrideSync, (g) acquitter alarme (Reset IHM), (h) reprendre cycle. L'opérateur a la possibilité d'utiliser d'autres axes (chariot) — ce choix fait perdre la mémoire du cycle. |
| D82 | **D_SLACK_3 — Acquittement manuel des alarmes mou de câble** | Les défauts mou de câble (bit3 `ErrorId`) sont exposés comme **alarmes sur l'IHM**. Acquittement **Manuel obligatoire** : pas de reset automatique, même si la cause disparaît. Condition : `GVL_IN.SlackCableSwitch = TRUE` (sain) **ET** appui Reset front montant. Pattern standard Partie3 §5 (front Reset + cause disparue) — identique aux autres défauts du domaine treuil. |
| D83 | **D_OVERRIDESYNC — Rôle élargi d'OverrideSync** | `OverrideSync` = désactive **toute** synchronisation ET tout contrôle de synchronisation. Applicable en **MAINT_N1 ET MAINT_N2** (pas restreint à N2 comme documenté initialement en §2 de Partie5 v1.2). Permet de piloter M1 et M2 **indépendamment sans contrôle d'écart de position**. **Lève également le SafeStop dû au mou de câble** (procédure de récupération manuelle autorisée). Corrige le pseudo-code de §2 Partie5 qui conditionne `OverrideSync` à `Mode = MAINT_N2` uniquement. |

### Fichiers impactés (2026-07-04)
- **DOC/** : `AF_Partie-09_Fonction_Winch` (v1.2→**v1.3** — §4ter entièrement réécrit : SafeStop total en mode normal, ForbidAscent en MAINT+OverrideSync, procédure récupération D_SLACK_2, acquittement D_SLACK_3), `AF_Partie-05_Modes_Maintenance` (v1.2 — §2 et §6 OverrideSync étendu MAINT_N1+N2, D_OVERRIDESYNC), AUDIT (ce §34).

---

## 🚀 35. Retour contacteur unique par treuil M1/M2 (2026-07-07)

**Contexte** : Retour terrain — le câblage réel des treuils M1/M2 a changé. Le retour contacteur
individuel par sens (`M1/M2_ContactorFeedbackFwd`/`Rev`, 2 signaux par treuil, un par sens)
n'existe plus côté matériel. Il est remplacé par **un seul retour par treuil**,
`M1/M2_FwdRevSpeedFeedbackOff` = « TOUS les contacteurs de ce treuil (sens avant, sens arrière,
ET les 4 paliers de vitesse) sont physiquement retombés/désénergisés » — câblé sur les nouvelles
entrées physiques `M1/M2_FwdRevSpeedFeedbackOff_DI` (remplacent les 4 anciens canaux
`M1/M2_FeedbackFwd/Rev_DI`). Changement déjà implémenté et validé côté `CODE/` avant cet audit
documentaire (voir fichiers impactés ci-dessous).

| # | Sujet | Décision |
|---|-------|----------|
| D84 | **Retour contacteur unique M1/M2 (`FwdRevSpeedFeedbackOff`)** | `FB_Winch` : `ContactorFeedbackFwd`/`Rev` (entrée) remplacés par l'entrée unique `FwdRevSpeedFeedbackOff`. Sorties `FwdContactorCheck`+`RevContactorCheck` (2×`ST_ContactorCheck`) fusionnées en **`ContactorsCheck`** (1 seul `ST_ContactorCheck`). Vérification **StuckClosed uniquement, à l'arrêt commandé** (tout ce que `FB_Winch` commande à `FALSE` mais `FwdRevSpeedFeedbackOff` ne repasse pas à `TRUE` sous `ContactorFeedbackTimeout`=500ms → bit1 `ErrorId`). **Plus de détection StuckOpen** (impossible avec ce signal unique — `ContactorsCheck.StuckOpen` reste toujours `FALSE`, champ conservé pour compatibilité de type). Bit2 `ErrorId` (ex-`RevContactorCheck`) **libéré/inutilisé**. `FB_Encoder_Homing.ArretConfirme` recalculé sur `FwdRevSpeedFeedbackOff AND (NOT BrakeFeedback)` (remplace `(NOT ContactorFeedbackFwd) AND (NOT ContactorFeedbackRev) AND (NOT BrakeFeedback)`). **Hors périmètre** : Chariot M3 (`FB_Chariot.st`) conserve ses retours individuels `ContactorFeedbackFwd`/`Rev` — changement non confirmé pour M3. |

### Fichiers impactés (2026-07-07)
- **CODE/** (déjà fait avant cet audit, non retouché ici) : `CODE/MAIN/PRG_00_Inputs.st`, `CODE/WINCH/FB_Winch.st`, `CODE/ENCODERS/FB_Encoder_Homing.st`, `CODE/MAIN/PRG_02_Encoders.st`, `CODE/MAIN/PRG_06_WinchControl.st`, `CODE/SUPERVISION/ST_WinchHMI.st`, `CODE/MAIN/PRG_09_Supervision.st`.
- **DOC/** : `AF_Partie-09_Fonction_Winch` (v1.1→**v1.4**, réalignement nom de fichier/version au passage — voir bandeau v1.4), `AF_Partie-10_Fonction_Encoder_Homing` (v1.6→**v1.7**), `AF_Partie-06_IO_Conditioning` (v1.4→**v1.5**), `AF_Partie-02_Architecture_Programme` (v2.9→**v2.10**), `AF_Partie-07_Interface_IHM` (v1.1→**v1.2**), références croisées corrigées dans `AF_Partie-11_Fonction_Chariot`, `AF_Partie-12_Fonction_Grappin`, `AF_Partie-13_Fonction_Simulation` (pointeurs vers Partie9), `CLAUDE.md` (racine, liste des docs), AUDIT (ce §35).
- **CODE/** (à faire) : `FB_Safety_Winch.st` (logique SafeStop conditionnée par `OverrideSync` / nouveau `ForbidAscent`), `FB_Winch.st` (masquage `RelayFwd` sur `ForbidAscent`).

---

## 🚀 36. Implémentation Cas B (roue libre) + 2 garde-fous supplémentaires — Méca A/B/C (2026-07-07)

**Contexte** : Suite à la consolidation du retour contacteur unique par treuil (§35, D84), l'utilisateur a
demandé de couvrir enfin le **Cas B** identifié dans la piste de sécurité "surveillance de cohérence
mouvement" (Partie9, jamais implémentée depuis son identification) — mouvement non commandé / roue libre —
ainsi que 2 garde-fous supplémentaires en défense en profondeur : perte de commande opérateur non suivie
d'un arrêt réel, et glissement du treuil M1 pendant un mouvement Grappin (M1 doit normalement rester
immobile pendant que M2 seul bouge).

| # | Sujet | Décision |
|---|-------|----------|
| D85 | **Méca A — Mouvement non commandé général (`FB_Safety_Winch` bit7)** | Armé quand `FwdRevSpeedFeedbackOff AND BrakeFeedback` (tout confirmé physiquement coupé). Si pendant l'armement la vitesse mesurée (différentiation logicielle de `CablePosM` via `FB_CycleTime`, **pas** un mot vitesse natif codeur — voir D87 ci-dessous) dépasse `UncommandedSpeedThresholdMps` (0.02 m/s, théorique) **ou** la position dérive de plus de `UncommandedDriftToleranceM` (2.0 m) par rapport à la référence prise à l'armement → `SafeStop` **et** `PowerCutOff` (les contacteurs sont déjà confirmés coupés, `SafeStop` seul ne suffit pas). |
| D86 | **Méca B — Pilotage actif sans commande opérateur (`FB_Safety_Winch` bit8)** | Indépendant de la logique interne `FB_Winch` (défense en profondeur). Si (perte CAN joystick, bit0 déjà existant) **ou** (joystick axe Y au neutre, nouvelle entrée `JoystickYNeutral`, seuil `ABS(SpeedRef) < 0.1`) **et** que `FwdRevSpeedFeedbackOff` ne repasse pas à `TRUE` dans `PostRampTimeout` (3 s, théorique) → `SafeStop` **et** `PowerCutOff`. |
| D87 | **Méca C — Glissement M1 pendant mouvement Grappin, 2 couches (`FB_Grappin` bit4 + `FB_Safety_Winch` bit9)** | **Couche 1** (`FB_Grappin`, tolérance `M1SlipToleranceM`=1.0 m) : si M1 dérive de plus d'1 m par rapport à sa position à l'entrée en `Busy` → `SevereError` (coupe M2) + sortie `M1SlipDetected` (consommée dans `PRG_06_WinchControl.st`, OR'ée dans `SafeStopM1_Raw`). **Couche 2** (`FB_Safety_Winch`, tolérance `GrappinSlipToleranceM`=2.0 m, armée uniquement via `GrappinHoldStillActive` câblée sur `instGrappin.Busy` pour l'instance M1 seule, toujours `FALSE` côté M2) : si la couche 1 n'a pas suffi (dérive continue au-delà de 2.0 m) → escalade `PowerCutOff`. |
| D88 | **`PowerCutOff` de `FB_Safety_Winch` devient réel** | `(ErrorId AND 16#0380) <> 0` (bits 7/8/9) remplace l'ancien `FALSE` codé en dur (documenté "TBD" depuis Partie9 v1.1). `SafeStop` inclut désormais aussi les bits 7/8/9 (masques `16#039F`/`16#0397` selon `OverrideSync`, au lieu de `16#001F`/`16#0017`) — les bits 7/8/9 ne sont **jamais** exclus par `OverrideSync` (sans rapport avec la procédure de récupération mou de câble, D80). |
| D89 | **TBD assumé — mesure de vitesse par mot natif codeur** | La vitesse mesurée par Méca A utilise une différentiation logicielle de `CablePosM` sur 1 cycle (10 ms), pas le mot vitesse natif EtherCAT (`COD1_SpdValue`/`COD2_SpdValue`, mappé `%IW10` côté COD1, jamais consommé dans `CODE/`). Échelle/unité de ce mot **inconnue** (à déterminer via fiche technique codeur Kübler F58x8 ou empiriquement sur site) — amélioration différée à une phase projet plus avancée : basculer Méca A sur `COD1/COD2_SpdValue` quand `EncoderM1/M2_IsReal=TRUE`, garder la différentiation logicielle en repli simulation. |

**Cas A (sens opposé) et Cas C original (absence de mouvement malgré commande) de la piste "surveillance de
cohérence mouvement"** restent **TBD, non implémentés** (sources encore manquantes : sens joystick brut,
mot vitesse natif fiable).

### Fichiers impactés (2026-07-07, session Méca A/B/C)
- **CODE/** (déjà fait avant cet audit, non retouché ici) : `CODE/WINCH/FB_Safety_Winch.st`, `CODE/GRAPPIN/FB_Grappin.st`, `CODE/MAIN/PRG_03_Safety.st`, `CODE/MAIN/PRG_06_WinchControl.st`.
- **DOC/** : `AF_Partie-09_Fonction_Winch` (v1.4→**v1.5**, §4quinquies nouveau — Méca A/B/C détaillés, remplace/complète la section TBD "surveillance de cohérence mouvement" pour le Cas B, interface `FB_Safety_Winch`/tableau `ErrorId`/formules `SafeStop`/`PowerCutOff` mis à jour), `AF_Partie-12_Fonction_Grappin` (v1.1→**v1.2**, §4.D nouveau — Méca C couche 1, `M1SlipDetected`), références croisées corrigées dans `AF_Partie-02_Architecture_Programme`, `AF_Partie-06_IO_Conditioning`, `AF_Partie-07_Interface_IHM`, `AF_Partie-10_Fonction_Encoder_Homing`, `AF_Partie-11_Fonction_Chariot`, `AF_Partie-13_Fonction_Simulation` (pointeurs vers Partie9/Partie12), `CLAUDE.md` (racine, liste des docs), AUDIT (ce §36).

---

## 🚀 37. Refonte §Sécurité électrique — 3 signaux AU distincts, polarité fail-safe `PowerCutOff`, séquence de réarmement (2026-07-07)

**Contexte** : Retour terrain — l'unique signal `EmergencyStopOk_DI` utilisé jusqu'ici recouvrait en
réalité **deux réalités physiques différentes** (la boucle AU elle-même, et l'état réel du
contacteur de puissance), ce qui empêchait de documenter proprement le réarmement après coupure.
Par ailleurs, la 1ère implémentation de `PowerCutOff_A_RQ`/`B_RQ` (canal PLC de la boucle AU) avait
une **polarité inversée** : `TRUE` signifiait « coupe », ce qui aurait **maintenu la puissance** en
cas de panne PLC réelle au lieu de la couper (pire cas de figure pour une fonction de sécurité).
Ces deux points ont été corrigés côté `CODE/` (avant cet audit, non retouché ici) et sont
désormais documentés en profondeur dans `AF_Partie-01` (choix explicite de l'utilisateur : ce
chantier reste dans la section "Sécurité électrique" existante de la Partie 1, pas de nouvelle
Partie créée).

| # | Sujet | Décision |
|---|-------|----------|
| D90 | **3 signaux distincts autour de la chaîne AU** | `EmergencyChain_DI`/`EmergencyChain` (🆕, entrée) = retour de la boucle AU physique (coup-de-poing série + canal PLC), précondition à l'armement, PAS le portail maître. `EmergencyStopOk_DI`/`EmergencyStopOk` (conservé, renommé sémantiquement) = confirmation que le contacteur de puissance est réellement engagé, reste le portail maître utilisé par tout le programme (contrat FB standard Partie 3 §1). `EmergencyArming_RQ` (🆕, sortie) = commande PLC de réarmement du contacteur (mécanisme à ressort). |
| D91 | **Polarité fail-safe `PowerCutOff_A_RQ`/`B_RQ`** | Architecture **à commande maintenue** : le PLC doit maintenir ces 2 sorties à `TRUE` en permanence ; toute transition `TRUE→FALSE` (volontaire — un Safety Mouvement de `FB_Safety_Winch` se déclenche, voir Partie9 v1.5 §4quinquies — ou accidentelle — PLC planté/coupure/watchdog dépassé) ouvre le circuit AU et coupe le contacteur, exactement comme un bouton coup-de-poing. Corrige la polarité inversée de la 1ère version (bug documenté en bandeau REX dans `AF_Partie-01` pour ne jamais être reproduit). |
| D92 | **Séquence de réarmement — IHM uniquement, jamais automatique** | Front sur `GVL_IHM.Modes.CmdEmergencyArming`, accepté seulement si `EmergencyChain=TRUE` et qu'aucune impulsion/verrouillage n'est en cours → impulsion 1 s sur `EmergencyArming_RQ` → verrouillage 5 s (recharge mécanique du ressort) avant toute nouvelle tentative. Retours IHM : `EmergencyChainOk`, `PowerContactorOk`, `EmergencyArmable`, `EmergencyArmingBusy`. Aucun réarmement auto même si `EmergencyChain` redevient sain seul — décision opérateur explicite requise. |
| D93 | **Cas non couverts par du code dédié — assumés TBD** | (1) Aucune temporisation de confirmation post-pulse ne vérifie que `EmergencyStopOk` repasse bien à `TRUE` après une impulsion `EmergencyArming_RQ` — une défaillance mécanique du contacteur reste indiscernable, côté IHM, d'un simple "pas encore réarmé" (pas d'alarme dédiée). (2) La redondance des canaux `PowerCutOff_A_RQ`/`B_RQ` est purement logicielle (`B := A`) — aucune détection de divergence si un seul des deux canaux est réellement câblé/fonctionnel côté matériel. Les deux points sont documentés comme questions ouvertes dans la casuistique `AF_Partie-01` (cas 9 et 10), à lever au câblage réel/tests terrain. |
| D94 | **Nommage « Safety Mouvement » — abandon du vocabulaire « Méca A/B/C » en documentation** | Retour utilisateur en cours de relecture (2026-07-07) : le nom de code par lettre séquentielle (« Méca A/B/C », introduit en §36/D85-D87) est jugé **ni parlant ni évolutif** (rien n'indique combien de cas existeront à terme, un 4ᵉ casserait la convention). `AF_Partie-01_Analyse_Fonctionnelle_v1.5` adopte **exclusivement** le vocabulaire descriptif **« Safety Mouvement — \<Rôle\> »** (Mouvement non commandé / Pilotage sans commande opérateur / Glissement grappin), catégorie **ouverte** sans limite de nombre, et n'utilise plus le nom par lettre nulle part dans son texte. **`CODE/` n'est pas retouché** (`FB_Safety_Winch.st`, `PRG_03_Safety.st`, `ST_WinchHMI.st` conservent aujourd'hui encore les commentaires/identifiants « Méca A/B/C », de même que `AF_Partie-09_Fonction_Winch_v1.5` §4quinquies, non modifiée dans cette session) : un renommage effectif en `CODE/` + Partie9 est une **proposition distincte**, non validée/appliquée ici, nommage cible suggéré `SafetyMotion<Role>` (`SafetyMotionUncommandedMotion`, `SafetyMotionUncommandedDrive`, `SafetyMotionGrappinSlip`) — cohérent avec le préfixe `FB_Safety_<Metier>` déjà en usage. **Q ouverte** : valider ce renommage `CODE/`+Partie9 dans une session dédiée (guardrails codesys-workflow, impact `ErrorId`/commentaires/tests). |
| D95 | **Clarification `PowerCutOff` multi-sources + couverture Grappin** | Retour utilisateur (2026-07-07) : `PowerCutOff_A_RQ` agrège **3 sources** (`instSafetyWinchM1`, `instSafetyWinchM2`, `instSafetyChariotM3`, voir `PRG_10_Outputs.st`), pas seulement `FB_Safety_Winch`. `FB_Safety_Chariot.PowerCutOff` participe déjà à la formule mais reste **codé en dur à `FALSE`** (TBD, pas de `ST_ContactorCheck` puissance M3 câblé) — aucun Safety Mouvement réel côté Chariot aujourd'hui. Le Grappin n'a pas de bloc safety dédié (pas de moteur propre) : sa protection glissement est **répartie sur 2 couches** — couche 1 dans `FB_Grappin` (`M1SlipDetected`, alimente `SafeStop` seulement) et couche 2 dans l'instance **M1** de `FB_Safety_Winch` (`GrappinHoldStillActive` sur `instGrappin.Busy`, peut escalader jusqu'à `PowerCutOff`) — donc `FB_Safety_Winch` couvre bien indirectement le Grappin via M1, sans bloc `FB_Safety_Grappin` séparé. Ces clarifications sont intégrées dans `AF_Partie-01_v1.5` (encadré dédié §Sécurité électrique). |

### Fichiers impactés (2026-07-07, session Sécurité électrique)
- **CODE/** (déjà fait avant cet audit, non retouché ici) : `CODE/MAIN/PRG_00_Inputs.st`, `CODE/MAIN/PRG_10_Outputs.st`, `CODE/MAIN/PRG_09_Supervision.st`, `CODE/SUPERVISION/ST_ModesHMI.st`. Aucun autre fichier `CODE/` touché dans cette session (le renommage `SafetyMotion*` proposé par D94 n'est **pas appliqué**).
- **DOC/** : `AF_Partie-01_Analyse_Fonctionnelle` (v1.4→**v1.5**, §Sécurité électrique entièrement réécrite/complétée : 3 signaux, polarité fail-safe, séquence de réarmement, 3 scénarios terrain, casuistique exhaustive 11 cas, vocabulaire « Safety Mouvement »), ancienne version archivée dans `ARCHIVES/Doc/` (gitignoré, via `git mv`), références croisées corrigées dans `AF_Partie-08_Fonction_Joystick`, `AF_Partie-10_Fonction_Encoder_Homing`, `AF_Partie-03_Template_FB_Commun` (pointeurs vers Partie1), `CLAUDE.md` (racine, liste des docs + note §Architecture), AUDIT (ce §37). `AF_Partie-09_Fonction_Winch_v1.5` **non modifiée** (le nom « Méca A/B/C » y reste tel quel, cohérent avec `CODE/` — voir D94).

---

## 🚀 38. Harmonisation documentaire titre ↔ filename (2026-07-08)

**Constat** : 7 fichiers AF_Partie ont incohérence entre titre interne (entête `# v1.X`) et nom de
fichier (suffixe `_vX.Y.md`). Exemple : `AF_Partie-05_Modes_Maintenance_v1.2.md` avec titre `(v1.4)`.
Cause probable : rechargement de versions lors de commit 26a9f1c (« full doc audit ») sans
synchronisation titre/filename. Ajout de Partie13 (Simulation v1.1) jamais mentionné dans
`CLAUDE.md`. Référence dans `CLAUDE.md` pointant vers v1.6 qui n'existe plus (actual : v1.7).

| # | Sujet | Décision |
|---|-------|----------|
| D96 | **Resynchronisation titre = filename (pas de renommage fichier, correction titre)** | Les 7 fichiers ont leur **titre** corrigé pour matcher le **filename version** (source de vérité). Filenames **inchangés** (conserve l'historique git). Fichiers affectés : Partie1 v1.6→v1.5, Partie5 v1.4→v1.2, Partie7 v1.3→v1.2, Partie9 v1.8→v1.7, Partie10 v1.8→v1.7, Partie12 v1.3→v1.2, Partie13 v1.2→v1.1. |
| D97 | **Misse à jour références croisées (Partie1/10/11/12 → Partie9 v1.7)** | 8 références internes ajustées : `AF_Partie-01` (3 occurrences v1.5/v1.6→v1.7), `AF_Partie-10` (2 occurrences v1.5→v1.7), `AF_Partie-11` (2 occurrences v1.6→v1.7), `AF_Partie-12` (1 occurrence v1.8→v1.7), `AF_Partie-13` (1 occurrence v1.8→v1.7). |
| D98 | **Mise à jour CLAUDE.md : Partie9 v1.6→v1.7 + ajout Partie13** | Lien dans `CLAUDE.md` ligne 125 pointant vers version fantasme v1.6 remplacé par v1.7 (actual). Ajout Partie13 dans la liste docs (ligne 129, avant AUDIT). Partie 13 décrite brièvement (« Fonction Simulation — flags bits maître + granularité par device »). |

### Fichiers impactés (2026-07-08, audit harmonisation)
- **DOC/** : `AF_Partie-01_Analyse_Fonctionnelle_v1.5.md` (titre corrigé + 3 refs Partie9),
  `AF_Partie-05_Modes_Maintenance_v1.2.md` (titre corrigé),
  `AF_Partie-07_Interface_IHM_v1.2.md` (titre corrigé),
  `AF_Partie-09_Fonction_Winch_v1.7.md` (titre corrigé),
  `AF_Partie-10_Fonction_Encoder_Homing_v1.7.md` (titre + 2 refs Partie9 corrigés),
  `AF_Partie-11_Fonction_Chariot_v1.3.md` (2 refs Partie9 v1.6→v1.7),
  `AF_Partie-12_Fonction_Grappin_v1.2.md` (titre + 1 ref Partie9 v1.8→v1.7 corrigés),
  `AF_Partie-13_Fonction_Simulation_v1.1.md` (titre + 1 ref Partie9 v1.8→v1.7 corrigés),
  `CLAUDE.md` (racine, 2 mises à jour : Partie9 v1.6→v1.7 + ajout Partie13).
- **Reste ouvert (non corrigé)** : Références de code à `OverrideSync` vs `SyncEnable` (renommage code 2026-07-08 non répercuté en DOC — voir D99 ci-après). Ces corrections visent la **forme** (version numbers cohérence) ; le fond technique (variable renommée dans code mais doc non mise à jour) est documenté séparement pour décision utilisateur.

---

## 🚀 39. ⚠️ Incohérence persistante — `OverrideSync` (doc) vs `SyncEnable` (code, 2026-07-08)

**Constat** : Commit 26a9f1c (feat grappin, 2026-07-08, 15h25) a renommé `OverrideSync`
→ `SyncEnable` dans le code avec inversion de polarité (logique positive désormais), répercuté sur
5 fichiers `CODE/` (`FB_Modes.st`, `FB_Safety_Winch.st`, `FB_WinchSync.st`, `ST_SyncHMI.st`,
`PRG_06_WinchControl.st`). **MAIS** la documentation `DOC/AF_Partie-05_Modes_Maintenance_v1.2.md`
**n'a pas suivi** — elle parle toujours de `OverrideSync` partout (13 occurrences confirmées au
2026-07-08 après le commit).

| # | Sujet | Décision |
|---|-------|----------|
| D99 | **Documentation NON CORRIGÉE, question ouverte** | Audit découvert l'incohérence doc/code, mais **correction documentaire dépasse le périmètre** « correction forme » (D96-D98) ; cela demande une **relecture métier complète** de AF_Partie-05 pour tracer tous les impacts (logique positive affectant les formules de guard, état IHM, messages). Recommandation : valider en session dédiée **après relecture code-review des changements 26a9f1c** (grappin, sécurité, IHM) — une mauvaise traduction `OverrideSync`→`SyncEnable` dans la doc pourrait introduire une confusion dangeuse. **Balisé à corriger** : Partie5 v1.2 **doit être mise à jour en v1.3** (au minimum) avec les 13 occurrences et la logique inversée documentée, à faire à titre de **nettoyage documentaire décidé par l'utilisateur, hors cet audit**. |

**Fichiers affectés (code, déjà modifiés en production)** :
- `CODE/MODES/FB_Modes.st:21` (commentaire REX 2026-07-08)
- `CODE/WINCH/FB_Safety_Winch.st:50` (entrée)
- `CODE/WINCH/FB_WinchSync.st:30` (entrée), ligne 95 (logique)
- `CODE/SUPERVISION/ST_SyncHMI.st:5` (commentaire)
- `CODE/MAIN/PRG_06_WinchControl.st:múltiples` (appels)
- **Documentation affectée (NON mise à jour)** : `AF_Partie-05_Modes_Maintenance_v1.2.md` ligne 6, 61,
  78-79, 95-97, 100, 107, 119-120, et détails §6bis entier.

---

## 🚀 40. ✅ Correction documentaire — `OverrideSync` → `SyncEnable` (2026-07-08)

**Constat** : Suite à D99, correction systématique de toutes les références `OverrideSync` en `SyncEnable` avec inversion de polarité dans la documentation.

| # | Sujet | Décision |
|---|-------|----------|
| D100 | **Correction documentaire complète — `OverrideSync` → `SyncEnable` avec inversion de polarité** | Migration effectuée de `AF_Partie-05_Modes_Maintenance_v1.2.md` → **v1.3.md** (13 occurrences corrigées). Toutes les formules et descriptions inversées pour refléter la logique positive (`SyncEnable = TRUE` ⟹ synchro active, au lieu de `OverrideSync = TRUE` ⟹ synchro désactivée). Pseudo-codes de `FB_Modes` mises à jour ; formule SafeStop masques inversés (condition `SyncEnable=FALSE`). Archives : v1.2 déplacée vers `ARCHIVES/Doc/`. Références croisées mises à jour dans `CLAUDE.md` (2 occurrences), `AF_Partie-02_Architecture_Programme_v2.10.md` (2 occurrences ligne 91, 138), `AF_Partie-09_Fonction_Winch_v1.7.md` (7 occurrences + 1 référence Partie5), `AF_Partie-07_Interface_IHM_v1.2.md` (1 occurrence). |

**Fichiers modifiés (documentation)** :
- ✅ `DOC/AF_Partie-05_Modes_Maintenance_v1.3.md` (NOUVEAU, corrigé avec polarité positive)
- ✅ `ARCHIVES/Doc/AF_Partie-05_Modes_Maintenance_v1.2.md` (archivé, ancien)
- ✅ `CLAUDE.md` (2 références Partie5 v1.2→v1.3)
- ✅ `AF_Partie-02_Architecture_Programme_v2.10.md` (2 refs ligne 91, 138)
- ✅ `AF_Partie-09_Fonction_Winch_v1.7.md` (7 refs + 1 lien Partie5 v1.2→v1.3)
- ✅ `AF_Partie-07_Interface_IHM_v1.2.md` (1 ref `ST_SyncHMI`)

**Conformité** : Toutes les occurrences documentées par D99 ont été corrigées. Polarité systématiquement inversée : `OverrideSync=TRUE` (synchro désactivée) → `SyncEnable=FALSE` (synchro désactivée). Défaut IHM aussi mis à jour (ancien défaut `FALSE` pour case «Override» → nouveau défaut `TRUE` pour case «Synchro active»).

---

## 🚀 41. Note TBD — Montée en charge et temporisation frein (2026-07-08)

**Contexte & vigilance métier** : Retour utilisateur identifié lors d'une discussion mise en service — **phase critique de remontée chargée** (après récupération de charge en descente, puis inversion de consigne joystick). Le poids de la charge peut créer un **effet entraînant mécanique** qui contredise les hypothèses sous-jacentes à la séquence de frein actuelle (`FB_Brake.st` §3 : temporisations fixes `DelayMagnetise`/`DelayMotorDecel`).

| # | Sujet | Décision |
|---|-------|----------|
| D101 | **Ajout note d'investigation — Montée en charge & frein (v1.8)** | Note documentaire ajoutée à `AF_Partie-09_Fonction_Winch_v1.8.md` §4undecies (nouvelle sous-section après §4decies). **Pas de correction de code**, juste identification de **point de vigilance** à tracker pour essais de charge/mise en service complète. Trois paramètres à valider terrain : (1) délai magnétisation suffisant pour transférer charge au moteur sans à-coup ; (2) délai décélération suffisant pour que moteur arrête avant serrage frein ; (3) aucun rebondissement/glissement frein en transition charge-neutre. **Scope complet de refactoring (si besoin)** : possibilité d'ajuster temporisations fixes ou refonte du modèle séquentiel — **déterminé par REX terrain**, non assumé d'avance. Archive v1.7 conservée pour traçabilité historique. Référence croisée mise à jour dans `CLAUDE.md` (pointer v1.8 au lieu de v1.7). |

**Fichiers modifiés (documentation)** :
- ✅ `DOC/AF_Partie-09_Fonction_Winch_v1.8.md` (NOUVEAU, contient note §4undecies)
- ✅ `DOC/AF_Partie-09_Fonction_Winch_v1.8.md` (header mis à jour, v1.7→v1.8)
- ✅ `CLAUDE.md` (1 référence Partie9 v1.7→v1.8)
- ✅ `AUDIT` (ce §41, nouvelle entrée)

**Traçabilité** : Essais de charge recommandés **avant** déploiement en production — surtout tester le scénario « plongée + récupération + extraction sous charge » pour observer le comportement du frein en transition et valider que les temporisations couvrent l'effet entraînant mécanique de la charge. Point de vigilance, **pas un bug confirmé aujourd'hui**.

---

## 🚀 42. Renommage documentation — tri alphabétique `AF_Partie-0N` (2026-07-08)

**Contexte** : Amélioration lisibilité GitHub (tri lexicographique, problème avec Partie1/Partie10/Partie2 qui se mélangent).

| # | Sujet | Décision |
|---|-------|----------|
| D102 | **Renommage 13 fichiers AF_PartieN en AF_Partie-0N** | Tous les fichiers de documentation `AF_PartieN_...vX.Y.md` renommés avec numérotation zéro-paddée sur 2 chiffres (`AF_Partie-01_...` à `AF_Partie-13_...`) pour assurer un tri alphabétique correct dans GitHub. **Format du renommage strict** : `AF_PartieN_SUFFIX_vX.Y.md` → `AF_Partie-0N_SUFFIX_vX.Y.md` (N ≤ 9) ou `AF_Partie-NN_SUFFIX_vX.Y.md` (N ≥ 10). Aucune modification de contenu des fichiers — renommage pur. |

**Fichiers renommés (13 fichiers, via `git mv`)** :
- `AF_Partie1_Analyse_Fonctionnelle_v1.5.md` → `AF_Partie-01_Analyse_Fonctionnelle_v1.5.md`
- `AF_Partie2_Architecture_Programme_v2.10.md` → `AF_Partie-02_Architecture_Programme_v2.10.md`
- `AF_Partie3_Template_FB_Commun_v1.3.md` → `AF_Partie-03_Template_FB_Commun_v1.3.md`
- `AF_Partie4_Cycle_Sequenceur_v1.2.md` → `AF_Partie-04_Cycle_Sequenceur_v1.2.md`
- `AF_Partie5_Modes_Maintenance_v1.3.md` → `AF_Partie-05_Modes_Maintenance_v1.3.md`
- `AF_Partie6_IO_Conditioning_v1.5.md` → `AF_Partie-06_IO_Conditioning_v1.5.md`
- `AF_Partie7_Interface_IHM_v1.2.md` → `AF_Partie-07_Interface_IHM_v1.2.md`
- `AF_Partie8_Fonction_Joystick_v1.2.md` → `AF_Partie-08_Fonction_Joystick_v1.2.md`
- `AF_Partie9_Fonction_Winch_v1.8.md` → `AF_Partie-09_Fonction_Winch_v1.8.md`
- `AF_Partie10_Fonction_Encoder_Homing_v1.7.md` → `AF_Partie-10_Fonction_Encoder_Homing_v1.7.md`
- `AF_Partie11_Fonction_Chariot_v1.3.md` → `AF_Partie-11_Fonction_Chariot_v1.3.md`
- `AF_Partie12_Fonction_Grappin_v1.2.md` → `AF_Partie-12_Fonction_Grappin_v1.2.md`
- `AF_Partie13_Fonction_Simulation_v1.1.md` → `AF_Partie-13_Fonction_Simulation_v1.1.md`

**Références croisées mises à jour** (sed multi-fichier, ordre : noms de fichiers d'abord, puis références avec/sans underscores) :
- ✅ `CLAUDE.md` : 13 liens + 4 mentions de versions (ex. « Winch=Partie9 »)
- ✅ `.claude/skills/codesys-workflow.md` : 3 liens + 1 pattern
- ✅ `README.md` : mentions s'il y en avait (vérification complète)
- ✅ `DOC/*.md` (les 13 fichiers eux-mêmes) : bandeaux "Dépend de", références internes (ex. « voir Partie9 §4quinquies » → « voir Partie-09 §4quinquies »)
- ✅ `DOC/VERSION_HISTORY.md` : références historiques
- ✅ `DOC/NAMING_CONVENTION.md` : 2 mentions (Partie3)

**Audit conformité** : `grep -r "AF_Partie[0-9][^-]" DOC/*.md CLAUDE.md README.md` (recherche de format ancien sans tiret) = 0 résultat → **aucun lien cassé subsiste**.

**Non affecté** : `ARCHIVES/Doc/` (versions périmées, gitignoré) — fichiers restent en format ancien (inutile de les renommer).

---

## 🚀 43. Documentation exhaustive des 5 mécanismes de sécurité Winch (2026-07-09)

**Contexte** : Les 5 mécanismes de sécurité (`FB_Safety_Winch` bits 7/8/9/11/12/13) avaient chacun un paragraphe de description dans le bandeau du code ST et dans la Partie 9, mais sans structure unifiée — absence de tableau récapitulatif, conditions d'armement/déclenchement éparpillées, conséquences pas toujours explicites. Demande utilisateur : documentation exhaustive et structurée (un tableau + une sous-section détaillée par Méca).

| # | Sujet | Décision |
|---|-------|----------|
| D103 | **Documentation Méca A–E complète (v1.9)** | Nouvelle section §4novies dans `AF_Partie-09_Fonction_Winch_v1.9.md` : (1) **tableau récapitulatif** 5 lignes (Méca / Bit / Armement / Déclenchement / Conséquence / Seuils) — vue d'ensemble 30 secondes ; (2) **5 sous-sections détaillées** (Méca A / B / C / D / E) listant **Rôle** (1 phrase), **Armement** (condition exact du code, commentée), **Déclenchement** (logique), **Conséquence** (SafeStop / PowerCutOff escalade), **Paramètres réglables** (noms variables réelles, défauts, unités), **Subtilités** (ex. Méca C UNIQUEMENT M1, Méca E escalade PowerCutOff sur bit13, pas bit12 seul). **Comportement extracté 100% du code réel** `CODE/WINCH/FB_Safety_Winch.st` (pas de duplication ST, description du comportement seulement). Versionning : v1.8 → v1.9. |

**Fichiers modifiés** :
- ✅ `DOC/AF_Partie-09_Fonction_Winch_v1.9.md` (NOUVEAU, section §4novies ; v1.8 archivé)
- ✅ `ARCHIVES/Doc/AF_Partie-09_Fonction_Winch_v1.8.md` (copie conservée pour traçabilité)
- ✅ `CLAUDE.md` (1 référence : AF_Partie-09 v1.8→v1.9 + description améliorée)
- ✅ `CODE/WINCH/FB_Safety_Winch.st` (bandeau : DOC ref v1.1→v1.9)

**Contenu section 4novies** :
1. Tableau récapitulatif 5 lignes × 7 colonnes (Méca / Bit / Armement / Déclenchement / Conséquence / Seuil/Délai)
2. **Méca A (bit7)** — Mouvement non commandé / roue libre : armé contacteurs+frein coupés, déclenchement dérive>2m OU vitesse>0.02m/s, PowerCutOff escalade
3. **Méca B (bit8)** — Pilotage sans commande opérateur : armé perte CAN/joystick neutre, déclenchement pas d'arrêt confirmé après 3s (contacteurs+frein), PowerCutOff
4. **Méca C (bit9)** — Glissement M1 grappin : armé UNIQUEMENT M1 (GrappinHoldStillActive), dérive>2m escalade, PowerCutOff
5. **Méca D (bit11)** — Capteur haut / limite logicielle : armé capteur atteint OU limite dépassée, pas confirmé arrêt après 3s, PowerCutOff
6. **Méca E (bits 12/13)** — Écart synchro critique : bit12 détection immédiate SafeStop seul, bit13 escalade PowerCutOff si pas confirmé après 3s
7. Chaque Méca inclut : Rôle (1 phrase), Armement (condition exacte), Déclenchement (logique), Conséquence, Paramètres (noms/défauts/unités), Subtilités (alertes critiques)

**Conformité** : Toutes les conditions/seuils extraits du code réel — garantit que la doc reflète le comportement codé, pas une interprétation théorique. Pas de code ST recopié (règle anti-duplication), comportement descriptif uniquement.

**Traçabilité** : Utile pour :
- Mise en service : tableau permet de comprendre RAPIDEMENT quels seuils ajuster (colonnes Seuil/Délai)
- Diagnostic : tableau guide le technicien « mon bit X est levé → voir Méca Y, regarder le seuil ZZ »
- Audit de sécurité : structure explicite + escalades PowerCutOff justifiées pour chaque Méca
- Évolution future : un nouveau mécanisme se documente sur le même pattern

---
