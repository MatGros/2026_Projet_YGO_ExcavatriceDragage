# 🔎 Audit — Homogénéisation & Purge Inconditionnelle des Bypasses Globaux (v1.0)

> 📄 **Document d'analyse et plan d'action** (2026-07-23).
> Analyse le retour terrain sur le blocage du Bypass Global Translation M3 et définit les règles d'homogénéisation pour TOUS les axes (M1, M2, M3, Benne, Synchro).
> 📌 Suivi actions : `PLAN_TASK_v1.0.md` (Nouvelle action prioritaire Maint/Mise en service).

---

## 0. Contexte & Problématique Terrain

Lors des essais terrain du 2026-07-23, un blocage a été constaté lors de l'utilisation du **Bypass Global Translation M3** :
1. Une incohérence transitoire du frein s'est produite en fonctionnement normal, déclenchant le bit `StuckOpen := 1` dans le sous-bloc `FB_Brake`.
2. L'opérateur a enclenché `Bypass.Global := TRUE` pour pouvoir déplacer le chariot en mode dégradé / maintenance.
3. **Problème** : Malgré l'activation du Bypass Global, la machine est restée bloquée à l'arrêt.

### 🔍 Cause Racine (Analyse Code ST)
* Le bloc maître de sécurité `FB_Safety_Translation` purgeait bien ses propres défauts (`ErrorId := 0` lors de `BypassGlobal = TRUE`).
* **Mais** le sous-composant `FB_Brake` (gestion physique du frein) appelait l'entrée `BypassContactorCheck` uniquement reliée à la simulation (`GVL_Simulation.SimulationModeActive`), sans recevoir l'information du `Bypass.Global`.
* Par conséquent, le sous-bloc `FB_Brake` conservait son bit d'erreur `StuckOpen = 1` mémorisé **avant** l'activation du bypass, et bloquait l'ouverture du frein.

---

## 1. Principe & Doctrine d'Architecture Recommandée

### 🎯 Règle d'or du Bypass Global Machine
> **Lorsqu'un opérateur ou un automaticien active le Bypass Global d'un axe (M1, M2, M3, Benne) sur l'IHM :**
> 1. **Purge Immédiate** : TOUS les défauts mémorisés (y compris dans les sous-blocs réutilisables comme `FB_Brake` ou `FB_SpeedStep`) doivent être immédiatement réinitialisés à `0`.
> 2. **Désactivation des Timers** : Tous les temporisateurs d'incohérence/surveillance doivent être forcés à `IN := FALSE`.
> 3. **Propagations Transversales** : L'information du Bypass Global doit être obligatoirement transmise aux sous-composants appelés (ex: `BypassContactorCheck`).

Aucun "reliquat de défaut" mémorisé avant l'activation du bypass ne doit pouvoir maintenir l'axe bloqué.

---

## 2. Inventaire des Actions à Mener par Axe

### ↔️ Axe M3 — Translation Chariot (`PRG_07_TranslationControl.st`)
* **Problème** : `BypassContactorCheck` sur l'instance `instTranslationM3` ne prenait pas en compte `Bypass.Global`.
* **Action Code** :
  Dans `PRG_07_TranslationControl.st` (Ligne 161) :
  ```pascal
  // Avant
  BypassContactorCheck := GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.SensorM3ContactorFeedbackIsReal;

  // Après (Correctif)
  BypassContactorCheck := GVL_IHM.TranslationM3.Bypass.Global 
                          OR GVL_IHM.TranslationM3.Bypass.ContactorFeedback 
                          OR (GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.SensorM3ContactorFeedbackIsReal);
  ```

---

### 🪝 Axes M1 & M2 — Treuils Retenue & Benne (`PRG_06_WinchControl.st`)
* **Problème** : Les instances `instWinchM1` et `instWinchM2` présentent exactement le même découplage sur leur sous-bloc `FB_Brake`. Si un contacteur/frein se bloque en fonctionnement normal, l'activation ultérieure du Bypass Global Treuil ne purgeait pas `FB_Brake`.
* **Action Code** :
  Dans `PRG_06_WinchControl.st` (Lignes 478 et 525) :
  ```pascal
  // Treuil M1
  BypassContactorCheck := GVL_IHM.M1TreuilRetenue.Bypass.Global 
                          OR GVL_IHM.M1TreuilRetenue.Bypass.ContactorCheck 
                          OR (GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.SensorM1ContactorFeedbackIsReal);

  // Treuil M2
  BypassContactorCheck := GVL_IHM.M2TreuilBenne.Bypass.Global 
                          OR GVL_IHM.M2TreuilBenne.Bypass.ContactorCheck 
                          OR (GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.SensorM2ContactorFeedbackIsReal);
  ```

---

### 🪨 Benne M2 (`FB_Bucket.st`)
* **Action Code** : Vérifier la propagation de `BypassGlobal` sur l'instance `FB_Bucket` afin d'assurer l'annulation de toute temporisation de blocage mécanique lors d'une manœuvre dégradée de la benne.

---

## 3. Plan de Validation & Tests (Procédure de Qualification)

Pour valider l'efficacité du correctif lors de la prochaine mise à jour :

1. **Test Provocation de Défaut (Sans Bypass)** :
   * Simuler ou débrancher un retour contacteur/frein sur M1, M2 ou M3 pour provoquer l'alarme `StuckOpen = 1`.
   * Vérifier que la machine s'arrête en sécurité.
2. **Test Activation du Bypass Global** :
   * Activer `Bypass.Global := TRUE` sur l'IHM sans appuyer sur Reset.
   * **Critère de Succès** : Le défaut `StuckOpen` doit disparaître **immédiatement**, les sorties de commande doivent se libérer, et le mouvement doit pouvoir s'effectuer en mode dégradé sans aucune action supplémentaire.
