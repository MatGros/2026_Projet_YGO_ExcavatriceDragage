(* =======================================================================
   🔌 ST_fbMachineHomingCycle_BucketCommit — Commit atomique de l'etat benne
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Impulsion 1 scan emise par FB_CycleMachineHoming vers FB_Bucket
             apres succes des DEUX homings. FB_Bucket reste seul proprietaire
             de IsOpen / IsClosed.
   🔒 Sécurité : CommitOpen et CommitClose mutuellement exclusifs (garanti
                 par le corps du FB — rejet du double-confirm, cf. C-2).
   📄 Doc métier : DOC/AF/AF_Partie-05_Modes_Maintenance_v2.1.md
   ======================================================================= *)
TYPE ST_fbMachineHomingCycle_BucketCommit :
STRUCT
    CommitOpen  : BOOL;   (* Publier "benne ouverte" (impulsion 1 scan) *)
    CommitClose : BOOL;   (* Publier "benne fermee" (impulsion 1 scan) *)
END_STRUCT
END_TYPE
