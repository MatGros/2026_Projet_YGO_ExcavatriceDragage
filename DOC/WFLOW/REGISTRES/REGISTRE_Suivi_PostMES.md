# 🧾 Registre de Suivi Post-Mise en Service — Livraison 10 Août (v1.0)

> 🎯 **Rôle** : Historique factuel et journal de bord de la phase post-mise en service en vue de la **livraison finale du 10 août 2026**. Suivi des ajustements terrain, réserves, ré-essais et levées de réserves.
> 📌 **Source des actions à réaliser** : `DOC/WFLOW/TASKS.yaml` §3 reste le registre maître des reliquats (`Txx`).
> 🚫 Ce registre trace les constats, réglages et preuves de validation pour la recette finale de la livraison du 10 août.

---

## 1. ⚡ Pense-bête Client YGO (Règles & Dédouanement MES)

### 💡 Engagements Archi & Simplification
- 🛡️ **Simu isolée** : 100% confinée dans `PRG_00_Inputs` en entrée (0 bidouille dans le code).
- 📊 **Table Visu pas-à-pas** : Suivi chronologique direct via `PRG_11_Troubleshooting`.
- ⏱️ **Rampes & Tampons** : Temporisations `FB_SpeedStep`/`FB_Ramp` sur contacteurs de vitesse.
- 🕹️ **Doctrine MAINT_N1 ➔ Auto** :
  - **Priorité Manuel** : TOUTES les actions unitaires qualifiées en MAINT_N1 (joystick) : M3 (déposition), descente, fond, fermeture, montée, charge.
  - **Auto = Surcouche** : Le cycle auto n'est qu'un séquençage sécurisé du manuel éprouvé.

### 🔍 Dédouanement PLC vs Matériel (Glissement / Arrêt M1 vs M2)
- 📈 **Étape 1 — Trace CODESYS 10ms** : Enregistrer `RelayFwd/Rev`, `Contactor1..4`, `BrakeCmd`, `BrakeFeedback`, `CablePosM`, `MeasuredSpeedMps`.
- ✅ **Verdict PLC** : Si tops commande & freins M1/M2 identiques ➔ **PLC dédouané**.
- 🛠️ **Étape 2 — Investigation Matérielle** : Si PLC OK ➔ vérifier relais, contacteurs puissance, usure/pression/réglage freins.

---

## 2. Règles d'utilisation

| Élément | Où le tracer |
|---|---|
| Test/Essai prévu et verdict Pass/Fail | Checklist métier ou `PLAN_TASK` §4 Recette |
| Ajustement terrain, réserve client, mesure post-MES, observation | Ce registre (`PMS-XXX`) |
| Action correctrice ou modification code/paramètre à faire | Ligne `Txx` dans `PLAN_TASK` §3, référencée ici |
| Évolution logicielle/documentaire majeure | `VERSION_HISTORY.md` |

**Une entrée = un fait vérifiable, un essai ou une levée de réserve.** Ne jamais supprimer une entrée : ajouter une correction ou un complément daté si nécessaire.

### Statuts

| Statut | Sens |
|---|---|
| 🟢 Validé / Levée | Réglage/correctif validé avec preuve conforme pour la livraison |
| 🟡 En observation | Fonctionne sur le terrain, stabilité à valider sur cycle long |
| 🟠 Action / Réserve ouverte | Réserve ou réglage restant à traiter avant le 10 août (`Txx`) |
| 🔴 Bloquant Livraison | Empêche la recette ou la livraison du 10 août |
| ⚪ En attente d'essai | Prévu pour la campagne d'essais finaux |

---

## 3. Planning Jalons jusqu'au 10 Août 2026

| Jalon | Date cible | Contenu & Objectif |
|---|---|---|
| 🚩 **Jalon 1** | 2026-07-31 | Clôture des correctifs logiciels et freeze du code v1.0-RC |
| 🚩 **Jalon 2** | 2026-08-04 | Campagne d'essais d'endurance & validation du cycle automatique complet |
| 🚩 **Jalon 3** | 2026-08-07 | Levée finale de toutes les réserves ouvertes (Txx) & recettes signées |
| 🚀 **LIVRAISON** | **2026-08-10** | **Livraison finale et transfert d'exploitation** |

---

## 4. Entrées de suivi Post-Mise en Service

### PMS-003 — Doctrine Codeur Multitours, Homing au Boot & Séquence Dégagement Top
| Champ | Valeur |
|---|---|
| Date | 2026-07-28 |
| Lieu / environnement | Documentation AF_Partie-10 / Préparation implémentation code |
| Périmètre | Codeurs M1/M2, Homing, Persistance, Sécurité Redémarrage, Seuil N2 |
| Statut | 🟠 Action ouverte (À traiter dans le code selon spec AF_Partie-10 v1.10) |
| Constat | Validation des règles de sécurité et de la cinématique de homing :<br>1. **Conservation Référence Redémarrage** : Codeur absolu multitours (8192 pts x 4096 tours). Si les freins ont tenu la position au boot ($\Delta \le \text{Seuil}$), `Homed=TRUE` est conservé (pas de ré-homing forcé).<br>2. **Détection Glissement/Démontage** : En cas de mouvement hors tension supérieur au seuil, `HomingSuspect=TRUE` masque `Homed` à `FALSE` et bloque `SEMI_AUTO`.<br>3. **Seuil Paramétrable IHM (Droits N2)** : Le seuil de tolérance `RestartCoherenceTolerancePts` est rémanent (`PERSISTENT`) et modifiable sur l'IHM uniquement par un utilisateur N2 avec mot de passe (adaptation météo/saisons/mécanique).<br>4. **Séquence Homing Dégagement Top** : Montée PV ➔ Dépassement capteur haut ➔ Arrêt ➔ Redescente PV ➔ Prise du top (Preset 8.0 m) au **front montant du RETOUR capteur** (garantit cote 8.0m légèrement plus basse que butée mécanique). |
| Décision / Action | Implémenter et vérifier ces 4 points dans le programme CODESYS (FB_Encoder_Homing / FB_Encoder_Safety) selon la spec AF_Partie-10. |
| Références | `AF_Partie-10_Fonction_Encoder_Homing_v1.10.md` §1/§3.7/§7bis |

### PMS-002 — Mémo / Pense-bête des points d'alignement Client YGO

| Champ | Valeur |
|---|---|
| Date | 2026-07-28 |
| Lieu / environnement | Échange direct client YGO & préparation mise en service |
| Périmètre | Isolation simu, rampes/tampons vitesse, dédouanement arrêt M1 vs M2 |
| Statut | 🟠 Action ouverte (Suivi T78/T79) |
| Constat | Validation du principe de simplification : isolation nette de la simulation en entrée (`PRG_00_Inputs`), visibilité par tables pas-à-pas (`PRG_11`), et démarche explicite pour dédouaner l'automate sur les écarts de freinage/glissement M1/M2. |
| Décision / Action | Exécuter la configuration de Trace CODESYS (`T79`) pour comparer au ms près les sorties relais/freins de M1 et M2 afin de séparer la cause logique d'un biais mécanique. |
| Références | `T78`, `T79`, `AF_Partie-14_Fonction_Troubleshooting_v1.0.md` |

### PMS-001 — Initialisation du Registre Post-MES pour Livraison 10 Août

| Champ | Valeur |
|---|---|
| Date | 2026-07-28 |
| Lieu / environnement | Documentation & préparation phase finale |
| Périmètre | Organisation du suivi des réserves et ajustements pré-livraison |
| Statut | 🟢 Validé |
| Constat | Bascule de la phase de première mise en service vers la phase d'affinement, levée de réserves et qualification finale pour la livraison du 10 août 2026. |
| Décision / Action | Consigner tous les essais, réglages fins et validations d'actions `Txx` d'ici le 10 août dans ce registre. |
| Références | `REGISTRE_Suivi_MiseEnService_v1.0.md`, `PLAN_TASK_v1.0.md` |

---

## 5. Modèle d'entrée à dupliquer

```md
### PMS-XXX — Titre court (Ex: Levée réserve M1 / Réglage rampe M3)

| Champ | Valeur |
|---|---|
| Date / heure | YYYY-MM-DD HH:MM |
| Lieu / environnement | Simulation / Banc / Carrière terrain |
| Intervenants | Initiales (ex: ZED, Client YGO, Dragueur) |
| Version CODE/DOC | Commit / Version export CODESYS |
| Périmètre | Treuils M1/M2, Translation M3, Benne, Cycle Automatique, Supervision IHM |
| Statut | 🟢 / 🟡 / 🟠 / 🔴 / ⚪ |
| Contexte & Réglage | Description de l'ajustement ou du test réalisé |
| Mesures / Preuves | Relevés de mesures, captures d'écran, logs Trace CODESYS, photos |
| Constat | Résultat factuel observé sur la machine |
| Verdict & Décision | Réserve levée / Ajustement validé / Essai complémentaire nécessaire |
| Action associée | Réf `Txx` dans PLAN_TASK_v1.0.md |
```

---

## 6. Procédure de Clôture pour Livraison

Pour valider définitivement un point avant la livraison du 10 août :

1. L'action `Txx` dans `PLAN_TASK_v1.0.md` doit être testée sur le terrain ou banc.
2. Renseigner l'entrée `PMS-XXX` correspondante avec la preuve de validation (mesure, log trace ou constat signé).
3. Passer le statut à 🟢 **Validé / Levée** et indiquer la date de résolution.
4. Mettre à jour [DOC/VERSION_HISTORY.md](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/DOC/VERSION_HISTORY.md) pour la version de livraison.
