#!/usr/bin/env python3
"""
extract_io.py - Extrait les entrées/sorties d'un fichier ST
"""
import re
import sys
from pathlib import Path

# Fonctions ST standard à exclure
ST_FUNCTIONS = {
    'LIMIT', 'SEL', 'MAX', 'MIN', 'ABS', 'SQRT', 'SIN', 'COS', 'TAN',
    'ASIN', 'ACOS', 'ATAN', 'LN', 'LOG', 'EXP', 'TRUNC', 'ROUND',
    'LEN', 'LEFT', 'RIGHT', 'MID', 'CONCAT', 'FIND', 'DELETE',
    'TON', 'TOF', 'TP', 'CTU', 'CTD', 'CTUD',
    'R_TRIG', 'F_TRIG',
    'MOVE', 'ADD', 'SUB', 'MUL', 'DIV', 'MOD',
    'AND', 'OR', 'XOR', 'NOT',
    'SHL', 'SHR', 'ROL', 'ROR',
    'CONVERT', 'MUX'
}

def extract_var_names(blocks):
    """Extrait les noms de variables des blocs VAR_*"""
    names = []
    for block in blocks:
        matches = re.findall(r'^\s*(\w+)\s*:', block, re.MULTILINE)
        names.extend(matches)
    return names

def remove_comments(content: str) -> str:
    """Enlève les commentaires du code ST"""
    content = re.sub(r'\(\*.*?\*\)', '', content, flags=re.DOTALL)
    content = re.sub(r'//.*$', '', content, flags=re.MULTILINE)
    return content

def extract_all_variables(content: str):
    """Extrait TOUTES les variables (pas juste après :=)"""
    # Variables avec point (GVL_*, PRG_*, etc.)
    all_vars = re.findall(r'\b([A-Z_][A-Z0-9_]*(?:\.[A-Z_][A-Z0-9_]*)*)\b', content, re.IGNORECASE)
    
    # Exclure les mots-clés ST
    keywords = {
        'PROGRAM', 'END_PROGRAM', 'VAR', 'END_VAR', 'VAR_INPUT', 'VAR_OUTPUT',
        'VAR_IN_OUT', 'VAR_EXTERNAL', 'VAR_GLOBAL', 'VAR_TEMP', 'VAR_CONST',
        'CONSTANT', 'RETAIN', 'AT', 'IF', 'THEN', 'ELSIF', 'ELSE', 'END_IF',
        'CASE', 'END_CASE', 'FOR', 'TO', 'BY', 'DO', 'END_FOR', 'WHILE',
        'END_WHILE', 'REPEAT', 'UNTIL', 'END_REPEAT', 'EXIT', 'RETURN',
        'TRUE', 'FALSE', 'NULL', 'OF', 'BOOL', 'BYTE', 'WORD', 'DWORD',
        'LWORD', 'SINT', 'INT', 'DINT', 'LINT', 'USINT', 'UINT', 'UDINT',
        'ULINT', 'REAL', 'LREAL', 'STRING', 'WSTRING', 'TIME', 'DATE',
        'TIME_OF_DAY', 'TOD', 'DATE_AND_TIME', 'DT', 'TYPE', 'END_TYPE',
        'STRUCT', 'END_STRUCT', 'ARRAY', 'FUNCTION', 'END_FUNCTION',
        'FUNCTION_BLOCK', 'END_FUNCTION_BLOCK', 'CONFIGURATION', 'END_CONFIGURATION',
        'RESOURCE', 'END_RESOURCE', 'TASK', 'WITH', 'ON', 'AND', 'OR', 'XOR',
        'NOT', 'MOD', 'REF', 'REF_TO', 'REFERENCE_TO', 'DREF', 'POINTER',
        'PUBLIC', 'PRIVATE', 'PROTECTED', 'EXTENDS', 'IMPLEMENTS', 'THIS',
        'SUPER', 'ABSTRACT', 'FINAL', 'OVERRIDE', 'METHOD', 'END_METHOD',
        'INTERFACE', 'END_INTERFACE', 'PROPERTY', 'END_PROPERTY', 'GET',
        'END_GET', 'SET', 'END_SET', '__NEW', '__DELETE'
    }
    
    # Filtrer
    filtered = []
    for var in all_vars:
        # Exclure les mots-clés
        if var.upper() in keywords:
            continue
        # Exclure les fonctions ST
        if var.upper() in ST_FUNCTIONS:
            continue
        # Exclure les nombres
        if var.isdigit():
            continue
        # Garder
        filtered.append(var)
    
    return sorted(set(filtered))

def extract_io(file_path: str):
    """Extrait toutes les variables d'un fichier ST"""
    
    if not Path(file_path).exists():
        print(f"❌ Fichier non trouvé: {file_path}")
        sys.exit(1)
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    content = remove_comments(content)
    
    # Adresses directes (%IX, %QX, etc.)
    direct_addresses = re.findall(r'(?i)%[IQM][XBWDL]?[0-9]+(?:\.[0-9]+)*', content)
    inputs_iec = [a for a in direct_addresses if a.upper().startswith('%I')]
    outputs_iec = [a for a in direct_addresses if a.upper().startswith('%Q')]
    memories_iec = [a for a in direct_addresses if a.upper().startswith('%M')]
    
    # Variables GVL (GVL_*)
    gvl_vars = re.findall(r'\bGVL_\w+', content)
    
    # Variables PRG (PRG_02_*, PRG_05_*, etc.)
    prg_vars = re.findall(r'\bPRG_\d+_\w+(?:\.\w+)*', content)
    prg_outputs = [v for v in prg_vars if 'Outputs' in v]
    prg_inputs = [v for v in prg_vars if 'Inputs' in v]
    prg_data = [v for v in prg_vars if 'Data' in v and 'Outputs' not in v and 'Inputs' not in v]
    
    # Blocs VAR_*
    var_input_block = re.findall(r'(?i)VAR_INPUT\s+(.*?)\s+END_VAR', content, re.DOTALL)
    var_output_block = re.findall(r'(?i)VAR_OUTPUT\s+(.*?)\s+END_VAR', content, re.DOTALL)
    var_in_out_block = re.findall(r'(?i)VAR_IN_OUT\s+(.*?)\s+END_VAR', content, re.DOTALL)
    var_block = re.findall(r'(?i)(?<!_)VAR(?!_)\s+(.*?)\s+END_VAR', content, re.DOTALL)
    var_external_block = re.findall(r'(?i)VAR_EXTERNAL\s+(.*?)\s+END_VAR', content, re.DOTALL)
    var_global_block = re.findall(r'(?i)VAR_GLOBAL\s+(.*?)\s+END_VAR', content, re.DOTALL)
    var_temp_block = re.findall(r'(?i)VAR_TEMP\s+(.*?)\s+END_VAR', content, re.DOTALL)
    const_block = re.findall(r'(?i)VAR_CONST\s+(.*?)\s+END_VAR', content, re.DOTALL)
    
    var_input_names = extract_var_names(var_input_block)
    var_output_names = extract_var_names(var_output_block)
    var_in_out_names = extract_var_names(var_in_out_block)
    var_names = extract_var_names(var_block)
    var_external_names = extract_var_names(var_external_block)
    var_global_names = extract_var_names(var_global_block)
    var_temp_names = extract_var_names(var_temp_block)
    const_names = extract_var_names(const_block)
    
    # === NOUVEAU : Toutes les variables ===
    all_vars = extract_all_variables(content)
    
    return {
        'inputs_iec': sorted(set(inputs_iec)),
        'outputs_iec': sorted(set(outputs_iec)),
        'memories_iec': sorted(set(memories_iec)),
        'var_input': sorted(set(var_input_names)),
        'var_output': sorted(set(var_output_names)),
        'var_in_out': sorted(set(var_in_out_names)),
        'var': sorted(set(var_names)),
        'var_external': sorted(set(var_external_names)),
        'var_global': sorted(set(var_global_names)),
        'var_temp': sorted(set(var_temp_names)),
        'const': sorted(set(const_names)),
        'gvl_vars': sorted(set(gvl_vars)),
        'prg_outputs': sorted(set(prg_outputs)),
        'prg_inputs': sorted(set(prg_inputs)),
        'prg_data': sorted(set(prg_data)),
        'all_vars': all_vars
    }

def main():
    if len(sys.argv) < 2:
        print("Usage: python extract_io.py <file.st>")
        sys.exit(1)
    
    file_path = sys.argv[1]
    result = extract_io(file_path)
    
    print(f"\n📄 Fichier: {file_path}")
    print("=" * 60)
    
    print("\n=== TOUTES LES VARIABLES ===")
    for var in result['all_vars'][:50]:
        print(f"  {var}")
    if len(result['all_vars']) > 50:
        print(f"  ... et {len(result['all_vars']) - 50} autres")
    
    print("\n" + "=" * 60)

if __name__ == '__main__':
    main()