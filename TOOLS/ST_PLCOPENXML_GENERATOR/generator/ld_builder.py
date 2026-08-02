from __future__ import annotations

import re
import xml.etree.ElementTree as ET

PLCOPEN_NS = "http://www.plcopen.org/xml/tc6_0200"
XHTML_NS = "http://www.w3.org/1999/xhtml"


def _create_standalone_banner_network(
    ld: ET.Element,
    local_id_start: int,
    title_text: str,
    description_text: str = "",
) -> int:
    """
    Génère un RÉSEAU SÉPARÉ DÉDIÉ (100% Bannière vide de code) :
    Affiche le décorateur brut // === [TITRE] === suivi de la description dans <comment>.
    Pas de titre de réseau <vendorElement> pour éviter tout doublon et gagner de la hauteur.
    """
    cid = local_id_start

    full_content = f"// === {title_text} ==="
    if description_text:
        full_content += f"\r\n// {description_text}"

    c_el = ET.SubElement(ld, "comment")
    c_el.set("localId", str(cid))
    c_el.set("height", "0")
    c_el.set("width", "0")
    ET.SubElement(c_el, "position", x="0", y="0")
    cnt = ET.SubElement(c_el, "content")
    xhtml_c = ET.SubElement(cnt, "xhtml")
    xhtml_c.set("xmlns", XHTML_NS)
    xhtml_c.text = full_content
    cid += 1

    # Balise vendorElement networktitle vide (nécessaire pour la séparation de réseau dans CODESYS)
    ve_t = ET.SubElement(ld, "vendorElement")
    ve_t.set("localId", str(cid))
    ET.SubElement(ve_t, "position", x="0", y="0")
    alt_t = ET.SubElement(ve_t, "alternativeText")
    xhtml_t = ET.SubElement(alt_t, "xhtml")
    xhtml_t.set("xmlns", XHTML_NS)
    xhtml_t.text = ""
    adddata_t = ET.SubElement(ve_t, "addData")
    d_t = ET.SubElement(adddata_t, "data")
    d_t.set("name", "http://www.3s-software.com/plcopenxml/fbdelementtype")
    d_t.set("handleUnknown", "implementation")
    el_type_t = ET.SubElement(d_t, "ElementType")
    el_type_t.set("xmlns", "")
    el_type_t.text = "networktitle"
    cid += 1

    return cid


def _append_network_header(
    ld: ET.Element,
    local_id_start: int,
    comment_text: str = "",
) -> int:
    """Génère l'en-tête de réseau classique avec préfixe // conservé."""
    cid = local_id_start

    formatted_comment = ""
    if comment_text:
        # Conserver le préfixe // sur chaque ligne de commentaire
        lines = comment_text.splitlines()
        formatted_lines = [l if l.startswith("//") else f"// {l}" for l in lines]
        formatted_comment = "\r\n".join(formatted_lines)

    c_el = ET.SubElement(ld, "comment")
    c_el.set("localId", str(cid))
    c_el.set("height", "0")
    c_el.set("width", "0")
    ET.SubElement(c_el, "position", x="0", y="0")
    cnt = ET.SubElement(c_el, "content")
    xhtml_c = ET.SubElement(cnt, "xhtml")
    xhtml_c.set("xmlns", XHTML_NS)
    xhtml_c.text = formatted_comment
    cid += 1

    ve_t = ET.SubElement(ld, "vendorElement")
    ve_t.set("localId", str(cid))
    ET.SubElement(ve_t, "position", x="0", y="0")
    alt_t = ET.SubElement(ve_t, "alternativeText")
    xhtml_t = ET.SubElement(alt_t, "xhtml")
    xhtml_t.set("xmlns", XHTML_NS)
    xhtml_t.text = ""
    adddata_t = ET.SubElement(ve_t, "addData")
    d_t = ET.SubElement(adddata_t, "data")
    d_t.set("name", "http://www.3s-software.com/plcopenxml/fbdelementtype")
    d_t.set("handleUnknown", "implementation")
    el_type_t = ET.SubElement(d_t, "ElementType")
    el_type_t.set("xmlns", "")
    el_type_t.text = "networktitle"
    cid += 1

    return cid


def build_ld_body(
    body_text: str,
    boolean_identifiers: set[str] | None = None,
    instance_types: dict[str, str] | None = None,
    instance_input_types: dict[str, dict[str, str]] | None = None,
) -> ET.Element:
    """Convertit un PROGRAM ``PRG_*_LD`` en Ladder.

    ``boolean_identifiers`` et ``instance_types`` proviennent exclusivement des
    déclarations réellement parsées du POU. Ainsi, chaque appel de bloc Ladder
    conserve le type IEC de son instance au lieu d'être implicitement rendu en
    ``FB_Output``. Une affectation directe n'est rendue contact→bobine que si sa
    source BOOL est connue ; les valeurs non booléennes restent des liaisons
    typées ``inVariable → outVariable``.
    """
    boolean_identifiers = boolean_identifiers or set()
    instance_types = instance_types or {}
    instance_input_types = instance_input_types or {}
    body = ET.Element("body")
    ld = ET.SubElement(body, "LD")

    # Rail de puissance gauche principal (ID 0)
    left_rail = ET.SubElement(ld, "leftPowerRail")
    left_rail.set("localId", "0")
    ET.SubElement(left_rail, "position", x="0", y="0")
    c_out_rail = ET.SubElement(left_rail, "connectionPointOut")
    c_out_rail.set("formalParameter", "none")

    local_id_counter = 1

    raw_text = body_text or ""
    lines = raw_text.splitlines()

    current_banner_title = ""
    current_banner_desc: list[str] = []
    current_stmt_comments: list[str] = []
    
    statements_with_headers = []
    current_stmt = []
    in_banner_desc = False

    for line in lines:
        line_s = line.strip()
        if not line_s:
            continue

        # 1. Détection Bannière Grand Titre : // == ou // ===
        if line_s.startswith("// ==") or line_s.startswith("//===") or line_s.startswith("(* =="):
            comment_content = re.sub(r"^//\s*=*\s*", "", line_s)
            comment_content = re.sub(r"\s*=*$", "", comment_content).strip()
            if comment_content:
                current_banner_title = comment_content
                current_banner_desc = []
                in_banner_desc = True
            continue

        # 2. Détection Commentaires
        if line_s.startswith("//") and not line_s.startswith("// ==="):
            comment_text = line_s.lstrip("/ ").strip()
            if comment_text:
                if in_banner_desc and not current_stmt:
                    current_banner_desc.append(comment_text)
                else:
                    current_stmt_comments.append(comment_text)
            continue

        if line_s.startswith("(*"):
            continue

        # Les commentaires ST de fin de ligne ne font pas partie de
        # l'instruction. Sans ce retrait, le `;` n'est plus terminal et la
        # ligne suivante est fusionnée, supprimant un appel FB du LD généré.
        line_s = re.sub(r"\(\*.*?\*\)", "", line_s).strip()
        if not line_s:
            continue

        # Dès qu'on touche une vraie ligne de code, la description de la bannière est terminée
        in_banner_desc = False

        current_stmt.append(line_s)
        if line_s.endswith(";"):
            stmt_full = " ".join(current_stmt)
            banner_desc_str = "\r\n".join(current_banner_desc)
            stmt_comment_str = "\r\n".join(current_stmt_comments)
            
            statements_with_headers.append((
                current_banner_title,
                banner_desc_str,
                stmt_comment_str,
                stmt_full.rstrip(";").strip()
            ))
            
            current_stmt = []
            current_banner_title = ""
            current_banner_desc = []
            current_stmt_comments = []

    # Cartographie et structuration des réseaux Ladder
    fb_commands: dict[str, tuple[str, str, str, str]] = {}
    coil_mappings: list[tuple[str, str, str, str, str, str]] = []

    other_statements = []

    for b_title, b_desc, stmt_comm, stmt_clean in statements_with_headers:
        if not stmt_clean:
            continue

        m_cmd = re.match(r"^(\w+)\s*\(\s*Command\s*:=\s*([\w\.]+)\s*\)$", stmt_clean)
        if m_cmd:
            fb_commands[m_cmd.group(1)] = (b_title, b_desc, stmt_comm, m_cmd.group(2))
            continue

        m_state = re.match(r"^([\w\.]+)\s*:=\s*(\w+)\.State$", stmt_clean)
        if m_state:
            coil_var, inst_name = m_state.groups()
            if inst_name in fb_commands:
                bt, bd, sc, cmd_v = fb_commands.pop(inst_name)
                coil_mappings.append((bt or b_title, bd or b_desc, sc or stmt_comm, inst_name, cmd_v, coil_var))
                continue

        other_statements.append((b_title, b_desc, stmt_comm, stmt_clean))

    last_emitted_title = ""

    # ── 1. Réseaux unifiés FB_Output ──
    for b_title, b_desc, stmt_comm, inst_name, cmd_var, coil_var in coil_mappings:

        # Si un nouveau grand titre // === apparaît, on crée le RÉSEAU SÉPARÉ DE BANNIÈRE
        if b_title and b_title != last_emitted_title:
            local_id_counter = _create_standalone_banner_network(ld, local_id_counter, b_title, b_desc)
            last_emitted_title = b_title

        # En-tête du réseau de code (contient le commentaire spécifique du réseau)
        local_id_counter = _append_network_header(ld, local_id_counter, stmt_comm)

        block_id = local_id_counter
        contact_id = local_id_counter + 1
        coil_id = local_id_counter + 2
        local_id_counter += 10

        # Contact de commande
        contact = ET.SubElement(ld, "contact")
        contact.set("localId", str(contact_id))
        contact.set("negated", "false")
        contact.set("storage", "none")
        contact.set("edge", "none")
        ET.SubElement(contact, "position", x="0", y="0")
        c_in = ET.SubElement(contact, "connectionPointIn")
        c_ref = ET.SubElement(c_in, "connection")
        c_ref.set("refLocalId", "0")
        ET.SubElement(contact, "connectionPointOut")
        var_el = ET.SubElement(contact, "variable")
        var_el.text = cmd_var

        # Le type du bloc doit correspondre à sa déclaration VAR réelle.
        instance_type = instance_types.get(inst_name)
        if instance_type is None:
            raise ValueError(f"LD block instance without declared type: {inst_name}")
        block = ET.SubElement(ld, "block")
        block.set("localId", str(block_id))
        block.set("typeName", instance_type)
        block.set("instanceName", inst_name)
        ET.SubElement(block, "position", x="0", y="0")

        in_vars = ET.SubElement(block, "inputVariables")
        var_in = ET.SubElement(in_vars, "variable")
        var_in.set("formalParameter", "Command")
        c_in_b = ET.SubElement(var_in, "connectionPointIn")
        c_ref_b = ET.SubElement(c_in_b, "connection")
        c_ref_b.set("refLocalId", str(contact_id))

        ET.SubElement(block, "inOutVariables")

        out_vars = ET.SubElement(block, "outputVariables")
        var_out = ET.SubElement(out_vars, "variable")
        var_out.set("formalParameter", "State")
        ET.SubElement(var_out, "connectionPointOut")

        b_adddata = ET.SubElement(block, "addData")
        d_b = ET.SubElement(b_adddata, "data")
        d_b.set("name", "http://www.3s-software.com/plcopenxml/fbdcalltype")
        d_b.set("handleUnknown", "implementation")
        call_type = ET.SubElement(d_b, "CallType")
        call_type.set("xmlns", "")
        call_type.text = "functionblock"

        # Bobine physique
        coil = ET.SubElement(ld, "coil")
        coil.set("localId", str(coil_id))
        coil.set("negated", "false")
        coil.set("storage", "none")
        ET.SubElement(coil, "position", x="0", y="0")
        c_in_c = ET.SubElement(coil, "connectionPointIn")
        c_ref_c = ET.SubElement(c_in_c, "connection")
        c_ref_c.set("refLocalId", str(block_id))
        c_ref_c.set("formalParameter", "State")
        ET.SubElement(coil, "connectionPointOut")
        var_el = ET.SubElement(coil, "variable")
        var_el.text = coil_var

    # ── 2. Autres instructions ──
    for b_title, b_desc, stmt_comm, stmt_clean in other_statements:
        if b_title and b_title != last_emitted_title:
            local_id_counter = _create_standalone_banner_network(ld, local_id_counter, b_title, b_desc)
            last_emitted_title = b_title

        local_id_counter = _append_network_header(ld, local_id_counter, stmt_comm)

        # FB multi-paramètres
        match_fb_call = re.match(r"^(\w+)\s*\((.*)\)$", stmt_clean, flags=re.DOTALL)
        if match_fb_call and ":=" in match_fb_call.group(2):
            inst_name, params_str = match_fb_call.groups()
            arg_matches = re.findall(r"(\w+)\s*:=\s*([\w\.\*\+\-\/]+)", params_str)

            block_id = local_id_counter
            local_id_counter += 10

            # Aucun nom/type implicite : l'appel LD reprend le type VAR déclaré.
            instance_type = instance_types.get(inst_name)
            if instance_type is None:
                raise ValueError(f"LD block instance without declared type: {inst_name}")
            block = ET.SubElement(ld, "block")
            block.set("localId", str(block_id))
            block.set("typeName", instance_type)
            block.set("instanceName", inst_name)
            ET.SubElement(block, "position", x="0", y="0")

            in_vars = ET.SubElement(block, "inputVariables")

            for p_name, p_val in arg_matches:
                var_in = ET.SubElement(in_vars, "variable")
                var_in.set("formalParameter", p_name)
                c_in_p = ET.SubElement(var_in, "connectionPointIn")

                # A ladder contact is a BOOL-only element.  Feeding a TIME,
                # INT, WORD or REAL argument through one creates an invalid
                # diagram despite well-formed XML (observed on the two LD
                # programs during CODESYS import).  The formal parameter type
                # comes from the declared interface of the called FB; values
                # of every non-BOOL (or unresolved) formal are data sources.
                formal_type = instance_input_types.get(inst_name, {}).get(p_name)
                if formal_type != "BOOL":
                    source_id = local_id_counter
                    local_id_counter += 2
                    input_var = ET.SubElement(ld, "inVariable")
                    input_var.set("localId", str(source_id))
                    ET.SubElement(input_var, "position", x="0", y="0")
                    ET.SubElement(input_var, "connectionPointOut")
                    expression = ET.SubElement(input_var, "expression")
                    expression.text = p_val
                    ET.SubElement(c_in_p, "connection", refLocalId=str(source_id))
                elif p_val == "TRUE":
                    ET.SubElement(c_in_p, "connection", refLocalId="0")
                else:
                    cnt_id = local_id_counter
                    local_id_counter += 2
                    contact = ET.SubElement(ld, "contact")
                    contact.set("localId", str(cnt_id))
                    contact.set("negated", "false")
                    contact.set("storage", "none")
                    contact.set("edge", "none")
                    ET.SubElement(contact, "position", x="0", y="0")
                    c_in_c = ET.SubElement(contact, "connectionPointIn")
                    c_ref_c = ET.SubElement(c_in_c, "connection")
                    c_ref_c.set("refLocalId", "0")
                    ET.SubElement(contact, "connectionPointOut")
                    var_el = ET.SubElement(contact, "variable")
                    var_el.text = p_val

                    c_ref_p = ET.SubElement(c_in_p, "connection")
                    c_ref_p.set("refLocalId", str(cnt_id))

            ET.SubElement(block, "inOutVariables")
            ET.SubElement(block, "outputVariables")

            b_adddata = ET.SubElement(block, "addData")
            d_b = ET.SubElement(b_adddata, "data")
            d_b.set("name", "http://www.3s-software.com/plcopenxml/fbdcalltype")
            d_b.set("handleUnknown", "implementation")
            call_type = ET.SubElement(d_b, "CallType")
            call_type.set("xmlns", "")
            call_type.text = "functionblock"
            continue

        # Expression AND
        if ":=" in stmt_clean and " AND " in stmt_clean:
            parts = stmt_clean.split(":=")
            out_var_name = parts[0].strip()
            conds = [c.strip() for c in parts[1].split("AND")]

            prev_id = 0
            for cond in conds:
                cnt_id = local_id_counter
                local_id_counter += 2

                contact = ET.SubElement(ld, "contact")
                contact.set("localId", str(cnt_id))
                contact.set("negated", "false")
                contact.set("storage", "none")
                contact.set("edge", "none")
                ET.SubElement(contact, "position", x="0", y="0")
                c_in = ET.SubElement(contact, "connectionPointIn")
                c_ref = ET.SubElement(c_in, "connection")
                c_ref.set("refLocalId", str(prev_id))
                ET.SubElement(contact, "connectionPointOut")
                var_el = ET.SubElement(contact, "variable")
                var_el.text = cond
                prev_id = cnt_id

            coil_id = local_id_counter
            local_id_counter += 10
            coil = ET.SubElement(ld, "coil")
            coil.set("localId", str(coil_id))
            coil.set("negated", "false")
            coil.set("storage", "none")
            ET.SubElement(coil, "position", x="0", y="0")
            c_in_c = ET.SubElement(coil, "connectionPointIn")
            c_ref_c = ET.SubElement(c_in_c, "connection")
            c_ref_c.set("refLocalId", str(prev_id))
            ET.SubElement(coil, "connectionPointOut")
            var_el = ET.SubElement(coil, "variable")
            var_el.text = out_var_name
            continue

        # Expression OR
        if ":=" in stmt_clean and " OR " in stmt_clean:
            parts = stmt_clean.split(":=")
            out_var_name = parts[0].strip()
            conds = [c.strip() for c in parts[1].split("OR")]

            branch_ids = []
            for cond in conds:
                cnt_id = local_id_counter
                local_id_counter += 2
                branch_ids.append(cnt_id)

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
                var_el.text = cond

            coil_id = local_id_counter
            local_id_counter += 10
            coil = ET.SubElement(ld, "coil")
            coil.set("localId", str(coil_id))
            coil.set("negated", "false")
            coil.set("storage", "none")
            ET.SubElement(coil, "position", x="0", y="0")
            c_in_c = ET.SubElement(coil, "connectionPointIn")
            for b_id in branch_ids:
                c_ref_c = ET.SubElement(c_in_c, "connection")
                c_ref_c.set("refLocalId", str(b_id))
            ET.SubElement(coil, "connectionPointOut")
            var_el = ET.SubElement(coil, "variable")
            var_el.text = out_var_name
            continue

        # Recopie booléenne connue : contact → bobine. Le type est pris dans
        # l'interface réellement parsée du POU, jamais déduit du nom de variable.
        if ":=" in stmt_clean:
            parts = stmt_clean.split(":=", 1)
            target_var = parts[0].strip()
            source_expression = parts[1].strip()
            direct_identifier = re.fullmatch(r"[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*", source_expression)

            if direct_identifier and source_expression in boolean_identifiers:
                contact_id = local_id_counter
                coil_id = local_id_counter + 1
                local_id_counter += 10

                contact = ET.SubElement(ld, "contact")
                contact.set("localId", str(contact_id))
                contact.set("negated", "false")
                contact.set("storage", "none")
                contact.set("edge", "none")
                ET.SubElement(contact, "position", x="0", y="0")
                contact_in = ET.SubElement(contact, "connectionPointIn")
                ET.SubElement(contact_in, "connection", refLocalId="0")
                ET.SubElement(contact, "connectionPointOut")
                contact_variable = ET.SubElement(contact, "variable")
                contact_variable.text = source_expression

                coil = ET.SubElement(ld, "coil")
                coil.set("localId", str(coil_id))
                coil.set("negated", "false")
                coil.set("storage", "none")
                ET.SubElement(coil, "position", x="0", y="0")
                coil_in = ET.SubElement(coil, "connectionPointIn")
                ET.SubElement(coil_in, "connection", refLocalId=str(contact_id))
                ET.SubElement(coil, "connectionPointOut")
                coil_variable = ET.SubElement(coil, "variable")
                coil_variable.text = target_var
                continue

            # Valeur/expression typée : PDO WORD/UINT ou conversion telle que
            # REAL_TO_UINT(...). CODESYS les représente par inVariable → outVariable.
            input_id = local_id_counter
            output_id = local_id_counter + 1
            local_id_counter += 10

            input_var = ET.SubElement(ld, "inVariable")
            input_var.set("localId", str(input_id))
            ET.SubElement(input_var, "position", x="0", y="0")
            ET.SubElement(input_var, "connectionPointOut")
            expression = ET.SubElement(input_var, "expression")
            expression.text = source_expression

            output_var = ET.SubElement(ld, "outVariable")
            output_var.set("localId", str(output_id))
            ET.SubElement(output_var, "position", x="0", y="0")
            connection_point = ET.SubElement(output_var, "connectionPointIn")
            connection = ET.SubElement(connection_point, "connection")
            connection.set("refLocalId", str(input_id))
            output_expression = ET.SubElement(output_var, "expression")
            output_expression.text = target_var
            continue

    # Rail de puissance droit principal
    right_rail = ET.SubElement(ld, "rightPowerRail")
    right_rail.set("localId", "2147483646")
    pos_right = ET.SubElement(right_rail, "position")
    pos_right.set("x", "0")
    pos_right.set("y", "0")
    ET.SubElement(right_rail, "connectionPointIn")

    return body
