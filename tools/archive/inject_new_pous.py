#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Ajoute les nouveaux POUs/GVLs à Device.export en préservant la structure existante
Approche prudente : append seulement, ne réécrit pas le fichier
"""

import xml.etree.ElementTree as ET
import uuid
from pathlib import Path
from datetime import datetime
import shutil
import re

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DEVICE_EXPORT = PROJECT_ROOT / "PRJ_CODESYS" / "PROJ_Full_ImportExport" / "Device.export"

APP_PARENT_GUID = "103fbab6-1b12-4ccb-9cc6-6c66cad0e1cb"

ST_CONTENTS = {
    "FB_DiagCanOpen": {
        "iface": """FUNCTION_BLOCK FB_DiagCanOpen
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
END_VAR""",
        "impl": """ResetEdge(CLK := Reset);

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
    END_CASE
END_IF

CanHealthy := BusOperational AND JoystickOperational;
Error      := (ErrorId <> 0);
Ready      := Enable;""",
    },
    "FB_BusAggregator": {
        "iface": """FUNCTION_BLOCK FB_BusAggregator
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
END_VAR""",
        "impl": """IF NOT Enable THEN
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
VariateurAvailable  := VariateurOperational;""",
    },
    "PRG_BusMonitor": {
        "iface": """PROGRAM PRG_BusMonitor
VAR
    DiagCanOpen         : FB_DiagCanOpen;
    DiagEthEncoderM1    : FB_DiagEthercat;
    DiagEthEncoderM2    : FB_DiagEthercat;
    DiagEthVariateur    : FB_DiagEthercat;
    BusAggregator       : FB_BusAggregator;
END_VAR""",
        "impl": """DiagCanOpen(Enable := TRUE, Reset := FALSE, BusState := BUS_STATE.OK, BusDiagAvailable := TRUE, DeviceState := DEVICE_STATE.FOUND, DevDiagAvailable := TRUE);
DiagEthEncoderM1(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, SafetyOk := TRUE, Mode := 0, SlaveAddress := 1, WcState := 0, SlaveState := 0);
DiagEthEncoderM2(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, SafetyOk := TRUE, Mode := 0, SlaveAddress := 2, WcState := 0, SlaveState := 0);
DiagEthVariateur(Enable := TRUE, Reset := FALSE, SafeStop := FALSE, SafetyOk := TRUE, Mode := 0, SlaveAddress := 3, WcState := 0, SlaveState := 0);
BusAggregator(Enable := TRUE, CanOnline := DiagCanOpen.BusOnline, CanOperational := DiagCanOpen.BusOperational, JoystickOnline := DiagCanOpen.JoystickOnline, JoystickOperational := DiagCanOpen.JoystickOperational, Cod1Online := DiagEthEncoderM1.Online, Cod1Operational := DiagEthEncoderM1.Operational, Cod2Online := DiagEthEncoderM2.Online, Cod2Operational := DiagEthEncoderM2.Operational, VariateurOnline := DiagEthVariateur.Online, VariateurOperational := DiagEthVariateur.Operational);
GVL_BusHealth.BusHealth.CanHealthy := BusAggregator.CanHealthy;
GVL_BusHealth.BusHealth.EthercatHealthy := BusAggregator.EthercatHealthy;
GVL_BusHealth.BusHealth.GlobalHealthy := BusAggregator.GlobalHealthy;
GVL_BusHealth.BusHealth.JoystickAvailable := BusAggregator.JoystickAvailable;
GVL_BusHealth.BusHealth.EncoderM1Available := BusAggregator.EncoderM1Available;
GVL_BusHealth.BusHealth.EncoderM2Available := BusAggregator.EncoderM2Available;
GVL_BusHealth.BusHealth.VariateurAvailable := BusAggregator.VariateurAvailable;""",
    },
}

GLVS = {
    "_TYPES": """TYPE E_DegradationLevel :
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
END_TYPE""",
    "GVL_BusHealth": """VAR_GLOBAL
    BusHealth : ST_BusHealth := (
        CanHealthy          := FALSE,
        EthercatHealthy     := FALSE,
        GlobalHealthy       := FALSE,
        JoystickAvailable   := FALSE,
        EncoderM1Available  := FALSE,
        EncoderM2Available  := FALSE,
        VariateurAvailable  := FALSE
    );
END_VAR""",
}


def escape_xml(text):
    return (text
        .replace('&', '&amp;')
        .replace('<', '&lt;')
        .replace('>', '&gt;')
        .replace('"', '&quot;')
        .replace("'", '&apos;')
    )


def read_file_as_string(path):
    """Lit le fichier Device.export en tant que string pour éviter les problèmes de parsing"""
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()


def write_file(path, content):
    """Écrit le fichier Device.export"""
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)


def create_pou_element(name, pou_type, iface, impl):
    """Crée le XML string d'un POU"""
    guid = str(uuid.uuid4())
    ts = int((datetime.utcnow() - datetime(1601, 1, 1)).total_seconds() * 10000000)

    return f"""<Single Type="{{6198ad31-4b98-445c-927f-3258a0e82fe3}}" Method="IArchivable">
      <Single Name="IsRoot" Type="bool">False</Single>
      <Single Name="MetaObject" Type="{{81297157-7ec9-45ce-845e-84cab2b88ade}}" Method="IArchivable">
        <Single Name="Guid" Type="System.Guid">{guid}</Single>
        <Single Name="ParentGuid" Type="System.Guid">{APP_PARENT_GUID}</Single>
        <Single Name="Name" Type="string">{name}</Single>
        <Dictionary Type="{{2c41fa04-1834-41c1-816e-303c7aa2c05b}}" Name="Properties" />
        <Single Name="TypeGuid" Type="System.Guid">6f9dac99-8de1-4efc-8465-68ac443b7d08</Single>
        <Array Name="EmbeddedTypeGuids" Type="System.Guid">
          <Single Type="System.Guid">a9ed5b7e-75c5-4651-af16-d2c27e98cb94</Single>
          <Single Type="System.Guid">3b83b776-fb25-43b8-99f2-3c507c9143fc</Single>
        </Array>
        <Single Name="Timestamp" Type="long">{ts}</Single>
      </Single>
      <Single Name="Object" Type="{{6f9dac99-8de1-4efc-8465-68ac443b7d08}}" Method="IArchivable">
        <Single Name="SpecialFunc" Type="{{0db3d7bb-cde0-4416-9a7b-ce49a0124323}}">None</Single>
        <Single Name="Implementation" Type="{{3b83b776-fb25-43b8-99f2-3c507c9143fc}}" Method="IArchivable">
          <Single Name="TextDocument" Type="{{f3878285-8e4f-490b-bb1b-9acbb7eb04db}}" Method="IArchivable">
            <Single Name="TextBlobForSerialisation" Type="string">{escape_xml(impl)}</Single>
            <Single Name="LineInfoPersistence" Type="string">{guid}_Impl_LineIds</Single>
          </Single>
        </Single>
        <Single Name="Interface" Type="{{a9ed5b7e-75c5-4651-af16-d2c27e98cb94}}" Method="IArchivable">
          <Single Name="TextDocument" Type="{{f3878285-8e4f-490b-bb1b-9acbb7eb04db}}" Method="IArchivable">
            <Single Name="TextBlobForSerialisation" Type="string">{escape_xml(iface)}</Single>
            <Single Name="LineInfoPersistence" Type="string">{guid}_Decl_LineIds</Single>
          </Single>
        </Single>
        <Single Name="UniqueIdGenerator" Type="string">10</Single>
        <Single Name="POULevel" Type="{{8e575c5b-1d37-49c6-941b-5c0ec7874787}}">Standard</Single>
        <List Name="ChildObjectGuids" Type="System.Collections.ArrayList" />
        <Single Name="AddAttributeSubsequent" Type="bool">False</Single>
      </Single>
      <Single Name="ParentSVNodeGuid" Type="System.Guid">{APP_PARENT_GUID}</Single>
      <Array Name="Path" Type="string">
        <Single Type="string">Device</Single>
        <Single Type="string">Logique API</Single>
        <Single Type="string">Application</Single>
      </Array>
      <Single Name="Index" Type="int">-1</Single>
    </Single>"""


def create_glv_element(name, content):
    """Crée le XML string d'une GVL"""
    guid = str(uuid.uuid4())
    ts = int((datetime.utcnow() - datetime(1601, 1, 1)).total_seconds() * 10000000)

    return f"""<Single Type="{{6198ad31-4b98-445c-927f-3258a0e82fe3}}" Method="IArchivable">
      <Single Name="IsRoot" Type="bool">False</Single>
      <Single Name="MetaObject" Type="{{81297157-7ec9-45ce-845e-84cab2b88ade}}" Method="IArchivable">
        <Single Name="Guid" Type="System.Guid">{guid}</Single>
        <Single Name="ParentGuid" Type="System.Guid">{APP_PARENT_GUID}</Single>
        <Single Name="Name" Type="string">{name}</Single>
        <Dictionary Type="{{2c41fa04-1834-41c1-816e-303c7aa2c05b}}" Name="Properties" />
        <Single Name="TypeGuid" Type="System.Guid">5a87cae9-f55f-4c0b-b3f5-d7ecbe04b6b6</Single>
        <Single Name="Timestamp" Type="long">{ts}</Single>
      </Single>
      <Single Name="Object" Type="{{5a87cae9-f55f-4c0b-b3f5-d7ecbe04b6b6}}" Method="IArchivable">
        <Single Name="TextDocument" Type="{{f3878285-8e4f-490b-bb1b-9acbb7eb04db}}" Method="IArchivable">
          <Single Name="TextBlobForSerialisation" Type="string">{escape_xml(content)}</Single>
          <Single Name="LineInfoPersistence" Type="string">{guid}_LineIds</Single>
        </Single>
      </Single>
      <Single Name="ParentSVNodeGuid" Type="System.Guid">{APP_PARENT_GUID}</Single>
      <Array Name="Path" Type="string">
        <Single Type="string">Device</Single>
        <Single Type="string">Logique API</Single>
      </Array>
      <Single Name="Index" Type="int">-1</Single>
    </Single>"""


def main():
    if not DEVICE_EXPORT.exists():
        print(f"ERROR: {DEVICE_EXPORT} not found")
        return False

    print("=" * 70)
    print("INJECTING NEW POUs/GVLs (SAFE MODE - STRING APPEND)")
    print("=" * 70)

    content = read_file_as_string(DEVICE_EXPORT)

    # Backup
    backup_path = DEVICE_EXPORT.with_suffix(f".export.{datetime.now().strftime('%Y%m%d_%H%M%S')}.bak")
    shutil.copy(str(DEVICE_EXPORT), str(backup_path))
    print(f"Backup: {backup_path.name}\n")

    # Créer les éléments XML
    new_elements = []

    print("[POUs]")
    for name, st in ST_CONTENTS.items():
        elem = create_pou_element(name, "FUNCTION_BLOCK" if name != "PRG_BusMonitor" else "PROGRAM", st["iface"], st["impl"])
        new_elements.append(elem)
        print(f"  + {name}")

    print("\n[GVLs]")
    for name, st in GLVS.items():
        elem = create_glv_element(name, st)
        new_elements.append(elem)
        print(f"  + {name}")

    # Injecter avant la fermeture du rootElement
    # Chercher la dernière occurrence de </Single> (fermeture du root)
    close_tag = "</Single>"
    insert_pos = content.rfind(close_tag)

    if insert_pos == -1:
        print("ERROR: Cannot find root closing tag")
        return False

    new_content = content[:insert_pos] + "\n    " + "\n    ".join(new_elements) + "\n  " + content[insert_pos:]

    write_file(DEVICE_EXPORT, new_content)
    print(f"\nWritten to Device.export")

    print("\n" + "=" * 70)
    print(f"SUCCESS: {len(new_elements)} elements injected")
    print("=" * 70)
    return True


if __name__ == '__main__':
    import sys
    sys.exit(0 if main() else 1)
