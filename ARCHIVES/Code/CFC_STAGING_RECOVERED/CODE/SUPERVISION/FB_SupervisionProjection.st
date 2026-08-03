(* ═══════════════════════════════════════════════════════════════
   👁️ FB_SupervisionProjection — Adaptateur de projection supervision (staging M6)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : point d'ancrage CFC strictement lecture seule de la future
      supervision au rang 07.

   🔒 Sécurité : n'écrit ni commande, ni configuration, ni bypass,
      ni interlock, ni sortie physique. Il ne consomme aucun interne
      de POU legacy.

   📌 Migration : les projections IHM et les cinq vues troubleshooting
      restent aujourd'hui produites par PRG_SUPERVISION_CFC et
      PRG_TROUBLESHOOTING_CFC actifs. Les contrats publics des domaines
      ne sont pas encore publiés; aucun miroir incomplet n'est créé ici.
      Le basculement ne pourra avoir lieu qu'après publication des états
      Acquisition / Treuils-Benne / Translation / Outputs.

   📄 Réfs : AF02 §2, AF03 §1/§5, AF07 §5, AF12 §5, AF14
   ═══════════════════════════════════════════════════════════════ *)
FUNCTION_BLOCK FB_SupervisionProjection
VAR_INPUT
    Enable : BOOL; // Active uniquement l'adaptateur de projection, sans effet machine.
END_VAR
VAR_OUTPUT
    Ready : BOOL;  // TRUE si l'adaptateur staging est appelable.
END_VAR

// Projection staging neutre : aucun accès aux GVL IHM, aux POU ou aux sorties.
Ready := Enable;
