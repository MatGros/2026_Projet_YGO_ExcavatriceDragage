#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Génère et ajoute les nouveaux POUs/GVLs directement dans Device.export
Contenus ST en dur — pas de fichiers intermédiaires
"""

import xml.etree.ElementTree as ET
import uuid
from pathlib import Path
from datetime import datetime
import shutil

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DEVICE_EXPORT = PROJECT_ROOT / "PRJ_CODESYS" / "PROJ_Full_ImportExport" / "Device.export"

# Parent : Application
APP_PARENT_GUID = "103fbab6-1b12-4ccb-9cc6-6c66cad0e1cb"

# ===== CONTENUS ST EN DUR =====

ST_FB_DIAGCANOPEN = """FUNCTION_BLOCK FB_DiagCanOpen
VAR_INPUT
    Enable              : BOOL;
    Reset               : BOOL;
    BusState            : BUS_STATE;
    BusDiagAvailable    : BOOL;
    DeviceState         : DEVICE_STATE;
    DevDiagAvailable    : BOOL;
END_VAR
VAR_OUTPUT
    Ready               : BOOL;
    Error               : BOOL;
    ErrorId             : WORD;
    BusOnline           : BOOL;
    BusOperational      : BOOL;
    JoystickOnline      : BOOL;
    JoystickOperational : BOOL;
    CanHealthy          : BOOL;
END_VAR
VAR
    ResetEdge           : R_TRIG;
END_VAR"""

ST_FB_DIAGCANOPEN_IMPL = """ResetEdge(CLK := Reset);

IF NOT Enable THEN
    Ready               := FALSE;
    BusOnline           := FALSE;
    BusOperational      := FALSE;
    JoystickOnline      := FALSE;
    JoystickOperational := FALSE;
    CanHealthy          := FALSE;
    RETURN;
END_IF

IF ResetEdge.Q THEN
    ErrorId := 0;
END_IF

IF NOT BusDiagAvailable THEN
    BusOnline       := FALSE;
    BusOperational  := FALSE;
    ErrorId         := ErrorId OR 16#0001;
ELSE
    CASE BusState OF
        BUS_STATE.OK:
            BusOnline       := TRUE;
            BusOperational  := TRUE;
            ErrorId         := ErrorId AND NOT 16#0001;
        BUS_STATE.WARNING:
            BusOnline       := TRUE;
            BusOperational  := TRUE;
            ErrorId         := ErrorId AND NOT 16#0001;
    ELSE
        BusOnline       := FALSE;
        BusOperational  := FALSE;
        ErrorId         := ErrorId OR 16#0001;
    END_CASE
END_IF

IF NOT DevDiagAvailable THEN
    JoystickOnline      := FALSE;
    JoystickOperational := FALSE;
    ErrorId             := ErrorId OR 16#0002;
ELSE
    CASE DeviceState OF
        DEVICE_STATE.FOUND:
            JoystickOnline      := TRUE;
            JoystickOperational := TRUE;
            ErrorId             := ErrorId AND NOT (16#0002 OR 16#0004);
        DEVICE_STATE.NOT_FOUND:
            JoystickOnline      := FALSE;
            JoystickOperational := FALSE;
            ErrorId             := ErrorId OR 16#0002;
        DEVICE_STATE.NOT_OPERATIONAL:
            JoystickOnline      := TRUE;
            JoystickOperational := FALSE;
            ErrorId             := ErrorId OR 16#0004;
    ELSE
        JoystickOnline      := FALSE;
        JoystickOperational := FALSE;
        ErrorId             := ErrorId OR 16#0002;
    END_CASE
END_IF

CanHealthy := BusOperational AND JoystickOperational;
Error      := (ErrorId <> 0);
Ready      := Enable;"""

ST_FB_BUSAGGREGATOR = """FUNCTION_BLOCK FB_BusAggregator
VAR_INPUT
    Enable              : BOOL;
    CanOnline           : BOOL;
    CanOperational      : BOOL;
    JoystickOnline      : BOOL;
    JoystickOperational : BOOL;
    Cod1Online          : BOOL;
    Cod1Operational     : BOOL;
    Cod2Online          : BOOL;
    Cod2Operational     : BOOL;
    VariateurOnline     : BOOL;
    VariateurOperational : BOOL;
END_VAR
VAR_OUTPUT
    CanHealthy          : BOOL;
    EthercatHealthy     : BOOL;
    GlobalHealthy       : BOOL;
    JoystickAvailable   : BOOL;
    EncoderM1Available  : BOOL;
    EncoderM2Available  : BOOL;
    VariateurAvailable  : BOOL;
END_VAR"""

ST_FB_BUSAGGREGATOR_IMPL = """IF NOT Enable THEN
    CanHealthy          := FALSE;
    EthercatHealthy     := FALSE;
    GlobalHealthy       := FALSE;
    JoystickAvailable   := FALSE;
    EncoderM1Available  := FALSE;
    EncoderM2Available  := FALSE;
    VariateurAvailable  := FALSE;
    RETURN;
END_IF

CanHealthy := CanOperational AND JoystickOperational;
EthercatHealthy := Cod1Operational AND Cod2Operational AND VariateurOperational;
GlobalHealthy := CanHealthy AND EthercatHealthy;

JoystickAvailable   := JoystickOperational;
EncoderM1Available  := Cod1Operational;
EncoderM2Available  := Cod2Operational;
VariateurAvailable  := VariateurOperational;"""

ST_PRG_BUSMONITOR = """PROGRAM PRG_BusMonitor
VAR
    DiagCanOpen         : FB_DiagCanOpen;
    DiagEthEncoderM1    : FB_DiagEthercat;
    DiagEthEncoderM2    : FB_DiagEthercat;
    DiagEthVariateur    : FB_DiagEthercat;
    BusAggregator       : FB_BusAggregator;
END_VAR

VAR
    LocalCanBusState        : BUS_STATE := BUS_STATE.OK;
    LocalCanDiagAvailable   : BOOL := TRUE;
    LocalJoystickDeviceState : DEVICE_STATE := DEVICE_STATE.FOUND;
    LocalJoystickDiagAvailable : BOOL := TRUE;
    LocalEthCod1Online      : BOOL := TRUE;
    LocalEthCod1Operational : BOOL := TRUE;
    LocalEthCod2Online      : BOOL := TRUE;
    LocalEthCod2Operational : BOOL := TRUE;
    LocalEthVarOnline       : BOOL := TRUE;
    LocalEthVarOperational  : BOOL := TRUE;
END_VAR"""

ST_PRG_BUSMONITOR_IMPL = """DiagCanOpen(
    Enable              := TRUE,
    Reset               := FALSE,
    BusState            := LocalCanBusState,
    BusDiagAvailable    := LocalCanDiagAvailable,
    DeviceState         := LocalJoystickDeviceState,
    DevDiagAvailable    := LocalJoystickDiagAvailable
);

DiagEthEncoderM1(
    Enable              := TRUE,
    Reset               := FALSE,
    SafeStop            := FALSE,
    SafetyOk            := TRUE,
    Mode                := 0,
    SlaveAddress        := 1,
    WcState             := 0,
    SlaveState          := 0
);

DiagEthEncoderM2(
    Enable              := TRUE,
    Reset               := FALSE,
    SafeStop            := FALSE,
    SafetyOk            := TRUE,
    Mode                := 0,
    SlaveAddress        := 2,
    WcState             := 0,
    SlaveState          := 0
);

DiagEthVariateur(
    Enable              := TRUE,
    Reset               := FALSE,
    SafeStop            := FALSE,
    SafetyOk            := TRUE,
    Mode                := 0,
    SlaveAddress        := 3,
    WcState             := 0,
    SlaveState          := 0
);

BusAggregator(
    Enable              := TRUE,
    CanOnline           := DiagCanOpen.BusOnline,
    CanOperational      := DiagCanOpen.BusOperational,
    JoystickOnline      := DiagCanOpen.JoystickOnline,
    JoystickOperational := DiagCanOpen.JoystickOperational,
    Cod1Online          := DiagEthEncoderM1.Online,
    Cod1Operational     := DiagEthEncoderM1.Operational,
    Cod2Online          := DiagEthEncoderM2.Online,
    Cod2Operational     := DiagEthEncoderM2.Operational,
    VariateurOnline     := DiagEthVariateur.Online,
    VariateurOperational := DiagEthVariateur.Operational
);

GVL_BusHealth.BusHealth.CanHealthy          := BusAggregator.CanHealthy;
GVL_BusHealth.BusHealth.EthercatHealthy     := BusAggregator.EthercatHealthy;
GVL_BusHealth.BusHealth.GlobalHealthy       := BusAggregator.GlobalHealthy;
GVL_BusHealth.BusHealth.JoystickAvailable   := BusAggregator.JoystickAvailable;
GVL_BusHealth.BusHealth.EncoderM1Available  := BusAggregator.EncoderM1Available;
GVL_BusHealth.BusHealth.EncoderM2Available  := BusAggregator.EncoderM2Available;
GVL_BusHealth.BusHealth.VariateurAvailable  := BusAggregator.VariateurAvailable;"""

ST_TYPES = """TYPE E_DegradationLevel :
(
    FULL        := 0,
    LEVEL1      := 1,
    LEVEL2      := 2,
    MAINTENANCE := 3
);
END_TYPE

TYPE ST_BusHealth :
STRUCT
    CanHealthy          : BOOL;
    EthercatHealthy     : BOOL;
    GlobalHealthy       : BOOL;
    JoystickAvailable   : BOOL;
    EncoderM1Available  : BOOL;
    EncoderM2Available  : BOOL;
    VariateurAvailable  : BOOL;
END_STRUCT
END_TYPE"""

ST_GVL_BUSHEALTH = """VAR_GLOBAL
    BusHealth : ST_BusHealth := (
        CanHealthy          := FALSE,
        EthercatHealthy     := FALSE,
        GlobalHealthy       := FALSE,
        JoystickAvailable   := FALSE,
        EncoderM1Available  := FALSE,
        EncoderM2Available  := FALSE,
        VariateurAvailable  := FALSE
    );
END_VAR"""


def escape_xml(text):
    return (text
        .replace('&', '&amp;')
        .replace('<', '&lt;')
        .replace('>', '&gt;')
        .replace('"', '&quot;')
        .replace("'", '&apos;')
    )


def create_pou_xml(name, pou_type, interface_st, impl_st):
    """Crée un élément XML POU"""
    guid = str(uuid.uuid4())

    root = ET.Element("Single", Type="{6198ad31-4b98-445c-927f-3258a0e82fe3}", Method="IArchivable")

    meta = ET.SubElement(root, "Single", Name="MetaObject", Type="{81297157-7ec9-45ce-845e-84cab2b88ade}", Method="IArchivable")
    ET.SubElement(meta, "Single", Name="Guid", Type="System.Guid").text = guid
    ET.SubElement(meta, "Single", Name="ParentGuid", Type="System.Guid").text = APP_PARENT_GUID
    ET.SubElement(meta, "Single", Name="Name", Type="string").text = name
    props = ET.SubElement(meta, "Single", Name="Properties", Type="{2c41fa04-1834-41c1-816e-303c7aa2c05b}")
    ET.SubElement(meta, "Single", Name="TypeGuid", Type="System.Guid").text = "6f9dac99-8de1-4efc-8465-68ac443b7d08"

    embedded_types = ET.SubElement(meta, "Array", Name="EmbeddedTypeGuids", Type="System.Guid")
    ET.SubElement(embedded_types, "Single", Type="System.Guid").text = "a9ed5b7e-75c5-4651-af16-d2c27e98cb94"
    ET.SubElement(embedded_types, "Single", Type="System.Guid").text = "3b83b776-fb25-43b8-99f2-3c507c9143fc"

    ts = int((datetime.utcnow() - datetime(1601, 1, 1)).total_seconds() * 10000000)
    ET.SubElement(meta, "Single", Name="Timestamp", Type="long").text = str(ts)

    obj = ET.SubElement(root, "Single", Name="Object", Type="{6f9dac99-8de1-4efc-8465-68ac443b7d08}", Method="IArchivable")
    ET.SubElement(obj, "Single", Name="SpecialFunc", Type="{0db3d7bb-cde0-4416-9a7b-ce49a0124323}").text = "None"

    impl_elem = ET.SubElement(obj, "Single", Name="Implementation", Type="{3b83b776-fb25-43b8-99f2-3c507c9143fc}", Method="IArchivable")
    impl_textdoc = ET.SubElement(impl_elem, "Single", Name="TextDocument", Type="{f3878285-8e4f-490b-bb1b-9acbb7eb04db}", Method="IArchivable")
    ET.SubElement(impl_textdoc, "Single", Name="TextBlobForSerialisation", Type="string").text = escape_xml(impl_st)
    ET.SubElement(impl_textdoc, "Single", Name="LineInfoPersistence", Type="string").text = f"{guid}_Impl_LineIds"

    iface_elem = ET.SubElement(obj, "Single", Name="Interface", Type="{a9ed5b7e-75c5-4651-af16-d2c27e98cb94}", Method="IArchivable")
    iface_textdoc = ET.SubElement(iface_elem, "Single", Name="TextDocument", Type="{f3878285-8e4f-490b-bb1b-9acbb7eb04db}", Method="IArchivable")
    ET.SubElement(iface_textdoc, "Single", Name="TextBlobForSerialisation", Type="string").text = escape_xml(interface_st)
    ET.SubElement(iface_textdoc, "Single", Name="LineInfoPersistence", Type="string").text = f"{guid}_Decl_LineIds"

    ET.SubElement(obj, "Single", Name="UniqueIdGenerator", Type="string").text = "10"
    ET.SubElement(obj, "Single", Name="POULevel", Type="{8e575c5b-1d37-49c6-941b-5c0ec7874787}").text = "Standard"
    ET.SubElement(obj, "List", Name="ChildObjectGuids", Type="System.Collections.ArrayList")
    ET.SubElement(obj, "Single", Name="AddAttributeSubsequent", Type="bool").text = "False"

    ET.SubElement(root, "Single", Name="ParentSVNodeGuid", Type="System.Guid").text = APP_PARENT_GUID
    path_arr = ET.SubElement(root, "Array", Name="Path", Type="string")
    ET.SubElement(path_arr, "Single", Type="string").text = "Device"
    ET.SubElement(path_arr, "Single", Type="string").text = "Logique API"
    ET.SubElement(path_arr, "Single", Type="string").text = "Application"
    ET.SubElement(root, "Single", Name="Index", Type="int").text = "-1"

    return root, guid


def create_glv_xml(name, glv_st):
    """Crée un élément XML GVL"""
    guid = str(uuid.uuid4())

    root = ET.Element("Single", Type="{6198ad31-4b98-445c-927f-3258a0e82fe3}", Method="IArchivable")

    meta = ET.SubElement(root, "Single", Name="MetaObject", Type="{81297157-7ec9-45ce-845e-84cab2b88ade}", Method="IArchivable")
    ET.SubElement(meta, "Single", Name="Guid", Type="System.Guid").text = guid
    ET.SubElement(meta, "Single", Name="ParentGuid", Type="System.Guid").text = APP_PARENT_GUID
    ET.SubElement(meta, "Single", Name="Name", Type="string").text = name
    props = ET.SubElement(meta, "Single", Name="Properties", Type="{2c41fa04-1834-41c1-816e-303c7aa2c05b}")
    ET.SubElement(meta, "Single", Name="TypeGuid", Type="System.Guid").text = "5a87cae9-f55f-4c0b-b3f5-d7ecbe04b6b6"
    ts = int((datetime.utcnow() - datetime(1601, 1, 1)).total_seconds() * 10000000)
    ET.SubElement(meta, "Single", Name="Timestamp", Type="long").text = str(ts)

    obj = ET.SubElement(root, "Single", Name="Object", Type="{5a87cae9-f55f-4c0b-b3f5-d7ecbe04b6b6}", Method="IArchivable")
    textdoc = ET.SubElement(obj, "Single", Name="TextDocument", Type="{f3878285-8e4f-490b-bb1b-9acbb7eb04db}", Method="IArchivable")
    ET.SubElement(textdoc, "Single", Name="TextBlobForSerialisation", Type="string").text = escape_xml(glv_st)
    ET.SubElement(textdoc, "Single", Name="LineInfoPersistence", Type="string").text = f"{guid}_LineIds"

    ET.SubElement(root, "Single", Name="ParentSVNodeGuid", Type="System.Guid").text = APP_PARENT_GUID
    path_arr = ET.SubElement(root, "Array", Name="Path", Type="string")
    ET.SubElement(path_arr, "Single", Type="string").text = "Device"
    ET.SubElement(path_arr, "Single", Type="string").text = "Logique API"
    ET.SubElement(root, "Single", Name="Index", Type="int").text = "-1"

    return root, guid


def main():
    if not DEVICE_EXPORT.exists():
        print(f"ERROR: {DEVICE_EXPORT} not found")
        return False

    print("=" * 70)
    print("GENERATING AND ADDING NEW POUs/GVLs TO DEVICE.EXPORT")
    print("=" * 70)

    try:
        tree = ET.parse(str(DEVICE_EXPORT))
        root = tree.getroot()
    except Exception as e:
        print(f"ERROR: Cannot parse Device.export: {e}")
        return False

    backup_path = DEVICE_EXPORT.with_suffix(f".export.{datetime.now().strftime('%Y%m%d_%H%M%S')}.bak")
    shutil.copy(str(DEVICE_EXPORT), str(backup_path))
    print(f"Backup: {backup_path.name}\n")

    created = 0

    print("[POUs]")
    pous = [
        ("FB_DiagCanOpen", "FUNCTION_BLOCK", ST_FB_DIAGCANOPEN, ST_FB_DIAGCANOPEN_IMPL),
        ("FB_BusAggregator", "FUNCTION_BLOCK", ST_FB_BUSAGGREGATOR, ST_FB_BUSAGGREGATOR_IMPL),
        ("PRG_BusMonitor", "PROGRAM", ST_PRG_BUSMONITOR, ST_PRG_BUSMONITOR_IMPL),
    ]

    for name, pou_type, iface, impl in pous:
        pou_elem, guid = create_pou_xml(name, pou_type, iface, impl)
        root.append(pou_elem)
        print(f"  + {name:20s} {guid[:12]}...")
        created += 1

    print("\n[GVLs]")
    glvs = [
        ("_TYPES", ST_TYPES),
        ("GVL_BusHealth", ST_GVL_BUSHEALTH),
    ]

    for name, glv_st in glvs:
        glv_elem, guid = create_glv_xml(name, glv_st)
        root.append(glv_elem)
        print(f"  + {name:20s} {guid[:12]}...")
        created += 1

    print(f"\nWriting {created} elements to Device.export...", end=" ")
    try:
        tree.write(str(DEVICE_EXPORT), encoding='utf-8', xml_declaration=True)
        print("OK")
    except Exception as e:
        print(f"ERROR: {e}")
        return False

    print("\n" + "=" * 70)
    print(f"SUCCESS: {created} new POUs/GVLs added")
    print("=" * 70)
    return True


if __name__ == '__main__':
    import sys
    sys.exit(0 if main() else 1)
