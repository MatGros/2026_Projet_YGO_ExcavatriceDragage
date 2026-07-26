(* ═══════════════════════════════════════════════════════════════
   🧪 GVL_PLC_Tests — Points d'injection de pannes pour essais banc
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie-13_Fonction_Simulation_v1.3.md
   🎯 Rôle : forcer artificiellement une entrée physique à un état donné, pour
      reproduire une panne en simulation sans avoir à la câbler réellement.

   🔧 REX 2026-07-26 : le framework de tests automatiques in-PLC (FB_TestSequencer,
      suites de validation, rapports) a été RETIRÉ — empreinte automate trop lourde et
      resynchronisation permanente des suites à chaque évolution métier. Archivé dans
      `ARCHIVES/Code/PLC_TESTS/`. Cette GVL survit car ses `Override*` restent le seul
      moyen d'injecter une panne en essai.

   ⚙️ Qui écrit ces variables désormais :
      - 🖐️ l'opérateur, en forçage manuel (vue instance / liste de surveillance CODESYS)
      - 🖥️ l'IHM, pour les 5 capteurs position M3 uniquement (voir PRG_09_Supervision,
           verrouillé par `GVL_Simulation.SimulationModeActive`)
      👉 Plus aucun automate ne les pilote : tout est à FALSE au boot, donc aucun effet
         de bord possible sur la machine réelle.

   🛡️ RÈGLE : ne JAMAIS forcer une sortie de commande calculée, uniquement une entrée
      physique en amont — un override ne doit pas pouvoir masquer un défaut.
   ═══════════════════════════════════════════════════════════════ *)

{attribute 'qualified_only'}
VAR_GLOBAL
    // ⚡ Chaîne Safety AU — lues par PRG_00_Inputs
    OverrideChainTrue           : BOOL;               // Force la boucle AU à TRUE
    OverrideChainFalse          : BOOL;               // Force la boucle AU à FALSE
    OverrideContactorFalse      : BOOL;               // Force le retour contacteur à FALSE
    OverrideEmergencyStopOkTrue : BOOL;               // Force le retour contacteur à TRUE (réarmé)

    // ⚡ Translation M3 — lues par PRG_00_Inputs, écrites par PRG_09_Supervision depuis l'IHM
    // (niveau capteur amont uniquement, jamais une sortie de commande calculée)
    OverrideM3AtTremie          : BOOL;               // Force TranslationPosTremie (Fdc extrême avant) à TRUE
    OverrideM3BrakeStuckOpen    : BOOL;               // Force M3BrakeFeedback (retour bobine) à TRUE (desserré) — simule Méca B
    OverrideM3PhantomFreq       : BOOL;               // Force M3_ActualFrequencyHz_Filtered à 1.00Hz malgré arrêt commandé — simule Méca A
    // 🆕 REX 2026-07-18 : force directement les 5 capteurs position M3 depuis un mot de test —
    // seul moyen de tester les 6 mots valides ET les combinaisons incohérentes indépendamment
    // du temps de trajet simulé (FB_Sim_Translation). bit4=Trémie,bit3=PV,bit2=P2,bit1=P1,bit0=Maintenance.
    OverrideM3SensorsWordActive : BOOL;               // TRUE = force les 5 capteurs depuis OverrideM3SensorsWord
    OverrideM3SensorsWord       : BYTE;               // Mot de test (voir FB_Translation_PositionDecoder)

    // ⚡ Joystick — lues par PRG_01_Diagnostics (voir FB_Sim_Joystick)
    OverrideJoystickActive      : BOOL;               // TRUE = RawX/Y/Button pilotés par les 3 champs suivants
    OverrideJoystickRawX        : INT;                // Débattement axe X simulé (5000=neutre, 10000=fond)
    OverrideJoystickRawY        : INT;                // Débattement axe Y simulé (5000=neutre, 10000=fond)
    OverrideJoystickRawButton   : BOOL;               // Appui homme-mort simulé

    // 💓 Heartbeat IHM↔PLC — stimulus AMONT uniquement, consommé par PRG_01_Diagnostics.
    // Rien n'écrit dans HeartbeatIhmOk/SafeStop/PowerCutOff calculés.
    OverrideIhmHeartbeatActive  : BOOL;               // TRUE = le forçage fournit le toggle IHM
    OverrideIhmHeartbeatToggle  : BOOL;               // Valeur IHM→PLC : figer pour provoquer le timeout, faire basculer pour simuler une IHM saine

    // 🛡️ Retours d'arrêt M1/M2 — polarité inverse : arrêt confirmé = TRUE. Lues par PRG_00_Inputs.
    OverrideM1FwdRevSpeedFbOff  : BOOL;               // TRUE = contacteurs retombés (sain)
    OverrideM1BrakeFeedback     : BOOL;               // TRUE = frein serré (sain)
    OverrideM2FwdRevSpeedFbOff  : BOOL;               // TRUE = contacteurs retombés (sain)
    OverrideM2BrakeFeedback     : BOOL;               // TRUE = frein serré (sain)

    // 🧹 WINCH-CORE-01 — rejoue la purge des commandes IHM RETAIN du boot, en simulation
    // uniquement (voir PRG_00_Inputs, gardé par GVL_Simulation.SimulationModeActive).
    OverrideHmiCommandPurge     : BOOL;               // TRUE = purge commandes RETAIN dans PRG_00
END_VAR
