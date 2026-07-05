from __future__ import annotations

from pathlib import Path

from .diagnostics import DiagnosticCollector
from .ir import SourceObject
from .st_parser import parse_file

_DECL_SUFFIX = "_Decl.st"
_IMPL_SUFFIX = "_Impl.st"


def _excluded_decl_impl_files(
    all_st_files: list[Path], diagnostics: DiagnosticCollector
) -> set[Path]:
    by_dir: dict[Path, dict[str, Path]] = {}
    for f in all_st_files:
        by_dir.setdefault(f.parent, {})[f.name] = f

    excluded: set[Path] = set()
    for directory, files_by_name in by_dir.items():
        decl_names = sorted(n for n in files_by_name if n.endswith(_DECL_SUFFIX))
        for decl_name in decl_names:
            base = decl_name[: -len(_DECL_SUFFIX)]
            impl_name = base + _IMPL_SUFFIX
            merged_name = base + ".st"
            decl_path = files_by_name.get(decl_name)
            impl_path = files_by_name.get(impl_name)
            merged_path = files_by_name.get(merged_name)
            source_label = f"{directory.name}/{base}"

            if decl_path:
                excluded.add(decl_path)
            if impl_path:
                excluded.add(impl_path)

            if decl_path and impl_path and merged_path:
                concatenated = decl_path.read_text(encoding="utf-8") + impl_path.read_text(encoding="utf-8")
                merged = merged_path.read_text(encoding="utf-8")
                if concatenated == merged:
                    diagnostics.info(
                        f"{decl_name} + {impl_name} == {merged_name} (identical); excluded from parsing",
                        source_label,
                    )
                else:
                    diagnostics.warning(
                        f"{decl_name} + {impl_name} does NOT match {merged_name} byte-for-byte "
                        f"(stale duplicate) -- {merged_name} remains the canonical source, "
                        f"_Decl/_Impl ignored",
                        source_label,
                    )
            else:
                diagnostics.warning(f"incomplete _Decl/_Impl/.st trio for {base!r}", source_label)

    return excluded


def discover_objects(code_dir: Path, diagnostics: DiagnosticCollector) -> list[SourceObject]:
    all_st_files = sorted(code_dir.rglob("*.st"))
    excluded = _excluded_decl_impl_files(all_st_files, diagnostics)

    objects: list[SourceObject] = []
    for f in all_st_files:
        if f in excluded:
            continue
        source = f.read_text(encoding="utf-8")
        rel = f.relative_to(code_dir).as_posix()
        obj = parse_file(
            source,
            folder=f.parent.name,
            stem=f.stem,
            mtime=f.stat().st_mtime,
            source_label=rel,
            diagnostics=diagnostics,
        )
        if obj is not None:
            objects.append(obj)
    return objects
