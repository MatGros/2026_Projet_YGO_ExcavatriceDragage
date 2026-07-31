"""Shared helpers for ST_PLCOPENXML_GENERATOR CLI scripts.

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
# scripts/  →  parent  =  TOOLS/ST_PLCOPENXML_GENERATOR/  (contains generator/)
_TOOL_ROOT = Path(__file__).resolve().parent.parent
if str(_TOOL_ROOT) not in sys.path:
    sys.path.insert(0, str(_TOOL_ROOT))

from generator.diagnostics import DiagnosticCollector  # noqa: E402
from generator.ir import SourceObject  # noqa: E402
from generator.st_parser import parse_file  # noqa: E402

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