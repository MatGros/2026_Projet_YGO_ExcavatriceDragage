# 📋 Registre de Préparation — Prochaine Mise en Service (26/09/2026)

> **Date d'ouverture :** 2026-09-26  
> **Branche de départ :** `main` (Jalon `MES_FIN_20260923`, base saine et synchronisée)  
> **Objet :** Recueil et suivi des nouvelles demandes, anomalies résiduelles et événements à préparer jusqu'à la prochaine séance d'essais sur site.

---

## 1. 🏛️ Acquis & Socle Technique Validé (Rappel)

Le programme en production sur l'automate intègre les validations suivantes :
- **Treuils M1/M2** : Inversion matérielle logicielle DI `M1_ContactorsReleased_DI` ↔ `M2_ContactorsReleased_DI` active (`PRG_02_Acquisition.st:145-153`). Bascule AX10 ➔ AX10b ➔ AX11 fluide en 21 ms sans trou de synchro.
- **Benne & Vidage trémie** : Suppression formelle du saut vers AX10 (`FB_CycleSemiAuto.st:1568-1576`). Modulation sur place AX15D disponible.
- **Translation M3** : Verrouillage `ArrivalLock` corrigé pour ne plus bloquer sur les cibles intermédiaires P1 (`FB_Translation.st`), anti-rebond FDC actif (`PRG_05_Translation.st`).
- **Réseau Électrique** : Alimentation réseau définitive validée (légère chute de tension sous charge sans incidence sur la dynamique ni l'inertie des entraînements ; réglages conservés).

---

## 2. 📝 Nouvelles Demandes & Évolutions Demandées

| # | Date | Domaine / Fonction | Description du besoin / Modification souhaitée | Criticité | Tâche associée | Statut |
|---|---|---|---|---|---|---|
| 1 | 2026-09-26 |  |  |  |  | À qualifier |

*(Section à compléter avec vos nouvelles demandes).*

---

## 3. 🔍 Événements, Comportements & Points de Vigilance à Suivre

| # | Sujet | Constat ou Risque identifié | Surveillance / Mesures à prévoir en essai | Priorité |
|---|---|---|---|---|
| 1 | Réglages RETAIN / NVRAM | Après import en ligne, certains paramètres IHM restent en cache mémoire. | Faire un reset RETAIN à froid au prochain arrêt machine pour vérifier que les défauts code (ex. 10%, 20Hz) s'appliquent bien. | P1 |
| 2 |  |  |  |  |

*(Section ouverte pour consigner les événements observés ou signalés d'ici la prochaine MES).*

---

## 4. 🚀 Plan d'Action & Prérequis avant Prochaine Séance

1. Cadrer chaque nouveau point sous forme de tâche contractuelle (ID, criticité C1..C4).
2. Vérifier mécaniquement les impacts logiciels via harness CI + `G200_check_linkage.py`.
3. Générer le diff bundle dédié pour chargement optimisé sur site.
