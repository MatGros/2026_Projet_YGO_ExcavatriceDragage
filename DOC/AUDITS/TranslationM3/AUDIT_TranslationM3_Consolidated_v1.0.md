# 📋 AUDIT CONSOLIDÉ — Fonctionnalité Translation M3 (Excavatrice de Dragage)

> **Sources fusionnées** :
> - **Audit Codex** : Analyse technique focalisée Translation M3 (architecture, safety, IHM, cycle, tests, guardrails)
> - **Audit Gemini (antigravity)** : Revue transversale machine + conformité normative + validation externe
> **Date** : 2026-07-21 | **Version** : 1.0 | **Statut** : Read-only, aucune modif CODE/

---

## 🏁 1. VERDICT GLOBAL

| Dimension | Niveau | Commentaire |
|-----------|--------|-------------|
| **Architecture code** | 🟢 **Solide** | Respecte `Enable > SafeStop > StartStop`, composition FB_Brake, instance unique Auto/Manu |
| **Sécurité fonctionnelle M3** | 🟢 **Opérationnelle** | Méca A/B actifs, PowerCutOff partagé, homme-mort boutons IHM corrigé v1.9 |
| **IHM/Supervision** | 🟢 **Complète** | Mapping 14 champs, diagnostiques décodés, DeadmanArmed requis partout |
| **Intégration Cycle** | 🟢 **Intégrée** | Étape 8 TRANSLATION_MOVE, sens auto, arrêt exact capteur, PV ciblé Trémie |
| **Tests/Validation** | 🟡 **Cadré** | Framework Partie 14 §7 planifié (M1→M6), 13 TC-TRANS définis |
| **Conformité guardrails** | ⚠️ **1 écart** | `FB_Ramp` custom au lieu de `RAMP_REAL` (Util) — violation §0 |
| **Risques machine/chantier** | 🟡 **Identifiés** | Seuils Méca A/B non étalonnés, STO absent, AC600 à valider sur site |
| **Conformité normative** | ⚠️ **Réserves** | PL-d Cat.3 non prouvé par code seul — dossier sécurité externe requis |

**Verdict consolidé** : 🟢 **APPROBATION OPÉRATIONNELLE POUR COMMISSIONING SIMULATION**
> Prêt pour chargement simulateur. Actions critiques (#1, #2, #3, #6, #7) avant 1ʳᵉ mise en mouvement site réel.

---

## 🏗️ 2. ARCHITECTURE AUTOMATISME — Pipeline Translation M3

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ PRG_07_TranslationControl (MainTask 10ms, Pos 7)                           │
├─────────────────────────────────────────────────────────────────────────────┤
│ 1. instPositionDecoder (5 capteurs → LimitSwitchFwd/Rev + Incoherent)      │
│ 2. Arbitrage selon Mode:                                                    │
│    • SEMI_AUTO  → Cycle (CmdTranslationM3_*) + Joystick X + DeadmanArmed   │
│    • MAINT_N1/2 → HMI (ReqFwd/ReqRev + FreqSetpointHz) + DeadmanArmed 🆕   │
│    • MANUEL     → Joystick X (AxisCmdX)                                     │
│ 3. Instanciation FB_Translation (MÊME instance Auto + Manu)                │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ FB_Translation (FB de mouvement — Partie 3 §1bis)                          │
├─────────────────────────────────────────────────────────────────────────────┤
│ Enable / Reset / EmergencyStopOk / Mode                                     │
│ StartStop / SafeStop (depuis FB_Safety_Translation)                        │
│ Direction (-1/0/+1) / SpeedRefPct (0-100%)                                 │
│ PositionSensorTarget / SlowdownSensor(PV) / LimitSwitchFwd/Rev             │
│ DriveStatusWord / DriveActualFreqHz (EtherCAT 4ms → lu 10ms)               │
│ BrakeFeedback / BypassContactorCheck                                        │
│                                                                             │
│ ⚙️ CORE: RampTargetPct selon (SafeStop > StartStop) + ApproachSpeed +     │
│     ArrivalLock (arrêt exact capteur) + DirectionInterlock (200ms)         │
│ 🔀 SORTIE ETHERCAT: DriveControlWord (0/1/2/7) + DriveFreqRefHz           │
│ 🛑 FREIN: instBrake (FB_Brake composé, réutilisé COMMUN)                  │
│ 🧾 ErrorId bitfield: bit0=Frein, bit3=Variateur, bit6=Fdc, bit7=Capteurs  │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ PRG_03_Safety.instSafetyTranslationM3 (MainTask 10ms, Pos 3)               │
├─────────────────────────────────────────────────────────────────────────────┤
│ Enable := TRUE (inconditionnel v1.7+, plus de bypass Manu)                 │
│ Surveillances: Joystick CAN, EtherCAT Variateur, PhaseRotation,           │
│                 BrakeThermal, Méca A, Méca B, Fdc extrêmes, Capteurs 5 bits│
│ Sorties: SafeStop (rampe rapide 100%/s) + PowerCutOff (coupure amont AU)   │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.1 Points forts (Consensus Codex + Gemini)

| ✅ Point fort | Source | Détail |
|--------------|--------|--------|
| Instance unique FB_Translation | Codex | Élimine ancien bypass `M3_CommandWord` direct (v1.7+) |
| Safety inconditionnelle | Codex | `Enable := TRUE` pour FB_Safety_Translation — Méca A/B/PowerCutOff actifs en MAINT |
| Homme-mort obligatoire partout | Codex | v1.9: `DeadmanArmed` requis **même pour boutons IHM** — corrige faille préexistante |
| Décodage 5 capteurs robuste | **Both** | T33 confirmé : 6 mots valides monotones, `Incoherent` → Safety bit7 |
| PV = ralentissement ciblé Trémie | Codex | `SlowdownSensor` ne ralentit **que** Direction=1 (vers Trémie) |
| Frein composé FB_Brake | Codex | Réutilisé tel quel (COMMUN) — délais physiques M3 paramétrés |
| Safety M3 sans contacteur ligne | **Gemini T12** | Architecture `PowerCutOff` amont validée — pas de contacteur dédié M3 |

### 2.2 Risques / Points d'attention architecture

| ⚠️ Risque | Source | Analyse | Recommandation |
|-----------|--------|---------|----------------|
| **FB_Ramp custom vs RAMP_REAL (Util)** | **Codex** | Violation guardrail §0 « NE PAS réinventer » — `FB_Ramp` ~80 lignes recalcul rampe | **Migrer vers `RAMP_REAL`** (Action #1) |
| Tâche EtherCAT 4ms → MainTask 10ms | Codex | Gigue ≤ 1 cycle. Méca A seuil 0.5Hz = 10ms acceptable | Vérifier `FB_CycleTime` = 10ms défaut |
| Pas de mesure courant M3 (AC600) | Codex | Pas détection surcharge/blocage mécanique | Méca A (freq > 0.5Hz) compense partiellement — documenter limite |
| PowerCutOff partagé 3 domaines | Codex | Winch M1+M2+Translation = 1 coupure amont | Conception voulue (Partie 3 §7bis). Si M3 déclenche → M1/M2 coupés aussi |
| Enable Safety Translation = TRUE inconditionnel | Codex | Pas d'`InhibitM3` dans FB_Modes (différence M1/M2) | Documenter : M3 safety toujours active |
| DirectionInterlockDelay 200ms | Codex | Suffisant pour variateur AC600 ? | Mesurer temps arrêt réel variateur sur site |

---

## 🛡️ 3. SÉCURITÉ FONCTIONNELLE & MACHINE SPÉCIALE

### 3.1 Chaîne de sécurité complète M3

```
🔴 BOUTON AU (PHYSIQUE) → Coupure contacteur puissance BRUTALE → Freins collent (manque courant)
       │
       ▼
🔧 RÉARMEMENT AU (PHYSIQUE) → EmergencyStopOk = TRUE
       │
       ▼
🧠 FB_Safety_Translation (Enable=TRUE inconditionnel)
       │
       ├── Perte Joystick CAN      (bit0) ──► SafeStop + PowerCutOff
       ├── Perte EtherCAT Variateur (bit1) ──► SafeStop + PowerCutOff
       ├── Mauvaise rotation phases (bit2) ──► SafeStop + PowerCutOff
       ├── Surchauffe frein commun (bit3) ──► PowerCutOff (pas SafeStop)
       ├── Méca B: Incohérence arrêt (bit4) ──► SafeStop + PowerCutOff
       │    (Direction=0 & BrakeCmd=FALSE) & (DriveStatusWord.0 OR BrakeFb) > 3s
       ├── Méca A: Mouvement non commandé (bit5) ──► SafeStop + PowerCutOff
       │    (Direction=0 & BrakeCmd=FALSE) & |DriveActualFreqHz| > 0.5Hz > 1s
       ├── Fdc extrêmes atteints (bit6) ──► SafeStop + PowerCutOff
       └── Incohérence 5 capteurs (bit7) ──► SafeStop + PowerCutOff
       │
       ▼
🛑 SafeStop ──► FB_Translation : Rampe décélération RAPIDE (100%/s)
🧨 PowerCutOff ──► PRG_10_Outputs : Coupure contacteurs amont (redondant A/B)
```

### 3.2 Analyse risques Machine de Dragage (Codex + Gemini compléments)

| Risque machine | Couverture | Résidu / Action | Source |
|----------------|------------|-----------------|--------|
| **Dérive pont** (vent, courant, câbles) | Méca A (0.5Hz) + Méca B + Fdc | ✅ Bien couvert. **Seuil 0.5Hz non étalonné** | Codex |
| **Collision butée mécanique** | `LimitSwitchFwd/Rev` → coupure immédiate + Safety bit6 | ✅ Coupure sans rampe. PowerCutOff redondant | Codex |
| **Capteur position collé/HS** | `PositionDecoder.Incoherent` (bit7) → Safety | ✅ 6/32 combinaisons valides. Détection capteur bloqué | **Both** |
| **Ralentissement insuffisant Trémie** | `SlowdownSensor` (PV) → `ApproachSpeedPct` 20% | ⚠️ PV **uniquement** sens Trémie. Valider position physique PV | Codex |
| **Arrêt pas sur capteur cible** | `ArrivalLock` : verrouille sens tant que `TargetReached` | ✅ Opérateur doit inverser pour se dégager | Codex |
| **Inversion sens brutale** | `DirectionInterlockDelay` 200ms + vitesse < 0.1% | ⚠️ 200ms suffisant AC600 ? Mesurer sur site | Codex |
| **Variateur défaut non détecté** | `DriveStatusWord.4` (bit3) + Safety bit1 (EtherCAT) | ✅ Double détection | Codex |
| **Frein ne colle/relâche pas** | `FB_Brake.ContactorCheck` StuckOpen/StuckClosed → bit0 | ✅ Double vérif + timeout 1s | Codex |
| **STO variateur non câblé** | **Documenté ⚠️** Partie 11 v1.5 | ⚠️ **RISQUE ACCEPTÉ DOCUMENTÉ** — Mesurer temps glissement | Codex |
| **Homme-mort contourné** | v1.9: `DeadmanArmed` requis même boutons IHM | ✅ Corrigé. Avant v1.9, boutons permettaient mouvement sans homme-mort | Codex |
| **Thermique moteur M3** | **Absent** (seul frein surveillé) | ℹ️ AC600 protocole T4 constructeur — clarification requise | **Gemini** |
| **Watchdog IHM↔Automate absent** | Pas de heartbeat Ethernet | 🔴 **Risque réel** : mouvement si Ethernet coupé | **Gemini** |

### 3.3 Conformité Normative (Lead Gemini — Réserves exactes)

> **Le code PLC seul ne démontre PAS la conformité PL-d Cat.3 / ISO 13849-1.**

| Exigence | Statut Code | Preuve / Réserve |
|----------|-------------|------------------|
| Arrêt urgence Cat 0 | ✅ | Bouton AU physique → contacteur puissance |
| Réarmement manuel distinct | ✅ | Bouton physique AU + `EmergencyStopOk` → pas redémarrage auto |
| SafeStop = Cat 1 (rampe) | ✅ | `SafeStop` → décélération rapide PLC, `Enable` maintenu |
| PowerCutOff = dernier rempart | ✅ | Contacteur général amont, commande redondante A/B |
| Surveillance contacteurs | ✅ | `ST_ContactorCheck` frein + `FB_Safety_EmergencyManagement` auto-test A/B |
| Diagnostics périodiques | ✅ | Auto-test à chaque réarmement AU (TC-02) |
| Verrouillage 5s échec | ✅ | `EmergencyArmingLockoutActive` (TC-03) |
| **STO variateur** | ❌ **Non câblé** | Documenté ⚠️ — Compensé par coupure amont + frein |
| **PL-d Cat.3 démontré** | ❌ **Externe** | Nécessite : Appréciation risques (ISO 12100), calculs PL (MTTFd, DCavg, CCF), validation électrique (IEC 60204-1), essais physique (ISO 13849-2) |

**Réserves normatives exactes (Gemini §6)** — À intégrer dans **dossier sécurité machine** :
1. Appréciation des risques initiale (EN ISO 12100)
2. Calculs quantitatifs PL/SIL (EN ISO 13849-1 / IEC 62061)
3. Validation matérielle électrique (EN IEC 60204-1)
4. Essais validation physique sécurité (EN ISO 13849-2)

---

## 🖥️ 4. INTERFACE IHM / SUPERVISION

### 4.1 Structure `ST_TranslationHMI` (GVL_IHM.TranslationM3) — Mapping vérifié

| Catégorie | Champs clés | Statut | Source |
|-----------|-------------|--------|--------|
| **Commandes opérateur** | `SelectedTargetNum` (1-4), `ReqFwd`, `ReqRev`, `FreqSetpointHz`, `JoystickSelect` | ✅ Complet | Codex |
| **État FB_Translation** | `FBState`, `Ready/Busy/Done/Error/ErrorId`, `BrakeCmd`, `PositionSensorTarget` | ✅ Standard | Codex |
| **Variateur (décodé)** | `DriveCommReady` (SW.7), `DrivePowerReady` (SW.0), `DriveActualFreqHz`, `DriveControlWord`, `DriveFreqRefHz` | ✅ **Pas bit-masking IHM** | Codex |
| **Capteurs position** | `PositionTremie/PV/P2/P1/Maintenance`, `SensorsWord`, `SensorWordIncoherent`, `LimitSwitchFwd/Rev` | ✅ Diagnostic câblage | **Both** |
| **Sécurité** | `SafetyError/ErrorId`, 8 booléens (Joystick, EtherCAT, Phase, Thermal, MécaA/B, Fdc, Capteurs), `SafetySafeStop`, `SafetyPowerCutOff` | ✅ Granulaire | Codex |
| **Simulation/Test** | `TestSensorsWordActive`, `TestAtTremie`, `TestBrakeStuckOpen`, `TestPhantomFreq` | ✅ Banc seulement | Codex |

### 4.2 Points ergonomie / opérateur

| Point | Avis | Source |
|-------|------|--------|
| Cible Maintenance (4) bloquée hors MAINT_N2 | ✅ `MaintenanceM3TargetEnable` (FB_Modes) | Codex |
| FreqSetpointHz = référence pleine échelle | ✅ Choix assumé v1.7 (fréquence continue vs paliers Winch) | Codex |
| JoystickSelect bascule boutons/joystick | ✅ Même `FreqSetpointHz` référence | Codex |
| BrakeCmd lecture seule | ✅ Doctrine Winch : déblocage par mouvement | Codex |
| DeadmanArmed requis même boutons | ✅ v1.9 — correction critique | Codex |
| **Watchdog IHM↔Automate ABSENT** | 🔴 **Ajouter Heartbeat GVL_IHM ↔ PLC** pour sécuriser mouvements si Ethernet coupé | **Gemini** |

---

## 🔄 5. INTÉGRATION CYCLE DE DRAGAGE (Partie 4)

### 5.1 Rôle Translation dans le cycle

```
Étape 8 : TRANSLATION_MOVE
├── Cible : `CmdTranslationM3_Target` (depuis instCycle)
├── StartStop : `CmdTranslationM3_Start` AND `DeadmanArmed` AND `AxisCmdX.StartStop`
├── Vitesse : MIN(40%, |AxisCmdX.SpeedRef|) — plafond sécurité cycle
├── Sens : Auto selon cible (Trémie=Fwd / P2,P1,Maintenance=Rev)
└── Condition sortie : Position atteinte (capteur cible) → RETURN_WORK_POS
```

### 5.2 Points validés

| Sujet | Statut |
|-------|--------|
| Homme-mort en cycle | ✅ `DeadmanArmed` AND `AxisCmdX.StartStop` — relâchement = pause, reprise = même étape |
| Vitesse limitée cycle | ✅ `MIN(40%, joystick)` — empêche vitesse excessive semi-auto |
| Sens auto selon cible | ✅ Logique simple : Trémie=Avant, autres=Arrière |
| Arrêt exact capteur | ✅ `ArrivalLock` dans FB_Translation — verrouille tant que capteur actif même sens |
| Pas de target PV | ✅ `SelectedTargetNum` jamais = PV. PV = ralentissement seul |

---

## 🧪 6. TESTS, VALIDATION & SIMULATION

### 6.1 Framework tests (Partie 14 §7) — État migration

| Étape | Statut | Commentaire |
|-------|--------|-------------|
| M1 Socle générique | 🟡 Planifié | Enums, structs, FB_TestSequencer, FB_TestCheck, FB_TestStimulus |
| M2 GVL & IHM data | 🟡 Planifié | Restructuration `GVL_PLC_Tests` + `ST_PlcTestsHMI` |
| M3 Suite Safety (TC-01/02/03) | 🟡 Planifié | Inclut correctif lockout + 5 checks supplémentaires |
| M4 Orchestrateur | 🟡 Planifié | Machine d'états suites indépendantes |
| M5 Page IHM banc | 🟡 Planifié | Progression, rapport, historique |
| M6 Docs | ✅ Cette version | Cadrage figé |

### 6.2 Cas de test Translation prioritaires (TC-TRANS-01 à 13)

| TC-ID | Type | Description | Critère de passage |
|-------|------|-------------|-------------------|
| TC-TRANS-01 | PERF | Latence commande → variateur | `DriveControlWord` mis à jour < 1 cycle MainTask |
| TC-TRANS-02 | MECA | Arrêt exact capteur cible | `TargetReached` → `SpeedRamp.Current`=0 < 200ms, `ArrivalLock` actif |
| TC-TRANS-03 | MECA | Ralentissement PV (Dir=1) | `SlowdownSensor=TRUE` + `Dir=1` → `SpeedRef` ≤ `ApproachSpeedPct` |
| TC-TRANS-04 | MECA | Pas de ralentissement PV (Dir=-1) | `SlowdownSensor=TRUE` + `Dir=-1` → `SpeedRef` inchangé |
| TC-TRANS-05 | SAFETY | Méca A : Fréquence fantôme | `Dir=0`, `BrakeCmd=FALSE`, `|Freq|>0.5Hz` > 1s → `SafeStop`+`PowerCutOff` |
| TC-TRANS-06 | SAFETY | Méca B : Incohérence arrêt | `Dir=0`, `BrakeCmd=FALSE`, (`SW.0` OR `BrakeFb`) > 3s → `SafeStop`+`PowerCutOff` |
| TC-TRANS-07 | SAFETY | Fdc extrême franchi | `LimitSwitchFwd` + `Dir=1` → `DriveControlWord=0` immédiat + `PowerCutOff` |
| TC-TRANS-08 | SAFETY | Incohérence 5 capteurs | `SensorsWord` hors 6 mots valides → `SafetyErrorSensorIncoherent` + `SafeStop`+`PowerCutOff` |
| TC-TRANS-09 | SAFETY | Perte EtherCAT variateur | `DriveOnline/Operational=FALSE` → `SafeStop`+`PowerCutOff` |
| TC-TRANS-10 | SAFETY | Perte Joystick | `JoystickOnline/Operational=FALSE` → `SafeStop`+`PowerCutOff` |
| TC-TRANS-11 | MODE | MAINT_N1/N2 : boutons + Deadman | `ReqFwd` + `DeadmanArmed=FALSE` → `StartStop=FALSE` |
| TC-TRANS-12 | MODE | MAINT_N1/N2 : joystick + Deadman | `AxisCmdX.StartStop` + `DeadmanArmed` → mouvement |
| TC-TRANS-13 | SIMU | Simulation trajet temps parcours | `TargetNum` changé → `ElapsedS=0`, progression si `RelayFwd/Rev` |

### 6.3 Simulation `FB_Sim_Translation` — Analyse

| ✅ Bien fait | ⚠️ À améliorer |
|-------------|----------------|
| Temps parcours configurable (8s défaut) | Pas calibration terrain — valeur par défaut |
| PV activé `PVLeadTimeS` (2s) avant Trémie | `PVLeadTimeS` fixe — devrait être RETAIN |
| Mot capteurs **toujours valide** (monotone) | ✅ Conception voulue — évite `Incoherent` en simu |
| Changement cible → reset `ElapsedS` | ✅ |
| Arrêt relais → pause progression (pas reset) | ✅ Comportement réaliste |
| `PosMaintenance := FALSE` pour mot 00000 | ✅ Respecte codage |

---

## ⚙️ 7. PARAMÈTRES RETAIN / MISE EN SERVICE — CHECKLIST

| Paramètre | Défaut | Unité | Criticité | Action |
|-----------|--------|-------|-----------|--------|
| `RampAccelRate` | 20.0 | %/s | 🔴 Haute | Étalonner selon inertie pont + charge |
| `RampDecelNormalRate` | 40.0 | %/s | 🔴 Haute | Confort + mécanique |
| `RampDecelFastRate` | 100.0 | %/s | 🔴 Haute | SafeStop — assez rapide sans à-coup |
| `DirectionInterlockDelay` | 200ms | ms | 🟡 Moyenne | **Mesurer temps arrêt réel variateur** |
| `ApproachSpeedPct` | 20.0 | % | 🔴 Haute | Valider vitesse approche Trémie sur site |
| `DriveFreqScaleMaxHz` | 60.0 | Hz | 🔴 Haute | **Max variateur** (nominal 30Hz @ 50%) |
| `CaptorDebounce` | 100ms | ms | 🟡 Moyenne | Selon capteur position |
| `BrakeDelayContactClose` | 100ms | ms | 🔴 Haute | Temps contacteur frein M3 |
| `BrakeDelayMagnetise` | 300ms | ms | 🔴 Haute | Magnétisation moteur M3 |
| `BrakeDelayMotorDecel` | 500ms | ms | 🔴 Haute | Décélération avant frein |
| `BrakeFeedbackTimeout` | 1s | ms | 🟡 Moyenne | Cohérence commande/retour |
| `PostRampTimeout` (Safety) | 3s | s | 🔴 Haute | Méca B — confirmation arrêt |
| `TonMecaA.PT` (Safety) | 1s | s | 🔴 Haute | Méca A — détection dérive |

> **Note critique** : `DriveFreqScaleMaxHz := 60.0` mais fonctionnement nominal 30Hz @ 50% consigne. Vérifier config variateur AC600.

---

## 📋 8. CONFORMITÉ GUARDRAILS (Codex — Checklist complète)

| Règle (AGENTS.md / Partie 3) | Statut | Preuve |
|------------------------------|--------|--------|
| PascalCase, pas hongrois | ✅ | `FB_Translation`, `DriveActualFreqHz`, `SlowdownSensor` |
| FB mouvement = StartStop + SafeStop | ✅ | `FB_Translation` les a (Partie 3 §1bis) |
| Précédence Enable > SafeStop > StartStop | ✅ | Ligne 124-133 `FB_Translation.st` |
| Reset = front obligatoire | ✅ | `ResetEdge := R_TRIG(Reset)` ligne 84 |
| Pas redémarrage auto après défaut | ✅ | `Error` force sorties sûres, `State` → READY |
| Pas de `CoupeEnable` | ✅ | Term absent, vocabulaire abandonné |
| Pas de `FB_Watchdog` applicatif | ✅ | Surveillance tâche = fonction système CODESYS (200ms) |
| `SafeStop` par métier (pas global) | ✅ | `FB_Safety_Translation` dédié |
| `PowerCutOff` contacteur amont | ✅ | `FB_Safety_EmergencyManagement` dans PRG_10 |
| Composition > Héritage | ✅ | `FB_Brake`, `FB_Ramp`, `FB_CycleTime` instanciés en `VAR` |
| **Lib CODESYS réutilisée (Util)** | ❌ **ÉCART** | `FB_Ramp` custom au lieu de `RAMP_REAL` — **Violation §0** |
| ErrorId bitfield ≤ 16 bits | ✅ | 8 bits utilisés (0,3,6,7) |
| State / StateAtError séparés | ✅ | `StateAtError` figé jusqu'au reset |

---

## 🎯 9. PLAN D'ACTIONS CONSOLIDÉ (PRIORISÉ)

| # | Action | Source | Priorité | Effort | Blocage |
|---|--------|--------|----------|--------|---------|
| **1** | **Migrer `FB_Ramp` → `RAMP_REAL` (Util)** dans `FB_Translation` | Codex | 🔴 **CRITIQUE** | ~2h | Guardrail §0 |
| **2** | **Étalonner seuils Méca A (0.5Hz) / Méca B (3s)** sur machine réelle | Codex | 🔴 **CRITIQUE** | 1 jour chantier | Seuils par défaut |
| **3** | **Mesurer temps glissement STO absent** (contacteur amont → frein collé) | Codex | 🔴 **CRITIQUE** | 2h essai | Risque accepté non quantifié |
| **4** | **Nettoyer `GVL_Translation_M3_Stub.st`** : supprimer orphelines mode relais (`M3_RelayFwd/Rev`, `M3Fwd_Eff/Rev_Eff`, `M3_ActiveFreqCmd`, `M3_DriveIsReal`) | **Gemini P2** | 🟡 **MOYENNE** | 30 min | Code mort |
| **5** | **Ajouter Watchdog IHM↔Automate** (Heartbeat GVL_IHM ↔ PLC) pour sécuriser mouvements si Ethernet coupé | **Gemini §4.1** | 🔴 **HAUTE** | ~4h (archi) | Risque mouvement non surveillé |
| **6** | **Bornage `TopSensorPositionM` (Homing) + étendre aux paramètres Translation** (`DriveFreqScaleMaxHz`, `ApproachSpeedPct`, etc.) | **Gemini §4.2** | 🟡 **MOYENNE** | 1h | Valeurs aberrantes IHM |
| **7** | **Valider AC600 sur site** : protocole EtherCAT (mots commande/état), thermique variateur, communication réelle | **Gemini §5.3 + T4/T19** | 🔴 **BLOCAGE MES** | 1-2 jours | Prérequis mise en service |
| **8** | **Documenter réserves normatives** (Gemini §6) dans dossier sécurité : PL-d Cat.3 non prouvé par code seul | **Gemini §6** | 🔴 **DOSSIER RÉGLEMENTAIRE** | Selon BE | Livrable client |
| **9** | Paramétrer `PVLeadTimeS` / `TravelTimeS` en RETAIN (simulation) | Codex | 🟢 Basse | 30 min | Calibration simu |
| **10** | Exécuter suite tests TC-TRANS-01→13 dans framework Partie 14 M3+ | Codex | 🟢 Basse | 1 semaine | Validation formelle |

---

## 🔌 10. BLOCAGES EXTERNES LÉGITIMES (Gemini — Pour commissioning site)

| # | Blocage | Description | Responsable |
|---|---------|-------------|-------------|
| **BE-1** | **Inertie décélération réelle (T9)** | Mesure physique enroulement résiduel en charge lors SafeStop (400%/s) + temps réponse freins | Mise en service |
| **BE-2** | **Calibrage couplage/hystérésis paliers (T45/T48)** | Affinement seuils/temporisations enclenchement résistances rotoriques en charge | Mise en service |
| **BE-3** | **Protocole & thermique AC600 (T4/T19)** | Validation mots commande/état constructeur + raccordement thermique variateur | **BE-3 = Action #7** |
| **BE-4** | **Réarmement chaîne sécurité physique (T11/T15)** | Vérification électrique + mesure tension auto-test redondance canaux A/B | Mise en service |

---

## 📚 11. TRAÇABILITÉ DOCUMENTAIRE

| Document | Version | Rôle |
|----------|---------|------|
| `AF_Partie-11_Fonction_Translation_v1.9.md` | v1.9 | Spec métier référence |
| `AF_Partie-03_Template_FB_Commun_v1.3.md` | v1.3 | Contrat FB / Guardrails |
| `AF_Partie-02_Architecture_Programme_v2.12.md` | v2.12 | Architecture, tâches, safety |
| `AF_Partie-04_Cycle_Sequenceur_v1.4.md` | v1.4 | Cycle, étape TRANSLATION_MOVE |
| `AF_Partie-05_Modes_Maintenance_v1.6.md` | v1.6 | Modes, MAINT_N1/N2, limite légale |
| `AF_Partie-07_Interface_IHM_v1.5.md` | v1.5 | ST_TranslationHMI, mapping |
| `AF_Partie-14_PLC_Tests_Validation_v1.2.md` | v1.2 | Framework tests §7 (M1-M6) |
| `AF_Partie-13_Fonction_Simulation_v1.2.md` | v1.2 | FB_Sim_Translation |
| `DOC/IHM_MANU_Journal_Modifications.md` | — | Historique migration v1.7→v1.9 |
| `DOC/PLAN_TASK_v1.0.md` | v1.0 | Suivi tâches (T12, T33, T40, T43) |

---

## ✅ 12. CONCLUSION

La fonctionnalité **Translation M3** est **architecturalement saine**, **documentée à jour** et **conforme aux guardrails** (sauf 1 écart : `FB_Ramp`).

**Feu vert pour commissioning simulation** sous réserve des **3 actions critiques** (#1, #2, #3) avant 1ʳᵉ mise en mouvement site réel.

Le **blocage majeur mise en service** reste la **validation AC600 sur site (Action #7 / BE-3)** — sans cela, pas de communication variateur fiable.

Le **dossier normatif PL-d Cat.3 (Action #8)** est un livrable **bureau d'études / client**, non couvert par le code PLC seul.

---

*Rapport consolidé généré par fusion Audit Codex (technique Translation M3) + Audit Gemini/antigravity (transverse machine + normatif). Aucune modification CODE/ effectuée.*