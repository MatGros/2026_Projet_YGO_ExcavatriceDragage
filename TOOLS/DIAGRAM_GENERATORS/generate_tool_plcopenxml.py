#!/usr/bin/env python3
"""Generate the explanatory pipeline diagram for TOOLS/ST_PLCOPENXML_GENERATOR."""

import sys
from pathlib import Path

TOOLS_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS_ROOT))
from visualize_workflow import render_puml

PUML = """@startuml Tool_PLCopenXmlGenerator
skinparam backgroundColor #FFFFFF
skinparam shadowing true
skinparam roundcorner 5
skinparam fontname "Consolas"
skinparam fontsize 12
skinparam ArrowColor #455A64
skinparam nodesep 40
skinparam ranksep 50
!pragma layout smetana
left to right direction

title Outil - ST_PLCOPENXML_GENERATOR (CODE/*.st -> PLCopenXML)

rectangle "📄 CODE/*.st" as INPUT #BBDEFB

package "🎛️ cli.py (orchestrateur)" #FFF3E0 {
  rectangle "main()" as CLI
}

package "🔍 1. Decouverte" #E3F2FD {
  rectangle "file_discovery.py\\ndiscover_objects()" as DISCOVER
}

package "📝 2. Parsing ST" #E8F5E9 {
  rectangle "st_parser.py\\nparse_file()" as PARSER
  rectangle "st_lexer.py" as LEXER
  rectangle "st_declarations.py" as DECL
  rectangle "st_sections.py" as SECTIONS
  rectangle "st_types.py" as TYPES
}

package "🧩 3. Representation intermediaire" #F8BBD0 {
  rectangle "ir.py\\nSourceObject" as IR
}

package "🏗️ 4. Construction XML" #E1BEE7 {
  rectangle "xml_builder.py\\nbuild_project_xml()" as BUILDER
  rectangle "dependency_resolver.py\\nresolve_dependencies()" as DEPS
  rectangle "guid.py\\nobject_guid()" as GUID
}

package "💾 5. Ecriture" #FFE0B2 {
  rectangle "xml_serializer.py\\nwrite_file()" as SERIALIZER
}

rectangle "📦 CODE/*.xml\\nou CODE_Bundle.xml" as OUTPUT #BBDEFB
rectangle "🏭 Import PLCopenXML\\ndans CODESYS 3.5" as CODESYS #C8E6C9

package "🚨 Transverse" #F44336 {
  rectangle "diagnostics.py\\nDiagnosticCollector\\n(erreurs/warnings)" as DIAG
}

INPUT --> DISCOVER
CLI --> DISCOVER : args.code_dir
DISCOVER --> PARSER : parse_file() par objet
PARSER --> LEXER
PARSER --> DECL
PARSER --> SECTIONS
PARSER --> TYPES
PARSER --> IR : construit
CLI --> BUILDER : build_project_xml()
BUILDER --> DEPS : include_deps
BUILDER --> GUID : creationDateTime/GUID
BUILDER --> IR : lit
BUILDER --> SERIALIZER
SERIALIZER --> OUTPUT
OUTPUT --> CODESYS : import manuel

DISCOVER ..> DIAG : erreurs parsing
BUILDER ..> DIAG : erreurs deps/types
DIAG ..> CLI : rapport final\\n(warning/error count)

footer Genere depuis TOOLS/ST_PLCOPENXML_GENERATOR/generator/*.py (imports reels cli.py)
@enduml"""

if __name__ == "__main__":
    project_root = TOOLS_ROOT.parent
    out_dir = project_root / "DOC" / "DIAGRAMS" / "TOOLS"
    out_dir.mkdir(parents=True, exist_ok=True)
    output = out_dir / "DIAG_TOOL_PLCopenXmlGenerator.png"

    print("Generation diagramme ST_PLCOPENXML_GENERATOR...")
    ok = render_puml(PUML, output)
    sys.exit(0 if ok else 1)
