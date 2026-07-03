(* ═══════════════════════════════════════════════════════════════
   🐞 GVL_DEBUG — Variables de simulation/bypass génériques (existant, non versionné jusqu'ici)
   ───────────────────────────────────────────────────────────────
   🔧 AJOUT (2026-07-03quater) : `DBG_EmergencyStopOkBypass_TEST` — bypass banc de test pour
      `EmergencyStopOk` (voir PRG_MAIN.st §1, instIoMachine). ⚠️ TOUJOURS FALSE en exploitation
      réelle — à remettre à FALSE (ou retirer le OR dans PRG_MAIN) avant tout essai réel avec
      la chaîne AU effectivement câblée. Suivi comme point bloquant (AUDIT).
   🔧 AJOUT (2026-07-03quinquies) : `DBG_TopPositionSensorBypass_TEST` — même principe pour
      `M1_M2_TopPositionSensor` (capteur position haute réel, commun M1/M2) : permet de
      re-déclencher un `Home` sur banc sans devoir actionner physiquement le capteur à
      chaque fois. ⚠️ TOUJOURS FALSE en exploitation réelle.
   🔧 AJOUT (2026-07-03octodecies, demande utilisateur) : `DBG_DeadmanBypass_TEST` — homme-mort
      `FB_Joystick` en investigation (comportement jugé gênant en essai), pas le temps de
      déboguer dans l'immédiat. Force l'armement en permanence (bouton plus nécessaire pour
      bouger le joystick). ⚠️ TOUJOURS FALSE en exploitation réelle — à restreindre par Mode
      (ex. MAINT_N1 seul) dès que l'arbitrage voulu par IHM sera précisé (AUDIT D70).
   🔧 AJOUT (2026-07-03vicies, demande utilisateur, AUDIT D73) : `DBG_ContactorFeedbackBypass_TEST`
      — sans contacteurs réels câblés/cohérents en essai (`FB_Winch`/`FB_Chariot`), le contrôle
      StuckClosed/StuckOpen (commande/retour incohérente > `ContactorFeedbackTimeout`) se
      déclenche à tort et bloque `RelayFwd`/`RelayRev`. ⚠️ TOUJOURS FALSE en exploitation réelle.
      Pour le thermique/mou de câble (simples variables `GVL_IN`), pas besoin de flag dédié :
      **Force** directement la variable dans CODESYS (le Force prend le dessus sur l'écriture
      cyclique du programme, contrairement à un simple Write).
   🔧 AJOUT (2026-07-03unvicies, créé par l'utilisateur) : `DBG_CtrlPhaseRotation_Bypass_TEST` —
      bypass dédié pour `CtrlPhaseRotation_DI`, OR'é sur le signal brut dans `FB_InputsMachine`
      (même principe que `DBG_EmergencyStopOkBypass_TEST`/`DBG_TopPositionSensorBypass_TEST`).
      ⚠️ TOUJOURS FALSE en exploitation réelle avec le vrai contrôle de rotation câblé.
   🔧 AJOUT (2026-07-03duovicies, créé par l'utilisateur) : `DBG_SlackCableSwitch_TEST` — même
      principe pour `M1_M2_SlackCableSwitch_DI`. Câblage sécurité (TRUE=OK, pas de mou) : le
      bypass force donc l'état OK. ⚠️ TOUJOURS FALSE en exploitation réelle avec le vrai
      capteur mou de câble câblé.
   ═══════════════════════════════════════════════════════════════ *)

{attribute 'qualified_only'}
VAR_GLOBAL
	DBG_True : BOOL := TRUE; //(Remplace les TRUE codéS en dur).
	DBG_False : BOOL := FALSE; //(Remplace les FALSE codéS en dur).
	DBG_Blink_1Hz : BOOL;// (Horloge générée par un clignoteur pour simuler un capteur).
	DBG_ForceNeutral : INT := 5000; //(Pour simuler le retour au centre).
	DBG_ForceMax : INT := 10000; //(Pour simuler une consigne à fond).

	// 🔴 BYPASS TEST BANC — TOUJOURS FALSE en exploitation réelle (chaîne AU câblée)
	DBG_EmergencyStopOkBypass_TEST : BOOL := FALSE; // TRUE = force EmergencyStopOk réel à TRUE (test banc sans AU câblé)
	// 🔴 BYPASS TEST BANC — TOUJOURS FALSE en exploitation réelle (capteur position haute câblé)
	DBG_TopPositionSensorBypass_TEST : BOOL := FALSE; // TRUE = force M1_M2_TopPositionSensor à TRUE (test banc, re-homing sans actionner le capteur)
	// 🔴 BYPASS TEST BANC — TOUJOURS FALSE en exploitation réelle (homme-mort actif)
	DBG_DeadmanBypass_TEST : BOOL := FALSE; // TRUE = force DeadmanArmed à TRUE en permanence (bouton non nécessaire, essais joystick)
	// 🔴 BYPASS TEST BANC — TOUJOURS FALSE en exploitation réelle (contacteurs réels câblés/cohérents)
	DBG_ContactorFeedbackBypass_TEST : BOOL := FALSE; // TRUE = désactive StuckClosed/StuckOpen (FB_Winch/FB_Chariot), pas de blocage RelayFwd/RelayRev sans retour contacteur réel
	// 🔴 BYPASS TEST BANC — TOUJOURS FALSE en exploitation réelle (contrôle rotation phase câblé)
	DBG_CtrlPhaseRotation_Bypass_TEST : BOOL := FALSE; // TRUE = force CtrlPhaseRotation_DI à TRUE (test banc sans le vrai contrôle de rotation câblé)
	// 🔴 BYPASS TEST BANC — TOUJOURS FALSE en exploitation réelle (capteur mou de câble câblé)
	DBG_SlackCableSwitch_TEST : BOOL := FALSE; // TRUE = force M1_M2_SlackCableSwitch_DI à TRUE (test banc sans le vrai capteur mou de câble câblé)
END_VAR
