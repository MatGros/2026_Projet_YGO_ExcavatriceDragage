(* =======================================================================
   Automated Unit Test - FB_Sim_Safety
   ======================================================================= *)
TEST 'TC-P13-SAF-001 Enable FALSE -> boucle AU ouverte'
VAR
    fb : FB_Sim_Safety;
END_VAR
    fb.Enable := FALSE;
    fb.SimChainOkBit := TRUE;
    fb();
    ASSERT_FALSE(fb.SimChainOk, 'Enable FALSE -> SimChainOk FALSE');
    ASSERT_FALSE(fb.SimContactorOk, 'Enable FALSE -> SimContactorOk FALSE');
END_TEST

TEST 'TC-P13-SAF-002 Pilotage boucle AU saine par SimChainOkBit et armement contacteur'
VAR
    fb : FB_Sim_Safety;
END_VAR
    fb.Enable := TRUE;
    fb.SimChainOkBit := TRUE; (* Chaine AU fermee par operateur *)
    fb();
    
    (* Ecoulement tempo de fermeture chaine (50ms = 60ms avancee) *)
    ADVANCE_TIME(60000000);
    fb();
    ASSERT_TRUE(fb.SimChainOk, 'SimChainOkBit TRUE -> SimChainOk TRUE apres tempo relais');
    
    (* Impulsion armement tenue 100ms (temps de collage contacteur) *)
    ADVANCE_TIME(10000000);
    fb.EmergencyArming := TRUE;
    fb();
    ADVANCE_TIME(110000000);
    fb();
    ASSERT_TRUE(fb.SimContactorOk, 'EmergencyArming soutenu -> SimContactorOk TRUE (engage)');
    
    (* Relachement impulsion -> auto-maintien *)
    ADVANCE_TIME(10000000);
    fb.EmergencyArming := FALSE;
    fb();
    ASSERT_TRUE(fb.SimContactorOk, 'Fin pulse -> Auto-maintien contacteur maintenu');
END_TEST
