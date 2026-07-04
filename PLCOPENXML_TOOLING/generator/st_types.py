from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Union

# Base IEC 61131-3 types actually used in CODE/ (confirmed by grep over the
# real source tree). Kept as an explicit whitelist rather than guessing.
BASE_TYPES = {
    "BOOL",
    "BYTE",
    "WORD",
    "DWORD",
    "SINT",
    "USINT",
    "INT",
    "UINT",
    "DINT",
    "UDINT",
    "REAL",
    "LREAL",
    "TIME",
}

_IDENTIFIER_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
_STRING_RE = re.compile(r"^STRING\s*\(\s*(\d+)\s*\)$")
_ARRAY_RE = re.compile(r"^ARRAY\s*\[\s*(-?\d+)\s*\.\.\s*(-?\d+)\s*\]\s*OF\s+(.+)$", re.IGNORECASE | re.DOTALL)


@dataclass(frozen=True)
class BaseType:
    name: str


@dataclass(frozen=True)
class StringType:
    length: int


@dataclass(frozen=True)
class DerivedType:
    name: str


@dataclass(frozen=True)
class ArrayType:
    lower: int
    upper: int
    base: "TypeRef"


TypeRef = Union[BaseType, StringType, DerivedType, ArrayType]


def parse_type(text: str) -> TypeRef:
    text = text.strip()
    if not text:
        raise ValueError("empty type expression")

    array_match = _ARRAY_RE.match(text)
    if array_match:
        lower_text, upper_text, base_text = array_match.groups()
        return ArrayType(int(lower_text), int(upper_text), parse_type(base_text))

    string_match = _STRING_RE.match(text)
    if string_match:
        return StringType(int(string_match.group(1)))

    if text in BASE_TYPES:
        return BaseType(text)

    if _IDENTIFIER_RE.match(text):
        return DerivedType(text)

    raise ValueError(f"unrecognized type expression: {text!r}")


def referenced_type_names(type_ref: TypeRef) -> set[str]:
    """Names of derived types this type expression pulls in as a dependency."""
    if isinstance(type_ref, DerivedType):
        return {type_ref.name}
    if isinstance(type_ref, ArrayType):
        return referenced_type_names(type_ref.base)
    return set()
