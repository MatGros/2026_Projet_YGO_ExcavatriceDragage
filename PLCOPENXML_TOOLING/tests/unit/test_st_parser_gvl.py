from generator.diagnostics import DiagnosticCollector, Severity
from generator.st_parser import parse_file

from conftest import CODE_DIR


def test_synthetic_gvl_single_block_name_comes_from_stem():
    source = "VAR_GLOBAL\n    X : BOOL;\nEND_VAR\n"
    diag = DiagnosticCollector()
    obj = parse_file(source, folder="MAIN", stem="GVL_Demo", mtime=1.0, source_label="GVL_Demo.st", diagnostics=diag)
    assert obj.kind == "gvl"
    assert obj.name == "GVL_Demo"
    assert len(obj.global_blocks) == 1
    assert obj.global_blocks[0].qualifiers == []
    assert [v.name for v in obj.global_blocks[0].variables] == ["X"]
    assert not diag.has_errors()


def test_synthetic_gvl_multiple_blocks_gets_info_diagnostic():
    source = "VAR_GLOBAL\n    X : BOOL;\nEND_VAR\nVAR_GLOBAL RETAIN\n    Y : REAL := 1.0;\nEND_VAR\n"
    diag = DiagnosticCollector()
    obj = parse_file(source, folder="MAIN", stem="GVL_Demo", mtime=1.0, source_label="GVL_Demo.st", diagnostics=diag)
    assert len(obj.global_blocks) == 2
    assert obj.global_blocks[0].qualifiers == []
    assert obj.global_blocks[1].qualifiers == ["RETAIN"]
    assert diag.of(Severity.INFO)
    assert not diag.has_errors()


def test_real_gvl_persistent_parses_retain_persistent_qualifiers_and_composite_init():
    from generator.ir import StructInitValue

    path = CODE_DIR / "SYSTEM" / "GVL_PERSISTENT.st"
    source = path.read_text(encoding="utf-8")
    diag = DiagnosticCollector()
    obj = parse_file(
        source, folder="SYSTEM", stem="GVL_PERSISTENT", mtime=1.0, source_label="GVL_PERSISTENT.st",
        diagnostics=diag,
    )
    assert obj is not None
    assert obj.kind == "gvl"
    assert obj.name == "GVL_PERSISTENT"
    assert len(obj.global_blocks) == 1
    assert obj.global_blocks[0].qualifiers == ["PERSISTENT", "RETAIN"]
    variables = {v.name: v for v in obj.global_blocks[0].variables}
    assert isinstance(variables["GrappinConfig"].init, StructInitValue)
    assert not diag.has_errors()


def test_real_gvl_debug_attribute_pragma_is_captured():
    path = CODE_DIR / "MAIN" / "GVL_DEBUG.st"
    source = path.read_text(encoding="utf-8")
    diag = DiagnosticCollector()
    obj = parse_file(source, folder="MAIN", stem="GVL_DEBUG", mtime=1.0, source_label="GVL_DEBUG.st", diagnostics=diag)
    assert obj.attribute_pragmas == ["qualified_only"]


def test_real_gvl_encoder_stub_multiple_var_global_blocks():
    source = """VAR_GLOBAL
    M1_Reset_IHM : BOOL;
END_VAR
VAR_GLOBAL RETAIN
    M1_TopSensorPositionM : REAL;
END_VAR"""
    diag = DiagnosticCollector()
    obj = parse_file(
        source, folder="ENCODERS", stem="GVL_Encoder_Stub", mtime=1.0, source_label="GVL_Encoder_Stub.st",
        diagnostics=diag,
    )
    assert obj is not None
    assert len(obj.global_blocks) == 2
    assert obj.global_blocks[0].qualifiers == []
    assert obj.global_blocks[1].qualifiers == ["RETAIN"]
    assert diag.of(Severity.INFO)
    assert not diag.has_errors()
