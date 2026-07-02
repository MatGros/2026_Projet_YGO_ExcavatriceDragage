(* ═══════════════════════════════════════════════════════════════
   📥 FB_Input_Digital — Entrée TOR conditionnée (brique réduite)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie6_IO_Conditioning_v1.1.md §1
   🧭 Interface RÉDUITE (Partie3 §1bis) : pas de contrat FB standard
      complet (pas d'Enable/StartStop/Mode/State/StateAtError) — brique
      de conditionnement bas niveau, à instancier en tableau (§3) ou
      composée directement dans un FB métier.
   🔁 Rôle : inversion NO/NC, filtrage anti-rebond, diagnostic voie/carte.
   🔴 INTÉGRATION dans Winch/Chariot/etc. : PAS encore décidée (choix
      d'architecture en attente — composition interne vs FB_IO générique
      séparé). Ce fichier ne fait QUE créer la brique elle-même.
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du POU FB_Input_Digital) ===

FUNCTION_BLOCK PUBLIC FB_Input_Digital
VAR_INPUT
    InputRaw    : BOOL;         // Signal brut carte d'entrée
    InvertLogic : BOOL;         // TRUE = NC (logique inversée)
    FilterTime  : TIME;         // Tempo anti-rebond (filtrage)
    ChannelOk   : BOOL := TRUE; // Diag voie/carte OK (§4) — TRUE par défaut si pas de diag dispo
END_VAR
VAR_OUTPUT
    OutputClean : BOOL;         // Signal conditionné, prêt à l'emploi
    Error       : BOOL;         // Voie en défaut (ChannelOk faux)
    ErrorId     : WORD;         // bit0 : voie/carte HS
END_VAR
VAR
    FilterTon   : TON;
    ValueRaw    : BOOL;
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_Input_Digital) ===

// 1. Inversion NO/NC
ValueRaw := InputRaw XOR InvertLogic;

// 2. Filtrage anti-rebond — ne valide le changement d'état qu'après FilterTime stable
FilterTon(IN := (ValueRaw <> OutputClean), PT := FilterTime);
IF FilterTon.Q THEN
    OutputClean := ValueRaw;   // Une fois à jour, IN redevient FALSE au cycle suivant (ValueRaw=OutputClean)
END_IF;

// 3. Diagnostic voie/carte
IF NOT ChannelOk THEN
    ErrorId := ErrorId OR 16#0001;
    OutputClean := FALSE;   // État sûr forcé (Partie6 §1)
ELSE
    ErrorId := ErrorId AND 16#FFFE;
END_IF;

Error := (ErrorId <> 16#0000);
