# 📋 Fiche de Passation & Clôture de Session — 2026-10-29

> **Document de transfert pour le prochain agent / orchestrateur reprenant le projet.**  
> Rédigé suite à la validation terrain et clôture de la tâche **T421** sur le banc CODESYS.

---

## 📌 État Git & Environnement de Session

* **Branche active** : `work/base-machine-simu`
* **Dernier commit validé** : `dc278fa8` (`feat(simu): validation T421 fidelite dynamique treuils M1/M2 et derive benne`)
* **État working tree** : 100% propre (`git status` vide, aucun scratch non indexé, cache `.tmp` nettoyé).
* **Bundle complet PLCopenXML** : [`CODE_XML/CODE_Bundle.xml`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE_XML/CODE_Bundle.xml) (frais et synchronisé).
* **Diff bundle** : [`CODE_XML/CODE_DiffBundle.xml`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE_XML/CODE_DiffBundle.xml) (contient `FB_SimBench`, `FB_Sim_Encoder`, `GVL_Simulation`, `PRG_02_Acquisition`).
* **Contrôle de liaison bloquant G200** : **PASS (0 erreur, 2 167 instances vérifiées)**.

---

## ✅ Récapitulatif des Travaux Validés (Tâche T421)

La tâche **T421** est officiellement **clôturée et passée en `✅ Terminé`** dans [`DOC/WFLOW/TASKS.yaml`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/DOC/WFLOW/TASKS.yaml).

### 1. Décélération & Glissement Inertiel Treuils M1 / M2
* **Problème initial** : Roulis fixe et symétrique hérité (1.30 m) irréaliste et dangereux en montée.
* **Solution appliquée (`FB_Sim_Encoder.st`)** : Modélisation continue d'une décélération signée calée sur les mesures réelles terrain (trace `Suivi_86`) :
  * Montée pleine vitesse : arrêt en $\approx \mathbf{+0.50\,m}$ (`CoastDecelUp_Mps2 := 1.20 m/s²`).
  * Descente pleine vitesse : arrêt en $\approx \mathbf{-1.20\,m}$ (`CoastDecelDown_Mps2 := 0.93 m/s²`).
  * Jog court / petite vitesse : glissement résiduel $<\mathbf{0.05\,m}$.

### 2. Nettoyage Configuration & Préservation NVRAM
* **Suppression de `SimWinchCoast_M`** dans `FB_SimBench.st`, `GVL_Simulation.st` et `PRG_02_Acquisition.st`.
* **Mémoire rémanente intacte** : `GVL_PERSISTENT` n'a **JAMAIS** été touché (alignement strict des offsets mémoire NVRAM préservé).
* **Ajout de `SimBucketSpeedFactor`** : Variable volatile (non rémanente) dans `GVL_Simulation` (défaut `2.0`), modifiable à la volée dans CODESYS pour accélérer les tests d'ouverture/fermeture benne seule.

### 3. Dérive de Plongée Conjointe 100% Physique (M1/M2)
* **Déconnexion de la logique applicative** : Suppression de `WinchBothDescentIntent` (pontage erroné avec `PRG_03`). La simulation ne dépend d'aucun mode logiciel.
* **Condition physique pure** : Active dès que `M1_RelayRev AND M2_RelayRev` sont collés (valable en MANU, en AUTO, aux boutons et au joystick).
* **Comportement calé sur trace 36** :
  * M1 est entraîné par le poids de la benne sous l'eau.
  * M2 descend avec un retard mesuré de 3% (`0.97 \times V_{M1}`) dû aux frottements des réducteurs.
  * L'écart $(M_2 - M_1)$ augmente proportionnellement à la profondeur ($\approx +0.60\,\text{m}$ à 20 m, $\approx +1.50\,\text{m}$ à 50 m), représentant un pincement doux de 6 à 10% de la benne.
  * **Élimination totale du faux défaut `[BENNE] ErrorID:02`** (l'écart reste strictement positif et très loin du seuil d'alarme bas de $-1.0\,\text{m}$).

### 4. Tests Utilisateur en Direct (CODESYS)
* Essais validés par l'exploitant en mode **MANUEL** et en cycle **AUTOMATIQUE**.
* Montée, descente, fermeture au fond et raccordement P1 fonctionnels sans blocage.

---

## 🧭 Instructions pour la Prochaine Session

Pour tout agent reprenant ce dépôt :
1. **Briefing automatique** : Appliquer la séquence de démarrage standard d'[`AGENTS.md`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/AGENTS.md).
2. **Ne pas retoucher à la dynamique de simulation treuils T421** : Le comportement physique actuel est validé et calé sur les traces du chantier réel.
3. **Consulter [`DOC/WFLOW/TASKS.yaml`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/DOC/WFLOW/TASKS.yaml)** : Choisir la prochaine tâche prioritaire non verrouillée (ou cadrer un nouveau besoin sous criticité C1..C4 avec contrat de tâche).
4. **Toujours générer le diff bundle + bundle complet + contrôle bloquant G200** avant toute proposition de livraison à l'utilisateur.
