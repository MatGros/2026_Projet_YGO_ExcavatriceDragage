(* ═══════════════════════════════════════════════════════════════
   ⏱️ ST_RunningHoursHMI — Compteurs horaires maintenance (PLC→IHM)
   ───────────────────────────────────────────────────────────────
   🎯 Role : totalisateurs de marche pour planification maintenance,
      independants du chrono de cycle (qui se remet a zero par passe).
   🔌 Machine = duree sous tension PLC (toujours active des le boot).
      M1/M2/M3 = duree contacteur marche reel actif (preuve physique).
   💾 Source RETAIN : GVL_PERSISTENT (secondes), converties ici en H:Min.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_RunningHoursHMI :
STRUCT
    MachineHours_H   : DINT; (* Heures entieres, PLC sous tension *)
    MachineHours_Min : INT;  (* Minutes 0..59 *)
    M1Hours_H        : DINT; (* Heures entieres, treuil M1 en marche *)
    M1Hours_Min      : INT;
    M2Hours_H        : DINT; (* Heures entieres, treuil M2 en marche *)
    M2Hours_Min      : INT;
    M3Hours_H        : DINT; (* Heures entieres, translation M3 en marche *)
    M3Hours_Min      : INT;
END_STRUCT
END_TYPE
