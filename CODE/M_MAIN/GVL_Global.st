(* ═══════════════════════════════════════════════════════════════
   🌐 GVL_Global — Variables globales d'utilité générale
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Horloges et signaux système partagés non persistants.
   📄 Docs : DOC/AF/AF_Partie-02_Architecture_Programme_v3.2.md
   ═══════════════════════════════════════════════════════════════ *)
{attribute 'qualified_only'}
VAR_GLOBAL
    BlinkClock                 : BOOL; // Horloge clignotement système (IHM/diag), rythme réglable GVL_PERSISTENT
END_VAR
