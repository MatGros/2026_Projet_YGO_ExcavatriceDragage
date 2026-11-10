# 📋 Registre de Préparation — Prochaine Mise en Service (26/09/2026)

> **Date d'ouverture :** 2026-09-26  
> **Branche de départ :** `main` (Jalon `MES_FIN_20260923`, Commit `57076207`)  
> **Objet :** Recueil et suivi des retours d'exploitation sur site, analyse des anomalies physiques, nouvelles demandes et préparation des tâches avant la prochaine séance.

---

## 1. 📢 Retours d'Exploitation Terrain (24/09 - 25/09)

### 🟢 J1 — 2026-09-24 : Production nominale confirmée
- **~100 cycles automatiques complets réalisés sans blocage majeur.**
- Validation terrain de la bascule rapide AX10 ➔ AX10b ➔ AX11 (inversion DI M1/M2 active), du vidage trémie sécurisé sans saut AX10 (AX15B) et de la translation M3.

### 🔴 J2 — 2026-09-25 : Blocage à -6m & Clignotement Reset (Défaut MECA)
- **Constat sur site :** Benne bloquée sous l'eau à -6 m, bouton physique Reset / acquittement clignotant, affichage d'un défaut MECA au bandeau IHM. Impossibilité de remonter les treuils.
- **Soupçon initial sur site :** Perte suspectée de l'état `AtP1` (chariot M3) suite à reboot PLC ou perte de jeton, empêchant la montée.
- **Cause racine réelle constatée :**
  - **Le capteur de fin de course haut mécanique (TopPosition M1/M2) était physiquement cassé à l'intérieur** (vieillissement des plastiques du contacteur de position).
  - La rupture du contact NF a ouvert la boucle `TopPositionFree_DI = FALSE` ➔ coupure immédiate de `SafetyPermitM1_Ascent` et `SafetyPermitM2_Ascent` dans `FB_Safety_Winch` + déclenchement du SafeStop / défaut MECA.
- **Contournement appliqué sur site :**
  - **Le client a choisi de shunter électriquement le capteur mécanique Top M1/M2 au bornier.**
  - ⚠️ **Devoir d'alerte / Responsabilité Sûreté Machine (ISO 13849) :**
    - Ce shunt physique relève de la responsabilité exclusive de l'exploitant/client.
    - *Atténuation du risque :* Les codeurs absolus M1/M2 sont surveillés en permanence en dérive/plage et la butée logicielle haute n'est pas modifiée, ce qui réduit la probabilité de surcourse.
    - *Danger résiduel :* Le risque n'est pas nul (perte de la coupure matérielle redondante indépendante du soft en cas de défaillance codeur ou mouflage).

### ⚠️ Régression constatée — Translation M3 : Arrêt très au-delà des capteurs (P1 & Trémie)
- **Constat d'exploitation :**
  - Alors qu'en début de mise en service l'arrêt du chariot M3 était net et propre à l'arrivée sur capteur, une régression flagrante a été relevée le 25/09 : **le chariot s'arrête bien au-delà du capteur physique P1**.
  - Une suspicion analogue avait été perçue en fin de journée de MES côté Trémie (impression d'aller trop loin).
  - Ce dépassement est critique : il décale la position de travail par rapport à la géométrie de la carrière et de la trémie, et sollicite anormalement les limites mécaniques.
- **Pistes causales à investiguer (sans modifier le code) :**
  1. *Modification des vitesses d'approche du 23/09* : passage de la fréquence d'approche de 10 Hz à 20 Hz (qui augmente l'énergie cinétique au moment du freinage par 4).
  2. *Retard/temporisation de freinage* : augmentation du délai retour frein (800 ➔ 1000 ms).
  3. *Chaîne d'arrêt cycle vs manuel (sujet de la tâche T334)* : retrait de commande par le séquenceur au lieu d'un verrou d'arrêt franc dans l'axe.
- **Rattachement tâche :** Réactivation et mise à jour de la tâche **T334** (`Translation M3 : dépassement P1/Trémie en cycle`).

---

## 2. 📝 Nouvelles Demandes d'Évolution & Robustesse

### T394 — Robustesse position P1 après reboot sous l'eau & Permis translation / descente M3
- **Problématique :** Si l'automate reboote alors que la benne est descendue (ou si la position intermédiaire P1 n'est plus qualifiée), risque de blocage de la descente ou de la translation.
- **Objectifs de l'étude :**
  1. Étudier la possibilité de forcer ou requalifier l'état `AtPosition P1` (ex. bouton IHM ou forçage sécurisé) pour éviter les blocages de descente après un arrêt/reboot.
  2. Vérifier que la translation M3 reste possible au moins jusqu'aux zones PV / P2.
  3. Rendre accessible à l'IHM le réglage `Commun.Cfg.TglEnableWinchDescentLock_M3` (débrayage du verrou de descente treuil dépendant de M3) et formaliser ses conditions d'utilisation.

### T395 — Commandes en MAINTENANCE N2 (Mode Dépannage / Secours ultime)
- **Problématique :** En situation d'avarie (benne coincée au fond, défaut de contacteur de puissance, etc.), l'opérateur doit pouvoir manœuvrer pour sécuriser l'installation.
- **Objectifs de l'évolution :**
  1. **Commande des freins inconditionnelle en MAINT_N2 :** Débloquer le forçage des freins M1/M2 même si le retour contacteur de puissance `PowerContactorEngaged_DI` est retombé (ouverture par gravité ou secours), sous réserve stricte du maintien de la chaîne AU fermée et de l'homme-mort.
  2. **Mouvements treuils et translation dégradés en MAINT_N2 :** Permettre les déplacements manuels lents en N2 malgré des défauts/interdictions process ou logiques (bypasses automatiques sous N2), **à l'exception absolue du capteur Top mécanique M1/M2** (sécurité ultime préservée).

### T396 — Compteur horaire de fonctionnement totaliseur (M1, M2, M3 et automate/machine)
- **Origine & Demande client (MES 23/09, confirmée 26/09) :**
  - Mesurer le temps de fonctionnement pour chaque actionneur principal : **M1** (Treuil Levage), **M2** (Treuil Benne/Fermeture), **M3** (Translation chariot), ainsi que le temps total sous tension de l'automate.
  - **Mécanisme de comptage & persistance :** Compter **toutes les secondes** de fonctionnement réel et les mémoriser en mémoire persistante NVRAM (`_RunningHoursMachine_S`, `_M1_S`, `_M2_S`, `_M3_S` dans `GVL_PERSISTENT`).
  - **Diffusion IHM filtrée (H et Min uniquement) :** Seules les grandeurs en **Heures** et **Minutes** sont calculées et diffusées vers la supervision (`GVL_IHM.Commun.RunningHours` de type `ST_RunningHoursHMI`), les secondes restant strictement internes pour éviter tout encombrement et scintillement à l'écran.
  - **Inviolabilité & Zéro RAZ IHM :** Aucun bouton ni commande de remise à zéro sur l'IHM. La seule RAZ possible relève d'une réinitialisation formelle des variables persistantes (NVRAM / RETAIN) en maintenance.
- **État d'implémentation :**
  - Logique déjà entièrement conforme et codée sous commit `d95904ae` (`GVL_PERSISTENT`, incrémentation seconde par `TON` 1s + `R_TRIG` dans `PRG_07_Supervision`, division modulo vers `ST_RunningHoursHMI`).
  - Reste à déployer en ligne dans le PLC CODESYS, vérifier la persistance NVRAM après redémarrage électrique et raccorder l'affichage sur le synoptique IHM.

### T377 — Homing M1/M2 manuel sans contact TOP : approche prudente, validation visuelle et sécurité anti-casse
- **Origine & Problématique (MES 23/09 & Incident du 25/09) :**
  - Faire le homing en montant automatiquement heurter le capteur fin de course mécanique haut (Top M1/M2) est dangereux : risque de dépassement, de contrainte mécanique excessive et de casse physique (survenue le 25/09).
- **Nouvelle doctrine opérationnelle validée :**
  1. **Approche prudente sans contact :** Remplacement de l'étape de montée automatique jusqu'au capteur par une étape où l'opérateur monte manuellement avec prudence (joystick sous homme-mort) à proximité du capteur haut TOP, **sans aller le toucher**.
  2. **Validation visuelle opérateur :** L'opérateur s'arrête visuellement à la position haute d'alignement et appuie sur le bouton de confirmation existant du Grafcet homing (`BtnValidation` / `BtnConfirmHomingBucket`). Zéro nouveau bouton créé : réutilisation de l'existant.
  3. **Sécurisation en cas de contact fortuit sur le capteur TOP :**
     - **Pas de PowerCutOff immédiat au contact :** Évite une coupure brutale au moindre effleurement.
     - **Coupure immédiate de la commande montée :** Interdiction stricte de continuer à monter (`SafetyPermit_Ascent := FALSE`).
     - **Sens descente obligatoire :** Seule la descente manuelle est autorisée pour dégager le capteur.
     - **PowerCutOff conditionnel si persistance de mouvement montant :** Le PowerCutOff (AU / arrêt d'urgence matériel) n'est déclenché que si un mouvement de montée effectif persiste alors que la consigne automate est coupée (ex. contacteur de puissance resté collé ou forcé manuellement dans l'armoire — détecté via vitesse/codeur ou défaut MECA).

---

## 3. 🔍 Événements, Comportements & Points de Vigilance à Suivre

| # | Sujet | Constat ou Risque identifié | Surveillance / Mesures à prévoir en essai | Priorité |
|---|---|---|---|---|
| 1 | Remplacement capteur Top M1/M2 | Capteur shunté électriquement par le client (provisoire). | Exiger le remplacement physique par un capteur neuf certifié sécurité avant clôture définitive de la réception. | P0 |
| 2 | Régression arrêt M3 (T334) | Arrêt très au-delà des capteurs Trémie et P1 constaté le 25/09 (alors que propre auparavant). | Analyser l'impact de la fréquence d'approche (20Hz vs 10Hz) et du délai frein, corréler avec la chaîne d'arrêt T334. | P0 |
| 3 | Homing sans contact TOP (T377) | Risque de heurt mécanique sur capteur TOP lors du référencement. | Vérifier la coupure montée sur contact TOP, le dégagement obligatoire en descente, et le PowerCutOff sur persistance montée. | P1 |
| 4 | Compteurs horaires NVRAM (T396) | Persistance des heures M1/M2/M3 et automate après coupure électrique. | Vérifier lors du prochain arrêt/démarrage secteur que les compteurs ne sont pas remis à zéro et qu'aucun bouton IHM ne permet de RAZ. | P1 |
| 5 | Réglages RETAIN / NVRAM | Après import en ligne, certains paramètres IHM restent en cache mémoire. | Faire un reset RETAIN à froid au prochain arrêt machine pour vérifier que les défauts code (ex. 10%, 20Hz) s'appliquent bien. | P1 |
| 6 | Chute de tension réseau électrique | Réseau définitif : légère chute de tension sous forte charge. | Dynamique et inertie stables ; confirmer en dragage intensif continu. | P2 |

---

## 4. 🚀 Plan de Travail Préparatoire

1. **Traiter en priorité la régression d'arrêt M3 (T334)** : réactiver la tâche, qualifier la cause de l'allongement de distance d'arrêt (vitesse d'approche 20Hz vs 10Hz, temporisation frein 1000ms vs 800ms, ou logique de coupure de cycle), sans modification de code précipitée.
2. **Cadrer T394, T395, T396 et T377 dans [`TASKS.yaml`](../TASKS.yaml)** avec leurs critères d'acceptation et niveaux de criticité (C1..C4).
3. **Rédiger/mettre à jour les contrats de tâche** :
   - `TASK_CONTRACT_T334_M3_OVERSHOOT_REGRESSION.yaml`
   - `TASK_CONTRACT_T377_HOMING_MANUEL_SANS_CONTACT_TOP.yaml`
   - `TASK_CONTRACT_T394_P1_REBOOT_ET_PERMIS_M3.yaml`
   - `TASK_CONTRACT_T395_MAINT_N2_FREINS_ET_SECOURS.yaml`
4. **Audits ciblés de sûreté machine** avant toute proposition d'édition logicielle.
