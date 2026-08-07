(* ═══════════════════════════════════════════════════════════════
   🎮 ST_DredgingAssistCmd — Sélections IHM assistance prélèvement
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_DredgingAssistCmd :
STRUCT
    TglEnableDiveSearch         : BOOL := TRUE;  (* Assistance plongée active *)
    TglEnableExtractionSequence : BOOL := TRUE;  (* Assistance extraction active *)
    TglBucketAtBottomConfirmed  : BOOL := FALSE; (* Attestation manuelle temporaire du fond *)
    TglEnableDumpAtTremie       : BOOL := FALSE; (* 🆕 2026-08-07 : mode vidage à la trémie —
                                                     verrouille descente treuils (P1/Maintenance
                                                     uniquement) + translation M3 (proche du haut
                                                     uniquement) ; défaut FALSE, n'active aucune
                                                     restriction tant que non armé explicitement *)
END_STRUCT
END_TYPE
