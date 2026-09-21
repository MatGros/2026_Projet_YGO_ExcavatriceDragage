# 📝 Note d'application — T367 · Acquittement AUTOMATIQUE borné (démarrage à froid & réarmement AU)

> 📅 2026-09-21 · 🧊 Statut : **implémenté, non commité** · 🏷️ Acteur : DSH01 · 🔒 Verrou : T367 (C2, `patch`)
> 📄 Contrat : `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T367_ACQ_AUTO_BOOT_ET_REARM.yaml`
> 📄 Contexte de conception : `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_T369_DEADLOCK_REARMEMENT_SIMU_20260921.md` §1 et §7
> 🎯 Objet : supprimer l'appui manuel sur le bouton d'acquittement dans **deux situations bornées**, sur décision de l'exploitant — et **TRACER explicitement l'écart de doctrine assumé**.

---

## 1. 🔒 Contrainte dictée par l'exploitant (verbatim)

> « au boot, le défaut (quel qu'il soit) doit être acquitté automatiquement, sans que j'aie besoin d'appuyer sur le bouton acquittement séparément. **Rien d'autre ne change** — aucun nouveau champ, aucune touche à GVL_IHM/ses types (table figée en ce moment pour livraison collègue). Si ta correction nécessite de toucher GVL_IHM ou un type associé, STOP et demande-moi avant. »
> + « oui GO mais il faut aussi l'implémenter après le réarmement AU contacteur de puissance »

**Conséquence de conception** : tout l'état des campagnes est porté par des **`VAR` / `VAR CONSTANT` LOCALES** au `PROGRAM PRG_07_Supervision` (non-RETAIN ⇒ 0 à froid), et la preuve « geste opérateur » est lue sur un bus **déjà public** (`PRG_06_Outputs.EmergencyState`). **Aucun champ créé, aucune GVL touchée, aucun type touché.**

---

## 2. ⚠️ ÉCART DE DOCTRINE ASSUMÉ — traçabilité explicite (jamais silencieux)

La doctrine du projet interdit l'acquittement automatique. Ce lot l'amende, **sur décision de l'exploitant (2026-09-21)**, **pour ces 2 cas seulement**.

| Règle amendée | Source | Ce que le lot fait | Portée de l'amendement |
|---|---|---|---|
| « `Reset` = front · évite le réarmement accidentel : **cause disparue + appui conscient** » | `AGENTS.md` § Principes non négociables | En (a) démarrage à froid et (b) après réarmement AU confirmé, l'impulsion est émise **sans** appui sur un bouton d'acquittement | **2 cas bornés uniquement**. Les 5 boutons existants gardent leur comportement, bit-identique. Aucun acquittement périodique, aucun acquittement en fonctionnement établi. |
| « Démarrer froid → **Demander le réarmement** » · « Coupure safety métier → traiter et **acquitter le défaut domaine, puis réarmer** » | `AF_Partie-01` §7.4 (table des actions opérateur) · §7.3 (« acquittement d'un défaut métier et réarmement du contacteur = deux actions distinctes ») | En (b), l'ordre devient **réarmer PUIS acquitter** automatiquement (l'acquittement est déclenché par la confirmation du contacteur de puissance) | Idem : 2 cas. Le **réarmement** lui-même reste **inchangé** : front de commande opérateur seulement, préconditions `Armable`, auto-test voies, aucun `FB` de sécurité modifié. |
| « Jamais de redémarrage auto après défaut » | `AGENTS.md` | **Aucun redémarrage n'est produit.** L'impulsion d'acquittement **n'ouvre aucun interlock ni aucun mouvement** : elle réarme des latches. Un défaut dont la cause est encore présente **reste latché et visible** (§7 ci-dessous). | L'écart porte sur l'**acquittement d'alarme**, jamais sur le démarrage machine, les permis ou la chaîne AU. |

**Ce qui autorise techniquement cet écart (propriété de non-masquage)** : `FB_FaultCore` exécute l'effacement sur `Reset` (§1) **AVANT** l'armement des latches (§3) **dans le même scan**. Une cause encore `Active AND Latching` **ré-arme son bit dans le scan même de l'impulsion**. L'acquittement automatique est donc **un no-op sur un défaut persistant** : il n'efface que les artefacts dont la cause a disparu. `FB_FaultCore` et tous les `FB` de sécurité sont **inchangés** par ce lot.

**⚠️ Décision à ne pas « améliorer »** : élargir la portée (acquittement périodique, acquittement en fonctionnement établi, acquittement sur front brut du contacteur) annulerait cette propriété de sûreté. Le garde-fou `G521_check_fault_reset_not_hw_triggered.py` refuse toute régression de ce type.

---

## 3. 🔇 Conséquence assumée : acquittement SILENCIEUX — risque résiduel

L'acquittement automatique est **silencieux** : **aucun compteur, aucun voyant, aucun texte IHM**. C'est une conséquence **directe** de la contrainte « aucun nouveau champ / aucune touche à `GVL_IHM` ».

- 🔎 **Risque résiduel assumé (contrat Q2)** : un défaut **réel mais DÉJÀ DISPARU** au moment du démarrage à froid est effacé **sans appui conscient**. L'opérateur ne voit donc ni qu'un défaut a existé, ni qu'il a été acquitté.
- 🧭 **Ce qui borne l'exposition** : (1) l'effacement ne concerne que des causes **retombées**, une cause encore présente reste latchée (donc visible au bandeau) ; (2) la campagne de démarrage à froid est **bornée dans le temps** ; (3) le canal de diagnostic `GVL_IHM.Emergency.State.Diag` / les `LatchedId` des `FB` restent inchangés pour tout défaut **encore présent**.
- 🔧 **Retrait du risque** : exigerait un compteur/voyant dédié ⇒ **nouveau champ IHM**, donc hors périmètre (cas d'arrêt du contrat). **Remonté à l'orchestrateur, non contourné.**

---

## 4. 🛠️ Ce qui a été implémenté — `CODE/M_MAIN/PRG_07_Supervision.st`

**Fichier unique de code** (aucun autre fichier `CODE/` modifié). Régions touchées : **la déclaration des `VAR` locales du PROGRAM** et la **région `§1c`**.

| Élément | Emplacement |
|---|---|
| `VAR` locales des campagnes (24 variables, **non-RETAIN**) | `PRG_07_Supervision.st:94-120` |
| `VAR CONSTANT` bornes de campagne | `PRG_07_Supervision.st:122-128` |
| §1c-1 — campagne (a) démarrage à froid | `PRG_07_Supervision.st:162-179` |
| §1c-1 — campagne (b) réarmement AU | `PRG_07_Supervision.st:181-194` |
| Moteur commun (une seule campagne à la fois) | `PRG_07_Supervision.st:196-201` |
| Cadence bornée des impulsions | `PRG_07_Supervision.st:203-218` |
| Fin de campagne (boot / réarmement) | `PRG_07_Supervision.st:220-235` |
| §1c-2 — porte unique d'acquittement | `PRG_07_Supervision.st:237-243` |

### 4.1 Campagne (a) — DÉMARRAGE À FROID (`PRG_07:175-179`)

```pascal
BootInputTransientDone := NOT PRG_02_Acquisition.Data.InputModules.Fault;
BootWindowTimer(IN := TRUE, PT := CST_AckBootWindow);
BootAckWindowOpen := NOT BootWindowTimer.Q;
BootSettleTimer(IN := BootInputTransientDone AND NOT BootAckFinished, PT := CST_AckBootSettle);
BootAckStart := BootSettleTimer.Q AND NOT BootAckFinished AND BootAckWindowOpen;
```

- Signal **existant** réutilisé : `Data.InputModules.Fault` (`PRG_02_Acquisition.st:216`, `TRUE` si l'un des 5 modules n'est pas `RUNNING`) — **aucun champ créé**.
- **Borne de temps** : la fenêtre `CST_AckBootWindow` clôt la campagne. Si le transitoire d'E/S n'a jamais abouti, la campagne se termine **SANS aucune impulsion** (voir §5, borne n°3).

### 4.2 Campagne (b) — APRÈS RÉARMEMENT AU (`PRG_07:185-194`)

```pascal
RearmSeqRunning := (PRG_06_Outputs.EmergencyState.Step <> 0);
RearmSeqStartEdge(CLK := RearmSeqRunning);
IF RearmSeqStartEdge.Q THEN
    RearmSeqSeen := TRUE;
END_IF;
ContactorOkEdge(CLK := PRG_06_Outputs.EmergencyState.ContactorOk);
RearmAckStart := ContactorOkEdge.Q AND RearmSeqSeen;
IF RearmAckStart THEN
    RearmSeqSeen := FALSE; // geste consomme : une nouvelle campagne exige un nouveau geste
END_IF;
```

- Une séquence d'armement ne peut démarrer que sur un **front de commande opérateur** (`FB_Safety_EmergencyManagement.st:299`, `ArmReqEdge.Q AND Armable AND …`) : c'est **la preuve du geste conscient**, sans lire `GVL_IHM`.
- ⛔ **Le seul front de `ContactorOk` ne déclenche JAMAIS d'impulsion** : le contacteur peut s'engager **sans geste opérateur** (relâchement d'un AU avec maintien repris, démarrage à chaîne fermée via `Maintain_ChainOk = EmergencyChainClosed`, bypass de mise en service). C'est l'objet de `TC-T367-107`.

### 4.3 Moteur commun, cadence et fin de campagne (`PRG_07:196-235`)

```pascal
IF (BootAckStart OR RearmAckStart) AND NOT AckCampaignActive THEN
    AckCampaignActive := TRUE;
    AckCampaignIsBoot := BootAckStart;
    AckPulseCount     := 0;
END_IF;

AckPulseSpacing(IN := AckCampaignActive AND NOT AckPulseSpacing.Q, PT := CST_AckPulseSpacing);
AckPulseAllowed := TRUE;
IF AckCampaignIsBoot THEN
    AckPulseAllowed := BootInputTransientDone; // jamais d'impulsion sur transitoire d'E/S en cours
END_IF;
AckPulseRoom       := AckPulseCount < CST_AckPulseMax;
AckPulseDue        := (AckPulseCount = 0) OR AckPulseSpacing.Q;
AckCampaignPulsing := AckCampaignActive AND AckPulseAllowed AND AckPulseRoom;
AckPulse           := AckCampaignPulsing AND AckPulseDue;
IF AckPulse THEN
    AckPulseCount := AckPulseCount + 1;
END_IF;
BootAckPulse  := AckPulse AND AckCampaignIsBoot;
RearmAckPulse := AckPulse AND NOT AckCampaignIsBoot;

BootCampaignLastPulse := AckCampaignActive AND AckCampaignIsBoot AND (AckPulseCount >= CST_AckPulseMax);
BootCampaignEnded     := (NOT BootAckWindowOpen) OR BootCampaignLastPulse;
IF NOT BootAckFinished AND BootCampaignEnded THEN
    BootAckFinished := TRUE;
    IF AckCampaignIsBoot THEN
        AckCampaignActive := FALSE;
    END_IF;
END_IF;

RearmCampaignLastPulse := AckCampaignActive AND (NOT AckCampaignIsBoot) AND (AckPulseCount >= CST_AckPulseMax);
IF RearmCampaignLastPulse THEN
    AckCampaignActive := FALSE;
END_IF;
```

### 4.4 Porte unique (`PRG_07:237-243`) — **les 5 sources existantes sont inchangées**

```pascal
FaultMachineReset_IHM := GVL_IHM.Modes.Cmd.BtnFaultReset
                    OR GVL_IHM.M1TreuilRetenue.Cmd.BtnReset
                    OR GVL_IHM.M2TreuilBenne.Cmd.BtnReset
                    OR GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnReset
                    OR GVL_IHM.CycleSemiAuto.Cmd.BtnReset
                    OR BootAckPulse OR RearmAckPulse; // T -> alimente aussi PRG_03.instCycleSemiAuto.Reset (retour, scan suivant)
```

Le **seul** ajout à cette porte est `OR BootAckPulse OR RearmAckPulse` : les **5 expressions source** sont bit-identiques, et le commentaire historique est conservé **verbatim**.

---

## 5. 🧮 Valeurs retenues et points ouverts

| # | Valeur | Statut |
|---|---|---|
| 1 | `CST_AckPulseMax = 3` impulsions max par campagne | Contrat **Q3** — valeur retenue, **à confirmer** par l'exploitant |
| 2 | `CST_AckPulseSpacing = T#1s` entre deux impulsions | Contrat **Q3** — valeur retenue, **à confirmer** |
| 3 | `CST_AckBootWindow = T#30s` — **fenêtre de démarrage à froid** | ⚠️ **NOUVELLE valeur, NON présente au contrat** — voir ci-dessous |
| 4 | `CST_AckBootSettle = T#3s` — stabilisation après fin du transitoire d'E/S | ⚠️ idem (valeur non chiffrée au contrat) |

**Pourquoi une fenêtre (n°3)** — arbitrage assumé, à valider : sans borne de temps, une campagne de démarrage à froid resterait « en attente » indéfiniment si un module E/S ne revient jamais `RUNNING` ; un module revenu **des heures plus tard** déclencherait alors un **acquittement automatique en fonctionnement établi**, ce que le contrat interdit (`AC6`). La fenêtre clôt la campagne **sans impulsion** si le transitoire n'a pas abouti, et reste compatible avec `AC2`/`TC-T367-105` (« aucune impulsion tant que le transitoire d'E/S n'est pas terminé »). **Valeur 30 s à confirmer** (aucune mesure terrain disponible : le transitoire réel des 5 modules n'a jamais été instrumenté — voir §9 « volet démarrage à froid » de la fiche T369).

### 5.1 ⚠️ Écart au design fourni : mémorisation du geste par FRONT, pas par NIVEAU

Le design d'orchestrateur proposait `RearmSeqSeen := RearmSeqSeen OR (PRG_06_Outputs.EmergencyState.Step <> 0);` (forme **niveau**). Implémenté : armement par **front de démarrage de séquence** + **consommation** du geste à l'usage.

**Motif (sûreté, pas esthétique)** : la forme niveau se **ré-arme toute seule** à chaque scan où `Step <> 0`. Or la séquence d'armement **continue de tourner** après le front du contacteur (RESTORE_B → PULSE → CONFIRM) : la mémoire se ré-armerait donc **juste après la fin de la campagne**, et un **front ultérieur du contacteur sans aucun geste nouveau** (relâchement d'un AU avec maintien repris, exactement le scénario de `TC-T367-107`) déclencherait une campagne — soit un acquittement automatique sans appui conscient, précisément ce que le lot doit empêcher. La forme front est un **sous-ensemble strict** de la forme niveau : elle ne peut que **restreindre** les cas d'acquittement, jamais en ajouter. `TC-T367-108` prouve la différence (variante « séquence encore en cours sans nouveau démarrage ⇒ 0 impulsion supplémentaire »), et `G521` refuse la réintroduction de la forme niveau.

---

## 6. ✅ Garanties conservées (contrat `conservation`)

| Garantie | Preuve |
|---|---|
| Un défaut dont la cause est **encore présente** reste latché et visible | `TC-T367-103` (`faultCore.Fault.Latched` reste `TRUE` après la campagne complète, `LatchedId = 1`, vue LIVE publiée) |
| Les préconditions d'armement (`Armable`) restent la **seule** autorisation d'armer | Aucun fichier de `CODE/B_AU_SECURITE/` modifié — `git diff --stat` **VIDE** |
| Aucun acquittement automatique en fonctionnement établi | `TC-T367-104` (0 impulsion sur 3 balayages + 30 s, puis 1 impulsion sur action opérateur) |
| Les 5 boutons d'acquittement gardent leur comportement | `AC7` — sources bit-identiques ; `TC-T367-104` prouve la voie opérateur toujours active |
| `GVL_IHM` et ses types strictement inchangés | `git diff --stat` **VIDE** sur `GVL_IHM.st` et `CODE/J_SUPERVISION/_TYPES/` |
| Le cycle de la campagne de boot ne peut pas se relancer sans nouveau démarrage à froid | État **local non-RETAIN** ⇒ 0 au cold start ; `BootAckFinished` verrouille la fin de campagne |
| Aucun redémarrage machine, aucun interlock ouvert | L'impulsion n'agit que sur les entrées `Reset` des `FB` (front d'acquittement) ; le `FB_FaultCore` ré-arme les latches des causes présentes |

---

## 7. 🧪 Preuves de validation

| Preuve | Résultat |
|---|---|
| Ci ROUGE **avant** correctif (AC12) | `PRG_07_Supervision` **6/13** — 7 des 8 cas `TC-T367-10x` en échec sur l'état initial |
| Ci **après** correctif | `PRG_07_Supervision` **13/13 PASS** |
| Garde-fou `fix:` + `guard:` | `TOOLS/AGENT_WORKFLOW/scripts/G521_check_fault_reset_not_hw_triggered.py` — PASS + `--selftest` PASS (11 mutations refusées, 0 faux positif) |
| Liaison | `G200_check_linkage.py --report` = **PASS** (0 erreur) |
| Gates palier C | 55/59 PASS — 4 rouges **préexistants** nommés (G300, G340, G430, G483), **0 nouveau rouge** |
| Bundle | `CODE_XML/CODE_Bundle.xml` régénéré (261/261 objets, 0 erreur) + `CODE_XML/CODE_DiffBundle.xml` (objet `PRG_07_Supervision`) |

---

## 8. 🚫 Ce que ce lot ne fait PAS (interdits respectés)

`GVL_IHM.st` · `CODE/J_SUPERVISION/_TYPES/**` · `CODE/B_AU_SECURITE/**` · `DOC/AF/**` · `DOC/STDS/**` · `CODE/L_SIMULATION/**` · `PRJ_CODESYS/**` · `Device.export` : **aucune écriture**.
Aucun nouveau champ GVL/DUT · aucune modification des 5 sources existantes · aucun reset périodique ou en fonctionnement · `FB_FaultCore` et les `FB` de sécurité **non modifiés** · **aucun commit, aucun push**.

---

## 9. 🚨 Devoir d'alerte — points remontés à l'orchestrateur

1. **Borne de temps `CST_AckBootWindow = T#30s`** et **`CST_AckBootSettle = T#3s`** : valeurs **non chiffrées par le contrat** — à confirmer (le transitoire réel des 5 modules E/S n'est pas instrumenté, aucune mesure disponible).
2. **Fichier de harnais CI modifié** : `TOOLS/TEST_AUTO_CI/RESULTS/M_MAIN/FB_TestHarness_PRG_07.st` **n'est pas listé littéralement** dans `scope.allowed` (qui liste `RESULTS/M_MAIN/tests/`). Il est le véhicule **désigné** par le contrat (« cas TC-T367-10x via `FB_TestHarness_PRG_07` ») et n'est **pas** du code de production : sans lui, les 8 cas ne peuvent pas exister. Modifications limitées à **une entrée** (`EmergencyState : ST_Safety_Emergency_State`) et **trois sorties** de campagne, plus le miroir strict de `§1c-1`. **À ratifier** (ou à déplacer dans le périmètre du contrat).
3. **Limite de portée de la preuve CI** : comme pour `PRG_04` (cf. `G480`), `run_tests.py` n'exécute **pas** `source_prg` — le harnais est un **stub miroir**. Les cas `TC-T367-10x` prouvent donc le **comportement du miroir** de `§1c-1`, pas le `PRG_07` compilé par CODESYS. Le seul verrou mécanique portant sur le **vrai** fichier est `G521` (statique). Un test d'intégration sur le POU réel reste à cadrer (classe de limitation déjà connue et documentée sur ce dépôt).
4. **3 nouveaux avertissements `L10`** (`RearmSeqSeen`, `AckCampaignActive`, `AckPulseCount`, tous **intra-POU** `PRG_07`) : faux positifs de la classe déjà documentée (`AF_Partie-02` TBD §3). `G200` reste **PASS**.
5. **Aucun statut de tâche écrit** : `DOC/WFLOW/TASKS.yaml` et `TASK_LOCKS.json` sont dans le périmètre autorisé mais déjà modifiés par d'autres acteurs — la mise à jour du statut T367 relève de l'orchestrateur (`task-planner`), pour éviter tout écrasement.
