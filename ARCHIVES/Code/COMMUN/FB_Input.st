(* ═══════════════════════════════════════════════════════════════
   📥 FB_Input — Entrée TOR conditionnée (brique réduite)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie-06_Acquisition_Qualification_IO_v2.1.md §1
   🧭 Interface RÉDUITE (Partie3 §1bis) : pas de contrat FB standard
      complet (pas d'Enable/StartStop/Mode/State/StateAtError) — brique
      de conditionnement bas niveau, à instancier en tableau (§3) ou
      composée directement dans un FB métier.
   🔁 Rôle : inversion NO/NC, filtrage anti-rebond, diagnostic voie/carte.
   ✅ TRANCHÉ 2026-08-04 : diagnostic carte disponible au niveau MODULE (pas canal) via
      `GetDeviceState()` sur les 3 supports DI (`Local_Digital_IO`, `VH_0800END`, `VH_0808ETP`).
      `ChannelOk` reste à sa valeur par défaut `TRUE` (pas de source par canal individuel
      disponible matériellement) — le diagnostic module est porté séparément par
      `PRG_02_Acquisition` (voir AF06 §3bis), pas par cette brique. Limitation assumée,
      pas un oubli : documentation à revoir si un module diagnostiquant chaque canal est
      installé.
      Intégration dans Winch/Translation : composition directe dans `PRG_04`/`PRG_05` via
      `InputModuleFault` → `SafeStop`, pas de FB_IO générique séparé.
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du POU FB_Input) ===

FUNCTION_BLOCK PUBLIC FB_Input
VAR_INPUT
    InputRaw    : BOOL;         // Signal brut carte d'entrée
    InvertLogic : BOOL;         // TRUE = NC (logique inversée)
    FilterTime  : TIME;         // Tempo anti-rebond (filtrage)
    ChannelOk   : BOOL := TRUE; // Diag voie/carte OK (§4) — TRUE par défaut si pas de diag dispo
END_VAR
VAR_OUTPUT
    State : BOOL;         // Signal conditionné, prêt à l'emploi
    Error       : BOOL;         // Voie en défaut (ChannelOk faux)
    ErrorId     : WORD;         // bit0: "Défaut matériel entrée (Carte HS)" - voie/carte HS
END_VAR
VAR
    FilterTon     : TON;
    ValueRaw      : BOOL;
    FirstScanDone : BOOL;
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_Input) ===

// 1. Inversion NO/NC
ValueRaw := InputRaw XOR InvertLogic;

// 2. Initialisation premier scan & Filtrage anti-rebond
// Au premier scan post-boot, State prend directement la valeur saine brute sans attendre le délai de 20ms,
// ce qui évite d'émettre des fausses alarmes transitoires au démarrage de l'automate.
IF NOT FirstScanDone THEN
    State := ValueRaw;
    FirstScanDone := TRUE;
ELSE
    FilterTon(IN := (ValueRaw <> State), PT := FilterTime);
    IF FilterTon.Q THEN
        State := ValueRaw;   // Une fois à jour, IN redevient FALSE au cycle suivant (ValueRaw=State)
    END_IF;
END_IF;

// 3. Diagnostic voie/carte
IF NOT ChannelOk THEN
    ErrorId := ErrorId OR 16#0001;
    // State conserve sa dernière valeur (hold) — le consommateur décide l'état sûr via Error.
    // FB_Input ne force pas State : il ne connaît pas l'état sûr du signal.
ELSE
    ErrorId := ErrorId AND 16#FFFE;
END_IF;

Error := (ErrorId <> 16#0000);
