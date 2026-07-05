from generator.diagnostics import DiagnosticCollector
from generator.st_parser import parse_file

from conftest import CODE_DIR


def test_synthetic_enum_parenthesized_form():
    source = "TYPE E_Demo :\n(\n  A := 0,\n  B := 1\n);\nEND_TYPE\n"
    diag = DiagnosticCollector()
    obj = parse_file(source, folder="DEMO", stem="E_Demo", mtime=1.0, source_label="E_Demo.st", diagnostics=diag)
    assert obj.kind == "enum"
    assert obj.name == "E_Demo"
    assert [(v.name, v.value) for v in obj.enum_values] == [("A", 0), ("B", 1)]
    assert not diag.has_errors()


def test_synthetic_enum_keyword_form():
    source = "TYPE E_Demo :\nENUM\n  A := 0,\n  B := 1\nEND_ENUM\nEND_TYPE\n"
    diag = DiagnosticCollector()
    obj = parse_file(source, folder="DEMO", stem="E_Demo", mtime=1.0, source_label="E_Demo.st", diagnostics=diag)
    assert [(v.name, v.value) for v in obj.enum_values] == [("A", 0), ("B", 1)]


def test_real_e_cyclestep_parenthesized_form():
    path = CODE_DIR / "CYCLE" / "E_CycleStep.st"
    source = path.read_text(encoding="utf-8")
    diag = DiagnosticCollector()
    obj = parse_file(
        source, folder="CYCLE", stem="E_CycleStep", mtime=1.0, source_label="E_CycleStep.st", diagnostics=diag
    )
    assert obj is not None
    assert obj.kind == "enum"
    assert obj.enum_values[0].name == "INIT"
    assert obj.enum_values[0].value == 0
    assert obj.enum_values[-1].name == "ERROR_HOLD"
    assert obj.enum_values[-1].value == 12
    assert not diag.has_errors()


def test_real_e_mode_keyword_enum_form():
    path = CODE_DIR / "MODES" / "E_Mode.st"
    source = path.read_text(encoding="utf-8")
    diag = DiagnosticCollector()
    obj = parse_file(source, folder="MODES", stem="E_Mode", mtime=1.0, source_label="E_Mode.st", diagnostics=diag)
    assert obj is not None
    assert obj.kind == "enum"
    names = [v.name for v in obj.enum_values]
    assert names == ["DISABLE", "MAINT_N1", "MAINT_N2", "SEMI_AUTO"]
    assert not diag.has_errors()
