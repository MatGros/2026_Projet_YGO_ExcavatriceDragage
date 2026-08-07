(* ═══════════════════════════════════════════════════════════════
   🎮 ST_DredgingAssistCmd — Sélections IHM assistance prélèvement
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_DredgingAssistCmd :
STRUCT
    TglEnableDiveSearch         : BOOL := TRUE;  (* Assistance plongée active *)
    TglEnableExtractionSequence : BOOL := TRUE;  (* Assistance extraction active *)
    TglBucketAtBottomConfirmed  : BOOL := FALSE; (* Attestation manuelle temporaire du fond *)
    TglEnableDumpAtTremie       : BOOL := TRUE;  (* 🆕 2026-08-07 : mode vidage à la trémie —
                                                     verrouille descente treuils (P1/Maintenance
                                                     uniquement) + translation M3 (proche du haut
                                                     uniquement) ; TRUE par défaut (2026-08-07,
                                                     décision utilisateur, cohérent avec
                                                     TglEnableDiveSearch/TglEnableExtractionSequence) —
                                                     ⚠️ contrairement aux deux autres, ce mode
                                                     RESTREINT des mouvements existants dès le boot *)
END_STRUCT
END_TYPE
