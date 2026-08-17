from generator.diagnostics import DiagnosticCollector
from generator.st_parser import parse_file
from generator.st_types import ArrayType, BaseType

from conftest import CODE_DIR


def test_synthetic_struct():
    source = "TYPE ST_Demo :\nSTRUCT\n    A : REAL;\n    B : BOOL;\nEND_STRUCT\nEND_TYPE\n"
    diag = DiagnosticCollector()
    obj = parse_file(source, folder="DEMO", stem="ST_Demo", mtime=1.0, source_label="ST_Demo.st", diagnostics=diag)
    assert obj.kind == "struct"
    assert obj.name == "ST_Demo"
    assert [f.name for f in obj.struct_fields] == ["A", "B"]
    assert not diag.has_errors()


def test_real_st_speedsteptable_parses_with_array_field():
    treuil_dir = "H_TREUILS_BENNE" if (CODE_DIR / "H_TREUILS_BENNE").is_dir() else "TREUILS"
    path = CODE_DIR / treuil_dir / "ST_SpeedStepTable.st"
    source = path.read_text(encoding="utf-8")
    diag = DiagnosticCollector()
    obj = parse_file(
        source, folder=treuil_dir, stem="ST_SpeedStepTable", mtime=1.0, source_label="ST_SpeedStepTable.st",
        diagnostics=diag,
    )
    assert obj is not None
    assert obj.kind == "struct"
    names = [f.name for f in obj.struct_fields]
    assert "P1R1" in names
    assert "StepThreshold_Pct" in names
    threshold = next(f for f in obj.struct_fields if f.name == "StepThreshold_Pct")
    assert threshold.type == ArrayType(1, 5, BaseType("REAL"))
    assert not diag.has_errors()
