(* ═══════════════════════════════════════════════════════════════
   🧪 GVL_Homing_Stub — Capteur position haute COMMUN aux 2 treuils
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie10_Fonction_Encoder_Homing_v1.3.md §1/§5/§7bis
   🔧 CORRECTIF (2026-07-02, retour terrain) : il n'existe qu'UN SEUL capteur
      physique de position haute, PAS un par treuil — les 2 câbles (M1/M2)
      hissent ensemble le même ensemble mécanique qui vient toucher ce
      capteur unique. Précédemment câblé à tort comme 2 signaux séparés
      (`M1_TopPositionSensor`/`M2_TopPositionSensor`, un par GVL stub
      Winch). Corrigé ici : UNE seule variable, câblée IDENTIQUEMENT sur
      les 2 instances FB_Encoder_Homing (M1 et M2) dans PRG_MAIN.st.
   ⚠️ Nom volontairement NEUTRE (`TopPositionSensor`, sans préfixe métier) :
      la terminologie exacte de l'ensemble mécanique concerné (en cours de
      clarification avec l'utilisateur) sera reprise lors d'une session de
      synchronisation documentaire globale — ne pas anticiper ce nommage ici.
   ⚠️ TEMPORAIRE — aucun capteur réel câblé. Reste FALSE tant que non
      forcé manuellement (sécurité : ne jamais simuler un signal
      safety-relevant comme actif par défaut).
   🔴 QUAND LE MATÉRIEL SERA PRÊT : SUPPRIMER ce GVL, saisir le MÊME nom
      directement en I/O Mapping (comme les autres stubs Winch/Translation).
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du GVL GVL_Homing_Stub) ===

VAR_GLOBAL
    TopPositionSensor   : BOOL;   // 🔌 Entrée — capteur position haute UNIQUE, commun M1+M2 (STUB, toujours FALSE)
END_VAR
