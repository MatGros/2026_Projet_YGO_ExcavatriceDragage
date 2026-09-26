# 📋 Étude Technique & Cadrage Solution — T334
## Unification du Pilotage Translation M3 (Manuel vs Cycle Automatique) & Résolution Définitive du Dépassement sur Buteur (Trémie / P1)

> 📅 **Date** : 2026-09-26  
> 🏷️ **Tâche rattachée** : `T334` (Criticité C3) — *Translation M3 : dépassement P1/Trémie en cycle et unification des chemins de commande*  
> 📄 **Fiche troubleshooting d'origine** : [TROUBLESHOOTING_T334_M3_DeuxChemins_2026-09-20.md](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_T334_M3_DeuxChemins_2026-09-20.md)  
> 📊 **Traces de référence analysées** :  
>   - Mode Cycle Auto : `TOOLS/PLC_CSV_SNAPSHOT/RESULTS/trace/Suivi_91_SIMU_M3_20260926.trace`  
>   - Mode Manuel MAINT_N1 : `TOOLS/PLC_CSV_SNAPSHOT/RESULTS/trace/Suivi_91_SIMU_M3_MAINTn1_20260926.trace`  
> 👤 **Auteur & Revue** : Échange collaboratif Exploitant / Architecte Automatisme Senior  
> 🔒 **Statut** : Cadrage validé par l'exploitant — En attente d'implémentation ST (Lot T334/T345)

---

## 1. Contexte & Faits Établis par la Comparaison des Traces

En exploitation réelle comme en simulation banc, un comportement divergent critique a été mis en évidence :
1. **En mode Manuel (`MAINT_N1`)** : Le chariot M3 décélère à l'approche (clamp 20 Hz), touche le capteur (Trémie ou P1) et **s'arrête net, sans dépassement ni choc**, le temps d'arrêt physique étant négligeable.
2. **En mode Cycle Auto (`SEMI_AUTO`)** : Lors des étapes de translation (AX14 vers Trémie ou AX2 vers P1), le chariot **dépasse systématiquement le capteur** de 20 à 40 cm avant de s'immobiliser, ou glisse en roue libre.

L'analyse comparative des traces du 2026-09-26 a démontré que le dépassement n'est **pas imputable à une inertie mécanique incontrôlable**, mais à **un bug logiciel structurel** provoqué par la rupture de commande du séquenceur au contact du capteur.

---

## 2. Tableau Synthétique des Problèmes, Options et Solutions Validées

| Réf | Problème Identifié (Symptôme & Cause Racine) | Solutions Envisagées | Solution Validée par l'Exploitant |
| :---: | :--- | :--- | :--- |
| **PB-1** | **Rupture brutale de commande et roue libre variateur en cycle auto**<br/>Dès que le capteur est touché, `FB_CycleSemiAuto` coupe net `TranslationCmd.ReqStart := FALSE`.<br/>Dans `FB_Translation`, `ReqTremie/Maint` tombe à 0, entraînant :<br/>1. `RequestedDriveControlWord := 0` (coupure modulation variateur = roue libre).<br/>2. Disparition du clamp PV 20 Hz ➔ bond de consigne calculée à 48.6 Hz.<br/>Le variateur cesse de freiner électriquement. | **Option A** : Augmenter la décélération rapide du variateur ou forcer un arrêt d'urgence.<br/>**Option B** : Temporiser l'étape dans le G7 avec un timer fixe.<br/>**Option C (Validée)** : **L'axe possède son arrêt**. Le G7 maintient `ReqStart := TRUE` tant que l'axe n'a pas fini sa décélération et fermé son frein. | **OPTION C RETENUE** :<br/>Aligner le cycle auto sur le manuel : `FB_Translation` pilote la décélération électrique continue de 20 Hz jusqu'à 0 Hz en maintenant `ControlWord = 1/2`. |
| **PB-2** | **Complexité et divergence de `SelTarget` (Manuel vs Auto)**<br/>Actuellement, l'arbitre force `SelTarget := 1` (Trémie) ou `3` (P1) en cycle auto, alors qu'en manuel `SelTarget = 0`.<br/>Cela introduit une double logique de sélection et de gestion de cible dans `FB_Translation` et `PRG_05`. | **Option A** : Conserver `SelTarget = 1/3` et modifier le traitement de cible dans `FB_Translation`.<br/>**Option B (Validée)** : **Généraliser `SelTarget = 0`**. L'axe détermine son arrêt automatiquement à partir du sens de translation et des autorisations métiers. | **OPTION B RETENUE** :<br/>Utiliser `SelTarget = 0` en cycle comme en manuel.<br/>Dans `PRG_05` :<br/>- Sens avant (Trémie) ➔ arrêt automatique Trémie (`TargetCode = 1`).<br/>- Sens arrière (P1/Maint) ➔ arrêt automatique P1 (`TargetCode = 3`). |
| **PB-3** | **Risque d'intrusion en zone Maintenance en Cycle Auto**<br/>Si l'autorisation d'accès zone maintenance (`Auth.MaintenanceM3TargetEnable` / bouton IHM `SelMaintenanceZoneAccess`) est active, un recul vers P1 risque de cibler le fin de course extrême Maintenance (code 4) au lieu de P1 (code 3). | **Option A** : Laisser l'opérateur vigilant sur son écran IHM.<br/>**Option B (Validée)** : Forcer inconditionnellement `MaintenanceM3TargetEnable := FALSE` en `SEMI_AUTO` et réinitialiser le bouton IHM lors du démarrage du cycle. | **OPTION B RETENUE** :<br/>Verrouillage strict : en `SEMI_AUTO`, l'accès zone Maintenance est forcé à FALSE, et le bit IHM est réinitialisé à l'entrée en cycle. |
| **PB-4** | **Risque de mouvement M3 parasite hors des étapes autorisées**<br/>Pendant les étapes benne/treuils (AX6 plongée, AX10 fermeture, AX12 remontée), un mouvement involontaire du joystick en X ne doit pas faire bouger le chariot M3. | **Option A** : Filtrer uniquement dans le bloc Joystick.<br/>**Option B (Validée)** : **Double barrière d'interlock** dans `PRG_05_Translation` (veto amont sur les requêtes + écrasement à 0 de la commande variateur et frein en sortie finale). | **OPTION B RETENUE** :<br/>Conserver et consolider le double verrou `M3_CycleTranslationStepAuthorized` (actif uniquement en AX2 et AX14 en `SEMI_AUTO`). |
| **PB-5** | **Transition prématurée du G7 avant l'arrêt physique complet**<br/>Le signal `ArrivalStopConfirmed` actuel valide l'arrêt dès $f_{act} \le 0.5\text{ Hz}$ et `NOT BrakeReleaseRequest`.<br/>Or, à 0.5 Hz le moteur tourne encore, et le frein mécanique met 200 à 300 ms à retombée. Le G7 passait à l'étape suivante alors que le pont était encore en mouvement. | **Option A** : Ajouter un timer fixe empirique dans chaque étape G7.<br/>**Option B (Validée)** : **Fiabiliser `ArrivalStopConfirmed` dans `FB_Translation`** par une confirmation triple :<br/>1. Verrou cible armé (`ArrivalLock`).<br/>2. Vitesse quasi nulle confirmée par tempo (`TonSpeedZero` : $f \le 0.1\text{ Hz}$ pendant 250 ms).<br/>3. Frein retombé physiquement (`NOT M3_BrakeIsOpen_DI` et ordre frein à 0). | **OPTION B RETENUE** :<br/>Sécurisation robuste de `ArrivalStopConfirmed`. Le G7 ne transite que sur ce fait certifié, garantissant une machine 100 % immobile avant la suite. |

---

## 3. Détail de la Solution Cible Unifiée

### 3.1. Principe de Fonctionnement Unifié (`SelTarget = 0`)
Quel que soit le mode (`MAINT_N1`, `MAINT_N2` ou `SEMI_AUTO`) :
- L'opérateur maintient le joystick incliné dans la direction souhaitée (avec homme-mort armé).
- En `SEMI_AUTO`, le mouvement n'est transmis à l'arbitre que si l'étape active est AX2 (vers P1) ou AX14 (vers Trémie).
- La consigne cible reste `SelTarget = 0` :
  - **Manche vers l'avant (Droite / +1)** ➔ `M3_TargetCodeSel := 1` (Trémie). Ralentissement automatique au capteur PV (20 Hz), puis déclenchement de l'`ArrivalLock` au capteur Trémie, freinage régénératif jusqu'à 0 Hz et serrage du frein.
  - **Manche vers l'arrière (Gauche / -1)** ➔ `M3_TargetCodeSel := 3` (P1). Ralentissement automatique au capteur P2 (20 Hz), puis déclenchement de l'`ArrivalLock` au capteur P1, freinage régénératif jusqu'à 0 Hz et serrage du frein.

### 3.2. Séquencement du Cycle Auto (G7)
Dans `FB_CycleSemiAuto.st` :
- **En AX14** :
  - L'étape émet `TranslationCmd.ReqStart := TRUE` et maintient cette demande pendant toute la course et pendant la phase de décélération de l'axe.
  - La réceptivité de transition vers AX15a devient :
    ```pascal
    IF Translation_At_Tremie AND Translation_ArrivalStopConfirmed THEN
        TranslationCmd.ReqStart := FALSE;
        State := E_AutoCycleStep.AX15A_DUMP_ARRIVE;
    END_IF;
    ```
- **En AX2** :
  - Même logique : `ReqStart := TRUE` maintenu pendant l'approche.
  - La réceptivité de transition vers AX3 devient :
    ```pascal
    IF Translation_At_P1 AND Translation_ArrivalStopConfirmed THEN
        TranslationCmd.ReqStart := FALSE;
        State := E_AutoCycleStep.AX3_OPEN_BUCKET;
    END_IF;
    ```

### 3.3. Fiabilisation du Signal `ArrivalStopConfirmed`
Dans `FB_Translation.st`, l'indicateur d'arrêt complet intègre la dynamique réelle de la chaîne cinématique :
```pascal
// Temporisation de stabilisation vitesse nulle (anti-rebond et fin de flux moteur)
TonSpeedZero(IN := (ABS(DriveActualFreqHz) <= 0.1), PT := T#250ms);

// Confirmation mécanique frein retombé (feedback physique DI ou fin de temporisation retombée)
BrakeMechanicallyLocked := NOT BrakeReleaseRequest 
                           AND NOT PRG_02_Acquisition.HwIn.Translation.M3_BrakeIsOpen_DI;

// Fait public d'arrêt certain
ArrivalStopConfirmed := ArrivalLock
                        AND NOT Fault.Error
                        AND TonSpeedZero.Q
                        AND BrakeMechanicallyLocked;
```

---

## 4. Plan de Validation & Déploiement

1. **Rattachement Catalogue** : Intégration dans la tâche active `T334` de `DOC/WFLOW/TASKS.yaml`.
2. **Rédaction du Contrat de Tâche** : Mise à jour de `TASK_CONTRACT_T334_AUTO_CYCLE_M3_OVERSHOOT.yaml` reflétant les 5 critères d'acceptation validés ci-dessus.
3. **Implémentation ST** :
   - `FB_Translation.st` : Fiabilisation `ArrivalStopConfirmed` et maintien du clamp pendant `ArrivalLock`.
   - `FB_TranslationCmdArbitrationM3.st` : Application de `SelTarget = 0` en `SEMI_AUTO`.
   - `FB_CycleSemiAuto.st` : Maintien de `ReqStart` jusqu'à `ArrivalStopConfirmed` en AX2 et AX14.
   - `FB_Modes.st` : Forçage RAZ `SelMaintenanceZoneAccess` à l'entrée en cycle.
4. **Validation CI & Banc** :
   - Exécution de la suite de tests unitaires CI (`run_all_tests.bat`).
   - Exécution des 21 gates mécaniques (`run_all_gates.py`).
   - Génération du bundle PLCopenXML et vérification de liaison bloquante (`G200_check_linkage.py`).
