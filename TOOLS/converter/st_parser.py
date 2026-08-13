"""Robust ST code parser producing clean ProgramAST representation."""
from __future__ import annotations
import re
from pathlib import Path
from .st_ast import ProgramAST, VariableDecl, FbCallAST, BooleanNetworkAST, AssignmentAST, StatementAST


_REGION_PRAGMA_RE = re.compile(
    r"\{\s*(?:region(?:\s+(?:\"[^\"]*\"|'[^']*'))?|endregion)\s*\}",
    re.IGNORECASE,
)

def _strip_comments(text: str) -> str:
    """Remove comments and visual CODESYS regions, preserving line count.

    ``{region ...}`` / ``{endregion}`` are editor-only pragmas. They must not
    become ST statements when this legacy converter reads a POU for LD.
    """
    out = []
    i = 0
    n = len(text)
    while i < n:
        if text[i] == "{":
            region_match = _REGION_PRAGMA_RE.match(text, i)
            if region_match:
                pragma = region_match.group(0)
                out.append("".join("\n" if ch == "\n" else " " for ch in pragma))
                i = region_match.end()
                continue
        if text[i:i + 2] == "(*":
            end = text.find("*)", i + 2)
            if end == -1:
                out.append("\n" * text.count("\n", i))
                break
            out.append("\n" * text.count("\n", i, end))
            i = end + 2
            continue
        if text[i:i + 2] == "//":
            end = text.find("\n", i)
            if end == -1:
                break
            i = end
            continue
        out.append(text[i])
        i += 1
    return "".join(out)


def _split_top_level(text: str) -> list[str]:
    """Split on ',' at paren-depth 0 only, so a nested expression's comma (if any)
    or parenthesized sub-expression isn't mistaken for a parameter boundary."""
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


_NETWORK_TITLE_RE = re.compile(r"^===\s*(.+?)\s*===$")


def _extract_comment_blocks(body_text: str) -> dict[int, str]:
    """Map 1-indexed statement-start line -> preceding comment text (as-written).

    Two real, distinct comment kinds observed in this codebase (REX 2026-08-13) --
    both captured here, classification (title vs plain) happens in ld_xml_writer.py:
      1. `// === §N TITLE ===` box comment -> CODESYS network title
         (confirmed pattern: <comment> + <vendorElement ElementType=networktitle>,
         PRG_06_Outputs_LD oracle export).
      2. A plain `// explanatory text` line -> ordinary <comment>, no vendorElement.
    Only a comment on its OWN line, directly preceding a statement (blank lines
    tolerated in between) is captured -- a comment embedded inside a multi-line
    function call's parameter list is a separate, unsolved problem.
    """
    lines = body_text.splitlines()
    blocks: dict[int, str] = {}
    block_lines: list[str] = []
    for idx, line in enumerate(lines, start=1):
        stripped = line.strip()
        if stripped.startswith("//"):
            block_lines.append(stripped[2:].strip())
            continue
        if not stripped:
            continue  # blank line between a comment block and its statement: keep pending
        if block_lines:
            blocks[idx] = "\n".join(block_lines)
            block_lines = []
    return blocks


def _split_statements(body_text: str) -> list[tuple[str | None, str]]:
    """Join multi-line ST statements into single logical units, split on top-level ';'.

    A naive line-by-line scan silently drops any statement (FB call, assignment)
    that spans multiple physical lines -- e.g. a multi-parameter FB call written
    one named parameter per line, common style in this codebase (REX 2026-08-13:
    instSimBench(...) was entirely dropped, no <block> emitted at all).

    Returns [(comment_or_None, statement_text)].
    """
    comment_blocks = _extract_comment_blocks(body_text)
    clean = _strip_comments(body_text)
    statements: list[tuple[str | None, str]] = []
    buf: list[str] = []
    buf_start_line: int | None = None
    depth = 0
    if_depth = 0
    line_no = 1
    # Word-boundary scan for IF/END_IF so a whole conditional becomes ONE statement
    # instead of being fragmented at its internal ';' -- fragmenting produces corrupt
    # variable names (e.g. "IF NOT X THEN Y" as a target) that crash CODESYS import
    # (REX 2026-08-13: "L'index se trouve en dehors des limites du tableau").
    word_re = re.compile(r"[A-Za-z_]\w*")
    i = 0
    n = len(clean)
    while i < n:
        ch = clean[i]
        if ch.isalpha() or ch == "_":
            m = word_re.match(clean, i)
            word = m.group(0)
            if word == "IF":
                if_depth += 1
            elif word == "END_IF":
                if_depth -= 1
            if buf_start_line is None:
                buf_start_line = line_no
            buf.append(word)
            i = m.end()
            continue
        if ch == "\n":
            line_no += 1
        elif not ch.isspace():
            if buf_start_line is None:
                buf_start_line = line_no
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        buf.append(ch)
        if ch == ";" and depth <= 0 and if_depth <= 0:
            stmt = "".join(buf).strip()
            if stmt:
                comment = comment_blocks.get(buf_start_line) if buf_start_line else None
                statements.append((comment, stmt))
            buf = []
            buf_start_line = None
            depth = 0
            if_depth = 0
        i += 1
    tail = "".join(buf).strip()
    if tail:
        comment = comment_blocks.get(buf_start_line) if buf_start_line else None
        statements.append((comment, tail))
    return statements


def parse_st_source(st_text: str, default_name: str = "PRG_Unknown") -> ProgramAST:
    """Parse ST code string into ProgramAST."""
    # Separate documentation / header comment if present
    doc_lines = []
    header_match = re.search(r"^\(\*(.*?)\*\)", st_text, re.DOTALL)
    if header_match:
        doc_lines.append(header_match.group(1).strip())

    # Find program name
    pou_name = default_name
    pou_type = "program"
    prog_match = re.search(r"\b(PROGRAM|FUNCTION_BLOCK)\s+([A-Za-z_]\w*)", st_text)
    if prog_match:
        pou_type = prog_match.group(1).lower()
        pou_name = prog_match.group(2)

    ast = ProgramAST(name=pou_name, pou_type=pou_type, documentation="\n".join(doc_lines))

    # Extract interface section (VAR_...)
    body_text = st_text
    if prog_match:
        end_decl_match = re.search(r"\bEND_VAR\b", st_text)
        # Find the last END_VAR before body logic
        all_end_vars = [m.end() for m in re.finditer(r"\bEND_VAR\b", st_text)]
        if all_end_vars:
            body_text = st_text[all_end_vars[-1]:]

    # Parse variable declarations
    var_sections = re.findall(r"\b(VAR_INPUT|VAR_OUTPUT|VAR_IN_OUT|VAR)\b(.*?)\bEND_VAR\b", st_text, re.DOTALL)
    
    # Map for FB instances to know their types
    fb_instances: dict[str, str] = {}

    for sec_type, sec_content in var_sections:
        for line in sec_content.splitlines():
            line_clean = line.strip()
            if not line_clean or line_clean.startswith("//") or line_clean.startswith("(*"):
                continue
            
            # Extract line comment if present
            comment = None
            if "(*" in line_clean:
                line_part, c_part = line_clean.split("(*", 1)
                line_clean = line_part.strip()
                comment = c_part.split("*)", 1)[0].strip()

            if ":" in line_clean and line_clean.endswith(";"):
                parts = line_clean[:-1].split(":", 1)
                v_name = parts[0].strip()
                v_type = parts[1].strip()
                
                # Check initial value
                v_init = None
                if ":=" in v_type:
                    v_type_parts = v_type.split(":=")
                    v_type = v_type_parts[0].strip()
                    v_init = v_type_parts[1].strip()

                decl = VariableDecl(name=v_name, data_type=v_type, initial_value=v_init, comment=comment)

                if sec_type == "VAR_INPUT":
                    ast.inputs.append(decl)
                elif sec_type == "VAR_OUTPUT":
                    ast.outputs.append(decl)
                elif sec_type == "VAR_IN_OUT":
                    ast.inouts.append(decl)
                else:
                    ast.locals.append(decl)
                    if v_type.startswith("FB_") or v_type.startswith("R_TRIG") or v_type.startswith("F_TRIG") or v_type.startswith("TON") or v_type.startswith("TOF"):
                        fb_instances[v_name] = v_type

    # Parse body statements
    fb_calls: dict[str, FbCallAST] = {}

    for stmt_comment, raw_stmt in _split_statements(body_text):
        stmt = " ".join(raw_stmt.split())
        if not stmt:
            continue
        if stmt in ("END_PROGRAM;", "END_FUNCTION_BLOCK;", "END_PROGRAM", "END_FUNCTION_BLOCK"):
            continue
        if re.match(r"\bIF\b", stmt) or re.match(r"\bCASE\b", stmt):
            # IF/ELSIF/ELSE/END_IF and CASE are not supported (CODE_QUALITY_STANDARDS.md §11) --
            # refuse cleanly rather than fragment on internal ';' and emit a corrupt
            # variable name that crashes CODESYS import (REX 2026-08-13, IndexOutOfRange).
            ast.unsupported_statements.append(stmt)
            continue

        # Check FB call syntax: instName(param1 := val1, param2 := val2);
        fb_call_match = re.match(r"([A-Za-z_]\w*)\s*\((.*)\)\s*;\s*$", stmt, re.DOTALL)
        if fb_call_match:
            inst_name = fb_call_match.group(1)
            params_str = fb_call_match.group(2)
            fb_type = fb_instances.get(inst_name, "FB_Block")

            fb_ast = FbCallAST(instance_name=inst_name, fb_type=fb_type, raw_text=stmt, comment=stmt_comment)

            if params_str.strip():
                # Parse parameters inside () -- split on top-level commas only,
                # a param value can itself contain '(' (e.g. a nested expression).
                p_items = _split_top_level(params_str)
                for p_item in p_items:
                    if ":=" in p_item:
                        p_name, p_val = [x.strip() for x in p_item.split(":=", 1)]
                        fb_ast.param_inputs[p_name] = p_val
                    elif "=>" in p_item:
                        p_name, p_val = [x.strip() for x in p_item.split("=>", 1)]
                        fb_ast.param_outputs[p_name] = [p_val]

            fb_calls[inst_name] = fb_ast
            ast.statements.append(fb_ast)
            continue

        # Check FB output assignment: VarTarget := instName.OutputName;
        if ":=" in stmt and ";" in stmt:
            stmt_clean = stmt.rstrip(";").strip()
            parts = stmt_clean.split(":=", 1)
            target = parts[0].strip()
            expr = parts[1].strip()

            # Check if expr is inst.Output
            if "." in expr and not expr.startswith("PRG_") and not expr.startswith("GVL_"):
                inst_part, out_part = expr.split(".", 1)
                if inst_part in fb_calls:
                    fb_ast = fb_calls[inst_part]
                    if out_part not in fb_ast.param_outputs:
                        fb_ast.param_outputs[out_part] = []
                    fb_ast.param_outputs[out_part].append(target)
                    continue

            # Check function call FIRST -- a call's arguments (e.g. SEL(A AND B, C, D))
            # can themselves contain " OR "/" AND ", so the whole-expression OR/AND
            # split below must never run on a call's text (REX 2026-08-13: produced
            # two garbage contacts, each holding a fragment of the SEL(...) text).
            if re.match(r"^[A-Za-z_]\w*\s*\(.*\)$", expr, re.DOTALL):
                ast.statements.append(AssignmentAST(target_var=target, expression=expr, raw_text=stmt, comment=stmt_comment))
                continue

            # Check OR network
            if " OR " in expr:
                conds = [c.strip() for c in expr.split(" OR ")]
                ast.statements.append(BooleanNetworkAST(target_var=target, operator="OR", operands=conds, raw_text=stmt, comment=stmt_comment))
                continue

            # Check AND network
            if " AND " in expr:
                conds = [c.strip() for c in expr.split(" AND ")]
                ast.statements.append(BooleanNetworkAST(target_var=target, operator="AND", operands=conds, raw_text=stmt, comment=stmt_comment))
                continue

            # Simple contact/coil or assignment
            ast.statements.append(AssignmentAST(target_var=target, expression=expr, raw_text=stmt, comment=stmt_comment))

    return ast


def parse_st_file(file_path: Path) -> ProgramAST:
    """Parse a .st file into ProgramAST."""
    content = file_path.read_text(encoding="utf-8")
    return parse_st_source(content, default_name=file_path.stem)
