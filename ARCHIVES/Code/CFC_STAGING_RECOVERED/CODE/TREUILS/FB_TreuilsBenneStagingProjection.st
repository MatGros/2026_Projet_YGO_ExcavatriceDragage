(* ═══════════════════════════════════════════════════════════════
   🪝 FB_TreuilsBenneStagingProjection — Publication staging M3
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : publier explicitement les résultats safety M1/M2 déjà
      calculés par le POU legacy, sans produire de commande ni sortie.

   🔒 Staging uniquement : ce FB est appelé par PRG_04_Treuils_Benne_CFC,
      qui n'est pas inscrit dans MainTask. Il ne remplace pas FB_Safety_Winch
      et ne crée donc aucun second écrivain actif de SafeStop/PowerCutOff.

   📄 Réfs : RU_C4_ARCHITECTURE_PROCEDES, registre A-11.
   ═══════════════════════════════════════════════════════════════ *)
FUNCTION_BLOCK FB_TreuilsBenneStagingProjection
VAR_INPUT
    LegacyM1SafeStop     : BOOL;
    LegacyM1PowerCutOff  : BOOL;
    LegacyM2SafeStop     : BOOL;
    LegacyM2PowerCutOff  : BOOL;
END_VAR
VAR_OUTPUT
    M1SafeStop           : BOOL;
    M1PowerCutOff        : BOOL;
    M2SafeStop           : BOOL;
    M2PowerCutOff        : BOOL;
END_VAR

(* Copie volontairement exacte des observations legacy : aucun arbitrage ici. *)
M1SafeStop := LegacyM1SafeStop;
M1PowerCutOff := LegacyM1PowerCutOff;
M2SafeStop := LegacyM2SafeStop;
M2PowerCutOff := LegacyM2PowerCutOff;
