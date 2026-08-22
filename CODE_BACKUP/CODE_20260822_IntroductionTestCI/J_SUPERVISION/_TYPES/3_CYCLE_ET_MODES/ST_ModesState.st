(* ═══════════════════════════════════════════════════════════════
   🚦 ST_ModesState — États et diagnostics IHM des modes de marche
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_ModesState :
STRUCT
    CurrentMode           : E_Mode; (* 🎚️ Mode de marche actuellement actif *)
    PowerContactorEngaged       : BOOL;   (* 🛡️ État de la chaîne d'arrêt d'urgence *)
    AnyFaultActive        : BOOL;   (* : au moins un défaut/alarme actif dans le domaine
                                        sécurité/métier — s'éteint seul quand la cause disparaît ET que
                                        BtnFaultReset a été pressé (OR de tous les .Error du domaine,
                                        même périmètre que BtnFaultReset) *)
    PowerCutOffActive     : BOOL;   (* 🧨 : au moins un Méca A/B/C (FB_Safety_Winch) ou
                                        PowerCutOff Translation actif — TRUE = coupure demandée. Attention :
                                        PowerCutOff_A_RQ/B_RQ (sortie physique réelle) sont à la polarité
                                        INVERSÉE (fail-safe, TRUE=maintenu/OK) — ce champ IHM reste en
                                        polarité "alarme" (TRUE=problème) pour cohérence avec AnyFaultActive *)
    EmergencyChainOk      : BOOL;   (* 🔗 Boucle AU saine (coup-de-poing relâchés + pas de PowerCutOff PLC actif) *)
    PowerContactorOk      : BOOL;   (* 🔌 Contacteur de puissance confirmé engagé (miroir PowerContactorEngaged) *)
    EmergencyArmable      : BOOL;   (* 🟢 Réarmement possible maintenant (chaîne saine, ni séquence ni verrouillage en cours,
                                        ni RedundancyTestFailed) *)
    EmergencyArmingBusy   : BOOL;   (* ⏳ Auto-test A/B, pulse, confirmation OU verrouillage 5s en cours — nouvelle demande ignorée *)
    RedundancyTestFailed  : BOOL;   (* Canal A ou B non fonctionnel détecté à l'auto-test — bloque tout réarmement (front Reset requis) *)
    EmergencyArmingFailed : BOOL;   (* Impulsion envoyée mais contacteur puissance jamais confirmé sous 2s (front Reset + contacteur confirmé requis) *)
END_STRUCT
END_TYPE
