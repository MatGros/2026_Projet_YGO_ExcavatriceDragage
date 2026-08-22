TYPE ST_ChainDredgingAssist :
STRUCT
    Idx101_EnableDiveSearch          : BOOL; // 1 = Assistance Plongée Armée (IHM) | 0 = Désarmée
    Idx102_EnableExtractionSequence  : BOOL; // 1 = Assistance Extraction Armée (IHM) | 0 = Désarmée
    Idx103_EnableDumpAtTremie        : BOOL; // 1 = Mode Vidage Trémie Armé (IHM) | 0 = Désarmé

    Idx201_DiveReady                 : BOOL; // 1 = Assistance Plongée Prête | 0 = Non Prête
    Idx202_DiveBusy                  : BOOL; // 1 = Séquence Plongée En Cours | 0 = Repos
    Idx203_DiveDone                  : BOOL; // 1 = Fond Confirmé | 0 = En Cours
    Idx204_DiveState                 : E_DiveSearchState; // État interne séquenceur plongée
    Idx205_DiveError                 : BOOL; // 0 = Sain | 1 = Défaut Plongée 🔴
    Idx206_DiveErrorId                : WORD; // bit0: préconditions, bit1: séquence Kobold, bit2: config seuils
    Idx207_BottomTouchConfirmed      : BOOL; // 1 = Contact Fond Confirmé (Kobold ou manuel) | 0 = Non Confirmé

    Idx301_ExtractionReady           : BOOL; // 1 = Assistance Extraction Prête | 0 = Non Prête
    Idx302_ExtractionBusy            : BOOL; // 1 = Séquence Extraction En Cours | 0 = Repos
    Idx303_ExtractionDone            : BOOL; // 1 = Extraction Terminée | 0 = En Cours
    Idx304_ExtractionState           : E_ExtractionSequenceState; // État interne séquenceur extraction
    Idx305_ExtractionError           : BOOL; // 0 = Sain | 1 = Défaut Extraction 🔴
    Idx306_ExtractionErrorId          : WORD; // bit0: fond absent, bit1: fermeture, bit2: contrôle remontée, bit3: config

    Idx401_OperatorActionId          : WORD;       // Identifiant consigne opérateur conduite (0 = aucune)
    Idx402_OperatorAction            : STRING(120); // Texte consigne opérateur (secours affichage)

    Idx501_DumpAtTremieArmed         : BOOL; // 1 = Bit IHM TglEnableDumpAtTremie actif | 0 = Désarmé
    Idx502_DumpAtTremieAssistActive  : BOOL; // 1 = Mode réellement actif (armé ET Mode MAINT_N1/N2) | 0 = Inactif
    Idx503_DumpAtTremieAtTremie      : BOOL; // 1 = M3 à la position Trémie | 0 = Ailleurs
    Idx504_DumpAtTremieBucketOpenArmed : BOOL; // 1 = Ouverture benne armée par ce mode | 0 = Non armée
    Idx505_DumpAtTremieDescentLocked : BOOL; // 1 = Descente M1/M2 verrouillée (M3 hors P1/Maintenance) | 0 = Libre

    Idx601_BypassDiveActive          : BOOL; // 🆕 2026-08-07 (9) : 1 = Bypass séquence DiveSearch armé (IHM)
    Idx602_BypassKoboldBottomTouched : BOOL; // 🆕 2026-08-07 (9) : 1 = Fond confirmé par le bypass (front montant Kobold en descente)
END_STRUCT
END_TYPE
