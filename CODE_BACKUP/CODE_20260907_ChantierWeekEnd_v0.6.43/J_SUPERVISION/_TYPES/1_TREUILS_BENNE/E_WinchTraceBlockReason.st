(* =======================================================================
   E_WinchTraceBlockReason - Cause de blocage priorisee treuil (trace terrain)
   -----------------------------------------------------------------------
   Role : Ordre de priorite de la cause de blocage d'un treuil M1/M2,
      calcule en PRG_04_Treuils_Benne (#8bis) et publie via Data.TraceM1/M2.
      L'ordre de l'enum EST l'ordre de priorite (valeur croissante = priorite
      decroissante) : la cause la plus grave gagne (PowerCutOff > ... > NONE).
   Producteur unique : PRG_04_Treuils_Benne (#8bis).
   Consommateur : FB_TroubleshootingView (recopie -> GVL_Troubleshooting.TraceM1/2).
   Lecture seule - aucune action de conduite n'en depend.
   Doc metier : DOC/AF/AF_Partie-14_Fonction_Troubleshooting_v1.4.md
   ======================================================================= *)
{attribute 'qualified_only'}
TYPE E_WinchTraceBlockReason :
(
    NONE                    := 0,   // Aucun blocage - au moins un sens effectivement permis
    POWER_CUTOFF            := 1,   // Coupure puissance amont (instSafetyWinch.PowerCutOff) - priorite max
    AXIS_DISABLED           := 2,   // Axe neutralise (Mode=DISABLE ou InhibitMx -> Enable FALSE)
    SAFESTOP                := 3,   // SafeStop effectif (rampe rapide demandee)
    SAFETY_FAULT            := 4,   // Defaut safety latched (FB_Safety_Winch.Fault.Error)
    SAFETY_PERMIT_MISSING   := 5,   // Aucun sens ne delivre de permit safety (limite / mou de cable / homing)
    PROCESS_PERMIT_MISSING  := 6,   // Permit process absent (benne / fond Kobold / limite legale / extraction)
    COUPLING_BLOCKED        := 7,   // Couplage synchro anti-telescopage (l'autre axe bloque)
    WINCH_FAULT             := 8,   // Defaut treuil latched (FB_Winch.Fault.Error)
    FINAL_INTERLOCK_BLOCKED := 9    // Barriere finale en defaut (frein / redemarrage)
);
END_TYPE
