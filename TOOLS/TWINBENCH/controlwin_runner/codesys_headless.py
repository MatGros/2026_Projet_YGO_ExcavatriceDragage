from __future__ import print_function

import json
import os
import sys
import traceback


CONTROL_WIN_TYPE = 4096
CONTROL_WIN_ID = "0000 0004"
CONTROL_WIN_VERSION = "3.5.19.10"
CONTROL_WIN_TYPE_NAME = "CODESYS Control Win V3 x64"
CONTROL_WIN_DEVICE_NAME = "PC-Z-VICTUS"


HW_SIM_BOOL_SYMBOLS = (
    "ConveyorInfeedReady_DI",
    "EmergencyArming_RQ",
    "EmergencyChainClosed_DI",
    "HydraulicThermalOk_DI",
    "JoyBtnRaw",
    "M1_BrakeIsOpen_DI",
    "M1_BrakeRelease_RQ",
    "M1_ContactorsReleased_DI",
    "M1_M2_KoboldBottomTouch_DI",
    "M1_M2_KoboldMeasureEnable_RQ",
    "M1_M2_M3_BrakeThermalOk_DI",
    "M1_RelayAscent_RQ",
    "M1_RelayDescent_RQ",
    "M1_SpeedContactor_1_DQ",
    "M1_SpeedContactor_2_DQ",
    "M1_SpeedContactor_3_DQ",
    "M1_SpeedContactor_4_DQ",
    "M1_ThermalOk_DI",
    "M1M2_TopPositionFree_DI",
    "M2_BrakeIsOpen_DI",
    "M2_BrakeRelease_RQ",
    "M2_ContactorsReleased_DI",
    "M2_RelayAscent_Close_RQ",
    "M2_RelayDescent_Open_RQ",
    "M2_SpeedContactor_1_DQ",
    "M2_SpeedContactor_2_DQ",
    "M2_SpeedContactor_3_DQ",
    "M2_SpeedContactor_4_DQ",
    "M2_TensionedCable_DI",
    "M2_ThermalOk_DI",
    "M3_BrakeIsOpen_DI",
    "M3_BrakeRelease_RQ",
    "M3_PosMaintenance_DI",
    "M3_PosP1_DI",
    "M3_PosPV_DI",
    "M3_PosPVP2_DI",
    "M3_PosTremie_DI",
    "M3_ThermalOK_DI",
    "PhaseRotationOk_DI",
    "PowerContactorEngaged_DI",
    "PowerKeepAlive_A_RQ",
    "PowerKeepAlive_B_RQ",
    "TremieFull_OR_GateRaised_DI",
)

HW_SIM_TYPED_SYMBOLS = (
    ("COD1_AccValue", "INT", "INT#0"),
    ("COD1_Alarms", "UINT", "UINT#0"),
    ("COD1_CodeSeqTrigCmd", "WORD", "WORD#0"),
    ("COD1_PosValue", "UDINT", "UDINT#0"),
    ("COD1_PresettTrigCmd", "WORD", "WORD#0"),
    ("COD1_PresetValue", "UDINT", "UDINT#0"),
    ("COD1_SpdValue", "DINT", "DINT#0"),
    ("COD1_Warnings", "UINT", "UINT#0"),
    ("COD2_AccValue", "INT", "INT#0"),
    ("COD2_Alarms", "UINT", "UINT#0"),
    ("COD2_CodeSeqTrigCmd", "WORD", "WORD#0"),
    ("COD2_PosValue", "UDINT", "UDINT#0"),
    ("COD2_PresettTrigCmd", "WORD", "WORD#0"),
    ("COD2_PresetValue", "UDINT", "UDINT#0"),
    ("COD2_SpdValue", "DINT", "DINT#0"),
    ("COD2_Warnings", "UINT", "UINT#0"),
    ("JoyXRaw_ANA1", "INT", "INT#5000"),
    ("JoyYRaw_ANA2", "INT", "INT#5000"),
    ("joyANA3", "INT", "INT#0"),
    ("joyANA4", "INT", "INT#0"),
    ("M3_ActualFrequencyHz", "UINT", "UINT#0"),
    ("M3_CommandWord", "WORD", "WORD#0"),
    ("M3_SetpointFrequencyHz", "WORD", "WORD#0"),
    ("M3_StatusWord", "WORD", "WORD#0"),
)

HW_SIM_DEVICE_CALLS = (
    ("AC600_ECAT_Drive.GetDeviceState()", "DEVICE_STATE.RUNNING"),
    ("COD1_CODEUR.GetDeviceState()", "DEVICE_STATE.RUNNING"),
    ("COD2_CODEUR.GetDeviceState()", "DEVICE_STATE.RUNNING"),
    ("JOY1_JOYSTICK_MCB560_CO4201A.GetDeviceState()", "DEVICE_STATE.RUNNING"),
    ("Local_Digital_IO.GetDeviceState()", "DEVICE_STATE.RUNNING"),
    ("VH_0800END.GetDeviceState()", "DEVICE_STATE.RUNNING"),
    ("VH_0808ETP.GetDeviceState()", "DEVICE_STATE.RUNNING"),
    ("VH_0008ER.GetDeviceState()", "DEVICE_STATE.RUNNING"),
    ("VH_0008ER_1.GetDeviceState()", "DEVICE_STATE.RUNNING"),
    ("CANbus.GetBusState()", "2"),
)


def env(name, required=True):
    value = os.environ.get(name, "")
    if required and not value:
        raise Exception("Variable environnement absente: " + name)
    return value


def write_report(path, data):
    data["report_path"] = path
    handle = open(path, "w")
    try:
        json.dump(data, handle, indent=2, sort_keys=True)
    finally:
        handle.close()


def object_name(obj):
    try:
        return str(obj.get_name())
    except:
        try:
            return str(obj.name)
        except:
            return str(obj)


def public_members(obj):
    names = []
    for name in dir(obj):
        if not str(name).startswith("_"):
            names.append(str(name))
    names.sort()
    return names


def find_root_device(project):
    devices = []
    for item in project.get_children(False):
        try:
            if item.is_device:
                devices.append(item)
        except:
            pass
    if len(devices) != 1:
        raise Exception("Un seul device racine est exige; trouve: %s" % len(devices))
    return devices[0]


def describe_device(device):
    try:
        identification = str(device.get_device_identification())
    except Exception as exc:
        identification = "indisponible: " + str(exc)
    try:
        settings = device.get_device_communication_settings()
        communication = {
            "device_address": str(settings.device_address),
            "device_name": str(settings.device_name),
            "scanned_ip": str(settings.scanned_ip_address_and_port),
        }
    except Exception as exc:
        communication = {"error": str(exc)}
    return identification, communication


def clear_message_store():
    try:
        for category in system.get_message_categories(False):
            system.clear_messages(category)
    except:
        pass


def build_project(project):
    application = project.active_application
    if application is None:
        raise Exception("Aucune application active dans la copie.")
    clear_message_store()
    application.rebuild()
    messages = []
    errors = 0
    warnings = 0
    categories = []
    try:
        categories = system.get_message_categories(True)
    except:
        pass
    for category in categories:
        try:
            objects = system.get_message_objects(category)
        except:
            objects = []
        for message in objects:
            severity_value = getattr(message, "severity", None)
            severity = str(severity_value)
            text = str(getattr(message, "text", message))
            is_error = (severity_value == Severity.Error or
                        severity_value == Severity.FatalError or
                        "Error" in severity or "Fatal" in severity)
            is_warning = (severity_value == Severity.Warning or "Warning" in severity)
            if is_error:
                errors += 1
            elif is_warning:
                warnings += 1
            if is_error or is_warning:
                messages.append({"severity": severity, "text": text})
    return application, errors, warnings, messages


def open_project(path):
    return projects.open(path, primary=True, update_flags=VersionUpdateFlags.NoUpdates)


def extract_archive(archive_path, project_path):
    if os.path.exists(project_path):
        raise Exception("La destination existe deja; archivage PowerShell attendu avant extraction.")
    project = projects.open_archive(
        archive_path,
        project_path,
        overwrite=False,
        update_flags=VersionUpdateFlags.NoUpdates,
    )
    project.save()
    project.close()


def apply_hw_sim_compat(native_path, result):
    """Adapt only the disposable native export used by the Control Win copy."""
    handle = open(native_path, "r")
    try:
        text = handle.read()
    finally:
        handle.close()

    original = text
    substitutions = []
    for source, replacement in HW_SIM_DEVICE_CALLS:
        count = text.count(source)
        if count:
            text = text.replace(source, replacement)
            substitutions.append({"source": source, "replacement": replacement,
                                  "count": count})

    define = "VISU_USEPROPERTYINFO, "
    define_count = text.count(define)
    if define_count:
        text = text.replace(define, "")

    name_marker = '<Single Name="Name" Type="string">GVL_Global</Single>'
    name_at = text.find(name_marker)
    if name_at < 0:
        raise Exception("Adaptateur HW_SIM: GVL_Global introuvable dans l export natif.")
    blob_marker = '<Single Name="TextBlobForSerialisation" Type="string">'
    blob_at = text.find(blob_marker, name_at)
    blob_end = text.find("</Single>", blob_at)
    if blob_at < 0 or blob_end < 0:
        raise Exception("Adaptateur HW_SIM: declaration GVL_Global illisible.")

    content_at = blob_at + len(blob_marker)
    declaration = text[content_at:blob_end]
    qualified = "{attribute 'qualified_only' := ''}"
    if qualified not in declaration:
        raise Exception("Adaptateur HW_SIM: garde qualified_only GVL_Global absente.")
    if declaration.count("END_VAR") != 1:
        raise Exception("Adaptateur HW_SIM: structure GVL_Global inattendue.")

    lines = [
        "",
        "\t/// TwinBench HW_SIM - genere uniquement dans la copie Control Win",
    ]
    for symbol in HW_SIM_BOOL_SYMBOLS:
        lines.append("\t%s : BOOL := FALSE;" % symbol)
    for symbol, type_name, initial_value in HW_SIM_TYPED_SYMBOLS:
        lines.append("\t%s : %s := %s;" % (symbol, type_name, initial_value))
    declaration = declaration.replace(qualified + "\n", "", 1)
    declaration = declaration.replace("END_VAR", "\n".join(lines) + "\nEND_VAR", 1)
    text = text[:content_at] + declaration + text[blob_end:]

    if text == original:
        raise Exception("Adaptateur HW_SIM: aucune modification appliquee.")
    handle = open(native_path, "w")
    try:
        handle.write(text)
    finally:
        handle.close()
    result["hw_sim_compat"] = {
        "scope": "derived_native_export_only",
        "bool_symbols": len(HW_SIM_BOOL_SYMBOLS),
        "typed_symbols": len(HW_SIM_TYPED_SYMBOLS),
        "device_call_substitutions": substitutions,
        "visualization_define_removed": define_count,
    }


def prepare_from_import(source_path, destination_path, result):
    source = open_project(source_path)
    native_path = os.path.join(os.path.dirname(destination_path),
                               "Application_from_source.export")
    try:
        source_device = find_root_device(source)
        before, communication = describe_device(source_device)
        result["device_before"] = before
        result["communication_before"] = communication
        source_application = source.active_application
        if source_application is None:
            raise Exception("Aucune application active dans la copie source.")
        source.export_native([source_application], native_path, recursive=True,
                             one_file_per_subtree=False)
    finally:
        source.close()

    apply_hw_sim_compat(native_path, result)

    target_id = device_repository.create_device_identification(
        CONTROL_WIN_TYPE, CONTROL_WIN_ID, CONTROL_WIN_VERSION)
    target_description = device_repository.get_device(target_id)
    if target_description is None:
        raise Exception("Description CODESYS Control Win absente du Device Repository.")

    project = projects.create(destination_path, primary=True)
    project.add("Device", target_description.device_id)
    default_application = project.active_application
    if default_application is None:
        applications = project.find("Application", True)
        if not applications:
            raise Exception("Le nouveau device Control Win ne fournit aucune Application.")
        default_application = applications[0]
    plc_logic = default_application.parent
    default_application.remove()
    plc_logic.import_native([native_path])
    applications = project.find("Application", True)
    if len(applications) != 1:
        raise Exception("Import natif ambigu: %s objets Application." % len(applications))
    project.active_application = applications[0]
    device = find_root_device(project)
    device.set_gateway_and_ip_address("Gateway-1", "127.0.0.1", 11740)
    project.save()

    after, communication_after = describe_device(device)
    result["device_identification"] = after
    result["communication_after"] = communication_after
    application, errors, warnings, messages = build_project(project)
    result["error_count"] = errors
    result["warning_count"] = warnings
    result["messages"] = messages
    if errors:
        raise Exception("Compilation Control Win refusee: %s erreur(s)." % errors)

    project.save()
    result["boot_application"] = "cree sur Control Win pendant le deploiement"
    return project


def find_local_control_win():
    matches = []
    seen = []
    for gateway in online.gateways:
        try:
            targets = gateway.perform_network_scan()
        except Exception as exc:
            seen.append("gateway %s: %s" % (str(gateway.name), str(exc)))
            continue
        for target in targets:
            description = "%s | %s | %s | %s" % (
                str(target.device_name), str(target.type_name),
                str(target.device_id), str(target.address))
            seen.append(description)
            if (str(target.device_name) == CONTROL_WIN_DEVICE_NAME and
                    str(target.type_name) == CONTROL_WIN_TYPE_NAME and
                    CONTROL_WIN_ID.replace(" ", "") in str(target.device_id).replace(" ", "")):
                matches.append((gateway, target))
    if len(matches) != 1:
        raise Exception(
            "Cible Control Win locale unique introuvable. Trouvees: " + " ; ".join(seen))
    return matches[0]


def deploy(project, result):
    device = find_root_device(project)
    current_id, unused = describe_device(device)
    normalized = current_id.replace(" ", "")
    if CONTROL_WIN_ID.replace(" ", "") not in normalized or CONTROL_WIN_VERSION not in current_id:
        raise Exception("Device de la copie non prepare pour Control Win: " + current_id)

    gateway, target = find_local_control_win()
    result["scanned_target"] = "%s | %s | %s | %s" % (
        str(target.device_name), str(target.type_name), str(target.device_id), str(target.address))
    device.set_gateway_and_address(gateway, str(target.address))
    project.save()

    username = env("TB_USERNAME")
    password = env("TB_PASSWORD")
    online.auth_fallback_modes = CredentialSourceKind.none
    online.set_specific_credentials(device, username, password)
    application, errors, warnings, messages = build_project(project)
    result["error_count"] = errors
    result["warning_count"] = warnings
    result["messages"] = messages[:200]
    if errors:
        raise Exception("Compilation avant download refusee: %s erreur(s)." % errors)

    online_application = online.create_online_application(application)
    try:
        online_application.login(OnlineChangeOption.Never, False)
        online_application.create_boot_application()
        online_application.start()
        result["application_state"] = str(online_application.application_state)
        result["logged_user"] = str(online_application.current_logged_on_username)
    finally:
        try:
            online_application.logout()
        except:
            pass
        online.clear_all_credentials()
    project.save()


def main():
    action = env("TB_ACTION").lower()
    project_path = env("TB_PROJECT")
    report_path = env("TB_REPORT")
    result = {"success": False, "action": action, "project": project_path}
    project = None
    try:
        workspace = os.path.join(os.environ.get("LOCALAPPDATA", ""),
                                 "TwinBenchControlWin", "Current")
        canonical_project = os.path.abspath(project_path).lower()
        canonical_workspace = os.path.abspath(workspace).lower() + os.sep
        if not canonical_project.startswith(canonical_workspace):
            raise Exception("REFUS SECURITE: CODESYS ne peut ouvrir que la copie TwinBench Current.")
        if action == "extract":
            extract_archive(env("TB_INPUT"), project_path)
            result["success"] = True
        elif action == "prepare":
            project = prepare_from_import(env("TB_INPUT"), project_path, result)
            result["success"] = True
        else:
            project = open_project(project_path)
            device = find_root_device(project)
            identification, communication = describe_device(device)
            result["device_name"] = object_name(device)
            result["device_identification"] = identification
            result["communication"] = communication
            if action == "inspect":
                result["success"] = True
            elif action == "introspect":
                application = project.active_application
                result["application_members"] = public_members(application)
                result["application_parent_members"] = public_members(application.parent)
                result["project_members"] = public_members(project)
                result["success"] = True
            elif action == "deploy":
                deploy(project, result)
                result["success"] = True
            else:
                raise Exception("Action headless inconnue: " + action)
    except Exception as exc:
        result["error"] = str(exc)
        result["traceback"] = traceback.format_exc()
    finally:
        if project is not None:
            try:
                project.close()
            except:
                pass
        write_report(report_path, result)
    return 0 if result["success"] else 2


if __name__ == "__main__":
    sys.exit(main())
