(* ═══════════════════════════════════════════════════════════════
   🚨 ST_AlarmBanner — Bandeau d'alarme defilant (carrousel n/N)
   ───────────────────────────────────────────────────────────────
   🎯 Role : liste les defauts/warnings actifs de toute la machine,
      affiches un a la fois en rotation (FB_Hmi_BannerFormatter S5)
   📄 Doc : DOC/AF/AF_Partie-07_Interface_IHM_v2.2.md S6
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_AlarmBanner :
STRUCT
    HasAlarm  : BOOL;        (* TRUE = au moins un defaut/warning actif *)
    Text      : STRING(120); (* Texte du message courant : [ORGANE] raison breve *)
    Index     : INT;         (* Position courante (1-based, 0 si aucun defaut) *)
    Count     : INT;         (* Nombre total de messages actifs *)
END_STRUCT
END_TYPE
