(* ═══════════════════════════════════════════════════════════════
   🧪 GVL_Translation_M3_Stub — Entrées de simulation M3 restantes
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie-12_Fonction_Translation_v2.0.md §7
   🧹 REX 2026-07-18 : ancien mode relais `DEGRADED_IO` retiré. Les sorties relais,
      retours contacteurs, défaut TOR et cible générique sans consommateur sont supprimés.
      Restent uniquement PV (entrée réelle à mapper) et le sélecteur de trajet simulé.
   ═══════════════════════════════════════════════════════════════ *)

VAR_GLOBAL

    // 🆕 REX 2026-07-18 : décision client (AF_Partie-02 v2.12 §3bis) — 5 capteurs Trémie|PV|P2|P1|
    // Maintenance. PV n'est JAMAIS une cible sélectionnable (point de ralentissement seul).
    StubTranslationPositionSelect_IHM : INT := 0;   // 🖥️ Sélecteur test maintenance (0=Aucun, 1=Trémie, 2=P2, 3=P1, 4=Maintenance)

END_VAR
