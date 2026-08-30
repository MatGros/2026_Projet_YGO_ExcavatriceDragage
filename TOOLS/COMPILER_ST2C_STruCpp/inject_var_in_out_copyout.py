#!/usr/bin/env python3
"""Post-traitement du test_main.cpp généré par STruCpp : injection du copy-out
des VAR_IN_OUT après chaque appel s.FB().

STruCpp (--test) génère un copy-in seul (s.FB.X = s.X;) avant chaque appel,
sans jamais le copy-out (s.X = s.FB.X;). Or CODESYS 3.5 passe les VAR_IN_OUT
par référence : toute écriture du FB sur une VAR_IN_OUT doit être restituée
à la variable de test. Ce module injecte le copy-out manquant.

Le mapping est SANS AMBIGUÏTÉ : la ligne de copy-in s.FB.X = s.Y; donne
exactement la variable de test Y liée à la VAR_IN_OUT X. Aucune heuristique.
Si une VAR_IN_OUT n'a pas de copy-in avant un appel, elle n'est pas passée par
le test : aucun copy-out n'est injecté (pas de variable de test à restituer).

Usage (module) :
    from inject_var_in_out_copyout import postprocess_file, recompile_test_runner
    postprocess_file(test_main_path, fb_st_path, fb_var="FB")
    exe = recompile_test_runner(temp_dir, runtime_include, runtime_test)
"""

import pathlib
import re
import subprocess
import sys

# Ligne de copy-in d'une VAR_IN_OUT : s.FB.X = s.Y;
COPYIN_RE = re.compile(
    r"^\s*s\.(?P<fb>\w+)\.(?P<param>\w+)\s*=\s*s\.(?P<var>\w+);\s*$"
)


def extract_var_in_out_names(fb_st_text: str) -> set:
    """Extrait les noms (MAJUSCULES, comme dans le C++ généré) des VAR_IN_OUT
    depuis l'interface déclarée du FB (.st). Retourne un set vide si aucun bloc."""
    m = re.search(r"\bVAR_IN_OUT\b(.*?)\bEND_VAR\b", fb_st_text, re.DOTALL | re.IGNORECASE)
    if not m:
        return set()
    body = m.group(1)
    names = set()
    for dm in re.finditer(
        r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*(?:AT\s*%[IQM][\w.]*)?\s*:",
        body,
        re.MULTILINE,
    ):
        names.add(dm.group(1).upper())
    return names


def inject_copyout(test_main_text: str, var_in_out_names: set, fb_var: str = "FB") -> str:
    """Injecte s.Y = s.FB.X; après chaque s.FB(); pour chaque VAR_IN_OUT X dont
    le copy-in s.FB.X = s.Y; précède l'appel. Retourne le texte modifié."""
    if not var_in_out_names:
        return test_main_text
    lines = test_main_text.splitlines(keepends=True)
    out = []
    pending = {}  # param -> test_var
    for line in lines:
        out.append(line)
        stripped = line.strip()
        m = COPYIN_RE.match(stripped)
        if m and m.group("fb") == fb_var and m.group("param") in var_in_out_names:
            pending[m.group("param")] = m.group("var")
            continue
        if stripped == f"s.{fb_var}();":
            continue
        if stripped == f"s.{fb_var}.ENO = true;":
            if pending:
                indent = line[: len(line) - len(line.lstrip())]
                for param, var in pending.items():
                    out.append(f"{indent}s.{var} = s.{fb_var}.{param};\n")
                pending = {}
            continue
    return "".join(out)


def postprocess_file(test_main_path: pathlib.Path, fb_st_path: pathlib.Path,
                     fb_var: str = "FB") -> bool:
    """Lit test_main.cpp, injecte le copy-out des VAR_IN_OUT du FB, réécrit le
    fichier en place. Retourne True si le fichier a été modifié, False sinon
    (aucune VAR_IN_OUT, ou aucune ligne de copy-in trouvée)."""
    fb_st_text = fb_st_path.read_text(encoding="utf-8", errors="replace")
    var_in_out = extract_var_in_out_names(fb_st_text)
    text = test_main_path.read_text(encoding="utf-8", errors="replace")
    modified = inject_copyout(text, var_in_out, fb_var=fb_var)
    if modified != text:
        test_main_path.write_text(modified, encoding="utf-8")
        return True
    return False


def recompile_test_runner(temp_dir: pathlib.Path, runtime_include: pathlib.Path,
                          runtime_test: pathlib.Path) -> pathlib.Path | None:
    """Recompile test_main.cpp + generated.cpp en test_runner_copyout.exe (g++).
    Retourne le chemin de l'exe recompilé, ou None si la compilation échoue
    (l'appelant retombe alors sur le test_runner.exe original de STruCpp)."""
    exe = temp_dir / "test_runner_copyout.exe"
    compile_cmd = [
        "g++", "-std=c++17", "-O0",
        f"-I{runtime_include}", f"-I{runtime_test}", f"-I{temp_dir}",
        str(temp_dir / "test_main.cpp"), str(temp_dir / "generated.cpp"),
        "-o", str(exe),
    ]
    subproc_flags = subprocess.BELOW_NORMAL_PRIORITY_CLASS if sys.platform == "win32" else 0
    result = subprocess.run(compile_cmd, capture_output=True, text=True, encoding="utf-8",
                            cwd=str(temp_dir), creationflags=subproc_flags)
    if result.returncode != 0:
        return None
    return exe
