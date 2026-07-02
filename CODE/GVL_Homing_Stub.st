(* ═══════════════════════════════════════════════════════════════
   🧪 GVL_Homing_Stub — Capteur position haute COMMUN aux 2 treuils
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie10_Fonction_Encoder_Homing_v1.3.md §1/§5/§7bis
   🔧 CORRECTIF (2026-07-02, retour terrain) : il n'existe qu'UN SEUL capteur
      physique de position haute, PAS un par treuil — c'est le grappin qui,
      en montant (tracté par les 2 câbles synchronisés), vient toucher ce
      capteur unique. Précédemment câblé à tort comme 2 signaux séparés
      (`M1_TopPositionSensor`/`M2_TopPositionSensor`, un par GVL stub
      Winch) alors que le §1 de la doc décrivait déjà correctement un
      "capteur de position haute unique et répétable" — divergence entre
      doc et implémentation, corrigée ici : UNE seule variable, câblée
      IDENTIQUEMENT sur les 2 instances FB_Encoder_Homing (M1 et M2) dans
      PRG_MAIN.st.
   ⚠️ TEMPORAIRE — aucun capteur réel câblé. Reste FALSE tant que non
      forcé manuellement (sécurité : ne jamais simuler un signal
      safety-relevant comme actif par défaut).
   🔴 QUAND LE MATÉRIEL SERA PRÊT : SUPPRIMER ce GVL, saisir le MÊME nom
      directement en I/O Mapping (comme les autres stubs Winch/Chariot).
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du GVL GVL_Homing_Stub) ===

VAR_GLOBAL
    GrappinTopPositionSensor   : BOOL;   // 🔌 Entrée — capteur position haute UNIQUE (grappin), commun M1+M2 (STUB, toujours FALSE)
END_VAR
