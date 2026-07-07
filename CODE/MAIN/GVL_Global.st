(* ═══════════════════════════════════════════════════════════════
   🌐 GVL_Global — Variables globales d'utilité générale
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Regrouper les signaux et horloges système partagés qui
      ne sont pas spécifiques à la logique de simulation ni raccordés
      à des calibrations persistantes.
   ═══════════════════════════════════════════════════════════════ *)
{attribute 'qualified_only'}
VAR_GLOBAL
    BlinkClock1Hz              : BOOL;          // Horloge 1Hz pour clignotements (IHM ou diagnostic)
END_VAR
