import pytest

from generator.st_sections import SectionError, split_file


def test_function_block_public_with_header_and_two_var_blocks():
    source = (
        "(* header comment\n   line two *)\n\n"
        "FUNCTION_BLOCK PUBLIC FB_Demo\n"
        "VAR_INPUT\n"
        "    Enable : BOOL;\n"
        "END_VAR\n"
        "VAR_OUTPUT\n"
        "    Ready : BOOL;\n"
        "END_VAR\n"
        "Ready := Enable;\n"
    )
    result = split_file(source)
    assert result.kind == "function_block"
    assert result.name == "FB_Demo"
    assert result.is_public is True
    assert result.header_comment == "header comment\n   line two"
    assert [b.section for b in result.var_blocks] == ["VAR_INPUT", "VAR_OUTPUT"]
    assert "Enable : BOOL;" in result.var_blocks[0].body
    assert "Ready : BOOL;" in result.var_blocks[1].body
    assert result.body_text.strip() == "Ready := Enable;"


def test_function_block_without_public_keyword():
    source = "FUNCTION_BLOCK FB_Cycle\nVAR\n    X : INT;\nEND_VAR\nX := 1;\n"
    result = split_file(source)
    assert result.kind == "function_block"
    assert result.name == "FB_Cycle"
    assert result.is_public is False


def test_program_kind():
    source = "PROGRAM PRG_Demo\nVAR_OUTPUT\n    Y : BOOL;\nEND_VAR\nY := TRUE;\n"
    result = split_file(source)
    assert result.kind == "program"
    assert result.name == "PRG_Demo"
    assert result.body_text.strip() == "Y := TRUE;"


def test_struct_kind():
    source = (
        "TYPE ST_Demo :\n"
        "STRUCT\n"
        "    A : REAL;\n"
        "    B : BOOL;\n"
        "END_STRUCT\n"
        "END_TYPE\n"
    )
    result = split_file(source)
    assert result.kind == "struct"
    assert result.name == "ST_Demo"
    assert "A : REAL;" in result.struct_body
    assert "B : BOOL;" in result.struct_body
    assert "END_STRUCT" not in result.struct_body


def test_enum_kind():
    source = (
        "TYPE E_Demo :\n"
        "(\n"
        "  A := 0, (* first *)\n"
        "  B := 1  (* second *)\n"
        ");\n"
        "END_TYPE\n"
    )
    result = split_file(source)
    assert result.kind == "enum"
    assert result.name == "E_Demo"
    assert "A := 0" in result.enum_body
    assert "B := 1" in result.enum_body


def test_enum_kind_with_end_enum_keyword_form():
    """Some real CODE/ files (E_Mode.st, E_State.st, E_ChariotCommMode.st) use
    'ENUM ... END_ENUM' instead of the '(...)' parenthesized literal form."""
    source = (
        "TYPE E_Demo :\n"
        "ENUM\n"
        "    A := 0,   (* first *)\n"
        "    B := 1    (* second *)\n"
        "END_ENUM\n"
        "END_TYPE\n"
    )
    result = split_file(source)
    assert result.kind == "enum"
    assert result.name == "E_Demo"
    assert "A := 0" in result.enum_body
    assert "B := 1" in result.enum_body
    assert "END_ENUM" not in result.enum_body


def test_gvl_kind_with_multiple_var_global_blocks_of_different_qualifiers():
    """Mirrors CODE/ENCODERS/GVL_Encoder_Stub.st: one plain VAR_GLOBAL block
    followed by a VAR_GLOBAL RETAIN block in the same GVL file."""
    source = (
        "VAR_GLOBAL\n"
        "    X : BOOL;\n"
        "END_VAR\n\n"
        "VAR_GLOBAL RETAIN\n"
        "    Y : REAL := 12.5;\n"
        "END_VAR\n"
    )
    result = split_file(source)
    assert result.kind == "gvl"
    assert len(result.var_blocks) == 2
    assert result.var_blocks[0].qualifiers == []
    assert result.var_blocks[1].qualifiers == ["RETAIN"]


def test_gvl_kind_has_no_name_and_single_var_global_block():
    source = "VAR_GLOBAL\n    X : BOOL;\nEND_VAR\n"
    result = split_file(source)
    assert result.kind == "gvl"
    assert result.name is None
    assert len(result.var_blocks) == 1
    assert result.var_blocks[0].section == "VAR_GLOBAL"
    assert result.var_blocks[0].qualifiers == []


def test_gvl_with_persistent_retain_qualifiers():
    source = "VAR_GLOBAL PERSISTENT RETAIN\n    X : BOOL;\nEND_VAR\n"
    result = split_file(source)
    assert result.var_blocks[0].qualifiers == ["PERSISTENT", "RETAIN"]


def test_gvl_with_retain_only_qualifier():
    source = "VAR_GLOBAL RETAIN\n    X : BOOL;\nEND_VAR\n"
    result = split_file(source)
    assert result.var_blocks[0].qualifiers == ["RETAIN"]


def test_attribute_pragma_before_var_global_is_captured_not_merged_into_header():
    source = (
        "(* header *)\n\n"
        "{attribute 'qualified_only'}\n"
        "VAR_GLOBAL\n"
        "    X : BOOL;\n"
        "END_VAR\n"
    )
    result = split_file(source)
    assert result.header_comment == "header"
    assert result.attribute_pragmas == ["qualified_only"]


def test_isolated_comment_between_header_and_keyword_is_merged_into_header():
    """Mirrors CODE/JOYSTICK/FB_Joystick.st: a block comment header, then a lone
    '// === DECLARATION ===' line comment, then FUNCTION_BLOCK — both must end
    up concatenated into header_comment, nothing lost or misattributed."""
    source = (
        "(* main header\n   detail *)\n\n"
        "// === DECLARATION (a coller) ===\n\n"
        "FUNCTION_BLOCK FB_Joystick\n"
        "VAR_INPUT\n"
        "    Enable : BOOL;\n"
        "END_VAR\n"
    )
    result = split_file(source)
    assert result.header_comment == "main header\n   detail\n=== DECLARATION (a coller) ==="


def test_banner_comment_inside_var_block_is_preserved_in_body_text():
    source = (
        "VAR_GLOBAL\n"
        "    // banner over X\n"
        "    X : BOOL;\n"
        "END_VAR\n"
    )
    result = split_file(source)
    assert "// banner over X" in result.var_blocks[0].body


def test_no_recognizable_root_construct_raises_section_error():
    with pytest.raises(SectionError):
        split_file("NOT_A_VALID_ROOT_KEYWORD\n")


def test_keyword_looking_text_inside_comment_does_not_confuse_root_detection():
    source = (
        "(* this comment mentions FUNCTION_BLOCK and END_VAR but is not one *)\n"
        "PROGRAM PRG_Real\n"
        "VAR\n"
        "    X : INT;\n"
        "END_VAR\n"
    )
    result = split_file(source)
    assert result.kind == "program"
    assert result.name == "PRG_Real"
