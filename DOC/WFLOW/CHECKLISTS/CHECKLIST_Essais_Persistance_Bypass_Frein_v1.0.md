# 🧪 CHECKLIST — Essais persistance, bypass & freins (v1.0)

> 🎯 **Cahier d'essais à exécuter** — matrice de 11 défaillances + 3 protocoles détaillés.
> 📅 Extrait le 2026-07-27 de `RAPPORT_Audit_Persistance_Bypass_Frein_v1.0.md` (§4), archivé depuis.
> 📌 Support de **T92** (qualification bypass + homing 0 m) et **T72** (interlock frein).
> 📝 Consigner chaque exécution dans `../REGISTRE_Suivi_MiseEnService_v1.0.md`.

---

## ⚠️ À savoir avant d'exécuter

Les colonnes « Résultat observé » et « Statut » ci-dessous datent du **2026-07-24** et décrivent le
code **d'avant les correctifs**. Depuis :

| Test | Évolution |
|---|---|
| **TEST-05** | ✅ **Corrigé** — `BypassEdge : R_TRIG` dans `FB_Brake` (l. 57, 79) : l'activation du bypass réarme le bloc. **À rejouer pour confirmer** |
| **TEST-06** | 🟠 **Partiellement corrigé** — `FB_Winch:268` conditionne les relais à `BrakeSafetyOk = NOT Brake.Error`. ⚠️ **Le critère d'acceptation du scénario 2 exige `BrakeCmd = TRUE`** (ordre effectif de desserrage), ce qui n'est **pas** ce qui a été implémenté : un frein sain mais non commandé laisse passer le mouvement. 👉 **Reste ouvert : T72** |
| **TEST-04** | Comportement RETAIN confirmé au lot L3 : un download remet les bypass à `FALSE`. ⚠️ Si un bypass masquait un blocage, celui-ci **réapparaît au premier boot** |
| Autres | Statuts à revalider : le code a beaucoup évolué (frontière `HwIn`, renommage E/S, `PRG_11`) |

---

## 🧪 4. BILAN DE L'AUDIT CODE & ESSAIS DE VALIDATION (TOUTES DÉFAILLANCES)

Ce chapitre résume les **constats expérimentaux réalisés sur le code actuel**, les **tests de simulation effectués** pour chaque type de défaillance et la matrice de recettes.

### 📊 Table Récapitulative Complète des Essais sur TOUTES les Défaillances

| N° Test | Domaine | Type de Défaillance Testée | Scénario d'Essai / Simulation | Résultat Observé sur Code Actuel | Statut Validation Code Actuel |
| :---: | :--- | :--- | :--- | :--- | :---: |
| **TEST-01** | Supervision | Persistance Boot | Effacement mémoire RETAIN IHM au boot | Les blocs `FB_CfgPersistBridge_*` restaurent correctement la config depuis `GVL_PERSISTENT`. Flag `ConfigRestoredFromPersistent` OK. | 🟢 **VALIDÉ (Conforme)** |
| **TEST-02** | Supervision | Sauvegarde Config | Modification d'une rampe ou consigne profondeur IHM | Transmis de `GVL_IHM` vers `GVL_PERSISTENT` sans écrasement par des zéros. | 🟢 **VALIDÉ (Conforme)** |
| **TEST-03** | Rémanence | Bypass RETAIN | Activation d'un bypass global puis simulation Reset Warm | Le bypass est conservé dans `GVL_BypassRetain` et réinjecté. | 🟢 **VALIDÉ (Conforme)** |
| **TEST-04** | Rémanence | Download Code | Activation bypass puis Rechargement du projet (Download) | Le bypass `RETAIN` repasse à `FALSE` (comportement RETAIN normal). | 🟡 **AVERTISSEMENT (Attendu)** |
| **TEST-05** | Frein | Acquittement Frein sous Bypass | Activation du Bypass Frein APRÈS l'apparition du défaut `StuckClosed` | **Le défaut reste verrouillé à TRUE.** L'activation seule du bypass ne réarme pas le bloc sans appui Reset manuel. | 🔴 **ÉCHEC (Non Conforme)** |
| **TEST-06** | Frein | Sécurité Anti-Échauffement | Commande mouvement treuil avec Frein bloqué collé (`BrakeCmd = FALSE`) | **`FB_Winch` émet `RelayFwd/RelayRev = TRUE`.** Le treuil force contre le frein bloqué. | 🔴 **ÉCHEC CRITIQUE (Danger)** |
| **TEST-07** | Codeurs | Position Aberrante / Homing | Saut de position câble > 99m (`CablePosM = 4096m`) | `FB_Encoder_Safety` gèle la valeur (`CablePosMSafe`). Mode `SEMI_AUTO` refusé. Sur `BypassGlobal`, la position fausse passe. | 🟢 **VALIDÉ (Sécurité OK)** / 🟡 Bypass Risqué |
| **TEST-08** | Synchro | Écart Critique M1/M2 | Simulation d'un écart de câble M1 ↔ M2 > 2.0 m | `FB_WinchSync` déclenche `Error = TRUE` et coupe le mouvement. En `BypassSyncGlobal`, l'arrêt est totalement ignoré. | 🟢 **VALIDÉ (Sécurité OK)** / 🟡 Bypass Risqué |
| **TEST-09** | Reseau | Perte Bus CAN / EtherCAT | Déconnexion esclave Joystick ou Codeur COD1 | `FB_Diag_CanOpen` / `FB_Diag_Ethercat` lèvent `Error = TRUE`. Blocage mouvement OK. `BypassNetworkGlobal` force Online. | 🟢 **VALIDÉ (Conforme)** |
| **TEST-10** | Translation | Incohérence Mot Capteurs M3 | Combinaison capteurs position invalide (ex: Trémie + P2 simultanés) | `FB_Safety_Translation` déclenche `PowerCutOff`. Sur `BypassSensorIncoherent`, le `PowerCutOff` s'efface. | 🟢 **VALIDÉ (Conforme)** |
| **TEST-11** | Urgence (AU) | Échec Auto-Test Redondance AU | Simulation canal A reste collé lors de l'auto-test d'armement | `RedundancyTestFailed` = TRUE, séquence interrompue, `PowerCutOff` maintenu. Aucun bypass possible. | 🟢 **VALIDÉ (Sécurité Absolue)** |

---

### 🧪 Détail des Scénarios d'Essais et Protocoles de Qualification Future

#### 🧪 Scénario 1 : Déblocage de l'Erreur Frein sur Activation du Bypass (TEST-05)
* **Contexte** : Une anomalie de retour contacteur survient (`ContactorFeedback` absent ou incohérent). `FB_Brake.Error` passe à `TRUE`.
* **Procédure d'Essai** :
  1. Générer le défaut de frein ➔ Constater `FB_Brake.Error = TRUE` et `BrakeCmd = FALSE`.
  2. Passer le Bypass `BypassContactorCheck` à `TRUE`.
  3. Appliquer un front sur `Reset` (`FaultMachineReset_IHM`).
* **Résultat Attendu (Après Correctif)** : `FB_Brake.Error` doit retomber immédiatement à `FALSE` et libérer le bloc pour la maintenance.

#### 🧪 Scénario 2 : Verrouillage Interlock Frein ↔ Relais Moteur (TEST-06)
* **Contexte** : Vérification de la sécurité anti-échauffement / anti-casse mécanique.
* **Procédure d'Essai** :
  1. Simuler un frein bloqué collé (`FB_Brake.Error = TRUE` ou `BrakeCmd = FALSE`).
  2. Pousser le joystick pour demander un mouvement treuil (`CommandedDirection = 1`).
* **Résultat Attendu (Après Correctif)** : Les relais `RelayFwd` et `RelayRev` doivent **rester impérativement à `FALSE`** tant que `BrakeCmd` n'est pas effectif (`TRUE`) ou valablement outrepassé par un bypass spécifique de mouvement maintenance.

#### 🧪 Scénario 3 : Auto-Test et Verrouillage Réarmement Boucle d'Urgence (TEST-11)
* **Contexte** : Contrôle de la redondance des contacteurs d'Arrêt d'Urgence (`FB_Safety_EmergencyManagementLogic`).
* **Procédure d'Essai** :
  1. Forcer le retour `EmergencyChainClosed = TRUE` alors que l'étape 1 coupe le canal A (`ForceTestA = TRUE`).
  2. Vérifier le basculement de `RedundancyTestFailed` à `TRUE` et l'arrêt de la séquence d'armement.
* **Résultat Attendu** : La commande d'armement `EmergencyArming_Cmd` ne doit jamais être émise (Étape 5 non atteinte). La puissance amont reste coupée. Un appui `Reset` explicite est requis après correction physique.

---

---

