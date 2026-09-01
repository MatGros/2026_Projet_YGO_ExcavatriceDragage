(* Tableau public, lecture seule, des permis canoniques. Producteur : PRG_07. *)
TYPE ST_PermitVisibilityHMI :
STRUCT
    ArmingPermit : BOOL;
    M1SafetyAscentPermit : BOOL;
    M1SafetyDescendPermit : BOOL;
    M1ProcessAscentPermit : BOOL;
    M1ProcessDescendPermit : BOOL;
    EffectivePermitM1_Ascent : BOOL;
    EffectivePermitM1_Descend : BOOL;
    AppliedPermitM1_Ascent : BOOL;
    AppliedPermitM1_Descend : BOOL;
    M1FinalPermitBlocked : BOOL;
    M2SafetyAscentPermit : BOOL;
    M2SafetyDescendPermit : BOOL;
    M2ProcessAscentPermit : BOOL;
    M2ProcessDescendPermit : BOOL;
    EffectivePermitM2_Ascent : BOOL;
    EffectivePermitM2_Descend : BOOL;
    AppliedPermitM2_Ascent : BOOL;
    AppliedPermitM2_Descend : BOOL;
    M2FinalPermitBlocked : BOOL;
    BothActive : BOOL;
    BothAscentPermit : BOOL;
    BothDescendPermit : BOOL;
    BothBlocked : BOOL;
    BothBlockReason : E_WinchTraceBlockReason;
    EffectivePermitM3_Tremie : BOOL;
    EffectivePermitM3_Maintenance : BOOL; // Droit directionnel zone Maintenance, distinct de l'acces P1
    M3MotionPermitEffective : BOOL;
    DiveDescendPermit : BOOL;
    ExtractionAscentPermit : BOOL;
    ExtractionAssistActive : BOOL;
    // Benne : pas de bit Permit canonique a ce stade ; publication des faits consommes.
    BucketOpenRequestActive : BOOL;
    BucketCloseRequestActive : BOOL;
    BucketMotionBlocked : BOOL;
END_STRUCT
END_TYPE
