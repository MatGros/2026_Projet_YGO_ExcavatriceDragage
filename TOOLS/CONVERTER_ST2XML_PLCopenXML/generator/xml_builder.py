from __future__ import annotations

import xml.etree.ElementTree as ET
from datetime import datetime, timezone

from .dependency_resolver import resolve_dependencies
from .diagnostics import DiagnosticCollector
from .guid import object_guid
from .ir import (
    ArrayInitValue,
    GlobalVarBlock,
    InitValue,
    SimpleInitValue,
    SourceObject,
    StructInitValue,
    VariableDecl,
    format_iec_real,
    format_iec_time,
)
from .st_types import ArrayType, BaseType, DerivedType, ReferenceType, StringType, TypeRef

PLCOPEN_NS = "http://www.plcopen.org/xml/tc6_0200"
XHTML_NS = "http://www.w3.org/1999/xhtml"
PRODUCT_VERSION = "CODESYS V3.5 SP19 Patch 1"

_FB_PROGRAM_SECTIONS = (
    ("inputVars", "input_vars", True),
    ("outputVars", "output_vars", True),
    ("inOutVars", "inout_vars", False),
    ("localVars", "local_vars", False),
    ("tempVars", "temp_vars", False),
)


def _format_timestamp(mtime: float) -> str:
    return datetime.fromtimestamp(mtime, tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%f")


def _documentation(text: str) -> ET.Element:
    doc = ET.Element("documentation")
    xhtml = ET.SubElement(doc, "xhtml")
    xhtml.set("xmlns", XHTML_NS)
    xhtml.text = text
    return doc


def _objectid_adddata(guid: str) -> ET.Element:
    adddata = ET.Element("addData")
    data = ET.SubElement(adddata, "data")
    data.set("name", "http://www.3s-software.com/plcopenxml/objectid")
    data.set("handleUnknown", "discard")
    object_id = ET.SubElement(data, "ObjectId")
    object_id.text = guid
    return adddata


def _type_inner(type_ref: TypeRef) -> ET.Element:
    if isinstance(type_ref, BaseType):
        return ET.Element(type_ref.name)
    if isinstance(type_ref, StringType):
        el = ET.Element("string")
        el.set("length", str(type_ref.length))
        return el
    if isinstance(type_ref, DerivedType):
        el = ET.Element("derived")
        el.set("name", type_ref.name)
        return el
    if isinstance(type_ref, ReferenceType):
        # 🔧 Confirmé sur échantillon réel CODESYS (FB_TestReference.xml, 2026-07-17) :
        # REFERENCE TO n'est PAS un <pointer> (ça, c'est POINTER TO) mais un <derived>
        # dont le name est le texte littéral "REFERENCE TO <Type>". Import CODESYS
        # avait précédemment réimporté en POINTER TO -> erreurs C0032 (assignation directe
        # d'instance incompatible avec POINTER TO qui exige ADR()).
        if not isinstance(type_ref.base, DerivedType):
            raise ValueError(
                f"REFERENCE TO d'un type non-derived non confirmé contre un échantillon réel "
                f"(seul REFERENCE TO <FB/type projet> est validé) : {type_ref.base!r}"
            )
        el = ET.Element("derived")
        el.set("name", f"REFERENCE TO {type_ref.base.name}")
        return el
    if isinstance(type_ref, ArrayType):
        el = ET.Element("array")
        for lower, upper in ((type_ref.lower, type_ref.upper), *type_ref.extra_dims):
            dim = ET.SubElement(el, "dimension")
            dim.set("lower", str(lower))
            dim.set("upper", str(upper))
        base_type_el = ET.SubElement(el, "baseType")
        base_type_el.append(_type_inner(type_ref.base))
        return el
    raise ValueError(f"unhandled type reference: {type_ref!r}")


def _type_element(type_ref: TypeRef) -> ET.Element:
    el = ET.Element("type")
    el.append(_type_inner(type_ref))
    return el


def _init_value_inner(
    init: InitValue,
    declared_type: TypeRef,
    objects_by_name: dict[str, SourceObject],
    diagnostics: DiagnosticCollector,
    context_label: str,
) -> ET.Element | None:
    if isinstance(init, SimpleInitValue):
        literal = init.literal
        if isinstance(declared_type, BaseType) and declared_type.name == "REAL":
            literal = format_iec_real(literal)
        elif isinstance(declared_type, BaseType) and declared_type.name == "TIME":
            literal = format_iec_time(literal)
        el = ET.Element("simpleValue")
        el.set("value", literal)
        return el

    if isinstance(init, ArrayInitValue):
        if not isinstance(declared_type, ArrayType):
            diagnostics.warning(
                f"array initializer used on a non-array-typed field ({context_label}); skipping initialValue",
                context_label,
            )
            return None
        el = ET.Element("arrayValue")
        for item in init.items:
            item_el = _init_value_inner(item, declared_type.base, objects_by_name, diagnostics, context_label)
            if item_el is None:
                return None
            value_el = ET.SubElement(el, "value")
            value_el.append(item_el)
        return el

    if isinstance(init, StructInitValue):
        if not isinstance(declared_type, DerivedType):
            diagnostics.warning(
                f"struct initializer used on a non-derived-typed field ({context_label}); skipping initialValue",
                context_label,
            )
            return None
        struct_obj = objects_by_name.get(declared_type.name)
        if struct_obj is None or struct_obj.kind != "struct":
            diagnostics.warning(
                f"struct initializer references unknown/non-STRUCT type {declared_type.name!r} "
                f"({context_label}); skipping initialValue",
                context_label,
            )
            return None
        member_values = init.as_dict()
        el = ET.Element("structValue")
        for field in struct_obj.struct_fields:
            if field.name not in member_values:
                continue
            member_init = member_values[field.name]
            # Allow nested struct-in-struct initializer recursion directly.
            member_el = _init_value_inner(member_init, field.type, objects_by_name, diagnostics, context_label)
            if member_el is None:
                continue
            value_el = ET.SubElement(el, "value")
            value_el.set("member", field.name)
            value_el.append(member_el)
        return el

    raise ValueError(f"unhandled init value: {init!r}")


def _variable_element(
    var: VariableDecl,
    objects_by_name: dict[str, SourceObject],
    diagnostics: DiagnosticCollector,
    context_label: str,
) -> ET.Element:
    el = ET.Element("variable")
    el.set("name", var.name)
    el.append(_type_element(var.type))
    if var.init is not None:
        inner = _init_value_inner(var.init, var.type, objects_by_name, diagnostics, f"{context_label}.{var.name}")
        if inner is not None:
            init_el = ET.SubElement(el, "initialValue")
            init_el.append(inner)
    if var.documentation:
        el.append(_documentation(var.documentation))
    return el


def _build_pou(
    obj: SourceObject, guid: str, objects_by_name: dict[str, SourceObject], diagnostics: DiagnosticCollector
) -> ET.Element:
    pou = ET.Element("pou")
    pou.set("name", obj.name)
    pou.set("pouType", "functionBlock" if obj.kind == "function_block" else "program")

    interface = ET.SubElement(pou, "interface")
    for xml_tag, attr_name, always_emit in _FB_PROGRAM_SECTIONS:
        variables = getattr(obj, attr_name)
        if not variables and not always_emit:
            continue
        section_el = ET.SubElement(interface, xml_tag)
        for var in variables:
            section_el.append(_variable_element(var, objects_by_name, diagnostics, obj.name))
    if obj.header_comment:
        interface.append(_documentation(obj.header_comment))

    body = ET.SubElement(pou, "body")
    st_el = ET.SubElement(body, "ST")
    xhtml = ET.SubElement(st_el, "xhtml")
    xhtml.set("xmlns", XHTML_NS)
    xhtml.text = obj.body_text or ""

    pou.append(_objectid_adddata(guid))
    return pou


def _build_struct_datatype(
    obj: SourceObject, guid: str, objects_by_name: dict[str, SourceObject], diagnostics: DiagnosticCollector
) -> ET.Element:
    data_type = ET.Element("dataType")
    data_type.set("name", obj.name)
    base_type = ET.SubElement(data_type, "baseType")
    struct_el = ET.SubElement(base_type, "struct")
    for field in obj.struct_fields:
        struct_el.append(_variable_element(field, objects_by_name, diagnostics, obj.name))
    data_type.append(_objectid_adddata(guid))
    if obj.header_comment:
        data_type.append(_documentation(obj.header_comment))
    return data_type


def _build_enum_datatype(obj: SourceObject, guid: str, diagnostics: DiagnosticCollector) -> ET.Element:
    data_type = ET.Element("dataType")
    data_type.set("name", obj.name)
    base_type = ET.SubElement(data_type, "baseType")
    enum_el = ET.SubElement(base_type, "enum")
    values_el = ET.SubElement(enum_el, "values")
    for value in obj.enum_values:
        value_el = ET.SubElement(values_el, "value")
        value_el.set("name", value.name)
        value_el.set("value", str(value.value))

    adddata = ET.SubElement(data_type, "addData")

    documented_values = [v for v in obj.enum_values if v.documentation]
    if documented_values:
        doc_data = ET.SubElement(adddata, "data")
        doc_data.set("name", "http://www.3s-software.com/plcopenxml/enumvaluedocumentation")
        doc_data.set("handleUnknown", "implementation")
        enum_value_doc = ET.SubElement(doc_data, "EnumValueDocumentation")
        for value in documented_values:
            enum_value_el = ET.SubElement(enum_value_doc, "EnumValue")
            name_el = ET.SubElement(enum_value_el, "Name")
            name_el.text = value.name
            doc_el = ET.SubElement(enum_value_el, "Documentation")
            xhtml = ET.SubElement(doc_el, "xhtml")
            xhtml.set("xmlns", XHTML_NS)
            xhtml.text = value.documentation

    attributes_data = ET.SubElement(adddata, "data")
    attributes_data.set("name", "http://www.3s-software.com/plcopenxml/attributes")
    attributes_data.set("handleUnknown", "implementation")
    attributes_el = ET.SubElement(attributes_data, "Attributes")
    for attr_name in ("qualified_only", "strict"):
        attr_el = ET.SubElement(attributes_el, "Attribute")
        attr_el.set("Name", attr_name)
        attr_el.set("Value", "")

    objectid_data = ET.SubElement(adddata, "data")
    objectid_data.set("name", "http://www.3s-software.com/plcopenxml/objectid")
    objectid_data.set("handleUnknown", "discard")
    object_id_el = ET.SubElement(objectid_data, "ObjectId")
    object_id_el.text = guid

    if obj.header_comment:
        diagnostics.info(
            f"{obj.name}: header comment has no confirmed schema slot for ENUM dataType in "
            "PLCopenXML -- dropped (see docs/PLCOPENXML_FORMAT.md §4)",
            obj.name,
        )

    return data_type


def _build_globalvars_data(
    obj: SourceObject,
    block: GlobalVarBlock,
    guid: str,
    objects_by_name: dict[str, SourceObject],
    diagnostics: DiagnosticCollector,
) -> ET.Element:
    data = ET.Element("data")
    data.set("name", "http://www.3s-software.com/plcopenxml/globalvars")
    data.set("handleUnknown", "implementation")

    global_vars = ET.SubElement(data, "globalVars")
    global_vars.set("name", obj.name)
    if "RETAIN" in block.qualifiers:
        global_vars.set("retain", "true")
    if "PERSISTENT" in block.qualifiers:
        global_vars.set("persistent", "true")
    if "CONSTANT" in block.qualifiers:
        global_vars.set("constant", "true")

    for persistent_index, var in enumerate(block.variables):
        variable = _variable_element(var, objects_by_name, diagnostics, obj.name)
        if "PERSISTENT" in block.qualifiers:
            # CODESYS requires this per-variable attribute to import a PERSISTENT GVL.
            # Without it, variable documentation is parsed as invalid ST declaration text.
            variable_adddata = ET.Element("addData")
            attributes_data = ET.SubElement(variable_adddata, "data")
            attributes_data.set("name", "http://www.3s-software.com/plcopenxml/attributes")
            attributes_data.set("handleUnknown", "implementation")
            attributes_el = ET.SubElement(attributes_data, "Attributes")
            attribute = ET.SubElement(attributes_el, "Attribute")
            attribute.set("Name", "order_in_persistent_editor")
            attribute.set("Value", str(persistent_index))
            documentation_index = next(
                (index for index, child in enumerate(variable) if child.tag == "documentation"),
                len(variable),
            )
            variable.insert(documentation_index, variable_adddata)
            # CODESYS 3.5 imports PERSISTENT variable XHTML documentation as ST text
            # on this target. Keep the source comments, but omit XML documentation.
            for child in list(variable):
                if child.tag == "documentation":
                    variable.remove(child)
        global_vars.append(variable)

    if obj.attribute_pragmas:
        adddata = ET.SubElement(global_vars, "addData")
        attributes_data = ET.SubElement(adddata, "data")
        attributes_data.set("name", "http://www.3s-software.com/plcopenxml/attributes")
        attributes_data.set("handleUnknown", "implementation")
        attributes_el = ET.SubElement(attributes_data, "Attributes")
        for pragma in obj.attribute_pragmas:
            attr_el = ET.SubElement(attributes_el, "Attribute")
            attr_el.set("Name", pragma)
            attr_el.set("Value", "")
        objectid_data = ET.SubElement(adddata, "data")
        objectid_data.set("name", "http://www.3s-software.com/plcopenxml/objectid")
        objectid_data.set("handleUnknown", "discard")
        object_id_el = ET.SubElement(objectid_data, "ObjectId")
        object_id_el.text = guid
    else:
        adddata = ET.SubElement(global_vars, "addData")
        data_el = ET.SubElement(adddata, "data")
        data_el.set("name", "http://www.3s-software.com/plcopenxml/objectid")
        data_el.set("handleUnknown", "discard")
        object_id_el = ET.SubElement(data_el, "ObjectId")
        object_id_el.text = guid

    if obj.header_comment and "PERSISTENT" not in block.qualifiers:
        global_vars.append(_documentation(obj.header_comment))

    return data


def build_project_xml(
    root_names: str | list[str],
    objects_by_name: dict[str, SourceObject],
    diagnostics: DiagnosticCollector,
    *,
    include_deps: bool = True,
    project_name: str = "Generated",
    timestamp_override: str | None = None,
    exclude_gvl_persistent: bool = False,
) -> ET.Element:
    roots = [root_names] if isinstance(root_names, str) else list(root_names)
    if not roots:
        raise ValueError("build_project_xml requires at least one root object name")
    missing = [r for r in roots if r not in objects_by_name]
    if missing:
        raise KeyError(f"unknown root object(s): {missing!r}")

    names = resolve_dependencies(roots, objects_by_name, diagnostics) if include_deps else roots
    objs = [objects_by_name[n] for n in names if n in objects_by_name]

    timestamp = timestamp_override or _format_timestamp(objects_by_name[roots[0]].mtime)

    project = ET.Element("project")
    project.set("xmlns", PLCOPEN_NS)

    file_header = ET.SubElement(project, "fileHeader")
    file_header.set("companyName", "")
    file_header.set("productName", "CODESYS")
    file_header.set("productVersion", PRODUCT_VERSION)
    file_header.set("creationDateTime", timestamp)

    content_header = ET.SubElement(project, "contentHeader")
    content_header.set("name", f"{project_name}.project")
    content_header.set("modificationDateTime", timestamp)
    coordinate_info = ET.SubElement(content_header, "coordinateInfo")
    for tag in ("fbd", "ld", "sfc"):
        scaling_parent = ET.SubElement(coordinate_info, tag)
        scaling = ET.SubElement(scaling_parent, "scaling")
        scaling.set("x", "1")
        scaling.set("y", "1")
    content_adddata = ET.SubElement(content_header, "addData")
    proj_info_data = ET.SubElement(content_adddata, "data")
    proj_info_data.set("name", "http://www.3s-software.com/plcopenxml/projectinformation")
    proj_info_data.set("handleUnknown", "implementation")
    project_information = ET.SubElement(proj_info_data, "ProjectInformation")
    prop = ET.SubElement(project_information, "property")
    prop.set("name", "Project")
    prop.set("type", "string")
    prop.text = project_name

    types_el = ET.SubElement(project, "types")
    data_types_el = ET.SubElement(types_el, "dataTypes")
    pous_el = ET.SubElement(types_el, "pous")

    instances_el = ET.SubElement(project, "instances")
    ET.SubElement(instances_el, "configurations")

    top_adddata = ET.SubElement(project, "addData")

    folders: dict[str, list[tuple[str, str]]] = {}

    for obj in objs:
        guid = object_guid(obj.kind, obj.name)
        folders.setdefault(obj.folder, []).append((obj.name, guid))
        if obj.raw_xml_path:
            # POU XML natif (ex. CFC) : ré-extraire l'élément <pou> direct
            raw_tree = ET.parse(obj.raw_xml_path)
            pou_node = next((n for n in raw_tree.iter() if n.tag.endswith("pou")), None)
            if pou_node is not None:
                # Nettoyer les namespaces pour éviter ns0: tout en préservant le namespace xhtml
                for elem in pou_node.iter():
                    if "}" in elem.tag:
                        elem.tag = elem.tag.split("}", 1)[1]
                    for key in list(elem.attrib.keys()):
                        if "xmlns" in key or "}" in key:
                            del elem.attrib[key]
                    if elem.tag == "xhtml":
                        elem.attrib["xmlns"] = "http://www.w3.org/1999/xhtml"
                    # CallType/ElementType sont des extensions vendor CODESYS : elles doivent
                    # rester hors du namespace PLCopen par défaut (xmlns="" explicite), sinon
                    # CODESYS ne reconnaît plus le type d'appel/d'élément (échec de compilation
                    # silencieux constaté sur les patterns non testés).
                    if elem.tag in ("CallType", "ElementType"):
                        elem.attrib["xmlns"] = ""
                # 🎯 Alignement ObjectId : forcer l'ObjectId du POU pour qu'il soit STRICTEMENT égal
                # à celui inscrit dans ProjectStructure (évite que CODESYS ne rejette l'arborescence
                # et ne place le POU à la racine du projet).
                obj_id_node = next((n for n in pou_node.iter() if n.tag == "ObjectId"), None)
                if obj_id_node is not None:
                    obj_id_node.text = guid
                else:
                    pou_adddata = next((n for n in pou_node.findall("addData")), None)
                    if pou_adddata is None:
                        pou_adddata = ET.SubElement(pou_node, "addData")
                    data_el = ET.SubElement(pou_adddata, "data")
                    data_el.set("name", "http://www.3s-software.com/plcopenxml/objectid")
                    data_el.set("handleUnknown", "discard")
                    obj_id_el = ET.SubElement(data_el, "ObjectId")
                    obj_id_el.text = guid

                pous_el.append(pou_node)
        elif obj.kind in ("function_block", "program"):
            pous_el.append(_build_pou(obj, guid, objects_by_name, diagnostics))
        elif obj.kind == "struct":
            data_types_el.append(_build_struct_datatype(obj, guid, objects_by_name, diagnostics))
        elif obj.kind == "enum":
            data_types_el.append(_build_enum_datatype(obj, guid, diagnostics))
        elif obj.kind == "gvl":
            # ⚠️ GVL_PERSISTENT est exclu du bundle : ses variables PERSISTENT RETAIN
            # sont gérées directement par CODESYS et ne doivent pas être importées
            # via PLCopenXML (risque de doublon / écrasement des valeurs persistantes).
            if exclude_gvl_persistent and obj.name == "GVL_PERSISTENT":
                diagnostics.info(
                    "GVL_PERSISTENT exclu du bundle (variables PERSISTENT RETAIN, géré par CODESYS)",
                    obj.name,
                )
                continue
            for block in obj.global_blocks:
                top_adddata.append(_build_globalvars_data(obj, block, guid, objects_by_name, diagnostics))

    project_structure_data = ET.SubElement(top_adddata, "data")
    project_structure_data.set("name", "http://www.3s-software.com/plcopenxml/projectstructure")
    project_structure_data.set("handleUnknown", "discard")
    project_structure = ET.SubElement(project_structure_data, "ProjectStructure")
    folder_elements: dict[tuple[str, ...], ET.Element] = {}
    for folder_path_str, entries in folders.items():
        if not folder_path_str:
            for object_name, guid in entries:
                object_el = ET.SubElement(project_structure, "Object")
                object_el.set("Name", object_name)
                object_el.set("ObjectId", guid)
            continue

        parts = tuple(folder_path_str.split('\\'))
        parent_el = project_structure
        for i in range(len(parts)):
            subpath = parts[:i+1]
            if subpath not in folder_elements:
                folder_el = ET.SubElement(parent_el, "Folder")
                folder_el.set("Name", parts[i])
                folder_elements[subpath] = folder_el
            parent_el = folder_elements[subpath]

        for object_name, guid in entries:
            object_el = ET.SubElement(parent_el, "Object")
            object_el.set("Name", object_name)
            object_el.set("ObjectId", guid)

    return project
