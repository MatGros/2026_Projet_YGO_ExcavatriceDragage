"""Clean, robust PLCopen XML TC6 v2.01 Ladder (LD) serializer with CODESYS ProjectStructure & ObjectId mapping."""
from __future__ import annotations
import re
import uuid
import xml.etree.ElementTree as ET
from xml.dom import minidom
from datetime import datetime
from pathlib import Path
from .st_ast import ProgramAST, FbCallAST, BooleanNetworkAST, AssignmentAST


NS_PLCOPEN = "http://www.plcopen.org/xml/tc6_0200"
ET.register_namespace("", NS_PLCOPEN)


def generate_object_id(kind: str, name: str) -> str:
    """Deterministic ObjectId GUID for CODESYS ProjectStructure mapping."""
    return str(uuid.uuid5(uuid.NAMESPACE_DNS, f"CODESYS:{kind}:{name}"))


def discover_fb_contracts(code_dir: Path) -> dict[str, list[str]]:
    """Discover all FB output formal parameters from project FB_*.st files."""
    fb_contracts: dict[str, list[str]] = {
        "FB_DigitalInputFilter": ["FilteredValue", "Out", "Error", "State"],
        "FB_Encoder_Abs": ["RawValue", "PositionM", "Incoherent", "Valid"],
        "FB_Encoder_Homing": ["HomingDone", "ZeroRefPosM", "Valid"],
        "FB_Encoder_Scale": ["RawValue", "PositionM", "Valid"],
        "FB_Encoder_Safety": ["PositionM", "Incoherent", "Valid"],
        "FB_Encoder_SpeedMeasure": ["Speed_Mps", "SignedSpeed_Mps", "Valid"],
        "FB_Translation_PositionDecoder": ["AtTremie", "AtPV", "AtP2", "AtP1", "AtMaintenance", "Incoherence"],
        "FB_SimBench": ["SimEngineOk", "SimEngineActive"],
    }
    if not code_dir.exists():
        return fb_contracts

    for st_file in code_dir.rglob("*.st"):
        text = st_file.read_text(encoding="utf-8")
        fb_match = re.search(r"\bFUNCTION_BLOCK\s+(?:PUBLIC\s+|INTERNAL\s+|FINAL\s+|ABSTRACT\s+)*([A-Za-z0-9_]+)", text)
        if not fb_match:
            continue
        fb_name = fb_match.group(1)

        out_sec = re.search(r"\bVAR_OUTPUT\b(.*?)\bEND_VAR\b", text, re.DOTALL)
        outputs = []
        if out_sec:
            # Strip (* *) blocks first: a multi-line comment's continuation lines start
            # with plain text, so a per-line startswith("(*") test misses them and turns
            # comment prose into a phantom output pin (REX 2026-08-13).
            section = re.sub(r"\(\*.*?\*\)", "", out_sec.group(1), flags=re.DOTALL)
            for line in section.splitlines():
                line_clean = line.strip()
                if not line_clean or line_clean.startswith("//"):
                    continue
                if ":" in line_clean:
                    v_name = line_clean.split(":", 1)[0].strip()
                    if re.match(r"^[A-Za-z_]\w*$", v_name):
                        outputs.append(v_name)
        if outputs:
            fb_contracts[fb_name] = outputs

    return fb_contracts


def build_ld_project_xml(ast_list: list[ProgramAST], project_name: str = "Generated", code_dir: Path | None = None, folder_name: str = "MAIN") -> bytes:
    """Build a complete importable PLCopen XML <project> for CODESYS."""
    if code_dir is None:
        code_dir = Path(r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\CODE")

    fb_contracts = discover_fb_contracts(code_dir)

    root = ET.Element("project", xmlns=NS_PLCOPEN)
    now_iso = datetime.now().isoformat()

    # <fileHeader>
    file_header = ET.SubElement(root, "fileHeader")
    file_header.set("companyName", "")
    file_header.set("productName", "CODESYS")
    file_header.set("productVersion", "CODESYS V3.5 SP19 Patch 1")
    file_header.set("creationDateTime", now_iso)

    # <contentHeader>
    content_header = ET.SubElement(root, "contentHeader")
    content_header.set("name", f"{project_name}.project")
    content_header.set("modificationDateTime", now_iso)
    coord_info = ET.SubElement(content_header, "coordinateInfo")
    ET.SubElement(coord_info, "fbd").append(ET.Element("scaling", x="1", y="1"))
    ET.SubElement(coord_info, "ld").append(ET.Element("scaling", x="1", y="1"))
    ET.SubElement(coord_info, "sfc").append(ET.Element("scaling", x="1", y="1"))

    c_adddata = ET.SubElement(content_header, "addData")
    d_proj = ET.SubElement(c_adddata, "data", name="http://www.3s-software.com/plcopenxml/projectinformation", handleUnknown="implementation")
    pi = ET.SubElement(d_proj, "ProjectInformation")
    prop = ET.SubElement(pi, "property", name="Project", type="string")
    prop.text = project_name

    # <types>
    types_el = ET.SubElement(root, "types")
    ET.SubElement(types_el, "dataTypes")
    pous_el = ET.SubElement(types_el, "pous")

    pou_guids: list[tuple[str, str]] = []

    for ast in ast_list:
        guid = generate_object_id(ast.pou_type, ast.name)
        pou_guids.append((ast.name, guid))
        pous_el.append(_build_pou_element(ast, guid, fb_contracts))

    # <instances>
    instances_el = ET.SubElement(root, "instances")
    ET.SubElement(instances_el, "configurations")

    # <addData><ProjectStructure> (CRITICAL FOR CODESYS IMPORT)
    proj_adddata = ET.SubElement(root, "addData")
    d_struct = ET.SubElement(proj_adddata, "data", name="http://www.3s-software.com/plcopenxml/projectstructure", handleUnknown="discard")
    ps = ET.SubElement(d_struct, "ProjectStructure")
    folder_el = ET.SubElement(ps, "Folder")
    folder_el.set("Name", folder_name)

    for p_name, p_guid in pou_guids:
        obj_el = ET.SubElement(folder_el, "Object")
        obj_el.set("Name", p_name)
        obj_el.set("ObjectId", p_guid)

    xml_str = ET.tostring(root, encoding="utf-8")
    parsed = minidom.parseString(xml_str)
    return parsed.toprettyxml(indent="  ", encoding="utf-8")


def _build_pou_element(ast: ProgramAST, guid: str, fb_contracts: dict[str, list[str]]) -> ET.Element:
    """Build a single <pou> XML element from ProgramAST with ObjectId vendor data."""
    pou = ET.Element("pou")
    pou.set("name", ast.name)
    pou.set("pouType", ast.pou_type)

    iface = ET.SubElement(pou, "interface")

    if ast.inputs:
        in_sec = ET.SubElement(iface, "inputVars")
        for v in ast.inputs:
            _append_var_decl(in_sec, v)

    if ast.outputs:
        out_sec = ET.SubElement(iface, "outputVars")
        for v in ast.outputs:
            _append_var_decl(out_sec, v)

    if ast.locals:
        loc_sec = ET.SubElement(iface, "localVars")
        for v in ast.locals:
            _append_var_decl(loc_sec, v)

    if ast.inouts:
        inout_sec = ET.SubElement(iface, "inOutVars")
        for v in ast.inouts:
            _append_var_decl(inout_sec, v)

    if ast.documentation:
        doc_el = ET.SubElement(iface, "documentation")
        xhtml = ET.SubElement(doc_el, "xhtml", xmlns="http://www.w3.org/1999/xhtml")
        xhtml.text = ast.documentation

    body = ET.SubElement(pou, "body")
    ld = ET.SubElement(body, "LD")

    local_id = 1

    rail_left = ET.SubElement(ld, "leftPowerRail")
    rail_left.set("localId", "0")
    ET.SubElement(rail_left, "position", x="0", y="0")
    ET.SubElement(rail_left, "connectionPointOut", formalParameter="none")

    for stmt in ast.statements:
        if getattr(stmt, "comment", None):
            local_id = _write_comment(ld, stmt.comment, local_id)
        if isinstance(stmt, FbCallAST):
            local_id = _write_fb_call(ld, stmt, local_id, fb_contracts)
        elif isinstance(stmt, BooleanNetworkAST):
            local_id = _write_bool_network(ld, stmt, local_id)
        elif isinstance(stmt, AssignmentAST):
            local_id = _write_assignment(ld, stmt, local_id)

    rail_right = ET.SubElement(ld, "rightPowerRail")
    rail_right.set("localId", "2147483646")
    ET.SubElement(rail_right, "position", x="0", y="0")
    ET.SubElement(rail_right, "connectionPointIn")

    # <pou><addData><ObjectId> (CRITICAL FOR CODESYS)
    pou_adddata = ET.SubElement(pou, "addData")
    d_objid = ET.SubElement(pou_adddata, "data", name="http://www.3s-software.com/plcopenxml/objectid", handleUnknown="discard")
    oid = ET.SubElement(d_objid, "ObjectId")
    oid.text = guid

    return pou


def _append_var_decl(parent: ET.Element, v: Any) -> None:
    var_el = ET.SubElement(parent, "variable")
    var_el.set("name", v.name)
    type_el = ET.SubElement(var_el, "type")

    elem_types = {"BOOL", "BYTE", "WORD", "DWORD", "LWORD", "INT", "UINT", "DINT", "UDINT", "REAL", "LREAL", "TIME", "STRING"}
    dt_upper = v.data_type.upper()
    if dt_upper in elem_types:
        ET.SubElement(type_el, dt_upper)
    else:
        derived = ET.SubElement(type_el, "derived")
        derived.set("name", v.data_type)

    if v.comment:
        doc = ET.SubElement(var_el, "documentation")
        xhtml = ET.SubElement(doc, "xhtml", xmlns="http://www.w3.org/1999/xhtml")
        xhtml.text = v.comment


_XHTML_NS = "http://www.w3.org/1999/xhtml"
_NETWORK_TITLE_RE = re.compile(r"^===\s*(.+?)\s*===$")


def _emit_comment_element(ld: ET.Element, text: str, local_id: int) -> None:
    comment_el = ET.SubElement(ld, "comment")
    comment_el.set("localId", str(local_id))
    # The genuine PRG_10_LD_Commentaires export uses height=0/width=0, but its comments
    # are 1-2 short lines; CODESYS then renders a zero-sized box that clips longer text
    # (retour terrain 2026-08-13). Size the box from the content instead.
    line_list = text.splitlines() or [""]
    longest = max((len(line) for line in line_list), default=0)
    comment_el.set("height", str(max(20, len(line_list) * 20 + 10)) if text else "0")
    comment_el.set("width", str(max(200, longest * 8 + 20)) if text else "0")
    ET.SubElement(comment_el, "position", x="0", y="0")
    content = ET.SubElement(comment_el, "content")
    xhtml = ET.SubElement(content, "xhtml")
    xhtml.set("xmlns", _XHTML_NS)
    if text:
        xhtml.text = text


def _emit_network_title_marker(ld: ET.Element, local_id: int) -> None:
    vendor = ET.SubElement(ld, "vendorElement")
    vendor.set("localId", str(local_id))
    ET.SubElement(vendor, "position", x="0", y="0")
    alt = ET.SubElement(vendor, "alternativeText")
    alt_xhtml = ET.SubElement(alt, "xhtml")
    alt_xhtml.set("xmlns", _XHTML_NS)
    v_adddata = ET.SubElement(vendor, "addData")
    d_v = ET.SubElement(v_adddata, "data", name="http://www.3s-software.com/plcopenxml/fbdelementtype", handleUnknown="implementation")
    el_type = ET.SubElement(d_v, "ElementType")
    el_type.set("xmlns", "")
    el_type.text = "networktitle"


def _write_comment(ld: ET.Element, comment_text: str, start_id: int) -> int:
    """Emit a comment, distinguishing the two real kinds found in this codebase.

    Structure copied from the genuine CODESYS oracle export (PRG_06_Outputs_LD,
    PRG_10_LD_Commentaires -- REX 2026-08):
      - `=== §N TITLE ===` box comment -> its OWN dedicated network: <comment> +
        <vendorElement networktitle>, then an EMPTY <comment> + <vendorElement
        networktitle> pair that opens the next network carrying the actual logic.
        That empty pair is exactly what separates the section header from the code
        in a real export (retour terrain 2026-08-13, "devrait être dans un réseau
        dédié pour séparer").
      - plain text -> a bare <comment>, no vendorElement, inside the current network.
    """
    lines = comment_text.splitlines()
    title_match = _NETWORK_TITLE_RE.match(lines[0].strip()) if lines else None

    curr_id = start_id
    _emit_comment_element(ld, comment_text, curr_id)
    curr_id += 1

    if title_match:
        _emit_network_title_marker(ld, curr_id)
        curr_id += 1
        # Empty pair -> closes the title-only network, opens the logic network.
        _emit_comment_element(ld, "", curr_id)
        curr_id += 1
        _emit_network_title_marker(ld, curr_id)
        curr_id += 1

    return curr_id


def _write_fb_call(ld: ET.Element, stmt: FbCallAST, start_id: int, fb_contracts: dict[str, list[str]]) -> int:
    block_id = start_id
    curr_id = start_id + 1

    block = ET.SubElement(ld, "block")
    block.set("localId", str(block_id))
    block.set("typeName", stmt.fb_type)
    block.set("instanceName", stmt.instance_name)
    ET.SubElement(block, "position", x="0", y="0")

    in_vars_el = ET.SubElement(block, "inputVariables")

    for p_name, p_val in stmt.param_inputs.items():
        in_var = ET.SubElement(in_vars_el, "variable")
        in_var.set("formalParameter", p_name)
        cpi = ET.SubElement(in_var, "connectionPointIn")

        src_id = curr_id
        curr_id += 1

        in_node = ET.SubElement(ld, "inVariable")
        in_node.set("localId", str(src_id))
        ET.SubElement(in_node, "position", x="0", y="0")
        ET.SubElement(in_node, "connectionPointOut")
        expr_el = ET.SubElement(in_node, "expression")
        expr_el.text = p_val

        conn = ET.SubElement(cpi, "connection")
        conn.set("refLocalId", str(src_id))

    ET.SubElement(block, "inOutVariables")
    out_vars_el = ET.SubElement(block, "outputVariables")

    contract_outputs = fb_contracts.get(stmt.fb_type, list(stmt.param_outputs.keys()) if stmt.param_outputs else ["State"])

    for idx, out_p in enumerate(contract_outputs):
        var_out = ET.SubElement(out_vars_el, "variable")
        var_out.set("formalParameter", out_p)
        c_out = ET.SubElement(var_out, "connectionPointOut")

        assigned_targets = stmt.param_outputs.get(out_p, [])

        if idx == 0:
            if assigned_targets and assigned_targets[0]:
                expr = ET.SubElement(c_out, "expression")
                expr.text = assigned_targets[0]
        else:
            expr = ET.SubElement(c_out, "expression")
            if assigned_targets and assigned_targets[0]:
                expr.text = assigned_targets[0]

    b_adddata = ET.SubElement(block, "addData")
    d_b = ET.SubElement(b_adddata, "data", name="http://www.3s-software.com/plcopenxml/fbdcalltype", handleUnknown="implementation")
    call_type = ET.SubElement(d_b, "CallType")
    call_type.text = "functionblock"

    return curr_id + 2


def _write_bool_network(ld: ET.Element, stmt: BooleanNetworkAST, start_id: int) -> int:
    curr_id = start_id
    operand_ids = []

    for op_name in stmt.operands:
        cnt_id = curr_id
        curr_id += 1
        operand_ids.append(cnt_id)

        contact = ET.SubElement(ld, "contact")
        contact.set("localId", str(cnt_id))
        contact.set("negated", "false")
        contact.set("storage", "none")
        contact.set("edge", "none")
        ET.SubElement(contact, "position", x="0", y="0")
        c_in = ET.SubElement(contact, "connectionPointIn")
        c_ref = ET.SubElement(c_in, "connection")
        c_ref.set("refLocalId", "0")
        ET.SubElement(contact, "connectionPointOut")
        var_el = ET.SubElement(contact, "variable")
        var_el.text = op_name

    coil_id = curr_id
    curr_id += 1

    coil = ET.SubElement(ld, "coil")
    coil.set("localId", str(coil_id))
    coil.set("negated", "false")
    coil.set("storage", "none")
    ET.SubElement(coil, "position", x="0", y="0")
    c_in_c = ET.SubElement(coil, "connectionPointIn")

    for b_id in operand_ids:
        c_ref_c = ET.SubElement(c_in_c, "connection")
        c_ref_c.set("refLocalId", str(b_id))

    ET.SubElement(coil, "connectionPointOut")
    var_el = ET.SubElement(coil, "variable")
    var_el.text = stmt.target_var

    return curr_id + 2


_BOOL_LITERAL_RE = re.compile(r"^(TRUE|FALSE)$")


def _is_simple_bool_copy(stmt: AssignmentAST) -> bool:
    """True only for a bare BOOL variable/literal copy -- eligible for contact/coil.

    Anything else (function call, struct/member access target implying non-BOOL,
    comparison, arithmetic) must use inVariable/outVariable per
    CODE_QUALITY_STANDARDS.md §11 -- a <coil> only accepts a BOOL variable name,
    never an expression.
    """
    expr = stmt.expression.strip()
    if "(" in expr or ")" in expr:
        return False
    if _BOOL_LITERAL_RE.match(expr):
        return True
    return re.match(r"^[A-Za-z_][A-Za-z0-9_.]*$", expr) is not None


def _write_assignment(ld: ET.Element, stmt: AssignmentAST, start_id: int) -> int:
    if _is_simple_bool_copy(stmt):
        return _write_bool_copy(ld, stmt, start_id)
    return _write_value_copy(ld, stmt, start_id)


def _write_bool_copy(ld: ET.Element, stmt: AssignmentAST, start_id: int) -> int:
    cnt_id = start_id
    coil_id = start_id + 1

    contact = ET.SubElement(ld, "contact")
    contact.set("localId", str(cnt_id))
    contact.set("negated", "false")
    contact.set("storage", "none")
    contact.set("edge", "none")
    ET.SubElement(contact, "position", x="0", y="0")
    c_in = ET.SubElement(contact, "connectionPointIn")
    c_ref = ET.SubElement(c_in, "connection")
    c_ref.set("refLocalId", "0")
    ET.SubElement(contact, "connectionPointOut")
    var_el = ET.SubElement(contact, "variable")
    var_el.text = stmt.expression

    coil = ET.SubElement(ld, "coil")
    coil.set("localId", str(coil_id))
    coil.set("negated", "false")
    coil.set("storage", "none")
    ET.SubElement(coil, "position", x="0", y="0")
    c_in_c = ET.SubElement(coil, "connectionPointIn")
    c_ref_c = ET.SubElement(c_in_c, "connection")
    c_ref_c.set("refLocalId", str(cnt_id))
    ET.SubElement(coil, "connectionPointOut")
    var_el = ET.SubElement(coil, "variable")
    var_el.text = stmt.target_var

    return start_id + 2


_CALL_RE = re.compile(r"^([A-Za-z_]\w*)\s*\((.*)\)$", re.DOTALL)


def _write_value_copy(ld: ET.Element, stmt: AssignmentAST, start_id: int) -> int:
    """Non-BOOL assignment: either a function call (SEL(...)) or a bare struct/member copy.

    ⚠️ No known-good PLCopenXML pattern is confirmed for a bare non-boolean copy with
    no function call (e.g. `HwSim.Winch := instSimBench.Winch;`) in this codebase --
    the only real, reverse-engineered evidence (AF_Partie-03 §5, G410 REX 2026-08-04)
    is that top-level <outVariable> triggers IndexOutOfRangeException and is never
    observed in a genuine CODESYS export. A function call CAN be represented safely
    as a <block> (proven pattern, same shape as an FB call) writing its result via
    <connectionPointOut><expression> on the block's own output pin -- never a
    top-level <outVariable>.
    """
    call_match = _CALL_RE.match(stmt.expression.strip())
    if call_match:
        return _write_call_as_block(ld, call_match.group(1), call_match.group(2), stmt.target_var, start_id)

    # Bare struct/member copy, no function call -- best-effort placeholder using the
    # same block-output-expression shape, single unnamed pin. UNVERIFIED against a
    # real CODESYS import: flag it, don't claim it as fixed.
    return _write_call_as_block(ld, "MOVE", "IN := " + stmt.expression, stmt.target_var, start_id, unverified=True)


# Real IEC 61131-3 formal parameter names for standard functions used positionally
# (no ":=" in the call site) -- CODESYS validates a block's formalParameter names
# against the function's actual signature, so a generic IN0/IN1/... placeholder is
# wrong for any function with named parameters (REX 2026-08-13: SEL's first param
# is "G", not "IN0" -- confirmed positional args must map to the real names).
_KNOWN_POSITIONAL_PARAMS: dict[str, list[str]] = {
    "SEL": ["G", "IN0", "IN1"],
}


def _top_level_bool_op(expr: str) -> str | None:
    """Return 'AND'/'OR' if that operator appears at paren-depth 0 in expr, else None."""
    depth = 0
    for op in (" OR ", " AND "):
        depth = 0
        i = 0
        while i < len(expr):
            ch = expr[i]
            if ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
            elif depth == 0 and expr[i:i + len(op)] == op:
                return op.strip()
            i += 1
    return None


def _split_top_level_bool(expr: str, op: str) -> list[str]:
    marker = f" {op} "
    parts: list[str] = []
    buf: list[str] = []
    depth = 0
    i = 0
    while i < len(expr):
        ch = expr[i]
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        if depth == 0 and expr[i:i + len(marker)] == marker:
            parts.append("".join(buf).strip())
            buf = []
            i += len(marker)
            continue
        buf.append(ch)
        i += 1
    tail = "".join(buf).strip()
    if tail:
        parts.append(tail)
    return parts


def _write_source_node(ld: ET.Element, expr: str, curr_id: int) -> tuple[int, int]:
    """Write whatever feeds a connectionPointIn for `expr`, return (its localId, next_id).

    A composite condition (A AND B) is wired as a real <block typeName="AND"> with one
    operand per input pin -- never dumped as raw ST text inside an inVariable's
    <expression> (REX 2026-08-13, "cette ecriture doit etre interdite" -- an LD page
    represents logic graphically, a text blob defeats the point of compiling to LD).
    """
    expr = expr.strip()
    op = _top_level_bool_op(expr)
    if op:
        return _write_bool_block(ld, op, _split_top_level_bool(expr, op), curr_id)

    src_id = curr_id
    curr_id += 1
    in_node = ET.SubElement(ld, "inVariable")
    in_node.set("localId", str(src_id))
    ET.SubElement(in_node, "position", x="0", y="0")
    ET.SubElement(in_node, "connectionPointOut")
    expr_el = ET.SubElement(in_node, "expression")
    expr_el.text = expr
    return src_id, curr_id


def _write_bool_block(ld: ET.Element, op_name: str, operands: list[str], curr_id: int) -> tuple[int, int]:
    """AND/OR as a real graphical block, one input pin per operand (IN1, IN2, ...).

    Confirmed by a real CODESYS import (REX 2026-08-13, PRG_02_Acquisition_LD) --
    branches render correctly in the LD editor and the project compiles. See
    CODE_QUALITY_STANDARDS.md §11 for the full confirmed structure.
    """
    block_id = curr_id
    curr_id += 1

    block = ET.SubElement(ld, "block")
    block.set("localId", str(block_id))
    block.set("typeName", op_name)
    block.set("instanceName", "")
    ET.SubElement(block, "position", x="0", y="0")

    in_vars_el = ET.SubElement(block, "inputVariables")
    for idx, operand in enumerate(operands, start=1):
        negated = False
        operand_clean = operand.strip()
        if operand_clean.upper().startswith("NOT "):
            negated = True
            operand_clean = operand_clean[4:].strip()

        src_id, curr_id = _write_source_node(ld, operand_clean, curr_id)

        in_var = ET.SubElement(in_vars_el, "variable")
        in_var.set("formalParameter", f"IN{idx}")
        if negated:
            in_var.set("negated", "true")
        cpi = ET.SubElement(in_var, "connectionPointIn")
        conn = ET.SubElement(cpi, "connection")
        conn.set("refLocalId", str(src_id))

    ET.SubElement(block, "inOutVariables")
    out_vars_el = ET.SubElement(block, "outputVariables")
    var_out = ET.SubElement(out_vars_el, "variable")
    var_out.set("formalParameter", "OUT")
    ET.SubElement(var_out, "connectionPointOut")

    b_adddata = ET.SubElement(block, "addData")
    d_b = ET.SubElement(b_adddata, "data", name="http://www.3s-software.com/plcopenxml/fbdcalltype", handleUnknown="implementation")
    call_type = ET.SubElement(d_b, "CallType")
    call_type.text = "function"

    return block_id, curr_id


def _write_call_as_block(ld: ET.Element, fn_name: str, args_str: str, target_var: str, start_id: int, unverified: bool = False) -> int:
    block_id = start_id
    curr_id = start_id + 1

    block = ET.SubElement(ld, "block")
    block.set("localId", str(block_id))
    block.set("typeName", fn_name)
    block.set("instanceName", "")
    ET.SubElement(block, "position", x="0", y="0")

    in_vars_el = ET.SubElement(block, "inputVariables")
    known_names = _KNOWN_POSITIONAL_PARAMS.get(fn_name, [])
    positional_idx = 0
    for p_item in _split_top_level_expr(args_str):
        if ":=" in p_item:
            p_name, p_val = [x.strip() for x in p_item.split(":=", 1)]
        else:
            if positional_idx < len(known_names):
                p_name = known_names[positional_idx]
            else:
                p_name = f"IN{positional_idx}"
            p_val = p_item.strip()
            positional_idx += 1

        in_var = ET.SubElement(in_vars_el, "variable")
        in_var.set("formalParameter", p_name)
        cpi = ET.SubElement(in_var, "connectionPointIn")

        src_id, curr_id = _write_source_node(ld, p_val, curr_id)

        conn = ET.SubElement(cpi, "connection")
        conn.set("refLocalId", str(src_id))

    ET.SubElement(block, "inOutVariables")
    out_vars_el = ET.SubElement(block, "outputVariables")
    var_out = ET.SubElement(out_vars_el, "variable")
    var_out.set("formalParameter", fn_name)
    c_out = ET.SubElement(var_out, "connectionPointOut")
    expr = ET.SubElement(c_out, "expression")
    expr.text = target_var

    b_adddata = ET.SubElement(block, "addData")
    d_b = ET.SubElement(b_adddata, "data", name="http://www.3s-software.com/plcopenxml/fbdcalltype", handleUnknown="implementation")
    call_type = ET.SubElement(d_b, "CallType")
    call_type.text = "function"

    return curr_id + 2


def _split_top_level_expr(text: str) -> list[str]:
    parts: list[str] = []
    buf: list[str] = []
    depth = 0
    for ch in text:
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        if ch == "," and depth <= 0:
            parts.append("".join(buf).strip())
            buf = []
            continue
        buf.append(ch)
    tail = "".join(buf).strip()
    if tail:
        parts.append(tail)
    return [p for p in parts if p]
