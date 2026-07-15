# 📦 Historique des versions CODESYS — Lien DOC ↔ CODE

Trace le programme CODESYS testé/validé à un instant donné, pour retrouver quelle version de l'analyse fonctionnelle (`DOC/AF_Partie*`) lui correspondait (retour arrière, FAT/SAT, essais site).

Une entrée par jalon significatif — pas besoin de logguer chaque sous-version mineure. Lignes courtes (~70 caractères), style `·` compact.

---

### `v0.4.12_ChariotHMI_Migration` — 2026-07-15
- ST_ChariotHMI migre ReqFwd/ReqRev/FreqSetpointHz depuis IHM_MANU
- + diag décodé DriveCommReady/DrivePowerReady (pas de WORD brut)
- Pas l'état final : bypass ManuActive→M3_CommandWord reste
- Fix FB_Sim_Chariot bloqué (relais morts ère DEGRADED_IO)
- → rebranché sur M3_CommandWord
- BypassBrakeFeedback supprimé (fusion BypassContactorFeedback)
- Rename Chariot/Joystick→ChariotM3/JoystickJOY1 (Grappin : GrappinM2 tenté puis annulé, stutter M2)
- ⚠️ pas encore réimporté/compilé dans CODESYS

### `v0.4.11_Chariot_AC600_Safety` — 2026-07-15
- EtherCAT AC600 nominal M3 · fin définitive mode relais DEGRADED_IO
- Sécurités Méca A (dérive vitesse à l'arrêt)
- + Méca B (incohérence frein/variateur)
- + arrêt fins de course extrêmes (fosses/trémie)
- Diag com EtherCAT · simu StatusWord/ActualFrequency/frein
- Doc STO ajoutée

### `v0.4.10_FdcGrappin_Rename` — 2026-07-15
- TASK-0002 : FdcGrappinOpen/Close→OpenEnable/CloseEnable
- (ST_IHM_MANU) — clarifie rôle config vs état
- MAJ logique PRG_10_Outputs

### — 2026-07-15
- 🗑️ Retrait DOC/AGENT_HANDOFF/ (queue, push_server.py, hooks)
- Posé en v0.4.8 · TASK-0001/0002 seules tâches réelles produites
- (TASK-0003-0010 = test pipeline factice)
- Remplacé par plugin antigravity (délégation Claude↔Gemini)

### `v0.4.9_JoystickWinchSelect_N2` — 2026-07-15
- TASK-0001 : Joystick M1/M2-seul restreint à MAINT_N2
- (évite désynchro fortuite) — sinon forcé Couplé (3)
- JoystickWinchSelectRequest/Arbitrated ajoutés FB_Modes
- Câblé PRG_04_Modes · PRG_10_Outputs utilise la consigne arbitrée

### `v0.4.8_IHM_MANU_FBWinch` — 2026-07-15
- IHM_MANU pilote M1/M2 via FB_Winch (PRG_06, 3ᵉ source arbitrage)
- Rampe/ralentissement natifs · doctrine "Conditional Bypass"
- retirée FB_Safety_Winch (Enable inconditionnel, granularité _IsReal)
- Fix latch FB_Safety_Chariot (Error pas remis à 0 si Enable=FALSE)
- Fix Fdc grappin appliqué M1 individuel + couplé (pas que M2)
- Fix compil PRG_02_Encoders (var supprimée)
- Nouvelle limite CableLimitAscentM1/M2_M (12.0m, exploitation)
- distincte HomingTarget (12.5m, réservé Homing)
- Fix Méca B bit8 (boutons HMI ignorés par JoystickYNeutral)
- WinchMaxStepFwd/Rev réactivé temporaire + fix boot-init à 0

### `v0.4.7_IHM_MANU_JOY` — 2026-07-14
- Alignement doctrine "Conditional Bypass" (sécu/homing)
- bloquants si réel, shuntés si simulé
- Fix Startup in Neutral · reset Grafcet auto sous IHM_MANU
- Timers homme-mort dynamiques · déblocage stub pompe hydraulique

### `v0.4.6_IHM_MANU_JOY` — 2026-07-14
- Joystick CANopen (X/Y) · décodage paliers K1-K4
- Fdc virtuelles grappin (delta M1-M2)
- Commande auxiliaires hydrauliques · bornage vitesse paliers
- Consigne fréquence chariot M3 réglable/clampée

### `v0.4.5_IHM_MANU` — 2026-07-09
- Fix lecture codeur réel forcée en mode Manu
- même si simu générale active

### `v0.4.4_IHM_MANU` — 2026-07-08
- Ajout structure IHM_MANU (pilotage direct secours)
- Mise en service urgence

### `v0.4.3_SimNoHardware-YGO_CablePre-Commissioning` — 2026-07-08
- Simu sans blocage validée (recul, vitesses, butée M2)
- HMI stable, bypass synchro — avant enroulage réel

### `v0.4.2_SimNoHardware-SyncBypass` — 2026-07-08
- Butée haute M2 dynamique (12m/14m)
- Offset bargraphe stabilisé en mouvement
- Bypass synchro en butées

### `v0.4.1_SimNoHardware-SyncUpdate` — 2026-07-08
- Méca E synchro critique ajoutée
- Arrêt rampe normale sur écart mineur (vs SafeStop)
- Simu stable, pas de MES matérielle

### `v0.4.0_SimNoHardware` — 2026-07-08
- Mouvements M1/M2 + grappin stables en simulation
- Aucune MES matérielle réelle
