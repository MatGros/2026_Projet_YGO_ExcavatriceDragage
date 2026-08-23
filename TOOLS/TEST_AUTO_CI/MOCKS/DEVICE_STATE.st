(* =======================================================================
   📊 Type CODESYS système pour tests STruCpp
   ======================================================================= *)
TYPE DEVICE_STATE :
(
    UNKNOWN             := 0,
    STOPPED             := 1,
    CONFIG_ERROR        := 2,
    BUS_ERROR           := 3,
    DISABLED            := 4,
    INITIALIZING        := 5,
    RESET_ORIGIN        := 6,
    RESET_COMMUNICATION := 7,
    RESET_APPLICATION   := 8,
    RUNNING             := 9,
    LOGGER_ERROR        := 10
);
END_TYPE
