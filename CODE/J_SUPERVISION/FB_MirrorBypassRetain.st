(* =======================================================================
   🔄 FB_MirrorBypassRetain — Miroir bidirectionnel IHM ↔ RETAIN (bypass)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Synchronise un bypass IHM (volatile) avec sa copie RETAIN
             (survit à une coupure) — dernier-écrit-gagne : si l'IHM a
             changé depuis le cycle précédent, le RETAIN suit ; sinon
             l'IHM est réaligné sur le RETAIN (ex. redémarrage à chaud).
   🔌 Architecture : Brique technique sans cycle de vie (pas de défaut à remonter)
   📍 Domaine : CODE/J_SUPERVISION (seul consommateur actuel : PRG_07_Supervision §2c)
   📄 Doc métier : DOC/STDS/CODE_QUALITY_STANDARDS.md §10
   ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_MirrorBypassRetain
VAR_IN_OUT
    // === MIROIR BIDIRECTIONNEL ===
    Hmi    : BOOL; // <-> [BUS] Valeur bypass côté IHM (GVL_IHM)
    Retain : BOOL; // <-> [BUS] Valeur bypass côté RETAIN (GVL_PERSISTENT)
    Prev   : BOOL; // <-> [BUS] Mémoire du cycle précédent (détection front IHM)
END_VAR

IF Hmi <> Prev THEN
    Retain := Hmi;
ELSE
    Hmi := Retain;
END_IF;
Prev := Hmi;
