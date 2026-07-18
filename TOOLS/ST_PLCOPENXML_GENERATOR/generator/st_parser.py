from __future__ import annotations

from .diagnostics import DiagnosticCollector
from .ir import GlobalVarBlock, SourceObject
from .st_declarations import parse_enum_values, parse_var_block
from .st_sections import SectionError, split_file

_FB_PROGRAM_TARGETS = {
    "VAR_INPUT": "input_vars",
    "VAR_OUTPUT": "output_vars",
    "VAR_IN_OUT": "inout_vars",
    "VAR_TEMP": "temp_vars",
    "VAR": "local_vars",
}


def parse_file(
    source: str,
    *,
    folder: str,
    stem: str,
    mtime: float,
    source_label: str,
    diagnostics: DiagnosticCollector,
) -> SourceObject | None:
    """Parse one .st source into a SourceObject. Resilience boundary: any
    parsing failure for this file is recorded as an ERROR diagnostic and the
    whole file is skipped (returns None) rather than crashing the run or
    emitting a partially-parsed object."""
    try:
        return _parse_file_unsafe(
            source, folder=folder, stem=stem, mtime=mtime, source_label=source_label, diagnostics=diagnostics
        )
    except (SectionError, ValueError) as exc:
        diagnostics.error(f"failed to parse: {exc}", source_label)
        return None


def _parse_file_unsafe(
    source: str,
    *,
    folder: str,
    stem: str,
    mtime: float,
    source_label: str,
    diagnostics: DiagnosticCollector,
) -> SourceObject:
    sec = split_file(source)

    if sec.kind in ("function_block", "program"):
        obj = SourceObject(
            kind=sec.kind,
            name=sec.name,
            folder=folder,
            file_path=source_label,
            header_comment=sec.header_comment,
            is_public=sec.is_public,
            mtime=mtime,
            attribute_pragmas=sec.attribute_pragmas,
            body_text=sec.body_text or "",
        )
        for block in sec.var_blocks:
            if block.section == "VAR_TEMP":
                diagnostics.warning(
                    "VAR_TEMP encountered (unverified against a real PLCopenXML sample)", source_label
                )
            decls = parse_var_block(block.body, diagnostics, source_label)
            getattr(obj, _FB_PROGRAM_TARGETS[block.section]).extend(decls)
        return obj

    if sec.kind == "struct":
        fields = parse_var_block(sec.struct_body or "", diagnostics, source_label)
        return SourceObject(
            kind="struct",
            name=sec.name,
            folder=folder,
            file_path=source_label,
            header_comment=sec.header_comment,
            mtime=mtime,
            attribute_pragmas=sec.attribute_pragmas,
            struct_fields=fields,
        )

    if sec.kind == "enum":
        values = parse_enum_values(sec.enum_body or "", diagnostics, source_label)
        return SourceObject(
            kind="enum",
            name=sec.name,
            folder=folder,
            file_path=source_label,
            header_comment=sec.header_comment,
            mtime=mtime,
            attribute_pragmas=sec.attribute_pragmas,
            enum_values=values,
        )

    if sec.kind == "gvl":
        blocks: list[GlobalVarBlock] = []
        for block in sec.var_blocks:
            if "CONSTANT" in block.qualifiers:
                diagnostics.warning(
                    "VAR_GLOBAL CONSTANT encountered (unverified against a real PLCopenXML sample)", source_label
                )
            decls = parse_var_block(block.body, diagnostics, source_label)
            blocks.append(GlobalVarBlock(qualifiers=block.qualifiers, variables=decls))
        if len(blocks) > 1:
            diagnostics.info(
                f"{stem} has {len(blocks)} VAR_GLOBAL blocks with distinct qualifiers; "
                f"will emit {len(blocks)} <globalVars> elements",
                source_label,
            )
        return SourceObject(
            kind="gvl",
            name=stem,
            folder=folder,
            file_path=source_label,
            header_comment=sec.header_comment,
            mtime=mtime,
            attribute_pragmas=sec.attribute_pragmas,
            global_blocks=blocks,
        )

    raise SectionError(f"unhandled section kind: {sec.kind!r}")
