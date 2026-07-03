(* ═══════════════════════════════════════════════════════════════
   🏭 GVL_Machine_Stub — Variables IHM transverses machine (Lot A mise en service)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie3_Template_FB_Commun_v1.3.md §5 (bouton général)
   🎯 `MachineReset_IHM` : bouton acquittement GÉNÉRAL (front) — distribué à TOUTES les
      instances (diag, modes, safety, winch, chariot, winchsync + OR-é avec les boutons
      par codeur M1/M2_Reset_IHM). Partie3 §5 : « bouton général ».
   🔧 CORRECTIF (2026-07-03quindecies) : `PowerCutOffCmd` retiré — relais réel câblé en
      I/O Mapping (`PowerCutOff_RQ`), voir PRG_MAIN.st §8.
   🔴 TOUJOURS STUB (pas de vrai bouton IHM câblé) : `MachineReset_IHM` se force en vue
      instance CODESYS (TRUE puis FALSE = front).
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du GVL GVL_Machine_Stub) ===

VAR_GLOBAL
    // 🔑 Acquittement général machine (front) — acquitte TOUS les FB d'un coup
    MachineReset_IHM : BOOL;   // 🖥️ À mapper bouton IHM — basculer TRUE puis FALSE pour simuler l'appui
END_VAR
