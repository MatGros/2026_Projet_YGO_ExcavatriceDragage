from __future__ import annotations

import xml.etree.ElementTree as ET
from pathlib import Path

# CODESYS 3.5 SP19's own PLCopenXML export (verified byte-for-byte against
# samples_reference_codesys/*.xml):
#   - UTF-8 with a BOM
#   - XML declaration with double quotes (ET's xml_declaration=True uses
#     single quotes, so it is written out manually instead)
#   - LF line endings, no trailing newline after the closing </project>
#   - 2-space indentation, self-closing empty elements with a space before
#     "/>" (this is ET.indent()/ET.tostring()'s own default, nothing special
#     needed for it)
_XML_DECLARATION = '<?xml version="1.0" encoding="utf-8"?>\n'
_BOM = b"\xef\xbb\xbf"


def serialize(root: ET.Element) -> bytes:
    ET.indent(root, space="  ")
    body = ET.tostring(root, encoding="unicode")
    return _BOM + (_XML_DECLARATION + body).encode("utf-8")


def write_file(root: ET.Element, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(serialize(root))
