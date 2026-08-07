from pathlib import Path

from generator.dependency_resolver import STANDARD_BLOCKS, resolve_dependencies
from generator.diagnostics import DiagnosticCollector, Severity
from generator.file_discovery import discover_objects
from generator.ir import SourceObject, VariableDecl
from generator.st_types import BaseType, DerivedType

from conftest import CODE_DIR


def _obj(name, kind="function_block", **var_lists):
    return SourceObject(kind=kind, name=name, folder="X", file_path=f"{name}.st", **var_lists)


def test_no_dependencies_returns_just_the_root():
    obj = _obj("FB_Leaf", input_vars=[VariableDecl("A", BaseType("BOOL"))])
    diag = DiagnosticCollector()
    result = resolve_dependencies(["FB_Leaf"], {"FB_Leaf": obj}, diag)
    assert result == ["FB_Leaf"]
    assert not diag.of(Severity.WARNING)


def test_direct_dependency_is_included():
    leaf = _obj("ST_Leaf", kind="struct", struct_fields=[VariableDecl("A", BaseType("BOOL"))])
    root = _obj("FB_Root", input_vars=[VariableDecl("X", DerivedType("ST_Leaf"))])
    diag = DiagnosticCollector()
    result = resolve_dependencies(["FB_Root"], {"FB_Root": root, "ST_Leaf": leaf}, diag)
    assert result == ["FB_Root", "ST_Leaf"]


def test_transitive_dependency_is_included():
    grandchild = _obj("E_Grand", kind="enum")
    child = _obj("ST_Child", kind="struct", struct_fields=[VariableDecl("M", DerivedType("E_Grand"))])
    root = _obj("FB_Root", input_vars=[VariableDecl("X", DerivedType("ST_Child"))])
    diag = DiagnosticCollector()
    objects = {"FB_Root": root, "ST_Child": child, "E_Grand": grandchild}
    result = resolve_dependencies(["FB_Root"], objects, diag)
    assert set(result) == {"FB_Root", "ST_Child", "E_Grand"}


def test_cycle_does_not_infinite_loop():
    a = _obj("FB_A", input_vars=[VariableDecl("X", DerivedType("FB_B"))])
    b = _obj("FB_B", input_vars=[VariableDecl("Y", DerivedType("FB_A"))])
    diag = DiagnosticCollector()
    result = resolve_dependencies(["FB_A"], {"FB_A": a, "FB_B": b}, diag)
    assert set(result) == {"FB_A", "FB_B"}
    assert len(result) == 2


def test_standard_iec_blocks_are_excluded_from_closure():
    obj = _obj(
        "FB_Root",
        local_vars=[VariableDecl("Ton1", DerivedType("TON")), VariableDecl("Edge", DerivedType("R_TRIG"))],
    )
    diag = DiagnosticCollector()
    result = resolve_dependencies(["FB_Root"], {"FB_Root": obj}, diag)
    assert result == ["FB_Root"]
    assert not diag.of(Severity.WARNING)


def test_unknown_referenced_type_warns_and_is_excluded():
    obj = _obj("FB_Root", input_vars=[VariableDecl("X", DerivedType("ST_DoesNotExist"))])
    diag = DiagnosticCollector()
    result = resolve_dependencies(["FB_Root"], {"FB_Root": obj}, diag)
    assert result == ["FB_Root"]
    warnings = [str(w) for w in diag.of(Severity.WARNING)]
    assert any("ST_DoesNotExist" in w for w in warnings)


def test_array_of_derived_type_counts_as_a_dependency():
    leaf = _obj("ST_Leaf", kind="struct")
    root = _obj("FB_Root")
    from generator.st_types import ArrayType

    root.struct_fields.append(VariableDecl("Arr", ArrayType(1, 5, DerivedType("ST_Leaf"))))
    diag = DiagnosticCollector()
    result = resolve_dependencies(["FB_Root"], {"FB_Root": root, "ST_Leaf": leaf}, diag)
    assert "ST_Leaf" in result


def test_real_fb_winch_dependency_closure_excludes_standard_blocks_includes_expected_types():
    diag = DiagnosticCollector()
    objects = discover_objects(CODE_DIR, diag)
    objects_by_name = {o.name: o for o in objects}

    result = resolve_dependencies(["FB_Winch"], objects_by_name, diag)

    assert "FB_Winch" in result
    assert "ST_SpeedStepTable" in result
    assert "FB_SpeedStep" in result
    # 🆕 2026-08-06 (retrait FB_Brake, demande client) : FB_Winch ne compose plus FB_Brake --
    # le frein est desormais un couplage direct RelayFwd/RelayRev calcule dans
    # FB_WinchOutputInterlock_LD, cable au grand jour dans PRG_06_Outputs_LD.
    assert "FB_Brake" not in result
    assert "ST_ContactorCheck" in result
    assert "E_State" in result
    for standard_name in STANDARD_BLOCKS:
        assert standard_name not in result
