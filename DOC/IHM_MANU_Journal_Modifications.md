# 🛠️ IHM_MANU — Journal des Modifications Provisoires
**Mise en service urgence d'excavatrice de dragage (Secours)**

---

## 📌 BANDEAU D'INTRODUCTION

La fonctionnalité **IHM_MANU** est un **dispositif DÉROGATOIRE et PROVISOIRE** ajouté pour les besoins de mise en service terrain (2026-07-09). Elle permet un **pilotage direct des sorties physiques** (relais M1/M2, contacteurs vitesse K1-K4, variateur M3 EtherCAT) en **contournant complètement le programme fonctionnel normal** (PRG_06_WinchControl, PRG_07_ChariotControl, PRG_03_Safety), avec un **minimum de sécurités logicielles**.

**Responsabilité du nettoyage futur :** Ce document enumère CHAQUE modification pour que, une fois la mise en service achevée, il soit simple et exhaustif de supprimer/rétablir le code normal.

⚠️ **EN MODE MANU, SEULE LA CHAÎNE AU PHYSIQUE (arrêt d'urgence matériel indépendante) PROTÈGE.**

---

## 📋 FICHIERS MODIFIÉS — INVENTAIRE DÉTAILLÉ

### 1. **CODE/SUPERVISION/ST_IHM_MANU.st** — Nouveau type créé (complet, lignes 1–52)

| Élément | Description |
|---------|-------------|
| **Type** | `ST_IHM_MANU` |
| **Portée** | Type de données (définition seule, pas d'instance) |
| **Raison** | Agrégation de tous les signaux IHM pour pilotage manuel direct |

**Champs du struct :**
- `ModeDisable : BOOL` — **logique inversée VOLONTAIRE** : FALSE (défaut, non-RETAIN) = mode Manu ACTIF sans action opérateur. Doit passer explicitement à TRUE pour revenir au normal. ⚠️ **Ceci est le point le plus dangereux et le premier à corriger au nettoyage.**
- `PositionM_M1/M2 : REAL` — lecture brute position codeur (affichage diagnostic)
- `M1/M2_RelayFwd/Rev : BOOL` — commandes montée/descente par axe, interlock Fwd/Rev
- `HomingEncoder_M1/M2 : BOOL` — front = référencement codeur (OR avec CmdHome existant, **aucune dérogation sécurité**)
- `M1_M2_RelayFwd/Rev : BOOL` — commandes couplées (mouvement simultané M1+M2)
- `M1_M2_Contactor1-4 : BOOL` — contacteurs vitesse K1-K4 communs (un seul actif à la fois, interlock fail-safe)
- `M3_RelayFwd/Rev : BOOL` — commandes chariot (sens via variateur EtherCAT)
- `M3_FreqSetpoint/Actual : REAL` — consigne/retour fréquence variateur [Hz]
- `M3_CommandWordMonitor/StatusWordMonitor : WORD` — diagnostics mot commande/état envoyés au variateur

**À supprimer au nettoyage :** Fichier entier.

---

### 2. **CODE/SUPERVISION/GVL_IHM.st** — Déclaration instance (ligne 17)

```st
IHM_MANU : ST_IHM_MANU; (* 🛠️ Variables d'échange IHM provisoires pour pilotage manuel direct (Secours) *)
```

**À modifier au nettoyage :** Supprimer cette ligne de la section VAR_GLOBAL RETAIN.

---

### 3. **CODE/MAIN/PRG_10_Outputs.st** — Trois blocs balisés Début/Fin IHM_MANU

#### 🔶 **Bloc 1 : Déclarations VAR** (lignes 73–90)

```st
// ─────────  Début modification IHM_MANU  ─────────
    // 🆕 REX 2026-07-09 — Mode IHM_MANU (mise en service urgence, override direct sorties)
    ManuActive            : BOOL; // NOT GVL_IHM.IHM_MANU.ModeDisable (logique inversée, voir ST_IHM_MANU)
    // Détection de fronts montants pour priorité temporelle
    TrigM1Fwd             : BOOL;
    TrigM1Rev             : BOOL;
    TrigM2Fwd             : BOOL;
    TrigM2Rev             : BOOL;
    TrigCoupledFwd        : BOOL;
    TrigCoupledRev        : BOOL;
    TrigM3Fwd             : BOOL;
    TrigM3Rev             : BOOL;
    // États au scan précédent
    LastM1Fwd             : BOOL;
    LastM1Rev             : BOOL;
    LastM2Fwd             : BOOL;
    LastM2Rev             : BOOL;
    LastCoupledFwd        : BOOL;
    LastCoupledRev        : BOOL;
    LastM3Fwd             : BOOL;
    LastM3Rev             : BOOL;
    M1Fwd_Eff             : BOOL;
    M1Rev_Eff             : BOOL;
    M2Fwd_Eff             : BOOL;
    M2Rev_Eff             : BOOL;
    K1_Eff                : BOOL; // Contacteurs vitesse communs M1+M2 — activables indépendamment
    K2_Eff                : BOOL;
    K3_Eff                : BOOL;
    K4_Eff                : BOOL;
    M3Fwd_Eff             : BOOL;
    M3Rev_Eff             : BOOL; // Demande interlockée — voir §M3 EtherCAT : ne pilote PAS le variateur tant que non confirmé
    instM3RelayFwdLed     : FB_Output; // 💡 LED témoin mise en service (M3_RelayFwd_DQ) — PAS de mouvement réel
    instM3RelayRevLed     : FB_Output; // 💡 LED témoin mise en service (M3_RelayRev_DQ) — PAS de mouvement réel
// ─────────  Fin modification IHM_MANU  ─────────
```

**Rôle :** Variables de travail, états précédents (Last*) et détection de fronts (Trig*) pour les interlocks temporels actifs, et instances FB de sortie pour LEDs de mise en service M3.

**À supprimer au nettoyage :** Bloc entier (23 lignes de déclarations + 2 FB_Output).

---

#### 🔶 **Bloc 2 : Calcul logique et override VAR_INPUT** (lignes 93–183)

**Position dans le code :** En tête du corps d'implémentation (avant les appels FB_Output existants), pour que l'override prenne effet immédiatement dans le même scan.

**Logique :**
1. Calcul `ManuActive := NOT GVL_IHM.IHM_MANU.ModeDisable` (logique inversée)
2. Affichage position codeurs M1/M2 (diagnostic)
3. **IF ManuActive THEN :**
   - Interlock Fwd/Rev par axe (M1/M2 seuls ET simultanés) : `Xfwd_Eff := (Cmd_Fwd OR Cmd_M1M2_Fwd) AND NOT (Cmd_Rev OR Cmd_M1M2_Rev)`
   - Interlock K1-K4 : un seul contacteur actif à la fois
   - Recalcul des VAR_INPUT existants (M1RelayFwd, M1RelayRev, M1BrakeCmd, M1/M2SpeedContactor1-4, ChariotBrakeCmd)
4. **Chariot M3 — mot de commande EtherCAT direct :**
   - Si `ManuActive AND M3Fwd_Eff` → `M3_CommandWord := 1` + fréquence
   - Si `ManuActive AND M3Rev_Eff` → `M3_CommandWord := 2` + fréquence
   - Sinon → `M3_CommandWord := 0` (arrêt, couvre aussi le mode normal)
   - Copie vars de diagnostic (CommandWordMonitor, StatusWordMonitor, FreqActual)
   - 💡 Pilotage LEDs M3 (M3_RelayFwd_DQ, M3_RelayRev_DQ) — **témoins mise en service uniquement, ne pilotent PAS le variateur**

**À supprimer au nettoyage :** Bloc entier (91 lignes + commentaires d'en-tête).

---

#### 🔶 **Bloc 3 : Override PowerCutOff_A_RQ / PowerCutOff_B_RQ** (lignes 244–252)

```st
IF ManuActive THEN
    PowerCutOff_A_RQ := NOT ForceTestA;
    PowerCutOff_B_RQ := NOT ForceTestB;
    // ─────────  Fin modification IHM_MANU  ─────────
ELSE
    PowerCutOff_A_RQ := NOT (PRG_03_Safety... ) AND NOT ForceTestA AND NOT GVL_IHM.Modes.CmdEmergencyCutOff;
    PowerCutOff_B_RQ := NOT (PRG_03_Safety... ) AND NOT ForceTestB AND NOT GVL_IHM.Modes.CmdEmergencyCutOff;
END_IF;
```

**Rôle :** **Imbriqué dans le IF/ELSE existant**, en mode Manu force la puissance à `TRUE` en ignorant les défauts Méca A/B/C ou le bouton CmdEmergencyCutOff, tout en laissant passer les signaux d'auto-test `ForceTestA` et `ForceTestB` pour permettre le réarmement de puissance.

**À modifier au nettoyage :** Retirer le bloc IF ManuActive/ELSE, replacer directement la logique normale dans le code.

**Ligne critique :** 249–251 (les 3 lignes du bloc THEN).

---

### 4. **CODE/MAIN/PRG_02_Encoders.st** — Override direct et bypass sécurité homing

#### 🔶 **Bloc 1 : M1 et M2 - PresetRequest/Value direct (Bypass de instHoming)**
Si `ManuActive` est activé, les commandes `HomingEncoder_M1/M2` pilotent directement le bloc `instEncoderAbsM1/M2` :
*   `PresetRequest` = `instHomingM1.PresetRequest OR (PRG_10_Outputs.ManuActive AND GVL_IHM.IHM_MANU.HomingEncoder_M1)`
*   `PresetValue` = `16777216` (milieu de plage)

**Rôle :** Permet d'envoyer l'écriture dans les mots physiques sans aucune condition de mode (MAINT_N1/N2 non requis) ni de sécurité (contacteur sens/frein non vérifiés).

#### 🔶 **Bloc 2 : Enregistrement manuel de calibration et reset bouton HMI**
Code ajouté tout à la fin du POU `PRG_02_Encoders` pour détecter le succès (`PresetAck`) ou le timeout (`PresetNak`) afin d'écrire directement l'offset de position dans la mémoire persistante pour faire `12.5` mètres (Offset = `16726016`), puis de désactiver le bouton HMI.

**À modifier au nettoyage :** 
*   Rétablir les entrées `PresetRequest := instHomingM1.PresetRequest` et `PresetValue := instHomingM1.PresetValue` sur `instEncoderAbsM1` et `instEncoderAbsM2`.
*   Retirer le bloc de code conditionnel `IF PRG_10_Outputs.ManuActive THEN ... END_IF` tout à la fin du fichier.

---

### 5. **CODE/ENCODERS/FB_Encoder_Abs.st** — Temporisation visuelle de l'écriture

#### 🔶 **Bloc 1 : Maintien visuel à 0.5s dans le step 1**
Un timer `PresetTimerVisual : TON` a été ajouté au bloc d'acquisition. Une fois le codeur recalé, le bit `PresetTriggerCmd := 2` est maintenu pendant **0.5 seconde** avant d'être repassé à `0` (step 0).

**Rôle :** Permet à l'œil humain et aux visualisations CODESYS de voir passer l'impulsion et l'écriture de valeur brute sur le bus en simulation.

**À modifier au nettoyage :** Rétablir la transition immédiate sans `PresetTimerVisual` dans le Step 1, et supprimer la déclaration du timer dans `VAR`.

---

## 🧹 CHECKLIST NETTOYAGE COMPLET

### Phase 1 : Vérifications préalables
- [ ] Confirmer que la mise en service terrain est terminée et stable
- [ ] Vérifier que le programme fonctionnel normal (PRG_06/07/03, Safety) est **opérationnel et testé**
- [ ] S'assurer qu'aucun opérateur ne dépend plus du mode IHM_MANU

### Phase 2 : Suppression de code
- [ ] **ST_IHM_MANU.st** : Supprimer le fichier entier
- [ ] **GVL_IHM.st** (ligne 17) : Supprimer la déclaration `IHM_MANU : ST_IHM_MANU;`
- [ ] **PRG_10_Outputs.st** :
  - [ ] Supprimer les déclarations VAR (lignes 73–88, bloc Début/Fin)
  - [ ] Supprimer le bloc override principal (lignes 93–183, bloc Début/Fin)
  - [ ] **Bloc PowerCutOff_A_RQ/B_RQ (lignes 351–355)** : Retirer le IF ManuActive, recollage du ELSE à la place
    ```st
    // ❌ AVANT :
    IF ManuActive THEN
        PowerCutOff_A_RQ := NOT ForceTestA;
        PowerCutOff_B_RQ := NOT ForceTestB;
    ELSE
        PowerCutOff_A_RQ := NOT (...) AND ...
        ...
    END_IF;
    
    // ✅ APRÈS :
    PowerCutOff_A_RQ := NOT (...) AND ...
    PowerCutOff_B_RQ := NOT (...) AND ...
    ```
- [ ] **PRG_02_Encoders.st** :
  - [ ] Restaurer `PresetRequest := instHomingM1.PresetRequest` et `PresetValue := instHomingM1.PresetValue` sur les appels de `instEncoderAbsM1` et `instEncoderAbsM2` (lignes 97-98 et 146-147).
  - [ ] Retirer le bit de forçage dérogatoire sur l'entrée `Home` des blocs `instHomingM1` et `instHomingM2` (lignes 113 et 162).
  - [ ] Supprimer entièrement le bloc conditionnel de fin de fichier (lignes 214-239).

### Phase 3 : Tests de validation
- [ ] Compiler le projet CODESYS sans erreur
- [ ] Télécharger sur l'automate
- [ ] Vérifier que le joystick commande correctement M1/M2/M3 (pas d'override resté actif)
- [ ] Confirmer que les sécurités métier (FB_Safety_Winch/Chariot, limites, synchro) sont à nouveau actives
- [ ] Tester l'auto-test redondance AU et le réarmement (EmergencyCutOff doit refonctionner)

### Phase 4 : Commit git
- [ ] Créer un commit unique avec tous les changements de suppression IHM_MANU
- [ ] Message suggéré : `fix(cleanup): remove provisional IHM_MANU bypass after field commissioning`
- [ ] Supprimer ce document de traçabilité (IHM_MANU_Journal_Modifications.md) **OU** le ranger en Archives/

---

## ⚠️ POINTS NON VÉRIFIÉS / À CONFIRMER SUR BANC

### 1. **M3_CommandWord (Registre 0x3101 Variateur AC600)**

**Recette fournisseur (non vérifiée au moment du codage 2026-07-09) :**
- `0x0000` = Arrêt
- `0x0001` = Marche avant
- `0x0002` = Marche arrière

**Actions requises :**
- Avant usage prolongé, forcer le mot de commande depuis CODESYS (instance PRG_10_Outputs.M3_CommandWord) et observer le comportement du variateur à moteur à vide
- **Risque identifié :** Les valeurs réelles du registre 0x3101 côté carte EtherCAT pourraient différer de la recette fournisseur initiale ou avoir des significations alternatives (ex. bits de flags). Corriger immédiatement si comportement anormal (moteur tourne à l'inverse, ignore la fréquence, etc.)
- **Remédiation :** Mettre à jour les lignes 165/168 (M3_CommandWord := 1/2) si la recette change

### 2. **Absence de vérification mode opérateur en IHM_MANU**

Actuellement, il n'y a **pas de vérification du mode machine** (Mode N1/N2/N3/etc.) avant autorisation du mouvement. Tout mouvement est autorisé en mode Manu, quel que soit l'état du mode, sauf les conditions internes de homing (qui restent inchangées).

**Implication :** Un opérateur pourrait forcer un mouvement en mode ARRÊT, par exemple. À vérifier terrain et voir si une protection supplémentaire est souhaitable.

### 3. **Fréquence M3 — pas de bounds-check**

`M3_FreqSetpoint` n'a pas de limite min/max applicative. L'écriture dans M3_SetpointFrequencyHz se fait à brut (×100) sans vérifier les limites du variateur (ex. 0–60 Hz nominalement).

**À confirmer :** Les limites du variateur AC600 doivent-elles être respectées en mode Manu ou peut-on libérer complètement ?

### 4. **Timeout DE SÉCURITÉ sur PowerCutOff_A/B_RQ = TRUE FIXE**

En mode Manu, PowerCutOff_A/B_RQ sont maintenues TRUE indéfiniment **sans surveillance de redondance** (ForceTestA/B n'est jamais déclenché). Si une ligne de sécurité tombe en panne et la détection de redondance est perdue, il n'y a **aucun timeout** pour le signaler.

**Implication :** La machine peut tourner longtemps sans savoir que la redondance A OU B est cassée. À investiguer si un mécanisme de supervision est souhaitable (ex. pulse périodique de test même en Manu).

---

## 📊 TABLEAU RÉCAPITULATIF DES RISQUES

| Risque | Gravité | Présence | Mitigation |
|--------|---------|----------|-----------|
| **ModeDisable inversé** — mode Manu ACTIF par défaut | 🔴 CRITIQUE | Oui (conception volontaire) | Vérifier chaque démarrage ; supprimer au nettoyage |
| **PowerCutOff_A/B_RQ = TRUE FIXE** — AU seul protège | 🔴 CRITIQUE | Oui | Seul l'AU matériel indépendant protège |
| **M3_CommandWord non vérifié sur banc** | 🟠 ÉLEVÉ | Oui | Test moteur à vide avant usage prolongé |
| **Pas de vérification mode opérateur** | 🟡 MOYEN | Oui | À confirmer terrain si souhaitable |
| **Pas de supervision redondance PowerCutOff** | 🟡 MOYEN | Oui | Envisager test périodique même en Manu |
| **Fréquence M3 sans limites** | 🟡 MOYEN | Oui | À confirmer si limites variateur doivent s'appliquer |

---

## 📚 RÉFÉRENCES DOCUMENTS

- **DOC/AF_Partie-03_Template_FB_Commun_v1.3.md** — Contrat FB (interface, précédence Enable/SafeStop/StartStop)
- **DOC/AF_Partie-09_Fonction_Winch_v1.9.md** — Winch M1/M2, safety, garde-fous Méca A–E
- **DOC/AF_Partie-11_Fonction_Chariot_v1.3.md** — Chariot M3, variateur AC600
- **DOC/AF_Partie-10_Fonction_Encoder_Homing_v1.7.md** — Homing codeurs (conditions Mode/arrêt/capteur)
- **CODE/MAIN/PRG_03_Safety.st** — Logique sécurité normales (PowerCutOff Méca A/B/C)

---

## 🔄 HISTORIQUE

| Date | Auteur | Action |
|------|--------|--------|
| **2026-07-09** | Mise en service urgence | Ajout fonctionnalité IHM_MANU provisoire (ST_IHM_MANU, blocs PR G_10/PRG_02) |
| **À définir** | Nettoyage | Suppression IHM_MANU après validation terrain |

---

**Document créé :** 2026-07-09 | **Version :** 1.0  
**État :** 🔴 PROVISOIRE — À SUPPRIMER APRÈS MISE EN SERVICE ACHEVÉE
