# 🗂️ Registre d'actions — Bypass (Simulation + Maintenance) v1.0

> **Rôle** : sas local entre la réflexion (session utilisateur ↔ Claude) et `DOC/PLAN_TASK_v1.0.md`.
> **Ce document n'est pas une spec ni une autorisation de modifier `CODE/`.**
>
> Cycle : `Discussion → Registre local → décision + impact verrouillés → TASK_CONTEXT → TEST_DESIGN (double revue A/B) → codesys-change`.

---

## 🚦 Règles de pilotage

- 🟡 Toute ligne commence **à analyser** : une idée de session n'est pas une exigence validée.
- ✅ Promotion vers `PLAN_TASK`/`TASK_CONTEXT` uniquement si : décision explicite, impact connu, périmètre borné, tests définis.
- 🛑 Sujet **C4 (safety)** : Ponytail interdit, double revue A/B obligatoire sur TEST_DESIGN et ST généré (voir `TOOLS/AGENT_WORKFLOW/docs/SAFETY_POLICY.md`).
- 🧩 1 changement cohérent = 1 tâche. Transversal (touche Winch + Translation + Bucket + Simulation) → découpage en phases.

---

## A. 🔍 Constat — Audit de l'existant (fait cette session, vérifié dans le code)

### A.1 — Inventaire des mécanismes de bypass actuels

| Famille | Exemple | Localisation | Portée | Verrouillage |
|---|---|---|---|---|
| **1. Bypass simulation** (`_IsReal`) | `EncoderM1_IsReal`, `SlackCableSwitch_IsReal`, `ContactorFeedbackM1_IsReal`... (19 flags) | `GVL_Simulation` | Avant câblage réel, mise en service | `SimulationModeActive=TRUE` uniquement, pas RETAIN |
| **2. Bypass IHM métier "dégradé assumé"** | `CmdEncoderFaultBypass`, `CmdInhibit` | `ST_WinchHMI`, câblé via `FB_Modes` | Terrain, maintenance réelle | **MAINT_N2 uniquement** (doctrine déjà tranchée, T53 `PLAN_TASK.md`) |
| **3. Bypass "retour contacteur non câblé"** | `BypassContactorFeedback` (Translation), `BypassContactorCheck` (FB_Winch/FB_Translation/FB_Brake) | `ST_TranslationHMI`, `ST_WinchHMI` | Banc de test, auto-calculé | Dérivé de `GVL_Simulation`, pas une commande IHM directe |
| **4. Bypass "capteur spécifique non câblé", miroir IHM** | `BypassSlackCable`, `BypassTopPositionSensor` | `ST_WinchHMI` | Banc de test | Câblés en lecture seule (`PRG_09_Supervision.st:275-278`), **corrigé** : ne sont PAS orphelins (erreur de constat initiale corrigée en session) |

### A.2 — Ampleur de la dispersion

- **19 flags `_IsReal`** déclarés dans `GVL_Simulation.st`.
- **21 fichiers** consomment `GVL_Simulation.*` (hors déclaration).
- `PRG_00_Inputs.st` : **25 usages** — fichier le plus impacté (normal, c'est la couche d'acquisition).
- Exemple `ContactorFeedbackM1_IsReal` : consommé dans **7 fichiers différents**, sous 3 formes d'expression différentes (`SEL(...)`, `AND NOT`, `OR (...)`) — pas de pattern commun.

### A.3 — Vérification architecture (bonne pratique automatisme)

- ✅ **Confirmé** : aucun `FUNCTION_BLOCK` métier (`FB_Winch`, `FB_Safety_Winch`, `FB_Translation`, `FB_Safety_Translation`, `FB_Brake`) ne lit `GVL_Simulation` directement dans son corps. Toutes les mentions trouvées dans ces FB sont des **commentaires**, pas du code exécuté.
- ✅ Le flux respecté est : `GVL_Simulation` → `PRG_00_Inputs` (bascule réel/simulé) → variable normale → `VAR_INPUT` du FB. Le FB ne sait jamais s'il reçoit du réel ou du simulé.
- ⚠️ **Écart identifié** : `BypassContactorCheck` (VAR_INPUT de `FB_Winch`/`FB_Translation`/`FB_Brake`) — respecte l'encapsulation technique (c'est bien un `VAR_INPUT`) mais son **nom** trahit directement le concept "simulation" dans l'interface du bloc métier — fuite conceptuelle mineure, pas une violation d'architecture.

### A.4 — Précédent historique direct : doctrine "Conditional Bypass" (RETIRÉE)

Trace trouvée dans le code (`PRG_03_Safety.st:26`, `PRG_03_Safety.st:166`, `AF_Partie-11_Fonction_Translation_v1.9.md:22`) :

> *"ex-doctrine 'Conditional Bypass' (`NOT ManuActive OR ...`) devenue obsolète et RETIRÉE — chaque capteur/retour a DÉJÀ sa propre granularité réel/simulé"*

**Enseignement** : un bypass **large** (au niveau d'un bloc/domaine entier, ex. "bypasser tout le codeur") a été testé et retiré car il empêchait `FB_Winch` de recevoir un `SafeStop`/`ForbidAscent`/`ForbidDescent` réel nécessaire à un comportement de rampe correct — masquait le comportement qu'on cherchait justement à valider en simulation.
📌 **Conséquence directe** : toute nouvelle doctrine de bypass doit conserver la **granularité fine** (capteur par capteur), pas revenir à un bypass "bloc entier".

### A.5 — Distinction bypass statique vs dynamique (capturée session)

| Type | Exemple | Comportement | Pourquoi nécessaire |
|---|---|---|---|
| **Statique** | `TopPositionSensor := DI OR (SimActive AND NOT IsReal)` | Force une valeur figée en permanence | Suffit pour capteurs tout-ou-rien (fin de course, thermique) |
| **Dynamique** | `FB_Sim_Encoder` (`RawPos := RawPos + Increment` selon `RelayFwd`/`SpeedRefPct`) | Modélise une grandeur physique qui évolue dans le temps | Nécessaire pour tester la synchro M1/M2, les rampes, le homing, la vitesse mesurée (Méca A/B/E dépendent de la variation de position dans le temps) |

Les deux mécanismes sont **légitimes et complémentaires**, pas redondants — mais partagent aujourd'hui la même famille de flags `_IsReal` sans distinction visuelle.

---

## B. 🎯 Doctrine actée en session (décisions utilisateur)

### B.1 — Distinction fondamentale : 2 familles de bypass, jamais confondues

| Famille | But | Qui active | Persistance | Reste après livraison ? |
|---|---|---|---|---|
| **A — Bypass simulation** ("pas encore câblé") | Avancer en dev/mise en service sans matériel réel | Automaticien/projet | 🟡 **Ouvert** — actuellement `GVL_Simulation` n'est pas RETAIN | Non — disparaît normalement une fois tout câblé (`SimulationModeActive=FALSE`) |
| **B — Bypass "dégradé assumé"** (maintenance réelle) | Continuer à travailler en connaissance de cause quand un capteur précis tombe en panne, machine livrée | Opérateur IHM | ✅ RETAIN (déjà le cas, `GVL_IHM`) | **Oui** — reste disponible en permanence sur machine livrée |

### B.2 — Architecture : Struct `Bypass` dédiée, imbriquée par métier

**Règle actée** (validée explicitement par l'utilisateur) :

1. **Jamais de champ bypass isolé à la racine** d'un struct métier (`ST_WinchHMI`, `ST_TranslationHMI`...) — même s'il n'y a qu'un seul bypass, il va dans un sous-struct dédié `Bypass`.
2. **Rangement par domaine métier** — chaque axe a son propre `Bypass`, imbriqué dans son struct existant :
   ```pascal
   TYPE ST_WinchHMI :
   STRUCT
       ...
       Bypass : ST_BypassWinch;
   END_STRUCT

   TYPE ST_BypassWinch :
   STRUCT
       EncoderFault : BOOL;   // reste dans son propre struct dédié, même seul
   END_STRUCT
   ```
3. **Signaux communs** (thermique frein commun M1/M2/M3, mou de câble, position haute, rotation phase) → dans `ST_CommunHMI.Bypass` (réutilise le pattern déjà existant de `ST_CommunHMI`, pas une nouvelle GVL).
4. **Flux toujours injecté en `VAR_INPUT`** vers les blocs métier — jamais un bloc ne lit une GVL/structure IHM directement depuis son corps (principe d'encapsulation POO, déjà respecté aujourd'hui pour `EncoderFaultBypass`, à généraliser).
5. **Granularité fine conservée** — pas de retour à un bypass "bloc entier" (leçon A.4, doctrine "Conditional Bypass" retirée pour cette raison précise).

### B.3 — Exemple pattern déjà conforme (référence à généraliser)

`EncoderFaultBypass` respecte déjà ce flux :
```pascal
// PRG_03_Safety.st
instSafetyWinchM1(
    ...
    EncoderFaultBypass := GVL_IHM.M1TreuilRetenue.CmdEncoderFaultBypass,  // injecté, pas lu depuis l'intérieur
    ...
);
```
Ce pattern devient LA référence pour toute la migration à venir.

### B.4 — Nommage

| Contexte | Convention actée |
|---|---|
| Simulation (`GVL_Simulation`, GVL plate) | `Sensor<Axe><Fonction>IsReal` (ex: `SensorM1ThermalIsReal`) — voir `NAMING_CONVENTION.md` section "Variables de simulation" déjà rédigée cette session |
| Struct `Bypass` imbriquée par métier | `<Fonction>` simple (le contexte métier + "Bypass" sont déjà donnés par le chemin `GVL_IHM.M1TreuilRetenue.Bypass.EncoderFault`) — pas de répétition de repère à l'intérieur du champ (règle déjà actée, section "Construction d'un nom") |

---

## C. ❓ Points encore ouverts (non tranchés, à décider avant TASK_CONTEXT)

| # | Question | Options envisagées |
|---|---|---|
| O1 | Famille A (simulation) et B (maintenance) : **même struct `Bypass`** avec sous-distinction, ou **2 structs séparés** (`ST_BypassSim` / `ST_BypassMaint`) par métier ? | À trancher — impact direct sur la struct finale à générer |
| O2 | Persistance de la famille A (simulation) : passer en RETAIN comme la famille B, ou rester volatile (repart à l'état par défaut à chaque redémarrage, mesure de sécurité pendant la mise en service) ? | À trancher |
| O3 | `BypassContactorCheck` (VAR_INPUT dont le nom trahit "simulation" dans l'interface du FB métier) : renommer en un nom neutre (ex: `SkipContactorCheck`) ou laisser tel quel (écart mineur, faible risque) ? | À trancher, priorité basse |
| O4 | Migration : tous les bypass d'un coup (gros lot), ou par métier (Winch d'abord, puis Translation, puis Bucket) ? Impact IHM (tags graphiques) à chaque renommage. | À trancher — recommandation : par métier, phases compilables/testables indépendamment |

---

## D. 🧠 Fiche d'impact à compléter avant promotion vers TASK_CONTEXT

```md
### BYPASS-A01 — Restructuration Bypass simulation + maintenance

**Décision validée :** struct `Bypass` dédiée par métier (ST_WinchHMI.Bypass, etc.),
signaux communs dans ST_CommunHMI.Bypass, flux VAR_INPUT généralisé, granularité fine
conservée (pas de bypass bloc entier).

**But / risque traité :** dispersion actuelle de 19 flags _IsReal + bypass maintenance
dans 21 fichiers, sans regroupement visuel ni distinction claire simulation/maintenance —
risque de confusion opérateur en mise en service et en exploitation terrain.

**À ne pas faire :**
- pas de bypass "bloc entier" (leçon Conditional Bypass, retirée pour cause avérée) ;
- pas de champ bypass isolé à la racine d'un struct métier ;
- pas de lecture GVL directe depuis l'intérieur d'un FB métier ;
- pas de modification CODE avant O1-O4 tranchés et double revue A/B du TEST_DESIGN.

| Domaine | Impact vérifié / à traiter |
|---|---|
| FB / PRG propriétaire | FB_Safety_Winch (x2 instances), FB_Safety_Translation, FB_Winch (x2), FB_Translation, FB_Brake, FB_Bucket |
| Producteurs d'entrées | GVL_Simulation (19 flags), GVL_IHM (CmdEncoderFaultBypass, CmdInhibit existants) |
| Consommateurs de sorties | PRG_00_Inputs (25 usages), PRG_03_Safety, PRG_06_WinchControl, PRG_07_TranslationControl, PRG_09_Supervision |
| IHM / GVL | ST_WinchHMI, ST_TranslationHMI, ST_BucketHMI, ST_CommunHMI — casse les tags IHM existants (BypassSlackCable, BypassTopPositionSensor, BypassContactorFeedback, CmdEncoderFaultBypass, CmdInhibit) |
| EtherCAT / E/S | Aucun impact direct (pas de nouveaux points I/O) |
| Cycle / Modes | FB_Modes (InhibitM1/M2 déjà conforme au pattern cible) |
| Simulation / PLC tests | 7 fichiers SUITE_* consomment GVL_Simulation.*_IsReal — impact sur les suites de tests existantes |
| Safety (Enable, SafeStop, PowerCutOff, Reset) | Sujet C4 direct — chaque bypass touche potentiellement une couche safety (Méca A-E, ForbidAscent/Descent, PowerCutOff) |
| DOC impactée | NAMING_CONVENTION.md (déjà mis à jour section simulation), AF_Partie-03 (contrat FB), AF_Partie-09 (Winch), AF_Partie-11 (Translation), AF_Partie-13 (Simulation) |

**Stratégie** : phases par métier (Winch → Translation → Bucket), chaque phase compilable/testable indépendamment.

**Préconditions :** O1-O4 tranchés par l'utilisateur.
**Tests intermédiaires :** 1 test par bypass — vérifier qu'il bypasse bien SA cause précise, ET qu'il ne masque aucun autre défaut du même bloc (non-régression sur les Méca A-E).
**Critères d'acceptation :** structure Bypass en place, ancien nommage migré avec mapping documenté, IHM re-testée après import bundle, tous les tests PLC_TESTS existants repassent au vert.
**Condition de promotion vers PLAN_TASK :** O1-O4 tranchés + fiche d'impact complète validée par l'utilisateur.
```

---

## 📚 Sources

- Session utilisateur ↔ Claude (discussion bypass, workflow C0-C4, préfixes IHM)
- `DOC/NAMING_CONVENTION.md` (sections mises à jour cette session : IHM préfixes, variables simulation, repères GVL plates)
- `CODE/SIMULATION/GVL_Simulation.st`, `CODE/MAIN/PRG_00_Inputs.st`, `CODE/MAIN/PRG_03_Safety.st`
- `CODE/TREUILS/FB_Safety_Winch.st`, `CODE/TRANSLATION/FB_Safety_Translation.st`
- `DOC/PLAN_TASK_v1.0.md` (T53, doctrine bypass individuel MAINT_N2 déjà tranchée)
- `AGENTS.md` / skill `codesys-workflow`

---

## 📋 Réponse opérateur — À copier-coller

```text
O1 (même struct ou séparées) :
O2 (persistance simulation RETAIN ou volatile) :
O3 (renommer BypassContactorCheck) :
O4 (migration : tout d'un coup ou par métier) :
```
