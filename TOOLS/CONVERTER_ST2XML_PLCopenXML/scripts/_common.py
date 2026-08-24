"""Shared helpers for CONVERTER_ST2XML_PLCopenXML CLI scripts.

This module ensures the ``generator`` package is importable when scripts are
run directly (``python scripts/st_to_ld.py ...``) and provides small parsing
utilities that reuse ``generator.st_parser`` and ``generator.file_discovery``
without duplicating their logic.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

# ── Path bootstrap: make ``generator`` importable ──────────────────────────
# scripts/  →  parent  =  TOOLS/CONVERTER_ST2XML_PLCopenXML/  (contains generator/)
_TOOL_ROOT = Path(__file__).resolve().parent.parent
if str(_TOOL_ROOT) not in sys.path:
    sys.path.insert(0, str(_TOOL_ROOT))

from generator.diagnostics import DiagnosticCollector  # noqa: E402
from generator.ir import SourceObject  # noqa: E402
from generator.st_parser import parse_file  # noqa: E402
from generator.xml_builder import build_project_xml  # noqa: E402
from generator.xml_serializer import serialize as _serialize_element  # noqa: E402

_POU_NAME_RE = re.compile(r'<pou\s+name="([^"]+)"')


def parse_single_st_file(path: Path, diagnostics: DiagnosticCollector) -> SourceObject | None:
    """Parse one ``.st`` file into a :class:`SourceObject`.

    The folder is derived from the immediate parent directory name (mirrors
    ``file_discovery.discover_objects`` which uses the path relative to the
    code-dir root).  A file at the root gets ``folder=""``.
    """
    source = path.read_text(encoding="utf-8")
    parent = path.parent
    folder = "" if parent.name in ("", ".") else parent.name
    return parse_file(
        source,
        folder=folder,
        stem=path.stem,
        mtime=path.stat().st_mtime,
        source_label=path.name,
        diagnostics=diagnostics,
    )


def cfc_pou_name(path: Path) -> str:
    """Extract the ``<pou name="...">`` value from a native CFC XML file."""
    text = path.read_text(encoding="utf-8")
    match = _POU_NAME_RE.search(text)
    return match.group(1) if match else path.stem


def make_cfc_source_object(path: Path) -> SourceObject:
    """Build a minimal :class:`SourceObject` wrapping a native CFC ``.xml`` file.

    ``build_project_xml`` already handles ``raw_xml_path`` extraction,
    namespace cleaning, and ObjectId alignment — this helper just creates the
    IR object it needs.
    """
    parent = path.parent
    folder = "" if parent.name in ("", ".") else parent.name
    return SourceObject(
        kind="program",
        name=cfc_pou_name(path),
        folder=folder,
        file_path=path.name,
        mtime=path.stat().st_mtime,
        raw_xml_path=str(path),
    )


def build_multi_file_project(
    objects_by_name: dict[str, SourceObject],
    root_names: list[str],
    diagnostics: DiagnosticCollector,
    *,
    project_name: str = "Generated",
) -> bytes:
    """Assemble a full PLCopenXML ``<project>`` bundle from multiple objects.

    Wraps :func:`build_project_xml` and serializes the result. Used by the
    CLI scripts (``st_to_ld.py``, ``st_to_pou.py``, ``cfc_extract.py``,
    ``st_to_dut.py``) when more than one input file is provided.
    """
    root = build_project_xml(
        root_names,
        objects_by_name,
        diagnostics,
        include_deps=True,
        project_name=project_name,
    )
    return _serialize_element(root)