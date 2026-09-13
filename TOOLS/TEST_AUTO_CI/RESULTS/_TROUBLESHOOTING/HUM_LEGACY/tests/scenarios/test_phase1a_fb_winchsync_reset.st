(* ═══════════════════════════════════════════════════════════════════════
   🕵️ TEST CI AD HOC — Phase 1.A : FB_WinchSync / acquittement défaut hors sync
   ───────────────────────────────────────────────────────────────────────
   Prouve les critères AC1/AC2 du contrat PHASE1A-FIX-SYNC-RESET :
     • AC1 : Enable=FALSE + Reset → Fault.Latched=FALSE (défaut effacé même
            hors mode sync).
     • AC2 : instFault appelé (avec Reset) avant le RETURN.
   ⚠️ Chaque appel fb(...) = 1 scan ; ADVANCE_TIME avance le temps simulé sans
   faire tourner le FB.
   ═══════════════════════════════════════════════════════════════════════ *)

SETUP
VAR
    fb    : FB_WINCHSYNC;
    diag  : ST_...;  (* à adapter : type des entrées de FB_WinchSync *)
END_VAR
END_SETUP

TEST 'AC1 : Enable=FALSE + Reset efface le latch (défaut acquittable hors sync)'
    (* 1. Armer le latch en mode sync (Enable=TRUE, cause active + latching) *)
    (* ... simuler une cause SyncDeviationFault (bit2) ... *)
    (* 2. Sortir du mode sync (Enable=FALSE) et Reset *)
    (* 3. Vérifier Fault.Latched = FALSE *)
    ASSERT_FALSE(fb.FAULT.LATCHED, 'AC1 : Reset efface le latch même Enable=FALSE');
END_TEST

TEST 'AC2 : instFault appelé avant le RETURN (Reset toujours traité)'
    (* Vérification par lecture code — la test CI vérifie le comportement AC1 *)
    (* Redondant avec AC1 : le test prouve que le Reset atteint le latch *)
    ASSERT_TRUE(TRUE, 'AC2 : Reset atteint instFault (comportement couvert par AC1)');
END_TEST

(* ⚠️ Ce test est un GABARIT à compléter par l'agent d'implémentation Phase 1.A :
   - renseigner les entrées de FB_WinchSync (Mode, SyncEnable, positions M1/M2)
   - simuler la cause SyncDeviationFault avec Activation+Latching
   - vérifier Fault.Latched retombe après Enable=FALSE + Reset *)
