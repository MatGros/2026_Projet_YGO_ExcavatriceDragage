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

---

## 3. 🔍 Événements, Comportements & Points de Vigilance à Suivre

| # | Sujet | Constat ou Risque identifié | Surveillance / Mesures à prévoir en essai | Priorité |
|---|---|---|---|---|
| 1 | Remplacement capteur Top M1/M2 | Capteur shunté électriquement par le client (provisoire). | Exiger le remplacement physique par un capteur neuf certifié sécurité avant clôture définitive de la réception. | P0 |
| 2 | Réglages RETAIN / NVRAM | Après import en ligne, certains paramètres IHM restent en cache mémoire. | Faire un reset RETAIN à froid au prochain arrêt machine pour vérifier que les défauts code (ex. 10%, 20Hz) s'appliquent bien. | P1 |
| 3 | Chute de tension réseau électrique | Réseau définitif : légère chute de tension sous forte charge. | Dynamique et inertie stables ; confirmer en dragage intensif continu. | P2 |

---

## 4. 🚀 Plan de Travail Préparatoire

1. **Inscrire T394 et T395 dans [`TASKS.yaml`](../TASKS.yaml)** avec leurs critères d'acceptation et niveaux de criticité (C3/C4).
2. **Rédiger les contrats de tâche** :
   - `TASK_CONTRACT_T394_P1_REBOOT_ET_PERMIS_M3.yaml`
   - `TASK_CONTRACT_T395_MAINT_N2_FREINS_ET_SECOURS.yaml`
3. **Auditer le code de `PRG_06_Outputs.st`** (condition `PowerContactorEngaged_DI` sur les freins) et **`PRG_03_Modes_Cycle.st`** (`WinchDescentAuth_M3` et `TglEnableWinchDescentLock_M3`).
