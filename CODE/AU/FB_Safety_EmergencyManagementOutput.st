(* ═══════════════════════════════════════════════════════════════
   📤 FB_Safety_EmergencyOutput — Pilote Physique de Sécurité
   ───────────────────────────────────────────────────────────────
   📄 Rôle : Transmet les ordres de sécurité logiques vers les 
      sorties physiques de l'automate (relais d'AU A/B/Impulsion).
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK PUBLIC FB_Safety_EmergencyManagementOutput
VAR_INPUT
    Enable              : BOOL;        // Active le pilote
    Cmd                 : ST_EmergencyManagementCmd; // Ordres logiques reçus du bloc logique
END_VAR
VAR_OUTPUT
    PowerCutOff_A_RQ    : BOOL;        // Vers le relais de coupure physique A
    PowerCutOff_B_RQ    : BOOL;        // Vers le relais de coupure physique B
    EmergencyArming_RQ  : BOOL;        // Vers le contacteur d'impulsion de réarmement
END_VAR

// === IMPLEMENTATION ===

IF NOT Enable THEN
    PowerCutOff_A_RQ   := FALSE;
    PowerCutOff_B_RQ   := FALSE;
    EmergencyArming_RQ := FALSE;
    RETURN;
END_IF;

// Écriture directe des signaux logiques sur les sorties physiques (fail-safe)
PowerCutOff_A_RQ   := Cmd.PowerCutOff_A_Cmd;
PowerCutOff_B_RQ   := Cmd.PowerCutOff_B_Cmd;
EmergencyArming_RQ := Cmd.EmergencyArming_Cmd;
