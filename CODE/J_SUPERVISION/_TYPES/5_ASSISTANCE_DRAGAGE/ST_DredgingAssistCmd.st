(* ═══════════════════════════════════════════════════════════════
   🎮 ST_DredgingAssistCmd — Sélections IHM assistance prélèvement
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_DredgingAssistCmd :
STRUCT
    TglEnableDiveSearch         : BOOL := FALSE; (* Assistance plongée active *)
    TglEnableExtractionSequence : BOOL := FALSE; (* Assistance extraction active *)
    TglBucketAtBottomConfirmed  : BOOL := FALSE; (* Attestation manuelle temporaire du fond *)
    // Bypass simplifié de la séquence FB_DiveSearch complète (préconditions
    // strictes -- benne ouverte, DiveStartMin_M, fenêtre immersion). Si TRUE, un front MONTANT
    // Kobold pendant une descente confirme directement le fond, sans passer par l'état-machine
    // FB_DiveSearch (qui continue de tourner en parallèle, inchangée -- utile pour
    // KoboldMeasureEnable). Défaut FALSE : comportement identique à avant (séquence complète
    // seule source de confirmation).
    TglBypassDiveSearchSequence : BOOL := FALSE;
    TglEnableDumpAtTremie       : BOOL := FALSE; (* : mode vidage à la trémie —
                                                     verrouille descente treuils (P1/Maintenance
                                                     uniquement) + translation M3 (proche du haut
                                                     uniquement) ; TRUE par défaut —
                                                     ⚠️ contrairement aux deux autres, ce mode
                                                     RESTREINT des mouvements existants dès le boot *)
END_STRUCT
END_TYPE
