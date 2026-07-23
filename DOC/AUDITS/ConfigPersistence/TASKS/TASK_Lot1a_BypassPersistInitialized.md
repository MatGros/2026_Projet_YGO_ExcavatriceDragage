# 📋 Document de Tâche — Lot 1a : Fix persistance Bypass (flag `Initialized` co-localisé)

> 🎯 **Pour agent externe sans accès à l'historique de conversation.** Ce document est autonome :
> tout le contexte nécessaire est inclus. Ne pas improviser au-delà de ce qui est spécifié — en cas
> de doute, s'arrêter et demander clarification plutôt qu'approximer (règle d'or du projet).
> 📌 Suivi : `PLAN_TASK_v1.0.md`, `DOC/AUDITS/ConfigPersistence/AUDIT_ConfigPersistence_v1.2.md`.
> 🧭 Convention de nommage obligatoire : `DOC/NAMING_CONVENTION.md` (PascalCase, pas de hongrois).

---

## 🆕 MISE À JOUR (si tu as déjà commencé ce document avant cette section) — 2 ajouts de scope

**Si tu es déjà en train de travailler sur ce document, lis ceci avant de continuer** — 2 ajouts
de périmètre, tout le reste (§1-§8 ci-dessous) reste valable tel quel :

1. **`ST_BypassNetwork` passe de "Global seul" à "par device + Global"** — voir §3bis.
2. **`ST_BypassTranslation` reçoit en plus 2 champs agrégés `Safety`/`Process`** — voir §3ter.
   `FB_Safety_Translation.st` doit être touché pour CE struct.
3. **`ST_BypassWinch` reçoit aussi `Safety`/`Process` + 2 bypass individuels fin de course
   (`TopLimitSwitch`/`CableLimitSwitch`)** — voir §3quater (classification complète des 16 bits,
   vérifiée ligne par ligne). `FB_Safety_Winch.st` doit être touché pour ces bits précis.
4. **Correction technique importante** : `FB_Safety_Translation`/`FB_Safety_Winch` prennent des
   paramètres BOOL à PLAT (`BypassMecaB`, `EncoderFaultBypass`, etc.), **pas** un struct `Bypass`
   passé en bloc — utiliser `BypassSafety`/`BypassProcess`/`BypassTopLimitSwitch`/
   `BypassCableLimitSwitch` (à plat), jamais `Bypass.Safety`. `CODE/MAIN/PRG_03_Safety.st` doit
   aussi être modifié (côté appelant, pour mapper `GVL_IHM...Bypass.Xxx` → paramètre à plat).

Ces 4 ajouts **remplacent** l'affirmation précédente de ce document ("pas de changement sur
Winch") — cette limitation ne tient plus, voir §3quater pour le détail complet et vérifié.

---

## 1. Contexte du bug (déjà diagnostiqué, ne pas re-analyser)

Le 2026-07-23, un bug de persistance a été corrigé sur les paramètres `Cfg` de Winch/Sync
(`GVL_IHM` en RETAIN simple → invalidé silencieusement par tout changement de structure d'un DUT
`ST_*HMI`, comme un ajout de champ). Le correctif retenu : un flag booléen dédié `Initialized`
(défaut `FALSE`, non ambigu), **co-localisé dans le struct qu'il protège**, remplace toute
sentinelle basée sur la valeur d'un champ métier (`IF champ = 0.0 THEN` — cassé dès que le défaut
réel n'est pas `0.0`).

**Le même défaut existe sur les bypass** : `PRG_09_Supervision.st` utilise aujourd'hui **un seul
flag partagé** `BypassRestoreDone` (déclaré `VAR RETAIN` en tête de fichier, lignes 24-29) pour
piloter la restauration de **6 structs bypass différents**. Si un seul de ces structs change de
layout (ex. ajout d'un champ), son invalidation RETAIN individuelle n'a **aucun effet** sur
`BypassRestoreDone` (variable différente, portée différente) → le bloc de restauration ne se
redéclenche pas pour CE struct → son bypass fraîchement remis à `FALSE` n'est jamais restauré
alors que les autres si.

## 2. Objectif de ce lot

Remplacer le flag central `BypassRestoreDone` par un flag `Initialized : BOOL := FALSE;`
**co-localisé** dans chaque struct bypass concerné (voir périmètre §3), suivant EXACTEMENT le même
pattern déjà validé (revue sécurité + vérification impact actionneur) sur `ST_WinchCfg`/
`ST_SyncHMI` — voir §5 pour le code de référence exact à reproduire.

## 3. Périmètre — 3 structs concernés, 4 instances

⚠️ **Périmètre volontairement limité** — NE PAS toucher `Sync.BypassGlobal` ni
`M2Benne.BypassGlobal` dans ce lot : ce sont aujourd'hui des champs **plats** (pas de struct
`Bypass` dédié). Ils seront restructurés dans un lot séparé (homogénéisation IHM) qui créera
`ST_BypassSync`/`ST_BypassBucket` — le flag `Initialized` sera ajouté à ce moment-là, pas avant
(éviter un double travail).

| Struct | Fichier | Instances (chemin GVL_IHM) |
|---|---|---|
| `ST_BypassWinch` | `CODE/SUPERVISION/_TYPES/ST_BypassWinch.st` | `GVL_IHM.M1TreuilRetenue.Bypass`, `GVL_IHM.M2TreuilBenne.Bypass` |
| `ST_BypassTranslation` | `CODE/SUPERVISION/_TYPES/ST_BypassTranslation.st` | `GVL_IHM.TranslationM3.Bypass` |
| `ST_BypassNetwork` | `CODE/SUPERVISION/_TYPES/ST_BypassNetwork.st` | `GVL_IHM.Network.Bypass` |

## 3bis. `ST_BypassNetwork` — granularité par device (remplace "Global seul")

**Contexte métier** : les bypass réseau seront utilisés en production réelle (pas juste au banc),
avec droits utilisateur élevés (MAINT_N2). Cas d'usage concret qui justifie la granularité : pouvoir
bypasser le variateur EtherCAT (`VariateurM3`) en panne SANS perdre la surveillance des 2 codeurs
(`EncoderM1`/`EncoderM2`) qui sont sur le MÊME bus physique.

Structure cible (remplace le contenu actuel — actuellement juste `Global : BOOL;`) :
```
TYPE ST_BypassNetwork :
STRUCT
    Joystick    : BOOL; (* 🕹️ Bypass diagnostic esclave CANopen Joystick *)
    EncoderM1   : BOOL; (* 🧲 Bypass diagnostic esclave EtherCAT COD1 *)
    EncoderM2   : BOOL; (* 🧲 Bypass diagnostic esclave EtherCAT COD2 *)
    VariateurM3 : BOOL; (* ↔️ Bypass diagnostic esclave EtherCAT AC600 *)
    Global      : BOOL; (* 🌐 Bypass GLOBAL : tous les devices réseau à la fois, prioritaire sur les 4 ci-dessus *)
    Initialized : BOOL := FALSE; (* 🚦 flag restauration boot, voir §5.1 *)
END_STRUCT
END_TYPE
```
Noms alignés sur les champs déjà existants dans `ST_NetworkDiagHMI` (`Joystick`, `EncoderM1`,
`EncoderM2`, `VariateurM3`) — mêmes noms, intuitif à lire.

⚠️ **Ne PAS toucher au code qui consomme ces bits** (là où `Bypass.Global` force les devices réseau
"online" pour le diagnostic) dans ce lot — se contenter d'ajouter les 4 nouveaux champs au struct.
Le câblage de ces 4 nouveaux bits dans la logique de diagnostic réseau (`PRG_01_Diagnostics.st` ou
équivalent) est **hors périmètre de ce lot**, à traiter séparément (le struct doit exister d'abord).

## 3ter. `ST_BypassTranslation` — ajout `Safety`/`Process` (agrégation par criticité)

**Contexte métier** : standardiser une hiérarchie à 3 niveaux sur les bypass utilisés en
production : `Global` (tout) > `Safety`/`Process` (par criticité) > bit individuel (ciblé). Le
`Global` prend toujours le relais même si des sous-bypass sont actifs — implémenté par un simple
OR à chaque test, jamais par dépendance conditionnelle (donc aucun risque de conflit de priorité).

**Critère de classification, objectif, déjà dans le code** :
`FB_Safety_Translation.st` calcule `PowerCutOff := (ErrorId AND 16#00F8) <> 16#0000;` — masque =
bits 3,4,5,6,7. Donc :
- **Safety** = bits qui escaladent en `PowerCutOff` : `BrakeThermal`(3), `MecaB`(4), `MecaA`(5),
  `LimitSwitch`(6), `SensorIncoherent`(7).
- **Process** = bits qui restent en simple `SafeStop` : `OperatorComm`(0), `DriveComm`(1),
  `PhaseRotation`(2), `ContactorFeedback`.

Ajouter à `ST_BypassTranslation` (en plus des 9 champs individuels + `Global` déjà existants) :
```
    Safety  : BOOL; (* 🛡️ Bypass groupé : tous les bits qui escaladent en PowerCutOff (BrakeThermal/MecaB/MecaA/LimitSwitch/SensorIncoherent) *)
    Process : BOOL; (* ⚙️ Bypass groupé : tous les bits SafeStop seul (OperatorComm/DriveComm/PhaseRotation/ContactorFeedback) *)
```

**⚠️ Correction importante — `FB_Safety_Translation` prend des paramètres BOOL à PLAT en
`VAR_INPUT`** (`BypassGlobal`, `BypassMecaB`, `BypassLimitSwitch`, etc. — voir lignes 34-43
actuelles), **PAS** un struct `Bypass` passé en bloc. Le struct `ST_BypassTranslation` n'existe
QUE côté `GVL_IHM` ; c'est l'appelant (`PRG_03_Safety.st`, autour de la ligne 194-202) qui lit
`GVL_IHM.TranslationM3.Bypass.Xxx` et le passe en paramètre `BypassXxx` à l'appel de la FB. Donc
partout ci-dessous, utiliser `BypassSafety`/`BypassProcess` (noms à plat), jamais `Bypass.Safety`.

**`Bypass.Global` enveloppe DÉJÀ tout le bloc** : `IF NOT BypassGlobal THEN ... (tous les tests)
... END_IF` englobant (lignes 118-205 actuelles). Donc **ne jamais réécrire `OR BypassGlobal`**
dans les tests individuels — déjà géré par ce gate englobant, l'ajouter en plus serait redondant.
Ne toucher QUE la condition propre à chaque test.

**Étape A — Ajouter 2 nouveaux `VAR_INPUT`** à `FB_Safety_Translation.st` (après la liste
`BypassXxx` existante, lignes 34-43) :
```
    BypassSafety          : BOOL := FALSE;   // 🛡️ Bypass groupé PowerCutOff (BrakeThermal/MecaB/MecaA/LimitSwitch/SensorIncoherent)
    BypassProcess         : BOOL := FALSE;   // ⚙️ Bypass groupé SafeStop seul (OperatorComm/DriveComm/PhaseRotation/ContactorFeedback)
```

**Étape B — Câblage dans le corps de `FB_Safety_Translation.st`** — pour CHAQUE test qui alimente
un bit du groupe Safety (ex. bit `MecaB`), remplacer :
```
IF NOT BypassMecaB THEN
    ... détection normale ...
END_IF;
```
par :
```
IF NOT (BypassSafety OR BypassMecaB) THEN
    ... détection normale (inchangée) ...
END_IF;
```
Et pour un bit du groupe Process (ex. `OperatorComm`), remplacer par
`IF NOT (BypassProcess OR BypassOperatorComm) THEN`. Répéter pour les 9 bits individuels selon
leur groupe (§3ter ci-dessus donne le groupe de chacun). Ne changer QUE la condition propre à
chaque `IF` — la logique de détection à l'intérieur ne change pas, et le `IF NOT BypassGlobal THEN`
englobant reste inchangé tel quel.

**Étape C — Mettre à jour l'appel dans `CODE/MAIN/PRG_03_Safety.st`** (instantiation
`instSafetyTranslationM3`, lignes ~193-202 actuelles) : ajouter 2 lignes après `BypassSensorIncoherent`
:
```
    BypassSafety          := GVL_IHM.TranslationM3.Bypass.Global OR GVL_IHM.TranslationM3.Bypass.Safety,
    BypassProcess         := GVL_IHM.TranslationM3.Bypass.Global OR GVL_IHM.TranslationM3.Bypass.Process
```
(suivre exactement le même style que les lignes existantes : `Global OR <bit correspondant>` —
c'est l'appelant, pas la FB, qui incorpore déjà `Bypass.Global` dans chaque paramètre transmis).

⚠️ Ceci **modifie la contrainte générale §6** ("ne pas toucher FB_Safety_*.st") : `FB_Safety_Translation.st`
ET `PRG_03_Safety.st` DOIVENT être modifiés pour ce point précis, uniquement selon les 3 étapes
ci-dessus — aucune autre modification.

## 3quater. `ST_BypassWinch` — ajout `Safety`/`Process` + 2 individuels fin de course

**Contexte** : `FB_Safety_Winch.st` a 16 bits `ErrorId` (vérifiés ligne par ligne, code actuel).
Critère objectif identique à Translation : `PowerCutOff := (ErrorId AND 16#2F84) <> 16#0000;`
(bits 2,7,8,9,10,11,13).

| Bit | Mécanisme | Groupe |
|---|---|---|
| 0 | Perte comm opérateur | Process |
| 1 | Perte codeur (déjà individuel `EncoderFault`, MAINT_N2, INCHANGÉ) | Process |
| 2 | Surchauffe moteur | **Safety** |
| 3 | Mou de câble | Process |
| 4 | Rotation de phase | Process |
| 5 | Fin de course haute | Process + **individuel `TopLimitSwitch`** (nouveau) |
| 6 | Limite basse câble | Process + **individuel `CableLimitSwitch`** (nouveau) |
| 7 | Méca A | **Safety** |
| 8 | Méca B | **Safety** |
| 9 | Méca C (benne) | **Safety** |
| 10 | Thermique frein commun | **Safety** |
| 11 | Méca D | **Safety** |
| 12 | Méca E détection | Process |
| 13 | Méca E escalade | **Safety** |
| 14 | Sens réel opposé commande | Process |
| 15 | Absence mouvement malgré commande | Process |

Structure cible `ST_BypassWinch` (remplace le contenu actuel) :
```
TYPE ST_BypassWinch :
STRUCT
    EncoderFault      : BOOL; (* 🔧 INCHANGÉ — bypass codeur, verrouillé MAINT_N2 dans FB_Safety_Winch *)
    ContactorFeedback : BOOL; (* 🔌 INCHANGÉ *)
    TopLimitSwitch    : BOOL; (* 🚧 Bypass fin de course haute (bit5) — nouveau, homogène avec Translation.LimitSwitch *)
    CableLimitSwitch  : BOOL; (* 🚧 Bypass limite basse câble (bit6) — nouveau *)
    Safety            : BOOL; (* 🛡️ Bypass groupé bits PowerCutOff : 2,7,8,9,10,11,13 *)
    Process           : BOOL; (* ⚙️ Bypass groupé tout le reste : 0,1,3,4,5,6,12,14,15 *)
    Global            : BOOL; (* 🌐 INCHANGÉ *)
    Initialized       : BOOL := FALSE; (* 🚦 flag restauration boot, §5.1 *)
END_STRUCT
END_TYPE
```

**⚠️ Même correction qu'en §3ter** : `FB_Safety_Winch` prend des `VAR_INPUT` BOOL à PLAT
(`BypassGlobal` ligne 172, `EncoderFaultBypass` ligne 130), **PAS** un struct. Utiliser
`BypassSafety`/`BypassProcess`/`BypassTopLimitSwitch`/`BypassCableLimitSwitch` (noms à plat)
partout ci-dessous, jamais `Bypass.Xxx`.

**Étape A — Ajouter 4 nouveaux `VAR_INPUT`** à `FB_Safety_Winch.st` (près de `BypassGlobal`
ligne 172) :
```
    BypassSafety          : BOOL := FALSE;   // 🛡️ Bypass groupé PowerCutOff (bits 2,7,8,9,10,11,13)
    BypassProcess         : BOOL := FALSE;   // ⚙️ Bypass groupé SafeStop/Forbid seul (bits 0,1,3,4,5,6,12,14,15)
    BypassTopLimitSwitch  : BOOL := FALSE;   // 🚧 Bypass individuel fin de course haute (bit5)
    BypassCableLimitSwitch: BOOL := FALSE;   // 🚧 Bypass individuel limite basse câble (bit6)
```

**Étape B — Câblage dans le corps de `FB_Safety_Winch.st`** — le bloc `IF NOT BypassGlobal THEN
... END_IF` (lignes 295-500 actuelles) englobe déjà tout, **ne pas y toucher / ne pas ajouter
`OR BypassGlobal`** dans les tests individuels. Modifier UNIQUEMENT la condition de chaque test
concerné :

- **bit2 (Safety)** ligne 316 : `IF ThermalFeedback THEN` → `IF NOT BypassSafety AND ThermalFeedback THEN`
- **bit7 Méca A (Safety)** ligne 380 : `IF NOT BypassSafety AND (DriftGuardA.Violation OR (...)) THEN` (englober la condition existante entre parenthèses, préfixer par `NOT BypassSafety AND`)
- **bit8 Méca B (Safety)** ligne 394 (`TonMecaB(IN := ...)`) : `TonMecaB(IN := NOT BypassSafety AND MecaB_NoOperatorCmd AND NOT (...), PT := PostRampTimeout);`
- **bit9 Méca C (Safety)** ligne 407 (`DriftGuardC(Arm := ...)`) : `Arm := NOT BypassSafety AND BenneHoldStillActive,`
- **bit10 (Safety)** ligne 424 : `IF BrakeThermalFeedback THEN` → `IF NOT BypassSafety AND BrakeThermalFeedback THEN`
- **bit11 Méca D (Safety)** ligne 437 (`TonMecaD(IN := ...)`) : préfixer la condition `IN :=` par `NOT BypassSafety AND (...)`
- **bit13 Méca E escalade (Safety)** ligne 465 (`TonMecaE(IN := ...)`) : `TonMecaE(IN := NOT BypassSafety AND ((ErrorId AND 16#1000)...), PT := PostRampTimeout);`
- **bit0 (Process)** ligne 297 : `IF NOT JoystickOnline OR ... THEN` → `IF NOT BypassProcess AND (NOT JoystickOnline OR NOT JoystickOperational OR NOT HeartbeatIhmOk) THEN`
- **bit1 (Process, EN PLUS de `EncoderFaultBypass` existant, INCHANGÉ)** ligne 307-308 : ajouter
  `OR (BypassProcess AND Mode = E_Mode.MAINT_N2)` à la formule `EncoderAvailableEffective` (même
  garde-fou MAINT_N2 que le bypass individuel existant — ne pas affaiblir la protection)
- **bit3 (Process)** ligne 325 : `IF SlackCableDetected THEN` → `IF NOT BypassProcess AND SlackCableDetected THEN`
- **bit4 (Process)** ligne 333 : `IF NOT PhaseRotationOk THEN` → `IF NOT BypassProcess AND NOT PhaseRotationOk THEN`
- **bit5 (Process + individuel `TopLimitSwitch`)** ligne 344 : `IF NOT TopPositionSensor AND NOT InReferencingMode AND (Direction > 0) THEN` → `IF NOT (BypassProcess OR BypassTopLimitSwitch) AND NOT TopPositionSensor AND NOT InReferencingMode AND (Direction > 0) THEN`
- **bit6 (Process + individuel `CableLimitSwitch`)** ligne 353 : même pattern, `IF NOT (BypassProcess OR BypassCableLimitSwitch) AND (CfgCableLimitDescentM < 0.0) AND ...`
- **bit12 Méca E détection (Process)** ligne 458 : ajouter `NOT BypassProcess AND` en tête de la condition `IF SyncEnable AND NOT BenneBusy AND ...`
- **bit14 (Process)** ligne 476 (`OppositeDirectionActive := ...`) : préfixer par `NOT BypassProcess AND (...)`
- **bit15 (Process)** ligne 489 (`TonNoMovement(IN := ...)`) : préfixer la condition `IN :=` par `NOT BypassProcess AND (...)`

⚠️ **bit5/bit6 servent aussi à `ForbidAscent`/`ForbidDescent`** (lignes 521, 526-528, hors du bloc
`ErrorId`) — **NE PAS toucher ces 2 lignes**, elles lisent `ErrorId AND 16#0020`/`16#0040` qui sera
déjà à 0 si le bit n'a jamais été levé grâce au bypass ci-dessus (pas besoin de dupliquer le bypass
à cet endroit, la correction en amont suffit).

**Étape C — Mettre à jour les 2 appels dans `CODE/MAIN/PRG_03_Safety.st`** (`instSafetyWinchM1`
lignes ~41-72, `instSafetyWinchM2` lignes ~87-116 actuelles — même FB `FB_Safety_Winch`, 2
instances, donc 2 blocs d'appel à mettre à jour, mais un seul fichier `.st` de la FB à modifier) :
ajouter, dans CHAQUE bloc d'appel, après la ligne `BypassGlobal := ...` :
```
    BypassSafety           := GVL_IHM.M1TreuilRetenue.Bypass.Global OR GVL_IHM.M1TreuilRetenue.Bypass.Safety,
    BypassProcess          := GVL_IHM.M1TreuilRetenue.Bypass.Global OR GVL_IHM.M1TreuilRetenue.Bypass.Process,
    BypassTopLimitSwitch   := GVL_IHM.M1TreuilRetenue.Bypass.Global OR GVL_IHM.M1TreuilRetenue.Bypass.TopLimitSwitch,
    BypassCableLimitSwitch := GVL_IHM.M1TreuilRetenue.Bypass.Global OR GVL_IHM.M1TreuilRetenue.Bypass.CableLimitSwitch
```
(remplacer `M1TreuilRetenue` par `M2TreuilBenne` dans le 2e bloc d'appel — sinon strictement
identique). Suivre le même style que les lignes existantes (`Global OR <bit correspondant>`).

## 4. Fichiers à modifier

1. `CODE/SUPERVISION/_TYPES/ST_BypassWinch.st` (§5.1 + §3quater)
2. `CODE/SUPERVISION/_TYPES/ST_BypassTranslation.st` (§5.1 + §3ter)
3. `CODE/SUPERVISION/_TYPES/ST_BypassNetwork.st` (§3bis, remplace le contenu)
4. `CODE/MAIN/PRG_09_Supervision.st`
5. `CODE/TRANSLATION/FB_Safety_Translation.st` (§3ter Étapes A+B)
6. `CODE/TREUILS/FB_Safety_Winch.st` (§3quater Étapes A+B — modifications ligne par ligne listées, rien d'autre)
7. `CODE/MAIN/PRG_03_Safety.st` (§3ter Étape C + §3quater Étape C — câblage des nouveaux paramètres à l'appel des 3 instances)
8. `CODE/CODE_Bundle.xml` (régénération obligatoire, voir §7)

## 5. Modification exacte à faire

### 5.1 — Ajouter le champ `Initialized` à chaque struct

Dans **chacun** des 3 fichiers struct (§3), ajouter EN FIN de struct (après le dernier champ
existant, avant `END_STRUCT`) :

```
    // 🐛 FIX persistance (voir DOC/AUDITS/ConfigPersistence/) : flag restauration boot dédié
    // (défaut FALSE non ambigu, contrairement à une valeur métier) — PRG_09_Supervision.st
    Initialized : BOOL := FALSE; (* 🚦 TRUE = bypass restauré depuis GVL_BypassRetain ce boot *)
```

Ne rien renommer, ne rien réordonner d'autre dans ces 3 fichiers.

### 5.2 — État actuel exact de `PRG_09_Supervision.st` à remplacer

**Déclaration** (lignes 20-29 actuelles) :
```
VAR
    instBlink1Hz : BLINK; // 🧩 Réutilisation lib Util (Partie3 §0) — horloge clignotement système
    instAckConfigRestored : R_TRIG; // 🔔 Front acquittement opérateur restauration config PERSISTENT (§2bis)
END_VAR
VAR RETAIN
    // 🐛 FIX 2026-07-23 : passé de VAR simple à VAR RETAIN — en VAR simple, ce flag repassait à
    // FALSE à CHAQUE reset/download (même quand GVL_IHM RETAIN restait intact), re-déclenchant la
    // restauration bypass et pouvant re-forcer un bypass Global que l'opérateur venait de couper.
    BypassRestoreDone : BOOL := FALSE; // 🌐 Flag restauration unique des bypass (boot)
END_VAR
```

**Bloc de restauration** (lignes ~215-238 actuelles, section "🌐 Restauration des bypass RETAIN au
boot") :
```
IF NOT BypassRestoreDone THEN
    IF BypassTranslationGlobal AND GVL_IHM.TranslationM3.Bypass.Global = FALSE THEN
        GVL_IHM.TranslationM3.Bypass.Global := TRUE;
    END_IF;
    IF BypassWinchM1Global AND GVL_IHM.M1TreuilRetenue.Bypass.Global = FALSE THEN
        GVL_IHM.M1TreuilRetenue.Bypass.Global := TRUE;
    END_IF;
    IF BypassWinchM2Global AND GVL_IHM.M2TreuilBenne.Bypass.Global = FALSE THEN
        GVL_IHM.M2TreuilBenne.Bypass.Global := TRUE;
    END_IF;
    IF BypassSyncGlobal AND GVL_IHM.Sync.BypassGlobal = FALSE THEN
        GVL_IHM.Sync.BypassGlobal := TRUE;
    END_IF;
    IF BypassNetworkGlobal AND GVL_IHM.Network.Bypass.Global = FALSE THEN
        GVL_IHM.Network.Bypass.Global := TRUE;
    END_IF;
    IF BypassBucketGlobal AND GVL_IHM.M2Benne.BypassGlobal = FALSE THEN
        GVL_IHM.M2Benne.BypassGlobal := TRUE;
    END_IF;
    BypassRestoreDone := TRUE;
END_IF;
```

**Sauvegarde continue** (lignes ~341-346 actuelles) :
```
BypassTranslationGlobal     := GVL_IHM.TranslationM3.Bypass.Global;
BypassWinchM1Global         := GVL_IHM.M1TreuilRetenue.Bypass.Global;
BypassWinchM2Global         := GVL_IHM.M2TreuilBenne.Bypass.Global;
BypassSyncGlobal            := GVL_IHM.Sync.BypassGlobal;
BypassNetworkGlobal         := GVL_IHM.Network.Bypass.Global;
BypassBucketGlobal          := GVL_IHM.M2Benne.BypassGlobal;
```

Les variables `BypassTranslationGlobal`/`BypassWinchM1Global`/etc. sont déclarées dans
`CODE/MAIN/GVL_BypassRetain.st` (`VAR_GLOBAL RETAIN`, **PAS** `PERSISTENT` — voir §6, ne pas
changer ce point).

### 5.3 — Remplacement à produire

**Ne toucher QUE les 4 structs Winch/Translation/Network** (M1, M2, Translation, Network) — Sync et
Bucket restent gérés par l'ancien mécanisme `BypassSyncGlobal`/`BypassBucketGlobal` /
`BypassRestoreDone` **inchangé** pour l'instant (hors périmètre, §3).

Nouveau bloc de restauration (remplace le bloc §5.2, en gardant Sync/Bucket tels quels) :
```
IF NOT GVL_IHM.TranslationM3.Bypass.Initialized THEN
    IF BypassTranslationGlobal THEN
        GVL_IHM.TranslationM3.Bypass.Global := TRUE;
    END_IF;
    GVL_IHM.TranslationM3.Bypass.Initialized := TRUE;
END_IF;

IF NOT GVL_IHM.M1TreuilRetenue.Bypass.Initialized THEN
    IF BypassWinchM1Global THEN
        GVL_IHM.M1TreuilRetenue.Bypass.Global := TRUE;
    END_IF;
    GVL_IHM.M1TreuilRetenue.Bypass.Initialized := TRUE;
END_IF;

IF NOT GVL_IHM.M2TreuilBenne.Bypass.Initialized THEN
    IF BypassWinchM2Global THEN
        GVL_IHM.M2TreuilBenne.Bypass.Global := TRUE;
    END_IF;
    GVL_IHM.M2TreuilBenne.Bypass.Initialized := TRUE;
END_IF;

IF NOT GVL_IHM.Network.Bypass.Initialized THEN
    IF BypassNetworkGlobal THEN
        GVL_IHM.Network.Bypass.Global := TRUE;
    END_IF;
    GVL_IHM.Network.Bypass.Initialized := TRUE;
END_IF;

// 🌐 Sync/Bucket : pas encore de struct Bypass dédié (hors périmètre de ce lot, voir §3) —
// mécanisme BypassRestoreDone conservé UNIQUEMENT pour ces 2-là.
IF NOT BypassRestoreDone THEN
    IF BypassSyncGlobal AND GVL_IHM.Sync.BypassGlobal = FALSE THEN
        GVL_IHM.Sync.BypassGlobal := TRUE;
    END_IF;
    IF BypassBucketGlobal AND GVL_IHM.M2Benne.BypassGlobal = FALSE THEN
        GVL_IHM.M2Benne.BypassGlobal := TRUE;
    END_IF;
    BypassRestoreDone := TRUE;
END_IF;
```

La section "sauvegarde continue" (§5.2, lignes ~341-346) **ne change pas** — elle reste
inconditionnelle pour les 6 variables, exactement comme aujourd'hui (pas de garde `Initialized`
nécessaire ici : ces lignes ne font que recopier l'état courant vers `GVL_BypassRetain`, jamais
l'inverse, donc pas de risque d'écrasement).

La déclaration `VAR RETAIN BypassRestoreDone` (§5.2) reste **inchangée** (toujours nécessaire pour
Sync/Bucket).

## 6. Contraintes à respecter STRICTEMENT

- **Ne pas transformer `GVL_BypassRetain` en `PERSISTENT`.** Son en-tête documente explicitement
  "Survit au Warm Restart mais PAS au Download" — c'est un choix de sécurité assumé (un bypass ne
  doit jamais survivre silencieusement à une reprogrammation). Ce lot corrige uniquement le bug de
  flag partagé, pas la nature RETAIN-simple de `GVL_BypassRetain`.
- **Ne pas ajouter de logique d'alarme IHM** pour ce lot (contrairement au fix Winch/Sync qui a une
  alarme `ConfigRestoredFromPersistent`) — un bypass qui se restaure silencieusement est acceptable
  ici (pas de nouvelle exigence produit sur ce point, ne pas improviser).
- **Ne pas toucher** `FB_Winch.st`, `FB_Translation.st`, `FB_Bucket.st` — aucune de ces FB de
  mouvement n'a besoin de changement pour ce lot.
- **Exceptions** (2 FB Safety, uniquement selon les patterns exacts décrits) :
  - `FB_Safety_Translation.st` : pattern §3ter (9 tests, `OR Bypass.Safety`/`OR Bypass.Process`).
  - `FB_Safety_Winch.st` : pattern §3quater (16 bits classés, modifications ligne par ligne
    listées). Ne pas toucher `ForbidAscent`/`ForbidDescent` (lignes 521, 526-528) — déjà couvert
    en amont, voir remarque §3quater.
  - Aucune autre modification de ces 2 FB au-delà de ce qui est listé.
- **PascalCase strict**, pas de hongrois (`DOC/NAMING_CONVENTION.md`).

## 7. Obligatoire avant restitution

1. Régénérer le bundle : `python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .` depuis
   la racine du dépôt — doit se terminer par `PASS: CODE/CODE_Bundle.xml is fresh`.
2. Lancer `python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --skip-codesys` — aucune NOUVELLE
   erreur ne doit apparaître par rapport à l'état actuel (des erreurs préexistantes sans lien avec
   ce lot peuvent déjà être présentes, ne pas essayer de les corriger, hors périmètre).
3. Ne PAS committer — restituer le diff pour vérification.

## 8. Critères d'acceptation (vérifiés par le relecteur)

- [ ] `Initialized : BOOL := FALSE;` ajouté dans `ST_BypassWinch.st`, `ST_BypassTranslation.st`,
      `ST_BypassNetwork.st` — et **uniquement** ces 3 fichiers struct.
- [ ] `PRG_09_Supervision.st` : bloc de restauration Winch M1/M2/Translation/Network gardé
      individuellement par `NOT <Instance>.Bypass.Initialized`, plus par `BypassRestoreDone`.
- [ ] `BypassRestoreDone` reste utilisé **uniquement** pour Sync et Bucket (inchangés).
- [ ] Section "sauvegarde continue" (6 lignes `BypassXxxGlobal := GVL_IHM...`) **inchangée**.
- [ ] `GVL_BypassRetain.st` **non modifié** (toujours `VAR_GLOBAL RETAIN`, pas `PERSISTENT`).
- [ ] Aucune modification de `FB_Winch.st`/`FB_Translation.st`/`FB_Bucket.st`.
- [ ] `ST_BypassNetwork.st` : `Joystick`/`EncoderM1`/`EncoderM2`/`VariateurM3`/`Global`/`Initialized`
      — pas de champ supplémentaire, pas de câblage logique ajouté ailleurs (hors périmètre).
- [ ] `ST_BypassTranslation.st` : `Safety`/`Process` ajoutés en plus des 9 champs individuels
      existants + `Global` + `Initialized`.
- [ ] `FB_Safety_Translation.st` : 2 nouveaux `VAR_INPUT` (`BypassSafety`/`BypassProcess`, à PLAT,
      pas de struct), chaque test modifié suit EXACTEMENT
      `IF NOT (BypassSafety|BypassProcess OR Bypass<bit>) THEN` (**sans** `OR BypassGlobal`, déjà
      géré par le gate englobant existant) — classification conforme au masque
      `PowerCutOff := (ErrorId AND 16#00F8)` (§3ter). Aucune autre ligne modifiée.
- [ ] `ST_BypassWinch.st` : `TopLimitSwitch`/`CableLimitSwitch`/`Safety`/`Process` ajoutés, en plus
      de `EncoderFault`/`ContactorFeedback`/`Global`/`Initialized` existants.
- [ ] `FB_Safety_Winch.st` : 4 nouveaux `VAR_INPUT` à PLAT, les 16 bits câblés exactement selon le
      tableau §3quater (7 bits `Safety`, 9 bits `Process` dont 2 avec bypass individuel en plus) —
      **sans** `OR BypassGlobal` nulle part (gate englobant déjà présent) — bit1 garde
      `AND Mode = E_Mode.MAINT_N2` sur le nouveau chemin `BypassProcess` (même garde-fou que
      l'existant `EncoderFaultBypass`) — `ForbidAscent`/`ForbidDescent` (lignes 521, 526-528) non
      modifiées.
- [ ] `PRG_03_Safety.st` : les 3 appels (`instSafetyTranslationM3`, `instSafetyWinchM1`,
      `instSafetyWinchM2`) mettent à jour les nouveaux paramètres à plat en lisant
      `GVL_IHM...Bypass.Global OR GVL_IHM...Bypass.<Champ>` — même style que les lignes existantes.
- [ ] Bundle régénéré et frais (`check_bundle_freshness` = PASS).
- [ ] Gates `run_all_gates.py --skip-codesys` : pas de nouvelle erreur introduite.
