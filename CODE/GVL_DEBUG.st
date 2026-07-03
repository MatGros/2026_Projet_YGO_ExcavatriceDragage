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
END_VAR
