import pytest

from generator.diagnostics import DiagnosticCollector, Severity
from generator.ir import ArrayInitValue, SimpleInitValue, StructInitValue, format_iec_real, format_iec_time
from generator.st_declarations import parse_enum_values, parse_var_block
from generator.st_types import BaseType, DerivedType, StringType


@pytest.mark.parametrize(
    "literal,expected",
    [
        ("50.0", "50"),
        ("-20.0", "-20"),
        ("0.0", "0"),
        ("12.5", "12.5"),
        ("0.05", "0.05"),
        ("100.0", "100"),
        ("20.0", "20"),
        ("40.0", "40"),
        ("60.0", "60"),
        ("80.0", "80"),
        ("15.0", "15"),
        ("2.0", "2"),
        ("0.10", "0.1"),
    ],
)
def test_format_iec_real(literal, expected):
    assert format_iec_real(literal) == expected


def test_format_iec_real_passthrough_for_non_numeric():
    assert format_iec_real("T#200ms") == "T#200ms"


def test_format_iec_real_passthrough_when_no_dot():
    assert format_iec_real("20") == "20"


@pytest.mark.parametrize(
    "literal,expected",
    [
        ("T#200ms", "TIME#200ms"),
        ("T#500ms", "TIME#500ms"),
        ("T#1s", "TIME#1s0ms"),
        ("T#30s", "TIME#30s0ms"),
        ("TIME#200ms", "TIME#200ms"),
        ("T#-5s", "TIME#-5s0ms"),
    ],
)
def test_format_iec_time(literal, expected):
    assert format_iec_time(literal) == expected


def test_format_iec_time_passthrough_for_unrecognized_shape():
    assert format_iec_time("BOOL") == "BOOL"


def test_simple_declaration_no_init():
    diag = DiagnosticCollector()
    decls = parse_var_block("    Enable : BOOL;\n", diag, "test")
    assert len(decls) == 1
    assert decls[0].name == "Enable"
    assert decls[0].type == BaseType("BOOL")
    assert decls[0].init is None
    assert not diag.has_errors()


def test_declaration_with_simple_init():
    diag = DiagnosticCollector()
    decls = parse_var_block("    MaxStepDescente : INT := 2;\n", diag, "test")
    assert decls[0].init == SimpleInitValue("2")


def test_declaration_real_init_gets_trailing_zero_stripped():
    diag = DiagnosticCollector()
    decls = parse_var_block("    RampAccelRate : REAL := 50.0;\n", diag, "test")
    assert decls[0].init == SimpleInitValue("50")


def test_declaration_real_init_non_integer_left_untouched():
    diag = DiagnosticCollector()
    decls = parse_var_block("    TopLimitM : REAL := 12.5;\n", diag, "test")
    assert decls[0].init == SimpleInitValue("12.5")


def test_time_literal_init_preserved_verbatim():
    diag = DiagnosticCollector()
    decls = parse_var_block("    Timeout : TIME := T#200ms;\n", diag, "test")
    assert decls[0].init == SimpleInitValue("T#200ms")


def test_trailing_inline_comment_attaches_to_its_own_declaration():
    body = "    Enable : BOOL; // active la logique\n    Reset : BOOL;\n"
    diag = DiagnosticCollector()
    decls = parse_var_block(body, diag, "test")
    assert decls[0].documentation == "active la logique"
    assert decls[1].documentation == ""


def test_banner_comment_attaches_to_next_declaration_only():
    body = (
        "    // Position du capteur de fin de course haut\n"
        "    HomingTargetM1_M : REAL := 12.5; // Hauteur cible homing M1\n"
        "    HomingTargetM2_M : REAL := 12.5; // Hauteur cible homing M2\n"
    )
    diag = DiagnosticCollector()
    decls = parse_var_block(body, diag, "test")
    assert decls[0].documentation == (
        "Position du capteur de fin de course haut\nHauteur cible homing M1"
    )
    assert decls[1].documentation == "Hauteur cible homing M2"


def test_block_comment_style_banner_and_trailing_also_supported():
    body = (
        "    (* Paramètres / Calibration *)\n"
        "    TopSensorPositionM : REAL := 12.5;     (* Position cible du capteur haut *)\n"
    )
    diag = DiagnosticCollector()
    decls = parse_var_block(body, diag, "test")
    assert decls[0].documentation == "Paramètres / Calibration\nPosition cible du capteur haut"


def test_derived_type_and_string_type():
    diag = DiagnosticCollector()
    decls = parse_var_block(
        "    Mode : E_Mode;\n    CycleStateStr : STRING(80);\n", diag, "test"
    )
    assert decls[0].type == DerivedType("E_Mode")
    assert decls[1].type == StringType(80)


def test_pointer_to_type_is_skipped_with_warning_not_crash():
    diag = DiagnosticCollector()
    decls = parse_var_block("    X : POINTER TO BOOL;\n    Y : BOOL;\n", diag, "test")
    assert [d.name for d in decls] == ["Y"]
    assert diag.of(Severity.WARNING)
    assert "POINTER" in str(diag.of(Severity.WARNING)[0])


def test_unrecognized_type_expression_is_skipped_with_warning():
    diag = DiagnosticCollector()
    decls = parse_var_block("    X : NotAValidType Extra;\n    Y : BOOL;\n", diag, "test")
    assert [d.name for d in decls] == ["Y"]
    assert diag.of(Severity.WARNING)


def test_struct_composite_init_flat_scalars_preserves_raw_values_and_order():
    """Mirrors CODE/SYSTEM/GVL_PERSISTENT.st GrappinConfig. Composite member
    values are stored raw (unformatted) here: format_iec_real for these is
    applied later by xml_builder once the referenced STRUCT's field types are
    resolved, not at this per-file parsing stage."""
    body = (
        "    GrappinConfig : ST_GrappinConfig := (\n"
        "        OffsetOpenM      := 0.0,\n"
        "        OffsetCloseM     := -1.5,\n"
        "        CoherenceLimitM  := 0.05\n"
        "    );\n"
    )
    diag = DiagnosticCollector()
    decls = parse_var_block(body, diag, "test")
    assert len(decls) == 1
    init = decls[0].init
    assert isinstance(init, StructInitValue)
    as_dict = init.as_dict()
    assert as_dict["OffsetOpenM"] == SimpleInitValue("0.0")
    assert as_dict["OffsetCloseM"] == SimpleInitValue("-1.5")
    assert as_dict["CoherenceLimitM"] == SimpleInitValue("0.05")
    assert [name for name, _ in init.members] == ["OffsetOpenM", "OffsetCloseM", "CoherenceLimitM"]


def test_struct_composite_init_with_array_member():
    """Mirrors WinchM1SpeedStepTable: a struct init containing BOOL members
    plus one ARRAY-typed member (StepThreshold_Pct)."""
    body = (
        "    WinchM1SpeedStepTable : ST_SpeedStepTable := (\n"
        "        P1R1 := TRUE,  P1R2 := FALSE,\n"
        "        StepThreshold_Pct := [20.0, 40.0, 60.0, 80.0, 100.0]\n"
        "    );\n"
    )
    diag = DiagnosticCollector()
    decls = parse_var_block(body, diag, "test")
    init = decls[0].init
    assert isinstance(init, StructInitValue)
    as_dict = init.as_dict()
    assert as_dict["P1R1"] == SimpleInitValue("TRUE")
    assert as_dict["P1R2"] == SimpleInitValue("FALSE")
    array_val = as_dict["StepThreshold_Pct"]
    assert isinstance(array_val, ArrayInitValue)
    assert array_val.items == (
        SimpleInitValue("20.0"),
        SimpleInitValue("40.0"),
        SimpleInitValue("60.0"),
        SimpleInitValue("80.0"),
        SimpleInitValue("100.0"),
    )


def test_comma_inside_comment_does_not_split_composite_init_early():
    """The comma inside the (* ... *) comment text must not be mistaken for a
    top-level struct-member separator (exact pitfall seen with E_CycleStep's
    INIT value documentation, applied here to a composite initializer)."""
    body = (
        "    X : ST_Demo := (\n"
        "        A := 0.0, (* has a comma, right here *)\n"
        "        B := 1.0\n"
        "    );\n"
    )
    diag = DiagnosticCollector()
    decls = parse_var_block(body, diag, "test")
    init = decls[0].init
    assert isinstance(init, StructInitValue)
    assert [name for name, _ in init.members] == ["A", "B"]


def test_qualifier_var_global_constant_still_parses():
    diag = DiagnosticCollector()
    decls = parse_var_block("    X : INT := 1;\n", diag, "test")
    assert len(decls) == 1


def test_enum_values_parsed_with_correct_int_value_and_trailing_comment():
    body = (
        "  INIT                 := 0,   (* Vérifs cohérence états + sécurités, mise en position init *)\n"
        "  WORK_POS_SELECT      := 1,   (* Choix opérateur pos travail 1/2 *)\n"
        "  ERROR_HOLD           := 12   (* Arrêt sûr figé sur défaut *)\n"
    )
    diag = DiagnosticCollector()
    values = parse_enum_values(body, diag, "test")
    assert [(v.name, v.value) for v in values] == [
        ("INIT", 0),
        ("WORK_POS_SELECT", 1),
        ("ERROR_HOLD", 12),
    ]
    assert values[0].documentation == "Vérifs cohérence états + sécurités, mise en position init"
    assert values[1].documentation == "Choix opérateur pos travail 1/2"
    assert values[2].documentation == "Arrêt sûr figé sur défaut"
    assert not diag.has_errors()


def test_enum_values_without_documentation():
    body = "  A := 0,\n  B := 1\n"
    diag = DiagnosticCollector()
    values = parse_enum_values(body, diag, "test")
    assert [(v.name, v.value, v.documentation) for v in values] == [
        ("A", 0, ""),
        ("B", 1, ""),
    ]


def test_enum_values_empty_body_warns():
    diag = DiagnosticCollector()
    values = parse_enum_values("", diag, "test")
    assert values == []
    assert diag.of(Severity.WARNING)


def test_multiple_declarations_banner_and_trailing_do_not_cross_contaminate():
    body = (
        "    A : BOOL; // doc A\n"
        "    // banner for B\n"
        "    B : BOOL;\n"
        "    C : BOOL; // doc C\n"
    )
    diag = DiagnosticCollector()
    decls = parse_var_block(body, diag, "test")
    assert [d.documentation for d in decls] == ["doc A", "banner for B", "doc C"]
