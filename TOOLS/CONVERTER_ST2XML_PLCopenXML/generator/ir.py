from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Union

from .st_types import TypeRef

_BARE_SECONDS_RE = re.compile(r"^(-?\d+)s$")


def format_iec_real(literal: str) -> str:
    """CODESYS re-serializes a REAL literal to its shortest round-tripping
    decimal form and drops a trailing '.0' entirely for whole numbers, when
    it exports to PLCopenXML. Confirmed byte-for-byte against
    samples_reference_codesys/GVL_PERSISTENT.xml: 50.0->"50", -20.0->"-20",
    0.0->"0", 0.10->"0.1" (trailing zero trimmed even though not a whole
    number), while 12.5->"12.5" and 0.05->"0.05" are left untouched."""
    text = literal.strip()
    if "." not in text:
        return text
    try:
        value = float(text)
    except ValueError:
        return text
    formatted = repr(value)
    if formatted.endswith(".0"):
        formatted = formatted[:-2]
    return formatted


def format_iec_time(literal: str) -> str:
    """CODESYS's PLCopenXML export rewrites the ST 'T#' shorthand to the full
    'TIME#' prefix, and -- confirmed on samples_reference_codesys/FB_Winch.xml
    (T#1s -> TIME#1s0ms) and FB_Grappin.xml (T#30s -> TIME#30s0ms) -- pads a
    bare-seconds literal with an explicit '0ms'. A literal already expressed
    down to milliseconds (e.g. T#200ms) is only prefix-rewritten. Any other
    shape (minutes/hours/days, not present anywhere in CODE/) is left
    prefix-rewritten only, since no sample confirms further normalization."""
    text = literal.strip()
    if text.startswith("TIME#"):
        rest = text[5:]
    elif text.startswith("T#"):
        rest = text[2:]
    else:
        return text
    bare_seconds = _BARE_SECONDS_RE.match(rest)
    if bare_seconds:
        rest = f"{bare_seconds.group(1)}s0ms"
    return f"TIME#{rest}"


@dataclass(frozen=True)
class SimpleInitValue:
    literal: str


@dataclass(frozen=True)
class ArrayInitValue:
    items: tuple["InitValue", ...]


@dataclass(frozen=True)
class StructInitValue:
    # insertion order = ST source order; xml_builder re-orders against the
    # referenced STRUCT's declared field order before emitting XML.
    members: tuple[tuple[str, "InitValue"], ...]

    def as_dict(self) -> dict[str, "InitValue"]:
        return dict(self.members)


InitValue = Union[SimpleInitValue, ArrayInitValue, StructInitValue]


@dataclass
class VariableDecl:
    name: str
    type: TypeRef
    documentation: str = ""
    init: InitValue | None = None


@dataclass
class EnumValueDecl:
    name: str
    value: int
    documentation: str = ""


@dataclass
class GlobalVarBlock:
    qualifiers: list[str]
    variables: list[VariableDecl]


@dataclass
class SourceObject:
    kind: str  # function_block | program | struct | enum | gvl
    name: str
    folder: str  # CODESYS project folder = immediate subdirectory under CODE/
    file_path: str  # path relative to CODE/, e.g. "WINCH/FB_Winch.st"
    header_comment: str = ""
    is_public: bool = False
    mtime: float = 0.0
    attribute_pragmas: list[str] = field(default_factory=list)

    input_vars: list[VariableDecl] = field(default_factory=list)
    output_vars: list[VariableDecl] = field(default_factory=list)
    inout_vars: list[VariableDecl] = field(default_factory=list)
    local_vars: list[VariableDecl] = field(default_factory=list)
    temp_vars: list[VariableDecl] = field(default_factory=list)
    body_text: str | None = None

    struct_fields: list[VariableDecl] = field(default_factory=list)

    enum_values: list[EnumValueDecl] = field(default_factory=list)

    global_blocks: list[GlobalVarBlock] = field(default_factory=list)
    raw_xml_path: str | None = None
