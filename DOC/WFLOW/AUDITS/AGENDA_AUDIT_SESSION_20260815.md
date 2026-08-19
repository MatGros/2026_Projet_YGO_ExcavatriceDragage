# 📋 JOURNAL D'AUDIT TECHNIQUE — SESSION DU 15 AOÛT 2026

**Projet** : Excavatrice de Dragage en Carrière Noyée  
**Cible API** : CODESYS 3.5 (IEC 61131-3)  
**Document** : Récapitulatif exhaustif des interventions pour audit & revue technique  
**Date** : 15 Août 2026  

---

## 🎯 Résumé Exécutif

Cette session a été consacrée à la fiabilisation du comportement mécanique et logique du treuil de benne (M2), à la résolution du référencement dynamique, à l'enrichissement des outils de diagnostic en direct (`GVL_Troubleshooting`) et à l'implémentation de mécanismes d'essais rapides (`SimulationBypassActive`).

Tous les développements ont été validés mécaniquement par l'intégralité des 18 gates CI du projet (492 tests unitaires, 0 régression, 0 erreur de liaison).

---

## 📑 Liste Exhaustive des Tâches & Actions Réalisées

| # | Tâche / Thématique | Fichiers Concernés | Description Technique & Décision d'Ingénierie |
|---|---|---|---|
| **1** | **Correction du Homing Dynamique M2** | [`FB_Encoder_Homing.st`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/E_CODEURS/FB_Encoder_Homing.st)<br>[`PRG_02_Acquisition.st`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/M_MAIN/PRG_02_Acquisition.st) | **Problème** : Le référencement M2 restait figé à 8m suite à une non-prise en compte du front sur `UseDynamicTarget`.<br>**Action** : Ajout de `DynamicTargetEdge : R_TRIG` dans `FB_Encoder_Homing` et refonte de la garde de déclenchement pour recalculer immédiatement `Calib.HomingRefRaw` à la position cible désirée ($0.0\text{ m}$ ou $15.0\text{ m}$). |
| **2** | **Suppression des forçages d'états manuels Benne** | [`FB_Bucket.st`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st) | **Règle de Sécurité** : `IsOpen` et `IsClosed` ne doivent jamais être forcés aveuglément par un bouton IHM.<br>**Action** : Suppression des assignations directes dans `ConfirmOpenPosition`/`ConfirmClosePosition`. L'état benne est exclusivement issu de la comparaison géométrique continue des codeurs réels. |
| **3** | **Extension à 5 Zones d'État Explicites Benne** | [`ST_BucketState.st`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/H_TREUILS_BENNE/BENNE/ST_BucketState.st)<br>[`FB_Bucket.st`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st) | **Ergonomie Opérateur** : Fournir une indication claire du sens de correction en cas de décalage.<br>**Action** : Ajout des indicateurs continus calculés hors BUSY :<br>• `TooOpen` ($\Delta < -1.0\text{ m}$ ➔ Enrouler M2)<br>• `IsOpen` ($[-1.0\text{ m} \dots +1.0\text{ m}]$)<br>• `IsIntermediate` ($]1.0\text{ m} \dots 14.0\text{ m}[$)<br>• `IsClosed` ($[+14.0\text{ m} \dots +16.0\text{ m}]$)<br>• `TooClosed` ($\Delta > +16.0\text{ m}$ ➔ Dérouler M2). |
| **4** | **Affichage de l'Écart Réel Signé ($\Delta$)** | [`ST_BucketHMIState.st`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/J_SUPERVISION/_TYPES/1_TREUILS_BENNE/ST_BucketHMIState.st)<br>[`FB_Bucket.st`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st)<br>[`PRG_04_Treuils_Benne.st`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/M_MAIN/PRG_04_Treuils_Benne.st) | **Visibilité IHM** : Permettre au grutier de lire l'écart exact entre câbles.<br>**Action** : Ajout de la variable `DeltaPosition_M : REAL;` ($\text{CablePosM2} - \text{CablePosM1}$) calculée en continu dans `FB_Bucket` et publiée vers la supervision IHM. |
| **5** | **Augmentation du Timeout Mouvement Benne** | [`GVL_PERSISTENT.st`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/GVL_PERSISTENT.st)<br>[`FB_Bucket.st`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st) | **Fiabilisation MES** : La course de fermeture sur site fait 15 m (vitesse lente = plus de 30s).<br>**Action** : Passage de `CfgTimeoutDuration` de 30s à **60s** par défaut pour éviter tout arrêt intempestif en vitesse lente. |
| **6** | **Revue Technique Indépendante (Expert Safety)** | Sous-agent dédié (Subagent Pro) | **Audit Indépendant** : Mandatement d'un agent de sécurité pour éprouver les modifications.<br>**Résultat** : Validation du déterminisme (pas de race conditions), confirmation de l'isolation stricte du mode `SEMI_AUTO`, validation de l'ergonomie. |
| **7** | **Mise à niveau de `GVL_Troubleshooting`** | [`ST_ChainBucket.st`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/J_SUPERVISION/_TYPES/1_TREUILS_BENNE/ST_ChainBucket.st)<br>[`FB_TroubleshootingView.st`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/K_DEPANNAGE/FB_TroubleshootingView.st) | **Diagnostic Dépannage** : Centralisation de tous les faits benne dans une structure unique.<br>**Action** : Ajout des index `Idx109_BucketTooOpen`, `Idx110_BucketTooClosed`, `Idx111_BucketIsIntermediate`, `Idx112_DeltaPosition_M` dans `GVL_Troubleshooting.BenneOuvertureFermeture`. |
| **8** | **Diagnostic Complet du Joystick dans Troubleshooting** | [`ST_JoystickChecklist.st`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/J_SUPERVISION/_TYPES/4_JOYSTICK_ACQUISITION/ST_JoystickChecklist.st)<br>[`FB_TroubleshootingView.st`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/K_DEPANNAGE/FB_TroubleshootingView.st)<br>[`PRG_07_Supervision.st`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/M_MAIN/PRG_07_Supervision.st) | **Traçabilité Prise en Main** : Visualiser l'état de l'homme-mort et des axes en un coup d'œil.<br>**Action** : Câblage de `DeadmanArmed`, `DeflectionX_Pct`, `DeflectionY_Pct`, `DirectionX`, `DirectionY` et `SelJoystickWinch` dans `GVL_Troubleshooting.Joystick`. |
| **9** | **Création des Bypass RETAIN Unitaires** | [`GVL_BypassRetain.st`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/L_SIMULATION/GVL_BypassRetain.st)<br>[`ST_BypassCommun.st`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/J_SUPERVISION/_TYPES/7_COMMUN_CONFIG/ST_BypassCommun.st)<br>[`PRG_07_Supervision.st`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/M_MAIN/PRG_07_Supervision.st) | **Facilité de Test** : Rendre les bypass de sécurités accessibles directement en variable Watch persistante.<br>**Action** : Ajout de `BypassCommunGlobal`, `BypassLimitLegal`, `BypassTopLimitSwitch`, `BypassTopLimitSoftware`, `BypassCableLimitSwitch`, `BypassSlackCable` synchronisés avec `GVL_IHM.Commun.Bypass`. |
| **10** | **Implémentation du Master Switch `SimulationBypassActive`** | [`GVL_BypassRetain.st`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/L_SIMULATION/GVL_BypassRetain.st)<br>[`PRG_07_Supervision.st`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/M_MAIN/PRG_07_Supervision.st) | **Automatisation des Essais** : Permettre d'armer/désarmer les bypass de test en une commande.<br>**Action** :<br>• Front Montant (`TRUE`) ➔ Active instantanément `LimitLegal`, `TopLimitSoftware`, `TopLimitSwitch`.<br>• Front Descendant (`FALSE`) ➔ Désactive immédiatement ces bypass pour restaurer les sécurités physiques nominales. |
| **11** | **Génération & Validation Bundle PLCopenXML** | [`CODE_XML/CODE_Bundle.xml`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE_XML/CODE_Bundle.xml) | **CI / CD** : Synchronisation continue du livrable CODESYS.<br>**Action** : Régénération du bundle XML et validation de l'intégralité des gates (`run_all_gates.py` : PASS 18/18, 492 tests unitaires OK). |
| **12** | **Versionnement & Déploiement Git** | Dépôt distant GitHub | **Traçabilité** : Commit et push sur la branche active `claude/quirky-goldberg-rvawr7`. |

---

## 🔒 Garanties de Sécurité & Conformité

1. **Non-régression Machine Réelle** : Aucune chaîne matérielle de sécurité (AU, coupure puissance, SafeStop) n'a été modifiée ou affaiblie.
2. **Herméticité Semi-Auto** : Les fonctions de forçage, homing dynamique et bypass restent strictement restreintes aux modes de maintenance (`MAINT_N1` et `MAINT_N2`).
3. **Traçabilité Complète** : Tout changement de structure a été reporté dans le modèle de données PLCopenXML et vérifié par l'outil de liaison `G200_check_linkage.py`.
