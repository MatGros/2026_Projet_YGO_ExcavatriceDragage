from __future__ import annotations

import re

from .diagnostics import DiagnosticCollector
from .ir import (
    ArrayInitValue,
    EnumValueDecl,
    InitValue,
    SimpleInitValue,
    StructInitValue,
    VariableDecl,
    format_iec_real,
)
from .st_lexer import BLOCK_COMMENT, LINE_COMMENT, comment_text, mask, token_offsets, tokenize
from .st_types import BaseType, parse_type

_ENUM_ENTRY_RE = re.compile(r"([A-Za-z_]\w*)\s*:=\s*(-?\d+)")


def _find_toplevel_char(masked_text: str, char: str) -> int:
    depth = 0
    for i, c in enumerate(masked_text):
        if c in "([":
            depth += 1
        elif c in ")]":
            depth -= 1
        elif depth == 0 and c == char:
            return i
    return -1


def _find_toplevel_str(masked_text: str, needle: str) -> int:
    depth = 0
    n = len(masked_text)
    m = len(needle)
    i = 0
    while i < n:
        c = masked_text[i]
        if c in "([":
            depth += 1
        elif c in ")]":
            depth -= 1
        elif depth == 0 and masked_text[i : i + m] == needle:
            return i
        i += 1
    return -1


def _find_toplevel_positions(masked_text: str, char: str) -> list[int]:
    depth = 0
    positions = []
    for i, c in enumerate(masked_text):
        if c in "([":
            depth += 1
        elif c in ")]":
            depth -= 1
        elif depth == 0 and c == char:
            positions.append(i)
    return positions


def _split_toplevel(masked_text: str, sep: str) -> list[tuple[int, int]]:
    depth = 0
    spans = []
    start = 0
    for i, c in enumerate(masked_text):
        if c in "([":
            depth += 1
        elif c in ")]":
            depth -= 1
        elif depth == 0 and c == sep:
            spans.append((start, i))
            start = i + 1
    spans.append((start, len(masked_text)))
    return spans


def _comment_text_in(raw_span: str) -> str:
    parts = [comment_text(tok) for tok in tokenize(raw_span) if tok.kind in (LINE_COMMENT, BLOCK_COMMENT)]
    return "\n".join(p for p in parts if p)


def _trim_to_masked_content(raw: str, masked: str) -> tuple[str, str]:
    """Trim leading/trailing blank-or-comment padding using the masked view
    (comments are blanked to spaces there, real content is not) and apply the
    same slice bounds to raw -- unlike independent raw.strip()/masked.strip(),
    this correctly drops a trailing same-line comment from raw too (e.g. the
    last member of a composite initializer, which has no following comma to
    otherwise separate its value from a trailing '// comment')."""
    start = 0
    end = len(masked)
    while start < end and masked[start] in " \t\r\n":
        start += 1
    while end > start and masked[end - 1] in " \t\r\n":
        end -= 1
    return raw[start:end], masked[start:end]


def _parse_init_value(raw: str, masked_view: str) -> InitValue:
    raw_s, masked_s = _trim_to_masked_content(raw, masked_view)
    if masked_s.startswith("(") and masked_s.endswith(")"):
        return _parse_struct_init(raw_s[1:-1], masked_s[1:-1])
    if masked_s.startswith("[") and masked_s.endswith("]"):
        return _parse_array_init(raw_s[1:-1], masked_s[1:-1])
    return SimpleInitValue(raw_s)


def _parse_array_init(raw_inner: str, masked_inner: str) -> ArrayInitValue:
    items = []
    for start, end in _split_toplevel(masked_inner, ","):
        chunk_masked = masked_inner[start:end]
        if not chunk_masked.strip():
            continue
        items.append(_parse_init_value(raw_inner[start:end], chunk_masked))
    return ArrayInitValue(tuple(items))


def _parse_struct_init(raw_inner: str, masked_inner: str) -> StructInitValue:
    members: list[tuple[str, InitValue]] = []
    for start, end in _split_toplevel(masked_inner, ","):
        chunk_masked = masked_inner[start:end]
        if not chunk_masked.strip():
            continue
        chunk_raw, chunk_masked = _trim_to_masked_content(raw_inner[start:end], chunk_masked)
        assign_pos = _find_toplevel_str(chunk_masked, ":=")
        if assign_pos == -1:
            raise ValueError(f"composite member missing ':=': {chunk_raw!r}")
        field_name = chunk_raw[:assign_pos].strip()
        value_raw = chunk_raw[assign_pos + 2 :]
        value_masked = chunk_masked[assign_pos + 2 :]
        members.append((field_name, _parse_init_value(value_raw, value_masked)))
    return StructInitValue(tuple(members))


def parse_var_block(body_text: str, diagnostics: DiagnosticCollector, source_label: str) -> list[VariableDecl]:
    tokens = tokenize(body_text)
    masked = mask(tokens)

    semi_positions = _find_toplevel_positions(masked, ";")

    decls: list[VariableDecl] = []
    prev_end = 0
    for semi_pos in semi_positions:
        stmt_masked = masked[prev_end:semi_pos]
        stmt_raw = body_text[prev_end:semi_pos]

        # Banner comment/blank lines can only be WHOLE lines preceding the
        # declaration; the declaration itself may span several lines (a
        # composite struct/array initializer), so scan forward for the first
        # substantive line rather than backward from the semicolon.
        n_stmt = len(stmt_masked)
        line_start = 0
        content_start_rel = None
        while line_start <= n_stmt:
            nl = stmt_masked.find("\n", line_start)
            line_end = nl if nl != -1 else n_stmt
            if stmt_masked[line_start:line_end].strip():
                content_start_rel = line_start
                break
            if nl == -1:
                break
            line_start = nl + 1
        if content_start_rel is None:
            content_start_rel = n_stmt

        if not stmt_masked[content_start_rel:].strip():
            diagnostics.warning("empty declaration segment before ';'", source_label)
            prev_end = semi_pos + 1
            continue

        banner_raw = stmt_raw[:content_start_rel]
        decl_raw = stmt_raw[content_start_rel:]
        decl_masked = stmt_masked[content_start_rel:]

        # trailing same-line comment: text from just after ';' to the next newline
        newline_pos = body_text.find("\n", semi_pos + 1)
        trailing_end = newline_pos if newline_pos != -1 else len(body_text)
        trailing_raw = body_text[semi_pos + 1 : trailing_end]
        prev_end = trailing_end + 1 if newline_pos != -1 else trailing_end

        banner_comment = _comment_text_in(banner_raw)
        trailing_comment = _comment_text_in(trailing_raw)
        documentation = "\n".join(p for p in (banner_comment, trailing_comment) if p)

        colon_pos = _find_toplevel_char(decl_masked, ":")
        if colon_pos == -1:
            diagnostics.error(f"declaration missing ':': {decl_raw.strip()!r}", source_label)
            continue
        name = decl_raw[:colon_pos].strip()
        tail_raw = decl_raw[colon_pos + 1 :]
        tail_masked = decl_masked[colon_pos + 1 :]

        assign_pos = _find_toplevel_str(tail_masked, ":=")
        if assign_pos == -1:
            type_text, _ = _trim_to_masked_content(tail_raw, tail_masked)
            init_raw = None
            init_masked = None
        else:
            type_text, _ = _trim_to_masked_content(tail_raw[:assign_pos], tail_masked[:assign_pos])
            init_raw = tail_raw[assign_pos + 2 :]
            init_masked = tail_masked[assign_pos + 2 :]

        try:
            type_ref = parse_type(type_text)
        except ValueError:
            if "POINTER" in type_text.upper():
                diagnostics.warning(f"POINTER TO not supported, skipping {name!r}", source_label)
            else:
                diagnostics.warning(f"unsupported type expression for {name!r}: {type_text!r}", source_label)
            continue

        init_value: InitValue | None = None
        if init_raw is not None:
            init_value = _parse_init_value(init_raw, init_masked)
            if (
                isinstance(init_value, SimpleInitValue)
                and isinstance(type_ref, BaseType)
                and type_ref.name == "REAL"
            ):
                init_value = SimpleInitValue(format_iec_real(init_value.literal))

        decls.append(VariableDecl(name=name, type=type_ref, documentation=documentation, init=init_value))

    return decls


def parse_enum_values(body_text: str, diagnostics: DiagnosticCollector, source_label: str) -> list[EnumValueDecl]:
    tokens = tokenize(body_text)
    offsets = token_offsets(tokens)
    masked = mask(tokens)

    matches = list(_ENUM_ENTRY_RE.finditer(masked))
    values: list[EnumValueDecl] = []
    for i, m in enumerate(matches):
        name = m.group(1)
        value = int(m.group(2))
        region_start = m.end()
        region_end = matches[i + 1].start() if i + 1 < len(matches) else len(body_text)
        doc_parts = [
            comment_text(tok)
            for off, tok in zip(offsets, tokens)
            if tok.kind in (LINE_COMMENT, BLOCK_COMMENT) and region_start <= off < region_end
        ]
        values.append(EnumValueDecl(name, value, "\n".join(p for p in doc_parts if p)))

    if not matches:
        diagnostics.warning("no enum values found", source_label)

    return values
