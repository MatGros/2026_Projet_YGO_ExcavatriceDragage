from __future__ import annotations

from pathlib import Path
import re

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
        
        # 🛡️ Contrôle de syntaxe CODESYS : espace interdit entre ':' et '=' (ex: TargetNum : = M3)
        clean_code = "\n".join(l.split("//")[0] for l in source.splitlines())
        if re.search(r":\s+=", clean_code):
            diagnostics.error(
                f"Syntax Error: Invalid space between ':' and '=' in assignment operator ':=' in {f.name}",
                f"{f.parent.name}/{f.name}"
            )

        rel = f.relative_to(code_dir).as_posix()
        rel_parent = f.parent.relative_to(code_dir)
        obj = parse_file(
            source,
            folder="" if rel_parent == Path(".") else rel_parent.as_posix().replace('/', '\\'),
            stem=f.stem,
            mtime=f.stat().st_mtime,
            source_label=rel,
            diagnostics=diagnostics,
        )
        if obj is not None:
            objects.append(obj)

    # 🧱 Découverte des POU XML natifs (ex. PRG_GLOBAL_CFC.xml, PRG_AU_Acquisition_CFC.xml)
    all_xml_files = sorted(code_dir.rglob("*.xml"))
    for f in all_xml_files:
        if "_Bundle" in f.name or f.name.startswith("CODE_"):
            continue
        rel = f.relative_to(code_dir).as_posix()
        rel_parent = f.parent.relative_to(code_dir)
        folder_str = "" if rel_parent == Path(".") else str(rel_parent).replace('/', '\\')

        # Extrait le nom exact du POU depuis l'attribut <pou name="..."> du XML
        xml_text = f.read_text(encoding="utf-8")
        pou_match = re.search(r'<pou\s+name="([^"]+)"', xml_text)
        pou_name = pou_match.group(1) if pou_match else f.stem

        # Un PRG Ladder versionné en .st peut aussi avoir son export PLCopenXML
        # individuel, destiné à l'import CODESYS. Cet export est un artefact de
        # livraison, pas une seconde source : le redécouvrir créerait deux POU
        # homonymes dans le bundle. Les CFC natifs restent, eux, des sources XML.
        st_source = f.with_suffix(".st")
        if pou_name.endswith("_LD") and st_source.is_file():
            diagnostics.info(
                f"{f.name} is standalone LD export for {st_source.name}; excluded from bundle discovery",
                rel,
            )
            continue

        obj = SourceObject(
            kind="program",
            name=pou_name,
            folder=folder_str,
            file_path=rel,
            mtime=f.stat().st_mtime,
            raw_xml_path=str(f)
        )
        objects.append(obj)

    return objects
