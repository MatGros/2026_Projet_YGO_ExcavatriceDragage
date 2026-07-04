(* ═══════════════════════════════════════════════════════════════
   ⚡ PRG_8_AuxiliaryControl — Gestion des Auxiliaires (Hydraulique, Crible...)
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 8.
   ✅ Regroupe toutes les commandes et logiques hors-axes.
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_8_AuxiliaryControl
VAR
    // 🌡️ Groupe Hydraulique
    HydraulicPumpRunCmd   : BOOL;   // Commande démarrage centrale hydraulique
    HydraulicFaultOk      : BOOL;   // Retour défaut groupe hydraulique (NC)

    // 🌾 Crible (Sifter / Sieve)
    SifterRunCmd          : BOOL;   // Commande marche crible
    SifterFaultOk         : BOOL;   // Retour défaut électrique crible (NC)
    
    // 🔗 Divers
    GridOpenCmd           : BOOL;   // Commande ouverture grille
    HelmetCloseCmd        : BOOL;   // Commande fermeture casque
END_VAR

// === IMPLEMENTATION (corps du PROGRAM PRG_8_AuxiliaryControl) ===

// --- STUBS LOGIQUES TEMPORAIRES (comportement passif / neutre) ---
HydraulicPumpRunCmd := FALSE;
SifterRunCmd        := FALSE;
GridOpenCmd         := FALSE;
HelmetCloseCmd      := FALSE;

HydraulicFaultOk    := TRUE; // Par défaut sain (NC)
SifterFaultOk       := TRUE; // Par défaut sain (NC)
