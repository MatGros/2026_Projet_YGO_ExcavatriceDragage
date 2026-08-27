(* =======================================================================
   🛡️ FB_Encoder_Safety — Bornage physique & surveillance cohérence
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Bornage physique absolu [-99; +99]m et relais d'incohérence redémarrage
   🔒 Polarité : EncoderIncoherent=TRUE en cas de hors bornes ou HomingSuspect
   🛡️ Sécurité : Verrouillage de la position câble sûre
   📄 Doc métier : DOC/AF/AF_Partie-09_Fonction_Encoder_v2.3.md
   ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_Encoder_Safety
VAR_INPUT
    // === COMMANDES & AUTORISATIONS ===
    Enable                : BOOL;        // --> [CMD] Autorisation generale FB (TRUE=Autorise)
    Reset                 : BOOL;        // --> [CMD] Acquittement defaut (front montant)

    // === MESURES & ALERTE HOMING ===
    CablePosM             : REAL;        // --> [HW]  Position calculee (m, sortie FB_Encoder_Scale)
    HomingSuspect         : BOOL;        // --> [SAFE] Alerte incoherence redemarrage (FB_Encoder_Homing)

    // === REGLAGES & BORNES PHYSIQUES ===
    PositionMinM          : REAL := -99.0; // --> [CFG] Plafond bornage physique bas (m)
    PositionMaxM          : REAL := 99.0;  // --> [CFG] Plafond bornage physique haut (m)

    // === TESTS & BYPASS ===
    BypassGlobal          : BOOL := FALSE; // --> [TST] Neutralisation defaut de bornage pour mise en service
END_VAR
VAR_OUTPUT
    // === ETATS IEC & SYNOPTIQUE ===
    Ready                 : BOOL;        // <-- [STAT] FB pret a fonctionner
    // 🧩 Statut transverse (forme cible ST_Fault)
    Fault                 : ST_Fault;

    // === MESURES SURE & SECURITE ===
    CablePosMSafe         : REAL;        // <-- [DIAG] Position cable instantanee transmise (m)
    EncoderIncoherent     : BOOL;        // <-- [SAFE] Incoherence ou hors bornes (TRUE = defaut)
END_VAR
VAR
    // === DETECTEURS DE FRONT ===
    ResetEdge             : R_TRIG;      // . [LOC] Detecteur front montant Reset

    // === SOCLE DEFAUT (FB_FaultCore) ===
    instFault             : FB_FaultCore;                   // * [INST] Socle défaut transverse
    instCauses            : ARRAY[0..15] OF ST_FaultCause;  // . [LOC] Table des causes nommées
END_VAR

// === IMPLEMENTATION ===

{region "§1 Causes & Socle Défaut (évalué en continu)"}
// 🔑 1. RESET FRONT
ResetEdge(CLK := Reset);

// 🔍 2. SURVEILLANCE BORNAGE & INCOHÉRENCE BOOT
instCauses[0].Active   := NOT BypassGlobal AND ((CablePosM < PositionMinM) OR (CablePosM > PositionMaxM));
instCauses[0].Latching := FALSE;
instCauses[0].Texte    := 'Depassement bornes physiques absolues cable';

instCauses[1].Active   := NOT BypassGlobal AND HomingSuspect;
instCauses[1].Latching := FALSE;
instCauses[1].Texte    := 'Incoherence position au redemarrage';

// Appel du socle de défaut
instFault(Enable := Enable, Reset := Reset, Causes := instCauses);
Fault := instFault.Fault;
{endregion}

{region "§2 Gate neutralisation"}
// 🛑 2. GATE
IF NOT Enable THEN
    Ready := FALSE;
    CablePosMSafe := CablePosM;
    EncoderIncoherent := FALSE;
    RETURN;
END_IF;

Ready := Enable AND NOT Fault.Latched;
{endregion}

{region "§3 Transmission mesure et sécurité"}
// 📏 3. TRANSMISSION DE LA MESURE & SÉCURITÉ
CablePosMSafe := CablePosM;
EncoderIncoherent := Fault.Error;
{endregion}
