# Audit architecture des flux PRG_02 / PRG_03 — 2026-08-28

> **Statut : BASELINE PROPOSÉE — visa humain requis avant toute édition de `CODE/`.**  
> Révision auditée : `54a5715c`. Le code est observé comme un **état intermédiaire de refactor**, pas comme l'architecture cible.

## 🎯 Verdict exécutif

L'orientation est saine si les responsabilités restent strictement séparées :

```text
Terrain / simulation
        ↓
PRG_02 — faits matériels, mesures et gestes qualifiés
        ├───────────────────────────────┐
        ↓                               ↓
PRG_03 — modes + demandes programme    geste opérateur courant
        └──────────────┬────────────────┘
                       ↓
PRG_04 / PRG_05 — arbitrage métier, concordance geste/programme,
                  régulation et sécurité locale
                       ↓
PRG_06 — barrière finale et sorties physiques
```

La règle structurante est :

- `PRG_02` publie des **faits qualifiés** ;
- `PRG_03` publie des **autorisations** et des **demandes de programme** ;
- `PRG_04/05` décident si la demande devient une consigne métier, puis appliquent les sécurités ;
- `PRG_06` est seul propriétaire des sorties physiques finales.

Cette séparation est cohérente avec `AF_Partie-02 v3.2`, `AF_Partie-03 v2.3`, la chaîne de nommage
`Req → Tgt → Cmd → Act` et le principe « un producteur par donnée ».

## 🧭 Sources et priorité d'arbitrage

1. décisions humaines explicites ;
2. AF active la plus récente ;
3. standards projet ;
4. code actuel comme preuve de comportement et de dépendance ;
5. audits d'agents comme éléments consultatifs, jamais comme ordre.

`Device.export` n'a pas été lu : il est périmé par principe sans export manuel frais.

## ✅ Ce qui est déjà correctement orienté

| Élément | Constat |
|---|---|
| Ordre global | `PRG_02 → PRG_03 → PRG_04 → PRG_05 → PRG_06 → PRG_07` est documenté. |
| Images d'entrée | `PRG_02` possède `HwReal`, `HwSim`, `HwIn` et l'aiguillage réel/simulé. |
| Bus publics métier | `PRG_04.Data : ST_WinchInterPrg` et `PRG_05.Data : ST_TranslationInterPrg` existent. |
| Joystick | `FB_Joystick` produit déjà `AxisCmdX/Y : ST_fbJoystick_AxisCmd`, le deadman et le diagnostic d'armement refusé. |
| Sécurité locale | Les safety treuils/translation restent dans `PRG_04/05`, conformément à l'AF‑02. |
| Simulation | Les retours de sortie N‑1 vers `PRG_02` sont une boucle de modèle explicitement admissible. |

## 🔎 Audit PRG_02 — écarts de frontière

### A02-01 — bus joystick public incomplet — MAJOR

`ST_AcquisitionInterPrg` ne publie qu'une vue partielle : deadman, neutres, direction et vitesse X.
Le producteur complet existe pourtant dans `instJoystick.AxisCmdX/Y`.

Conséquence : `PRG_03`, `PRG_04` et `PRG_07` lisent directement `instJoystick.*`. Cela rompt
l'encapsulation et empêche de figer une interface stable.

**Cible :** publier dans `Data.Joystick` les deux `AxisCmd`, `DeadmanArmed`, `AtNeutralXY`,
`ArmingPermitDenied`, `Ready`, `Fault` et l'état réseau utile. Aucun consommateur ne recalcule
direction, neutre ou déflexion.

### A02-02 — diagnostics réseau non publiés — MAJOR

`PRG_04`, `PRG_05` et `PRG_07` lisent `instDiagCanOpen` et `instDiagEthercat` directement.
Les sorties sont déjà structurées en `ST_Diag_Device` : elles doivent être recopiées dans un sous-bus
`Data.Network` produit une seule fois par `PRG_02`.

### A02-03 — façade codeur contournée — MAJOR

Des consommateurs lisent encore `instEncoderM1/M2.Homed`, `Measurement.*` ou le lifecycle homing.
Les faits requis doivent être publiés par `Data.Encoders` et les gates de fiabilité publics.

### A02-04 — `ArmingPermit := TRUE` — BLOCK avant mise en service

Le câblage est explicitement temporaire dans `PRG_02_Acquisition.st`. `AF_Partie-08 v2.5 §10 Q1`
le classe C4 ouvert. Le nouveau bus ne doit ni masquer ce stub ni inventer son producteur.

**Décision humaine requise :** définir la source positive de permission d'armement et les conditions
de désarmement. Le comportement manuel actuel doit rester bloqué en validation tant que ce point
n'est pas fermé.

### A02-05 — dépendances inverses admises mais à typer — MINOR/MAJOR selon usage

- simulation : commandes `PRG_04/05/06` N‑1, admises pour le modèle ;
- homing : `PRG_03.Auth` et états publics `PRG_04` N‑1, admis seulement si nommés ;
- lecture d'internals aval : interdite ; remplacer par les bus publics existants.

### A02-06 — défaut codeur qualifié non consommé uniformément — BLOCK safety

`Data.M1_EncoderFault/M2_EncoderFault` agrègent disponibilité et incohérence. Pourtant `PRG_03`
recalcule depuis le seul `DeviceState`, et certaines safety treuils utilisent seulement
`EncoderAvailable`. Une mesure incohérente avec bus opérationnel peut donc être interprétée
différemment suivant le consommateur.

**Action :** figer une matrice de consommation du fait `EncoderFault`, puis corriger sous un lot
`fix:` + `guard:` séparé si l'analyse safety confirme l'écart. Le remappage T165 ne doit pas changer
silencieusement cette logique.

## 🔎 Audit PRG_03 — écarts de frontière

### A03-01 — instance `instCycleSemiAuto` exposée — MAJOR

`PRG_04`, `PRG_05` et `PRG_07` lisent directement ses demandes, états et diagnostics. Le programme
expose donc son implémentation au lieu d'un contrat stable.

**Cible :** un seul `Data : ST_ModesCycleInterPrg` regroupant `Auth`, `ReqProgram` et
`SequenceState`. L'instance redevient privée.

### A03-02 — publication `Auth` après l'appel cycle — MAJOR

Le code appelle `FB_Cycle` avant `Auth := instModes.Auth`. Le cycle utilise donc l'autorisation N‑1,
alors que `PRG_04/05` voient ensuite l'autorisation courante.

**Recommandation :** publier et injecter `Auth` courant avant l'appel des séquences. Ce changement
doit être testé comme comportement de mode, pas traité comme un simple déplacement de ligne.

### A03-03 — geste transformé en permit générique — MAJOR

`CycleMotionPermit := NOT AtNeutralXY` ne prouve ni l'axe, ni le sens, ni le deadman, ni la
concordance avec l'étape. Il ne doit pas devenir un « permit sécurité » de `PRG_03`.

**Cible :** `PRG_03` publie la demande et l'action opérateur attendue. `PRG_04/05` comparent cette
attente au geste qualifié courant et publient la raison réelle d'acceptation/refus.

### A03-04 — retours procédé lus dans les internals PRG_04/05 — MAJOR

Les transitions doivent lire `PRG_04.Data` et `PRG_05.Data` au scan N‑1. Le retard est admissible
pour séquencer, jamais pour réaliser l'arrêt immédiat ou l'interlock physique.

### A03-05 — `DiveSearch` / `ExtractionSequence` : contradiction documentaire — BLOCK décision

La préférence humaine exprimée est de les considérer comme des sous-cycles pilotés depuis
`PRG_03`. L'AF‑02 v3.2 active dit qu'ils restent dans `PRG_04`, car ils servent aussi en maintenance.

**Recommandation robuste :** ne pas les déplacer dans le premier lot. Figer d'abord le bus
`ReqProgram`. Puis arbitrer séparément :

- soit les FB restent dans `PRG_04` et sont déclenchés par une requête de `PRG_03` ;
- soit ils migrent dans `PRG_03`, après amendement AF‑02/AF‑04/AF‑10 et contrat de conservation C4.

Leur déplacement ne doit jamais transférer les interlocks ou safety de `PRG_04` vers `PRG_03`.

### A03-06 — statut T164-5 incompatible avec l'interface réelle `FB_Cycle` — BLOCK catalogue

Le catalogue marque T164-5 terminée, mais `FB_Cycle` expose encore `Busy`, `Done`, `Error` et
`ErrorId` à plat, sans `Fault : ST_Fault` ni `Lifecycle : ST_Lifecycle`. `PRG_03.SequenceState` ne
doit pas fabriquer un faux `ST_Fault` dans le programme d'orchestration.

**Action :** T165-C0 vérifie le lot réel et fait réouvrir/créer le contrat G_CYCLE approprié avant
T165-C1. Aucun agent C1 ne démarre tant que cette précondition n'est pas levée.

## 🛡️ Invariants de conservation

| ID | Invariant non négociable |
|---|---|
| INV-01 | Relâchement ou invalidité du geste : `StartStop=FALSE`, vitesse cible nulle, sans redémarrage automatique. |
| INV-02 | Le deadman reste requis selon la politique humaine validée ; aucun chemin semi-auto/assistant ne le contourne silencieusement. |
| INV-03 | `Enable > SafeStop > StartStop` ; seul l'AU physique / `PowerCutOff` coupe brutalement. |
| INV-04 | `PRG_03` ne produit ni `Cmd`, ni `Act`, ni permit de sécurité physique. |
| INV-05 | `PRG_04/05` conservent tous les interlocks, rampes, limites, synchronisation et défauts existants. |
| INV-06 | Les modes manuel actuellement essayés restent disponibles avec mêmes polarités, vitesses et sens. |
| INV-07 | Une donnée publique a un producteur unique ; aucune coexistence durable `_old`/nouvelle. |
| INV-08 | Les retards N‑1 sont nommés ; les arrêts physiques utilisent les faits courants dans `PRG_04/05`. |
| INV-09 | Aucun consommateur ne lit un `inst*` appartenant à un autre PRG après migration. |
| INV-10 | Les structures IHM ne deviennent jamais un bus interne de commande. |

## 🧪 Anomalies fonctionnelles observées hors refactor d'interface

Ces éléments ne doivent pas être corrigés « en passant » : chacun nécessite une tâche dédiée et un
garde-fou automatique si le défaut est confirmé.

| Élément | Niveau | Traitement |
|---|---:|---|
| `ArmingPermit := TRUE` | BLOCK | Décision C4 préalable, puis test deadman/arming. |
| chemin M2/benne potentiellement sans deadman | MAJOR | Scénario de conservation obligatoire avant refactor consommateur. |
| transition homing du cycle sur demande plutôt que confirmation | MAJOR | Revue AF‑04/AF‑09 dédiée ; hors contrat inter‑PRG. |
| étape X11 direction incompatible avec ouverture attendue | MAJOR | Test de séquence dédié ; hors contrat inter‑PRG. |
| sorties d'étape potentiellement conservées lors d'une transition | MAJOR | Test « toutes demandes neutralisées avant nouvelle étape » ; hors remappage pur. |
| séquence Kobold potentiellement réduite au mauvais front | BLOCK | Vérifier la séquence exigée `0→1→0→1` avant toute autorisation d'extraction. |
| capture `CycleStepAtError` possiblement après passage en stabilisation | MAJOR | Injecter une erreur par étape et prouver l'étape fautive mémorisée. |
| `PowerContactorEngaged` injecté dans plusieurs séquenceurs | À ARBITRER | Conserver uniquement si précondition fonctionnelle justifiée ; ne pas le confondre avec safety locale. |
| défaut codeur recalculé différemment par PRG_03/PRG_04 | BLOCK | Source unique `Data.*_EncoderFault` à valider par matrice safety. |
| champs M3 nommés `*_Filtered` sans filtre démontré | MINOR | Corriger nom ou implémentation dans un lot séparé, jamais pendant le remappage. |
| polarité frein M3 contradictoire entre AF‑06 et code | BLOCK documentaire | Trancher avant toute modification du chemin frein/safety. |

## 📌 Décisions à viser avant code

| ID | Décision | Recommandation |
|---|---|---|
| D-01 | Producteur de `ArmingPermit` | Décider explicitement ; ne jamais garder `TRUE` en cible. |
| D-02 | Deadman en manuel, semi-auto et assistants | Exigence uniforme par mouvement, sauf exception safety documentée et testée. |
| D-03 | Vitesse programme | Conserver temporairement `%` ; décider séparément du passage à `SpeedStep 1..5` (T131). |
| D-04 | Localisation Dive/Extraction | Ne pas déplacer au premier lot ; arbitrage AF séparé. |
| D-05 | `Auth` courant ou N‑1 dans cycle | `Auth` courant recommandé. |
| D-06 | Contrat public PRG_03 | `Data.Auth`, `Data.ReqProgram`, `Data.SequenceState` recommandé. |
| D-07 | Confirmation Kobold | Exiger et tester la chronologie physique complète avant extraction. |
| D-08 | Entrée puissance dans les séquenceurs | Documenter comme précondition de cycle ou la retirer ; jamais modifier sans revue AF. |
| D-09 | Source unique du défaut codeur consommé | Utiliser la façade qualifiée après validation safety et test d'incohérence. |

## 🗺️ Plan d'exécution sûr

1. **T165-A** — visa de cette architecture et fermeture D-01..D-06.
2. **T165-B1** — compléter la publication PRG_02 sans changer les consommateurs.
3. **T165-B2** — migrer tous les consommateurs vers `Data/HwIn`, puis supprimer les accès internes.
4. **T165-BR** — revue indépendante read-only PRG_02 + non-régression manuelle.
5. **T165-C0** — réconcilier l'état réel du contrat `FB_Cycle` avec T164-5.
6. **T165-C1** — créer/publier le bus PRG_03 et corriger l'ordre interne validé.
7. **T165-C2** — migrer tous les consommateurs, puis rendre `instCycleSemiAuto` privé.
8. **T165-CR** — revue indépendante read-only PRG_03 + chaîne `Req → Tgt → Cmd → Act`.

**Ligne d'arrêt :** aucun refactor métier de `PRG_04/05`, aucun déplacement Dive/Extraction et
aucune réécriture du GRAFCET dans T165. Ces travaux reprennent ensuite sur des contrats dédiés.
