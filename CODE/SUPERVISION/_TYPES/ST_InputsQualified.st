(* ═══════════════════════════════════════════════════════════════
   🏗️ ST_InputsQualified — TOR réelles qualifiées (squelette 22 entrées)
   ───────────────────────────────────────────────────────────────
   📄 Lot M1 · Doc : DOC/AF_Partie-06_Acquisition_Qualification_IO_v2.0.md §2ter/§4
   🎨 Une entrée BOOL par TOR réelle qualifiée, organisée par domaine
      (Winch 8 · Translation 7 · Machine 7 = 22).
   🔗 Producteur : PRG_01_Inputs_LD (Ladder, FB_Input) — écrivain unique.
      Lecteur : PRG_02_Acquisition_CFC (seul — alimente le « réel » des domaines TOR).
   ✅ Polarité : TRUE = état logique normalisé (déjà inversé/filtré par FB_Input).
      Filtre appliqué avant la sélection, sur le réel uniquement (décision Q1=A).
      Aucune simulation n'y figure : la bascule réel/simulé vit dans PRG_02.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_InputsQualified :
STRUCT
    Winch       : ST_InputsQualifiedWinch;       (* TOR réelles qualifiées Treuils M1/M2 *)
    Translation : ST_InputsQualifiedTranslation; (* TOR réelles qualifiées Translation M3 *)
    Machine     : ST_InputsQualifiedMachine;     (* TOR réelles qualifiées Sécurités/Communs *)
END_STRUCT
END_TYPE
