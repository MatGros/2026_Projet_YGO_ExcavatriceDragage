# orchestrate run r-muclnalg-xpvoq8

- mode: supervisor | agent: session-40bbfeca-c32a-4b04-b686-f3b4592d4797 | provider: spawn
- concurrency: 3 | durationMs: 594702 | aborted: false
- startedAt: 2026-09-22T11:37:13.060Z | finishedAt: 2026-09-22T11:47:07.761Z

## Etats et table de transitions [completed]

[structured] {"verdict_global":"AXE 1/3 — ÉTATS & TABLE DE TRANSITIONS — SPEC (BRIEF_T364, exploitant 2026-09-21) vs CODE ACTUEL (working tree post-refonte T364).\n\nMÉTHODE : lecture intégrale des 5 fichiers (spec + FB + 3 types). Énumération GRAFCET ACTUELLE lue dans E_MachineHomingTxState.st (NON celle des anciens états de la §1 du brief). Verdicts VERIFIE / DEDUIT / INDETERMINE. hash = git hash-object (blob du working tree, état sur disque).\n\nHASH (sur blob, fichiers lus) :\n- spec BRIEF_T364_REFONTE_COMPLETE_SEQUENCE_HOMING.md = d4adb41e9a4aa1bbd7f256d2606df71893b81b5a\n- CODE/G_CYCLE/FB_CycleMachineHoming.st = c882acac757b127f4bc0d1ab319d99d6c3c3c618\n- CODE/G_CYCLE/_TYPES/E_MachineHomingTxState.st = 85e9697649f5bf5977a04ca116a53dc3dde2663e\n- CODE/G_CYCLE/_TYPES/E_MachineHomingStep.st = 7b0a835c3a4d47db4d26cc0d7308ca01910f1dd0\n- CODE/G_CYCLE/_TYPES/ST_MachineHoming.st = 224957a7e3b9710f4e8f61bf2e1127a679bd956d\n\nÉNUMÉRATION GRAFCET ACTUELLE (E_MachineHomingTxState.st, 9 états) :\nHX0_REPOS=0 · HX1_BUCKET_PREPARE=1 · HX1A_COUPLING_INTERLOCK=2 · HX2_CLIMB_COUPLED=3 · HX3_FLYING_REFERENCE=4 · HX4_STABILIZATION_CHECK=5 · HX5_RELEASE_CLEARANCE=6 · HX6_HOMED_SUCCESS=7 · HX7_FAILED=8.\n(Aucun HX2N, aucun HX3N, aucun HX7_LOCKED_REFERENCE — ces états pré-refonte ont été supprimés.)\n\nTABLEAU DE CORRESPONDANCE ÉTAPE PAR ÉTAPE :\n| Spec (brief §2) | Rôle demandé | État code actuel | Valeur | Fichier:ligne | Verdict |\n| HX0 | Machine non référencée, état initial | HX0_REPOS | 0 | FB:411 | VERIFIE — conforme ; lancement MAINT_N2 + StartEdge/BtnValidationEdge |\n| HX1 | Fermeture benne, WinchSel=2, FDC benne OFF, sortie par 1 appui bouton IHM | HX1_BUCKET_PREPARE | 1 | FB:420-436 | VERIFIE — CmdWinchSelect:=2 (:423), CmdBucketClose sur BucketPermit+JoystickPull (:424), sortie HomingBucketConfirmEdge + neutre (:431) |\n| HX1a | Bascule WinchSel=0, FDC benne réactivé | HX1A_COUPLING_INTERLOCK | 2 | FB:438-450 | VERIFIE (état présent + CASE). ATTENTION : spec §2 décrit aussi « référencement M1+M2, M1 Homed=0 pas bloquant » → le code n'y fait QUE la bascule/interlock ; le référencement réel est HX3. Voir écart H1a. |\n| HX2 | Monte 2 treuils palier 1 MAX vers capteur haut | HX2_CLIMB_COUPLED | 3 | FB:452-470 | VERIFIE — CmdWinchM1/M2 RunRequest+ReqAscent+StepTgt=CST_StepSlow(1) (:456-457), sortie TopPositionSensor (:463) |\n| HX3 | Re-référencer M1+M2 « à la volée » sur pos config (8.5m) | HX3_FLYING_REFERENCE | 4 | FB:472-517 | VERIFIE — Mode A vol + repli auto Mode B arret (:478-512), sortie BothAxesHomed → HX4 |\n| HX4 | Stabilisation inertie au-dessus de 8.5m ; échec → repositionnement + nouvelle tentative | HX4_STABILIZATION_CHECK | 5 | FB:519-545 | VERIFIE — contrôle [CfgStabilizationMin..Max] + cohérence M1/M2 (:524-527), 3 retries max, échec → retour HX1_BUCKET_PREPARE (:543) |\n| HX5/HX6 | « à définir » (brief interdit de deviner) | HX5_RELEASE_CLEARANCE=6 + HX6_HOMED_SUCCESS=7 | 6/7 | FB:547-567 | INDETERMINE — la spec laisse ouvert le rôle ; le code a TRANCHÉ (HX5=dégagement zone haute/neutre, HX6=MachineHomed+commit benne). Question ouverte exploitant. Voir écart HX56. |\n| HX7 | Échec — acquittement Reset requis | HX7_FAILED | 8 | FB:569-572 + §4 | VERIFIE — sorties à 0, pas de transition sortante automatique (sortie via ResetEdge §4), Reset conscient requis. |\n\nPOINTS À TRANCHER (réponses) :\n1) HX1a DANS LE CODE ? → OUI. État nommé HX1A_COUPLING_INTERLOCK=2, CASE FB:438-450, CmdWinchSelect:=0 (FB:441), dwell CouplingSettleTimer 300ms (:442), sortie → HX2 si JoystickWinchSelectArbitrated=0 (:447).\n2) HX3N / HX2N DANS LE CODE ? → NON. L'énumération actuelle n'en contient AUCUN ; ils existaient AVANT la refonte (section 1 du brief) et ont été supprimés. Conforme à la spec (plus d'écart de neutralité superflue).\n3) HX5/HX6 : spec « à définir » vs code figé → INDETERMINE. Le code a assigné des rôles (dégagement zone haute / validation homed) non confirmés par l'exploitant ; à trancher.\n4) HX7 COLLISION DE NOM : LEVÉE dans le code actuel. HX7 n'est PLUS HX7_LOCKED_REFERENCE (supprimé) mais HX7_FAILED unifié = échec + Reset (§6 brief respecté). Aucun autre membre HX7 dans E_MachineHomingTxState.st.\n\nAUTRE CONSTAT (restitution) : E1 couplage M1/M2 est codé (dwell HX1a sur retour d'arbitrage + CouplingInterlockFault sur HX2 si WinchSel<>0, FB:259-260, cause CST_CauseCouplingFault=6). La SPEC §3-51 exige une PREUVE par test CI que WinchSel=0 appliqué en aval est réel (gates/CI hors du périmètre read-only de cet axe → rester pour l'orchestrateur). Aucun écrit/commit effectué ; lecture seule.\n\nVERDICT GLOBAL : code aligné sur la refonte T364 (9 états HX0..HX7 incluant HX1a, suppression HX2N/HX3N, collision HX7 levée). 2 points ouverts non tranchés par la spec : rôle exact HX5/HX6 (figé par le code) et contenu « référencement / M1 Homed=0 pas bloquant » de HX1a.","hash_revision":"blob(git hash-object, working tree): spec d4adb41e9a4aa1bbd7f256d2606df71893b81b5a | FB_CycleMachineHoming.st c882acac757b127f4bc0d1ab319d99d6c3c3c618 | E_MachineHomingTxState.st 85e9697649f5bf5977a04ca116a53dc3dde2663e | E_MachineHomingStep.st 7b0a835c3a4d47db4d26cc0d7308ca01910f1dd0 | ST_MachineHoming.st 224957a7e3b9710f4e8f61bf2e1127a679bd956d","ecarts":[{"code":"HX5_RELEASE_CLEARANCE=6 (FB:547-555, dégagement zone haute, neutre joystick) et HX6_HOMED_SUCCESS=7 (FB:557-567, MachineHomed:=TRUE + commit atomique benne, retour HX0). Rôles assignés et figés par le code alors que la spec les laisse ouverts.","etape":"HX5/HX6","fichier":"CODE/G_CYCLE/FB_CycleMachineHoming.st","gravite":"MAJOR","ligne":"547 et 557","spec":"Brief §2 : « HX5/HX6 (à définir avec l'agent — ne pas deviner) » + brief §3 objectif 2 liste rôle HX5/HX6 comme question ouverte exploitant","verdict":"INDETERMINE"},{"code":"HX1A_COUPLING_INTERLOCK (FB:438-450) ne réalise QUE la bascule WinchSel=0 (:441) + dwell 300ms sur retour d'arbitrage (:442-447). Le référencement M1+M2 est reporté en HX3_FLYING_REFERENCE ; aucune condition « M1 Homed=0 pas bloquant » n'est implémentée à HX1a.","etape":"HX1a","fichier":"CODE/G_CYCLE/FB_CycleMachineHoming.st","gravite":"MINOR","ligne":"438-450","spec":"Brief §2 HX1a : bascule WinchSel=0 + FDC benne réactivé + « Référencement M1+M2, benne fermée. M1 Homed=0 pas bloquant si impossible de sortir du cycle autrement »","verdict":"INDETERMINE"},{"code":"HX4 (FB:529-545) : 3 retries max figés, puis HX7_FAILED (:540). Retour vers HX1_BUCKET_PREPARE (:543) réengage la phase fermeture benne (pas un simple retour « attente MAINT_N2 »). Le nombre max de retries (3) et la cible du retour sont tranchés par le code, non spécifiés.","etape":"HX4 échec multi-tentatives","fichier":"CODE/G_CYCLE/FB_CycleMachineHoming.st","gravite":"MINOR","ligne":"537-544","spec":"Brief §2 HX4 : « Si échec : retour en attente MAINT_N2 pour repositionnement + nouvelle tentative » (brief §3 objectif 2 : comportement si échec répété à préciser)","verdict":"INDETERMINE"}],"conformites":["VERIFIE — HX0_REPOS (=0) : état initial pure (FB:411-418), lancement en MAINT_N2 via front StartEdge/BtnValidationEdge. Conforme brief §2 HX0.","VERIFIE — HX1_BUCKET_PREPARE (=1) : CmdWinchSelect:=2 (FB:423), fermeture benne sous FDC logiciel OFF (CmdBucketClose, FB:424-425), sortie par UN seul appui bouton dédié IHM (HomingBucketConfirmEdge + joystick neutre, FB:431) — conforme « 1 seul appui, pas 3 ».","VERIFIE — HX1A_COUPLING_INTERLOCK (=2) : l'état HX1a existe bien dans le code (E_MachineHomingTxState=2, FB:438-450), bascule WinchSel=0 + attente effective couplage aval (dwell 300ms sur JoystickWinchSelectArbitrated=0). Répond au point « HX1a existe-t-il ? » = OUI.","VERIFIE — HX2_CLIMB_COUPLED (=3) : montée couplée M1+M2, palier 1 MAX strict (StepTgt=CST_StepSlow=1, FB:456-457), sortie sur TopPositionSensor (:463); interlock couplage (CouplingInterlockFault si WinchSel<>0, FB:259-260) conforme résolution E1 du brief.","VERIFIE — HX3_FLYING_REFERENCE (=4) : référencement « à la volée » M1+M2 (Mode A, FB:478-494) + repli automatique Mode B à l'arrêt (:499-511). Conforme brief §2 HX3.","VERIFIE — HX4_STABILIZATION_CHECK (=5) : contrôle inertie [CfgStabilizationMin..Max] + concordance codeurs (FB:524-527); sur stabilisation OK passage HX5 (:535). Globalement conforme brief §2 HX4.","VERIFIE — Collision de nom HX7 LEVÉE : le code actuel ne contient PLUS HX7_LOCKED_REFERENCE (supprimé de E_MachineHomingTxState.st); l'unique HX7 est HX7_FAILED (=8) = échec + Reset conscient requis (FB:569-572, pas de transition sortante auto, sortie via ResetEdge §4). Conforme brief §2 HX7 et §6.","VERIFIE — HX2N / HX3N ABSENTS du code actuel : les anciens états de neutralité (HX2N_NEUTRAL, HX3N décrits en §1 du brief) ont été supprimés. L'énumération actuelle ne comporte que HX0..HX7 + aucun état orphelin hors spec.","VERIFIE — Reset sur front + jamais de redémarrage auto après échec : ResetEdge R_TRIG (FB:210), sortie d'HX7/Fault par Reset conscient uniquement; MachineHomed bloqué par ReHomingAckRequired/Fault.Latched (FB:602-605). Sécurité machine respectée.","DEDUIT — E1 couplage M1+M2 correctement structuré dans le séquenceur (dwell HX1a + interlock HX2 + cause CST_CauseCouplingFault). La PREUVE par test CI que WinchSel=0 est réellement appliqué en aval (brief §3-51) est HORS périmètre de cet axe read-only → à dérouler par l'orchestrateur (gates/CI)."]}


## Conditions d'etapes + couplage M1/M2 (E1) [error]

unsupported JSON schema: schema.properties.ecarts.additionalProperties is not supported on type "array"

## FDC benne HX1 vs HX4 + point de securite [error]

unsupported JSON schema: schema.properties.ecarts.additionalProperties is not supported on type "array"

## reviewer [via reviewer] [completed]

Voici le tableau comparatif **SPEC vs CODE** pour l'exploitant, état par état (HX0→HX7), avec révision épinglée et signalement des points où le brief est périmé ou se contredit.

---

## 🔖 Révision épinglée (hash git blob — working tree sur disque)

| Fichier | Blob |
|---|---|
| `BRIEF_T364_REFONTE_COMPLETE_SEQUENCE_HOMING.md` (spec) | `d4adb41e9a4aa1bbd7f256d2606df71893b81b5a` |
| `CODE/G_CYCLE/FB_CycleMachineHoming.st` | `c882acac757b127f4bc0d1ab319d99d6c3c3c618` |
| `CODE/G_CYCLE/_TYPES/E_MachineHomingTxState.st` | `85e9697649f5bf5977a04ca116a53dc3dde2663e` |
| `CODE/G_CYCLE/_TYPES/E_MachineHomingStep.st` | `7b0a835c3a4d47db4d26cc0d7308ca01910f1dd0` |
| `CODE/G_CYCLE/_TYPES/ST_MachineHoming.st` | `224957a7e3b9710f4e8f61bf2e1127a679bd956d` |

> `CODE_PATH = CODE/G_CYCLE/FB_CycleMachineHoming.st` (abrévié `FB:`). Énumération réelle actuelle = 9 états HX0…HX7 (E_MachineHomingTxState.st:13-21). **Les états HX2N/HX3N/HX5_BUCKET_COMMIT/HX7_LOCKED_REFERENCE/HXF_FAILED n'existent plus.**

---

## 0. ⚠️ Le brief est en partie PLUS ANCIEN que le code (à lire avant le tableau)

- **Brief §1 (L12-14)** liste les "états actuels du code" : `HX0_REPOS, HX1_CHOICE, HX2_CLIMB, HX2N_NEUTRAL, HX3, HX3N, HX4, HX5_BUCKET_COMMIT, HX7_LOCKED_REFERENCE, HXF_FAILED`. **Ceci ne correspond pas au working tree** (E_MachineHomingTxState.st:13-21). C'est l'état **pré-refonte** : obsolète. → Le code a **déjà implémenté la refonte** ; le brief est donc lu ici comme **spec-cible**, pas comme description du code.
- **Brief §4 « 3bis » (L73-77)** renvoie à `HX4_BUCKET_ADJUST (:647)` comme lieu actuel de désactivation du FDC benne. Ligne **périmée** : le code désactive désormais le FDC à **HX1** (FB:423-426). Point déjà réglé.
- **Brief §5 (L93)** : « AUCUN CODE dans ce lot » — aujourd'hui le code existe (post-refonte). Cohérent avec le point précédent.
- **Contradiction interne du brief** : HX1a réclame « Référencement M1+M2 » (L26) **et** HX3 réclame « référence à nouveau M1+M2 » (L28). Le code a tranché : référencement **à HX3 uniquement** (FB:472-512). À trancher par l'exploitant.
- **Divergence 1 appui vs 3 appuis** : brief = 1 appui (L25), code = 1 appui (FB:431-435). Un brouillon « GEL » voudrait 3 appuis → **conforme au brief**, divergeant du brouillon (hors périmètre read-only).

---

## 1. TABLEAU COMPARATIF SPEC vs CODE (HX0→HX7)

| Étape | Ce que la SPEC exige (citation courte) | Ce que le CODE fait (fichier:ligne) | Verdict |
|---|---|---|---|
| **HX0** | « Machine pas référencée (état initial) » (L24) | Étape pure, sortie **uniquement** sur `StartEdge`/`BtnValidationEdge` en MAINT_N2 (FB:411-418) ; cycle jamais auto-armé (FB:369-371) | 🟢 **CONFORME** |
| **HX1** | « fermer benne… `WinchSel=2`, FDC benne désactivé… **un seul appui** bouton IHM » (L25) | `CmdWinchSelect:=2` (FB:423), `CmdBucketClose` sous permis, FDC off (FB:424-426), sortie sur `HomingBucketConfirmEdge` **1 seul appui** + neutre (FB:431-435) | 🟢 **CONFORME** |
| **HX1a** | « bascule `WinchSel=0`, FDC benne réactivé. Référencement M1+M2… M1 Homed=0 pas bloquant » (L26) | Bascule `CmdWinchSelect:=0` (FB:441) + dwell interlock couplage 300 ms (FB:442-447). **Pas de référencement ici**, pas de « M1 Homed=0 pas bloquant » | 🟡 MINOR — **INDETERMINE** |
| **HX2** | « monte les 2 treuils vers capteur haut… **palier 1 MAX toujours** » (L27) | Ascension couplée `StepTgt:=CST_StepSlow`=1 strict (FB:456-457, const:181), sortie `TopPositionSensor` (FB:463), interlock couplage (FB:259-260) | 🟢 **CONFORME** |
| **HX3** | « référence à nouveau M1+M2 à la volée sur pos config (défaut 8.5) » (L28) | Mode A vol (FB:478-494) + repli auto Mode B arrêt (FB:496-512) ; cible `CfgTopHomingTarget_M`=8.5 (CFG:15, PRG_02_Acquisition:549) | 🟢 **CONFORME** *(structure)* |
| **HX4** | « position au-dessus de 8.5m (inertie)… Si échec : retour attente MAINT_N2 + nouvelle tentative » (L29) | Contrôle plage `[CfgStabilizationMinM..MaxM]` + cohérence M1/M2 (FB:524-527). **Défauts : seuils par défaut 7.50..9.50** (CFG:29-30) **acceptent < 8.5m** ; retour échec → `HX1_BUCKET_PREPARE` (FB:543) ; 3 retries max (FB:538) | 🔴 MAJOR — **ECART** (+ restes INDETERMINE) |
| **HX5 / HX6** | « (à définir avec l'agent — **ne pas deviner**) » (L30) | HX5 = dégagement zone haute + neutre joystick (FB:547-555), HX6 = `MachineHomed` + commit benne (FB:557-567). **Rôles imposés par le code, non validés** | 🔴 MAJOR — **INDETERMINE** |
| **HX7** | « Échec — acquittement (Reset) requis pour recommencer » (L31) | `HX7_FAILED` : sorties 0, aucune transition sortante automatique (FB:569-572) ; Reset front → HX0 (FB:294-304). Collision de nom levée (`HX7_LOCKED_REFERENCE` supprimé) | 🟢 **CONFORME** |

---

## 2. 🔴 LES ÉCARTS classés par gravité

| Gravité | Constat | Fichier:ligne | Correction attendue |
|---|---|---|---|
| **MAJOR** | **HX4 accepte une position < 8.5m.** La spec exige « au-dessus de 8.5m » ; les seuils par défaut sont `7.50..9.50` (donc 7.6m passerait). Incohérence doc interne : les commentaires du code revendiquent `[8.50..8.80m]` alors que la config vaut `[7.50..9.50]` et porte la mention « **valeur à risque** ». | FB:524-527 · `ST_fbMachineHomingCycle_Cfg.st:29-30` (+ FB:9, enum:18) | Recentrer la bande d'acceptation sur ≥ 8.5m (ex. min=8.50) et **aligner les 3 sources** (FB, enum, CFG). Confirmation exploitant de la cote réelle (lien T301) avant figer. |
| **MAJOR** | **Rôles HX5/HX6 inventés.** La spec dit explicitement « ne pas deviner » ; le code a tranché (dégagement zone haute / validation homed + commit benne). | FB:547-567 | Validation exploiteur des rôles, ou réouverture de la spec. Ne pas livrer la séquence tant que non tranché. |
| **MAJOR** | **E1 : preuve aval CI absente.** Le FB exige `JoystickWinchSelectArbitrated=0` avant HX2 (FB:447, FB:455) et il existe un test FB (test_fb_cyclemachinehoming.st), mais **aucune preuve CI au niveau de l'arbitrage aval** que `CmdWinchSelect=0` est réellement consommé (grep J_SUPERVISION : 0 occurrence). Le brief §3.3 (L49-56) la rend **MANDATOIRE** pour livrer le lot. | FB:447,455 · (grep `J_SUPERVISION` vide sur `CmdWinchSelect`) | Ajouter un test d'intégration prouvant que la demande du cycle n'est consommée qu'en couplage et que les 2 FB treuil reçoivent effectivement l'ordre en simultané. **BLOCAGE de livraison** si brief §3.3 appliqué à la lettre. |
| **MINOR** | **HX4 « retour attente MAINT_N2 » non conforme.** La spec veut un retour en *attente MAINT_N2* pour repositionnement ; le code ré-engage `HX1_BUCKET_PREPARE` (fermeture benne). Le **nombre de retries (3) n'est pas spécifié**. | FB:536-544 | Précision exploitant : retour en attente simple vs rechaine complète, et borne du nombre de tentatives. |
| **MINOR** | **HX1a : référencement manquant / « M1 Homed=0 pas bloquant » non implémenté.** HX1a ne réalise que la bascule + interlock ; le référencement est différé à HX3 (ambiguïté interne du brief, voir §0). | FB:438-450 | Trancher si le référencement reste à HX3 seul (conforme) ou doit exister à HX1a ; sinon retirer la mention de la spec. |

---

## 3. 🟢 LES CONFORMITÉS (preuve du travail fait)

- **HX0 initial pur, jamais d'auto-armement** : le cycle ne démarre que par action consciente en MAINT_N2, pas spontanément (FB:411-418, commentaire :369-371). Conforme brief L24.
- **HX1 WinchSel=2 + FDC soft désactivé + sortie par 1 seul appui** : conforme brief L25, et divergence « 3 appuis (brouillon GEL) » tranchée en faveur de l'exploitant (1 appui) — FB:423-435.
- **HX1a existe et réalise l'interlock couplage E1** : bascule WinchSel=0 + dwell 300ms sur retour d'arbitrage (FB:441-447). Répond « HX1a est-il codé ? » = **OUI**.
- **HX2 palier 1 MAX strict** (StepTgt=1 figé, FB:456-457 + CST_StepSlow:181) : aucun palier supérieur possible.
- **Protection E1 en HX2** : `CouplingInterlockFault` si `WinchSel<>0` pendant la montée (FB:259-260, cause :354-356).
- **HX3 Mode A vol + repli automatique Mode B arrêt**, cible configurée 8.5 (FB:478-512 ; CFR:15 ; PRG_02_Acquisition:549).
- **HX7 : aucun redémarrage automatique après échec**, Reset sur **front** requis (FB:294-304, R_TRIG :210) — conforme au principe non négociable « jamais de redémarrage auto après défaut » (AGENTS).
- **Collision de nom HX7 levée** : `HX7_FAILED` unifié, l'ancien `HX7_LOCKED_REFERENCE` a disparu (enum:21).
- **Sécurité machine** : `M3Locked` pendant le cycle (FB:595) → translation interdite tant que homing non en HX0.
- **Testabilité** : suite CI unitaire complète `test_fb_cyclemachinehoming.st` (PASS) qui couvre chaque transition HX0→HX7 (montee, retries, échec, Reset, forcage mise en service). Preuve que la refonte est encodée et vérifiée au niveau FB.

---

## 4. 🟡 LES INDÉTERMINÉS et ce qu'il faut mesurer

| Point | Fichier:ligne | Ce qu'il faut mesurer / trancher |
|---|---|---|
| Seuil HX4 exact | CFG:29-30 vs FB:524-527 | Confirmer la bande d'acceptation (8.50..8.80 ? au-dessus de 8.5 ?) et aligner les 3 sources. |
| E1 aval réel | FB:447,455 | Test d'intégration arbitrage aval : prouver que `WinchSel=0` cycle est réellement consommé avant HX2. |
| Butée mécanique benne HX1 | FB:423-426 | Vérifier physiquement/specs qu'une butée mécanique indépendante du soft protège la benne pendant la fermeture « à l'aveugle » (brief §4) — non prouvable depuis le code seul. |
| Rôle HX5/HX6 | FB:547-567 | Décision exploitant (le code a deviné). |
| HX4 échec répété | FB:536-544 | Nombre max de tentatives + cible du retour (attente vs rechaine benne). |
| Calibration 8.5m / T301 | PRG_02_Acquisition:549 | Mesurer la cote physique du capteur vs config : sinon erreur systématique invisible (brief §3ter). |
| FDC benne réactivé à HX1a | FB:441 | Vérifier dans FB_Bucket que la garde FDC est relâchée dès `CmdWinchSelect=0`. |

---

## 🧭 Verdict global

**Code globalement conforme à l'esprit de la refonte T364** : la séquence cible HX0→HX7 (9 états dont HX1a) est **implémentée et testée au niveau FB**, les principales exigences opératoires (WinchSel=2 puis 0, palier 1 MAX, référence à la volée, Reset requis, pas d'auto-armement, M3Locked) sont respectées, et la collision de nom HX7 est levée.

**Mais le lien spec↔code n'est pas bouclé sur 4 points ouverts** : (1) **HX4 accepte des positions sous 8.5m** (déviation fonctionnelle, MAJOR) ; (2) **rôles HX5/HX6 imposés par le code sans validation** ; (3) **preuve CI aval E1 absente** (blocante si brief §3.3 strict) ; (4) ambiguïtés/contradictions du brief (HX1a référencement, `HX4_BUCKET_ADJUST:647` périmé, états §1 obsolètes). Aucun de ces points n'est un défaut de câblage logique avéré, mais la séquence ne doit pas être considérée **fiable et livrée** tant que ces points et la vérification de la butée mécanique restent en l'état.

---
*Note : cette revue est une analyse read-only (zéro écrit/commit). Le fichier de test CI `TOOLS/TEST_AUTO_CI/RESULTS/G_CYCLE/tests/test_fb_cyclemachinehoming.st` confirme le PASS de la séquence au niveau FB ; la preuve aval (arbitrage) reste à établir — voir §4.*

## supervisor#1 [completed]

Vérifications faites sur disque (hashes git blob confirmés, CASE du FB relu ligne à ligne, config relue). Je livre le comparatif consolidé pour l'exploitant — vérifié indépendamment, pas recopié.

---

## 🔖 Révision épinglée — hash git blob (working tree)

| Objet | Blob |
|---|---|
| `BRIEF_T364_REFONTE_COMPLETE_SEQUENCE_HOMING.md` (spec exploitant 2026-09-21) | `d4adb41e9a4aa1bbd7f256d2606df71893b81b5a` |
| `CODE/G_CYCLE/FB_CycleMachineHoming.st` | `c882acac757b127f4bc0d1ab319d99d6c3c3c618` |
| `CODE/G_CYCLE/_TYPES/E_MachineHomingTxState.st` | `85e9697649f5bf5977a04ca116a53dc3dde2663e` |
| `CODE/G_CYCLE/_TYPES/E_MachineHomingStep.st` | `7b0a835c3a4d47db4d26cc0d7308ca01910f1dd0` |
| `CODE/G_CYCLE/_TYPES/ST_fbMachineHomingCycle_Cfg.st` | `7e0b1feba304a0b94886f879643f0829809eea32` |

> `FB:` = `CODE/G_CYCLE/FB_CycleMachineHoming.st` ; `ENUM:` = `E_MachineHomingTxState.st` ; `CFG:` = `ST_fbMachineHomingCycle_Cfg.st`.
> **Énumération réele = 9 états** HX0…HX7 (ENUM:13-21). Les états pré-refonte HX1_CHOICE / HX2N / HX3N / HX5_BUCKET_COMMIT / HX7_LOCKED_REFERENCE / HXF_FAILED **n'existent plus**.

---

## ⚠️ D'abord : le BRIEF est en partie PLUS ANCIEN que le code (3 points factuels)

- **Brief §1 (L12-14)** liste les « états actuels du code » = liste **pré-refonte obsolète** (HX2N, HX3N, HX7_LOCKED_REFERENCE…). Le working tree les a **déjà supprimés**. → Le brief est à lire comme **spec-cible**, pas comme description du code.
- **Brief §4 (L73-77)** situe la désactivation du FDC benne à `HX4_BUCKET_ADJUST (:647)` — **ligne périmée** : elle est désormais faite à HX1 (FB:423-426). Point déjà réglé.
- **Brief §5 (L93) « AUCUN CODE »** : ce lot est aujourd'hui **codé**. → les 3 points « à définir / à vérifier » du brief sont soit tranchés soit à revalider (voir §4).

---

## 📊 1. TABLEAU SPEC vs CODE — HX0 → HX7

| Étape | Spec exige (citation) | Code fait (fichier:ligne) | Verdict |
|---|---|---|---|
| **HX0** | « Machine pas référencée (état initial) » (L24) | Étape pure, sortie sur `StartEdge`/`BtnValidationEdge` **en MAINT_N2 uniquement**, jamais d'auto-armement (FB:411-418) | 🟢 **CONFORME** |
| **HX1** | « fermer benne `WinchSel=2`, FDC benne désactivé, sortie par **un seul appui** bouton IHM » (L25) | `CmdWinchSelect:=2` (FB:423), `CmdBucketClose` sous `BucketPermit AND JoystickPull` (FB:424-425), sortie `HomingBucketConfirmEdge` **1 appui** + neutre (FB:431-435) | 🟢 **CONFORME** |
| **HX1a** | « bascule `WinchSel=0`, FDC benne réactivé. Référencement M1+M2… `M1 Homed=0` pas bloquant » (L26) | Bascule `CmdWinchSelect:=0` (FB:441) + dwell interlock 300ms sur `JoystickWinchSelectArbitrated=0` (FB:442-447). **Aucun référencement ici, ni « M1 Homed=0 pas bloquant »** — différé à HX3 | 🟡 **INDETERMINE** |
| **HX2** | « monte les 2 treuils vers capteur haut, **palier 1 MAX toujours** » (L27) | Montée couplée `StepTgt:=CST_StepSlow`=1 strict (FB:456-457), sortie `TopPositionSensor` (FB:463), interlock couplage si `WinchSel<>0` (FB:259-260) | 🟢 **CONFORME** |
| **HX3** | « référence à nouveau M1+M2 à la volée sur position config (défaut 8.5) » (L28) | Mode A vol (FB:478-488) + repli auto Mode B arrêt (FB:496-512), cible `CfgTopHomingTarget_M`=8.5 (CFG:15) | 🟢 **CONFORME** (structure) |
| **HX4** | « position au-dessus de 8.5m (inertie). Si échec : retour attente MAINT_N2 + nouvelle tentative » (L29) | Contrôle plage `[CfgStabilizationMinM..MaxM]` + cohérence M1/M2 (FB:524-527). **Seuils par défaut 7.50..9.50** (CFG:29-30) → **accepte < 8.5m** ; échec → `HX1_BUCKET_PREPARE` (FB:543) ; **3 retries max** (FB:538) | 🔴 **ECART** (+ restes INDETERMINE cf §4) |
| **HX5 / HX6** | « (à définir… **ne pas deviner**) » (L30) | HX5 = dégagement zone haute + neutre (FB:547-555) ; HX6 = `MachineHomed` + commit benne (FB:557-567). **Rôles figés par le code, non validés** | 🔴 **ECART** (spéculé) |
| **HX7** | « Échec — acquittement (Reset) requis » (L31) | `HX7_FAILED` : sorties à 0, **aucune transition sortante auto** (FB:569-572) ; Reset front → HX0 + purge (FB:294-304). Collision `HX7_LOCKED_REFERENCE` levée (ENUM:21) | 🟢 **CONFORME** |

---

## (1) 🔴 LES ÉCARTS — par gravité

| Gravité | Constat | Fichier:ligne | Correction attendue |
|---|---|---|---|
| **BLOCK** | **Aucun écart BLOCK de logique identifié.** Seul verrou de livraison : la **preuve aval E1** (test CI) requise par brief §3.3 — cf. INDÉTERMINÉ n°2. | — | — |
| **MAJOR** | **HX4 accepte une position < 8.5m** : la spec exige « au-dessus de 8.5m » ; les seuils par défaut `7.50..9.50` laisseraient passer 7.6m. Incohérence : en-têtes commentaire et ENUM:18 revendiquent `[8.50..8.80m]` alors que CFG vaudrait `[7.50..9.50]` (mention « valeur à risque »). | FB:524-527 · CFG:29-30 · ENUM:18 | Recentrer la bande sur ≥ 8.5m (ex. min=8.50) **et aligner les 3 sources** (FB, ENUM, CFG). Confirmer la cote réelle (lien T301) avant figer. |
| **MAJOR** | **Rôles HX5/HX6 inventés** : la spec dit explicitement « ne pas deviner », le code a tranché (dégagement / validation homed + commit). | FB:547-567 | Décision exploitant sur les rôles, ou réouverture spec. Ne pas livrer tant que non tranché. |
| **MINOR** | **HX4 échec → retour ≠ « attente MAINT_N2 »** : le code ré-engage `HX1_BUCKET_PREPARE` (refait fermeture benne) ; le **nombre de retries (3) n'est pas spécifié**. | FB:536-544 | Trancher : retour en attente simple vs rechaîne complète, et borne de tentatives. |
| **MINOR** | **HX1a incomplet** : pas de référencement ici ni de « `M1 Homed=0` pas bloquant » ; ambiguïté interne du brief (L26 vs L28). | FB:438-450 | Trancher si réf reste à HX3 seul (conforme) ou doit exister à HX1a ; sinon retirer la mention de la spec. |

## (2) 🟢 LES CONFORMITÉS (preuve du travail fait)

- **Enum refonte = 9 états HX0..HX7 avec HX1a**, suppression HX2N/HX3N, collision HX7 levée (ENUM:13-21).
- **HX0 initial pur, jamais d'auto-armement** : ne démarre qu'en MAINT_N2 sur front conscient (FB:411-418).
- **HX1 WinchSel=2 + FDC soft désactivé + sortie par 1 seul appui** (FB:423-435) — diverge du brouillon « GEL/3 appuis », **conforme au brief** (L25).
- **HX1a existe et réalise l'interlock couplage E1** : bascule WinchSel=0 + dwell 300ms sur retour d'arbitrage (FB:441-447).
- **HX2 palier 1 MAX strict** `StepTgt=1` figé (FB:456-457) + protection E1 `CouplingInterlockFault` si `WinchSel<>0` (FB:259-260).
- **HX3 Mode A vol + repli auto Mode B**, cible configurée 8.5m (FB:478-512 · CFG:15).
- **HX7 : pas de redémarrage auto après défaut** ; Reset sur **front** → HX0 + purge complète des latches (FB:294-304) — conforme au principe non négociable AGENTS.md ; `M3Locked:=CycleRunning` (FB:595).
- **Qualification `MachineHomed` verrouillée** tant que commit/offset invalides, échec, ou re-homing non acquitté (FB:602-605).

## (3) 🟡 LES INDÉTERMINÉS — ce qu'il faut mesurer/trancher

| Point | Fichier:ligne | À mesurer / trancher |
|---|---|---|
| Seuil HX4 exact | CFG:29-30 vs FB:524-527 | Confirmer la bande (8.50..8.80 ? « >8.5 » ?) et aligner FB+ENUM+CFG. |
| **E1 aval réel** ← verrou livraison brief §3.3 | FB:447,455 | **Test d'intégration** prouvant que `CmdWinchSelect=0` cycle est réellement consommé par l'arbitrage aval avant HX2 (les 2 treuils reçoivent l'ordre ensemble). Aucun `J_SUPERVISION` sur `CmdWinchSelect` trouvé. |
| Butée mécanique benne (fermeture à l'aveugle HX1) | FB:423-425 | Vérifier **physiquement/dans specs** une butée indépendante du soft pendant la fermeture sans FDC (brief §4) — non prouvable depuis le code seul. |
| Rôle HX5/HX6 | FB:547-567 | Décision exploitant (le code a deviné). |
| HX4 échec répété | FB:536-544 | Borne de tentatives + cible du retour (attente vs rechaîne benne). |
| Calibration cote 8.5m / T301 | CFG:15 · PRG_02_Acquisition:549 | Mesurer la cote capteur physique vs config : sinon erreur systématique invisible (brief §3ter). |
| FDC benne réactivé à HX1a | FB:441 | Vérifier dans `FB_Bucket` que la garde FDC est bien relâchée dès `CmdWinchSelect=0`. |

---

## 🧭 (4) VERDICT GLOBAL — écart spec↔code

**Code globalement conforme à l'esprit de la refonte T364** : la séquence HX0→HX7 (9 états dont HX1a) est **implémentée au niveau FB**, et les exigences opératoires fortes (WinchSel=2 puis 0, palier 1 MAX strict, référence à la volée, Reset requis, pas d'auto-armement, `M3Locked`) sont **respectées**.

**Mais l'écart spec↔code n'est pas bouclé sur 4 points**, dont **un fonctionnel MAJOR** :
1. 🔴 **HX4 accepte des positions sous 8.5m** (7.50..9.50) — déviation réelle des seuils vs « au-dessus de 8.5m ».
2. 🔴 **Rôles HX5/HX6 imposés par le code sans l'aval de l'exploitant** (spec : « ne pas deviner »).
3. 🟡 **Preuve CI aval E1 absente** → **bloquante pour livraison** si brief §3.3 appliqué à la lettre.
4. 🟡 **Ambiguïtés/contradictions du brief** (HX1a réf, `HX4_BUCKET_ADJUST:647` périmé, états §1 obsolètes) à résoudre explicitement.

Aucun de ces points n'est un **défaut de câblage logique avéré** ; mais la séquence ne doit pas être considérée **fiable et livrée** tant que le seuil HX4, la validation HX5/HX6, la preuve aval E1 et la vérification de la butée mécanique restent en l'état.

---
*Revue read-only (zéro écrit/commit). Hashes = `git hash-object` du working tree. Le fichier de test CI `TOOLS/TEST_AUTO_CI/RESULTS/G_CYCLE/tests/test_fb_cyclemachinehoming.st` couvre la séquence au niveau FB ; la preuve aval reste à établir (§3 n°2).*

## supervisor#2 [completed]

Le travail est terminé et vérifié indépendamment sur disque. Je livre la restitution finale pour l'exploitant (consolidée avec la revue phase 1, sans recopier les rapports).

---

# 🔖 Révision épinglée — blob git (working tree)

| Objet | Blob |
|---|---|
| `BRIEF_T364_REFONTE_COMPLETE_SEQUENCE_HOMING.md` (spec) | `d4adb41e9a4aa1bbd7f256d2606df71893b81b5a` |
| `CODE/G_CYCLE/FB_CycleMachineHoming.st` | `c882acac757b127f4bc0d1ab319d99d6c3c3c618` |
| `CODE/G_CYCLE/_TYPES/E_MachineHomingTxState.st` | `85e9697649f5bf5977a04ca116a53dc3dde2663e` |
| `CODE/G_CYCLE/_TYPES/E_MachineHomingStep.st` | `7b0a835c3a4d47db4d26cc0d7308ca01910f1dd0` |
| `CODE/G_CYCLE/_TYPES/ST_fbMachineHomingCycle_Cfg.st` | `7e0b1feba304a0b94886f879643f0829809eea32` |

> `FB:` = `FB_CycleMachineHoming.st` · `CFG:` = `ST_fbMachineHomingCycle_Cfg.st`. Énumération **réelle = 9 états** (`E_MachineHomingTxState.st:13-21`). **HX2N / HX3N / HX7_LOCKED_REFERENCE / HX5_BUCKET_COMMIT / HXF_FAILED n'existent plus.**

## ⚠️ D'abord — le brief est en partie PLUS ANCIEN que le code (3 points factuels)

1. **Brief §1 (L12-14)** liste des « états actuels » **pré-refonte obsolètes** (HX2N, HX3N, HX7_LOCKED_REFERENCE…). Le working tree les a **déjà supprimés** → à lire comme **spec-cible**, pas description du code.
2. **Brief §4 `HX4_BUCKET_ADJUST (:647)`** (L73-77) situe la désactivation du FDC benne à HX4 — **périmé** : elle est **déjà à HX1** (FB:423-426).
3. **Brief §5 « AUCUN CODE » (L93)** : ce lot est **aujourd'hui codé**.

**Contradiction interne du brief** : HX1a réclame « référencement M1+M2 » (L26) **et** HX3 réclame « réf. à nouveau » (L28) → le code a tranché : réf. **à HX3 uniquement** (FB:478-512). À confirmer.

---

# 1. TABLEAU SPEC vs CODE — HX0 → HX7

| Étape | Spec exige (citation) | Code fait (fichier:ligne) | Verdict |
|---|---|---|---|
| **HX0** | « Machine pas référencée (état initial) » (L24) | Étape pure, sortie uniquement `StartEdge`/`BtnValidationEdge` en MAINT_N2, jamais auto-armée (FB:411-418) | 🟢 **CONFORME** |
| **HX1** | « fermer benne, `WinchSel=2`, FDC benne désactivé, sortie par **un seul appui** » (L25) | `CmdWinchSelect:=2` (FB:423), `CmdBucketClose` sous `BucketPermit AND JoystickPull` (FB:424-425), sortie `HomingBucketConfirmEdge` **1 appui** (FB:431-435) | 🟢 **CONFORME** |
| **HX1a** | « bascule `WinchSel=0`, FDC réactivé. Référencement M1+M2… `M1 Homed=0` pas bloquant » (L26) | Bascule `:=0` (FB:441) + dwell interlock 300ms sur arbitrage (FB:442-447). **Pas de référencement ni de `M1 Homed=0 pas bloquant`** ici — différé à HX3 | 🟡 **INDETERMINE** |
| **HX2** | « monte les 2 treuils, **palier 1 MAX toujours** » (L27) | Montée couplée `StepTgt:=CST_StepSlow`=1 strict (FB:456-457), sortie sur `TopPositionSensor` (FB:463), interlock `WinchSel<>0`→fault (FB:259-260) | 🟢 **CONFORME** |
| **HX3** | « référence à nouveau M1+M2 à la volée sur pos config (défaut 8.5) » (L28) | Mode A vol (FB:478-488) + repli auto Mode B arrêt (FB:496-512), cible `CfgTopHomingTarget_M`=8.5 (CFG:15) | 🟢 **CONFORME** (structure) |
| **HX4** | « position **au-dessus de 8.5m**. Si échec : retour attente MAINT_N2 + nouvelle tentative » (L29) | Contrôle plage `[CfgStabilizationMinM..MaxM]` + cohérence M1/M2 (FB:524-527). **Défauts `7.50..9.50` acceptent <8.5m** (CFG:29-30) ; échec→`HX1_BUCKET_PREPARE` (FB:543) ; **3 retries max** (FB:538) | 🔴 **ECART** |
| **HX5 / HX6** | « à définir… **ne pas deviner** » (L30) | HX5 = dégagement zone haute + neutre (FB:547-555) ; HX6 = `MachineHomed` + commit benne (FB:557-567). **Rôles figés par le code, non validés** | 🔴 **ECART** (spéculé) |
| **HX7** | « Échec — acquittement Reset requis » (L31) | `HX7_FAILED` : sorties 0, aucune transition auto (FB:569-572) ; Reset **front**→HX0+purge (FB:294-304) ✓ | 🟢 **CONFORME** |

---

# 2. 🔴 LES ÉCARTS — par gravité

| Gravité | Constat | Fichier:ligne | Correction attendue |
|---|---|---|---|
| **BLOCK** | Aucun écart de logique avéré. **Seul verrou de livraison : la preuve aval E1** (test CI arbitrage) requise par brief §3.3 | FB:447,455 | Test d'intégration prouvant que `CmdWinchSelect=0` est réellement consommé par l'arbitrage aval avant HX2 et que les 2 treuils reçoivent l'ordre en simultané. **BLOCAGE livraison** si §3.3 strict |
| **MAJOR** | **HX4 accepte une position < 8.5m** (`7.50..9.50`). Incohérence : commentaires code + ENUM:18 revendiquent `[8.50..8.80]` | FB:524-527 · CFG:29-30 · ENUM:18 | Recentrer la bande sur ≥8.5 (ex. min=8.50) **et aligner les 3 sources** ; confirmer la cote (lien T301) avant figer |
| **MAJOR** | **Rôles HX5/HX6 imposés** alors que spec dit « ne pas deviner » | FB:547-567 | Décision exploitant sur les rôles, ou réouverture spec. Ne pas livrer tant que non tranché |
| **MINOR** | HX4 échec → re-engage `HX1_BUCKET_PREPARE` ≠ « attente MAINT_N2 » ; **nb de retries (3) non spécifié** | FB:536-544 | Trancher : attente simple vs rechaine complète + borne de tentatives |
| **MINOR** | HX1a : pas de référencement ni `M1 Homed=0 pas bloquant` (ambiguïté interne L26 vs L28) | FB:438-450 | Trancher : réf. reste à HX3 seul (conforme) ou à implémenter à HX1a ; sinon retirer la mention |

---

# 3. 🟢 LES CONFORMITÉS (preuve du travail fait)

- **Enum refonte = 9 états HX0..HX7 dont HX1a**, suppression HX2N/HX3N, **collision HX7 levée** (`E_MachineHomingTxState.st:13-21`).
- **HX0 ne démarre jamais en auto** : uniquement front conscient en MAINT_N2 (FB:411-418).
- **HX1 WinchSel=2 + FDC soft off + sortie 1 seul appui** (FB:423-435) — diverge du brouillon « 3 appuis », conforme au brief.
- **HX1a réalise l'interlock couplage E1** : WinchSel=0 + dwell 300ms sur retour d'arbitrage (FB:441-447).
- **HX2 palier 1 MAX strict** `StepTgt=1` (+`CouplingInterlockFault` si `WinchSel<>0`, FB:256-260).
- **HX3 Mode A vol + repli auto Mode B**, cible configurée 8.5 (FB:478-512 · CFG:15).
- **HX7 pas de redémarrage auto** ; Reset **front**→HX0+purge complète des latches (FB:294-304) — conforme principe non négociable AGENTS.md ; `M3Locked:=CycleRunning` (FB:595).
- **Qualification `MachineHomed` verrouillée** tant que commit/offset invalides, échec, ou re-homing non acquitté (FB:602-605).
- **Séquence testée au niveau FB** : suite CI `TOOLS/TEST_AUTO_CI/RESULTS/G_CYCLE/tests/test_fb_cyclemachinehoming.st` couvre HX0→HX7 (PASS).

---

# 4. 🟡 LES INDÉTERMINÉS — ce qu'il faut mesurer/trancher

| Point | Fichier:ligne | Ce qu'il faut mesurer / trancher |
|---|---|---|
| Seuil HX4 exact | CFG:29-30 vs FB:524-527 | Bande réelle (8.50..8.80 ? « >8.5 » ?) + aligner FB/ENUM/CFG |
| **Preuve aval E1** ⛔ verrou livraison | FB:447,455 | Test d'intégration arbitrage aval ; `grep J_SUPERVISION` sur `CmdWinchSelect` = 0 occurrence |
| Butée mécanique benne (fermeture à l'aveugle HX1) | FB:423-425 | Vérifier physiquement/specs une butée indépendante du soft (brief §4) — non prouvable depuis le code seul |
| Rôle HX5/HX6 | FB:547-567 | Décision exploitant (le code a deviné) |
| HX4 échec répété | FB:536-544 | Borne de tentatives + cible du retour |
| Calibration cote 8.5 / T301 | CFG:15 · PRG_02_Acquisition:549 | Mesurer cote capteur versus config : sinon erreur systématique invisible |
| FDC benne réactivé à HX1a | FB:441 | Vérifier dans `FB_Bucket` que la garde FDC relâchée dès `WinchSel=0` |

---

# 🧭 (5) Verdict global — écart spec↔code

**Code globalement conforme à l'esprit de la refonte T364** : séquence HX0→HX7 (9 états dont HX1a) **implémentée et testée au niveau FB** ; exigences opératoires fortes (WinchSel=2 puis 0, palier 1 MAX strict, référence à la volée, Reset requis, pas d'auto-armement, `M3Locked`) **respectées**.

**Mais l'écart spec↔code n'est pas bouclé sur 4 points**, dont **un fonctionnel MAJOR** :
1. 🔴 **HX4 accepte des positions sous 8.5m** — déviation réelle des seuils.
2. 🔴 **Rôles HX5/HX6 imposés par le code sans l'aval de l'exploitant**.
3. 🟡 **Preuve CI aval E1 absente → bloquante pour livraison** si brief §3.3 appliqué à la lettre.
4. 🟡 **Contradictions/périmé du brief** (HX1a réf, `HX4_BUCKET_ADJUST:647`, états §1 obsolètes) à résoudre explicitement.

Aucun défaut de **câblage logique avéré** ; mais la séquence ne doit pas être considérée **fiable et livrée** tant que le seuil HX4, la validation HX5/HX6, la preuve aval E1 et la vérification de la butée mécanique restent en l'état.

---
*Revue read-only (zéro écrit/commit). Hashes = `git hash-object` du working tree sur disque.*

## summary

supervisor 结论：Le travail est terminé et vérifié indépendamment sur disque. Je livre la restitution finale pour l'exploitant (consolidée avec la revue phase 1, sans recopier les rapports).

---

# 🔖 Révision épinglée — blob git (working tree)

| Objet | Blob |
|---|---|
| `BRIEF_T364_REFONTE_COMPLETE_SEQUENCE_HOMING.md` (spec) | `d4adb41e9a4aa1bbd7f256d2606df71893b81b5a` |
| `CODE/G_CYCLE/FB_CycleMachineHoming.st` | `c882acac757b127f4bc0d1ab319d99d6c3c3c618` |
| `CODE/G_CYCLE/_TYPES/E_MachineHomingTxState.st` | `85e9697649f5bf5977a04ca116a53dc3dde2663e` |
| `CODE/G_CYCLE/_TYPES/E_MachineHomingStep.st` | `7b0a835c3a4d47db4d26cc0d7308ca01910f1dd0` |
| `CODE/G_CYCLE/_TYPES/ST_fbMachineHomingCycle_Cfg.st` | `7e0b1feba304a0b94886f879643f0829809eea32` |

> `FB:` = `FB_CycleMachineHoming.st` · `CFG:` = `ST_fbMachineHomingCycle_Cfg.st`. Énumération **réelle = 9 états** (`E_MachineHomingTxState.st:13-21`). **HX2N / HX3N / HX7_LOCKED_REFERENCE / HX5_BUCKET_COMMIT / HXF_FAILED n'existent plus.**

## ⚠️ D'abord — le brief est en partie PLUS ANCIEN que le code (3 points factuels)

1. **Brief §1 (L12-14)** liste des « états actuels » **pré-refonte obsolètes** (HX2N, HX3N, HX7_LOCKED_REFERENCE…). Le working tree les a **déjà supprimés** → à lire comme **spec-cible**, pas description du code.
2. **Brief §4 `HX4_BUCKET_ADJUST (:647)`** (L73-77) situe la désactivation du FDC benne à HX4 — **périmé** : elle est **déjà à HX1** (FB:423-426).
3. **Brief §5 « AUCUN CODE » (L93)** : ce lot est **aujourd'hui codé**.

**Contradiction interne du brief** : HX1a réclame « référencement M1+M2 » (L26) **et** HX3 réclame « réf. à nouveau » (L28) → le code a tranché : réf. **à HX3 uniquement** (FB:478-512). À confirmer.

---

# 1. TABLEAU SPEC vs CODE — HX0 → HX7

| Étape | Spec exige (citation) | Code fait (fichier:ligne) | Verdict |
|---|---|---|---|
| **HX0** | « Machine pas référencée (état initial) » (L24) | Étape pure, sortie uniquement `StartEdge`/`BtnValidationEdge` en MAINT_N2, jamais auto-armée (FB:411-418) | 🟢 **CONFORME** |
| **HX1** | « fermer benne, `WinchSel=2`, FDC benne désactivé, sortie par **un seul appui** » (L25) | `CmdWinchSelect:=2` (FB:423), `CmdBucketClose` sous `BucketPermit AND JoystickPull` (FB:424-425), sortie `HomingBucketConfirmEdge` **1 appui** (FB:431-435) | 🟢 **CONFORME** |
| **HX1a** | « bascule `WinchSel=0`, FDC réactivé. Référencement M1+M2… `M1 Homed=0` pas bloquant » (L26) | Bascule `:=0` (FB:441) + dwell interlock 300ms sur arbitrage (FB:442-447). **Pas de référencement ni de `M1 Homed=0 pas bloquant`** ici — différé à HX3 | 🟡 **INDETERMINE** |
| **HX2** | « monte les 2 treuils, **palier 1 MAX toujours** » (L27) | Montée couplée `StepTgt:=CST_StepSlow`=1 strict (FB:456-457), sortie sur `TopPositionSensor` (FB:463), interlock `WinchSel<>0`→fault (FB:259-260) | 🟢 **CONFORME** |
| **HX3** | « référence à nouveau M1+M2 à la volée sur pos config (défaut 8.5) » (L28) | Mode A vol (FB:478-488) + repli auto Mode B arrêt (FB:496-512), cible `CfgTopHomingTarget_M`=8.5 (CFG:15) | 🟢 **CONFORME** (structure) |
| **HX4** | « position **au-dessus de 8.5m**. Si échec : retour attente MAINT_N2 + nouvelle tentative » (L29) | Contrôle plage `[CfgStabilizationMinM..MaxM]` + cohérence M1/M2 (FB:524-527). **Défauts `7.50..9.50` acceptent <8.5m** (CFG:29-30) ; échec→`HX1_BUCKET_PREPARE` (FB:543) ; **3 retries max** (FB:538) | 🔴 **ECART** |
| **HX5 / HX6** | « à définir… **ne pas deviner** » (L30) | HX5 = dégagement zone haute + neutre (FB:547-555) ; HX6 = `MachineHomed` + commit benne (FB:557-567). **Rôles figés par le code, non validés** | 🔴 **ECART** (spéculé) |
| **HX7** | « Échec — acquittement Reset requis » (L31) | `HX7_FAILED` : sorties 0, aucune transition auto (FB:569-572) ; Reset **front**→HX0+purge (FB:294-304) ✓ | 🟢 **CONFORME** |

---

# 2. 🔴 LES ÉCARTS — par gravité

| Gravité | Constat | Fichier:ligne | Correction attendue |
|---|---|---|---|
| **BLOCK** | Aucun écart de logique avéré. **Seul verrou de livraison : la preuve aval E1** (test CI arbitrage) requise par brief §3.3 | FB:447,455 | Test d'intégration prouvant que `CmdWinchSelect=0` est réellement consommé par l'arbitrage aval avant HX2 et que les 2 treuils reçoivent l'ordre en simultané. **BLOCAGE livraison** si §3.3 strict |
| **MAJOR** | **HX4 accepte une position < 8.5m** (`7.50..9.50`). Incohérence : commentaires code + ENUM:18 revendiquent `[8.50..8.80]` | FB:524-527 · CFG:29-30 · ENUM:18 | Recentrer la bande sur ≥8.5 (ex. min=8.50) **et aligner les 3 sources** ; confirmer la cote (lien T301) avant figer |
| **MAJOR** | **Rôles HX5/HX6 imposés** alors que spec dit « ne pas deviner » | FB:547-567 | Décision exploitant sur les rôles, ou réouverture spec. Ne pas livrer tant que non tranché |
| **MINOR** | HX4 échec → re-engage `HX1_BUCKET_PREPARE` ≠ « attente MAINT_N2 » ; **nb de retries (3) non spécifié** | FB:536-544 | Trancher : attente simple vs rechaine complète + borne de tentatives |
| **MINOR** | HX1a : pas de référencement ni `M1 Homed=0 pas bloquant` (ambiguïté interne L26 vs L28) | FB:438-450 | Trancher : réf. reste à HX3 seul (conforme) ou à implémenter à HX1a ; sinon retirer la mention |

---

# 3. 🟢 LES CONFORMITÉS (preuve du travail fait)

- **Enum refonte = 9 états HX0..HX7 dont HX1a**, suppression HX2N/HX3N, **collision HX7 levée** (`E_MachineHomingTxState.st:13-21`).
- **HX0 ne démarre jamais en auto** : uniquement front conscient en MAINT_N2 (FB:411-418).
- **HX1 WinchSel=2 + FDC soft off + sortie 1 seul appui** (FB:423-435) — diverge du brouillon « 3 appuis », conforme au brief.
- **HX1a réalise l'interlock couplage E1** : WinchSel=0 + dwell 300ms sur retour d'arbitrage (FB:441-447).
- **HX2 palier 1 MAX strict** `StepTgt=1` (+`CouplingInterlockFault` si `WinchSel<>0`, FB:256-260).
- **HX3 Mode A vol + repli auto Mode B**, cible configurée 8.5 (FB:478-512 · CFG:15).
- **HX7 pas de redémarrage auto** ; Reset **front**→HX0+purge complète des latches (FB:294-304) — conforme principe non négociable AGENTS.md ; `M3Locked:=CycleRunning` (FB:595).
- **Qualification `MachineHomed` verrouillée** tant que commit/offset invalides, échec, ou re-homing non acquitté (FB:602-605).
- **Séquence testée au niveau FB** : suite CI `TOOLS/TEST_AUTO_CI/RESULTS/G_CYCLE/tests/test_fb_cyclemachinehoming.st` couvre HX0→HX7 (PASS).

---

# 4. 🟡 LES INDÉTERMINÉS — ce qu'il faut mesurer/trancher

| Point | Fichier:ligne | Ce qu'il faut mesurer / trancher |
|---|---|---|
| Seuil HX4 exact | CFG:29-30 vs FB:524-527 | Bande réelle (8.50..8.80 ? « >8.5 » ?) + aligner FB/ENUM/CFG |
| **Preuve aval E1** ⛔ verrou livraison | FB:447,455 | Test d'intégration arbitrage aval ; `grep J_SUPERVISION` sur `CmdWinchSelect` = 0 occurrence |
| Butée mécanique benne (fermeture à l'aveugle HX1) | FB:423-425 | Vérifier physiquement/specs une butée indépendante du soft (brief §4) — non prouvable depuis le code seul |
| Rôle HX5/HX6 | FB:547-567 | Décision exploitant (le code a deviné) |
| HX4 échec répété | FB:536-544 | Borne de tentatives + cible du retour |
| Calibration cote 8.5 / T301 | CFG:15 · PRG_02_Acquisition:549 | Mesurer cote capteur versus config : sinon erreur systématique invisible |
| FDC benne réactivé à HX1a | FB:441 | Vérifier dans `FB_Bucket` que la garde FDC relâchée dès `WinchSel=0` |

---

# 🧭 (5) Verdict global — écart spec↔code

**Code globalement conforme à l'esprit de la refonte T364** : séquence HX0→HX7 (9 états dont HX1a) **implémentée et testée au niveau FB** ; exigences opératoires fortes (WinchSel=2 puis 0, palier 1 MAX strict, référence à la volée, Reset requis, pas d'auto-armement, `M3Locked`) **respectées**.

**Mais l'écart spec↔code n'est pas bouclé sur 4 points**, dont **un fonctionnel MAJOR** :
1. 🔴 **HX4 accepte des positions sous 8.5m** — déviation réelle des seuils.
2. 🔴 **Rôles HX5/HX6 imposés par le code sans l'aval de l'exploitant**.
3. 🟡 **Preuve CI aval E1 absente → bloquante pour livraison** si brief §3.3 appliqué à la lettre.
4. 🟡 **Contradictions/périmé du brief** (HX1a réf, `HX4_BUCKET_ADJUST:647`, états §1 obsolètes) à résoudre explicitement.

Aucun défaut de **câblage logique avéré** ; mais la séquence ne doit pas être considérée **fiable et livrée** tant que le seuil HX4, la validation HX5/HX6, la preuve aval E1 et la vérification de la butée mécanique restent en l'état.

---
*Revue read-only (zéro écrit/commit). Hashes = `git hash-object` du working tree sur disque.*
