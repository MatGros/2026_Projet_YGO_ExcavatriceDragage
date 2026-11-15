# 🧪 T377 — Étude solutions : rapport d'arbitrage (workflow lecture seule)

> **Date** : 2026-11-14 · **Auteur** : T377-CC03 (RT)
> **Origine** : workflow `t377-solutions-etude-lecture-seule` (run `wf_d3355380-916`) — **8 agents**, 0 erreur,
> 288 opérations, 868k tokens, ~9 min. Lecture seule stricte (Read/Grep/Glob uniquement, 0 écriture, 0 gate script).
> **Preuves brutes** : journal `…/subagents/workflows/wf_d3355380-916/journal.jsonl` (1 ligne `result` par agent) ·
> sortie complète du run. Chaque solution citée ci-dessous a été reprise ligne à ligne par un adversaire dédié.
> **Verdict global** : 12 CONFIRMÉ au code · 2 A-PRÉCISER · 0 RÉFUTÉ.

---

## 1. D4 — Source de validation (collision homme-mort/volonté) — 4/4 CONFIRMÉ

| Solution | Apport clé (preuves adversarial) | Point d'attention hostile |
|---|---|---|
| **S1 Découplage câblage** : `BtnValidation := GVL_IHM…Cmd.BtnValidate` seul (1 ligne) | `BtnValidate` existe déjà (`ST_CycleMachineHomingCmd.st:11`), front `R_TRIG` déjà câblé (`FB:214`), comment. périmé `PRG_02:607-608` (« motif 3 appuis » jamais implémenté — compteur absent du code) | Reachabilité cabine du bouton IHM à confirmer par l'exploitant |
| **S2 Garde fenêtre brute** (refus si `|pos − 8,50| > 1,00 m`) | Ancre exacte relue : `CfgTopHomingTarget_M` existe (`ST_fbMachineHomingCycle_Cfg:15`, alim. `PRG_02:583`) | `CablePosM1/M2` sont scalés sur calibration PERSISTÉE (`GVL_PERSISTENT:13-14`, RETAIN) → dérive longue invisible déjà documentée ; `BootReady` (`FB:23`) **jamais lu** (grep 1 occurrence) → le consommer ferme le cas codeur gelé |
| **S3 Garde de progression** (montée démontrée depuis l'entrée) | hypothèse (variante) | Mode commun avec S2 : les deux lisent `CablePosM` — choisir l'une |
| **S4 Refus traçable** (compteur + cause + guide §10 + snapshot) | `MachineHomingInstruction STRING(120)` `FB:74`, chaîne `:610-692` et façade `PRG_02:623-637` vérifiées intégralité | alimenter aussi `F_HomingM2` depuis `FB_TroubleshootingView:461-484` (dans le contrat) |

## 2. D5 + D7 — Permis & garde de mode — 2 CONFIRMÉ / 2 A-PRÉCISER

- **S3 « Zéro code treuil » — la barrière existante EST l'interdit (CONTRAT pur)** : le verrou `TopContactLatched` + refus de validation suffisent ; falsifiabilité par le diagnostic. Recommandation RT : **voie canonique** (0 risque de régression treuil).
- **S4 D7 posé proprement** : options N2-seul vs N1-OU-N2 écrites + **garde consommateur indépendante**. ⚠️ Fait adversarial : `HomingPermit` câblé actuel = **N1 OR N2** (`PRG_02:652`) — la garde D7 doit être choisie avant pose.
- S1 (permis `AscentInhibit` consommé au canal `AscentPermit`) : A-PRÉCISER — ⚠️ **`Enable` du gate câble `TRUE` en dur** (`PRG_02:588`) → le FB de gate est inerte aujourd'hui ; le permis doit être lu par la voie manuelle réelle.
- S2 (coupure d'intention post-arbitré, pattern hold T248) : **HORS-CONTRAT** (`PRG_04`) — à réserver aux cas où S3 échoue.

## 3. D6 — Dégagement HX2A — 3 CONFIRMÉ / 1 HYPOTHÈSE HORS-CONTRAT

| Solution | Apport clé | Fix hostile |
|---|---|---|
| **HX2A segmenté « consentement conscient »** (descente joystick par segments ≤3 s + Reset) | `JoystickPush = AxisY.DirectionNegative` (`PRG_02:606`), façade `PRG_02:623-637` vérifiée | ⚠️ amender le contrat pour inclure `CODE/G_CYCLE/_TYPES/E_MachineHomingTxState.st` (les TYPES sont HORS des 6 modifiables actuels) |
| **Repli gravité N2 — 0 CODE** : levier `BtnM1BrakeRelease`/`BtnBothBrakeRelease` EXISTANT | chaîne vérifiée `PRG_06:320-324` : `MaintenanceN2BrakeForceM1 := MAINT_N2 AND EmergencyChainClosed AND Contactor AND (BtnBoth OR BtnM1)` | le dégagement COUPLÉ exige `BtnBothBrakeRelease` (procedure guide + checklist) |
| **Dernier recours : bypass MecaD IHM EXISTANT — 0 CODE** | `ST_BypassWinch.st:32` (MecaD), câblé **sans gate de mode** `PRG_04:865` (dérogation MES 2026) | la descente continue exige **les 2** `Bypass.MecaD` posés (purge `BtnFaultReset` globale) ; re-homing obligatoire en sortie de mode |
| Exemption MecaD consentement cycle latché | modèle existant relu (`FB_Safety_Winch:372-384`) | HORS-CONTRAT, hypothèse — preuve fenêtre `PRG_06:481-483` |

👉 Découverte : **la machine n'est pas condamnée après contact** : 2 leviers 0-code existent déjà (gravité N2, bypass MecaD IHM). Le plan v1.0 HX2A reste l'option nominale ; les leviers 0-code = procédures de secours documentées.

## 4. Transaction du preset — 3 CONFIRMÉ / 1 A-PRÉCISER

- **S1 HX3 transaction lue par axe** (émission M1 puis M2, ack `HomingBusy→HomingDone`, exit sur Done frais du cycle) — CONFIRMÉ. Fix : purger `Tx*SeenBusy/DoneSeen` sur **toute** ré-entrée HX3 (retry inclus).
- **S2 HX4 non-tautologique** — A-PRÉCISER : fond confirmé (le FB ne connaît PAS `CfgTopSensorPos_M` — grep 0 hit ; `CfgTopHomingTarget_M` existe et est alimenté `PRG_02:583`) ; préciser la cible du contrôle M1 (`_WinchM1CfgPersist` vs M2).
- **S3 Retry unique piloté par le retour** — CONFIRMÉ. Fix : textes de cause `:360` + commentaire `:177` alignés au nouveau seuil (constantes, plus de « 3 » hardcode `:358`).
- **S4 🔎 DÉCOUVERTE : verrou READBACK_ONLY côté appelant** — CONFIRMÉ et majeure :
  `HwInM1.PresetStatusBit := FALSE` (`PRG_02:643`) / `M2` (`:698`) — le bit HW est forcé FALSE, le mode de confirmation est **réglage IHM partagé** (`PRG_02:670/725` via `GVL_IHM.Commun.EncoderCfg`).
  → Si un réglage IHM porte le mode sur `READBACK_AND_STATUSBIT` ou `STATUSBIT_ONLY`, **`PresetConfirmed` ne viendra jamais** → plus de `Homed`, homing inopérant silencieux.
  Fix : verrou + champ trace `PresetConfirmModeForced`.

## 5. Recommandation RT (synthèse)

1. **Retenir** : D4=S1+S2 (fenêtre en garde de refus) + S4 traçage · **D5/D7=S3** (barrière existante) + S4 (garde de mode posée avant pose) · **D6=HX2A plan + 2 procédures 0-code documentées** · Transaction=S1+S2+S3+S4.
2. **Élargissement de contrat à arbitrer** : inclure `CODE/G_CYCLE/_TYPES/E_MachineHomingTxState.st` (HX2A/enum) — ou garder enum stable et ne pas renommer (D3 du plan).
3. **Faire trancher** : D4 (IHM seul vs fenêtre+progression), D6 (segmenté vs gravité vs bypass comme secours), D7 (N2 vs N1+N2), risque résiduel calibration persistante, reachabilité cabine `Cmd.BtnValidate`.
4. **Alimenter** : contrat v1.1 (candidat déjà posé `T377_CONTRAT_REVISION_v1.1_CANDIDAT.md`) avec ces mécanismes avant pose canonique.
