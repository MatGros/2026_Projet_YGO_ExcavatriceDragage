(* =======================================================================
   ST_TraceWinch - Trace de blocage terrain d'un treuil M1/M2
   -----------------------------------------------------------------------
   Role : Publier au technicien une vue consolidee "pourquoi l'axe ne bouge
   pas" : permis effectifs par sens, source du SafeStop/coupure, cause de
   blocage priorisee et horodatee.
   Producteur unique : PRG_04_Treuils_Benne (#8bis) - 1 instance par axe
       (TraceM1 / TraceM2 au sein de ST_WinchInterPrg).
   Consommateur : FB_TroubleshootingView (pure recopie -> GVL_Troubleshooting).
   Lecture seule - aucun calcul de commande n'en depend.
   BlockReasonTimestamp : ms depuis demarrage PLC (TIME()), latched au dernier
       changement de BlockReason (1 scan, memoire).
   Doc metier : DOC/AF/AF_Partie-14_Fonction_Troubleshooting_v1.4.md
   ======================================================================= *)
TYPE ST_TraceWinch :
STRUCT
    // Permis effectifs par sens (reflet exact des permis appliques au mouvement)
    DescendPermitEffective  : BOOL;   // Descente effectivement permise (EffectivePermit*_Descend)
    AscentPermitEffective   : BOOL;   // Montee effectivement permise (EffectivePermit*_Ascent)
    AscentPermitApplied      : BOOL;   // Permis effectivement transmis a la barriere finale
    DescendPermitApplied     : BOOL;   // Permis effectivement transmis a la barriere finale
    FinalPermitBlocked       : BOOL;   // Demande presente mais refusee par le permis final

    // Source de SafeStop / coupure - pour distinguer l'origine du blocage
    SafeStopActive          : BOOL;   // SafeStop effectif applique (SafeStop*_Active)
    SafeStopSourceSafety    : BOOL;   // SafeStop issu de FB_Safety_Winch (defaut safety)
    SafeStopSourceInput     : BOOL;   // SafeStop issu du module d'entree / homing / slip benne
    SafeStopSourceSync      : BOOL;   // SafeStop issu de la synchro M1/M2 (couplage anti-telescopage)
    PowerCutOffActive       : BOOL;   // Coupure puissance amont active (instSafetyWinch.PowerCutOff)
    Inhibited               : BOOL;   // Axe neutralise (Mode=DISABLE ou InhibitMx)

    // Barriere finale (fin de course mecanique / frein / redemarrage)
    FinalInterlockError     : BOOL;   // Defaut barriere finale (frein / redemarrage)
    FinalInterlockReason    : E_WinchFinalInterlockReason; // Cause barriere finale memorisee

    // Cause de blocage priorisee + horodatage
    BlockReason             : E_WinchTraceBlockReason; // Cause de blocage prioritaire
    BlockReasonTimestamp    : UDINT;  // ms depuis demarrage PLC (TIME()) - dernier changement de BlockReason
    StepNumber              : INT;    // Palier de vitesse actif (WinchState.StepNumber)
END_STRUCT
END_TYPE
