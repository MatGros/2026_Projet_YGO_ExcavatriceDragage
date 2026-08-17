(* ═══════════════════════════════════════════════════════════════
   ⚙️ ST_BucketConfig — Configuration des offsets du benne
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF/AF_Partie-10_Fonction_Winch/FB_Bucket_v1.0.md §4.A
   ═══════════════════════════════════════════════════════════════ *)

TYPE ST_BucketConfig :
STRUCT
    OffsetOpenM     : REAL;    (* Écart M1/M2 en mètres benne ouvert *)
    OffsetCloseM    : REAL;    (* Écart M1/M2 en mètres benne fermé *)
    CoherenceLimitM : REAL;    (* Seuil de détection d'incohérence au boot *)
    // 🆕 2026-08-07 (20) — retour terrain, demande client : inertie mécanique du benne (M2 continue
    // sur sa lancée après coupure StartStop) -- couper la commande EN AVANCE de la cible pour que
    // l'arrêt réel (après coast-down) tombe proche du vrai offset, au lieu de dépasser. Anticipation
    // distincte par sens (fermeture/ouverture ont des inerties différentes selon retour terrain).
    CloseAnticipationM : REAL := 1.0; (* Coupe la commande de fermeture 1m avant OffsetCloseM *)
    OpenAnticipationM  : REAL := 1.3; (* Coupe la commande d'ouverture 1.3m avant OffsetOpenM *)
END_STRUCT
END_TYPE
