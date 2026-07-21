# 📋 AUDIT CONSOLIDÉ FINAL — Translation M3 (Excavatrice Dragage)

> **Fusion validée par test A/B aveugle** (Évaluateur Claude Herdr) :
> - **Base technique** : Audit Codex (rigueur architecture, safety, IHM, cycle, tests, guardrails)
> - **Couche conformité/dette** : Audit Gemini/antigravity (ISO 13849, watchdog IHM, stub mort, blocages chantier)
> **Date** : 2026-07-21 | **Version** : 2.0 | **Statut** : Read-only — Prêt pour `codesys-change`

---

## 🏁 VERDICT OPÉRATIONNEL

| Dimension | Statut | Condition suivant |
|-----------|--------|-------------------|
| **Commissioning Simulation** | 🟢 **GO** | Aucun blocage code |
| **1ʳᵉ mise en mouvement SITE** | 🟡 **CONDITIONNEL** | Actions #1, #2, #3, #7 validées |
| **Dossier réglementaire PL-d** | 🔴 **EXTERNE** | Bureau d'études / Client (Action #8) |

---

## 🎯 PLAN D'ACTIONS PRIORISÉ — Format `codesys-change`

| # | Action | Fichier(s) | Priorité | Effort | Gate de validation | Bloquant |
|---|--------|------------|----------|--------|-------------------|----------|
| **1** | **Migrer `FB_Ramp` → `RAMP_REAL` (Util)** | `CODE/TRANSLATION/FB_Translation.st` | 🔴 **P0** | 2h | Compile + même comportement rampe (test unitaire) | Guardrail §0 |
| **2** | **Étalonner seuils Méca A (0.5Hz) / Méca B (3s)** | `CODE/TRANSLATION/FB_Safety_Translation.st` (PostRampTimeout, TonMecaA.PT) | 🔴 **P0** | 1j chantier | Mesure dérive réelle + confirmation arrêt sur machine | Seuils par défaut non étalonnés |
| **3** | **Mesurer temps glissement STO absent** | — (mesure physique) | 🔴 **P0** | 2h essai | Chrono contacteur amont → frein collé < temps acceptable | Risque accepté non quantifié |
| **4** | **Nettoyer `GVL_Translation_M3_Stub.st`** (orphelines mode relais) | `CODE/TRANSLATION/GVL_Translation_M3_Stub.st` | 🟡 **P1** | 30 min | Compile + variables `M3_RelayFwd/Rev`, `M3Fwd_Eff/Rev_Eff`, `M3_ActiveFreqCmd`, `M3_DriveIsReal` supprimées | Code mort v0.4.11 |
| **5** | **Ajouter Watchdog IHM↔Automate** (Heartbeat) | `CODE/SUPERVISION/GVL_IHM.st` + `CODE/MAIN/PRG_09_Supervision.st` + `CODE/MAIN/PRG_07_TranslationControl.st` | 🔴 **P1** | ~4h | Heartbeat 500ms → `SafeStop` si perdu > 2s (test simulation) | Risque mouvement non surveillé |
| **6** | **Bornage paramètres critiques** (RETAIN min/max) | `CODE/TRANSLATION/FB_Translation.st` + `CODE/SUPERVISION/ST_TranslationHMI.st` | 🟡 **P1** | 1h | IHM rejette valeurs hors bornes (test unitaire) | Valeurs aberrantes opérateur |
| **7** | **Valider AC600 sur site** (protocole + thermique) | — (chantier) | 🔴 **BLOCAGE MES** | 1-2j | Mots commande/état conformes + thermique raccordé + communication stable | **Prérequis mise en service** |
| **8** | **Dossier normatif PL-d Cat.3** | — (BE/Client) | 🔴 **DOSSIER** | Selon BE | Appréciation risques + calculs PL + validation électrique + essais 13849-2 | Livrable client |

---

## 🔧 DÉTAIL TECHNIQUE ACTIONS P0/P1 (Pour `codesys-change`)

### **ACTION #1 — FB_Ramp → RAMP_REAL (Util)**

**Fichier** : `CODE/TRANSLATION/FB_Translation.st`
**Zone** : `VAR` → remplacer `SpeedRamp : FB_Ramp;` par `SpeedRamp : RAMP_REAL;`
**Appel** : adapter paramètres `RAMP_REAL` (IN, OUT, ACCEL_TIME, DECEL_TIME vs AccelRate/DecelRate %/s)
**Conversion** : `AccelTime_s := 100.0 / RampAccelRate` | `DecelTime_s := 100.0 / DecelRate`
**Test** : Simuler rampe 0→100% avec `RampAccelRate=20` → temps = 5s (identique actuel)

```st
// AVANT (FB_Ramp custom)
SpeedRamp(Target := RampTargetPct, AccelRate := RampAccelRate, DecelRate := DecelRate, CycleTimeS := CycleTimeCalc.CycleTimeS);

// APRÈS (RAMP_REAL Util)
SpeedRamp(
    IN      := RampTargetPct / 100.0,  // 0..1
    ACCEL_TIME := 100.0 / RampAccelRate,  // s
    DECEL_TIME := 100.0 / SEL(SafeStop, RampDecelNormalRate, RampDecelFastRate),
    CYCLE_TIME := CycleTimeCalc.CycleTimeS
);
RampTargetPct := SpeedRamp.OUT * 100.0;
```

---

### **ACTION #2 — Seuils Méca A / Méca B**

**Fichier** : `CODE/TRANSLATION/FB_Safety_Translation.st`
**Paramètres à étalonner sur machine** :
```st
PostRampTimeout     : TIME := T#3S;    // → Méca B : temps confirmation arrêt (mesurer temps réel frein+variateur)
TonMecaA.PT         : TIME := T#1S;    // → Méca A : détection fréquence fantôme (mesurer inertie pont)
MecaA_FreqThreshold : REAL := 0.5;     // Hz → seuil fréquence (mesurer fréquence résiduelle à l'arrêt)
```
**Méthode** : Arrêt d'urgence réel → chronométrer : (1) temps fréquence > 0.5Hz, (2) temps frein collé + variateur arrêté.

---

### **ACTION #4 — Nettoyage GVL_Stub**

**Fichier** : `CODE/TRANSLATION/GVL_Translation_M3_Stub.st`
**Supprimer** (orphelines depuis abandonment mode relais v0.4.11) :
- `M3_RelayFwd`, `M3_RelayRev` (BOOL)
- `M3Fwd_Eff`, `M3Rev_Eff`, `M3_ActiveFreqCmd`, `M3_DriveIsReal` (BOOL/REAL)
**Conserver** : `StubTranslationPositionSelect_IHM` (utilisé PRG_07)

---

### **ACTION #5 — Watchdog IHM↔Automate**

**Architecture** :
```
GVL_IHM.Commun.Heartbeat_IHM (BOOL, toggle 500ms côté IHM)
    → PRG_09_Supervision : détecte front manquant > 2s
    → PRG_07_TranslationControl : SafeStop_IHM_Watchdog := TRUE
    → FB_Safety_Translation : nouvelle entrée HeartbeatOK → bit8 ErrorId
```

**Fichiers** :
1. `CODE/SUPERVISION/ST_CommunHMI.st` : ajouter `Heartbeat_IHM : BOOL;`
2. `CODE/MAIN/PRG_09_Supervision.st` : supervision timeout (TON 2s sur front)
3. `CODE/TRANSLATION/FB_Safety_Translation.st` : entrée `HeartbeatOK`, bit8 `ErrorHeartbeatLost`
4. `CODE/MAIN/PRG_03_Safety.st` : câbler `HeartbeatOK := GVL_IHM.Commun.Heartbeat_IHM` (avec TON)

---

### **ACTION #6 — Bornage paramètres RETAIN**

| Paramètre | Min | Max | Défaut | Fichier |
|-----------|-----|-----|--------|---------|
| `DriveFreqScaleMaxHz` | 10.0 | 100.0 | 60.0 | FB_Translation.st + ST_TranslationHMI.st |
| `ApproachSpeedPct` | 5.0 | 50.0 | 20.0 | FB_Translation.st + ST_TranslationHMI.st |
| `RampAccelRate` | 5.0 | 200.0 | 20.0 | FB_Translation.st + ST_TranslationHMI.st |
| `RampDecelFastRate` | 20.0 | 500.0 | 100.0 | FB_Translation.st + ST_TranslationHMI.st |
| `DirectionInterlockDelay` | T#50ms | T#2s | T#200ms | FB_Translation.st + ST_TranslationHMI.st |
| `CaptorDebounce` | T#10ms | T#1s | T#100ms | FB_Translation.st + ST_TranslationHMI.st |

**Implémentation** : Dans `FB_Translation` → `VAR_INPUT` → ajouter `RangeCheck` (clamp silencieux + warning IHM si hors bornes).

---

## 🧪 VALIDATION ACTIONS — Critères de recette

| Action | Test unitaire (Simulation) | Test intégration (Machine) |
|--------|---------------------------|---------------------------|
| #1 FB_Ramp | Rampe 0→100% en 5s @ AccelRate=20 | Même comportement variateur |
| #2 Seuils | Injecter freq 0.6Hz > 1s → SafeStop | Arrêt d'urgence réel → chrono |
| #4 Stub | Compile sans warning variables inutilisées | — |
| #5 Watchdog | Couper heartbeat IHM → SafeStop < 2.5s | Déconnecter Ethernet IHM → arrêt |
| #6 Bornage | IHM saisit 200Hz → clamp 60Hz + warning | — |
| #7 AC600 | — | Mots commande/état + thermique + com stable 1h |

---

## 📋 CHECKLIST PRÉ-CODESYS-CHANGE

Avant de lancer `codesys-change`, vérifier :

- [ ] **Action #1** : `RAMP_REAL` disponible dans librairie `Util` (version projet)
- [ ] **Action #2** : Accès machine pour étalonnage (planifier créneau)
- [ ] **Action #3** : Chronomètre / oscilloscope dispo pour mesure glissement
- [ ] **Action #5** : IHM supporte toggle heartbeat 500ms (côté intégrateur IHM)
- [ ] **Action #7** : Documentation constructeur AC600 (mots 0x3101/0x3102/0x3100/0x3103) + câblage thermique
- [ ] **Action #8** : Bureau d'études notifié pour dossier PL-d

---

## 📚 TRACABILITÉ COMPLÈTE

| Source | Contribution | Référence |
|--------|-------------|-----------|
| Audit Codex | Architecture, Safety, IHM, Cycle, Tests, Guardrails, Paramètres, Risques M3 | `AUDIT_TranslationM3_Consolidated_v1.0.md` |
| Audit Gemini/antigravity | ISO 13849 réserves, Watchdog IHM, GVL_Stub orphelines, Blocages AC600/T4/T19, Bornage TopSensorPositionM | `revue_de_securite_excavatrice.md` + `analyse_conformite_reglementaire.md` |
| Test A/B (Claude Herdr) | Validation fusion nécessaire — A = rigueur technique, B = garde-fous normatifs/dette | Session `ab-test-auditor` |
| Docs projet | Parties 2,3,4,5,7,11,13,14 + NAMING_CONVENTION + AGENTS.md | `DOC/` |

---

## 🚀 PROCHAINE ÉTAPE RECOMMANDÉE

```bash
# Lancer codesys-change sur l'action #1 (plus haute priorité, purement code, sans dépendance externe)
codesys-change "Migrer FB_Ramp vers RAMP_REAL (Util) dans FB_Translation — Action P0 #1"
```

Puis enchaîner #4 (nettoyage stub, rapide) → #6 (bornage, IHM) → #5 (watchdog, archi) → #2/#3/#7 (chantier) → #8 (BE).

---

*Rapport consolidé final v2.0 — Prêt pour exécution workflow `codesys-change`.*