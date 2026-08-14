from __future__ import annotations

import re
import xml.etree.ElementTree as ET

PLCOPEN_NS = "http://www.plcopen.org/xml/tc6_0200"
XHTML_NS = "http://www.w3.org/1999/xhtml"

# Types scalaires IEC 61131-3 : les copies de sorties typées de FB vers des variables
# locales/POU sont convertibles en Ladder via le pattern inVariable→outVariable (PDO
# WORD/UINT/REAL). Tout type hors cette liste est un STRUCT/derived → copie struct non
# convertible (refus, REX 2026-08-13).
SCALAR_TYPES = {
    "BOOL", "BYTE", "WORD", "DWORD", "LWORD",
    "SINT", "INT", "DINT", "LINT",
    "USINT", "UINT", "UDINT", "ULINT",
    "REAL", "LREAL",
    "TIME", "LTIME", "DATE", "TIME_OF_DAY", "TOD", "DATE_AND_TIME", "DT",
    "STRING", "WSTRING", "CHAR",
}


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
    instance_output_types: dict[str, list[str]] | None = None,
    instance_output_type_map: dict[str, dict[str, str]] | None = None,
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
    instance_output_types = instance_output_types or {}
    instance_output_type_map = instance_output_type_map or {}
    body = ET.Element("body")
    ld = ET.SubElement(body, "LD")

    # Rail de puissance gauche principal (ID 0)
    left_rail = ET.SubElement(ld, "leftPowerRail")
    left_rail.set("localId", "0")
    ET.SubElement(left_rail, "position", x="0", y="0")
    c_out_rail = ET.SubElement(left_rail, "connectionPointOut")
    c_out_rail.set("formalParameter", "none")

    local_id_counter = 1

    # Mapping instance_name -> block_localId pour cable les outputs FB
    # directement au bloc (REX 2026-08-04 : contact fantome -> IndexOutOfRangeException)
    instance_block_map: dict[str, int] = {}

    raw_text = body_text or ""
    lines = raw_text.splitlines()

    current_banner_title = ""
    current_banner_desc: list[str] = []
    current_stmt_comments: list[str] = []
    
    statements_with_headers = []
    current_stmt = []
    in_banner_desc = False
    in_block_comment = False

    for line in lines:
        line_s = line.strip()
        if not line_s:
            continue

        # REX 2026-08-13 : un bloc commenté `(* ... *)` multi-lignes dans le corps
        # était traité comme du code actif (seule la ligne d'ouverture était sautée),
        # provoquant "LD block instance without declared type" sur des instances
        # déclarées uniquement dans la section commentée. On saute tout le bloc.
        if in_block_comment:
            if "*)" in line_s:
                in_block_comment = False
            continue
        if line_s.startswith("(*"):
            if "*)" in line_s:
                continue
            in_block_comment = True
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

    # REX 2026-08-04 (oracle PRG_Oracle_Nested.xml) : les assignations d outputs
    # FB (target := instName.outputName) vont DANS les <outputVariables> du bloc
    # sous forme <expression>target</expression>, pas en coils separees.
    fb_output_assignments: dict[str, dict[str, list[str]]] = {}

    for b_title, b_desc, stmt_comm, stmt_clean in statements_with_headers:
        if not stmt_clean:
            continue

        # FB_Output : instXxx(Command := var)  →  suivi de var := instXxx.State
        m_cmd = re.match(r"^(\w+)\s*\(\s*Command\s*:=\s*([\w\.]+)\s*\)$", stmt_clean)
        if m_cmd:
            fb_commands[m_cmd.group(1)] = (b_title, b_desc, stmt_comm, m_cmd.group(2), {})
            continue

        # FB_Input / FB_Output : instXxx(Param := val, Param2 := val2, ...)
        # Capture TOUS les paramètres pour le câblage LD multi-params.
        m_input = re.match(r"^(\w+)\s*\((.+)\)$", stmt_clean, flags=re.DOTALL)
        if m_input and ' := ' in m_input.group(2):
            inst = m_input.group(1)
            params_str = m_input.group(2)
            params = {}
            for pm in re.finditer(r'(\w+)\s*:=\s*([^,]+)', params_str):
                params[pm.group(1)] = pm.group(2).strip()
            if 'InputRaw' in params or 'Command' in params:
                main_var = params.get('InputRaw') or params.get('Command') or ''
                fb_commands[inst] = (b_title, b_desc, stmt_comm, main_var, params)
                continue

        m_state = re.match(r"^([\w\.]+)\s*:=\s*(\w+)\.State$", stmt_clean)
        if m_state:
            coil_var, inst_name = m_state.groups()
            if inst_name in fb_commands:
                bt, bd, sc, cmd_v, all_params = fb_commands.pop(inst_name)
                coil_mappings.append((bt or b_title, bd or b_desc, sc or stmt_comm, inst_name, cmd_v, coil_var, all_params))
                continue

        # REX 2026-08-04 : capturer les assignations d outputs FB (target := instName.output)
        # pour les injecter dans les <outputVariables> du bloc (oracle PRG_Oracle_Nested.xml).
        m_fb_out = re.match(r"^([A-Za-z_]\w*)\s*:=\s*(\w+)\.(\w+)$", stmt_clean)
        if m_fb_out and m_fb_out.group(2) in instance_types:
            _target, _inst, _output = m_fb_out.groups()
            fb_output_assignments.setdefault(_inst, {}).setdefault(_output, []).append(_target)
            continue  # Ne pas mettre dans other_statements (sera dans le bloc)

        # ⛔ REX 2026-08-13 (PRG_02_Acquisition_LD scratch) : ici tout ce qui n'a été capturé
        # par AUCUN pattern tomberait dans le fallback qui produit du XML invalide
        # (IndexOutOfRangeException à l'import CODESYS). On refuse net plutôt que d'approximer.
        # Cas non convertibles :
        #   - contrôle de flux (IF/ELSE/CASE/FOR/WHILE) → coil au nom absurde
        #   - fonctions standards structurées (SEL/MUX/...) → inVariable non résoluble
        #   - copie struct→struct (HwSim.Winch := instSimBench.Winch) → outVariable
        flow_kw = re.match(
            r"\b(IF|CASE|FOR|WHILE|ELSIF|ELSE|THEN|END_IF|END_CASE|END_FOR|END_WHILE)\b",
            stmt_clean,
        )
        if flow_kw:
            raise ValueError(
                f"LD non convertible : `{stmt_clean[:80]}` — construction de contrôle de "
                f"flux '{flow_kw.group(1)}' interdite dans un POU `_LD` (REX 2026-08-13). "
                f"Convertir la logique en réseau de contacts/coils, ou la sortir vers un FB ST."
            )
        if any(k in stmt_clean for k in ("SEL(", "MUX(", "LIMIT(", "MAX(", "MIN(", "ABS(")):
            raise ValueError(
                f"LD non convertible : `{stmt_clean[:80]}` — fonction standard non prise en "
                f"charge en Ladder (REX 2026-08-13). Sortir le calcul dans un FB ST et câbler "
                f"sa sortie, ne pas l'écrire dans le POU `_LD`."
            )
        m_copy = re.match(r"^([\w.]+)\s*:=\s*([\w.]+)$", stmt_clean)
        if m_copy and "." in m_copy.group(2):
            src = m_copy.group(2)
            inst, member = src.split(".", 1)
            if "." not in member and inst in instance_output_type_map:
                src_type = instance_output_type_map.get(inst, {}).get(member)
                if src_type is not None and src_type not in SCALAR_TYPES:
                    raise ValueError(
                        f"LD non convertible : `{stmt_clean[:80]}` — copie struct→struct "
                        f"(source `{src}` type `{src_type}`, STRUCT) interdite dans un "
                        f"POU `_LD` (REX 2026-08-13). Publier la structure depuis un FB ST "
                        f"et câbler ses champs BOOL un à un."
                    )

        other_statements.append((b_title, b_desc, stmt_comm, stmt_clean))

    last_emitted_title = ""

    # ── 1. Réseaux unifiés FB_Output / FB_Input ──
    for b_title, b_desc, stmt_comm, inst_name, cmd_var, coil_var, all_params in coil_mappings:

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

        # Contact de commande / entrée principale
        # FB_Output utilise Command, FB_Input utilise InputRaw.
        main_input_param = "Command"
        inst_type_name = instance_types.get(inst_name, "")
        if inst_type_name == "FB_Input" or "InputRaw" in (instance_input_types.get(inst_name, {})):
            main_input_param = "InputRaw"

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

        # Sources pour TOUS les inputs déclarés du FB, câblés ou non.
        # Oracle CODESYS (samples_reference_codesys/PRG_input_LD.xml, REX 2026-08) :
        #   - chaque input formel du FB apparaît dans inputVariables, même non câblé ;
        #   - input non câblé        → inVariable à expression VIDE ;
        #   - BOOL littéral TRUE     → leftPowerRail (0) ;
        #   - BOOL littéral FALSE    → inVariable expression "0" (sérialisation CODESYS) ;
        #   - non-BOOL ou expression → inVariable (expression) ;
        #   - BOOL variable          → contact.
        # Un contact Ladder ne porte jamais de littéral TIME ni d'expression : c'est
        # un bug d'import CODESYS (REX 2026-08).
        declared_inputs = list(instance_input_types.get(inst_name, {}).keys())
        for p_name in all_params:
            if p_name not in declared_inputs:
                declared_inputs.append(p_name)

        instance_type = instance_types.get(inst_name)
        if instance_type is None:
            raise ValueError(f"LD block instance without declared type: {inst_name}")

        extra_param_sources = {}  # param_name -> localId (0 = leftPowerRail)
        for p_name in declared_inputs:
            if p_name == main_input_param:
                continue
            p_value = all_params.get(p_name)
            if p_value is None:
                if instance_type == "FB_Input":
                    src_id = local_id_counter
                    local_id_counter += 2
                    input_var = ET.SubElement(ld, "inVariable")
                    input_var.set("localId", str(src_id))
                    ET.SubElement(input_var, "position", x="0", y="0")
                    ET.SubElement(input_var, "connectionPointOut")
                    expression = ET.SubElement(input_var, "expression")
                    expression.text = ""
                    extra_param_sources[p_name] = src_id
                continue
            formal_type = instance_input_types.get(inst_name, {}).get(p_name)
            direct_identifier = (
                p_value is not None
                and not p_value.startswith("PRG_")
                and re.fullmatch(r"[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*", p_value)
            )
            if p_value == "TRUE" or p_value == "FALSE" or formal_type != "BOOL" or not direct_identifier:
                src_id = local_id_counter
                local_id_counter += 2
                input_var = ET.SubElement(ld, "inVariable")
                input_var.set("localId", str(src_id))
                ET.SubElement(input_var, "position", x="0", y="0")
                ET.SubElement(input_var, "connectionPointOut")
                expression = ET.SubElement(input_var, "expression")
                if p_value == "FALSE":
                    expression.text = "0"
                elif p_value == "TRUE":
                    expression.text = "1"
                elif p_value is not None:
                    expression.text = p_value
                extra_param_sources[p_name] = src_id
                continue
            p_contact_id = local_id_counter
            local_id_counter += 2
            extra_param_sources[p_name] = p_contact_id
            p_contact = ET.SubElement(ld, "contact")
            p_contact.set("localId", str(p_contact_id))
            p_contact.set("negated", "false")
            p_contact.set("storage", "none")
            p_contact.set("edge", "none")
            ET.SubElement(p_contact, "position", x="0", y="0")
            p_c_in = ET.SubElement(p_contact, "connectionPointIn")
            p_c_ref = ET.SubElement(p_c_in, "connection")
            p_c_ref.set("refLocalId", "0")
            ET.SubElement(p_contact, "connectionPointOut")
            p_var_el = ET.SubElement(p_contact, "variable")
            p_var_el.text = p_value

        # Le type du bloc doit correspondre à sa déclaration VAR réelle.
        # REX 2026-08-04 (oracle PRG_06_Outputs_LD.xml) : TOUTES les sources
        # (contacts ET inVariable pour inputs non connectes) doivent etre creees
        # AVANT le bloc. Les inVariable apres le bloc -> IndexOutOfRangeException.
        unconnected_sources: dict[str, int] = {}
        for p_name in declared_inputs:
            if p_name == main_input_param:
                continue
            if p_name not in extra_param_sources:
                src_id = local_id_counter
                local_id_counter += 2
                input_var = ET.SubElement(ld, "inVariable")
                input_var.set("localId", str(src_id))
                ET.SubElement(input_var, "position", x="0", y="0")
                ET.SubElement(input_var, "connectionPointOut")
                ET.SubElement(input_var, "expression")
                unconnected_sources[p_name] = src_id

        block = ET.SubElement(ld, "block")
        block.set("localId", str(block_id))
        block.set("typeName", instance_type)
        block.set("instanceName", inst_name)
        instance_block_map[inst_name] = block_id
        ET.SubElement(block, "position", x="0", y="0")

        in_vars = ET.SubElement(block, "inputVariables")
        var_in = ET.SubElement(in_vars, "variable")
        var_in.set("formalParameter", main_input_param)
        c_in_b = ET.SubElement(var_in, "connectionPointIn")
        c_ref_b = ET.SubElement(c_in_b, "connection")
        c_ref_b.set("refLocalId", str(contact_id))
        for p_name in declared_inputs:
            if p_name == main_input_param:
                continue
            if p_name in extra_param_sources:
                var_p = ET.SubElement(in_vars, "variable")
                var_p.set("formalParameter", p_name)
                c_in_p = ET.SubElement(var_p, "connectionPointIn")
                c_ref_p = ET.SubElement(c_in_p, "connection")
                c_ref_p.set("refLocalId", str(extra_param_sources[p_name]))
            elif p_name in unconnected_sources:
                var_p = ET.SubElement(in_vars, "variable")
                var_p.set("formalParameter", p_name)
                c_in_p = ET.SubElement(var_p, "connectionPointIn")
                c_ref_p = ET.SubElement(c_in_p, "connection")
                c_ref_p.set("refLocalId", str(unconnected_sources[p_name]))

        ET.SubElement(block, "inOutVariables")

        # Émettre TOUS les outputs déclarés du FB (State, Error, ErrorId pour FB_Input).
        # Structure oracle CODESYS : State → <connectionPointOut/> ;
        # Error/ErrorId → <connectionPointOut><expression/></connectionPointOut>.
        declared_outputs = instance_output_types.get(inst_name, [])
        if not declared_outputs:
            declared_outputs = ["State"]
        out_vars = ET.SubElement(block, "outputVariables")
        for out_p in declared_outputs:
            var_out = ET.SubElement(out_vars, "variable")
            var_out.set("formalParameter", out_p)
            c_out = ET.SubElement(var_out, "connectionPointOut")
            if out_p != "State":
                ET.SubElement(c_out, "expression")

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

            # ── Phase 1 : créer les sources (contacts/inVariables) AVANT le bloc.
            # CODESYS exige que les éléments source précèdent le bloc dans le LD.
            # Chaque input formel du FB apparaît (câblé ou non, expression vide
            # sinon) — oracle PRG_input_LD.xml (REX 2026-08).
            declared_inputs = list(instance_input_types.get(inst_name, {}).keys())
            arg_map = dict(arg_matches)
            for p_name in arg_map:
                if p_name not in declared_inputs:
                    declared_inputs.append(p_name)

            param_source_ids = {}  # param_name -> localId du contact/inVariable (ou 0 pour TRUE)
            for p_name in declared_inputs:
                p_val = arg_map.get(p_name)
                if p_val is None:
                    continue
                formal_type = instance_input_types.get(inst_name, {}).get(p_name)
                # REX 2026-08-04 (oracle PRG_Oracle_Nested.xml) : une variable BOOL
                # qualifiee (ex. PRG_07_Supervision.FaultMachineReset_IHM) doit etre un
                # CONTACT, pas un inVariable avec expression. Le filtre PRG_ precedent
                # causait IndexOutOfRangeException (inVariable avec nom qualifie).
                direct_identifier = (
                    p_val is not None
                    and re.fullmatch(r"[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*", p_val)
                )
                if p_val == "TRUE" or p_val == "FALSE" or formal_type != "BOOL" or not direct_identifier:
                    # Non-BOOL (TIME/INT/WORD/REAL), constantes (TRUE/FALSE), expression :
                    # inVariable, pas contact. FALSE est sérialisé "0", TRUE est "1" (oracle CODESYS).
                    source_id = local_id_counter
                    local_id_counter += 2
                    input_var = ET.SubElement(ld, "inVariable")
                    input_var.set("localId", str(source_id))
                    ET.SubElement(input_var, "position", x="0", y="0")
                    ET.SubElement(input_var, "connectionPointOut")
                    expression = ET.SubElement(input_var, "expression")
                    if p_val == "FALSE":
                        expression.text = "0"
                    elif p_val == "TRUE":
                        expression.text = "1"
                    elif p_val is not None:
                        expression.text = p_val
                    param_source_ids[p_name] = source_id
                    continue
                # BOOL variable : contact.
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
                param_source_ids[p_name] = cnt_id

            # ── Phase 2 : créer le bloc APRÈS ses sources.
            block = ET.SubElement(ld, "block")
            block.set("localId", str(block_id))
            block.set("typeName", instance_type)
            block.set("instanceName", inst_name)
            instance_block_map[inst_name] = block_id
            ET.SubElement(block, "position", x="0", y="0")

            in_vars = ET.SubElement(block, "inputVariables")
            for p_name in declared_inputs:
                if p_name not in param_source_ids:
                    continue
                var_in = ET.SubElement(in_vars, "variable")
                var_in.set("formalParameter", p_name)
                c_in_p = ET.SubElement(var_in, "connectionPointIn")
                c_ref_p = ET.SubElement(c_in_p, "connection")
                c_ref_p.set("refLocalId", str(param_source_ids[p_name]))

            ET.SubElement(block, "inOutVariables")
            out_vars = ET.SubElement(block, "outputVariables")
            # Émettre TOUS les outputs déclarés du FB (alignement sur l'oracle CODESYS
            # PRG_TestSafety_LD.xml). Une balise <outputVariables/> vide provoque une
            # IndexOutOfRangeException à l'import CODESYS pour les FB composites.
            # REX 2026-08-04 (régression commit af5566a).
            #
            # IMPORTANT — forme de <connectionPointOut> (oracle PRG_TestSafety_LD.xml) :
            #   - Le **premier output** DOIT être en forme "câblée" <connectionPointOut/>
            #     (SANS <expression/>), même si aucune coil n'est connectée. C'est la
            #     convention CODESYS pour le "principal" output du bloc.
            #   - Les autres outputs sont en forme "non-câblée"
            #     <connectionPointOut><expression/></connectionPointOut>.
            # Si TOUS les outputs sont en forme non-câblée, CODESYS lève
            # IndexOutOfRangeException à l'import (REX 2026-08-04, bundles D/E/F/G/H).
            # REX 2026-08-04 (oracle PRG_Oracle_Nested.xml) : assignations dans outputVariables
            outputs = instance_output_types.get(inst_name, [])
            out_assigns = fb_output_assignments.get(inst_name, {})
            # Targets supplementaires (doublons) -> coils connectees au bloc
            extra_out_targets: list[tuple[str, str]] = []
            for idx, out_p in enumerate(outputs):
                var_out = ET.SubElement(out_vars, "variable")
                var_out.set("formalParameter", out_p)
                c_out = ET.SubElement(var_out, "connectionPointOut")
                if idx == 0:
                    pass  # Premier output : forme cablee (pas d expression)
                else:
                    expr = ET.SubElement(c_out, "expression")
                    if out_p in out_assigns:
                        targets = out_assigns[out_p]
                        expr.text = targets[0]  # Premier target dans le bloc
                        # Targets supplementaires -> coils connectees au bloc
                        for t in targets[1:]:
                            extra_out_targets.append((out_p, t))
            if not list(out_vars):
                # FB sans output déclaré connu : on conserve au moins State en forme
                # câblée (convention CODESYS pour le premier output).
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

            # REX 2026-08-04 : coils pour les targets supplementaires (doublons d output).
            # Oracle PRG_Oracle_Nested.xml : un output a un seul <expression> dans le bloc.
            # Les targets supplementaires -> coils connectees au bloc avec formalParameter.
            for out_p, target_var in extra_out_targets:
                coil_id = local_id_counter
                local_id_counter += 10
                coil = ET.SubElement(ld, "coil")
                coil.set("localId", str(coil_id))
                coil.set("negated", "false")
                coil.set("storage", "none")
                ET.SubElement(coil, "position", x="0", y="0")
                coil_in = ET.SubElement(coil, "connectionPointIn")
                conn = ET.SubElement(coil_in, "connection")
                conn.set("refLocalId", str(block_id))
                conn.set("formalParameter", out_p)
                ET.SubElement(coil, "connectionPointOut")
                coil_variable = ET.SubElement(coil, "variable")
                coil_variable.text = target_var

            continue

        # ── Blocs Fonctionnels Standards IEC OR(...) et AND(...) ──
        match_func_logic = re.match(r"^([A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*)\s*:=\s*(OR|AND)\s*\((.*)\)$", stmt_clean, flags=re.DOTALL | re.IGNORECASE)
        if match_func_logic:
            out_var_name, func_name, args_str = match_func_logic.groups()
            func_type = func_name.upper()
            raw_args = [a.strip() for a in args_str.split(",") if a.strip()]
            
            parsed_func_args: list[tuple[str, bool]] = []
            valid_func = True
            for a in raw_args:
                is_not = False
                a_clean = a
                if a.startswith("NOT "):
                    is_not = True
                    a_clean = a[4:].strip()
                if re.fullmatch(r"[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*", a_clean):
                    parsed_func_args.append((a_clean, is_not))
                else:
                    valid_func = False
                    break

            if valid_func and len(parsed_func_args) >= 2:
                # Invariant CODESYS : localId du bloc PLUS PETIT que ses sources
                block_id = local_id_counter
                local_id_counter += 2

                # 1. Créer les inVariables d'entrée en amont (opérandes d'une fonction boîte)
                param_ids: list[int] = []
                for cond_name, is_not in parsed_func_args:
                    src_id = local_id_counter
                    local_id_counter += 2
                    param_ids.append((src_id, is_not))

                    input_var = ET.SubElement(ld, "inVariable")
                    input_var.set("localId", str(src_id))
                    input_var.set("negated", "false")
                    ET.SubElement(input_var, "position", x="0", y="0")
                    ET.SubElement(input_var, "connectionPointOut")
                    expr_el = ET.SubElement(input_var, "expression")
                    expr_el.text = cond_name

                # 2. Créer le bloc opérateur AND / OR
                block = ET.SubElement(ld, "block")
                block.set("localId", str(block_id))
                block.set("typeName", func_type)
                ET.SubElement(block, "position", x="0", y="0")

                in_vars = ET.SubElement(block, "inputVariables")
                # Broche EN reliée au rail d'alimentation gauche (localId="0")
                var_en = ET.SubElement(in_vars, "variable")
                var_en.set("formalParameter", "EN")
                c_in_en = ET.SubElement(var_en, "connectionPointIn")
                c_ref_en = ET.SubElement(c_in_en, "connection")
                c_ref_en.set("refLocalId", "0")

                for idx, (src_id, is_not) in enumerate(param_ids, start=2):
                    var_in = ET.SubElement(in_vars, "variable")
                    var_in.set("formalParameter", f"In{idx}")
                    if is_not:
                        var_in.set("negated", "true")
                    c_in_b = ET.SubElement(var_in, "connectionPointIn")
                    c_ref_b = ET.SubElement(c_in_b, "connection")
                    c_ref_b.set("refLocalId", str(src_id))

                ET.SubElement(block, "inOutVariables")
                out_vars = ET.SubElement(block, "outputVariables")
                # Broche ENO (non câblée)
                var_eno = ET.SubElement(out_vars, "variable")
                var_eno.set("formalParameter", "ENO")
                ET.SubElement(var_eno, "connectionPointOut")

                # Broche Out2 avec target expression
                var_out = ET.SubElement(out_vars, "variable")
                var_out.set("formalParameter", "Out2")
                c_out = ET.SubElement(var_out, "connectionPointOut")
                expr_out = ET.SubElement(c_out, "expression")
                expr_out.text = out_var_name

                b_adddata = ET.SubElement(block, "addData")
                d_b = ET.SubElement(b_adddata, "data")
                d_b.set("name", "http://www.3s-software.com/plcopenxml/fbdcalltype")
                d_b.set("handleUnknown", "implementation")
                call_type = ET.SubElement(d_b, "CallType")
                call_type.set("xmlns", "")
                call_type.text = "operator"
                continue

        # Expression AND (contacts en série)
        if ":=" in stmt_clean and " AND " in stmt_clean:
            parts = stmt_clean.split(":=")
            out_var_name = parts[0].strip()
            raw_conds = [c.strip() for c in parts[1].split("AND")]
            
            valid_and = True
            parsed_conds: list[tuple[str, bool]] = []
            for c in raw_conds:
                is_not = False
                c_clean = c
                if c.startswith("NOT "):
                    is_not = True
                    c_clean = c[4:].strip()
                if re.fullmatch(r"[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*", c_clean):
                    parsed_conds.append((c_clean, is_not))
                else:
                    valid_and = False
                    break

            if valid_and:
                prev_id = 0
                for cond_name, is_not in parsed_conds:
                    cnt_id = local_id_counter
                    local_id_counter += 2

                    contact = ET.SubElement(ld, "contact")
                    contact.set("localId", str(cnt_id))
                    contact.set("negated", "true" if is_not else "false")
                    contact.set("storage", "none")
                    contact.set("edge", "none")
                    ET.SubElement(contact, "position", x="0", y="0")
                    c_in = ET.SubElement(contact, "connectionPointIn")
                    c_ref = ET.SubElement(c_in, "connection")
                    c_ref.set("refLocalId", str(prev_id))
                    ET.SubElement(contact, "connectionPointOut")
                    var_el = ET.SubElement(contact, "variable")
                    var_el.text = cond_name
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
            raw_conds = [c.strip() for c in parts[1].split("OR")]
            
            valid_or = True
            parsed_or_conds: list[tuple[str, bool]] = []
            for c in raw_conds:
                is_not = False
                c_clean = c
                if c.startswith("NOT "):
                    is_not = True
                    c_clean = c[4:].strip()
                if re.fullmatch(r"[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*", c_clean):
                    parsed_or_conds.append((c_clean, is_not))
                else:
                    valid_or = False
                    break

            if valid_or:
                branch_ids = []
                for cond_name, is_not in parsed_or_conds:
                    cnt_id = local_id_counter
                    local_id_counter += 2
                    branch_ids.append(cnt_id)

                    contact = ET.SubElement(ld, "contact")
                    contact.set("localId", str(cnt_id))
                    contact.set("negated", "true" if is_not else "false")
                    contact.set("storage", "none")
                    contact.set("edge", "none")
                    ET.SubElement(contact, "position", x="0", y="0")
                    c_in = ET.SubElement(contact, "connectionPointIn")
                    c_ref = ET.SubElement(c_in, "connection")
                    c_ref.set("refLocalId", "0")
                    ET.SubElement(contact, "connectionPointOut")
                    var_el = ET.SubElement(contact, "variable")
                    var_el.text = cond_name

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
            direct_identifier = bool(re.fullmatch(r"[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*", source_expression))

            # Résolution du type booléen :
            # 1. target ou source déclarée explicitement dans boolean_identifiers
            # 2. membre résolu comme BOOL dans instance_output_type_map
            # 3. par défaut pour les signaux booléens simples sans type non-BOOL explicite
            src_is_bool = source_expression in boolean_identifiers
            if "." in source_expression:
                s_inst, _, s_mem = source_expression.rpartition(".")
                s_type = instance_output_type_map.get(s_inst, {}).get(s_mem)
                if s_type == "BOOL":
                    src_is_bool = True
                elif s_type in SCALAR_TYPES:
                    src_is_bool = False

            is_bool_assignment = direct_identifier and (
                target_var in boolean_identifiers
                or src_is_bool
                or (source_expression.startswith("PRG_") and not any(source_expression.endswith(w) for w in ("Word", "Hz", "Speed", "Ref", "Step", "Count", "Time")))
                or (source_expression.startswith("GVL_") and not any(source_expression.endswith(w) for w in ("Word", "Hz", "Speed", "Ref", "Step", "Count", "Time")))
            )

            if is_bool_assignment:
                inst_name, _, member_name = source_expression.partition(".")
                is_direct_output = (
                    inst_name in instance_block_map
                    and member_name in instance_output_type_map.get(inst_name, {})
                    and "." not in member_name
                )
                if is_direct_output:
                    block_local_id = instance_block_map[inst_name]
                    coil_id = local_id_counter
                    local_id_counter += 10

                    coil = ET.SubElement(ld, "coil")
                    coil.set("localId", str(coil_id))
                    coil.set("negated", "false")
                    coil.set("storage", "none")
                    ET.SubElement(coil, "position", x="0", y="0")
                    coil_in = ET.SubElement(coil, "connectionPointIn")
                    conn = ET.SubElement(coil_in, "connection")
                    conn.set("refLocalId", str(block_local_id))
                    conn.set("formalParameter", member_name)
                    ET.SubElement(coil, "connectionPointOut")
                    coil_variable = ET.SubElement(coil, "variable")
                    coil_variable.text = target_var
                    continue

                # Sinon contact -> coil (variable BOOL simple ou qualifiée)
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
                continue

            # Contact inversé : NOT variable → contact negated=true → coil
            not_match = re.fullmatch(r"NOT\s+([A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*)", source_expression)
            if not_match and not not_match.group(1).startswith("PRG_") and not_match.group(1) in boolean_identifiers:
                contact_id = local_id_counter
                coil_id = local_id_counter + 1
                local_id_counter += 10

                contact = ET.SubElement(ld, "contact")
                contact.set("localId", str(contact_id))
                contact.set("negated", "true")
                contact.set("storage", "none")
                contact.set("edge", "none")
                ET.SubElement(contact, "position", x="0", y="0")
                contact_in = ET.SubElement(contact, "connectionPointIn")
                ET.SubElement(contact_in, "connection", refLocalId="0")
                ET.SubElement(contact, "connectionPointOut")
                contact_variable = ET.SubElement(contact, "variable")
                contact_variable.text = not_match.group(1)

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
            if source_expression == "FALSE":
                expression.text = "0"
            elif source_expression == "TRUE":
                expression.text = "1"
            else:
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
