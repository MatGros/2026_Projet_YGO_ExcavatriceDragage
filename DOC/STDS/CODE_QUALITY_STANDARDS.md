# 🧭 Standards Qualité Code — Référentiel Universel (v2.0)

> 📌 **Propriétaire unique** des règles de déclaration, de liaison et de POO du projet.
> Tout autre document (skill CODESYS, `CODE_WRITING_POLICY`, prompts Pi) **renvoie ici**
> au lieu de reformuler — une règle écrite deux fois dérive toujours.
> Portée : tout agent (Claude, Codex, Gemini/antigravity), tout workflow, et l'humain.

**Répartition des rôles — ne pas chercher ailleurs :**

| Sujet | Document |
|---|---|
| Comment on **nomme** | `DOC/STDS/NAMING_CONVENTION.md` |
| Comment on **déclare, encapsule, relie** | **ce document** |
| Contrats FB, DUT et CFC | `DOC/AF/AF_Partie-03_Contrats_Composants_v2.1.md` |
| Ce que fait la machine | `DOC/` — voir `DOC/README.md` pour l'index complet |
| Comment on exécute une modif | `.claude/skills/codesys-workflow.md` |

---

## 1. Nommage — les 3 règles qui ne se négocient pas

1. Le nom dit **le rôle**, jamais le type (`bFlag` ❌, `iCounter` ❌ — le type se lit en déclaration).
2. Le nom se lit **sans le commentaire d'à côté**. Si le commentaire répète le nom, le nom est mauvais.
3. Une notion = **un seul nom** dans tout le projet (jamais `BrakeIsOpenConfirmed` à côté de `BrakeCommandOpenConfirmed`).

Détail complet (préfixes, suffixes d'unité, polarité booléenne, construction instance→champ) :
`DOC/STDS/NAMING_CONVENTION.md`.

---

## 2. Déclaration — ce qu'un automaticien vérifie sans y penser

- **Toute variable est initialisée explicitement** quand sa valeur par défaut n'est pas la valeur
  sûre. Cas vécu : un `BOOL` capteur de sécurité non initialisé démarre à `FALSE` = « défaut »
  permanent (REX `PhaseRotationOk`). Règle : famille sécurité → `:= TRUE` explicite.
- **Aucun nombre magique dans le corps.** Un seuil, une durée, un facteur se déclarent en
  `VAR CONSTANT` nommée (ou en paramètre de config), jamais en littéral au milieu du code.
  Exception admise : `0`, `1`, `TRUE`, `FALSE` et les indices de boucle.
- **Portée minimale.** Dans l'ordre de préférence : variable locale `VAR` → `VAR_INPUT`/`VAR_OUTPUT`
  → GVL. Une GVL ne se crée que pour une **frontière identifiée** (IHM, persistance, simulation,
  image process), jamais comme boîte à variables communes.
- **Une déclaration = un rôle documenté** : unité, plage et polarité en commentaire de fin de ligne
  quand elles ne sont pas évidentes dans le nom.
- **`VAR_IN_OUT` est réservé** au partage intentionnel et documenté d'un objet. Il ne sert jamais
  à contourner une interface ni à autoriser un second écrivain.
- **`PERSISTENT`/`RETAIN`** : uniquement pour un réglage qui doit survivre à un redémarrage.
  Un paramètre influençant une fonction de sécurité n'est pas rendu réglable sans exigence
  métier validée, bornage et traçabilité.

---

## 3. Liaison — la vérification qui manquait (REX 2026-07-29)

> ⛔ **Un bundle généré, des tests Python verts ou un XML bien formé ne prouvent JAMAIS
> qu'une fonction est reliée au reste du programme.** Ce sont des preuves de forme.
> Le bug de la barrière finale Outputs a franchi tous ces contrôles.

Quatre faits doivent être **prouvés par recherche**, jamais déduits :

1. L'instance est **déclarée** dans le POU qui doit la porter (`Instance : FB_Xxx;` en `VAR`).
2. L'instance est **appelée** — `Instance(...)` — dans le corps du **même** POU, une fois par scan.
3. Elle n'existe **pas en double** ailleurs (déclaration accidentelle dans un autre POU).
4. Toute référence croisée `AutrePOU.instXxx.Champ` pointe une instance **réellement déclarée**
   dans `AutrePOU`, et un nouveau `PROGRAM` est **référencé dans la configuration de tâche**
   CODESYS sous son nom exact.

🤖 **Ce n'est plus à faire de tête** — c'est mécanique et obligatoire :

```powershell
python TOOLS/AGENT_WORKFLOW/scripts/check_linkage.py --report
```

Le résultat (bloc `Auto-vérification liaison`) est **collé dans la restitution du lot**.
Une restitution sans ce bloc est incomplète, quel que soit l'agent qui l'écrit.

---

## 3bis. Collision de nom avec une variable matérielle (REX 2026-08-05)

> 🚨 **Incident vécu** : `PRG_06_Outputs_LD` déclarait `M3_BrakeRelease_RQ` (et l'équivalent
> M1/M2) en `VAR_OUTPUT` **avec le même nom exact** que la variable globale que CODESYS crée
> lors du mapping E/S physique du device. Un identificateur **local masque toujours un global
> homonyme** (IEC 61131-3) : toute écriture dans ce POU résolvait vers la sortie locale, jamais
> vers la globale réellement mappée au matériel. **Aucune erreur de compilation ni d'import ne
> signale ce piège** — le contacteur frein M3 ne s'est simplement jamais activé, plusieurs
> heures de diagnostic terrain avant identification. Le même schéma touchait aussi la
> **chaîne AU** (`PowerKeepAlive_A_RQ`/`PowerKeepAlive_B_RQ`/`EmergencyArming_RQ`, confirmé
> câblé réel par l'utilisateur) — corrigé dans le même lot. Détail complet et fix :
> `TOOLS/ST_PLCOPENXML_GENERATOR/scripts/gen_prg06_oracle.py` (`_build_actuator_network`
> et `FB_SAFETY_OUTPUT_ASSIGNS`).

**Règle** : un `PROGRAM` ne déclare **jamais** de variable (`VAR`/`VAR_INPUT`/`VAR_OUTPUT`)
portant le **nom exact** d'un point matériel du mapping E/S (`TOOLS/AGENT_WORKFLOW/config/
Device_IO_20260806.csv`, colonne `Mapped variable`) — sauf `PRG_02_Acquisition`, seul POU dont
le rôle architectural est de porter ces noms bruts en `VAR_INPUT` (AF_Partie-06 §1/§4).

Un `FUNCTION_BLOCK` n'est pas concerné : ses paramètres sont toujours référencés via une
instance (`instXxx.Param`), jamais par un nom nu — pas le même risque de collision de portée.

**Raccordement physique correct** : le mapping E/S CODESYS cible le **chemin qualifié**
(`PRG_06_Outputs_LD.TranslationBrakeCmd`, `PRG_06_Outputs_LD.M1RelayFwd`...), jamais un nom nu
qui recréerait la collision.

🤖 **Vérification automatique** :
```powershell
python TOOLS/AGENT_WORKFLOW/scripts/check_hw_name_collision.py .
```
Intégré à `run_all_gates.py` (GATE 2quinquies). Toute nouvelle collision est bloquante (`ERROR`).

---

## 4. Code et variables mortes (base MISRA)

- Toute variable déclarée est **lue au moins une fois** hors de son initialisation.
- Toute instance déclarée est **appelée** (§3) — jamais déclarée « pour plus tard ».
- Une branche inatteignable est **supprimée**, pas commentée.
- Un FB qui n'est plus appelé nulle part sort du programme actif ; s'il reste disponible
  comme POU, c'est documenté explicitement.

---

## 5. POO / encapsulation en IEC 61131-3

- **Une responsabilité par objet.** Le propriétaire d'une donnée est le FB qui l'acquiert, la
  calcule ou garantit sa cohérence. Un bloc safety surveille une mesure ; il n'en devient pas
  le producteur par commodité de câblage.
- **Producteur unique.** Une donnée/commande a **un seul** POU qui l'écrit. Les autres la lisent,
  ne la recalculent pas et ne créent pas de source parallèle.
- **Composition, pas héritage.** Un FB compose d'autres FB en instances privées `VAR`.
  Pas de méthode/propriété ajoutée sans décision d'architecture explicite.
- **Internes privés.** Aucun appelant ne lit ni n'écrit `Instance.VariableInterne`. Le contrat,
  ce sont les `VAR_INPUT`/`VAR_OUTPUT` — et eux seuls.
- **Couplage explicite.** Une GVL n'est jamais un canal de commande informel entre deux POU qui
  devraient se parler par interface typée.
- **Commandes arbitrées avant l'appel.** Une décision combinant plusieurs causes est calculée,
  nommée et documentée par son propriétaire fonctionnel :

```pascal
// ❌ sources fusionnées anonymement à l'interface
Start := HmiButton OR JoystickActive OR CycleRequest;

// ✅ l'arbitre propriétaire choisit, expose, puis appelle
StartArbitrated := ...;
Instance(Start := StartArbitrated);
```

Un `OR` reste légitime pour agréger des **états homogènes** documentés (`AnyError := ErrorM1 OR ErrorM2`).
Il ne doit jamais masquer un arbitrage de commandes ni une priorité safety.

- **Structure (`ST_*`) seulement si les données forment un contrat cohérent** (commande, mesure,
  état, diagnostic). Ni fourre-tout, ni structure pour deux scalaires sans bénéfice.
- **Un programme orchestre**, il ne réimplémente pas la responsabilité d'un FB. Les données
  destinées à d'autres programmes passent par ses `VAR_OUTPUT`, pas par accès direct à une instance interne.

---

## 6. Robustesse numérique

- **Division** : jamais sans garantir le dénominateur non nul (test explicite ou borne de config).
- **Conversion de type** : explicite (`TO_REAL`, `TO_INT`), jamais implicite ; vérifier la plage
  avant une conversion réductrice.
- **Bornage** : toute valeur issue d'un capteur, d'un bus ou de l'IHM est bornée avant usage
  (`LIMIT`), y compris quand la source est « censée » être valide.
- **Temps** : les durées se déclarent en `TIME` nommé, pas en compteurs de cycles implicites.

---

## 7. Organisation d'un POU

```text
En-tête (rôle, doc source, sécurité, dépendances)
Déclarations d'interface (VAR_INPUT / VAR_OUTPUT / VAR_IN_OUT)
Déclarations internes (VAR, VAR CONSTANT)
Initialisation / gates (Enable, PowerContactorEngaged)
Reset sur front
Sécurité et défauts
Logique métier
États et sorties
Diagnostic / IHM
```

En-tête minimal obligatoire :

```pascal
(* ═══════════════════════════════════════════════════════════════
   🎯 Nom du POU — rôle métier
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF_Partie-XX_...md §...
   🛡️ Sécurité : [règle ou domaine concerné]
   🧩 Dépendances : [FB/PRG principaux]
   ═══════════════════════════════════════════════════════════════ *)
```

Commentaires en français, orientés **rôle / raison / risque**. Détail obligatoire sur sécurité,
interlock, temporisation, polarité, ordre d'appel et correction de bug. Pas de commentaire sur
une affectation évidente.

---

## 8. Non-régression

- **Avant** modification : identifier ce qui consomme la fonction/variable touchée (appelants,
  IHM, diagnostics, tests).
- **Après** : vérifier que chaque consommateur identifié tient toujours (types, noms, signature).
- Un renommage ou un déplacement de responsabilité se fait **atomiquement** avec ses appelants.
- Un changement de comportement de sécurité (`SafeStop`, `Enable`, `Reset`, timeouts) est comparé
  explicitement au comportement documenté avant d'être accepté.

---

## 9. Alarmes et défauts — condition vs acquittement (REX 2026-08 AU)

> 🚩 Pattern absent depuis le début du projet, formalisé après incident `EmergencyArmingFailed`
> (Reset conditionné → blocage opérateur). Basé sur ISA-18.2 (gestion d'alarmes industrielles).

Deux catégories de défaut, **jamais mélangées dans la même variable** :

| Catégorie | Comportement | Exemple |
|---|---|---|
| **Info / Warning** | S'affiche et s'efface **seule** avec la cause. Jamais d'acquittement, aucun `Reset` impliqué. | `BypassOperatorComm actif` |
| **Fault (à acquitter)** | Nécessite un geste opérateur conscient (`Reset`) pour être effacée, **même si la cause a disparu**. Si la cause **revient après acquittement**, l'alarme réapparaît et redemande un acquittement. | `EmergencyArmingFailed`, `SlackCableDetected` |

### Le Reset n'est jamais conditionné

```pascal
// ❌ Reset conditionné par un état externe — bloque l'acquittement lui-même
IF ResetEdge.Q THEN
    IF PowerContactorEngaged THEN
        EmergencyArmingFailed := FALSE;
    END_IF;
END_IF;
```

```pascal
// ✅ Pattern Cause / Ack — Reset TOUJOURS effectif, jamais conditionné
CauseEdge(CLK := EmergencyArmingFailedCause);   // R_TRIG : nouvelle apparition de la cause
IF CauseEdge.Q THEN
    EmergencyArmingFailedAck := FALSE;          // nouvelle occurrence -> ack remis à zéro (ré-alarme)
END_IF;
IF ResetEdge.Q THEN
    EmergencyArmingFailedAck := TRUE;           // toujours effectif, sans condition externe
END_IF;

EmergencyArmingFailed := EmergencyArmingFailedCause OR NOT EmergencyArmingFailedAck;
```

- `<Nom>Cause` = condition brute (l'événement ou la mesure qui a déclenché).
- `<Nom>Ack` = accusé de réception opérateur, remis à `FALSE` automatiquement au prochain front de cause.
- Un interlock de sécurité (ex : interdiction de redémarrage) se base **toujours sur la cause brute**,
  jamais sur l'état d'acquittement — l'acquittement n'ouvre jamais un interlock de sécurité par lui-même.

### Temporisation d'affichage IHM (anti-clignotement, pas de délai sur l'action)

L'**action de sécurité** reste instantanée (coupure, interdiction de mouvement...). Seul
**l'affichage IHM** de la cause peut être retardé par un `TON` court (typiquement `T#0ms` à `T#500ms`,
valeur en `VAR CONSTANT` documentée) pour éviter qu'un opérateur qui acquitte pendant que la
cause est encore présente voie l'alarme reclignoter immédiatement — le délai laisse le temps de
constater visuellement que le problème revient plutôt qu'un affichage figé permanent.

```pascal
// Action de sécurité : instantanée sur la cause brute, jamais retardée
SafeStopRequest := EmergencyArmingFailedCause OR ...;

// Affichage IHM uniquement : lissage anti-clignotement
TonDisplayDebounce(IN := EmergencyArmingFailedCause, PT := CST_FaultDisplayDebounce);
EmergencyArmingFailedDisplayed := TonDisplayDebounce.Q OR NOT EmergencyArmingFailedAck;
```

## 10. Orchestration ST pur (`.st`) — REX 2026-08 (Remplace CFC XML)

> 📌 **Décision d'architecture (Urgence Projet)** : L'orchestration par diagrammes graphiques CFC (`.xml`) est remplacée par du **Texte Structuré ST pur (`.st`)** pour tous les programmes d'orchestration (`PRG_02_Acquisition`, `PRG_03_Modes_Cycle`, `PRG_04_Treuils_Benne`, `PRG_05_Translation`, `PRG_07_Supervision`).

Règles obligatoires pour tout programme d'orchestration ST :

1. **Sections structurées avec emojis** : Chaque programme ST d'orchestration doit obligatoirement découper son flux de haut en bas avec des bannières commentées explicites (ex: `// === 📥 §1 ACQUISITION ===`, `// === 🛡️ §2 SÉCURITÉ ===`, `// === 🔀 §3 ARBITRAGE ===`).
2. **Aucune logique métier inline** : Le POU ST ne contient aucun `IF` complexe ni calcul métier — uniquement des instanciations et des appels de FB avec liaison par structures DUT publiques (`ST_*`).
3. **Producteur unique par bus DUT** : Les échanges inter-programmes passent par des structures typées dédiées (`Auth`, `Qualified`, `Measurements`).
4. **Conservation du Ladder Diagram (`_LD.st`)** : La barrière finale des sorties physiques TOR
   (`PRG_06_Outputs_LD.st`) reste exclusivement en Ladder Diagram (`<LD>`). `PRG_01_Inputs_LD`
   et `FB_Input` sont des composants historiques en retrait ; aucune nouvelle page Ladder d'entrée
   ne doit être créée.

## 11. Règles de génération Ladder (`_LD.st` → `<LD>`) — REX 2026-08

> 🚩 Trois bugs d'import CODESYS sur l'ancien `PRG_01_Inputs_LD` ont révélé que le générateur
> ST→LD (`TOOLS/ST_PLCOPENXML_GENERATOR/generator/ld_builder.py`) produisait du
> PLCopenXML invalide. Les règles ci-dessous restent obligatoires pour toute
> source `_LD.st` active, notamment `PRG_06_Outputs_LD`, et sont vérifiées par `test_ld_import_guard.py`.

### Structure d'un rung LD complet

Un programme suffixe `_LD` est converti en `<LD>` dans le bundle PLCopenXML.
Chaque rung doit contenir la **chaîne complète** :

```text
leftPowerRail → contact → block(FB) → coil → rightPowerRail
```

CODESYS **rejette** les rungs incomplets (sans coil, sans rightPowerRail).

### Règles de câblage FB

| FB | Contact principal | Sortie → coil |
|---|---|---|
| `FB_Output` | `Command` (contact) | `.State` → coil |
| `FB_Input` historique | Aucun nouveau câblage | Retrait contrôlé, pas de nouveau rung |

- Le **contact principal** (`InputRaw` ou `Command`) est relié au
  `leftPowerRail` puis au `formalParameter` du block.
- La **coil** est reliée à la sortie `State` du block (`formalParameter="State"`).
- Les paramètres supplémentaires (`FilterTime`, `InvertLogic`)
  ne sont **pas** représentés en LD — seuls les paramètres BOOL sont câblés
  comme contacts ; les paramètres typés (TIME, INT…) restent des `inVariable`
  dans la section multi-paramètres du générateur.

### Expressions BOOL

| Expression | Rendu LD |
|---|---|
| `var` (BOOL connu) | contact `negated="false"` |
| `NOT var` (BOOL connu) | contact `negated="true"` |
| `var1 AND var2` | série de contacts |
| `var1 OR var2` | parallèle de contacts |
| Expression typée non-BOOL | `inVariable` → `outVariable` (hors page BOOL pure) |

- **`NOT var` ne produit jamais d'`inVariable`/`outVariable`** pour un signal
  BOOL. Un `inVariable` en page LD BOOL pure est un bug d'import.
- Une page `_LD` de type BOOL pur (notamment `PRG_06_Outputs_LD`) ne doit contenir
  **aucun** `inVariable` ni `outVariable` — uniquement des `contact`, `coil`,
  `block` et `comment`.

### Tests de régression

```powershell
python -m pytest TOOLS/AGENT_WORKFLOW/tests/test_ld_import_guard.py -v
```

Les tests couvrent les rungs LD actifs, les contacts inversés, l'absence d'inVariable/outVariable
sur les pages BOOL et la coil reliée à `.State` pour chaque block actif. `FB_Input` historique ne
fait plus partie des nouveaux contrats LD.

## 12. Checklist de restitution (bloquante)

```text
[ ] check_linkage.py --report = PASS, bloc collé dans la restitution
[ ] check_doc_links.py = PASS (aucun lien mort, aucune version périmée)
[ ] check_hw_name_collision.py = PASS (aucune variable PRG_* homonyme d'un point Device_IO, §3bis)
[ ] Nommage conforme DOC/STDS/NAMING_CONVENTION.md
[ ] Aucune variable/instance déclarée non utilisée
[ ] Aucun nombre magique ; constantes nommées
[ ] Producteur unique par donnée ; aucune GVL de commande cachée
[ ] Contrat FB respecté (AF_Partie-03)
[ ] Non-régression : appelants/IHM/diagnostics identifiés et mis à jour
[ ] Défaut à acquitter : Reset jamais conditionné (§9) ; Warning auto-effaçable distingué du Fault
[ ] Orchestration ST pur (.st) : découpage par sections commentées avec emojis, zéro logique métier inline, contrats DUT raccordés (§10)
[ ] Devoir d'alerte : toute ambiguïté signalée AVANT d'écrire, pas après
```

---

## 📖 Comment ce document vit

- `AGENTS.md` (point d'entrée unique) y renvoie au même niveau que `NAMING_CONVENTION.md`.
- `.claude/skills/codesys-workflow.md` **applique** ce référentiel, ne le recopie pas.
- `TOOLS/AGENT_WORKFLOW/docs/CODE_WRITING_POLICY.md` renvoie ici pour §POO et §organisation.
- Les prompts de sous-agents Pi le citent via `TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md`.
- Toute règle ajoutée ici après un incident vient **avec son garde-fou** dans
  `TOOLS/AGENT_WORKFLOW/scripts/` (règle `fix:` + `guard:`, `docs/WORKFLOW.md`).

Sources : *Clean Code* (R. C. Martin), MISRA C:2012 (dead code / unused variables), principes
SOLID, conventions IEC 61131-3. Amendable par tout agent disposant d'une recherche externe réelle —
indiquer la source ajoutée.
