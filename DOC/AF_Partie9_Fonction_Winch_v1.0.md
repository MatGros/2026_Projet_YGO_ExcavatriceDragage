# 📋 Analyse Fonctionnelle — Partie 9 : Fonction Winch (v1.0)

> **Fonction métier** : chaîne de commande Joystick (axe Y, Plongée/Extraction) → `FB_Winch` →
> relais de sens et de vitesse, avec séquence frein. Premier lot testable en **Maintenance N1**,
> treuil **M1 seul**, **sans dépendance codeur**.
> **Cible** : CODESYS 3.5 — application **manuelle** par l'utilisateur.
> 🔗 Dépend de : [P2 Architecture v2.5](AF_Partie2_Architecture_Programme_v2.5.md), [P3 Contrat FB v1.2](AF_Partie3_Template_FB_Commun_v1.2.md), [P4 Cycle v1.1](AF_Partie4_Cycle_Sequenceur_v1.1.md) §3bis/§4, [P5 Modes v1.1](AF_Partie5_Modes_Maintenance_v1.1.md), [P8 Joystick v1.1](AF_Partie8_Fonction_Joystick_v1.1.md).

---

## 🎯 1. Rôle métier

Traduire la consigne d'axe du joystick (`ST_AxisCmd`, axe Y = Plongée/Extraction) en commande
physique d'un treuil : sens de rotation (2 contacteurs), palier de vitesse (4 contacteurs,
masque 4 bits), et séquence de frein à manque de courant — dans le respect strict de la
précédence `Enable` > `SafeStop` > `StartStop` (Partie3 §1bis).

Objectif de ce lot : **valider la chaîne complète en Maintenance N1** sur le treuil **M1**,
piloté **unitairement** (droit N1, Partie5 §2), **sans codeur** (acquisition non finalisée —
voir §5 Sécurité pour ce que cela implique concrètement).

---

## ⚙️ 2. Chaîne de traitement (pipeline)

```
FB_Joystick.AxisCmdY ──► FB_Winch(M1) ──┬─► FB_SpeedStep ──► Contactor1..4 (table P<palier>R<relais>)
                                        ├─► RelayFwd / RelayRev (interlock changement de sens)
                                        └─► FB_Brake ──► BrakeCmd (séquence temporisée)

FB_Safety_Winch ──► SafeStop ──► (entrée) FB_Winch(M1)
```

| Bloc | Rôle métier |
|------|-------------|
| `FB_SpeedStep` | Décode `SpeedRefPct` (0..100 %) en 4 sorties `Contactor1..4`, via table `ST_SpeedStepTable` propre à M1 (paramétrage individuel `P<palier>R<relais>`), sélection par `HYSTERESIS` (lib Util, anti-battement) |
| `FB_Brake` | Séquence frein temporisée (relâche après magnétisation, collage après décélération), double vérif retour contacteur |
| `FB_Safety_Winch` | Bloc safety **métier** du domaine treuil : lève `SafeStop` sur perte joystick/CAN (codeur **TBD**, non câblé ce lot) |
| `FB_Winch` | Assemble les deux + arbitrage rampe `Enable > SafeStop > StartStop` + interlock sens |

> ♻️ **Réutilisation** (Partie3 §0) : `HYSTERESIS` (lib Util) pour les paliers, `FB_Ramp` +
> `FB_CycleTime` (déjà utilisés par `FB_Joystick`) pour la rampe interne — aucune brique
> réinventée.

---

## 🔌 3. Interface `FB_Winch` (FB de mouvement, Partie3 §1bis)

**📥 Entrées**
| Entrée | Type | Rôle |
|--------|------|------|
| `Enable` | BOOL | `FALSE` = neutralisation totale (sorties coupées) |
| `Reset` | BOOL | Acquittement défaut (front) |
| `EmergencyStopOk` | BOOL | Chaîne AU réarmée + conditions globales OK |
| `Mode` | `E_Mode` | Contexte (droits arbitrés en amont, `FB_Modes` à venir) |
| `StartStop` | BOOL | `TRUE` = rampe accélération, `FALSE` = rampe décélération normale |
| `SafeStop` | BOOL | Sortie `FB_Safety_Winch` : `TRUE` = rampe décélération **rapide** |
| `Direction` | INT | -1/0/+1 |
| `SpeedRefPct` | REAL | Consigne 0..100 % |
| `SpeedStepTable` | `ST_SpeedStepTable` | Table des 5 paliers **propre à M1** (20 `BOOL` `P<palier>R<relais>` + seuils) |
| `ContactorFeedbackFwd/Rev` | BOOL | Retours contacteurs de sens |
| `BrakeFeedback` | BOOL | Retour contacteur bobine frein |

**📤 Sorties clés**
| Sortie | Type | Rôle |
|--------|------|------|
| `RelayFwd` / `RelayRev` | BOOL | Contacteurs de sens (jamais simultanés — interlock) |
| `Contactor1..4` | BOOL | Contacteurs de vitesse du palier courant (lus dans `Table.P<palier>R<relais>`) |
| `BrakeCmd` | BOOL | Commande bobine frein (`TRUE` = relâché) |
| `Ready/Busy/Done/Error/ErrorId/State/StateAtError` | — | État standard (Partie3 §1) |
| `FwdContactorCheck/RevContactorCheck/BrakeContactorCheck` | `ST_ContactorCheck` | Diagnostic détaillé (IHM) |

`ErrorId` : bit0 = défaut frein, bit1 = contacteur sens Fwd incohérent, bit2 = contacteur sens Rev incohérent.

---

## 🛡️ 4. Sécurité

- **Précédence stricte** `Enable > SafeStop > StartStop` (arbitrage rampe interne à `FB_Winch`,
  indépendant de la rampe déjà appliquée par `FB_Joystick` sur la consigne).
- **Interlock changement de sens** : `RelayFwd`/`RelayRev` ne sont jamais actifs simultanément ;
  **seul l'engagement initial** neutre→un sens est immédiat — un arrêt (un sens→neutre) **et**
  une inversion directe Fwd↔Rev exigent tous les deux la vitesse rampée confirmée nulle
  (`DirectionInterlockDelay`), pour que le contacteur de sens reste actif tout le temps de la
  décélération réelle (cohérent avec le palier et le frein).
- **Frein** : séquence temporisée stricte (Partie4 §4) — jamais de relâche avant fermeture
  contacteur + magnétisation, jamais de collage avant décélération.
- **Double vérification contacteurs** (sens + frein) via `ST_ContactorCheck` : incohérence
  commande/retour au-delà d'un timeout → `ErrorId`.
- **Sortie sûre sur défaut** (`FB_Winch`/`FB_Brake`) : `Error` force `RelayFwd`/`RelayRev`/
  `Contactor1..4`/`BrakeCmd` à leur état sûr (coupure directe, frein collé), conforme Partie3
  §9 étape 7 — un contacteur incohérent ne doit plus jamais rester commandé normalement.

> 🔧 **Correctifs retour terrain + revue de code 2026-07-01** (2 itérations) :
> 1. La 1ère version de l'interlock exigeait la vitesse confirmée nulle (200 ms) **avant même
>    le tout premier engagement** (neutre → un sens) — or la rampe interne quitte le seuil de
>    repos en ~2 ms dès qu'une consigne existe (`AccelRate` 50 %/s), donc `CommandedDirection`
>    restait bloqué à 0 en permanence : les paliers de vitesse évoluaient (`Contactor1..4`),
>    mais aucun `RelayFwd`/`RelayRev` ne s'activait jamais (symptôme observé : "les relais
>    vitesse évoluent mais pas de commande de sens").
> 2. Le correctif 1 traitait ensuite "un sens → neutre" comme immédiat lui aussi — or
>    `Contactor1..4` suit une rampe indépendante (`SpeedRamp.Current`) : un arrêt demandé
>    coupait le contacteur de sens **avant** la fin de la décélération réelle, frein encore
>    ouvert (non conforme Partie3 §9). Corrigé dans `CODE/FB_Winch.st` §3bis (revue de code
>    indépendante) : seul l'engagement initial est immédiat, arrêt et inversion directe
>    exigent tous les deux la vitesse confirmée nulle.
> 3. Ajout de la sortie sûre sur `Error` (ci-dessus), absente des deux versions précédentes.

### ⚠️ Ce que « pas de codeur » signifie concrètement pour ce lot

`FB_Winch` **ne consomme pas** le codeur directement (il n'en a jamais eu besoin — c'est
`FB_WinchSync`/`FB_Encoder_Safety`, absents de ce lot, qui l'utilisent). `FB_Safety_Winch`
couvre **uniquement** la perte joystick/CAN pour ce lot ; la perte codeur/EtherCAT M1 est
**explicitement non câblée** (pas de stub simulé) — voir `CODE/FB_Safety_Winch.st`.

Conséquence assumée (validée avec l'utilisateur) : **aucune limite de fin de course logicielle**
tant que le codeur n'est pas fiabilisé. En Maintenance N1, le pilotage reste **unitaire** et
**revalidé en continu par le joystick (homme-mort)** : relâcher le joystick arrête le mouvement
via la rampe. Ne pas utiliser cette chaîne au-delà de la vigilance opérateur directe (pas de
descente sans surveillance visuelle des fins de câble physiques).

---

## 🗺️ 5. Mapping E/S (à créer en I/O Mapping CODESYS, voir §7)

| Variable (code) | Sens | Rôle |
|------------------|------|------|
| `M1_RelayFwd` | Sortie | Contacteur sens avant (montée) M1 |
| `M1_RelayRev` | Sortie | Contacteur sens arrière (descente) M1 |
| `M1_Contactor1..4` | Sortie | Contacteurs de vitesse M1 (palier courant, table `P<palier>R<relais>`) |
| `M1_BrakeCmd` | Sortie | Bobine frein M1 (`TRUE` = relâché) |
| `M1_ContactorFeedbackFwd/Rev` | Entrée | Retours contacteurs de sens M1 |
| `M1_BrakeFeedback` | Entrée | Retour contacteur bobine frein M1 |

---

## 💻 6. Implémentation (référence code)

📂 **Code source à copier (unique)** — dossier `CODE/` :
- [`CODE/E_Mode.st`](../CODE/E_Mode.st), [`CODE/E_State.st`](../CODE/E_State.st) — fondations manquantes
- [`CODE/ST_SpeedStepTable.st`](../CODE/ST_SpeedStepTable.st), [`CODE/ST_ContactorCheck.st`](../CODE/ST_ContactorCheck.st)
- [`CODE/ST_AxisCmd.st`](../CODE/ST_AxisCmd.st) — **mise à jour** (renommage `Start`→`StartStop`, retrait `SafetyOk`)
- [`CODE/FB_Joystick.st`](../CODE/FB_Joystick.st) — **mise à jour** (suit `ST_AxisCmd`, renomme `SafetyOk`→`EmergencyStopOk`, l'ajoute au GATE)
- [`CODE/FB_SpeedStep.st`](../CODE/FB_SpeedStep.st), [`CODE/FB_Brake.st`](../CODE/FB_Brake.st) — nouvelles briques composées
- [`CODE/FB_Safety_Winch.st`](../CODE/FB_Safety_Winch.st) — nouveau bloc safety métier
- [`CODE/FB_Winch.st`](../CODE/FB_Winch.st) — nouveau FB de mouvement
- [`CODE/PRG_MAIN.st`](../CODE/PRG_MAIN.st) — **mise à jour** (câblage complet)

*(Pas de recopie du corps ici — voir les fichiers `CODE/` pour le ST complet, règle anti-doublon.)*

---

## 📝 7. Note d'application CODESYS 3.5 (manuel, pas à pas)

> ⚠️ **Ordre impératif** (dépendances entre objets) : suivre les étapes dans l'ordre ci-dessous.
> Chaque étape indique précisément quoi cocher/sélectionner dans les fenêtres CODESYS.

### Étape 0 — Vérifier la bibliothèque Util (pour `HYSTERESIS`)
1. Menu **Outils → Library Repository** (ou **Bibliothèques** dans l'arbre projet, nœud
   `Library Manager`).
2. Ouvrir **Library Manager** (double-clic dans l'arbre projet).
3. Vérifier que **`Util`** apparaît dans la liste. Si absent : bouton **Add library...** →
   rechercher `Util` → sélectionner → **OK**.
   *(Sans ça, `HYSTERESIS` dans `FB_SpeedStep` ne compilera pas.)*

> 🔧 **Correctif 2026-07-01** : la 1ère version de `FB_SpeedStep.st` supposait une interface
> `HYSTERESIS(XIN1, XIN2, EPSILON → Q)` qui n'existe pas dans `Util` 3.5.19.0. L'interface réelle
> (confirmée par la doc officielle CODESYS) est `HYSTERESIS(IN, HIGH, LOW : INT → OUT : BOOL)`
> — `OUT` passe à `TRUE` quand `IN < LOW`, à `FALSE` quand `IN > HIGH`, maintien entre les deux.
> `CODE/FB_SpeedStep.st` a été corrigé en conséquence (conversion `SpeedRefPct` REAL → INT via
> `REAL_TO_INT`). **Recoller ce fichier si tu avais déjà créé `FB_SpeedStep` avec la 1ère version.**

### Étape 1 — Créer les types fondamentaux (`_TYPES` ou racine `Application`)
Clic droit sur **Application** (ou un sous-dossier `_TYPES` si tu préfères en créer un :
clic droit → **Add Object → Folder...** → Name = `_TYPES` → **Add**) :

Pour **`E_Mode`** et **`E_State`** :
1. Clic droit → **Add Object → DUT...**
2. Champ **Name** : `E_Mode` (puis répéter pour `E_State`)
3. Champ **Type** (menu déroulant) : sélectionner **`Enumeration`**
4. Bouton **Add**
5. Dans l'éditeur qui s'ouvre, **effacer tout le contenu généré** et coller le contenu de
   `CODE/E_Mode.st` (resp. `CODE/E_State.st`) — un seul bloc `TYPE ... END_TYPE`, pas de
   séparation déclaration/implémentation pour un DUT.

Pour **`ST_SpeedStepTable`** et **`ST_ContactorCheck`** :
1. Clic droit → **Add Object → DUT...**
2. Champ **Name** : `ST_SpeedStepTable` (puis `ST_ContactorCheck`)
3. Champ **Type** : sélectionner **`Structure`**
4. **Add**, puis coller le contenu du fichier `CODE/` correspondant (remplace tout).

> 🔧 **Évolution retour terrain 2026-07-01** : `ST_SpeedStepTable` n'utilise plus un masque
> `BYTE` packé par palier, mais **20 `BOOL` nommés individuellement** `P1R1`..`P5R4`
> (`P`=Palier, `R`=Relais de vitesse 1..4) — chacun réglable **un par un**, en direct dans la
> vue instance CODESYS pendant la mise en service, sans manipuler de valeur binaire packée.
> Si tu avais déjà créé `ST_SpeedStepTable`/`FB_SpeedStep`/`FB_Winch` avec la 1ère version
> (masque `BYTE`), **recoller les 3 fichiers** (`ST_SpeedStepTable.st`, `FB_SpeedStep.st`,
> `FB_Winch.st`) et le `M1_SpeedStepTable` de `PRG_MAIN.st`.

### Étape 2 — Mettre à jour `ST_AxisCmd`
1. Double-clic sur `ST_AxisCmd` existant (racine `Application`, à côté de `ST_DeviceDiag`).
2. Sélectionner tout le contenu, remplacer par le contenu de `CODE/ST_AxisCmd.st`.
3. **Enregistrer** (Ctrl+S). Ne pas compiler tout de suite (des erreurs de référence sur
   `FB_Joystick` sont attendues tant que l'étape 3 n'est pas faite — normal).

### Étape 3 — Mettre à jour `FB_Joystick`
1. Double-clic sur `FB_Joystick` (dossier `JOYSTICK`).
2. Le POU a **deux volets** : le volet **déclaration** (haut, VAR_INPUT/OUTPUT/VAR) et le
   volet **implémentation** (bas, code ST).
3. Dans le volet déclaration : effacer tout, coller la section **DECLARATION** de
   `CODE/FB_Joystick.st`.
4. Dans le volet implémentation : effacer tout, coller la section **IMPLEMENTATION** du
   même fichier.
5. **Enregistrer**.

### Étape 4 — Créer `FB_SpeedStep`
1. Clic droit sur le dossier **WINCH** (le créer d'abord si absent : clic droit sur
   `Application` → **Add Object → Folder...** → Name = `WINCH` → **Add**).
2. Clic droit sur `WINCH` → **Add Object → POU...**
3. Champ **Name** : `FB_SpeedStep`
4. Champ **Type** (radio) : sélectionner **`Function block`**
5. Champ **Implementation language** (radio) : sélectionner **`Structured Text (ST)`**
6. Laisser **Extends** et **Implements** vides (pas d'héritage — composition, règle projet)
7. **Add**
8. Coller la section **DECLARATION** de `CODE/FB_SpeedStep.st` dans le volet déclaration,
   la section **IMPLEMENTATION** dans le volet implémentation. **Enregistrer**.

### Étape 5 — Créer `FB_Brake`
Idem étape 4, mais :
- Dossier cible : **`_COMMON`** (le créer si absent, comme à l'étape 4 pour `WINCH`) —
  `FB_Brake` est une brique réutilisable (Partie2 §3), pas spécifique à un seul treuil.
- **Name** : `FB_Brake`, **Type** : `Function block`, **Language** : `Structured Text (ST)`.
- Coller `CODE/FB_Brake.st` (déclaration + implémentation).

### Étape 6 — Créer `FB_Safety_Winch`
- Dossier cible : **`SAFETY`** (existe déjà — contient `FB_Safety`).
- **Add Object → POU...** → **Name** : `FB_Safety_Winch`, **Type** : `Function block`,
  **Language** : `Structured Text (ST)`.
- Coller `CODE/FB_Safety_Winch.st`.

### Étape 7 — Créer `FB_Winch`
- Dossier cible : **`WINCH`**.
- **Add Object → POU...** → **Name** : `FB_Winch`, **Type** : `Function block`,
  **Language** : `Structured Text (ST)`.
- Coller `CODE/FB_Winch.st`.

### Étape 8 — Mettre à jour `PRG_MAIN`
1. Double-clic sur `PRG_MAIN` (dossier `SYSTEM`, ou racine selon ton arborescence actuelle).
2. Volet déclaration : effacer tout, coller la section **DECLARATION** de `CODE/PRG_MAIN.st`.
3. Volet implémentation : effacer tout, coller la section **IMPLEMENTATION** du même fichier.
4. **Enregistrer**.

### Étape 9 — I/O Mapping (câblage physique réel) — **si le matériel est déjà branché**
Onglet **I/O Mapping** du device concerné (carte de sortie relais pour les commandes,
carte d'entrée TOR pour les retours) :

| Canal physique | Colonne **Variable** à saisir |
|-----------------|-------------------------------|
| Sortie contacteur sens avant M1 | `M1_RelayFwd` |
| Sortie contacteur sens arrière M1 | `M1_RelayRev` |
| Sortie contacteur vitesse 1..4 M1 | `M1_Contactor1`, `M1_Contactor2`, `M1_Contactor3`, `M1_Contactor4` |
| Sortie bobine frein M1 | `M1_BrakeCmd` |
| Entrée retour contacteur sens avant M1 | `M1_ContactorFeedbackFwd` |
| Entrée retour contacteur sens arrière M1 | `M1_ContactorFeedbackRev` |
| Entrée retour contacteur frein M1 | `M1_BrakeFeedback` |

*(Même principe que `JoyXRaw_ANA1`/`JoyYRaw_ANA2` déjà utilisés : taper le nom directement
dans la colonne Variable du canal correspondant — CODESYS crée la variable globale associée.)*

### Étape 9bis — GVL stub logiciel (câblage PAS ENCORE branché — choix retenu 2026-07-01)
Tant que le matériel de test (relais/retours M1) n'est pas branché, créer une GVL temporaire
plutôt que l'I/O Mapping :
1. Clic droit sur **Application** → **Add Object → Global Variable List (GVL)...**
2. **Name** : `GVL_Winch_M1_Stub` → **Add**
3. Coller le contenu de [`CODE/GVL_Winch_M1_Stub.st`](../CODE/GVL_Winch_M1_Stub.st) (10 `BOOL`,
   aucun relais réel piloté).
4. `PRG_MAIN.st` (déjà à jour dans `CODE/`) mire les retours contacteurs sur les commandes
   (`M1_ContactorFeedbackFwd := M1_RelayFwd`, etc.) pour simuler un contacteur idéal et éviter
   de faux défauts `StuckOpen` — bloc marqué `🧪 SIMULATION` dans le fichier, à supprimer en
   même temps que le GVL quand le matériel réel arrivera.
5. **Rebuild** doit passer sans erreur (hors avertissement `CAN` déjà présent, non lié à ce lot).

🔴 **Migration vers le matériel réel plus tard** : supprimer `GVL_Winch_M1_Stub` **et** le bloc
`🧪 SIMULATION` de `PRG_MAIN`, puis faire l'Étape 9 (I/O Mapping) avec les mêmes noms de
variables — les deux mécanismes ne peuvent pas coexister (conflit de nom).

### Étape 10 — Compiler et vérifier
1. Menu **Build → Rebuild all** (ou **F11**).
2. Corriger les éventuelles erreurs de référence résiduelles (noms de variables I/O Mapping
   pas encore saisis, typiquement — l'erreur indique la ligne exacte dans `PRG_MAIN`).
3. **Ne pas télécharger sur l'automate avant d'avoir un Rebuild propre (0 erreur).**

### 🔒 À sécuriser après remise en service (stubs debug de ce lot)
| Entrée debug | Remplacer par |
|--------------|---------------|
| `StubWinchEnableN1 := TRUE` (PRG_MAIN) | Sortie réelle `FB_Modes` (Enable arbitré par mode) |
| `EmergencyStopOk := GVL_DEBUG.DBG_True` (Joystick/Safety/Winch) | Chaîne AU réarmée réelle |
| `Reset := FALSE` (Joystick/Safety/Winch) | Front acquittement IHM |
| `Mode := E_Mode.MAINT_N1` (Safety/Winch) | Sortie réelle `FB_Modes` |
| Table `M1_SpeedStepTable` (valeurs par défaut cumulatives) | `P<palier>R<relais>` + seuils réels validés à la mise en service |

---

## 🔁 8. Retour d'expérience (à compléter après test)

- [x] Sens (Fwd/Rev) — bug interlock corrigé 2026-07-01 (neutre→un sens bloqué à tort) : à revalider en marche réelle
- [x] Revue de code indépendante 2026-07-01 : 2 critiques + 1 majeur corrigés (interlock arrêt
      prématuré, `Reset` non-front sur `FB_Joystick`, sortie sûre sur `Error` manquante) — à
      revalider en marche réelle malgré tout (défauts précédemment "dormants" en banc de test).
- [ ] Sens (Fwd/Rev) cohérent avec le joystick axe Y (haut = plongée ou extraction ? à vérifier au 1er essai)
- [ ] Paliers de vitesse progressifs et stables (pas de battement au changement de palier)
- [ ] Chaque `P<palier>R<relais>` de `M1_SpeedStepTable` réglé un par un selon le câblage réel des 4 contacteurs M1
- [ ] Frein : relâche bien après le délai (pas d'à-coup), collage bien après arrêt (pas de grincement)
- [ ] Interlock changement de sens : impossible de commuter Fwd/Rev en mouvement ; arrêt ET inversion directe bien bloqués hors vitesse confirmée nulle
- [ ] Relâcher le joystick → rampe de décélération normale → contacteur de sens reste actif jusqu'à l'arrêt réel → frein collé
- [ ] Défaut simulé (débrancher un retour contacteur) → sorties coupées immédiatement (sortie sûre sur `Error`)
- [ ] Seuils `StepThreshold_Pct` définitifs à figer une fois validés
- [ ] **Avant de câbler le CAN réel ou le bouton Reset IHM** : re-tester spécifiquement la
      perte joystick/CAN (`SafeStop`) et un Reset maintenu, actuellement inatteignables en
      banc d'essai (`CanOnline`/`CanOperational` figés `TRUE`, `Reset` figé `FALSE`)
- [ ] Si validé → dupliquer pour M2 (nouvelle instance `FB_Winch`, nouvelle table), puis
      réintégrer `FB_WinchSync`/`FB_Encoder_Safety` une fois le codeur fiabilisé

---

## 📚 Documents liés
- **Partie 2 v2.5** — Architecture (`FB_Winch`, `FB_SpeedStep`, mapping M1/M2).
- **Partie 3 v1.2** — Contrat FB (`StartStop`/`SafeStop`, ErrorId, reset).
- **Partie 4 v1.1** — Cycle (§3 Synchro, §4 Frein — règles reprises ici pour `FB_Brake`).
- **Partie 5 v1.1** — Modes & maintenance (droits Maintenance N1).
- **Partie 8 v1.1** — Fonction Joystick (source de `AxisCmdY`, corrections `ST_AxisCmd` liées).
