from pathlib import Path

from generator.diagnostics import DiagnosticCollector, Severity
from generator.file_discovery import discover_objects

from conftest import CODE_DIR


def _write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def test_identical_decl_impl_pair_is_excluded_with_info_diagnostic(tmp_path):
    decl = "FUNCTION_BLOCK FB_X\nVAR_INPUT\n    A : BOOL;\nEND_VAR\n"
    impl = "A := TRUE;\n"
    _write(tmp_path / "FB_X_Decl.st", decl)
    _write(tmp_path / "FB_X_Impl.st", impl)
    _write(tmp_path / "FB_X.st", decl + impl)

    diag = DiagnosticCollector()
    objects = discover_objects(tmp_path, diag)

    assert [o.name for o in objects] == ["FB_X"]
    assert not diag.has_errors()
    infos = [str(d) for d in diag.of(Severity.INFO)]
    assert any("FB_X_Decl.st + FB_X_Impl.st" in i for i in infos)
    assert not diag.of(Severity.WARNING)


def test_stale_mismatched_decl_impl_pair_is_excluded_with_warning_diagnostic(tmp_path):
    decl = "FUNCTION_BLOCK FB_X\nVAR_INPUT\n    A : BOOL;\nEND_VAR\n"
    impl = "A := TRUE;\n"
    merged = "FUNCTION_BLOCK FB_X\nVAR_INPUT\n    A : BOOL;\n    B : BOOL;\nEND_VAR\nA := TRUE;\n"
    _write(tmp_path / "FB_X_Decl.st", decl)
    _write(tmp_path / "FB_X_Impl.st", impl)
    _write(tmp_path / "FB_X.st", merged)

    diag = DiagnosticCollector()
    objects = discover_objects(tmp_path, diag)

    assert [o.name for o in objects] == ["FB_X"]
    assert [v.name for v in objects[0].input_vars] == ["A", "B"]
    warnings = [str(d) for d in diag.of(Severity.WARNING)]
    assert any("does NOT match" in w for w in warnings)


def test_incomplete_decl_impl_trio_warns(tmp_path):
    _write(tmp_path / "FB_X_Decl.st", "FUNCTION_BLOCK FB_X\nVAR_INPUT\n    A : BOOL;\nEND_VAR\n")
    # no _Impl.st, no merged FB_X.st

    diag = DiagnosticCollector()
    objects = discover_objects(tmp_path, diag)

    assert objects == []
    warnings = [str(d) for d in diag.of(Severity.WARNING)]
    assert any("incomplete" in w for w in warnings)


def test_gvl_name_derived_from_filename(tmp_path):
    _write(tmp_path / "GVL_Demo.st", "VAR_GLOBAL\n    X : BOOL;\nEND_VAR\n")
    diag = DiagnosticCollector()
    objects = discover_objects(tmp_path, diag)
    assert [o.name for o in objects] == ["GVL_Demo"]
    assert objects[0].folder == tmp_path.name


def test_real_code_dir_dynamic_count_relationship():
    """CODE/ isn't a fixed number we hardcode here: recompute it from disk so
    this stays meaningful as files are added/removed."""
    all_st_files = sorted(CODE_DIR.rglob("*.st"))
    decl_impl_files = [f for f in all_st_files if f.name.endswith("_Decl.st") or f.name.endswith("_Impl.st")]

    diag = DiagnosticCollector()
    objects = discover_objects(CODE_DIR, diag)

    assert len(objects) == len(all_st_files) - len(decl_impl_files)
    assert not diag.has_errors()


def test_real_fb_winch_and_fb_winchsync_pairs_are_identical_info_only():
    diag = DiagnosticCollector()
    discover_objects(CODE_DIR, diag)
    infos = [str(d) for d in diag.of(Severity.INFO)]
    assert any("FB_WinchSync_Decl.st + FB_WinchSync_Impl.st" in i for i in infos)


def test_real_fb_winch_pair_is_flagged_stale():
    diag = DiagnosticCollector()
    discover_objects(CODE_DIR, diag)
    warnings = [str(d) for d in diag.of(Severity.WARNING)]
    assert any("FB_Winch_Decl.st + FB_Winch_Impl.st" in w and "does NOT match" in w for w in warnings)


def test_real_fb_safety_winch_pair_is_flagged_stale():
    diag = DiagnosticCollector()
    discover_objects(CODE_DIR, diag)
    warnings = [str(d) for d in diag.of(Severity.WARNING)]
    assert any("FB_Safety_Winch_Decl.st + FB_Safety_Winch_Impl.st" in w and "does NOT match" in w for w in warnings)


def test_real_gvl_modes_stub_object_present_and_named_from_stem():
    diag = DiagnosticCollector()
    objects = discover_objects(CODE_DIR, diag)
    stub = next(o for o in objects if o.name == "GVL_Modes_Stub")
    assert stub.kind == "gvl"
    assert len(stub.global_blocks) == 1
