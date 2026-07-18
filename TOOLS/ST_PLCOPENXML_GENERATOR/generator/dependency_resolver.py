from __future__ import annotations

from .diagnostics import DiagnosticCollector
from .ir import SourceObject
from .st_types import referenced_type_names

# Standard IEC 61131-3 / CODESYS library blocks: always available, never part
# of CODE/, so never pulled into a dependency closure.
STANDARD_BLOCKS = {"TON", "TOF", "TP", "R_TRIG", "F_TRIG", "CTU", "CTD", "CTUD"}


def _referenced_names(obj: SourceObject) -> set[str]:
    names: set[str] = set()
    for variables in (
        obj.input_vars,
        obj.output_vars,
        obj.inout_vars,
        obj.local_vars,
        obj.temp_vars,
        obj.struct_fields,
    ):
        for var in variables:
            names |= referenced_type_names(var.type)
    for block in obj.global_blocks:
        for var in block.variables:
            names |= referenced_type_names(var.type)
    return names


def resolve_dependencies(
    roots: list[str],
    objects_by_name: dict[str, SourceObject],
    diagnostics: DiagnosticCollector,
) -> list[str]:
    """BFS transitive closure of object names referenced (directly or
    indirectly) starting from `roots`. Returns names in BFS discovery order
    (roots first, in the order given). Standard IEC blocks are excluded.
    An unknown referenced type is reported as a WARNING and left out of the
    closure rather than guessed at."""
    seen: set[str] = set(roots)
    queue: list[str] = list(roots)
    order: list[str] = []
    idx = 0
    while idx < len(queue):
        name = queue[idx]
        idx += 1
        order.append(name)
        obj = objects_by_name.get(name)
        if obj is None:
            continue
        for dep_name in sorted(_referenced_names(obj)):
            if dep_name in STANDARD_BLOCKS or dep_name in seen:
                continue
            if dep_name not in objects_by_name:
                diagnostics.warning(f"referenced type {dep_name!r} not found among parsed objects", name)
                continue
            seen.add(dep_name)
            queue.append(dep_name)
    return order
