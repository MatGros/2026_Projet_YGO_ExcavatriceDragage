(* =======================================================================
   ST_IoHw_In — Image exhaustive des entrées hardware pour visualisation IHM
   -----------------------------------------------------------------------
   Producteur : PRG_07_Supervision (recopie de PRG_02_Acquisition).
   Rôle : observation PLC→IHM uniquement. Aucun champ n'est une commande.
   Les images Hardware/Network/Modules reprennent les sources qualifiées;
   les champs Raw complètent les voies présentes dans Device_IO_20260831.csv.
   ======================================================================= *)
TYPE ST_IoHw_In :
STRUCT
    Hardware       : ST_HardwareImage;                // Entrées physiques normalisées (Winch/Translation/Operator/Machine)
    Network        : ST_AcquisitionNetworkDiagnostics; // EtherCAT + CANopen + esclaves
    InputModules   : ST_IOModuleDiag;                 // 5 cartes VBus
    DataValid      : BOOL;                            // Scan acquisition valide

    COD1_AccValue  : INT; // EtherCAT COD1 : valeur accélération brute (voie %IW7)
    COD2_AccValue  : INT; // EtherCAT COD2 : valeur accélération brute (voie %IW103)
    JoyAna3Raw     : INT; // CANopen JOY1 : entrée analogique 3 brute
    JoyAna4Raw     : INT; // CANopen JOY1 : entrée analogique 4 brute

    Vh0800EndBit05Reserved : BOOL; // VH_0800END bit 5 : voie présente, fonction non documentée
END_STRUCT
END_TYPE
