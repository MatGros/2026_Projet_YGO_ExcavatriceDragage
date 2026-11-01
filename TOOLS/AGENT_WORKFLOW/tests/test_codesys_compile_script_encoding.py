"""Regression tests for Unicode-safe generated CODESYS IronPython runners."""

from __future__ import annotations

import sys
from pathlib import Path
from unittest.mock import patch

REPO_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO_ROOT / "TOOLS" / "AGENT_WORKFLOW" / "scripts"))

import test_codesys_compile as compile_tool  # noqa: E402


class ScriptSink:
    def __init__(self) -> None:
        self.content = ""

    def write_text(self, content: str, encoding: str) -> None:
        assert encoding == "utf-8"
        self.content = content


def test_generated_runner_declares_utf8_for_unicode_project_paths() -> None:
    script = ScriptSink()
    project_path = Path("C:/tmp/projet_simulé.project")
    xml_path = Path("C:/tmp/FB_Translation_été.xml")
    log_path = Path("C:/tmp/résultat_compilation.log")

    compile_tool.create_ironpython_script(script, project_path, xml_path, log_path)  # type: ignore[arg-type]
    generated = script.content

    assert generated.startswith("# -*- coding: utf-8 -*-\n")
    assert "Using the CODESYS --noUI default prompt policy" in generated
    assert "PromptChoice." not in generated
    assert "PromptHandling(" not in generated
    assert 'trace_file = log_file + ".trace"' in generated
    assert 'open("C:/tmp/trace.log"' not in generated
    assert "projects.open(project_file, primary=True, update_flags=VersionUpdateFlags.NoUpdates)" in generated
    assert str(project_path).replace("\\", "/") in generated
    assert str(xml_path).replace("\\", "/") in generated
    assert str(log_path).replace("\\", "/") in generated


def test_baseline_runner_disables_xml_import() -> None:
    script = ScriptSink()
    compile_tool.create_ironpython_script(script, Path("project"), Path("input.xml"), Path("result"), baseline=True)  # type: ignore[arg-type]
    assert "if False:\n        trace(\"5. Importing XML" in script.content


def test_runner_traces_native_message_metadata() -> None:
    script = ScriptSink()
    compile_tool.create_ironpython_script(script, Path("project"), Path("input.xml"), Path("result"))  # type: ignore[arg-type]
    assert "for index, message in enumerate(msgs):" in script.content
    assert "for name in dir(message):" in script.content
    assert 'trace("Message[%s].%s=%s"' in script.content
    assert 'trace("Application.is_active_application=" + str(app.is_active_application))' in script.content
    assert 'trace("Simulation device name=" + device_name)' in script.content
    assert "device_repository.get_device(device.get_device_identification())" in script.content
    assert 'for name in ("name", "vendor", "description", "order_number")' in script.content


def test_incremental_option_uses_application_build() -> None:
    script = ScriptSink()
    compile_tool.create_ironpython_script(
        script,
        Path("project"),
        Path("input.xml"),
        Path("result"),
        incremental=True,
    )  # type: ignore[arg-type]
    assert 'trace("7. Building active application..." if True' in script.content
    assert "if True:\n        app.build()" in script.content


def test_generate_code_option_is_separate_from_build() -> None:
    script = ScriptSink()
    compile_tool.create_ironpython_script(
        script,
        Path("project"),
        Path("input.xml"),
        Path("result"),
        generate_code=True,
    )  # type: ignore[arg-type]
    assert 'trace("7. Generating application code...")' in script.content
    assert "if True:\n        app.generate_code()" in script.content


def test_compile_workspace_is_retained_in_authorized_gate_scratch() -> None:
    expected = REPO_ROOT / "TOOLS" / "AGENT_WORKFLOW" / ".tmp" / "codesys_compile_FB_Sim_Translation_run"
    scratch_root = expected.parent
    with patch.object(compile_tool.Path, "mkdir") as mkdir, patch.object(
        compile_tool.tempfile, "mkdtemp", return_value=str(expected)
    ) as make_temp:
        actual = compile_tool.create_retained_scratch("FB_Sim_Translation")

    assert actual == expected
    mkdir.assert_called_once_with(parents=True, exist_ok=True)
    make_temp.assert_called_once_with(prefix="codesys_compile_FB_Sim_Translation_", dir=scratch_root)
