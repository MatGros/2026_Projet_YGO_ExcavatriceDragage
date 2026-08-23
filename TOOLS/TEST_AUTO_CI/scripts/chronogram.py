#!/usr/bin/env python3
"""Instrumentation du C++ genere par STruCpp pour produire une trace scan-par-scan (chronogramme).

STruCpp (--test) genere dans un dossier temp OS (jamais nettoye, constate empiriquement) :
  generated.hpp   -- classes des FB + DUT compiles
  generated.cpp   -- implementation
  test_main.cpp   -- 1 fonction par TEST, entierement deroulee : s.FB.CHAMP=val; ... s.FB();

Ce module : (1) extrait la liste des champs publics du FB teste depuis generated.hpp,
(2) injecte un dump JSON apres chaque appel s.FB() dans une copie de test_main.cpp,
(3) recompile avec g++ (memes includes runtime que STruCpp), (4) execute et parse la trace.
Aucun fichier de TOOLS/COMPILER_ST2C_STruCpp ni CODE/ n'est modifie -- tout se passe dans le
dossier temp.
"""

import json
import pathlib
import re
import subprocess

FIELD_LINE_RE = re.compile(r"^\s*(\w+)\s+(\w+)\s*;\s*$")
STRUCT_RE = re.compile(r"struct\s+(\w+)\s*\{(.*?)\};", re.DOTALL)
SCAN_CALL_RE = re.compile(r"(\n(\s*)s\.FB\(\);\n\s*s\.FB\.ENO = true;)")
TEST_FUNC_RE = re.compile(
    r"// TEST '([^']*)'\nbool (test_\d+)\(strucpp::TestContext& ctx\) \{.*?"
    r"bool __passed = \[&\]\(\) -> bool \{",
    re.DOTALL,
)


def _extract_structs(hpp_text: str) -> dict:
    """DUT (struct) -> liste de (nom, type IEC_*) (les champs non-IEC_, tableaux, etc. sont
    ignores -- suffisant pour un premier niveau de chronogramme)."""
    structs = {}
    for m in STRUCT_RE.finditer(hpp_text):
        name, body = m.group(1), m.group(2)
        fields = []
        for line in body.splitlines():
            fm = FIELD_LINE_RE.match(line.split("{")[0] + ";" if "{" in line else line)
            if fm and fm.group(1).startswith("IEC_"):
                fields.append((fm.group(2), fm.group(1)))
        if fields:
            structs[name] = fields
    return structs


def extract_fb_fields(hpp_text: str, fb_class_name: str) -> list:
    """Retourne une liste de (expression C++, label, is_bool) pour tous les champs scalaires
    (et DUT imbriques sur 1 niveau) du FB teste, dans l'ordre de declaration. is_bool vient du
    VRAI type declare (IEC_BOOL) -- ne JAMAIS le deduire des valeurs observees (un WORD qui ne
    prend que 0/1 dans un test donne n'est pas un booleen, cf. ERRORID bit0)."""
    structs = _extract_structs(hpp_text)

    class_re = re.compile(rf"class {fb_class_name} \{{\npublic:\n(.*?)\n\n    // Implicit", re.DOTALL)
    m = class_re.search(hpp_text)
    if not m:
        return []

    fields = []
    for line in m.group(1).splitlines():
        line = line.strip()
        if not line or line.startswith("//"):
            continue
        fm = FIELD_LINE_RE.match(line)
        if not fm:
            continue
        ftype, fname = fm.group(1), fm.group(2)
        if ftype.startswith("IEC_"):
            fields.append((fname, fname, ftype == "IEC_BOOL"))
        elif ftype in structs:
            for sub_name, sub_type in structs[ftype]:
                fields.append((f"{fname}.{sub_name}", f"{fname}.{sub_name}", sub_type == "IEC_BOOL"))
        # sinon (instance de FB imbrique) -- ignore pour ce 1er niveau de chronogramme
    return fields


def build_trace_helper(fb_class_name: str, fields: list) -> str:
    parts = " + \",\" + ".join(
        f'"\\"{label}\\":\\"" + strucpp::json_escape(strucpp::to_display_string(fb.{expr})) + "\\""'
        for expr, label, _is_bool in fields
    )
    return f"""
static std::string __trace_fields(const strucpp::{fb_class_name}& fb) {{
    return {parts};
}}
static int __scan_id = 0;
"""


def instrument_test_main(test_main_text: str, fb_class_name: str, fields: list) -> str:
    helper = build_trace_helper(fb_class_name, fields)
    text = test_main_text.replace('#include "iec_test.hpp"', '#include "iec_test.hpp"' + helper)

    # reset __scan_id + injecte un tag "test" par fonction de test (pour associer les scans)
    def _inject_reset(m):
        return m.group(0) + f'\n        __scan_id = 0; const char* __test_name = "{m.group(1)}";'

    text = TEST_FUNC_RE.sub(_inject_reset, text)

    def _inject_trace(m):
        indent = m.group(2)
        return (
            f"{m.group(1)}\n{indent}printf(\"SCANTRACE {{\\\"test\\\":\\\"%s\\\",\\\"scan\\\":%d,"
            f"\\\"t_ns\\\":%lld,\\\"fields\\\":{{%s}}}}\\n\", __test_name, __scan_id++, "
            f"(long long)strucpp::__CURRENT_TIME_NS, __trace_fields(s.FB).c_str());"
        )

    text = SCAN_CALL_RE.sub(_inject_trace, text)
    return text


def build_and_run_traced(temp_dir: pathlib.Path, runtime_include: pathlib.Path,
                          runtime_test: pathlib.Path, fb_class_name: str) -> tuple:
    """Retourne (entries, field_types) : entries = [{test, scan, t_ns, fields:{...}}, ...],
    field_types = {label: bool} -- vrai type declare (IEC_BOOL ou non), a utiliser pour le
    rendu au lieu de deviner depuis les valeurs observees."""
    hpp_text = (temp_dir / "generated.hpp").read_text(encoding="utf-8")
    fields = extract_fb_fields(hpp_text, fb_class_name)
    field_types = {label: is_bool for _expr, label, is_bool in fields}
    if not fields:
        return [], field_types

    test_main_text = (temp_dir / "test_main.cpp").read_text(encoding="utf-8")
    instrumented = instrument_test_main(test_main_text, fb_class_name, fields)

    traced_main = temp_dir / "test_main_traced.cpp"
    traced_main.write_text(instrumented, encoding="utf-8")

    traced_exe = temp_dir / "test_runner_traced.exe"
    compile_cmd = [
        "g++", "-std=c++17", "-O0",
        f"-I{runtime_include}", f"-I{runtime_test}", f"-I{temp_dir}",
        str(traced_main), str(temp_dir / "generated.cpp"),
        "-o", str(traced_exe),
    ]
    result = subprocess.run(compile_cmd, capture_output=True, text=True, encoding="utf-8", cwd=str(temp_dir))
    if result.returncode != 0:
        print("[chronogram] echec compilation instrumentee :")
        print(result.stdout, result.stderr)
        return [], field_types

    run_result = subprocess.run([str(traced_exe)], capture_output=True, text=True, encoding="utf-8")
    entries = []
    for line in run_result.stdout.splitlines():
        if line.startswith("SCANTRACE "):
            try:
                entries.append(json.loads(line[len("SCANTRACE "):]))
            except json.JSONDecodeError:
                continue
    return entries, field_types
