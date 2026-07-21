# 📊 Chronogramme SuiteModes — FB_ModesValidation

Coller le JSON sur https://wavedrom.com/editor.html

**Échelle : 1 tick = 500 ms**

---

## 🔍 Problèmes identifiés

| # | Step | Problème | Statut |
|---|------|----------|--------|
| P1 | 5 | `EmergencyStopOk` jamais armé sans hardware → step 5 timeout car `CmdEmergencyArming` ne traverse pas la chaîne | ❌ **BLOQUANT** |
| P2 | 52 | Après `OverrideContactorFalse := FALSE` + Reset, `EmergencyStopOk` revient TRUE via `instSimSafety` ? Pas garanti — même problème qu'au démarrage | ⚠️ **RISQUE** |
| P3 | 100→101→102 | `FB_Cycle` démarre en INIT, `CmdWinchM1_StartStop` est FALSE en INIT pas TRUE → step 100 timeout immédiatement | ❌ **BLOQUANT** |
| P4 | 66 | `instWinchM1.State = DISABLED` nécessite 1 cycle de propagation après `Mode = DISABLE` — step 65→66 peut passer trop vite | ⚠️ **RISQUE** |

---

## ✅ Solution recommandée

| # | Fix |
|---|-----|
| P1 | Ajouter `OverrideEmergencyStopOkTrue : BOOL` dans `GVL_PLC_Tests` + `PRG_00_Inputs` ; step 5 le positionne à TRUE directement |
| P2 | Après step 52, forcer aussi `OverrideEmergencyStopOkTrue := TRUE` (même mécanisme) |
| P3 | Step 100 : `FB_Cycle` en INIT → `CmdWinchM1_StartStop = FALSE` (pas TRUE) — inverser la logique du check : attendre que Enable=TRUE stabilise le FB, puis vérifier la transition |
| P4 | Ajouter `DwellPT := T#100ms` entre step 65 et 66 (laisser 1 cycle de propagation) |

---

## 📐 Chronogramme

```json
{signal: [
  {name: 'STEP', wave: '==========.====.====.====.=.=.=.=.=.=.=.=.=.=.=.=.=.=.=.',
   data: ['5','10','11','12','13','14','20','21','30','40','50','51','52','60','65','66','70','71','80','90','91','100','101','102','110','111','0'],
   period: 1},

  {name: 'EmergencyArming', wave: '0.............................................', node: ''},
  {},

  {name: 'EmergencyStopOk',  wave: '0................1......................0....1.................', node: '.a......................................b....c'},
  {name: 'Mode',             wave: 'x.=.=.=.=.=.=.=.=.=.=.=.=.=.=.=.=.=.=.=.=.=.=.=.=.=.=.',
   data: ['?','N1','N1','N1','N1','N1','N2','N2','SA','SA','DIS','DIS','N1','N1','DIS','DIS','N1','N1','N1','N1','N1','N1','N1','N1','N1','N1']},
  {},

  {name: 'JoyButton',        wave: '0...1.0.1.0.1.0.1.0.......................................'},
  {name: 'JoyRawY(5000=n)', wave: '=...=.=.=.=.=.=.=.=.......................................', data: ['neu','neu','10k','5k','10k','neu','10k','neu','neu','neu','neu','neu','neu','neu','neu','neu','neu','neu','neu','neu','neu','neu','neu','neu','neu','neu']},
  {},

  {name: 'RelayFwd M1',      wave: '0...01.0.1.0.1...0.........................................'},
  {},

  {name: 'OvrContactorFalse',wave: '0.............................1..0..................'},
  {name: 'OvrHmiCmdPurge',   wave: '0.................................................1.0'},
  {},

  {name: '❌P1 EmergStopOk jamais armé',  wave: 'x1.................................................', node: '.!'},
  {name: '⚠️P2 Récup step52 risque',      wave: 'x.............................1...x.................', node: ''},
  {name: '❌P3 Cycle INIT CmdSS=FALSE',   wave: 'x.........................................1........', node: '...............................!'},
],
edge: [
  'a<->b perte AU (step50)', 'b<->c récup (step52)'
],
config: { hscale: 1 },
head: { text: 'SuiteModes — 1 tick ≈ 500ms — problèmes P1/P2/P3/P4 annotés', tick: 0 }
}
```

---

## 📋 Détail step par step

| Step | TC | Durée max | Signal IN | Condition PASS | Problème |
|------|----|-----------|-----------|----------------|----------|
| **5** | Pré | 5s | `CmdEmergencyArming=TRUE` | `EmergencyStopOk=TRUE` | ❌ P1 : chaîne inactive sans HW |
| **10** | M1 | 3s | `ModeRequest=N1`, Joy neutre | `Mode=N1` | bloqué si P1 non résolu |
| **11** | M1 | 5s | `JoyButton=TRUE`, `JoyY=10000` | `RelayFwd=TRUE` | OK si mode N1 |
| **12** | M1 | 5s | `JoyButton=FALSE` | `RelayFwd=FALSE` | OK |
| **13** | M1 | 3s | `JoyY=5000` | `NeutralHoldTimer.Q` (1,2s) | OK |
| **14** | M1 | 5s | `JoyButton=TRUE`, `JoyY=10000` | `RelayFwd=TRUE` | OK |
| **20** | M2 | 3s | `ModeRequest=N2`, Joy neutre | `Mode=N2` | OK |
| **21** | M2 | 5s | `JoyButton=TRUE`, `JoyY=10000` | `RelayFwd=TRUE` | OK |
| **30** | M3 | 5s | `ModeRequest=SA` | `Mode=SA` | OK |
| **40** | M4 | 3s | — | `SimulationModeActive AND SimGateOk` | OK (toujours TRUE) |
| **50** | M5 | 3s | `OvrContactorFalse=TRUE` | `Mode=DISABLE` | OK |
| **51** | M5 | 3s | — | `WinchM1.State=DISABLED` | OK |
| **52** | M5 | 5s | `OvrContactorFalse=FALSE`, `Reset=TRUE` | `Mode≠DISABLE` | ⚠️ P2 : EmergencyStopOk revient? |
| **60** | M6 | 3s | `CmdStart=TRUE` 200ms | `Cycle.Busy=FALSE` | OK |
| **65** | M7 | 3s | `ModeRequest=DISABLE` | `Mode=DISABLE` | OK |
| **66** | M7 | 3s | — | `M1/M2/M3.State=DISABLED` | ⚠️ P4 : propagation 1 cycle |
| **70** | M8 | 2s | `FB_Safety_Winch` local, `Mode=N1`, `EncoderBypass=TRUE` | `ErrorId bit1≠0` | OK (instance locale) |
| **71** | M8 | 2s | idem `Mode=N2`, `Reset=TRUE` | `ErrorId bit1=0` | OK |
| **80** | M9 | 2s | `FB_Winch` local, `SpeedStepTable` palier1=tout FALSE | `ErrorId bit2≠0` | OK |
| **90** | M10 | 2s | `FB_WinchLoadEstimator`, `SignedSpeed=-0.1` (descente) | `EstLoad=0` | OK |
| **91** | M10 | 2s | idem `SignedSpeed=+0.1` (montée) | `EstLoad=42.0` | OK |
| **100** | M11 | 2s | `FB_Cycle`, `M1Pos=7.9`, `Limit=8.0` | `CmdSS_M1=TRUE` | ❌ P3 : INIT→FALSE pas TRUE |
| **101** | M11 | 2s | idem `M1Pos=8.0` | `CmdSS_M1=FALSE` | dépend de P3 |
| **102** | M11 | 2s | idem `M1Pos=8.0` | `CmdSS_M1=FALSE` | dépend de P3 |
| **110** | M12 | 2s | Force toutes cmds IHM TRUE + `OvrHmiCmdPurge=TRUE` | (immédiat) | OK |
| **111** | M12 | 2s | — | Toutes cmds IHM=FALSE + `HmiInitDone=TRUE` | OK |
