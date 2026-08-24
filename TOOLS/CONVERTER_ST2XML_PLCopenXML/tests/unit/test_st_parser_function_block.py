from generator.diagnostics import DiagnosticCollector, Severity
from generator.st_parser import parse_file

from conftest import CODE_DIR


def test_synthetic_function_block():
    source = (
        "(* header *)\n\n"
        "FUNCTION_BLOCK PUBLIC FB_Demo\n"
        "VAR_INPUT\n"
        "    Enable : BOOL;\n"
        "END_VAR\n"
        "VAR_OUTPUT\n"
        "    Ready : BOOL;\n"
        "END_VAR\n"
        "VAR\n"
        "    Internal : INT;\n"
        "END_VAR\n"
        "Ready := Enable;\n"
    )
    diag = DiagnosticCollector()
    obj = parse_file(source, folder="DEMO", stem="FB_Demo", mtime=123.0, source_label="FB_Demo.st", diagnostics=diag)
    assert obj is not None
    assert obj.kind == "function_block"
    assert obj.name == "FB_Demo"
    assert obj.folder == "DEMO"
    assert obj.is_public is True
    assert [v.name for v in obj.input_vars] == ["Enable"]
    assert [v.name for v in obj.output_vars] == ["Ready"]
    assert [v.name for v in obj.local_vars] == ["Internal"]
    assert obj.body_text.strip() == "Ready := Enable;"
    assert not diag.has_errors()


def test_var_temp_records_warning():
    source = (
        "FUNCTION_BLOCK FB_Demo\n"
        "VAR_TEMP\n"
        "    X : INT;\n"
        "END_VAR\n"
    )
    diag = DiagnosticCollector()
    obj = parse_file(source, folder="DEMO", stem="FB_Demo", mtime=1.0, source_label="FB_Demo.st", diagnostics=diag)
    assert [v.name for v in obj.temp_vars] == ["X"]
    assert diag.of(Severity.WARNING)


def test_malformed_file_returns_none_and_records_error():
    diag = DiagnosticCollector()
    obj = parse_file("NOT_A_VALID_ROOT\n", folder="DEMO", stem="X", mtime=1.0, source_label="X.st", diagnostics=diag)
    assert obj is None
    assert diag.has_errors()


def test_real_fb_winch_parses_end_to_end():
    treuil_dir = "H_TREUILS_BENNE" if (CODE_DIR / "H_TREUILS_BENNE").is_dir() else "TREUILS"
    path = CODE_DIR / treuil_dir / "FB_Winch.st"
    source = path.read_text(encoding="utf-8")
    diag = DiagnosticCollector()
    obj = parse_file(source, folder=treuil_dir, stem="FB_Winch", mtime=1.0, source_label="FB_Winch.st", diagnostics=diag)
    assert obj is not None
    assert obj.kind == "function_block"
    assert obj.name == "FB_Winch"
    assert obj.is_public is True
    names = [v.name for v in obj.input_vars]
    assert "Enable" in names
    assert "SpeedStepTable" in names
    speed_step_table = next(v for v in obj.input_vars if v.name == "SpeedStepTable")
    from generator.st_types import DerivedType

    assert speed_step_table.type == DerivedType("ST_SpeedStepTable")
    assert not diag.has_errors()
