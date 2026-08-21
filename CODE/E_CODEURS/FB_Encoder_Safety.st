(* =======================================================================
   🛡️ FB_Encoder_Safety — Bornage physique & surveillance cohérence
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Bornage physique absolu [-99; +99]m et relais d'incohérence redémarrage
   🔒 Polarité : EncoderIncoherent=TRUE en cas de hors bornes ou HomingSuspect
   🛡️ Sécurité : Verrouillage de la position câble sûre
   📄 Doc métier : DOC/AF/AF_Partie-09_Fonction_Encoder_v2.1.md
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
    // 🧩 Statut transverse (forme cible) — regroupe Busy/Done/Error/ErrorId/State/StateAtError.
    // ErrorId bit0: "Bornes", bit1: "Boot suspect".
    Status                : ST_FbStatus;

    // === MESURES SURE & SECURITE ===
    CablePosMSafe         : REAL;        // <-- [DIAG] Position cable instantanee transmise (m)
    EncoderIncoherent     : BOOL;        // <-- [SAFE] Incoherence ou hors bornes (TRUE = defaut)
END_VAR
VAR
    // === DETECTEURS DE FRONT ===
    ResetEdge             : R_TRIG;      // . [LOC] Detecteur front montant Reset
    ErrorEdge             : R_TRIG;      // . [LOC] Detecteur front montant Error
END_VAR

{region "§1 Gate"}
// 🛑 1. GATE
IF NOT Enable THEN
    Ready := FALSE; Status.Busy := FALSE; Status.Done := FALSE;
    Status.State := E_State.DISABLED;
    CablePosMSafe := CablePosM;
    EncoderIncoherent := FALSE;
    RETURN;
END_IF;

Ready := TRUE;
Status.State := E_State.READY;
{endregion}

{region "§2 Reset front"}
// 🔑 2. RESET FRONT
ResetEdge(CLK := Reset);
{endregion}

{region "§3 Bypass global"}
// 🌐 3. BYPASS GLOBAL
IF BypassGlobal THEN
    Status.ErrorId := 16#0000;
END_IF;
{endregion}

{region "§4 Surveillance bornage"}
// 🔍 4. SURVEILLANCE BORNAGE PHYSIQUE ABSOLU (bit0)
IF NOT BypassGlobal AND ((CablePosM < PositionMinM) OR (CablePosM > PositionMaxM)) THEN
    Status.ErrorId := Status.ErrorId OR 16#0001;
ELSE
    Status.ErrorId := Status.ErrorId AND 16#FFFE; (* Auto-clearing dès retour dans la plage *)
END_IF;
{endregion}

{region "§5 Relais incohérence redémarrage"}
// 🔍 5. RELAIS INCOHÉRENCE REDÉMARRAGE (bit1)
IF NOT BypassGlobal THEN
    IF HomingSuspect THEN
        Status.ErrorId := Status.ErrorId OR 16#0002;
    ELSE
        Status.ErrorId := Status.ErrorId AND 16#FFFD;
    END_IF;
END_IF;
{endregion}

{region "§6 Transmission mesure"}
// 📏 6. TRANSMISSION DE LA MESURE (Toujours réelle, non figée)
CablePosMSafe := CablePosM;
{endregion}

{region "§7 Sorties état et sécurité"}
// 📤 7. SORTIES ÉTAT & SÉCURITÉ
Status.Error := (Status.ErrorId <> 16#0000);
ErrorEdge(CLK := Status.Error);
IF ErrorEdge.Q THEN
    Status.StateAtError := Status.State;
END_IF;

EncoderIncoherent := Status.Error;
Status.Busy := FALSE;
Status.Done := FALSE;
{endregion}
