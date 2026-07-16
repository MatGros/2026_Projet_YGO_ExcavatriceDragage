(* ═══════════════════════════════════════════════════════════════
   🌐 GVL_Global — Variables globales d'utilité générale
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Regrouper les signaux et horloges système partagés qui
      ne sont pas spécifiques à la logique de simulation ni raccordés
      à des calibrations persistantes.
   🔧 REX 2026-07-16 : BlinkClock1Hz renommé BlinkClock — alimenté via Util.BLINK
      (asymétrique, durées réglables GVL_PERSISTENT._BlinkTimeOn/_BlinkTimeOff,
      câblage dans PRG_09_Supervision §0). Le nom "1Hz" n'a plus de sens dès que
      le rythme n'est pas symétrique 500ms/500ms.
   💡 Besoin d'un AUTRE rythme pour un voyant particulier (pas celui-ci) ?
      Instancier son propre `BLINK` (lib Util) localement plutôt que de détourner
      ce bit partagé — voir Partie3 §0 (réutilisation obligatoire des libs).
   ═══════════════════════════════════════════════════════════════ *)
{attribute 'qualified_only'}
VAR_GLOBAL
    BlinkClock                 : BOOL;          // Horloge clignotement système (IHM/diag), rythme réglable GVL_PERSISTENT
END_VAR
