# 🟡 ADVISORY — Câblage homing D1-D7 (pas CLEAN)

**Verdict :** aucune erreur d'ordre de scan IEC confirmée dans le diff visible ; architecture cohérente et redondée. **2 risques P1 dépendent de code hors diff (PRG_02 FSM homing + câblage ReqDescend existant) et doivent être coupés avant de déclarer CLEAN.**

## Invariants

1. [✅ PASS] Purge benne en homing : triple barrière cohérente (instArbBucket Enable=FALSE + ReqOpen/ReqClose:=FALSE PRG_03 + purge interne FB_Bucket, CloseReached inclus). Conforme à la note « CommitClose = commit codeur ».
2. [✅ PASS] TonDatumUnreliable étendu (`NOT HomedM1/M2`) : au flip Homed, IN=Faux le même scan → TON.Q=Faux, le BucketReferenced posé par CommitClose post-homing n'est pas écrasé. Pas de course.
3. [✅ PASS] Symétrisation soft-limits descente/montée (`Homed ∧ ¬Suspect ∧ ¬SoftLimitsBypassed`) : repli maintenu (FDC matériel indépendant, Kobold, palier 1 forcé, `HomingFreeMoveBlockedN1` coupant demandes ET permis). Le flag `SoftLimitsOff` est mort s'il fuit hors homing (AND Active au câblage). Strictement additif, pas de régression.
4. [✅ PASS] PowerCutOff actif en N2 (retrait `AND NOT MaintN2`) conforme à l'intention ; gating permis homing place §585 (demandes) et §1179 (permits) avant interlock final §1707 → pas d'inversion de scan. Lag 1 scan documenté, homogène au reste.
5. [✅ PASS] PRG_06 `WinchOutputCoupled` : changement strictement additif (avant : FALSE dés que homing ; après : FALSE partout sauf pas 1/4). Fix `WinchBothIntent` (direction gated par Active) supprime la direction fantôme.
6. [❌ ADVIDE P1] **Suppression MecaD par ReqDescend** : la clause `NOT (ReqDescend AND NOT ReqAscent)` ne protège le homing que si `instSafetyWinchM2.ReqDescend` porte la demande programme/homing post-gating. Le diff ne touche pas ce câblage (pré-existant). Si câblé opérateur/both-intent seul : descente homing (select=2) démarrée depuis position haute → BenneBusy purgé FALSE → `UncommandedActiveD` → MecaD latch → **PowerCutOff honoré (désormais en N1 ET N2) → coupure mi-homing**.
7. [❌ ADVIDE P1] **Branche ELSE (select ∉ {0,2})** coupe M1 ET M2 (demandes §585 + permis §1179). Si PRG_02 code un pas homing M1-seul avec `CmdWinchSelect=1` → **deadlock homing**. Convention 1=M1/2=M2 plausible au vu du reste du code.
8. [⚠ P2] `instArbBucket(Enable)` : tri-state des sorties sur Enable=FALSE non prouvé (Auth/Busy stale après reprise post-homing).
9. [⚠ P2] M3AtTremie masqué en homing : conservateur si l'input n'est qu'une autorisation ; réactivateur si un consommateur utilise `NOT M3AtTremie`. À confirmer dans FB_Modes.
10. [⚠ compile] Objets non visibles dans le diff : `FB_Bucket.HomedM1/HomedM2`, `ST_MachineHoming.{SeqStep, CmdWinchSelect, AllowAscent, AllowDescend, SoftLimitsOff}`. Si non livrés dans le même lot → non compilable.

## Argumentaire

MecaB est épargné en homing par construction (l'expression n'asserte pas sur mouvement « commandé », même logique que les mouvements programme en production) ; MecaD, lui, a un périmètre BenneBusy indépendant des demandes treuil — d'où la suppression ReqDescend, dont l'efficacité repose entièrement sur le câblage de l'input. La désactivation de l'arbitre benne et la purge ne créent pas de fenêtre : toute mobilité treuil hors pas homing est fermée à deux niveaux (demandes + permis).

## Plan d'action

1. PRG_02 (FSM homing, assignments `CmdWinchSelect` + câblage `instSafetyWinchM2.ReqDescend`) — trancher P1 #6 et #7. Outil : grep déterministe sur `CmdWinchSelect :=` et la chaîne `ReqDescend`. Risque si ignoré : coupure/deadlock mi-homing.
2. FB_ArbBucket — prouver reset des sorties sur Enable=FALSE (lecture du FB + test unitaire). Risque : résidu Auth/Busy au retour.
3. FB_Modes — auditer les consommateurs de M3AtTremie (polarité ¬/∧). Risque : garde désamorcée sous homing.
4. Vérifier compilation/complétude du lot (objets de l'invariant 10) via build.

Pas de verdict CLEAN tant que l'action 1 n'est pas coupée par preuve (grep + lecture câblage), le reste du diff est sain.