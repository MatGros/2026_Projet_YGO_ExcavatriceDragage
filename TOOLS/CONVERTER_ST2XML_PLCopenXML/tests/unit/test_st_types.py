import pytest

from generator.st_types import (
    ArrayType,
    BaseType,
    DerivedType,
    StringType,
    parse_type,
    referenced_type_names,
)


@pytest.mark.parametrize(
    "text,expected_name",
    [
        ("BOOL", "BOOL"),
        ("INT", "INT"),
        ("DINT", "DINT"),
        ("UINT", "UINT"),
        ("UDINT", "UDINT"),
        ("WORD", "WORD"),
        ("REAL", "REAL"),
        ("TIME", "TIME"),
    ],
)
def test_base_types(text, expected_name):
    assert parse_type(text) == BaseType(expected_name)


def test_string_with_length():
    assert parse_type("STRING(80)") == StringType(80)


def test_string_with_spaces():
    assert parse_type("STRING ( 80 )") == StringType(80)


@pytest.mark.parametrize(
    "text",
    ["E_Mode", "FB_SpeedStep", "ST_SpeedStepTable", "TON", "R_TRIG"],
)
def test_derived_types(text):
    assert parse_type(text) == DerivedType(text)


def test_array_of_real():
    result = parse_type("ARRAY[1..5] OF REAL")
    assert result == ArrayType(1, 5, BaseType("REAL"))


def test_array_of_derived():
    result = parse_type("ARRAY[0..3] OF ST_SpeedStepTable")
    assert result == ArrayType(0, 3, DerivedType("ST_SpeedStepTable"))


def test_array_with_negative_bounds():
    result = parse_type("ARRAY[-2..2] OF INT")
    assert result == ArrayType(-2, 2, BaseType("INT"))


def test_array_multi_dimension():
    # REX : ARRAY[1..2, 1..2, 1..2, 1..5] OF T (FB_WinchSpeedLearning, T181-15) était
    # silencieusement ignoré par _ARRAY_RE (une seule paire de bornes gérée) -> le champ
    # struct était absent du <struct/> exporté -> CODESYS C0046/C0004 "Cell non défini".
    result = parse_type("ARRAY[1..2, 1..2, 1..2, 1..5] OF ST_fbWinchSpeedLearning_Cell")
    assert result == ArrayType(
        1, 2, DerivedType("ST_fbWinchSpeedLearning_Cell"), extra_dims=((1, 2), (1, 2), (1, 5))
    )


def test_array_single_dimension_has_no_extra_dims():
    result = parse_type("ARRAY[1..5] OF REAL")
    assert result.extra_dims == ()


def test_empty_type_raises():
    with pytest.raises(ValueError):
        parse_type("")


def test_malformed_type_raises():
    with pytest.raises(ValueError):
        parse_type("1NotAnIdentifier")


def test_referenced_type_names_base_type_is_empty():
    assert referenced_type_names(BaseType("BOOL")) == set()


def test_referenced_type_names_string_is_empty():
    assert referenced_type_names(StringType(80)) == set()


def test_referenced_type_names_derived_type():
    assert referenced_type_names(DerivedType("FB_SpeedStep")) == {"FB_SpeedStep"}


def test_referenced_type_names_array_of_derived():
    array = ArrayType(1, 5, DerivedType("ST_SpeedStepTable"))
    assert referenced_type_names(array) == {"ST_SpeedStepTable"}


def test_referenced_type_names_array_of_base_is_empty():
    array = ArrayType(1, 5, BaseType("REAL"))
    assert referenced_type_names(array) == set()
