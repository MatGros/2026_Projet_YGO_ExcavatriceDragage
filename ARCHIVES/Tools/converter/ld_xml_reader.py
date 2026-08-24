"""Bidirectional PLCopen XML Ladder (LD) to ST extractor for MES field retro-sync."""
from __future__ import annotations
import xml.etree.ElementTree as ET
from pathlib import Path


NS_MAP = {"plc": "http://www.plcopen.org/xml/tc6_0200"}


def extract_ld_to_st(xml_path: Path) -> str:
    """Parse PLCopen XML <LD> POU and extract clean readable ST code."""
    tree = ET.parse(xml_path)
    root = tree.getroot()

    pou = root if root.tag.endswith("pou") else (root.find(".//plc:pou", NS_MAP) or root.find(".//pou"))
    if pou is None:
        raise ValueError(f"No <pou> found in {xml_path}")

    pou_name = pou.get("name", "UNKNOWN_POU")
    pou_type = (pou.get("pouType") or "program").upper()

    lines = [f"// === Extrait automatique depuis {xml_path.name} ===", f"{pou_type} {pou_name}"]

    # Interface declarations
    iface = pou.find("plc:interface", NS_MAP) or pou.find("interface")
    if iface is not None:
        for section_tag, section_kw in [
            ("inputVars", "VAR_INPUT"),
            ("outputVars", "VAR_OUTPUT"),
            ("localVars", "VAR"),
            ("inOutVars", "VAR_IN_OUT"),
        ]:
            sec_el = iface.find(f"plc:{section_tag}", NS_MAP) or iface.find(section_tag)
            if sec_el is not None and len(sec_el) > 0:
                lines.append(f"{section_kw}")
                for var_el in sec_el.findall("plc:variable", NS_MAP) or sec_el.findall("variable"):
                    v_name = var_el.get("name")
                    v_type_nodes = list(var_el.find("plc:type", NS_MAP) or var_el.find("type") or [])
                    v_type_str = "BOOL"
                    if v_type_nodes:
                        t_node = v_type_nodes[0]
                        v_type_str = t_node.get("name") if t_node.tag.rsplit("}", 1)[-1] == "derived" else t_node.tag.rsplit("}", 1)[-1]
                    lines.append(f"    {v_name} : {v_type_str};")
                lines.append("END_VAR")

    # Body extraction
    body_ld = pou.find(".//plc:LD", NS_MAP) or pou.find(".//LD")
    if body_ld is not None:
        lines.append("// === Logique RLO / Réseaux ===")
        all_elements = {e.get("localId"): e for e in body_ld if e.get("localId")}

        # Extract coils / assignments
        for coil in body_ld.findall("plc:coil", NS_MAP) or body_ld.findall("coil"):
            var_el = coil.find("plc:variable", NS_MAP) or coil.find("variable")
            target_name = var_el.text if var_el is not None else "UNKNOWN"
            
            c_in = coil.find("plc:connectionPointIn", NS_MAP) or coil.find("connectionPointIn")
            if c_in is not None:
                connections = c_in.findall("plc:connection", NS_MAP) or c_in.findall("connection")
                sources = []
                for conn in connections:
                    ref_id = conn.get("refLocalId")
                    src_elem = all_elements.get(ref_id)
                    if src_elem is not None:
                        s_tag = src_elem.tag.rsplit("}", 1)[-1]
                        if s_tag == "contact":
                            s_var = src_elem.find("plc:variable", NS_MAP) or src_elem.find("variable")
                            if s_var is not None and s_var.text:
                                sources.append(s_var.text)
                
                if len(sources) > 1:
                    lines.append(f"{target_name} := {' OR '.join(sources)};")
                elif len(sources) == 1:
                    lines.append(f"{target_name} := {sources[0]};")

    lines.append(f"END_{pou_type}")
    return "\n".join(lines)
