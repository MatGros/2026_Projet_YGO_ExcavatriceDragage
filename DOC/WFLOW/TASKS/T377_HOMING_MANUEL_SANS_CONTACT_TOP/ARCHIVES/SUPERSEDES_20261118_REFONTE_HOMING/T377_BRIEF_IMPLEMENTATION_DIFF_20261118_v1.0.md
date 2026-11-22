# T377 — Brief d'implémentation du lot diff (GO exploitation)

→ NOUVEL AGENT (délégué implémentation T377). Émetteur : CC03 (session tâche T377, Superviseur T377-CC03). Transmission par l'exploitant.
Contrat v1.1 : `.../T377_HOMING_MANUEL_SANS_CONTACT_TOP/CONTRACTS/TASK_CONTRACT_T377_HOMING_MANUEL_SANS_CONTACT_TOP.yaml` — **check_task_contract PASS (2026-11-18)**.

## 1. Objet
Implémenter le lot diff T377 (criticité C3, stratégie patch) : homing N1 manuel SANS
contact capteur TOP. Le mini-lot anti-démarrage accidentel est DÉJÀ posé (PRG_02:609
IHM seule ; FB:416 manche neutre) — il reste inchangé, ton diff s'ajoute sur la base.

## 2. Contexte & vérités
- Preset 8,50 m déjà câblé (PRG_02:661-663/:715-717) — RIEN à changer sur le preset.
- Barrière montée : PRG_04:1126-1129 (non touchée). PowerCutOff masquée MAINT_N2
  (PRG_04:1632/1653), contacteur bypass (PRG_06:355) — ne pas modifier.
- Enum actuelle 0..8, valeur 9 libre ; 3 consommateurs seulement (FB + ST_MachineHoming + type).
- Docs de référence OBLIGATOIRES :
  - `T377_BROUILLON_ST_DIFF_20261116_v0.1.md` (v0.4) — spécification par fichier
  - `T377_SEQUENCE_GRAFCET_20261116_v0.1.md` (§2bis arbitrage) — séquence cible
  - `T377_ARBITRAGE_ERGONOMIE_20261116_v0.1.md` + `T377_ARBITRAGE_IN_OUT_20261117_v0.1.md`
    — décisions v0.4 (purge latches Enable FALSE, messagerie, ClimbTimedOut → HX7, invariants)

## 3. Spécification des diff (détail complet : brouillon §1-§9)
1. `G_CYCLE/_TYPES/E_MachineHomingTxState.st` — renommages	HX3 → HX3_REFERENCE_RESTORE,
   HX4 → HX4_REFERENCE_VERIFY + `HX2A_CONTACT_CLEARANCE := 9` (valeurs 0..8 inchangées).
2. `G_CYCLE/_TYPES/ST_fbMachineHomingCycle_Cfg.st` — supp CfgStabilizationMinM/MaxM et
   CfgTimeoutFlyingHoming ; ajout CfgVerifyTolHighM := 0.10 / CfgVerifyTolLowM := 0.10.
3. `G_CYCLE/FB_CycleMachineHoming.st` — le lot :
   HX2 approche manuelle (montée sous gardes + skew + validation 5 gardes, refus tracé) ·
   HX2A dégagement (montée interdite par latch, descente joystick, purge latch au
   dégagement ET au Reset §4 ET au gate §7 Enable FALSE — v0.4) · HX3 HomeReq unique à
   l'arrêt (Mode A/B supprimés : HomingModeBActive, FlyingHomingTimer, StandstillHomeReqDone,
   0 consommateur externe vérifié) · HX4 vérif (cohérence 1,0 m + bande 8,50 +0,10/-0,10,
   UNE ré-émission puis HX7) · cause C8 := 8 NON-latching — point de vérification FB_FaultCore
   obligatoire avant restitution · mapping IHM §10 (4 nouveaux libellés + 4 messages
   d'inopérance v0.4, HX2A porte « DESCENTE SEULE », HX7 cause d'entrée exposée) ·
   homing unitaire interlock CycleRunning (câblage PRG_03:274 côté permis).
4. `M_MAIN/PRG_02_Acquisition.st` — publication diagnostic TopContactLatched + refus.
5. `M_MAIN/PRG_07_Supervision.st` — publication des 2 nouveaux champs checklist.
6. `J_SUPERVISION/_TYPES/6_DIAG_ET_CHAINES/ST_HomingChecklist.st` — + 2 champs.
7. `J_SUPERVISION/FB_TroubleshootingView.st` — remplissage E_HomingM1/F_HomingM2.
8. `J_SUPERVISION/GVL_Troubleshooting.st` + `troubleshooting_variables.txt`.
9. `ST_MachineHoming` — libellés renommés (lire avant d'éditer).

## 4. Périmètre & INTERDITS
Forbidden : `FB_Safety_Winch.st` (D1=C : aucune modif) · `FB_Encoder_Homing.st` ·
`FB_Encoder.st` · `FB_WinchSync.st` · `Device.export` · `ARCHIVES/**` · `TASKS.yaml`
(lecture seule). Ne pas toucher le mini-lot du 17/11 ni ta propre base MAINT_N2.

## 5. Règles de conduite
- **AUCUN commit, aucun push** sans validation humaine explicite. GO implémentation ≠ GO commit.
- Preuve avant affirmation : toute valeur citée = sortie brute dans le même message.
- `Device.export` jamais référence ; source de vérité = `CODE/*.st` + bundle frais.
- Tout constat touchant le périmètre (collision, effet de bord terrain, écart doctrine) :
  SIGNALÉ immédiatement, jamais en fin de lot — copie datée au dossier T377 + mention exploitant.

## 6. CHANTIERS CONCURRENTS (obligatoire : vérifier avant écriture)
- Lot terrain MAINT_N2 inconditionnel : PRG_03/04/05/06, FB_Modes, CycleSemiAuto,
  Translation*, ST_CycleCmd — committé le 18/11 (5e7935a4, 078be11e). Vérifier `git log`
  avant le tien ; un seul écrivain à la fois sur un fichier.
- T377-B (séparée, C4, agent à désigner) : FB_Safety_Winch + EmergencyManagement — NE PAS écrire.
- Bundle `CODE_XML/CODE_Bundle.xml` global disque : régénérer seul, vérifier avant commit.

## 7. Preuves attendues (restitution)
- `git diff` réel fichier:fichier (aucun fichier que tu n'as pas touché dedans).
- Bandeaux : bundle exporté · diff bundle (`generate_codesys_diff_bundle.py . <fichiers>`)
  · G200 `--report` (bloc Auto-vérification collé) · `run_all_gates.py --palier C`.
- SimBench : les 8 scénarios du brouillon §8 (refus ×4, validation nominale, contact→HX2A,
  hors bande → 1 re-émission, preset non confirmé, TC adaptés, anti-déclenchement, TC inertie).
- Matrice de mapping sortie→consommateur (file:line) pour CmdWinchM1/M2, CmdWinchSelect,
  HomeReq, causes, IHM.

## 8. Points d'arrêt & escalade
- Élargissement de périmètre (écrire dans un fichier interdit) → STOP + signal.
- `Fault.Latched` (cause C8) : si l'audit des consommateurs hors checklist révèle une
  inhibition variateur potentielle → retenir le fallback (retirer cause 8, sorties
  dédiées) et le signaler, ne pas improviser.
- Divergence entre brouillon v0.4 et réalité du code : prévaut le code ; signaler l'écart.
- Vérité terrain : l'exploitant applique dans CODESYS (copie ST + import diff bundle).
