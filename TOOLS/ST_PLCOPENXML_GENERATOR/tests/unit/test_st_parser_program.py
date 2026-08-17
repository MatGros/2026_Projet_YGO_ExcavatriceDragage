from generator.diagnostics import DiagnosticCollector
from generator.st_parser import parse_file

from conftest import CODE_DIR


def test_synthetic_program():
    source = "PROGRAM PRG_Demo\nVAR_OUTPUT\n    Y : BOOL;\nEND_VAR\nY := TRUE;\n"
    diag = DiagnosticCollector()
    obj = parse_file(source, folder="IO", stem="PRG_Demo", mtime=1.0, source_label="PRG_Demo.st", diagnostics=diag)
    assert obj.kind == "program"
    assert obj.name == "PRG_Demo"
    assert obj.is_public is False
    assert obj.body_text.strip() == "Y := TRUE;"
    assert not diag.has_errors()


def test_real_prg_acquisition_parses_end_to_end():
    main_dir = "M_MAIN" if (CODE_DIR / "M_MAIN").is_dir() else "MAIN"
    path = CODE_DIR / main_dir / "PRG_02_Acquisition.st"
    source = path.read_text(encoding="utf-8")
    diag = DiagnosticCollector()
    obj = parse_file(
        source, folder=main_dir, stem="PRG_02_Acquisition", mtime=1.0,
        source_label="PRG_02_Acquisition.st", diagnostics=diag
    )
    assert obj is not None
    assert obj.kind == "program"
    assert obj.name == "PRG_02_Acquisition"
    names = [v.name for v in obj.output_vars]
    assert "HwReal" in names
    assert "HwRealQualified" not in names
    assert "HwIn" in names
    assert '{region "§1 Acquisition brute — HwReal"}' in obj.body_text
    assert "{endregion}" in obj.body_text
    assert not diag.has_errors()
