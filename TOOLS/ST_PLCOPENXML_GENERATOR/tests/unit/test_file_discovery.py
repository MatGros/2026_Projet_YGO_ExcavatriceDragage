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
    assert objects[0].folder == ""


def test_standalone_ld_export_is_excluded_from_discovery(tmp_path):
    _write(tmp_path / "PRG_01_Inputs_LD.st", "PROGRAM PRG_01_Inputs_LD\nEND_PROGRAM\n")
    _write(
        tmp_path / "PRG_01_Inputs_LD.xml",
        '<project><pou name="PRG_01_Inputs_LD" pouType="program"><body><LD /></body></pou></project>',
    )

    diag = DiagnosticCollector()
    objects = discover_objects(tmp_path, diag)

    assert [object_.name for object_ in objects] == ["PRG_01_Inputs_LD"]
    assert any("standalone LD export" in str(info) for info in diag.of(Severity.INFO))


def test_real_code_dir_dynamic_count_relationship():
    """CODE/ isn't a fixed number we hardcode here: recompute it from disk so
    this stays meaningful as files are added/removed."""
    all_st_files = sorted(CODE_DIR.rglob("*.st"))
    all_native_xml = [f for f in CODE_DIR.rglob("*.xml") if f.name != "CODE_Bundle.xml"]
    standalone_ld_exports = [
        file for file in all_native_xml if file.stem.endswith("_LD") and file.with_suffix(".st").is_file()
    ]
    decl_impl_files = [file for file in all_st_files if file.name.endswith("_Decl.st") or file.name.endswith("_Impl.st")]

    diag = DiagnosticCollector()
    objects = discover_objects(CODE_DIR, diag)

    assert len(objects) == len(all_st_files) + len(all_native_xml) - len(standalone_ld_exports) - len(decl_impl_files)
    assert not diag.has_errors()


def test_real_gvl_modes_removed():
    """GVL_Modes_Stub a été supprimé (refactoring): les signaux viennent maintenant directement de GVL_IHM."""
    diag = DiagnosticCollector()
    objects = discover_objects(CODE_DIR, diag)
    names = {o.name for o in objects}
    assert "GVL_Modes_Stub" not in names, "GVL_Modes_Stub devrait être supprimé"
    # Vérifier que les signaux sont désormais dans GVL_IHM
    gvl_ihm = next((o for o in objects if o.name == "GVL_IHM"), None)
    assert gvl_ihm is not None, "GVL_IHM doit exister"
    assert len(gvl_ihm.global_blocks) >= 1, "GVL_IHM doit avoir des blocs globaux"


def test_real_prg_modes_cfc_object_present_and_named_from_stem():
    diag = DiagnosticCollector()
    objects = discover_objects(CODE_DIR, diag)
    prg = next(o for o in objects if o.name == "PRG_MODES_CFC")
    assert prg.kind == "program"
    # Vérifier que le programme a été parsé correctement
    # instModes est une variable locale (VAR), Auth est une sortie (VAR_OUTPUT)
    assert any(v.name == "instModes" for v in prg.local_vars)
    assert len(prg.output_vars) >= 1  # Auth au minimum
    assert any(v.name == "Auth" for v in prg.output_vars)

