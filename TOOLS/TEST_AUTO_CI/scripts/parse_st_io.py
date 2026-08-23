#!/usr/bin/env python3
"""
parse_st_io.py — Analyseur lexical et d'interface pour le code Structured Text (ST) CODESYS 3.5 / IEC 61131-3.

Rôle :
  1. Tokenisation et suppression propre de tous les commentaires (* ... *), // ..., littéraux de chaînes et pragmas { ... }.
  2. Extraction exhaustive des déclarations par catégorie (VAR_INPUT, VAR_OUTPUT, VAR_IN_OUT, VAR, VAR CONSTANT, VAR_EXTERNAL, etc.) avec types.
  3. Identification des sous-instances de FB instanciées et appelées.
  4. Analyse du corps exécutable pour cartographier les flux réels :
     - Écritures (LHS de :=, écritures de sorties, écritures dans structures/GVL)
     - Lectures (RHS de :=, conditions IF/CASE, arguments d'appels de FB)
  5. Détection des flux implicites (Lectures/Écritures hors interface formelle : GVL_*, retours d'autres PRG, accès transverses).
  6. Génération de matrice de mock pour bancs de tests / harnais.
"""

import argparse
import json
import pathlib
import re
import sys
from typing import Dict, List, Set, Tuple, Any

# Ensure UTF-8 output on Windows consoles
if sys.stdout.encoding != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except AttributeError:
        pass

# Mots-clés IEC 61131-3 & CODESYS à exclure de la détection de variables
ST_KEYWORDS = {
    # Déclarations & Blocs
    "PROGRAM", "END_PROGRAM", "FUNCTION", "END_FUNCTION", "FUNCTION_BLOCK", "END_FUNCTION_BLOCK",
    "TYPE", "END_TYPE", "STRUCT", "END_STRUCT", "ENUM", "END_ENUM", "ARRAY", "OF",
    "VAR", "END_VAR", "VAR_INPUT", "VAR_OUTPUT", "VAR_IN_OUT", "VAR_GLOBAL", "VAR_EXTERNAL",
    "VAR_TEMP", "VAR_STAT", "VAR_CONSTANT", "CONSTANT", "RETAIN", "NON_RETAIN", "PERSISTENT",
    "CONFIGURATION", "END_CONFIGURATION", "RESOURCE", "END_RESOURCE", "TASK", "WITH", "ON",
    "PUBLIC", "INTERNAL", "PROTECTED", "PRIVATE", "ABSTRACT", "FINAL", "EXTENDS", "IMPLEMENTS",
    "INTERFACE", "END_INTERFACE", "METHOD", "END_METHOD", "PROPERTY", "END_PROPERTY", "GET", "SET",
    
    # Contrôle de flux
    "IF", "THEN", "ELSIF", "ELSE", "END_IF",
    "CASE", "END_CASE",
    "FOR", "TO", "BY", "DO", "END_FOR",
    "WHILE", "END_WHILE",
    "REPEAT", "UNTIL", "END_REPEAT",
    "RETURN", "EXIT", "CONTINUE",
    
    # Opérateurs & Littéraux
    "AND", "OR", "XOR", "NOT", "MOD", "SEL", "MUX", "MOVE",
    "TRUE", "FALSE", "NULL", "THIS", "SUPER", "ADR", "SIZEOF",
    
    # Fonctions standard courantes
    "ABS", "SQRT", "LN", "LOG", "EXP", "SIN", "COS", "TAN", "ASIN", "ACOS", "ATAN",
    "LIMIT", "MAX", "MIN", "TRUNC", "ROUND", "FLOOR", "CEIL",
    "LEN", "LEFT", "RIGHT", "MID", "CONCAT", "FIND", "INSERT", "DELETE", "REPLACE",
    "TO_INT", "TO_REAL", "TO_LREAL", "TO_BOOL", "TO_BYTE", "TO_WORD", "TO_DWORD", "TO_UDINT", "TO_DINT", "TO_STRING",
    "INT_TO_REAL", "REAL_TO_INT", "REAL_TO_DINT", "UDINT_TO_REAL", "WORD_TO_UINT", "UINT_TO_WORD",
    "SHL", "SHR", "ROL", "ROR",
    
    # Blocs standard
    "TON", "TOF", "TP", "R_TRIG", "F_TRIG", "CTU", "CTD", "CTUD",
}

# Types de base IEC
IEC_BASE_TYPES = {
    "BOOL", "BYTE", "WORD", "DWORD", "LWORD",
    "SINT", "INT", "DINT", "LINT", "USINT", "UINT", "UDINT", "ULINT",
    "REAL", "LREAL", "STRING", "WSTRING", "TIME", "LTIME", "DATE", "TIME_OF_DAY", "TOD", "DATE_AND_TIME", "DT"
}

class STTokenizer:
    """Tokenizer lexical propre qui gère les commentaires imbriqués, chaînes et pragmas."""
    
    @staticmethod
    def strip_comments_and_literals(source: str) -> Tuple[str, List[str]]:
        """
        Supprime les commentaires (* ... *) et // ..., 
        tout en préservant la structure du code et en extrayant les littéraux de chaînes.
        """
        result = []
        strings = []
        i = 0
        n = len(source)
        
        while i < n:
            # 1. Pragma { ... }
            if source[i] == '{':
                end_p = source.find('}', i + 1)
                if end_p != -1:
                    result.append(' ')
                    i = end_p + 1
                    continue
                else:
                    i += 1
                    continue
            
            # 2. Chaîne littérale '...'
            if source[i] == "'":
                start_s = i
                i += 1
                while i < n and source[i] != "'":
                    if source[i] == '$' and i + 1 < n: # Échappement ST ($', $N, etc.)
                        i += 2
                    else:
                        i += 1
                if i < n:
                    str_lit = source[start_s + 1:i]
                    strings.append(str_lit)
                    result.append(" '' ") # Remplacé par une chaîne vide
                    i += 1
                    continue
            
            # 3. Commentaire ligne // ...
            if source[i:i+2] == '//':
                end_l = source.find('\n', i + 2)
                if end_l != -1:
                    result.append('\n')
                    i = end_l + 1
                else:
                    break
                continue
            
            # 4. Commentaire bloc (* ... *) avec gestion de l'imbrication
            if source[i:i+2] == '(*':
                depth = 1
                i += 2
                while i < n and depth > 0:
                    if source[i:i+2] == '(*':
                        depth += 1
                        i += 2
                    elif source[i:i+2] == '*)':
                        depth -= 1
                        i += 2
                    else:
                        if source[i] == '\n':
                            result.append('\n') # Garder le retour à la ligne pour le comptage
                        i += 1
                continue
            
            # Caractère normal
            result.append(source[i])
            i += 1
            
        return "".join(result), strings


class STParser:
    """Analyseur de structure d'un POU (Program, Function Block)."""

    VAR_BLOCK_RE = re.compile(
        r"\bVAR(?P<kind>_INPUT|_OUTPUT|_IN_OUT|_GLOBAL|_EXTERNAL|_TEMP|_STAT)?(?:\s+(?P<qualifier>CONSTANT|RETAIN|PERSISTENT))?\b(?P<body>.*?)\bEND_VAR\b",
        re.DOTALL | re.IGNORECASE
    )
    
    DECL_RE = re.compile(
        r"^\s*(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*(?:AT\s*%[IQM][\w.]*)?\s*:\s*(?P<type>[^;:=]+)(?:\s*:=\s*(?P<init>[^;]+))?\s*;\s*$",
        re.MULTILINE
    )

    FB_CALL_RE = re.compile(
        r"\b(?P<inst>[A-Za-z_][A-Za-z0-9_]*)\s*\((?P<args>[^;)]*)\)",
        re.DOTALL
    )

    ASSIGN_RE = re.compile(r":=")

    @classmethod
    def parse_declarations(cls, clean_text: str) -> Dict[str, Dict[str, str]]:
        """
        Extrait les déclarations classées par type de bloc :
        {
            "VAR_INPUT": { "VarName": "DataType", ... },
            "VAR_OUTPUT": { ... },
            "VAR_IN_OUT": { ... },
            "VAR_LOCAL": { ... },
            "VAR_CONSTANT": { ... },
            "VAR_EXTERNAL": { ... }
        }
        """
        declarations = {
            "VAR_INPUT": {},
            "VAR_OUTPUT": {},
            "VAR_IN_OUT": {},
            "VAR_LOCAL": {},
            "VAR_CONSTANT": {},
            "VAR_EXTERNAL": {}
        }
        
        for m in cls.VAR_BLOCK_RE.finditer(clean_text):
            kind = m.group("kind")
            qualifier = m.group("qualifier")
            body = m.group("body")
            
            if qualifier and qualifier.upper() == "CONSTANT":
                target_kind = "VAR_CONSTANT"
            elif kind:
                k_upper = kind.upper()
                if k_upper == "_INPUT": target_kind = "VAR_INPUT"
                elif k_upper == "_OUTPUT": target_kind = "VAR_OUTPUT"
                elif k_upper == "_IN_OUT": target_kind = "VAR_IN_OUT"
                elif k_upper == "_EXTERNAL": target_kind = "VAR_EXTERNAL"
                else: target_kind = "VAR_LOCAL"
            else:
                target_kind = "VAR_LOCAL"
                
            for dm in cls.DECL_RE.finditer(body):
                v_name = dm.group("name")
                v_type = dm.group("type").strip()
                v_init = dm.group("init")
                if v_init:
                    declarations[target_kind][v_name] = f"{v_type} := {v_init.strip()}"
                else:
                    declarations[target_kind][v_name] = v_type
                
        return declarations

    @classmethod
    def extract_body(cls, clean_text: str) -> str:
        """Extrait la partie exécutable située après le dernier END_VAR."""
        matches = list(cls.VAR_BLOCK_RE.finditer(clean_text))
        if not matches:
            # Pas de VAR block explicite, chercher le début après PROGRAM / FUNCTION_BLOCK
            header_match = re.search(r"\b(PROGRAM|FUNCTION_BLOCK|FUNCTION)\s+[A-Za-z0-9_]+", clean_text, re.IGNORECASE)
            if header_match:
                return clean_text[header_match.end():]
            return clean_text
        
        last_var_end = matches[-1].end()
        body = clean_text[last_var_end:]
        
        # Supprimer le terminator final s'il existe
        for term in ("END_PROGRAM", "END_FUNCTION_BLOCK", "END_FUNCTION"):
            idx = body.rfind(term)
            if idx != -1:
                body = body[:idx]
                break
        return body

    @classmethod
    def analyze_usages(cls, body: str, declarations: Dict[str, Dict[str, str]]) -> Dict[str, Any]:
        """
        Analyse détaillée des écritures, lectures, appels de sous-blocs et flux externes.
        """
        all_declared_locals = {}
        for block, decls in declarations.items():
            for v, t in decls.items():
                all_declared_locals[v] = {"block": block, "type": t}

        # 1. Identifier les sous-instances (variables locales typées avec un FB non primitif)
        fb_instances = {}
        for v, info in all_declared_locals.items():
            t_upper = info["type"].upper()
            if t_upper not in IEC_BASE_TYPES and not t_upper.startswith("ARRAY") and not t_upper.startswith("STRING"):
                if info["block"] in ("VAR_LOCAL", "VAR_EXTERNAL"):
                    fb_instances[v] = info["type"]

        writes_all: Set[str] = set()
        reads_all: Set[str] = set()
        
        # Tokeniser les expressions pour distinguer identifiants, chemins structurés (A.B.C)
        # 2. Analyser les affectations A := B;
        # Séparer les énoncés
        statements = [s.strip() for s in body.split(';') if s.strip()]
        
        for stmt in statements:
            if ":=" in stmt:
                # C'est une affectation directe (attention aux parenthèses d'appels de FB)
                # Trouver le premier := à profondeur 0 de parenthèses
                depth = 0
                assign_pos = -1
                for idx, ch in enumerate(stmt):
                    if ch in "([": depth += 1
                    elif ch in ")]": depth = max(0, depth - 1)
                    elif ch == ':' and idx + 1 < len(stmt) and stmt[idx+1] == '=' and depth == 0:
                        assign_pos = idx
                        break
                
                if assign_pos != -1:
                    lhs = stmt[:assign_pos].strip()
                    rhs = stmt[assign_pos+2:].strip()
                    
                    # Identifier cible écrite (LHS)
                    lhs_ident = cls._extract_primary_ident_path(lhs)
                    if lhs_ident:
                        writes_all.add(lhs_ident)
                    
                    # Identifier expressions lues (RHS)
                    for r_ident in cls._extract_identifiers_from_expr(rhs):
                        reads_all.add(r_ident)
                    continue

            # Vérifier si c'est un appel de sous-instance : InstName(...)
            fb_m = cls.FB_CALL_RE.match(stmt)
            if fb_m:
                inst_name = fb_m.group("inst")
                args_str = fb_m.group("args")
                # Parser les arguments de l'appel
                cls._parse_fb_call_args(args_str, reads_all, writes_all)
                continue

            # Autres énoncés (IF condition, CASE expr, etc.)
            for ident in cls._extract_identifiers_from_expr(stmt):
                reads_all.add(ident)

        # 3. Classer les flux par domaine / nature
        categorized_writes = cls._categorize_identifiers(writes_all, all_declared_locals)
        categorized_reads = cls._categorize_identifiers(reads_all, all_declared_locals)

        # 4. Déterminer les entrées et sorties réelles transverses (Implicit I/O)
        implicit_inputs = [r for r in reads_all if cls._is_external_or_transverse(r, all_declared_locals)]
        implicit_outputs = [w for w in writes_all if cls._is_external_or_transverse(w, all_declared_locals)]

        return {
            "declarations": declarations,
            "fb_instances": fb_instances,
            "all_writes": sorted(writes_all),
            "all_reads": sorted(reads_all),
            "categorized_writes": categorized_writes,
            "categorized_reads": categorized_reads,
            "implicit_inputs": sorted(set(implicit_inputs)),
            "implicit_outputs": sorted(set(implicit_outputs))
        }

    @staticmethod
    def _is_external_or_transverse(ident_path: str, declared_locals: Dict[str, Any]) -> bool:
        """Détermine si un identifiant provient de l'extérieur (GVL_*, PRG_*, ou non déclaré localement)."""
        base = ident_path.split('.')[0]
        if base.startswith("GVL_") or base.startswith("PRG_"):
            return True
        if base not in declared_locals:
            return True
        block = declared_locals[base]["block"]
        return block in ("VAR_EXTERNAL",)

    @staticmethod
    def _extract_primary_ident_path(lhs: str) -> str:
        """Extrait le chemin complet d'affectation LHS (ex: HwReal.Winch.M1_ContactorsReleased_DI)."""
        tokens = re.findall(r"\b[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*\b", lhs)
        if tokens:
            return tokens[-1]
        return ""

    @staticmethod
    def _extract_identifiers_from_expr(expr: str) -> List[str]:
        """Extrait tous les identifiants/chemins qualifiés d'une expression."""
        # Supprimer les nombres purs, hexa (16#...), etc.
        clean_expr = re.sub(r"\b16#[0-9A-Fa-f]+\b", " ", expr)
        clean_expr = re.sub(r"\b2#[0-1]+\b", " ", clean_expr)
        clean_expr = re.sub(r"\bT#[0-9a-zA-Z_.]+\b", " ", clean_expr)
        clean_expr = re.sub(r"\b\d+(?:\.\d+)?\b", " ", clean_expr)
        
        matches = re.findall(r"\b([A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*)\b", clean_expr)
        res = []
        for m in matches:
            base = m.split('.')[0]
            if base.upper() not in ST_KEYWORDS and not m.isdigit():
                res.append(m)
        return res

    @staticmethod
    def _parse_fb_call_args(args_str: str, reads_set: Set[str], writes_set: Set[str]):
        """Parse les arguments nommés d'appel de FB : Param := Expr ou OutParam => VarTarget."""
        depth = 0
        cur = []
        arg_chunks = []
        for ch in args_str:
            if ch in "([": depth += 1
            elif ch in ")]": depth = max(0, depth - 1)
            elif ch == ',' and depth == 0:
                arg_chunks.append("".join(cur).strip())
                cur = []
                continue
            cur.append(ch)
        if cur:
            arg_chunks.append("".join(cur).strip())

        for chunk in arg_chunks:
            if ":=" in chunk:
                # Param := Expr (Lecture de Expr)
                parts = chunk.split(":=", 1)
                for ident in STParser._extract_identifiers_from_expr(parts[1]):
                    reads_set.add(ident)
            elif "=>" in chunk:
                # OutParam => VarTarget (Écriture dans VarTarget)
                parts = chunk.split("=>", 1)
                target = STParser._extract_primary_ident_path(parts[1])
                if target:
                    writes_set.add(target)

    @staticmethod
    def _load_device_io_mapping() -> Tuple[Dict[str, Dict[str, str]], Set[str]]:
        """Charge la table des E/S physiques mappées et la liste des Devices CODESYS (Device_IO_*.csv)."""
        repo_root = pathlib.Path(__file__).resolve().parents[3]
        csv_candidates = list((repo_root / "TOOLS" / "AGENT_WORKFLOW" / "config").glob("Device_IO_*.csv"))
        if not csv_candidates:
            return {}, set()
        csv_path = sorted(csv_candidates)[-1]
        hw_map = {}
        devices = set()
        try:
            for line in csv_path.read_text(encoding="utf-8", errors="replace").splitlines():
                line = line.strip()
                if not line or line.startswith("//") or line.startswith(";"):
                    continue
                parts = line.split(";")
                if len(parts) >= 6:
                    var_name = parts[0].strip()
                    param_name = parts[1].strip()
                    unit = parts[2].strip()
                    desc = parts[3].strip()
                    iec_addr = parts[4].strip()
                    device = parts[5].strip()
                    if device:
                        devices.add(device)
                    if var_name:
                        hw_map[var_name] = {
                            "param": param_name,
                            "unit": unit,
                            "desc": desc,
                            "iec_addr": iec_addr,
                            "device": device,
                            "is_input": "%I" in iec_addr,
                            "is_output": "%Q" in iec_addr,
                        }
        except Exception:
            pass
        return hw_map, devices

    @classmethod
    def _categorize_identifiers(cls, ident_paths: Set[str], declared_locals: Dict[str, Any]) -> Dict[str, Any]:
        hw_map, devices = cls._load_device_io_mapping()
        categories = {
            "GVL": [],
            "PRG_Inter": [],
            "VAR_OUTPUT": [],
            "VAR_INPUT": [],
            "VAR_LOCAL": [],
            "SUB_INSTANCES": [],
            "HW_IO": {},          # Entrées/Sorties physiques mappées (Device_IO)
            "DEVICES": [],        # Nœuds/Équipements de l'arbre CODESYS (ex: CANbus, COD1_CODEUR)
            "ENUMS": [],          # Énumérations globales du projet (ex: E_Mode, DEVICE_STATE)
            "RETAIN_PERSIST": [], # Variables rémanentes / calibrations persistantes (ex: _CalibM1, _WinchM1CfgPersist)
            "EXTERNAL": []        # Variables réellement inconnues / non déclarées
        }
        
        for p in ident_paths:
            base = p.split('.')[0]
            if base.startswith("GVL_"):
                categories["GVL"].append(p)
            elif base.startswith("PRG_"):
                categories["PRG_Inter"].append(p)
            elif base in declared_locals:
                block = declared_locals[base]["block"]
                type_name = declared_locals[base]["type"]
                if block == "VAR_OUTPUT":
                    categories["VAR_OUTPUT"].append(p)
                elif block == "VAR_INPUT":
                    categories["VAR_INPUT"].append(p)
                elif type_name.upper() not in IEC_BASE_TYPES and not type_name.upper().startswith("ARRAY"):
                    categories["SUB_INSTANCES"].append(p)
                else:
                    categories["VAR_LOCAL"].append(p)
            elif base in hw_map:
                categories["HW_IO"][p] = hw_map[base]
            elif base in devices or base.upper() in ("CANBUS", "ETHERCAT_MASTER", "LOCAL_DIGITAL_IO", "VH_0800END", "VH_0808ETP", "COD1_CODEUR", "COD2_CODEUR", "AC600_ECAT_DRIVE", "JOY1_JOYSTICK_MCB560_CO4201A"):
                categories["DEVICES"].append(p)
            elif base.startswith("E_") or base.upper() in ("DEVICE_STATE", "E_STATE", "E_MODE", "E_DIAG_STATE"):
                categories["ENUMS"].append(p)
            elif base.startswith("_") or "PERSIST" in base.upper() or "CALIB" in base.upper():
                categories["RETAIN_PERSIST"].append(p)
            else:
                categories["EXTERNAL"].append(p)
                
        for k in ("GVL", "PRG_Inter", "VAR_OUTPUT", "VAR_INPUT", "VAR_LOCAL", "SUB_INSTANCES", "DEVICES", "ENUMS", "RETAIN_PERSIST", "EXTERNAL"):
            categories[k].sort()
        return categories


def analyze_st_file(file_path: pathlib.Path) -> Dict[str, Any]:
    raw_text = file_path.read_text(encoding="utf-8", errors="replace")
    
    # 0. Vérification simple et stricte : UN SEUL cartouche d'en-tête propre AVANT la déclaration
    decl_match = re.search(r"\b(?:FUNCTION_BLOCK|PROGRAM)\b", raw_text)
    if decl_match:
        top_code = raw_text[:decl_match.start()].strip()
    else:
        top_code = raw_text.strip()
        
    # Doit commencer par (* === et finir par === *)
    starts_ok = bool(re.match(r"^\(\*\s*(?:={3,}|═{3,}|-{3,}|─{3,})", top_code))
    ends_ok = bool(re.search(r"(?:={3,}|═{3,}|-{3,}|─{3,})\s*\*\)\s*$", top_code))
    
    # Extraire l'intérieur du cartouche
    inner_comment = ""
    if starts_ok and ends_ok:
        first_open = top_code.find("(*")
        last_close = top_code.rfind("*)")
        if first_open != -1 and last_close != -1 and last_close > first_open:
            inner_comment = top_code[first_open + 2 : last_close]

    # Pas de commentaire imbriqué à l'intérieur : ni '//', ni '(*', ni '*)'
    has_no_nested_comments = (
        "//" not in inner_comment and
        "(*" not in inner_comment and
        "*)" not in inner_comment
    )
    
    has_header_comment = starts_ok and ends_ok and has_no_nested_comments
    
    has_var_input_banner = bool(re.search(r"VAR_INPUT\s*[\r\n]+.*?(?://\s*(?:={3,}|═{3,}|-{3,})|\(\*\s*(?:={3,}|═{3,}|-{3,}))", raw_text, re.DOTALL))
    has_var_output_banner = bool(re.search(r"VAR_OUTPUT\s*[\r\n]+.*?(?://\s*(?:={3,}|═{3,}|-{3,})|\(\*\s*(?:={3,}|═{3,}|-{3,}))", raw_text, re.DOTALL))
    has_var_local_banner = bool(re.search(r"(?:^|[\r\n]+)\s*VAR(?:\s+CONSTANT)?\s*[\r\n]+.*?(?://\s*(?:={3,}|═{3,}|-{3,})|\(\*\s*(?:={3,}|═{3,}|-{3,}))", raw_text, re.DOTALL))
    
    structure_quality = {
        "has_header_comment": has_header_comment,
        "has_var_input_banner": has_var_input_banner,
        "has_var_output_banner": has_var_output_banner,
        "has_var_local_banner": has_var_local_banner,
    }

    clean_text, _ = STTokenizer.strip_comments_and_literals(raw_text)
    
    # 1. Déclarations
    declarations = STParser.parse_declarations(clean_text)
    
    # 2. Corps exécutable
    body = STParser.extract_body(clean_text)
    
    # 3. Analyse des flux
    analysis = STParser.analyze_usages(body, declarations)
    analysis["file"] = str(file_path)
    analysis["file_name"] = file_path.name
    analysis["structure_quality"] = structure_quality
    return analysis


def print_report(analysis: Dict[str, Any], verbose: bool = False):
    print(f"\n================================================================================")
    print(f"📦 ANALYSE D'INTERFACE & FLUX I/O : {analysis['file_name']}")
    print(f"================================================================================")
    
    decls = analysis["declarations"]
    print("\n--- 1. INTERFACE FORMELLE DÉCLARÉE ---")
    for block_name in ("VAR_INPUT", "VAR_OUTPUT", "VAR_IN_OUT", "VAR_CONSTANT", "VAR_LOCAL", "VAR_EXTERNAL"):
        vars_in_block = decls.get(block_name, {})
        if vars_in_block:
            print(f"\n🔹 {block_name} ({len(vars_in_block)} déclarations) :")
            for v, t in vars_in_block.items():
                print(f"   • {v:<35} : {t}")
        else:
            print(f"\n🔹 {block_name} : (aucun)")

    print("\n--- 2. SOUS-INSTANCES DE FUNCTION BLOCKS (INSTANCIÉES) ---")
    fb_insts = analysis["fb_instances"]
    if fb_insts:
        for inst, fb_t in fb_insts.items():
            print(f"   ⚙️ {inst:<30} : FB de type [{fb_t}]")
    else:
        print("   (aucune sous-instance)")

    print("\n--- 3. FLUX SORTANTS RÉELS (ÉCRITURES) ---")
    writes = analysis["categorized_writes"]
    if writes["VAR_OUTPUT"]:
        print(f"\n  📤 Sorties Formelles publiées ({len(writes['VAR_OUTPUT'])}) :")
        for w in writes["VAR_OUTPUT"]:
            print(f"     -> {w}")
            
    if writes["GVL"]:
        print(f"\n  ⚠️ Écritures directes dans des GVL ({len(writes['GVL'])}) :")
        for w in writes["GVL"]:
            print(f"     -> {w}")
            
    if writes["PRG_Inter"]:
        print(f"\n  ⚠️ Écritures directes vers d'autres PRG ({len(writes['PRG_Inter'])}) :")
        for w in writes["PRG_Inter"]:
            print(f"     -> {w}")

    print("\n--- 4. FLUX ENTRANTS RÉELS (LECTURES) ---")
    reads = analysis["categorized_reads"]
    if reads["VAR_INPUT"]:
        print(f"\n  📥 Entrées Formelles consommées ({len(reads['VAR_INPUT'])}) :")
        for r in reads["VAR_INPUT"]:
            print(f"     <- {r}")
            
    if reads["GVL"]:
        print(f"\n  🌐 Lectures depuis GVL (Variables Globales) ({len(reads['GVL'])}) :")
        for r in reads["GVL"]:
            print(f"     <- {r}")
            
    if reads["PRG_Inter"]:
        print(f"\n  🔗 Lectures depuis d'autres PRG ({len(reads['PRG_Inter'])}) :")
        for r in reads["PRG_Inter"]:
            print(f"     <- {r}")

    print("\n--- 5. MATRICE DE MOCK RECOMMANDÉE POUR TEST HARNESS ---")
    print("  Pour isoler ce POU et simuler fidèlement son environnement, le harnais de test doit injecter :")
    
    # Inputs formels
    if decls["VAR_INPUT"]:
        print("   [ ] VAR_INPUT directs")
    # Lectures transverses (GVL / Autres PRG)
    gvl_reads_bases = sorted(set(r.split('.')[0] + '.' + r.split('.')[1] if '.' in r else r for r in reads["GVL"]))
    for g in gvl_reads_bases:
        print(f"   [ ] Mock de la variable d'entrée transverse : {g}")
        
    print("\n================================================================================\n")


def main():
    parser = argparse.ArgumentParser(description="Analyseur d'interface et de flux I/O pour fichiers ST CODESYS")
    parser.add_argument("file", help="Chemin vers le fichier .st à analyser")
    parser.add_argument("--json", action="store_true", help="Format de sortie en JSON pur")
    parser.add_argument("--verbose", "-v", action="store_true", help="Affichage verbeux")
    args = parser.parse_args()

    p = pathlib.Path(args.file)
    if not p.is_file():
        print(f"Erreur: fichier introuvable '{p}'", file=sys.stderr)
        sys.exit(1)

    analysis = analyze_st_file(p)
    
    if args.json:
        print(json.dumps(analysis, indent=2))
    else:
        print_report(analysis, verbose=args.verbose)


if __name__ == "__main__":
    main()
