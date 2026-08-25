# Convention de Nommage — Projet Excavatrice Dragage
 
## Principes
- **Sans hongrois** : le type se lit dans la déclaration, pas dans le nom.
- **Sémantique** : le nom décrit le rôle, l'unité ou l'état.
- **PascalCase** partout. Abréviations anglaises courtes acceptées.
- **Suffixes d'unité** : seule exception aux abréviations (pour lever ambiguïtés métier).

---

## 🧪 Points de validation

> Distincts des `TC-Pxx-nnn` des AF (comportement machine) : ici, vérification du **nommage**
> lui-même. Numérotation `NC-nnn` par pas de 10, immuable (même règle que `TC-`, voir
> `CODE_QUALITY_STANDARDS.md §0`). `🤖 AUTO` = mécaniquement vérifiable en regex (candidat au
> script de lint nommage évoqué le 2026-08-12) ; `👁️ MANUEL` = jugement sémantique, pas
> automatisable.

| ID | Intention | Preuve | Type | Réf |
|---|---|---|---|---|
| <nobr><code>NC-010</code></nobr> | Instance de FB préfixée `inst<Rôle>` | Déclaration `<Nom> : FB_Xxx` — nom commence par `inst` | 🤖 AUTO | §Préfixes structurels |
| <nobr><code>NC-020</code></nobr> | Pas de notation hongroise (`bFlag`, `iCounter`, `rValue`) | Aucun nom débutant par `b`/`i`/`r` minuscule suivi d'une majuscule | 🤖 AUTO | §Principes |
| <nobr><code>NC-030</code></nobr> | Suffixe d'unité précédé d'un underscore (`_M`, `_Pct`, `_Hz`, `_Ms`, `_Mps`) | Toute variable finissant par une unité connue respecte le `_` | 🤖 AUTO | §Suffixes d'unité |
| <nobr><code>NC-040</code></nobr> | `_DI`/`_DQ`/`_RQ` jamais redéclaré comme variable locale hors `PRG_02_Acquisition` | Déjà couvert par `G350_check_hw_name_collision.py` (GATE 2quinquies) | 🤖 AUTO (existant) | `CODE_QUALITY_STANDARDS.md §3bis` |
| <nobr><code>NC-050</code></nobr> | `Cmd`/`Req` toujours en préfixe sur une **nouvelle** variable, jamais en suffixe | Aucune nouvelle occurrence `XxxCmd`/`XxxReq` hors baseline legacy | 🤖 AUTO | §`Req` vs `Cmd` |
| <nobr><code>NC-060</code></nobr> | `ST_*HMI` : préfixes `Btn`/`Sel`/`Set`/`Tgl`/`Cfg`/`Tst` sans underscore après le préfixe, jamais `Cmd`/`Req` dedans | Champs des structs `ST_*HMI` respectent `<Préfixe><PascalCase>` | 🤖 AUTO | §Variables IHM |
| <nobr><code>NC-070</code></nobr> | Variable `PERSISTENT` préfixée `_` | Déclaration dans `GVL_PERSISTENT.st` commence par `_` | 🤖 AUTO | §Variables globales persistantes |
| <nobr><code>NC-080</code></nobr> | Repère matériel (M1/M2/M3) juste après le préfixe dans une GVL plate | Motif `<Préfixe><Repère><Fonction>` respecté | 👁️ MANUEL | §Repère juste après le préfixe |
| <nobr><code>NC-090</code></nobr> | Une notion = un seul nom dans tout le projet (pas de synonyme parallèle) | Revue sémantique, pas mécanisable | 👁️ MANUEL | `CODE_QUALITY_STANDARDS.md §1` |
| <nobr><code>NC-100</code></nobr> | Polarité positive des arbitrages `*Permit`/`*Allowed` : `TRUE` = autorisé, `FALSE` = bloqué | Tout signal d'arbitrage répond à « que signifie `TRUE` ? » = autorisation positive ; jamais d'`OR` d'autorisations | 👁️ MANUEL | §Polarité positive des arbitrages (T109) |

---
 
## Préfixes structurels (classification, non typage)
| Préfixe | Usage | Exemple |
|---------|-------|---------|
| `ST_` | Struct de données | `ST_Safety_Emergency_State`, `ST_Winch_State` |
| `E_` | Enum / énumération | `E_Mode`, `E_State`, `E_CycleStep` |
| `FB_` | Function Block (type) | `FB_Joystick`, `FB_Winch` |
| `inst` | Instance d'un FB (variable) | `instJoystick`, `instWinchM1`, `instModes` |
| `PRG_` | Programme (POU principal) | `PRG_02_Acquisition`, `PRG_06_Outputs` |

### Tags de Rôle & Flèches de Flux en Déclaration ST (Fenêtre Watch CODESYS)

Dans la partie déclaration des fichiers `.st`, chaque variable est documentée en fin de ligne par sa flèche ASCII de flux et son tag de sous-domaine (*voir `CODE_QUALITY_STANDARDS.md §2`*) :

| Tag | Sens Flux | Usage | Exemple |
|---|---|---|---|
| `[CMD]` | `-->` (Entrée) | Commande / Consigne opérateur ou POU amont | `Direction : INT; // --> [CMD] Sens (-1,0,1)` |
| `[CFG]` | `-->` (Entrée) | Paramètre de configuration / Seuil / Tempo | `CfgMaxStep : INT; // --> [CFG] Plafond palier` |
| `[HW]` | `-->` (Entrée) | Retour matériel / Capteur physique TOR-ANA | `Homed : BOOL; // --> [HW] Etat reference` |
| `[SAFE]`| `-->` (Entrée) | Permis de sécurité / Câblage verrous | `DescendPermit : BOOL; // --> [SAFE] Permis descente` |
| `[TST]` | `-->` (Entrée) | Forçage simulation / Bypass de test | `BypassGlobal : BOOL; // --> [TST] Bypass defauts` |
| `[STAT]`| `<--` (Sortie) | État IEC / Synoptique public | `Ready : BOOL; // <-- [STAT] FB pret` |
| `[ACT]` | `<--` (Sortie) | Ordre vers actionneur physique (Contacteur/Relais) | `RelayFwd : BOOL; // <-- [ACT] Contacteur montee` |
| `[DIAG]`| `<--` (Sortie) | Code défaut / Mesure d'exploitation / Miroir | `ErrorId : WORD; // <-- [DIAG] Code defaut` |
| `[BUS]` | `<->` (InOut) | Structure ou bus bidirectionnel | `HmiBus : ST_HMI; // <-> [BUS] Bus IHM` |
| `[INST]`| `*` (Interne) | Sous-instance de Function Block | `SpeedStep : FB_SpeedStep; // * [INST] Decodage` |
| `[LOC]` | `.` (Interne) | Variable locale interne (Timer, Trigger, Calcul) | `ResetEdge : R_TRIG; // . [LOC] Front Reset` |

*(⚠️ **Ne jamais utiliser `[INT]`** comme tag pour éviter toute confusion avec le type IEC `INT`).*

### Structures de données (DUT) — Convention hiérarchique

```text
ST_<Domaine>_[<SousDomaine>_]<Rôle>
```

Pour regrouper naturellement les types dans l'autocomplétion CODESYS et les fenêtres Watch :
- **Préfixe** : `ST_` (séparé par `_`)
- **Domaine** : `Safety`, `Winch`, `Translation`, `Encoder`, `Modes`, `Cycle`, `Commun` (séparé par `_`)
- **SousDomaine** (optionnel) : `Emergency`, `M1`, `M2`, `M3`, `Bucket` (séparé par `_`)
- **Rôle** : `Cmd`, `State`, `Diag`, `HmiCmd`, `HmiState`, `InternalCmd`, `TestContext`

**Exemples conformes :**
- `ST_Safety_Emergency_State` (État public arrêt d'urgence)
- `ST_Safety_Emergency_Diag` (Diagnostic arrêt d'urgence)
- `ST_Safety_Emergency_InternalCmd` (Commande interne Logic → Output)
- `ST_Safety_Emergency_HmiCmd` (Commandes IHM)
- `ST_Safety_Emergency_HmiState` (Retours état IHM)

### Programmes (POU principaux) — architecture cible

| Suffixe | Langage bundle | Source versionnee | Rôle | Exemple |
|---------|----------------|-------------------|------|---------|
| (sans suffixe) | Structured Text (`<ST>`) | `.st` | Orchestration ST par procédé, câblage d'instances FB par bus DUT | `PRG_02_Acquisition.st`, `PRG_04_Treuils_Benne.st` |
| `_LD` | Ladder Diagram (`<LD>`) | `.st`, converti automatiquement en Ladder dans le bundle | Barrière finale des sorties physiques TOR | `PRG_06_Outputs.st` |

**Règles :**
- Tout programme est préfixé `PRG_XX_` : la numérotation fixe l'ordre exact d'exécution dans la `MainTask` (décidé dans `AF_Partie-02`).
- Les programmes d'orchestration procédés sont rédigés en **Texte Structuré ST (`.st`)** pour maximiser la vitesse d'implémentation et la lisibilité textuelle.
- **Organisation en sections commentées avec emojis dans le ST** : Chaque programme ST d'orchestration doit structurer son flux de manière limpide de haut en bas (ex: `// === 📥 §1 ACQUISITION ===`, `// === 🛡️ §2 SÉCURITÉ ===`, `// === 🔀 §3 ARBITRAGE ===`). Les sections de responsabilité distinctes d'un POU ST sont repliables avec `{region "§N Rôle fonctionnel"}` / `{endregion}` ; le commentaire reste visible dans le source et la recherche texte.
- **Aucune logique métier inline** dans les POU `PRG_` ST : l'orchestration ne contient ni `IF` complexe ni calcul métier — uniquement des instanciations de FB et des câblages par bus DUT (`ST_*`).
- Les programmes `_LD.st` restent convertis automatiquement en `<LD>` pour la barrière finale des sorties
  (`PRG_06_Outputs.st`). `PRG_01_Inputs_LD.st` est une couche historique en retrait.

### Noms cibles des programmes — aucun renommage sans lot dedie

> 🗺️ **Cette table ne decide rien : elle recopie la cible de `AF_Partie-02` §2 et §4**, seule
> source de l'architecture. Elle sert uniquement a fixer l'orthographe des noms.
> Le decoupage est fait **par ensemble mecanique**, pas par couche transverse : chaque procede
> porte sa safety dans sa propre page. Décision reportée dans `AF_Partie-02` §2/§4 ; historique archivé (`ARCHIVES/Doc/AUDITS/Architecture_Migration7POU/`).

| Rang | Nom cible | Langage / source |
|---|---|---|
| 01 | `PRG_02_Acquisition` | `.st` ST pur (acquisition unique HwReal/HwSim/HwIn) |
| — | `PRG_01_Inputs_LD` | `.st` converti en `<LD>` historique, retrait contrôlé |
| 02 | `PRG_03_Modes_Cycle` | `.st` ST pur (Orchestration Modes & Cycle) |
| 03 | `PRG_03_Modes_Cycle` | `.st` ST pur (Orchestration Modes & Cycle) |
| 04 | `PRG_04_Treuils_Benne` | `.st` ST pur (Orchestration Levage/Treuils) |
| 05 | `PRG_05_Translation` | `.st` ST pur (Orchestration Translation) |
| 06 | `PRG_06_Outputs` | `.st` converti en `<LD>` (Ladder Sorties) |
| 07 | `PRG_07_Supervision` | `.st` ST pur (Supervision / Lecture seule) |

🚫 **Noms abandonnes comme cibles** — ne pas les reintroduire dans une table de nommage :
`PRG_01_Acquisition_CFC`, `PRG_02_Inputs_LD`, `PRG_03_Modes_CFC`, `PRG_04_Safety_CFC` (ou toute
page safety separee des mouvements), `PRG_05_Cycle`, `PRG_06_Treuils_CFC`, `PRG_07_Translation_CFC`,
`PRG_10_Outputs_LD`, `PRG_11_Troubleshooting`.

### POU actuels — correspondance vers la cible

Les POU ci-dessous existent dans `CODE/MAIN` et gardent leur nom **jusqu'a leur lot de migration**.
Aucun n'est un nom cible : ils sont absorbes par la page du procede correspondant.

| POU actuel | Absorbe par |
|---|---|
| `PRG_INPUTS_LD` | retrait contrôlé : qualification absorbée par `PRG_02_Acquisition` |
| `PRG_ACQUISITION_CFC`, `PRG_01_Diagnostics`, `PRG_02_Encoders`, `PRG_AUXILIARY_CFC` | `PRG_02_Acquisition` |
| `PRG_MODES_CFC`, `PRG_05_Cycle` | `PRG_03_Modes_Cycle` |
| `PRG_TREUILS_CFC` + partie M1/M2/benne de `PRG_SAFETY_CFC` | `PRG_04_Treuils_Benne` |
| `PRG_TRANSLATION_CFC` + partie M3 de `PRG_SAFETY_CFC` | `PRG_05_Translation` |
| `PRG_OUTPUTS_LD` | `PRG_06_Outputs` |
| `PRG_SUPERVISION_CFC`, `PRG_TROUBLESHOOTING_CFC` | `PRG_07_Supervision` |

⛔ **Aucun renommage, fusion ou conversion ne demarre sans lot dedie** : chaque etape
exige le remappage complet des consommateurs avant suppression de l'ancien producteur, un
producteur unique a tout instant, et une preuve de liaison. La renumérotation 7 POU
(`PRG_02`→`PRG_07`) est **soldée** ; la conversion CFC natif est **abandonnée** (code en ST +
PLCopenXML). Historique : `ARCHIVES/Doc/AUDITS/Architecture_Migration7POU/`.

### Instances FB — Règle d'Ingénierie & Hiérarchie

Le nommage des instances privilégie la **sémantique métier** et la lisibilité sans alourdissement dogmatique :

1. **Primitives système & IEC (`TON`, `TOF`, `R_TRIG`, `F_TRIG`, `HYSTERESIS`)** :
   - 🚫 **Jamais de préfixe `inst`**.
   - ✅ Rôle sémantique + suffixe standard : `ResetEdge : R_TRIG;`, `BrakeTimeout : TON;`, `Hyst1 : HYSTERESIS;`.

2. **Composition interne dans un FB (Micro-composants POO)** :
   - 🚫 **Pas de préfixe `inst`** (évite le bruit visuel dans le corps du bloc).
   - ✅ Rôle fonctionnel direct : `ScaleX : FB_AxisScale;`, `FilterY : FB_Filter_PT1;`, `OutputLogic : FB_Safety_EmergencyManagementOutput;`.

3. **Organes répliqués / Multi-instances métier** :
   - ✅ Nom explicite de l'organe physique : `WinchM1 : FB_Winch;`, `WinchM2 : FB_Winch;`, `HomingM1 : FB_Encoder_Homing;`.

4. **Singletons au niveau `PROGRAM` (`PRG_02` à `PRG_07`)** :
   - ✅ Préfixe **`inst`** + rôle PascalCase pour isoler la portée et éviter toute collision de nom avec les GVL/DUT : `instJoystick : FB_Joystick;`, `instModes : FB_Modes;`, `instCycleSemiAuto : FB_Cycle;`, `instTranslationM3 : FB_Translation;`.
   - ❌ Pas `FB_Joystick_0`, pas le nom du type seul, pas de suffixe `_0` d'export.
  
---
 
## Abréviations autorisées

⚠️ Liste vérifiée sur `CODE/` (2026-07-15, grep exhaustif) — certaines abréviations
historiquement documentées n'étaient en réalité **jamais utilisées** (le code préfère le mot
complet) : retirées de la liste "autorisée", déplacées en "à éviter" ci-dessous.

### Rôle / catégorie
| Abrév. | Sens | Exemple réel dans `CODE/` |
|---|---|---|
| `Cmd` | Commande (signal final vers actionneur/bus — Niveau 2, préfixe) | `CmdReset`, `CmdOpen`/`CmdClose` (Bucket), `BrakeCmd` (legacy, suffixe) |
| `Req` | Requête brute, pas encore arbitrée (Niveau 2, préfixe) | `OpenReq`/`CloseReq` (legacy, suffixe) — voir §`Req` vs `Cmd`, pas de préfixe `Req` en usage actuellement |
| `Ref` | Consigne | `SpeedRef`, `CablePosRef`, `RefPosM` |
| `Act` | Valeur mesurée/actuelle | `SpeedAct`, `CablePosAct` |
| `Diag` | Diagnostic | `FB_Diag_CanOpen`, `FB_Diag_Ethercat`, `ST_Diag_Device` |
| `Calc` | Calcul / calculateur (nom d'instance) | `CycleTimeCalc` (instance de `FB_CycleTime`) |
| `Fwd` / `Rev` | Avant / Arrière (forward/reverse) | `RelayFwd`, `LimitSwitchFwd`, `BtnFwd` |
| `Min` / `Max` | Limite basse / haute | `MaxStepDescente`, `LimitLegalDepthMinAllowed` |
| `Pos` | Position — coexiste avec la forme complète (les deux existent dans le code, pas de règle stricte) | `CablePos_M`, `TranslationPosP1` **et** `Position_M`, `PositionSensorTarget` |

### ⚠️ Dans l'ancien doc mais PAS utilisées dans le code — préférer le mot complet
| Abrév. (à éviter) | Toujours écrire |
|---|---|
| `En` | `Enable` |
| `Rdy` | `Ready` |
| `Err` | `Error` / `ErrorId` |
| `Sts` | `State` (ou `Ready`/`Busy`/`Done`/`Error` directement, pas de préfixe générique — voir Niveau 2) |
| `Spd` | `Speed` |
| `Lim` | `Limit` (ex. `LimitSwitchFwd`, jamais `LimSwitchFwd`) |

### Suffixes hardware `_DI`/`_DQ`/`_RQ` — mapping I/O physique, différent du `ReqX` (Niveau 2)
Trois suffixes déjà établis pour les variables globales **mappées directement sur le matériel**
(hors struct IHM, hors `ReqX`/`CmdX` qui restent au niveau logique) :

### 🧭 E/S TOR : polarité lisible dans le nom (REX C1 — 2026-07-27)

Pour chaque nouveau point TOR, le nom répond sans schéma à « que signifie `TRUE` ? » :

```
<Domaine>_<ÉtatQuandTRUE>_DI      M1_BrakeIsOpen_DI   → TRUE = frein ouvert
<Domaine>_<ActionCommandée>_RQ    M1_BrakeRelease_RQ  → TRUE = desserrage commandé
```

🚫 Éviter les noms muets (`Feedback`, `Status`, `Ok`) seuls lorsqu'ils ne donnent pas la polarité.
Le bug C1 (retour frein) a démontré qu'une polarité implicite peut masquer un défaut réel.
Source et cas existants : `AUDITS/PreLivraison/TABLE_Renommage_IO_v1.0.md`.

| Suffixe | Sens | Exemple |
|---|---|---|
| `_DI` | **D**igital **I**nput — entrée digitale brute, point I/O physique | `M1_BrakeFeedback_DI`, `M3_PosTremie_DI`, `PowerContactorEngaged_DI` |
| `_DQ` | **D**igital **Q** — sortie digitale, point I/O physique final (après `FB_Output`) | `M1_RelayFwd_DQ`, `M3_RelayFwd_DQ` |
| `_RQ` | Sortie **relais** — requête maintenue logicielle, juste avant `_DQ`/le contacteur, OU variable terminale mappée directement au device quand aucun `_DQ` intermédiaire n'existe | `M1_BrakeRelease_RQ`, `M3_BrakeRelease_RQ` |

🚨 **Un `_DI`/`_DQ`/`_RQ` est un nom de point matériel réel** (`TOOLS/AGENT_WORKFLOW/config/Device_IO_*.csv`, le plus récent) — ne
**jamais** redéclarer ce nom exact comme variable locale d'un `PROGRAM` (collision de portée
IEC 61131-3, REX 2026-08-05 : `DOC/STDS/CODE_QUALITY_STANDARDS.md §3bis`). Seul `PRG_02_Acquisition`
porte ces noms bruts, en `VAR_INPUT`.

⚠️ **Contre-exemple — polarité inversée dans le nom** : `PowerCutOff_A_RQ`/`PowerCutOff_B_RQ`
(`FB_Safety_EmergencyManagement`) valent `TRUE` quand il n'y a **aucune** coupure (maintien
sain) — un nom contenant « CutOff » pour dire « je ne coupe pas » contredit directement la
règle C1 ci-dessus (« le nom répond à que signifie TRUE »). Renommage identifié, pas encore
fait (voir `PLAN_TASK_v1.0.md`) — **ne pas reproduire ce nom sur un nouveau composant**.

Ne pas confondre avec `ReqX` (préfixe, requête **opérateur** dans un struct `ST_*HMI`, niveau
IHM) — deux familles à deux niveaux d'architecture différents : `_DI`/`_DQ`/`_RQ` = I/O
physique/matériel, `ReqX`/`CmdX` = logique métier/IHM.

---
 
## Nommage par catégorie
 
### Entrées de commande
```
Enable, Reset
StartStop            → BOOL : TRUE = rampe accélération, FALSE = rampe décélération normale
                        (FB de mouvement uniquement — Winch, Translation)
```

### Entrées sécurité / contexte
```
SafeStop             → BOOL : sortie d'un bloc safety MÉTIER, consommée en entrée
                        par les FB de mouvement de son domaine (1 SafeStop par métier,
                        pas de signal global unique). TRUE = rampe décélération RAPIDE.
                        Enable reste actif pendant SafeStop (≠ neutralisation).
PowerContactorEngaged       → BOOL : chaîne de sécurité AU (arrêt d'urgence) réarmée / OK,
                        ou retour contacteur de puissance (source à définir par métier).
                        Anciennement nommé SafetyOk — renommé pour éviter l'ambiguïté
                        avec SafeStop.
Mode                  → E_Mode courant (autorisations)
```

> 🧭 **Hiérarchie de précédence** (du plus fort au plus faible) : `Enable` > `SafeStop` > `StartStop`.
> - `Enable = FALSE` → FB désactivé, **toutes les sorties coupées** (neutralisation dure).
> - `SafeStop = TRUE` (Enable actif) → **rampe de décélération rapide** (défaut process).
> - `StartStop = FALSE` (Enable actif, pas de SafeStop) → **rampe de décélération normale** (arrêt demandé).

### 🔒 Polarité des booléens I/O : sécurité vs information vs commande

Trois familles, ne pas les confondre — c'est précisément ce qui a coûté une session de débogage
complète sur ce projet (voir incident ci-dessous).

| Famille | Convention | Exemples | Pourquoi |
|---|---|---|---|
| **Capteur de sécurité** (entrée brute, suffixe `Ok` ou assimilé fail-safe) | `TRUE` = état OK/nominal ; `FALSE` = défaut | `PowerContactorEngaged`, `GVL_IN.SlackCableSwitch`, `GVL_IN.PhaseRotationOk`, `GVL_IN.TopPositionSensor` (sain si non atteint), `GVL_IN.DriveFaultOk` | Câblage NF/energized-to-run : une coupure de câble ou un contact ouvert retombe naturellement à `FALSE` → détecté comme défaut sans câblage supplémentaire. |
| **Information / état classique** (entrée brute) | `FALSE` = repos ; `TRUE` = capteur atteint/déclenché | `M3_PosTremie_DI`/`PosPV_DI`/`PosP2_DI`/`PosP1_DI`/`PosMaintenance_DI` (ex-Fosse1/Fosse2, renommés 2026-07-18) | Logique directe : "je suis arrivé à la position" = `TRUE`. Pas d'enjeu fail-safe. |
| **Sortie de COMMANDE / AUTORISATION d'un bloc Safety** (calculée) | `SafeStop` / `PowerCutOff` : `TRUE` = **déclenche** l'action d'arrêt.<br>`AscentPermit` / `DescendPermit` : `TRUE` = **mouvement autorisé**, `FALSE` = **bloqué** (défaut/fail-safe). | `SafeStop`, `PowerCutOff`, `AscentPermit`, `DescendPermit` (décision T109/T112 — remplace les anciens `Forbid*`) | Cohérence fail-safe : la rupture de liaison ou la désactivation d'un FB passe naturellement les autorisations de mouvement à `FALSE`. |

📖 **Deux incidents réels** ont fondé ces règles (SafeStop forcé manuellement · `SlackCableSwitch`
câblé sans inversion · `PhaseRotationOk` non initialisé) : récits complets dans
[`ARCHIVES/Doc/AUDITS/REX_Nommage_v1.0.md`](AUDITS/REX_Nommage_v1.0.md).

🚫 **Règle** : ne JAMAIS forcer manuellement une sortie de COMMANDE/AUTORISATION (`SafeStop`, `AscentPermit`, `DescendPermit`,
`PowerCutOff`) — elle est TOUJOURS calculée par son bloc Safety. Pour un test banc, forcer
l'entrée CAPTEUR en amont, jamais la sortie de commande.

**Règle à appliquer systématiquement** (famille "capteur de sécurité" UNIQUEMENT — ne s'applique
PAS aux sorties de commande, qui ne s'initialisent pas, elles se calculent) : toute variable de la
famille "sécurité" (suffixe `Ok`, ou toute entrée capteur consommée par un `FB_Safety_<Metier>`)
doit être **initialisée explicitement à `TRUE`** dans sa déclaration (`VAR_GLOBAL`/`VAR_INPUT`),
jamais laissée à la valeur par défaut du langage — sinon un capteur "pas encore câblé" se lit
comme "défaut détecté". La famille "information classique" n'a pas ce besoin : son repos naturel
(`FALSE`) est déjà la bonne valeur par défaut.

### 🔐 Polarité positive des arbitrages — `*Permit` / `*Allowed` (T109)

**Règle absolue pour TOUT signal d'arbitrage** (permission, autorisation, interlock, gate) :
`TRUE` = **mouvement/action autorisé(e)**, `FALSE` = **bloqué(e)**. C'est la **polarité positive
fail-safe** : une liaison rompue, un FB désactivé (`Enable=FALSE`) ou un bloc non calculé retombe
naturellement à `FALSE` → aucune action n'est possible sans une autorisation **explicitement
positive**. On ne passe jamais à travers un `NOT Permit` pour autoriser.

Les noms portent le suffixe sémantique `*Permit` (autorisation calculée, famille "sortie de
commande") ou `*Allowed` (état/predicat consommé par une chaîne diag/IHM — voir `Idx401_MotionAllowed`,
`Step6_DirectionAllowed`, `Step5_ArmingAllowed`).

#### Taxonomie `Permit` de l'arbitrage treuils (D-P1 → D-P11, `PRG_04_Treuils_Benne`)

L'arbitrage distingue **jusqu'à 4 niveaux** de permission, tous en polarité positive. ⚠️ **La
chaîne est ASYMÉTRIQUE** (vérifié code, revue 2026-08-24) : le niveau **Process** n'existe que
pour la **descente** ; la **montée** passe **Safety → Effectif directement** (pas de Process).
Ne pas inventer un `ProcessPermit*_Ascent` — ces variables **n'existent pas** à l'usage réel
(2 mortes à retirer, voir question).

| Sens | Chaîne réelle |
|---|---|
| **Descend** | `SafetyPermit<M>_Descend` → `ProcessPermit<M>_Descend` → `ProcessAndSafetyPermit<M>_Descend` → `EffectivePermit<M>_Descend` |
| **Ascent** | `SafetyPermit<M>_Ascent` → **`ProcessAndSafetyPermit<M>_Ascent`** (sans étage Process) → `EffectivePermit<M>_Ascent` |

| Niveau | Nom | Sémantique | Production |
|---|---|---|---|
| 1. Safety | `SafetyPermit<Repère>_<Sens>` | Autorisation **safety pure** (limites, contacteur, chaîne) | sortie d'un `FB_Safety_<Metier>` (`AscentPermit`/`DescendPermit`) |
| 2. Process (descente) | `ProcessPermit<Repère>_Descend` | Autorisation **process pur** (interlocks de séquence, benne, trémie) — descente uniquement | logique de séquence / interlock |
| 3. Combiné | `ProcessAndSafetyPermit<Repère>_<Sens>` | `SafetyPermit AND ProcessPermit` (descente) **ou** `SafetyPermit` seul (montée) | nœud de fusion explicitement nommé |
| 4. Effectif | `EffectivePermit<Repère>_<Sens>` | Combiné + couplage synchro (anti-télescopage) | alimente l'entrée `AscentPermit`/`DescendPermit` du FB de mouvement |

```
EffectivePermit = ProcessAndSafetyPermit (et couplage synchro)   →  TRUE = mouvement autorisé
```

- **Règle `AND`, exception `OR` de couplage** : deux permissions **safety/process** s'agrègent par
  `AND`. ⚠️ **Exception LÉGITIME** : l'`OR` de **couplage synchro** dans `EffectivePermit`
  (`EffectivePermitM1_Descend := ProcessAndSafetyPermitM1_Descend AND (NOT SyncActive OR
  ProcessAndSafetyPermitM2_Descend)`, `PRG_04_Treuils_Benne.st:810`) — il reste **sous le `AND`
  de son propre `ProcessAndSafetyPermit`**, donc il ne court-circuite jamais le Safety individuel.
  → **Interdit** : un `OR` qui court-circuite le Safety d'un axe. **Permis** : un `OR` de couplage
  synchro, sous `AND` du Safety de chaque treuil. Un `OR` d'autorisation sans Safety = cas d'arrêt.
- Le nom **porte toujours le niveau** (`SafetyPermit` ≠ `EffectivePermit`) — ne pas écrire un
  `Permit` générique qui cache le niveau réel.
- Chaque niveau suit `<Niveau>Permit<Repère>_<Sens>` (`_Ascent`/`_Descend` en suffixe,
  l'axe `M1/M2` juste après `Permit`, cf. NC-080).

#### `*Allowed` — chaînes de diagnostic / IHM (lecture seule)

Les flags `*Allowed` exposent le **résultat** d'un arbitrage pour le diag, l'IHM ou le
troubleshooting (jamais comme source d'autorisation) : `us401_MotionAllowed`, `Step6_DirectionAllowed`,
`Step5_ArmingAllowed`. Même polarité positive (`TRUE` = autorisé/possible).

**Règle anti-ambiguïté (REX C1)** : ne **jamais** nommer une permission de façon inversée (`CutOff`
pour dire "je ne coupe pas", `ForbidX` pour un "PermitX") — voir le contre-exemple
`PowerCutOff_A_RQ` plus haut et la décision T117 (élimination des `Forbid*`).

### Consignes (références)
```
SpeedRef          → consigne de vitesse
CablePosRef       → position câble consignée
```
 
### Mesures (actual)
```
SpeedAct          → vitesse mesurée
CablePosAct       → position câble mesurée (déroulé)
DrumPos           → position tambour codeur
```
 
### Sorties d'état / feedback
```
Ready, Done, Busy, Moving
Error, ErrorId    → ErrorId = bitfield WORD (bit n = défaut n)
                   Règle documentation ErrorId : 
                   - Chaque bit doit être documenté dans la déclaration du FB.
                   - Format : `bitN: "MESSAGE IHM" - Description technique`
                   - Le texte entre guillemets est le message exact attendu sur l'IHM (à copier-coller).
```
 
### Sorties physiques / actionneurs
```
RelayFwd, RelayRev           → contacteurs direction
OutSpeed, OutSpeedCmd        → commande variateur (%)
SoftStartRampActive          → gestion rampe soft-start
```

### `Req` vs `Cmd` — toujours en préfixe (`<Rôle><Racine>`)

🔧 REX 2026-07-15 : `Cmd` était utilisé tantôt en préfixe (`CmdOpen`), tantôt en suffixe
(`BrakeCmd`) sans règle. Tranché en préfixe — plus fluide à l'écriture avec l'autocomplétion
(taper `Req`/`Cmd` fait remonter direct toutes les requêtes/commandes, peu importe le mécanisme).

| Préfixe | Sens | Où dans le pipeline |
|---|---|---|
| `ReqX` | Requête brute (bouton IHM / séquenceur), **pas encore arbitrée** | Entrée d'un arbitrage (interlocks, sélection Manu/Auto, limitation) |
| `CmdX` | Signal **final** vers l'actionneur/le bus, après arbitrage | Sortie FB ou variable écrite juste avant le matériel |

Exemple de pipeline (illustratif — pas le pipeline réel actuel, voir note ⚠️ ci-dessous) :
```
<champ brut IHM> (bouton IHM, pas encore arbitré)
  → <variable arbitrée Manu/Joystick>
  → <variable après interlocks AU/SafeStop>
  → <signal final envoyé sur le bus>
```

📖 **Statut réel** : `Req` n'est appliqué **nulle part** dans le code actuel ; `CmdX` existe en
préfixe, `BrakeCmd`/`OpenReq` en suffixe (legacy assumé). Le chantier de généralisation et la
migration `ST_TranslationHMI` non retenue sont documentés dans
[`ARCHIVES/Doc/AUDITS/REX_Nommage_v1.0.md`](AUDITS/REX_Nommage_v1.0.md) — **ne pas s'en servir comme
référence d'un état existant**.

### Paramètre → Mesure → État atteint → État actif (fin de course logiciel, seuils)

Chaîne à 4 maillons pour tout seuil logiciel (limite, ralentissement, zone) — déjà en
production côté Winch (`ST_WinchHMI`), pris comme référence :

| Maillon | Rôle | Nom (suffixe unité) | Exemple réel |
|---|---|---|---|---|
| 1. Paramètre / seuil | Réglage (souvent RETAIN, modifiable IHM) | `<Nom>_<Unité>` | `CableLimitAscent_M := 12.0` |
| 2. Mesure / info | Valeur mesurée ou calculée en temps réel | `<Nom>_<Unité>`, pas de suffixe rôle particulier | `Position_M` (position câble actuelle) |
| 3. État atteint | **Fait pur** : mesure vs seuil, aucune conséquence | `<Nom>Reached` | `CableLimitAscentReached` |
| 4. État actif | **Conséquence comportementale** — famille "sortie de commande" (polarité `TRUE` = déclenche, voir tableau plus haut) | `<Verbe><Nom>Active` | `ForbidAscentActive` (bloque la montée) |

Différence 3 vs 4 : `CableLimitAscentReached` dit juste "on est arrivé au seuil" (info) ;
`ForbidAscentActive` dit "en conséquence, la montée est interdite maintenant" (action). Les deux
existent souvent en paire, mais pas toujours 1:1 — un même "actif" peut agréger plusieurs
"atteint"/conditions (ex. `FdcBucketOpenActive` dépend d'un seuil ET d'un `Enable` de config).

**Paramètres/réglages (Config)** vs **Consignes (`Ref`)** : un paramètre change rarement (RETAIN,
réglage banc/mise en service — `RampAccelRate`, `TopSensorPosition_M`, `Config : ST_BucketConfig`) ;
une consigne (`Ref`) est recalculée à chaque cycle par la logique (`SpeedRef`, `CablePosRef`).
Les deux peuvent partager un suffixe d'unité (`M`, `Pct`) mais ne sont pas la même catégorie —
un paramètre ne doit pas s'appeler `XxxRef`, une consigne calculée ne doit pas ressembler à un
réglage figé.

### Booléens : convention d'état
**Entrées** → verbe d'action :
```
Reset, Enable, StartStop
```

**Sorties** → état/propriété :
```
Ready, Busy, Done, Error
IsOverload, HasFault
SafeStop            → sortie d'un bloc safety métier (état, pas une commande)
```

---

## Suffixes d'unité (règle stricte)
Toujours précédés d'un underscore `_` pour lisibilité immédiate (évite la confusion `CablePosM` vs `CablePos_M`) :
```
CablePos_M       → position en mètres (2 déc)
Speed_Pct        → vitesse en % nominal
RampTime_Ms      → temps de rampe en ms
Freq_Hz          → fréquence en Hz
Speed_Mps        → vitesse linéaire en m/s
```
*Exception* : les suffixes `_DI`/`_DQ`/`_RQ` (I/O physique, voir §suffixes hardware) et `_Pct`/`_M`/`_Hz`/`_Ms`/`_Mps` (unités physiques) gardent l'underscore systématique.
Les variables PERSISTENT ajoutent en plus le préfixe `_` global (ex. `_CableLimitM1Descent_M`).

---

## Variables globales persistantes (GVL_PERSISTENT)
Les variables déclarées dans la liste globale persistante (`GVL_PERSISTENT.st`) suivent une règle spécifique pour assurer leur lisibilité et identifier leur persistance :
- L'attribut `{attribute 'qualified_only'}` est **retiré** pour permettre un accès direct partout dans l'application.
- Toutes les variables persistantes sont **obligatoirement préfixées par un underscore** `_` (qui sert de décorateur pour les identifier instantanément).
- Les suffixes d'unités physiques doivent être **précédés d'un underscore** (ex. `_M`, `_Pct`, `_Hz`).

*Exemples de variables persistantes :*
- `_CableLimitM1Descent_M` (mètres)
- `_WinchM1RampAccelRate_Pct` (pourcentage)
- `_TranslationMaxFreq_Hz` (Hz)
- `_WinchMaxStepDescent` (sans unité, correction linguistique de "Descente" en "Descent")

---

## Variables IHM (structures ST_*HMI) — Préfixes sémantiques (collés)

Les structures d'échange IHM (`ST_WinchHMI`, `ST_BucketHMI`, `ST_TranslationHMI`, `ST_ModesHMI`, `ST_JoystickHMI`, `ST_SyncHMI`, `ST_CycleHMI`, `ST_CommunHMI`) suivent une convention de préfixes **sans underscore après le préfixe** — format `<Préfixe><PascalCase>` (ex: `BtnReset`, `SelTarget`, `SetFreqHz`).

| Préfixe | Sémantique | Exemple | Cycle de vie |
|---|---|---|---|
| `Btn` | Bouton impulsionnel (IHM → PLC, front) | `BtnReset`, `BtnHome`, `BtnOpen` | Consommé par `R_TRIG` / `F_TRIG` |
| `Sel` | Sélecteur / Choix maintenu (IHM → PLC) | `SelMode`, `SelTarget`, `SelWinchMode` | Valeur persistante, `INT`/`ENUM` |
| `Set` | Consigne numérique exploitable (IHM → PLC) | `SetFreqHz`, `SetDepthM`, `SetSpeedPct` | Bornée PLC, modifiable en mouvement |
| `Tgl` | Bascule / Toggle booléen (IHM ↔ PLC) | `TglJoystickMaster`, `TglBypassContactor` | État persistant `TRUE`/`FALSE` |
| `Cfg` | Paramètre de configuration / mise en service (RETAIN) | `CfgTopSensorPos_M`, `CfgRampAccelRate` | Rarement modifié, souvent `RETAIN` |
| `Tst` | Commande de test banc uniquement | `TstSensorsWord`, `TstBrakeStuckOpen` | Jamais en production, `GVL_Simulation` gate |

**Règles strictes :**
- **Jamais** de `Cmd` dans `ST_*HMI` — `Cmd` réservé aux signaux finaux vers actionneur/bus (niveau 2 pipeline `Req`→`Cmd`)
- **Jamais** de `Req` dans `ST_*HMI` — `Req` = requête brute entrant dans arbitrage
- **Pas d'underscore** après le préfixe — format `<Préfixe><PascalCase>` (ex: `BtnReset`, `SelTarget`, `SetFreq_Hz`)
- Underscore **uniquement** pour suffixes d'unité (`_M`, `_Hz`, `_Pct`, `_Mps`, `_Ms`)
- État (`Ready`, `Busy`, `Error`...), Mesure (`Position_M`, `Speed_Mps`...), Diagnostic (`ErrorId`...), Sortie physique (`RelayFwd`, `Brake`...) : **pas de préfixe**, forme établie conservée

> ⚠️ **Migration** : toute modification de ces noms dans `CODE/SUPERVISION/*.st` casse les liaisons IHM (tags graphiques). Ne renommer **qu'en migration planifiée** (bundle PLCopenXML + mise à jour IHM simultanée, mapping `OldName → NewName` documenté). L'existant (`CmdReset`, `BtnFwd`, `SetFreq_Hz`...) reste valide tant que la migration n'est pas décidée.

---

## Variables de simulation (GVL_Simulation)

⚠️ `GVL_Simulation` mélange aujourd'hui 3 familles (`_IsReal`, `_Simulated`, `Sim...`).
La convention cible (`Bus`/`Sensor`/`Sim`/`Tst`/`Link`) est **planifiée, pas appliquée** :
voir [`ARCHIVES/Doc/AUDITS/REX_Nommage_v1.0.md`](AUDITS/REX_Nommage_v1.0.md).
**Ne pas migrer au fil de l'eau** — chantier à part.

### Règle — Repère juste après le préfixe (GVL plates uniquement)

Dans une **GVL plate** (liste à plat, pas de struct imbriquée par instance/axe comme
`GVL_IHM.WinchM1.xxx`), le Repère matériel (M1/M2/M3) se place **juste après le préfixe**,
avant la fonction — pour que le tri alphabétique (vue Watch/Instance CODESYS) regroupe
automatiquement toutes les variables du même axe, sans avoir besoin de déplier une structure :

```
<Préfixe><Repère><Fonction>[<Suffixe>]
```

✅ `SensorM1ContactorFeedbackIsReal`, `SensorM1ThermalIsReal`, `SensorM2ThermalIsReal`
❌ `SensorContactorFeedbackM1IsReal` (regroupe par fonction, pas par axe — mélange les axes
à l'écran, impossible à lire vite en session stress terrain)

⚠️ Ne s'applique QUE aux GVL plates. Dans une struct imbriquée par instance
(`GVL_IHM.WinchM1.CmdReset`), le Repère est déjà porté par le nom de l'instance — ne
JAMAIS le répéter dans le champ (règle existante, voir section « Construction d'un nom »
ci-dessous).

### Repères multiples (axe + sous-composant fonctionnel numéroté)

Si une fonction porte elle-même un repère numérique propre (ex: `Contactor1`..`Contactor4`
= palier vitesse), ce repère fonctionnel reste **toujours collé** à son mot de fonction,
formant un bloc indissociable. Seul l'axe/mécanisme (repère le plus large et stable :
M1/M2/M3) remonte juste après le préfixe.

```
<Préfixe><Axe><Fonction+RepèreFonctionnel><Suffixe>
```

✅ `SensorM1Contactor4IsReal` (M1 = axe, `Contactor4` = fonction+repère indissociable)
❌ `SensorContactor4M1IsReal` (casse le regroupement par axe)
❌ `Sensor4M1ContactorIsReal` (sépare le repère fonctionnel de sa fonction, perd le sens)

---

## Constantes (VAR CONSTANT / VAR_GLOBAL CONSTANT)

Toute constante déclarée reçoit le **préfixe `CST_`** (nommage explicite, repérable au tri
alphabétique et en Watch), suivi d'un nom PascalCase décrivant le rôle :

```
CST_<NomPascalCase> : <type> := <valeur>;   // dans VAR CONSTANT du FB
CST_<NomPascalCase> : <type> := <valeur>;   // dans VAR_GLOBAL CONSTANT d'une GVL
```

✅ `CST_BannerHoldTime : TIME := T#500ms`, `CST_FaultDisplayDebounce`, `CST_MaxDescentTime`
❌ `BannerHoldTime`, `HOLD_TIME`, `HoldTime := T#500ms` (variable modifiable — c'est une
constante d'affichage, elle ne doit jamais être modifiable à chaud)

- Une valeur figée par conception métier/sécurité se déclare en **`VAR CONSTANT`** (ou
  `VAR_GLOBAL CONSTANT` pour les constantes partagées entre POU) — jamais en variable modifiable.
- Une valeur qui DOIT être calibrée/tunable (ex. seuils terrain) reste une **variable** (souvent
  persistante), PAS une constante `CST_`.
- Sauf dérogation documentée, le préfixe `CST_` est **obligatoire** pour toute constante —
  il n'existe pas de constante sans préfixe.

---

## Construction d'un nom : instance → champ (2 niveaux, jamais mélangés)

🔧 REX 2026-07-15 : formalisé après plusieurs allers-retours sur le Translation M3 — un nom se
construit toujours en 2 étapes distinctes, chacune avec sa propre règle.

### Niveau 1 — Instance (membre `GVL_IHM`, instance de FB)
`<Mécanisme>[<Repère>]`
- **Mécanisme** : nom métier court (`Winch`, `Translation`, `Bucket`, `Joystick`, `Sync`, `Modes`)
- **Repère** : identifiant matériel (`M1`/`M2`/`M3`/`JOY1`...) — **uniquement si plusieurs
  instances du même mécanisme existent**, pour les distinguer. Un mécanisme unique n'a pas de repère.

| Instance | Repère ? | Pourquoi |
|---|---|---|
| `WinchM1`, `WinchM2` | Oui | 2 treuils physiques, il faut distinguer lequel |
| `TranslationM3` | Oui | Identifiant matériel du variateur (cohérence avec M1/M2 des treuils) |
| `JOY1Joystick` | Oui | Repère = ID noeud CANopen physique |
| `Bucket` | **Non** | Un seul benne sur la machine — un repère (`BucketM2`) répéterait le `M2` déjà présent dans ses propres champs (`M2PositionCorrected`, `LastPosM2Close`...) : tenté puis annulé le 2026-07-15, stutter |

### Niveau 2 — Champ à l'intérieur du struct
`<Rôle><Fonction>` — **uniquement pour les catégories réellement ambiguës** (commande vs
requête, voir `Req`/`Cmd` plus haut). Les catégories déjà univoques gardent leur forme établie
**sans** préfixe de rôle, ajouter un préfixe n'apporterait rien :
- `Ready`/`Busy`/`Done`/`Error` (état) — pas `StsReady`
- `RelayFwd`/`RelayRev` (sortie physique relais)
- `SpeedRef`/`CablePosRef` (consigne)

⚠️ **Ne jamais répéter le Repère du niveau 1 à l'intérieur du champ** — le nom du struct porte
déjà le contexte matériel :
```
✅ GVL_IHM.TranslationM3.BtnFwd
❌ GVL_IHM.TranslationM3.M3BtnFwd   (M3 déjà dans TranslationM3, répétition inutile)
```

### Exemple complet (les 2 niveaux assemblés)
```
GVL_IHM . TranslationM3 . BtnFwd
          └───┬────┘  └─┬─┘
          Niveau 1    Niveau 2
        Mécanisme+   Rôle+Fonction
         Repère      (Btn = bouton
       (Translation+M3)   IHM, Fwd =
                       avant)
```

---
 
## Structures : exemple CODESYS
```codesys
(* Consigne joystick *)
TYPE ST_Joystick_AxisCmd :
STRUCT
    Enable      : BOOL;       (* Autorisation *)
    StartStop   : BOOL;       (* TRUE = rampe accel, FALSE = rampe decel normale *)
    SpeedRef    : REAL;       (* Consigne vitesse 0..100% *)
    Direction   : INT;        (* -1=Rev, 0=Neutre, +1=Fwd *)
    PowerContactorEngaged : BOOL;   (* Chaine AU réarmée / contacteur puissance OK *)
END_STRUCT
END_TYPE
 
(* Status treuil *)
TYPE ST_WinchIO :
STRUCT
    Ready       : BOOL;
    Done        : BOOL;
    Error       : BOOL;
    ErrorId     : WORD;       (* bitfield : bit n = défaut n, pas un code numérique *)
    SafeStop    : BOOL;       (* sortie safety métier consommée par ce treuil *)
    CablePosAct : REAL;       (* m *)
    SpeedAct    : REAL;       (* % *)
    RelayFwd    : BOOL;
    RelayRev    : BOOL;
END_STRUCT
END_TYPE
```
 
---
 
## En Ladder : lisibilité flux
```
[FB_Joystick]     →  (.Done)  →  [FB_Treuil.Enable]
     ↓ SpeedRef        + StartStop ↓ SpeedRef
[FB_Encodeur]     ←  (.CablePosAct)
```
→ Chaînes d'instance, flux d'info immédiatement visible pour maintenance. ✅
 
---
 
## Résumé règles
1. ❌ Pas de `bFlag`, `iCounter`, `rValue`.
2. ✅ `Enable`, `Ready`, `CablePosM`, `SpeedPct`.
3. Type se découvre dans l'IDE → le nom parle du rôle.
4. Instance = `<Mécanisme>[<Repère>]` (repère seulement si plusieurs instances du même mécanisme).
5. Champ = `<Rôle><Fonction>` **seulement si ambigu** (`Req`/`Cmd`) ; sinon forme établie sans préfixe (`Ready`, `RelayFwd`, `SpeedRef`).
6. Seuil logiciel = 4 maillons : Paramètre (`XxxM`) → Mesure → `XxxReached` (fait) → `XxxActive` (conséquence).
7. Structures + Enums = organisation, pas typage du nom.
 
