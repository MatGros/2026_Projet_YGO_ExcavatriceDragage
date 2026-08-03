from __future__ import annotations

import re
from dataclasses import dataclass, field

from .st_lexer import (
    BLOCK_COMMENT,
    LINE_COMMENT,
    comment_text,
    is_blank_code,
    mask,
    token_offsets,
    tokenize,
)


class SectionError(ValueError):
    pass


@dataclass
class VarBlock:
    section: str  # VAR_INPUT | VAR_OUTPUT | VAR_IN_OUT | VAR_TEMP | VAR | VAR_GLOBAL
    qualifiers: list[str]
    body: str  # raw source text between the section header line and END_VAR
    start_line: int


@dataclass
class SectionizedFile:
    kind: str  # function_block | program | struct | enum | gvl
    name: str | None  # None for gvl; caller derives it from the filename
    is_public: bool
    header_comment: str
    attribute_pragmas: list[str] = field(default_factory=list)
    var_blocks: list[VarBlock] = field(default_factory=list)
    struct_body: str | None = None
    enum_body: str | None = None
    body_text: str | None = None


_PRAGMA_RE = re.compile(r"\{attribute\s+'([^']*)'\}[ \t]*\n?")
_FB_RE = re.compile(r"FUNCTION_BLOCK[ \t]+(PUBLIC[ \t]+)?(\w+)")
_PROGRAM_RE = re.compile(r"PROGRAM[ \t]+(\w+)")
_TYPE_RE = re.compile(r"TYPE[ \t]+(\w+)[ \t]*:\s*")
_VAR_SECTION_RE = re.compile(
    r"(VAR_INPUT|VAR_OUTPUT|VAR_IN_OUT|VAR_TEMP|VAR_GLOBAL|VAR)([ \t]+[A-Z_ \t]+)?[ \t]*\n"
)


def _skip_blank(text: str, pos: int) -> int:
    while pos < len(text) and text[pos] in " \t\r\n":
        pos += 1
    return pos


def _find_matching_paren(text: str, open_index: int) -> int:
    depth = 0
    for i in range(open_index, len(text)):
        if text[i] == "(":
            depth += 1
        elif text[i] == ")":
            depth -= 1
            if depth == 0:
                return i
    raise SectionError("unbalanced parentheses in ENUM body")


def _consume_header_comment(source: str) -> tuple[str, int]:
    tokens = tokenize(source)
    offsets = token_offsets(tokens)
    pending: list[str] = []
    cursor = 0
    for offset, token in zip(offsets, tokens):
        if token.kind in (LINE_COMMENT, BLOCK_COMMENT):
            pending.append(comment_text(token))
            cursor = offset + len(token.text)
            continue
        if is_blank_code(token):
            cursor = offset + len(token.text)
            continue
        break
    header_comment = "\n".join(p for p in pending if p)
    return header_comment, cursor


def _consume_attribute_pragmas(source: str, masked: str, cursor: int) -> tuple[list[str], int]:
    pragmas: list[str] = []
    cursor = _skip_blank(masked, cursor)
    while True:
        match = _PRAGMA_RE.match(source, cursor)
        if not match:
            break
        pragmas.append(match.group(1))
        cursor = _skip_blank(masked, match.end())
    return pragmas, cursor


def _parse_var_blocks(source: str, masked: str, cursor: int) -> tuple[list[VarBlock], int]:
    blocks: list[VarBlock] = []
    pos = _skip_blank(masked, cursor)
    # Position right after the last "END_VAR", with no skip_blank applied --
    # this is what the caller uses as the FB/PROGRAM body_start. skip_blank
    # walks over masked text, where a comment is blanked to spaces just like
    # real whitespace, so applying it here would silently swallow a genuine
    # leading comment on the implementation body (confirmed against
    # FB_Grappin.xml: its body legitimately starts with "// GATE DE
    # SÉCURITÉ" -- CODESYS keeps it, so must we).
    end_of_last_block = pos
    while True:
        match = _VAR_SECTION_RE.match(masked, pos)
        if not match:
            break
        section = match.group(1)
        qualifiers = (match.group(2) or "").split()
        body_start = match.end()
        end_var = masked.index("END_VAR", body_start)
        body = source[body_start:end_var]
        start_line = source[:body_start].count("\n") + 1
        blocks.append(VarBlock(section, qualifiers, body, start_line))
        end_of_last_block = end_var + len("END_VAR")
        pos = _skip_blank(masked, end_of_last_block)
    return blocks, end_of_last_block


def _strip_pou_terminator(source: str, masked: str, body_start: int, terminator: str) -> str:
    """Return implementation body without the trailing POU terminator token.

    Some .st sources end with END_PROGRAM/END_FUNCTION_BLOCK. CODESYS adds its
    own terminator on import, so the generator MUST NOT emit this token inside
    the <ST><xhtml> body — a duplicate causes C0009 "Jeton inattendu" at the
    exact line of the embedded token. Strip it (and trailing whitespace) here.
    """
    body = source[body_start:]
    masked_body = masked[body_start:]
    idx = masked_body.rfind(terminator)
    if idx == -1:
        return body
    # Cut at the terminator; keep trailing comment/whitespace only if present
    # before the token. The terminator itself and anything after is dropped.
    return body[:idx].rstrip() + "\n"


def split_file(source: str) -> SectionizedFile:
    header_comment, cursor = _consume_header_comment(source)
    masked = mask(tokenize(source))
    attribute_pragmas, cursor = _consume_attribute_pragmas(source, masked, cursor)

    fb_match = _FB_RE.match(masked, cursor)
    if fb_match:
        var_blocks, body_start = _parse_var_blocks(source, masked, fb_match.end())
        return SectionizedFile(
            kind="function_block",
            name=fb_match.group(2),
            is_public=bool(fb_match.group(1)),
            header_comment=header_comment,
            attribute_pragmas=attribute_pragmas,
            var_blocks=var_blocks,
            body_text=_strip_pou_terminator(source, masked, body_start, "END_FUNCTION_BLOCK"),
        )

    program_match = _PROGRAM_RE.match(masked, cursor)
    if program_match:
        var_blocks, body_start = _parse_var_blocks(source, masked, program_match.end())
        return SectionizedFile(
            kind="program",
            name=program_match.group(1),
            is_public=False,
            header_comment=header_comment,
            attribute_pragmas=attribute_pragmas,
            var_blocks=var_blocks,
            body_text=_strip_pou_terminator(source, masked, body_start, "END_PROGRAM"),
        )

    type_match = _TYPE_RE.match(masked, cursor)
    if type_match:
        name = type_match.group(1)
        after_type = _skip_blank(masked, type_match.end())
        if masked[after_type : after_type + 6] == "STRUCT":
            struct_start = after_type + len("STRUCT")
            end_struct = masked.index("END_STRUCT", struct_start)
            return SectionizedFile(
                kind="struct",
                name=name,
                is_public=False,
                header_comment=header_comment,
                attribute_pragmas=attribute_pragmas,
                struct_body=source[struct_start:end_struct],
            )
        if masked[after_type : after_type + 1] == "(":
            close_paren = _find_matching_paren(masked, after_type)
            return SectionizedFile(
                kind="enum",
                name=name,
                is_public=False,
                header_comment=header_comment,
                attribute_pragmas=attribute_pragmas,
                enum_body=source[after_type + 1 : close_paren],
            )
        if masked[after_type : after_type + 4] == "ENUM":
            enum_start = after_type + len("ENUM")
            end_enum = masked.index("END_ENUM", enum_start)
            return SectionizedFile(
                kind="enum",
                name=name,
                is_public=False,
                header_comment=header_comment,
                attribute_pragmas=attribute_pragmas,
                enum_body=source[enum_start:end_enum],
            )
        raise SectionError(f"unrecognized TYPE construct for {name!r}: neither STRUCT nor ENUM")

    var_blocks, _ = _parse_var_blocks(source, masked, cursor)
    if var_blocks and all(b.section == "VAR_GLOBAL" for b in var_blocks):
        return SectionizedFile(
            kind="gvl",
            name=None,
            is_public=False,
            header_comment=header_comment,
            attribute_pragmas=attribute_pragmas,
            var_blocks=var_blocks,
        )

    raise SectionError(
        "no recognizable root construct (FUNCTION_BLOCK/PROGRAM/TYPE/VAR_GLOBAL) found"
    )
