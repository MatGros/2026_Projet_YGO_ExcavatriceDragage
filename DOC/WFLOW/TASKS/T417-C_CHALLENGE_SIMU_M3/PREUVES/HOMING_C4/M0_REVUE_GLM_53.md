# 🔴 BLOCK — Revue T417-C : 5 failles bloquantes à trancher avant écriture CODE/

**Verdict :** BLOCK — le design D1–D7 est structurellement sain, mais 6 points de spécification manquants ou contradictoires, dont deux à portée sécurité (ISO 13849 : comportement des fonctions sécurité non défini en MAINT_N2, fausse référence possible au Step 4).
**Durée/Horodatage :** n/d — revue statique du document design fourni uniquement ; **aucun fichier du dépôt lu, aucun outil exécuté** (faits = texte D1–D7 ; le reste = inférences marquées).
**Périmètre honoré :** aucune écriture dans `CODE/`, aucun commit.

## Niveau 1 — Checklist design (1–10, points critiques)

1. `[✅ PASS]` **D2 entrée Step 0** — spécification complète et cohérente : 5 s `JoyBtnRaw`+`AtNeutralXY`+`SeenReleased`, entrée N2 par front `BtnStart`, verrou `MachineHomed`, indépendance vis-à-vis d'`ArmingPermit` à l'entrée.
2. `[❌ FAIL]` **Devenir d'`ArmingPermit` après Step 0 (N1) non spécifié.** Si `ArmingPermit` reste FALSE en Step 1 : aucun mouvement M2 autorisé, garde 20 s en boucle — impasse garantie. Règle manquante : `ArmingPermit := TRUE` quand `MachineHoming.Active AND Step >= 1`.
3. `[❌ FAIL]` **D7 N2 : conflit `Meca D` actif + `MaintenanceN2BrakeForceM1/M2` + descente par gravité non tranché.** Frein forcé ⇒ Step 3 impossible (blocage au contact TOP) ; frein relâché sous `PowerCutOff` ⇒ descente non maîtrisée de charge suspendue. Le masquage du faux `Meca B` n'est borné à aucun créneau précis.
4. `[❌ FAIL]` **Step 4 : course de commit.** `NOT TopPositionSensor` n'est évalué qu'au front `BtnValidate` ; l'auto-move vers `8,5 m` peut ensuite déclencher le contact TOP **pendant l'attente `BothAxesHomed`** — rien n'interdit alors l'écriture `MachineHomed := TRUE` sur un contact TOP.
5. `[❌ FAIL]` **Absence d'interlock « benne fermée »** entre Step 1 et Step 4 : montée possible benne ouverte ⇒ cible `8,5 m + OffsetCloseM` incohérente ⇒ fausse référence committée avec `BucketCommit.CommitClose`.
6. `[❌ FAIL]` **HX7/Abort : hygiène d'état et watchdog Step 4 absents.** Si `MachineHoming.Active` couvre HX7, `SoftLimitsBypassed`, déverrouillages M3 (`M3AtTremie`, `T248`, `WinchDescentAuth_M3`) et masques Meca persisteraient hors séquence. Attente `BothAxesHomed` potentiellement infinie au Step 4 (benne coincée).
7. `[❌ FAIL]` **D6 : sémantique du 4 s ambiguë.** « Descente continue » après relâchement TOP : si le chronomètre est une fenêtre continue et que l'opérateur relâche à 3,9 s puis repasse au neutre, sortie prématurée vers Step 1 ⇒ re-contact TOP en boucle. Sémantique à imposer : temps **accumulé** de descente après relâchement, figé au neutre, sortie seulement si `accumulé ≥ 4 s AND neutre`.
8. `[❌ FAIL]` **D4 : 2 s « par geste » contournable.** Si la fenêtre se ré-arme sans observation de neutre, un maintien continu du joystick enchaîne des descentes de détente illimitées. Re-armement subordonné à `AtNeutralXY` observé.
9. `[❌ FAIL]` **Step 2 : capteur TOP collé FALSE** (fil coupé, faux contact) =aucun arrêt logiciel avant butée mécanique. Le design n'a qu'un seul canal de détection de surcourse. Rédundance manquante : plafond encodeur (`M1PosEst ≥ CfgTopApproachMaxM` ⇒ coupure + Step 3, sans écriture de référence, sans aveugler le capteur).
10. `[⚪ N/A]` **Couplage `FB_WinchSync` avec axes non référencés** (faute de synchro possible au Step 2 ? arbitrage `WinchSelArbitrated = 0` atteignable ?), **branche manuelle `FB_Bucket` sans `BucketReferenced`** au Step 1 : invérifiable sans les sources. Idem ancres `PRG_04:1632,1653`. Verdict limité par ces inconnues.

**Fixes socle** (PRG_07 `AnyFaultActive`/`SimBypassRise`, PRG_03 boot N1, `FB_SimBench` arrêt méca M2 post-référencement, `FB_Encoder_Homing` blocage `BtnHome` unitaire + porte Step 4, invalidation `BucketReferenced`) : cohérents entre eux et avec D1–D7.

## Niveau 1 bis — Réponses Q1/Q2

**Q1 (trous/deadlocks) :** voir items 2, 3, 4, 5 ci-dessus — ce sont les quatre candidats nommés dans la question, tous confirmés comme non tranchés par le texte fourni. Complément : `InReferencingMode` doit rester FALSE pendant les Steps 1–3 ; vérifier qu'aucun consommateur tiers ne l'exige pour autoriser M2 (sinon impasse Step 1) ni n'aveugle `TopPositionSensor` (interdit D3). `WinchSelArbitrated = 0` doit être atteignable sans mouvement opérateur avant l'ordre Step 2, et toute traction avant arbitrage doit rester inhibée.

**Q2 (seuils/replis) :** ordres de grandeur cohérents. Sémantiques à figer : 20 s = coupure jusqu'au neutre + relâchement homme-mort, **2ᵉ déclenchement ⇒ HX7** ; 2 s avec hystérésis neutre (item 8) ; 4 s accumulé (item 7), garder `× vitesse palier 1 > profondeur d'engagement capteur` ; 5 s OK (`SeenReleased` anti-collage correct) ; 3 s Meca B/D = séquencement — interdire toute fenêtre « puissance coupée + frein non forcé » sur charge suspendue, ré-armement de la surveillance Meca B immédiatement après le geste. Replis : `HX7_FAILED` = état terminal (message + `MachineHomed` reste FALSE, redémarrage via Step 0 uniquement) ; `Abort` (opérateur/E-Stop) = retour Step 0 immédiat, mêmes purges ; `Active` défini sur Steps 0–4 seulement, HX7 hors `Active`.

## Niveau 2 — Plan d'action avant écriture CODE/

1. **Localisation :** design §D3. **Ancre :** entrée Step 1. **Action :** ajouter la règle d'armement `ArmingPermit` (Step ≥ 1). **Outil :** `grep -rn "ArmingPermit" CODE/` à l'écriture. **Risque si ignoré :** impasse Step 1.
2. **Localisation :** design §D7. **Ancre :** `PRG_04:1632,1653`. **Action :** matrice de priorité {frein forcé, Meca D, descente intentionnelle} par Step ; masque Meca B borné à `Active AND Step IN [2,3] AND ReqDescend AND NOT ReqAscent`. **Outil :** grep `MaintenanceN2BrakeForce` + revue diff. **Risque :** chute non contrôlée / boucle de faux défaut.
3. **Localisation :** design §D4bis. **Ancre :** commit final. **Action :** commit atomique `MachineHomed := TRUE` seulement si `BothAxesHomed AND NOT TopPositionSensor` évalués au même cycle ; TOP pendant Step 4 ⇒ HX7. **Outil :** pytest (INV-12/13). **Risque :** fausse référence sur contact TOP.
4. **Localisation :** design §D3→D4. **Ancre :** entrée Step 2. **Action :** exiger confirmation benne fermée avant la montée (ou before `CommitClose`). **Outil :** grep sorties `FB_Bucket`. **Risque :** offset `OffsetCloseM` faux.
5. **Localisation :** design §D5. **Ancre :** montée Step 2. **Action :** plafond encodeur `CfgTopApproachMaxM`. **Outil :** pytest simulation. **Risque :** crash mécanique sur capteur mort.
6. **Localisation :** design états. **Ancre :** HX7/Abort. **Action :** purges systématiques + watchdog Step 4 (ex. 15 s paramétrable Cfg). **Outil :** pytest (INV-14). **Risque :** bypass résiduel hors séquence.
7. Pré-requis verdict complet : fournir `PRG_02..PRG_07`, `FB_WinchSync.st`, `FB_Encoder_Homing.st`, `FB_Bucket.st` ; `grep -rn "InReferencingMode|SoftLimitsBypassed|WinchBothIntent" CODE/` pour recenser tous les consommateurs. **Risque si ignoré :** trou inter-modules non détecté.

## Q3 — Invariants à tester (`test_fb_cyclemachinehoming.st`)

1. INV-01 : entrée N1 = 5 s neutre + `SeenReleased`, décompte affiché, indépendante de `DeadmanArmed`/`ArmingPermit`.
2. INV-02 : entrée refusée si `MachineHomed = TRUE` OU `AnyFaultActive` — zéro transition.
3. INV-03 : entrée N2 = front `BtnStart` au neutre ou méthode 5 s ; même verrou.
4. INV-04 : Step 1 : `SoftLimitsBypassed = TRUE`, `InReferencingMode = FALSE`, `ManualBucketLimitsActive = FALSE`, `CfgCableLimitDescentM` inhibée, `TopPositionSensor` actif.
5. INV-05 : Step 1 : purge `instBucket` à l'entrée ⇒ zéro `ErrorID:04/05` ; M2 seul palier 1, open ET close autorisés.
6. INV-06 : Step 1 : garde 20 s — décompte live, coupure jusqu'au neutre/relâchement, 2ᵉ trip ⇒ HX7.
7. INV-07 : Step 1→2 : `BtnValidate` au neutre ; mouvement inhibé jusqu'à `WinchSelArbitrated = 0` + neutre ; couplage sans faute `FB_WinchSync`.
8. INV-08 : Step 2 : montée seulement `DeadmanArmed AND JoystickPull` ; Step 3 : toute demande montée ⇒ aucun contacteur montée.
9. INV-09 : contact TOP en Step 2 ⇒ coupure immédiate + Step 3 ; **jamais** d'écriture 8,5 m ni de `MachineHomed`.
10. INV-10 : détente Step 2 bornée à 2 s, ré-armement après neutre observé uniquement.
11. INV-11 : Step 3 : 4 s accumulé après relâchement TOP, figé au neutre ; sortie ⇒ Step 1 uniquement.
12. INV-12 : Step 4 : mouvements bloqués + message `8,5 m + benne fermee` ; commit = `BtnValidate` au neutre AND `NOT TopPositionSensor` au cycle de commit ; TOP pendant l'auto-move ⇒ HX7, `MachineHomed` reste FALSE.
13. INV-13 : commit = `M1Demand 8,5` + `M2Demand 8,5+OffsetCloseM` + `BucketCommit.CommitClose` puis `BothAxesHomed` avant `MachineHomed := TRUE` ; `BtnHome` unitaire à 8,5 m impossible hors Step 4 sans contact TOP.
14. INV-14 : HX7/Abort/E-Stop ⇒ coupure + purge (`SoftLimitsBypassed`, M3, masques Meca, demandes) + `MachineHomed = FALSE` + retour Step 0 ; retour Step 0 OK ⇒ re-verrouillage M3 N1, limites restaurées, `MachineHoming.Active` cleared.
15. INV-15 : M3 : verrou commandé dès Step 0 N1 quel que soit la position capteur ; déverrouillage/levées `M3AtTremie`/`T248`/`WinchDescentAuth_M3` limités aux Steps 1–4 ; N2 Step 0 libre. Boot `NOT MachineHomed` ⇒ `MAINT_N1` (jamais `SEMI_AUTO`).
16. INV-16 (sim) : `M2_MechanicStopEngaged` (et homologue M1) jamais avant référencement ; capteur TOP simulé à `8,5 m + marge` ; `SimBypassRise` n'active jamais `Bypass.TopLimitSwitch`/`Bypass.Safety` pendant le run.

## Informations minimales manquantes (limite de verdict)

- Définition/créneau d'`ArmingPermit` actuel ; logique frein/Meca B/D réelle en N2 (contexte `PRG_04:1632,1653`) ; internes `FB_WinchSync` et `UseDynamicTarget` ; sémantique exacte `ReqAscend/ReqDescend` ; type de frein (détermine la descente par gravité). Sans ces éléments, les items 3, 4, 10 restent des inconnues confirmées — le BLOCK couvre ce qui est déjà prouvé par le texte design.