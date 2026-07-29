import xml.etree.ElementTree as ET

from generator.diagnostics import DiagnosticCollector, Severity
from generator.ir import SimpleInitValue, SourceObject, StructInitValue, VariableDecl, GlobalVarBlock, ArrayInitValue
from generator.st_types import ArrayType, BaseType, DerivedType, ReferenceType, StringType
from generator.xml_builder import PLCOPEN_NS, build_project_xml

NS = {"p": PLCOPEN_NS}


def _fb(name, folder="DEMO", **kwargs):
    return SourceObject(kind="function_block", name=name, folder=folder, file_path=f"{name}.st", **kwargs)


def test_minimal_function_block_skeleton():
    obj = _fb(
        "FB_Demo",
        header_comment="header text",
        input_vars=[VariableDecl("Enable", BaseType("BOOL"))],
        output_vars=[VariableDecl("Ready", BaseType("BOOL"))],
        body_text="Ready := Enable;",
        mtime=0.0,
    )
    diag = DiagnosticCollector()
    root = build_project_xml("FB_Demo", {"FB_Demo": obj}, diag, include_deps=False)

    assert root.tag == "project"
    assert root.get("xmlns") == PLCOPEN_NS
    file_header = root.find("fileHeader")
    assert file_header.get("productVersion") == "CODESYS V3.5 SP19 Patch 1"

    pou = root.find("types/pous/pou")
    assert pou.get("name") == "FB_Demo"
    assert pou.get("pouType") == "functionBlock"
    input_var = pou.find("interface/inputVars/variable")
    assert input_var.get("name") == "Enable"
    assert input_var.find("type/BOOL") is not None
    doc = pou.find("interface/documentation/xhtml")
    assert doc.text == "header text"
    st_text = pou.find("body/ST/xhtml").text
    assert st_text == "Ready := Enable;"
    object_id = pou.find("addData/data/ObjectId")
    assert object_id.text

    project_structure = root.find("addData/data/ProjectStructure")
    folder_el = project_structure.find("Folder")
    assert folder_el.get("Name") == "DEMO"
    assert folder_el.find("Object").get("Name") == "FB_Demo"
    assert not diag.has_errors()


def test_program_pou_type():
    obj = SourceObject(kind="program", name="PRG_Demo", folder="IO", file_path="x", body_text="")
    diag = DiagnosticCollector()
    root = build_project_xml("PRG_Demo", {"PRG_Demo": obj}, diag, include_deps=False)
    pou = root.find("types/pous/pou")
    assert pou.get("pouType") == "program"


def test_only_prg_ld_is_converted_to_ladder():
    program = SourceObject(
        kind="program", name="PRG_10_Outputs_LD", folder="MAIN", file_path="x",
        input_vars=[VariableDecl("M1RelayFwd", BaseType("BOOL"))],
        body_text="M1_RelayFwd_Up_DQ := M1RelayFwd;"
    )
    function_block = _fb(
        "FB_WinchOutputInterlock_LD", body_text="IF Enable THEN\n    Ready := TRUE;\nEND_IF;"
    )
    diag = DiagnosticCollector()
    root = build_project_xml(
        "PRG_10_Outputs_LD",
        {program.name: program, function_block.name: function_block},
        diag,
        include_deps=False,
    )
    pou = root.find("types/pous/pou")
    assert pou.find("body/LD") is not None
    assert pou.find("body/LD/contact/variable").text == "M1RelayFwd"
    assert pou.find("body/LD/coil/variable").text == "M1_RelayFwd_Up_DQ"

    root = build_project_xml(
        "FB_WinchOutputInterlock_LD",
        {program.name: program, function_block.name: function_block},
        diag,
        include_deps=False,
    )
    pou = root.find("types/pous/pou")
    assert pou.find("body/ST/xhtml").text == "IF Enable THEN\n    Ready := TRUE;\nEND_IF;"
    assert pou.find("body/LD") is None


def test_prg_ld_block_type_name_matches_declared_instance_type():
    program = SourceObject(
        kind="program",
        name="PRG_10_Outputs_LD",
        folder="MAIN",
        file_path="x",
        local_vars=[
            VariableDecl("instWinchOutputInterlockM1_LD", DerivedType("FB_WinchOutputInterlock_LD")),
            VariableDecl("instWinchOutputInterlockM2_LD", DerivedType("FB_WinchOutputInterlock_LD")),
            VariableDecl("instTranslationOutputInterlock_LD", DerivedType("FB_TranslationOutputInterlock_LD")),
        ],
        body_text=(
            "instWinchOutputInterlockM1_LD(Enable := M1Enable, RequestedStep := M1Step);\n"
            "instWinchOutputInterlockM2_LD(Enable := M2Enable, RequestedStep := M2Step);\n"
            "instTranslationOutputInterlock_LD(Enable := M3Enable, RequestedDriveControlWord := M3Word);"
        ),
    )
    diag = DiagnosticCollector()
    root = build_project_xml(program.name, {program.name: program}, diag, include_deps=False)
    blocks = {
        block.get("instanceName"): block.get("typeName")
        for block in root.findall("types/pous/pou/body/LD/block")
    }
    assert blocks == {
        "instWinchOutputInterlockM1_LD": "FB_WinchOutputInterlock_LD",
        "instWinchOutputInterlockM2_LD": "FB_WinchOutputInterlock_LD",
        "instTranslationOutputInterlock_LD": "FB_TranslationOutputInterlock_LD",
    }


def test_inout_and_temp_vars_only_emitted_when_present():
    obj = _fb("FB_Demo", input_vars=[VariableDecl("A", BaseType("BOOL"))], body_text="")
    diag = DiagnosticCollector()
    root = build_project_xml("FB_Demo", {"FB_Demo": obj}, diag, include_deps=False)
    interface = root.find("types/pous/pou/interface")
    assert interface.find("inOutVars") is None
    assert interface.find("tempVars") is None
    assert interface.find("inputVars") is not None
    assert interface.find("outputVars") is not None


def test_string_and_array_type_rendering():
    obj = _fb(
        "FB_Demo",
        input_vars=[
            VariableDecl("S", StringType(80)),
            VariableDecl("A", ArrayType(1, 5, BaseType("REAL"))),
        ],
        body_text="",
    )
    diag = DiagnosticCollector()
    root = build_project_xml("FB_Demo", {"FB_Demo": obj}, diag, include_deps=False)
    variables = root.findall("types/pous/pou/interface/inputVars/variable")
    string_type = variables[0].find("type/string")
    assert string_type.get("length") == "80"
    array_type = variables[1].find("type/array")
    dim = array_type.find("dimension")
    assert dim.get("lower") == "1"
    assert dim.get("upper") == "5"
    assert array_type.find("baseType/REAL") is not None


def test_reference_to_type_renders_as_derived_with_literal_prefix():
    """Confirmé sur échantillon réel CODESYS (FB_TestReference.xml, 2026-07-17) :
    REFERENCE TO FB_Winch -> <derived name="REFERENCE TO FB_Winch" />, PAS un <pointer>."""
    obj = _fb(
        "FB_Demo",
        input_vars=[VariableDecl("refTest", ReferenceType(DerivedType("FB_Winch")))],
        body_text="",
    )
    diag = DiagnosticCollector()
    root = build_project_xml("FB_Demo", {"FB_Demo": obj}, diag, include_deps=False)
    variable = root.find("types/pous/pou/interface/inputVars/variable")
    derived = variable.find("type/derived")
    assert derived is not None
    assert derived.get("name") == "REFERENCE TO FB_Winch"
    assert variable.find("type/pointer") is None


def test_struct_datatype_and_field_documentation():
    struct_obj = SourceObject(
        kind="struct",
        name="ST_Demo",
        folder="DEMO",
        file_path="x",
        header_comment="struct header",
        struct_fields=[VariableDecl("A", BaseType("REAL"), documentation="doc A")],
    )
    diag = DiagnosticCollector()
    root = build_project_xml("ST_Demo", {"ST_Demo": struct_obj}, diag, include_deps=False)
    data_type = root.find("types/dataTypes/dataType")
    assert data_type.get("name") == "ST_Demo"
    field = data_type.find("baseType/struct/variable")
    assert field.get("name") == "A"
    assert field.find("documentation/xhtml").text == "doc A"
    assert data_type.find("documentation/xhtml").text == "struct header"


def test_enum_datatype_has_no_top_level_documentation_even_with_header_comment():
    """Confirmed against samples_reference_codesys/E_CycleStep.xml: an ENUM's
    own header comment has no schema slot at the dataType level (only
    per-value EnumValueDocumentation exists) -- it must be silently dropped
    (with an INFO diagnostic), not fabricated into an unconfirmed element."""
    from generator.ir import EnumValueDecl

    enum_obj = SourceObject(
        kind="enum",
        name="E_Demo",
        folder="DEMO",
        file_path="x",
        header_comment="this has nowhere to go",
        enum_values=[EnumValueDecl("A", 0, "doc A"), EnumValueDecl("B", 1)],
    )
    diag = DiagnosticCollector()
    root = build_project_xml("E_Demo", {"E_Demo": enum_obj}, diag, include_deps=False)
    data_type = root.find("types/dataTypes/dataType")
    assert data_type.find("documentation") is None
    values = data_type.findall("baseType/enum/values/value")
    assert [(v.get("name"), v.get("value")) for v in values] == [("A", "0"), ("B", "1")]
    enum_value_doc = data_type.find(
        "addData/data[@name='http://www.3s-software.com/plcopenxml/enumvaluedocumentation']"
        "/EnumValueDocumentation"
    )
    assert enum_value_doc.find("EnumValue/Name").text == "A"
    assert len(enum_value_doc.findall("EnumValue")) == 1  # B has no documentation, not emitted
    attributes = data_type.findall(
        "addData/data[@name='http://www.3s-software.com/plcopenxml/attributes']/Attributes/Attribute"
    )
    assert {a.get("Name") for a in attributes} == {"qualified_only", "strict"}
    assert any("dropped" in str(d) for d in diag.of(Severity.INFO))


def test_gvl_retain_and_persistent_attributes():
    gvl_obj = SourceObject(
        kind="gvl",
        name="GVL_Demo",
        folder="MAIN",
        file_path="x",
        global_blocks=[GlobalVarBlock(["PERSISTENT", "RETAIN"], [VariableDecl("X", BaseType("BOOL"))])],
    )
    diag = DiagnosticCollector()
    root = build_project_xml("GVL_Demo", {"GVL_Demo": gvl_obj}, diag, include_deps=False)
    global_vars = root.find("addData/data[@name='http://www.3s-software.com/plcopenxml/globalvars']/globalVars")
    assert global_vars.get("name") == "GVL_Demo"
    assert global_vars.get("retain") == "true"
    assert global_vars.get("persistent") == "true"


def test_gvl_without_qualifiers_has_no_retain_or_persistent_attribute():
    gvl_obj = SourceObject(
        kind="gvl",
        name="GVL_Demo",
        folder="MAIN",
        file_path="x",
        global_blocks=[GlobalVarBlock([], [VariableDecl("X", BaseType("BOOL"))])],
    )
    diag = DiagnosticCollector()
    root = build_project_xml("GVL_Demo", {"GVL_Demo": gvl_obj}, diag, include_deps=False)
    global_vars = root.find("addData/data[@name='http://www.3s-software.com/plcopenxml/globalvars']/globalVars")
    assert global_vars.get("retain") is None
    assert global_vars.get("persistent") is None


def test_gvl_attribute_pragma_becomes_attributes_block():
    gvl_obj = SourceObject(
        kind="gvl",
        name="GVL_Demo",
        folder="MAIN",
        file_path="x",
        attribute_pragmas=["qualified_only"],
        global_blocks=[GlobalVarBlock([], [VariableDecl("X", BaseType("BOOL"))])],
    )
    diag = DiagnosticCollector()
    root = build_project_xml("GVL_Demo", {"GVL_Demo": gvl_obj}, diag, include_deps=False)
    global_vars = root.find("addData/data[@name='http://www.3s-software.com/plcopenxml/globalvars']/globalVars")
    attrs = global_vars.findall("addData/data[@name='http://www.3s-software.com/plcopenxml/attributes']/Attributes/Attribute")
    assert [a.get("Name") for a in attrs] == ["qualified_only"]


def test_gvl_multiple_blocks_emit_multiple_globalvars_elements():
    gvl_obj = SourceObject(
        kind="gvl",
        name="GVL_Demo",
        folder="MAIN",
        file_path="x",
        global_blocks=[
            GlobalVarBlock([], [VariableDecl("X", BaseType("BOOL"))]),
            GlobalVarBlock(["RETAIN"], [VariableDecl("Y", BaseType("BOOL"))]),
        ],
    )
    diag = DiagnosticCollector()
    root = build_project_xml("GVL_Demo", {"GVL_Demo": gvl_obj}, diag, include_deps=False)
    global_vars_elements = root.findall(
        "addData/data[@name='http://www.3s-software.com/plcopenxml/globalvars']/globalVars"
    )
    assert len(global_vars_elements) == 2
    assert global_vars_elements[0].get("retain") is None
    assert global_vars_elements[1].get("retain") == "true"


def test_composite_struct_init_field_order_follows_struct_declaration_not_source_order():
    struct_obj = SourceObject(
        kind="struct",
        name="ST_Cfg",
        folder="X",
        file_path="x",
        struct_fields=[
            VariableDecl("A", BaseType("REAL")),
            VariableDecl("B", BaseType("REAL")),
            VariableDecl("C", BaseType("REAL")),
        ],
    )
    gvl_obj = SourceObject(
        kind="gvl",
        name="GVL_Demo",
        folder="MAIN",
        file_path="x",
        global_blocks=[
            GlobalVarBlock(
                [],
                [
                    VariableDecl(
                        "Cfg",
                        DerivedType("ST_Cfg"),
                        init=StructInitValue(
                            (("C", SimpleInitValue("3.0")), ("A", SimpleInitValue("1.0")), ("B", SimpleInitValue("2.0")))
                        ),
                    )
                ],
            )
        ],
    )
    diag = DiagnosticCollector()
    root = build_project_xml(
        "GVL_Demo", {"GVL_Demo": gvl_obj, "ST_Cfg": struct_obj}, diag, include_deps=False
    )
    struct_value = root.find(
        "addData/data[@name='http://www.3s-software.com/plcopenxml/globalvars']"
        "/globalVars/variable/initialValue/structValue"
    )
    members = struct_value.findall("value")
    assert [m.get("member") for m in members] == ["A", "B", "C"]
    # REAL formatting applied even inside composite members
    assert [m.find("simpleValue").get("value") for m in members] == ["1", "2", "3"]


def test_nested_struct_in_struct_init():
    other_struct = SourceObject(
        kind="struct", name="ST_Other", folder="X", file_path="x",
        struct_fields=[VariableDecl("X", BaseType("REAL"))],
    )
    struct_obj = SourceObject(
        kind="struct", name="ST_Cfg", folder="X", file_path="x",
        struct_fields=[VariableDecl("Inner", DerivedType("ST_Other"))],
    )
    gvl_obj = SourceObject(
        kind="gvl",
        name="GVL_Demo",
        folder="MAIN",
        file_path="x",
        global_blocks=[
            GlobalVarBlock(
                [],
                [
                    VariableDecl(
                        "Cfg",
                        DerivedType("ST_Cfg"),
                        init=StructInitValue((("Inner", StructInitValue((("X", SimpleInitValue("1.0")),))),)),
                    )
                ],
            )
        ],
    )
    diag = DiagnosticCollector()
    root = build_project_xml(
        "GVL_Demo",
        {"GVL_Demo": gvl_obj, "ST_Cfg": struct_obj, "ST_Other": other_struct},
        diag,
        include_deps=False
    )
    struct_value = root.find(
        "addData/data[@name='http://www.3s-software.com/plcopenxml/globalvars']"
        "/globalVars/variable/initialValue/structValue"
    )
    inner_val = struct_value.find("value[@member='Inner']/structValue")
    assert inner_val is not None
    x_val = inner_val.find("value[@member='X']/simpleValue")
    assert x_val is not None
    assert x_val.get("value") == "1"
    assert not diag.has_errors()


def test_array_member_inside_struct_init():
    struct_obj = SourceObject(
        kind="struct", name="ST_Cfg", folder="X", file_path="x",
        struct_fields=[VariableDecl("Arr", ArrayType(1, 3, BaseType("REAL")))],
    )
    gvl_obj = SourceObject(
        kind="gvl",
        name="GVL_Demo",
        folder="MAIN",
        file_path="x",
        global_blocks=[
            GlobalVarBlock(
                [],
                [
                    VariableDecl(
                        "Cfg",
                        DerivedType("ST_Cfg"),
                        init=StructInitValue(
                            (("Arr", ArrayInitValue((SimpleInitValue("1.0"), SimpleInitValue("2.0")))),)
                        ),
                    )
                ],
            )
        ],
    )
    diag = DiagnosticCollector()
    root = build_project_xml("GVL_Demo", {"GVL_Demo": gvl_obj, "ST_Cfg": struct_obj}, diag, include_deps=False)
    array_value = root.find(
        "addData/data[@name='http://www.3s-software.com/plcopenxml/globalvars']"
        "/globalVars/variable/initialValue/structValue/value/arrayValue"
    )
    values = array_value.findall("value/simpleValue")
    assert [v.get("value") for v in values] == ["1", "2"]


def test_include_deps_pulls_in_referenced_struct():
    struct_obj = SourceObject(kind="struct", name="ST_Dep", folder="X", file_path="x")
    fb_obj = _fb("FB_Demo", input_vars=[VariableDecl("X", DerivedType("ST_Dep"))], body_text="")
    diag = DiagnosticCollector()
    root = build_project_xml(
        "FB_Demo", {"FB_Demo": fb_obj, "ST_Dep": struct_obj}, diag, include_deps=True
    )
    data_type = root.find("types/dataTypes/dataType")
    assert data_type.get("name") == "ST_Dep"


def test_no_deps_excludes_referenced_struct():
    struct_obj = SourceObject(kind="struct", name="ST_Dep", folder="X", file_path="x")
    fb_obj = _fb("FB_Demo", input_vars=[VariableDecl("X", DerivedType("ST_Dep"))], body_text="")
    diag = DiagnosticCollector()
    root = build_project_xml(
        "FB_Demo", {"FB_Demo": fb_obj, "ST_Dep": struct_obj}, diag, include_deps=False
    )
    assert root.find("types/dataTypes/dataType") is None


def test_project_structure_groups_objects_by_folder():
    a = _fb("FB_A", folder="FOLDER1", body_text="")
    b = SourceObject(kind="struct", name="ST_B", folder="FOLDER2", file_path="x")
    a.input_vars.append(VariableDecl("X", DerivedType("ST_B")))
    diag = DiagnosticCollector()
    root = build_project_xml("FB_A", {"FB_A": a, "ST_B": b}, diag, include_deps=True)
    folders = root.findall("addData/data[@name='http://www.3s-software.com/plcopenxml/projectstructure']/ProjectStructure/Folder")
    names = {f.get("Name"): [o.get("Name") for o in f.findall("Object")] for f in folders}
    assert names == {"FOLDER1": ["FB_A"], "FOLDER2": ["ST_B"]}
