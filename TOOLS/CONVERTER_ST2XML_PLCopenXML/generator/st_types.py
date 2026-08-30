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
# 🔧 Borne = littéral entier OU constante (qualifiée ou non), ex. GVL_PLC_Tests_Const.MaxSteps
# (ARRAY[1..N] OF T avec N symbolique — voir docs/PLCOPENXML_FORMAT.md, note "non vérifié").
_BOUND = r"(-?\d+|[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*)"
_DIM_RE = re.compile(rf"^\s*{_BOUND}\s*\.\.\s*{_BOUND}\s*$")
# Multi-dimensionnel : ARRAY[1..2, 1..3] OF T — une seule paire de crochets, dimensions
# séparées par des virgules (confirmé PLCopenXML : plusieurs <dimension> dans un <array>,
# voir docs/PLCOPENXML_FORMAT.md). Distinct de ARRAY[1..2] OF ARRAY[1..3] OF T (imbriqué).
_ARRAY_RE = re.compile(r"^ARRAY\s*\[\s*(?P<dims>.+?)\s*\]\s*OF\s+(?P<base>.+)$", re.IGNORECASE | re.DOTALL)
_REFERENCE_RE = re.compile(r"^REFERENCE\s+TO\s+(.+)$", re.IGNORECASE | re.DOTALL)


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
    lower: int | str  # str = borne symbolique (ex. constante GVL), passée telle quelle en sortie XML
    upper: int | str
    base: "TypeRef"
    # Dimensions supplémentaires (2e, 3e, ... N) pour ARRAY[1..2, 1..2, ...] OF T — vide pour
    # un tableau à une dimension (comportement historique inchangé).
    extra_dims: tuple[tuple[int | str, int | str], ...] = ()


@dataclass(frozen=True)
class ReferenceType:
    base: "TypeRef"


TypeRef = Union[BaseType, StringType, DerivedType, ArrayType, ReferenceType]


def _parse_bound(text: str) -> int | str:
    """Borne de tableau : int si littéral, sinon expression symbolique passée telle quelle."""
    if re.fullmatch(r"-?\d+", text):
        return int(text)
    return text


def parse_type(text: str) -> TypeRef:
    text = text.strip()
    if not text:
        raise ValueError("empty type expression")

    reference_match = _REFERENCE_RE.match(text)
    if reference_match:
        base_text = reference_match.group(1).strip()
        return ReferenceType(parse_type(base_text))

    array_match = _ARRAY_RE.match(text)
    if array_match:
        dims_text = array_match.group("dims")
        base_text = array_match.group("base")
        dims: list[tuple[int | str, int | str]] = []
        for dim_text in dims_text.split(","):
            dim_match = _DIM_RE.match(dim_text)
            if not dim_match:
                raise ValueError(f"invalid array dimension expression: {dim_text!r}")
            lower_text, upper_text = dim_match.groups()
            dims.append((_parse_bound(lower_text), _parse_bound(upper_text)))
        first_lower, first_upper = dims[0]
        return ArrayType(first_lower, first_upper, parse_type(base_text), extra_dims=tuple(dims[1:]))

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
    if isinstance(type_ref, ReferenceType):
        return referenced_type_names(type_ref.base)
    return set()
