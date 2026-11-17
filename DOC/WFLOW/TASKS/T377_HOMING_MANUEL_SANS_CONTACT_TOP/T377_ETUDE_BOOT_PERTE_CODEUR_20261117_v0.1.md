# Étude lecture seule (hors périmètre T377) — « perte codeur » au démarrage + autotest AU

Demande : TORC-CC10, GO tracé `DOC/WFLOW/MISE_EN_SERVICE/GO_T377-CC03_20261117_etude-demarrage.md`.
Faits vs hypothèses séparés. Programme observé : v0.7.24 (machine). Aucune écriture CODE/.

## 1. FAITS vérifiés (fichier:ligne, lu aujourd'hui)

- Cause 1 « perte codeur » latched SANS Enable ni warmup : `CODE/H_TREUILS_BENNE/FB_Safety_Winch.st:277-282`
  (`IF NOT (BypassProcess OR EncoderFaultBypass) AND NOT EncoderAvailable THEN EncoderFaultLatched := TRUE`). CONFIRMÉ.
- Le warmup `TonStartupWarmup` (:268) ne sert que la cause 0 (com opérateur). CONFIRMÉ (TORC).
- `EncoderAvailable := NOT((AlarmsIn<>0) OR NOT SlaveOperational)` : `CODE/E_CODEURS/FB_Encoder_Abs.st:75,91` ; cause 0 live (non latchée). CONFIRMÉ.
- PRG_02 appelle le codeur `Enable := TRUE` (PRG_02:645) et `SlaveOperational := instDiagEthercat.DeviceEncoderM1.Operational` (PRG_02:642). CONFIRMÉ.
- **Complément 1** : `FB_Diag_Ethercat.st:72` — par défaut au boot `DeviceEncoderM1.Operational := FALSE` ; :92 — `EncoderM1OnlineReal := (DeviceEncoderM1StateRaw = DEVICE_STATE.RUNNING)`. Le état RUNNING n'est atteint que quand le maître/moteur EtherCAT montera en OP → `EncoderAvailable = FALSE` pendant toute l'init bus.
- **Complément 2 (ordre d'appel)** : PRG_02 (données codeurs) s'exécute avant PRG_04 qui appelle la sécurité avec `EncoderAvailable := Data.EncoderM1.Measurement.EncoderAvailable` (PRG_04:942, :1012) ; `Enable := (Mode <> DISABLE) AND NOT InhibitM1` (PRG_04:929) — armée dès les 1ers cycles. Chaque scan où le bus est encore en init lêche donc le latch.
- **Complément 3 (Reset)** : `Reset := PRG_07_Supervision.FaultMachineReset_IHM` sur le safety (PRG_04:930) et le codeur (PRG_02:646) → le Reset opérateur purge les latches → machine fonctionnelle ensuite. Cohérent avec l'observation.
- **Snapshot 2026-11-17 10:34:33** : COD1/COD2 `Alarms=0`, `DeviceState=RUNNING`, `HomedAndReliable=TRUE` (:95,:97,:103,:188,:190,:196) ; `Idx311_ErrorEncoder TRUE` (:118,:211) = miroir du LATCH sécurité (`FB_TroubleshootingView.st:200,279` → `Safety.ErrorEncoder`), pas de l'état live (`Step3_EncoderAvailable TRUE`, :336/:347). Cohérent : latch résiduel de boot, bus sain.
- **ArmingErrorId = WORD#8** (:36) → `FB_FaultCore.st:49-57` : ErrorId = bitmask bit i = cause i active. Bit 3 = cause 3 de l'AU = **« Echec autotest demarrage AU »** (`FB_Safety_EmergencyManagement.st:496-497`, latched). Affichage « ErrorID:04 » = même cause (index 3). Hypothèse (base affichage M1 «02» <-> cause 1 « perte codeur » FB_Safety_Winch:276-282) : l'affichage correspond à l'index de cause — à confirmer côté trace console.
- Autotest AU : exécuté 1 cycle au **1er EnableRising** (`:171-186`) avec `Enable := TRUE` inconditionnel (`PRG_06_Outputs.st:502-503`) ; critères : `EmergencyChainClosed AND NOT PowerContactorEngaged AND ArmingSeqStep=IDLE` (`:179-181`) ; `EmergencyChainClosed := HwIn.Machine.EmergencyChainClosed_DI` DI **physique** (PRG_06:506 ; PRG_02:190 ; `ST_HwMachine.st:9`).

## 2. Réponses aux questions

### Q1 — contestation des constats
Tous CONFIRMÉS + 3 compléments (boot OP FALSE par défaut, l'ordre PRG_02→PRG_04, ErrorId bitmask).

### Q2 — pourquoi l'autotest AU échoue au démarrage, même matinal (contacteur au repos)
Le critère est évalué **au premier scan task** (Enable := TRUE constant) alors que ses préconditions
ne sont valides qu'**après** le réarmement matériel de l'AU :
- à l'arrêt de mise sous tension, la boucle AU est physiquement **ouverte** tant que personne
  n'a réarmé (réarmement = bouton matériel externe hors PLC, `FB_Safety_EmergencyManagement.st:194`) → `EmergencyChainClosed_DI = FALSE` → `StartupCheckOK := FALSE` → cause 3 latchée.
- cas (a) reboot PLC courant : `PowerContactorEngaged_DI = TRUE` (vérifié au snapshot, et l'ordre voulu du test le suppose au repos) → le test 2 échoue → même latch.
La machine « marche après Reset » car il n'y a **aucun défaut réel** : un latch d'autotest n'est purgé que par Reset.
En résumé : l'autotest est câblé pour s'exécuter à un moment où ses préconditions sont
légitimement fausses → faux positif structurel, pas un capteur fautif.
HYPOTHÈSES à confirmer : position exacte de la chaîne AU au boot matin (schéma DOC/WFLOW/ELEC) ;
sens exact de l'affichage console ErrorID ; affectation 24 V codeurs vs AU (historique exploitant).

### Q3 — variantes
- **A (acquittement unique au boot après X s liaison saine)** : acceptable mais faible ISO :
  un auto-acquittement d'un latch de sécurité sans action opérateur affaiblit la discipline
  « cause latched → Reset conscient » ; reste borné aux causes bus/codeur.
- **B (ne pas armer le latch tant que le bus n'a pas atteint OP une fois, délai max X s)** :
  - scénario (a) reboot PLC, 24 V présent : flag OP absent au boot → pas de latch pendant
    la re-init bus → le bus repasse OP → sain → **faux positif supprimé**.
  - scénario (b) mise sous tension complète : idem (a) ; un défaut codeur RÉEL avant le
    1er OP reste couvert par le **délai max** : pas d'OP après X s → latch quand même.
  - scénario (c) AU puis réarmement (historique : les codeurs étaient sur le 24 V
    COUPÉ par AU — à confirmer schéma) : le flag « OP atteint une fois » est TRUE depuis
    le boot → la perte consécutive à l'AU **latche impérativement** → B **ne dégrade pas** (c).
  - l'ISO 13849 est préservé : B ne fait que **retarder l'armement** de la cause pendant
    une fenêtre bornée de boot, l'acquittement reste un Reset conscient ; la disponibilité
    machine reste de toute façon bloquée par `HomedAndReliable` / permits tant que le bus
    n'est pas sain, et la cause 0 (live) du codeur continue de signaler.
  - Risques de bord : fenêtre X s à choisir > temps réel de montée bus (mesurer sur site) ;
    un esclave réellement mort au boot n'est vu qu'après X s (cause 0 live le montre
    immédiatement) ; le code ne doit pas créer une 2e source de vérité (le flag s'appuie
    sur `Operational` existant).
- Recommandation : **B avec délai max** (couvre le « capteur mort au boot » qu'A masquerait
  jusqu'à X s). A seul = accepté seulement si l'acquittement reste visible à l'IHM.

## 3. Tests nécessaires (proposition de matrice, à cadrer avant code)

1. (a) reboot PLC sous puissance → NO latch après init bus, ErrorId 0.
2. (b) cold boot, chaîne AU ouverte → AU ErrorID 04 présent (comportement documenté)
   OU corrigé si l'autotest est re-câblé post-réarmement.
3. (c) AU en cours + réarmement → latch « perte codeur » immédiat (préservé).
4. Codeur mort au boot (avant 1er OP) → latch après délai max X s.
5. Torsade bus en exploitation → latch immédiat (aucun changement).
6. Non-régression : gates existants (`G200 --report`, palier C) + scénarios SimBench
   des 3 états du flag (OP jamais vu / vu une fois / perdu après vue).
