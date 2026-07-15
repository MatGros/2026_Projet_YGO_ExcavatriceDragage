import xml.etree.ElementTree as ET

from generator.cli import main
from generator.file_discovery import discover_objects
from generator.diagnostics import DiagnosticCollector

from conftest import CODE_DIR


def _parse_unprefixed(text: str) -> ET.Element:
    """ET.fromstring() re-namespaces every tag ({uri}tag) when it sees the
    document's own 'xmlns=' declaration, regardless of how the tree was
    originally built -- strip it back off so plain-tag find()/findall()
    queries work against a round-tripped generated file."""
    root = ET.fromstring(text)
    for el in root.iter():
        if "}" in el.tag:
            el.tag = el.tag.split("}", 1)[1]
    return root


def test_cli_generates_every_real_object_with_zero_unexpected_errors(tmp_path, capsys):
    out_dir = tmp_path / "generated"

    exit_code = main(["--code-dir", str(CODE_DIR), "--out-dir", str(out_dir)])

    captured = capsys.readouterr()
    assert exit_code == 0, captured.err

    diag = DiagnosticCollector()
    objects = discover_objects(CODE_DIR, diag)
    assert not diag.has_errors()

    generated_files = sorted(out_dir.rglob("*.xml"))
    assert len(generated_files) == len(objects)
    assert len(objects) >= 60

    for path in generated_files:
        data = path.read_bytes()
        assert data[:3] == b"\xef\xbb\xbf", f"{path}: missing UTF-8 BOM"
        text = data.decode("utf-8-sig")
        assert text.startswith('<?xml version="1.0" encoding="utf-8"?>\n')
        assert text.endswith("</project>")
        assert "\r\n" not in text
        assert "ns0:" not in text
        # well-formed: must parse without raising
        ET.fromstring(text)


def test_cli_mirrors_code_folder_structure(tmp_path):
    out_dir = tmp_path / "generated"
    main(["--code-dir", str(CODE_DIR), "--out-dir", str(out_dir)])

    assert (out_dir / "WINCH" / "FB_Winch.xml").is_file()
    assert (out_dir / "GVL_PERSISTENT.xml").is_file()
    assert (out_dir / "CYCLE" / "E_CycleStep.xml").is_file()


def test_cli_single_object_with_deps_embeds_dependency_closure(tmp_path):
    out_dir = tmp_path / "generated"
    exit_code = main(["FB_Winch", "--code-dir", str(CODE_DIR), "--out-dir", str(out_dir)])
    assert exit_code == 0

    generated_files = list(out_dir.rglob("*.xml"))
    assert len(generated_files) == 1  # one file, dependencies embedded inside it, not as separate files

    root = _parse_unprefixed((out_dir / "WINCH" / "FB_Winch.xml").read_text(encoding="utf-8-sig"))
    data_type_names = {dt.get("name") for dt in root.findall(".//dataType")}
    pou_names = {p.get("name") for p in root.findall(".//pou")}
    assert "ST_SpeedStepTable" in data_type_names
    assert "FB_SpeedStep" in pou_names  # FB_SpeedStep is a FUNCTION_BLOCK, so it's a <pou>, not a <dataType>


def test_cli_no_deps_flag_excludes_dependencies(tmp_path):
    out_dir = tmp_path / "generated"
    main(["FB_Winch", "--no-deps", "--code-dir", str(CODE_DIR), "--out-dir", str(out_dir)])

    root = _parse_unprefixed((out_dir / "WINCH" / "FB_Winch.xml").read_text(encoding="utf-8-sig"))
    assert root.findall(".//dataType") == []
    pous = root.findall(".//pou")
    assert [p.get("name") for p in pous] == ["FB_Winch"]


def test_cli_unknown_object_reports_error_and_nonzero_exit(tmp_path, capsys):
    out_dir = tmp_path / "generated"
    exit_code = main(["FB_DoesNotExist", "--code-dir", str(CODE_DIR), "--out-dir", str(out_dir)])
    assert exit_code == 1
    captured = capsys.readouterr()
    assert "FB_DoesNotExist" in captured.err


def test_cli_timestamp_override_is_used_verbatim(tmp_path):
    out_dir = tmp_path / "generated"
    main(
        [
            "E_CycleStep",
            "--code-dir",
            str(CODE_DIR),
            "--out-dir",
            str(out_dir),
            "--timestamp",
            "2020-01-01T00:00:00.000000",
        ]
    )
    root = _parse_unprefixed((out_dir / "CYCLE" / "E_CycleStep.xml").read_text(encoding="utf-8-sig"))
    assert root.find("fileHeader").get("creationDateTime") == "2020-01-01T00:00:00.000000"
    assert root.find("contentHeader").get("modificationDateTime") == "2020-01-01T00:00:00.000000"


def test_cli_project_name_flag_is_used_in_content_header(tmp_path):
    out_dir = tmp_path / "generated"
    main(
        ["E_CycleStep", "--code-dir", str(CODE_DIR), "--out-dir", str(out_dir), "--project-name", "MyProject"]
    )
    root = _parse_unprefixed((out_dir / "CYCLE" / "E_CycleStep.xml").read_text(encoding="utf-8-sig"))
    assert root.find("contentHeader").get("name") == "MyProject.project"
