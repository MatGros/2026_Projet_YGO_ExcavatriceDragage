(* =======================================================================
   🧪 test_prg02_acquisition_archi.st — Architecture PRG_02_Acquisition (TC-P02-001..005)
   ───────────────────────────────────────────────────────────────
   Lot : écriture de tests CI — domaine AF-02 (architecture programme).
   Fiche : DOC/AF/AF_Partie-02_Architecture_Programme_v3.2.md §1 (table des points
           de validation) + AF_Fiche_PRG_02_Acquisition_v1.0.md.
   Conventions : 1 appel harness() = 1 scan ; ADVANCE_TIME(ns) entre les scans pour
   les fronts R_TRIG. Les TC-P02 sont des TC d'architecture : les scénarios valident
   ce qui est testable en boîte noire (population/initialisation/interfaces via
   assertions sur les instances Data/HwIn du harnais) ; les TC de pure architecture
   portent une assertion d'invariant structurel documenté + commentaire
   « (essai d'architecture — validation partielle boîte noire) ».
   ======================================================================= *)

SETUP
VAR
    harness : FB_TestHarness_PRG_02;
END_VAR
END_SETUP

TEST 'TC-P02-001 Un seul producteur par donnee : bus Data qualifie et complet (essai d architecture - validation partielle boite noire)'
    (* Architecture F02.03 : chaque image/bus/commande a un proprietaire unique. En boite
       noire, on verifie que PRG_02 (via le harnais) peuple le bus Data de facon coherente
       et complete : diagnostics DI, qualification codeurs, mesures. *)
    harness();
    ADVANCE_TIME(10000000);
    harness();
    ASSERT_TRUE(harness.Data.LocalDigitalIoOk, 'Diagnostic module LocalDigitalIoOk publie (producteur unique)');
    ASSERT_TRUE(harness.Data.Vh0800EndOk, 'Diagnostic module VH0800 publie');
    ASSERT_TRUE(harness.Data.Vh0808EtpOk, 'Diagnostic module VH0808 publie');
    ASSERT_FALSE(harness.Data.InputModuleFault, 'Pas de defaut module E/S (nominal)');
    ASSERT_TRUE(harness.Data.M1_HomedAndReliable, 'Codeur M1 qualifie publie');
    ASSERT_EQ(harness.Data.Encoders.M1.CablePosM, 2.0, 'Mesure cable M1 publiee (2.0 m)');
END_TEST

TEST 'TC-P02-002 Orchestration ST sans logique cachee : qualification joystick et codeurs (essai d architecture - validation partielle boite noire)'
    (* Architecture F02.02 : les calculs resident dans les FB, le PRG orchestre. En boite
       noire, on verifie que le bus Data porte les resultats qualifies des sous-FB
       (joystick, codeurs) — preuve que l orchestration ST rend les flux lisibles. *)
    harness(JoyRawX := 5000, JoyRawY := 5000, JoyBtnRaw := FALSE);
    ADVANCE_TIME(60000000);
    harness(JoyRawX := 5000, JoyRawY := 5000, JoyBtnRaw := TRUE);
    ADVANCE_TIME(150000000);
    harness(JoyRawX := 5000, JoyRawY := 5000, JoyBtnRaw := TRUE);
    ASSERT_TRUE(harness.Data.JoystickDeadmanArmed, 'Homme-mort arme (qualification joystick)');
    ASSERT_TRUE(harness.Data.JoystickXNeutral, 'Axe X au neutre');
    ASSERT_EQ(harness.Data.Encoders.M1.CablePosM, 2.0, 'Mesure codeur M1 publiee');
END_TEST

TEST 'TC-P02-003 Sorties physiques via PRG_06 : PRG_02 ne produit aucune commande actionneur (essai d architecture - validation partielle boite noire)'
    (* Architecture F02.04 : seul PRG_06_Outputs ecrit les Q/PDO. Le harnais PRG_02 n expose
       que Data (bus) et HwIn (image) — aucune sortie physique. On verifie que l image HwIn
       est bien peuplee (frontiere acquisition) sans commande actionneur. *)
    harness(M1_RelayFwd := TRUE, M1_BrakeCmd := TRUE);
    ADVANCE_TIME(10000000);
    harness(M1_RelayFwd := TRUE, M1_BrakeCmd := TRUE);
    ASSERT_TRUE(harness.HwIn.Winch.M1_ContactorsReleased_DI, 'Image HwIn peuplee (frontiere acquisition)');
    ASSERT_TRUE(harness.HwIn.Machine.PowerContactorEngaged_DI, 'Image machine peuplee');
    (* (essai d architecture - validation partielle boite noire) : le harnais PRG_02 n a aucune
       VAR_OUTPUT de commande actionneur (Q/PDO) — la barriere sortie est PRG_06. *)
END_TEST

TEST 'TC-P02-004 Ordre MainTask conforme : HwIn image arbitree reel/simule (essai d architecture - validation partielle boite noire)'
    (* Architecture F02.01/F02.05 : ordre MainTask + retards N-1. En boite noire, on verifie
       l aiguillage reel/simule : hors simulation, HwIn reflete l image reelle (entrees). *)
    harness(SimulationModeActive := FALSE, M1_ContactorsReleased := FALSE, PowerContactorEngaged := FALSE);
    ADVANCE_TIME(10000000);
    harness(SimulationModeActive := FALSE, M1_ContactorsReleased := FALSE, PowerContactorEngaged := FALSE);
    ASSERT_FALSE(harness.HwIn.Winch.M1_ContactorsReleased_DI, 'Hors simulation -> HwIn reflete le reel (M1 contacteurs relaches)');
    ASSERT_FALSE(harness.HwIn.Machine.PowerContactorEngaged_DI, 'Hors simulation -> HwIn reflete le reel (AU non arme)');
END_TEST

TEST 'TC-P02-005 Troubleshooting lecture seule : PRG_02 produit les diagnostics observes (essai d architecture - validation partielle boite noire)'
    (* Architecture F02.06 : la vue troubleshooting observe seulement. PRG_02 produit les faits
       diagnostiques (InputModuleFault, etats modules) consommes par la vue. En boite noire, on
       verifie que ces diagnostics sont publies sur le bus Data. *)
    harness();
    ADVANCE_TIME(10000000);
    harness();
    ASSERT_FALSE(harness.Data.InputModuleFault, 'Diagnostic InputModuleFault publie (FALSE nominal)');
    ASSERT_TRUE(harness.Data.LocalDigitalIoOk, 'Diagnostic module LocalDigitalIoOk publie');
    (* (essai d architecture - validation partielle boite noire) : la lecture seule stricte de la
       vue troubleshooting est couverte en AF-14 (TC-P14-TSV-01..05). *)
END_TEST
