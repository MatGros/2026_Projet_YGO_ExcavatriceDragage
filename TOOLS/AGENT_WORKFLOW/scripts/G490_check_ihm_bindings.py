#!/usr/bin/env python3
"""G490 — Vérification mécanique des liaisons IHM dans le code ST.

Rôle
----
Analyse le code ST (`CODE/**/*.st`) et vérifie mécaniquement, pour chaque champ
de `GVL_IHM` (et des structures IHM associées), le triplet producteur /
consommateur / exposition. C'est un **gate répétable** : les résultats sont
déterministes, exécutables à tout moment, sans dépendre d'un export CODESYS.

Ce que le script détecte
------------------------
* **Liaison cassée** (ERROR)   : champ consommé (lu) mais jamais produit (écrit).
* **Code mort** (WARNING)      : champ produit mais jamais consommé dans le ST.
  ⚠️ L'exposition IHM (binding dans la visualisation CODESYS) n'est PAS
  vérifiable depuis le code ST : un champ produit-non-consommé est donc un
  *candidat* code mort — à confirmer humainement côté binding IHM.
* **Doublon producteur** (WARNING) : champ écrit par 2+ affectations feuilles
  distinctes (2 producteurs pour la même donnée).
* **Doublon exposition** (WARNING) : 2+ champs GVL_IHM alimentés depuis la même
  source externe (même info exposée en double dans 2 structures IHM).
* **Référence inconnue** (ERROR) : référence `GVL_IHM.<chemin>` vers un champ
  qui n'existe pas dans l'arbre de types (typo / champ supprimé).

Usage
-----
    python TOOLS/AGENT_WORKFLOW/scripts/G490_check_ihm_bindings.py
    python TOOLS/AGENT_WORKFLOW/scripts/G490_check_ihm_bindings.py --only-errors
    python TOOLS/AGENT_WORKFLOW/scripts/G490_check_ihm_bindings.py --verbose
    python TOOLS/AGENT_WORKFLOW/scripts/G490_check_ihm_bindings.py --root <chemin>

Code de sortie
--------------
0 si aucun constat ; non-zéro si au moins un constat (liaison cassée, code mort,
doublon, référence inconnue). `--only-errors` ne fait échouer que sur les ERROR.

Périmètre
---------
Lecture seule de `CODE/`. Aucune modification, aucun commit.
"""

from __future__ import annotations

import argparse
import re
import sys
from collections import defaultdict
from pathlib import Path

# ---------------------------------------------------------------------------
# 1. Nettoyage des commentaires (préserve les numéros de ligne)
# ---------------------------------------------------------------------------

def _blank_keep_newlines(match: re.Match) -> str:
    return re.sub(r"[^\n]", " ", match.group(0))


def strip_comments(text: str) -> str:
    """Retire les commentaires ST `(* ... *)` et `// ...` en préservant les
    numéros de ligne (les caractères sont remplacés par des espaces)."""
    text = re.sub(r"\(\*.*?\*\)", _blank_keep_newlines, text, flags=re.DOTALL)
    text = re.sub(r"//[^\n]*", _blank_keep_newlines, text)
    return text


# ---------------------------------------------------------------------------
# 2. Registre des types STRUCT
# ---------------------------------------------------------------------------

def build_type_registry(files: list[Path]) -> dict[str, dict[str, str]]:
    """Construit {nom_type: {champ: type}} pour tous les `TYPE X : STRUCT`."""
    registry: dict[str, dict[str, str]] = {}
    for path in files:
        text = strip_comments(path.read_text(encoding="utf-8", errors="replace"))
        for m in re.finditer(
            r"TYPE\s+(\w+)\s*:\s*STRUCT\b(.*?)END_STRUCT\s*END_TYPE",
            text,
            flags=re.DOTALL,
        ):
            name = m.group(1)
            body = m.group(2)
            fields: dict[str, str] = {}
            for fm in re.finditer(r"^\s*(\w+)\s*:\s*([^;]+?)\s*;", body, flags=re.MULTILINE):
                fields[fm.group(1)] = fm.group(2).strip()
            if name in registry:
                print(f"[WARNING] Type STRUCT duplique, premier gagnant : {name} ({path.name})")
            else:
                registry[name] = fields
    return registry


# ---------------------------------------------------------------------------
# 3. Variables globales GVL_IHM
# ---------------------------------------------------------------------------

def parse_gvl_ihm(path: Path) -> dict[str, str]:
    """Extrait les variables `VAR_GLOBAL` de GVL_IHM : {nom: type}."""
    text = strip_comments(path.read_text(encoding="utf-8", errors="replace"))
    m = re.search(r"VAR_GLOBAL(.*?)END_VAR", text, flags=re.DOTALL)
    if not m:
        return {}
    vars_: dict[str, str] = {}
    for fm in re.finditer(r"^\s*(\w+)\s*:\s*([^;]+?)\s*;", m.group(1), flags=re.MULTILINE):
        vars_[fm.group(1)] = fm.group(2).strip()
    return vars_


# ---------------------------------------------------------------------------
# 4. Expansion de l'arbre de champs en feuilles
# ---------------------------------------------------------------------------

def expand_leaves(type_name: str, path: str, registry: dict) -> list[str]:
    """Déplie un type STRUCT en chemins de feuilles `GVL_IHM.<var>.<champ>...`."""
    if type_name in registry:
        leaves: list[str] = []
        for fname, ftype in registry[type_name].items():
            leaves.extend(expand_leaves(ftype, f"{path}.{fname}", registry))
        return leaves
    return [path]


# ---------------------------------------------------------------------------
# 5. Analyse des références GVL_IHM dans le code
# ---------------------------------------------------------------------------

REF_RE = re.compile(r"GVL_IHM\.[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*")


def resolve_to_leaves(ref_path: str, gvl_vars: dict, registry: dict) -> list[str] | None:
    """Résout un chemin `GVL_IHM.A.B.C` en feuilles. None si racine inconnue."""
    parts = ref_path.split(".")
    if len(parts) < 2 or parts[0] != "GVL_IHM":
        return None
    var_name = parts[1]
    if var_name not in gvl_vars:
        return None
    type_name = gvl_vars[var_name]
    # Marche dans l'arbre de types
    for seg in parts[2:]:
        if type_name not in registry or seg not in registry[type_name]:
            return None  # chemin inconnu (champ inexistant)
        type_name = registry[type_name][seg]
    return expand_leaves(type_name, ".".join(parts), registry)


def analyze(root: Path):
    code_dir = root / "CODE"
    if not code_dir.is_dir():
        print("ERREUR : dossier CODE/ introuvable sous", root)
        sys.exit(2)
    st_files = sorted(code_dir.rglob("*.st"))
    registry = build_type_registry(st_files)

    gvl_path = code_dir / "J_SUPERVISION" / "GVL_IHM.st"
    if not gvl_path.exists():
        # recherche générique
        cands = [p for p in st_files if p.name == "GVL_IHM.st"]
        gvl_path = cands[0] if cands else None
    if gvl_path is None:
        print("ERREUR : GVL_IHM.st introuvable.")
        sys.exit(2)
    gvl_vars = parse_gvl_ihm(gvl_path)

    # Toutes les feuilles GVL_IHM déclarées
    all_leaves: set[str] = set()
    for var_name, type_name in gvl_vars.items():
        all_leaves.update(expand_leaves(type_name, f"GVL_IHM.{var_name}", registry))

    # Références : feuille -> {(fichier, ligne)}
    producers: dict[str, set] = defaultdict(set)          # toute écriture (struct ou feuille)
    individual_producers: dict[str, set] = defaultdict(set)  # écritures feuille uniquement
    consumers: dict[str, set] = defaultdict(set)
    unknown_refs: list[tuple[str, str, int]] = []          # (chemin, fichier, ligne)
    # RHS par écriture feuille : feuille -> liste de (source_normalisée, fichier, ligne)
    write_rhs: dict[str, list[tuple[str, str, int]]] = defaultdict(list)
    raw_refs = 0

    for path in st_files:
        text = strip_comments(path.read_text(encoding="utf-8", errors="replace"))
        # index de début de ligne pour mapper position -> numéro de ligne
        line_starts = [0]
        for i, ch in enumerate(text):
            if ch == "\n":
                line_starts.append(i + 1)
        line_starts.append(len(text) + 1)

        def line_of(pos: int) -> int:
            lo, hi = 0, len(line_starts) - 1
            while lo < hi:
                mid = (lo + hi + 1) // 2
                if line_starts[mid] <= pos:
                    lo = mid
                else:
                    hi = mid - 1
            return lo + 1

        for m in REF_RE.finditer(text):
            ref = m.group(0)
            raw_refs += 1
            rel = str(path.relative_to(root))
            # écriture si suivi de `:=`
            after = text[m.end():]
            is_write = bool(re.match(r"\s*:=", after))
            leaves = resolve_to_leaves(ref, gvl_vars, registry)
            if leaves is None:
                unknown_refs.append((ref, rel, line_of(m.start())))
                continue
            loc = (rel, line_of(m.start()))
            if is_write:
                for leaf in leaves:
                    producers[leaf].add(loc)
                # RHS pour détection doublon exposition (écritures feuille)
                if len(leaves) == 1:
                    rhs = _extract_rhs(text, m.end())
                    write_rhs[leaves[0]].append((rhs, rel, line_of(m.start())))
                    individual_producers[leaves[0]].add(loc)
            else:
                for leaf in leaves:
                    consumers[leaf].add(loc)

    return {
        "registry": registry,
        "gvl_vars": gvl_vars,
        "all_leaves": all_leaves,
        "producers": producers,
        "individual_producers": individual_producers,
        "consumers": consumers,
        "unknown_refs": unknown_refs,
        "write_rhs": write_rhs,
        "raw_refs": raw_refs,
    }


def _extract_rhs(text: str, pos: int) -> str:
    """Extrait l'expression source après `:=` jusqu'au prochain `;`."""
    m = re.search(r":=", text[pos:])
    if not m:
        return ""
    start = pos + m.end()
    end = text.find(";", start)
    if end == -1:
        end = len(text)
    return re.sub(r"\s+", " ", text[start:end]).strip()


# ---------------------------------------------------------------------------
# 6. Constats
# ---------------------------------------------------------------------------

# Champs écrits par l'IHM (IHM -> PLC) : boutons, consignes, bypass, config.
# Le producteur n'est PAS dans le ST (c'est l'opérateur via la visualisation).
# Un tel champ "consommé mais jamais produit dans le ST" est NORMAL.
_IHM_INPUT_SUB = (".Cmd.", ".Cfg.", ".Bypass.", ".EncoderCfg.")
_IHM_INPUT_PREFIX = ("Btn", "Tgl", "Sel", "Calibrate")
_PLC_OUTPUT_SUB = (".State.", ".Safety.")


def is_ihm_input(leaf: str) -> bool:
    """True si le champ est une entrée IHM (produit par l'IHM, pas par le ST).

    Règles :
      * sous-structure Cmd / Cfg / Bypass / EncoderCfg -> entrée IHM
        (EncoderCfg est écrit par FB_CfgPersistBridge, producteur hors `:=`).
      * champ préfixé Btn/Tgl/Sel/Calibrate (bouton/consigne opérateur), SAUF
        sous State/Safety (sorties PLC) -> entrée IHM.
      * GVL_IHM.HmiInitDone -> entrée IHM (flag posé par l'IHM après init).
    """
    if any(sub in leaf for sub in _IHM_INPUT_SUB):
        return True
    parts = leaf.split(".")
    field = parts[-1]
    if field.startswith(_IHM_INPUT_PREFIX) and not any(s in leaf for s in _PLC_OUTPUT_SUB):
        return True
    if len(parts) == 2 and parts[1] == "HmiInitDone":
        return True
    return False


def compute_findings(data) -> dict:
    findings = {
        "broken": [],        # liaison cassée (ERROR)
        "dead": [],          # code mort (WARNING)
        "dead_input": [],    # entrée IHM jamais consommée (WARNING)
        "dup_prod": [],      # doublon producteur (WARNING)
        "dup_exp": [],       # doublon exposition (WARNING)
        "unknown": [],       # référence inconnue (ERROR)
    }
    leaves = data["all_leaves"]
    producers = data["producers"]
    consumers = data["consumers"]
    individual = data["individual_producers"]
    write_rhs = data["write_rhs"]

    for leaf in sorted(leaves):
        prod = producers.get(leaf, set())
        cons = consumers.get(leaf, set())
        if is_ihm_input(leaf):
            # Entrée IHM : le producteur est l'IHM. "Consommé jamais produit" = normal.
            # Code mort = bouton/consigne jamais lu par le ST (ne fait rien).
            if cons and not prod:
                pass  # normal (produit par l'IHM)
            elif not cons:
                findings["dead_input"].append((leaf, sorted(prod)))
        else:
            # Sortie PLC : le producteur est le ST.
            if cons and not prod:
                findings["broken"].append((leaf, sorted(cons)))
            elif prod and not cons:
                findings["dead"].append((leaf, sorted(prod)))
        if len(individual.get(leaf, set())) > 1:
            # Doublon producteur : 2+ écritures feuille dans des FICHIERS différents
            # (2 producteurs distincts). Les multi-écritures dans le même fichier
            # (set/clear dans des branches) sont un pattern légitime, non signalé.
            files = {f for f, _ in individual[leaf]}
            if len(files) > 1:
                findings["dup_prod"].append((leaf, sorted(individual[leaf])))

    # Doublon exposition : même source externe (non GVL_IHM, non constante) -> 2+ feuilles
    _CONST_RE = re.compile(r"^(TRUE|FALSE|0|1|[-+]?\d+(\.\d+)?)$", re.IGNORECASE)
    by_source: dict[str, list[tuple[str, str, int]]] = defaultdict(list)
    for leaf, entries in write_rhs.items():
        for rhs, rel, line in entries:
            if not rhs or "GVL_IHM." in rhs or _CONST_RE.match(rhs):
                continue  # source vide, miroir interne (sync) ou constante
            by_source[rhs].append((leaf, rel, line))
    for rhs, entries in sorted(by_source.items()):
        if len(entries) > 1:
            findings["dup_exp"].append((rhs, sorted(entries)))

    findings["unknown"] = sorted(data["unknown_refs"])
    return findings


# ---------------------------------------------------------------------------
# 7. Rapport
# ---------------------------------------------------------------------------

def _fmt_locs(locs) -> str:
    return ", ".join(f"{f}:{l}" for f, l in locs)


def render(data, findings, verbose: bool, only_errors: bool) -> int:
    n_leaves = len(data["all_leaves"])
    n_prod = sum(len(v) for v in data["producers"].values())
    n_cons = sum(len(v) for v in data["consumers"].values())

    print("=" * 78)
    print("G490 - RAPPORT LIAISONS IHM (GVL_IHM)")
    print("=" * 78)
    print(f"Champs GVL_IHM (feuilles) : {n_leaves}")
    print(f"References GVL_IHM brutes : {data['raw_refs']}")
    print(f"  (ecritures feuilles {n_prod}, lectures feuilles {n_cons})")
    print("Exposition IHM : non verifiable depuis le ST (binding visualisation CODESYS).")
    print("  -> 'code mort' = candidat : champ produit mais jamais lu dans le ST.")
    print()

    errors = 0
    warnings = 0

    def section(title, items, severity):
        nonlocal errors, warnings
        if not items:
            return
        print(f"--- {title} [{severity}] ({len(items)}) ---")
        for it in items:
            if severity == "ERROR":
                errors += 1
            else:
                warnings += 1
        for it in items:
            print(f"  • {it}")
        print()

    section("LIAISONS CASSEES (sortie PLC consommee jamais produite)", findings["broken"], "ERROR")
    section("REFERENCES INCONNUES (champ inexistant)", findings["unknown"], "ERROR")
    section("CODE MORT (sortie PLC produite jamais consommee)", findings["dead"], "WARNING")
    section("ENTREES IHM JAMAIS CONSOMMEES (bouton/consigne inerte)", findings["dead_input"], "WARNING")
    section("DOUBLONS PRODUCTEUR (2+ ecritures feuille)", findings["dup_prod"], "WARNING")
    section("DOUBLONS EXPOSITION (meme source externe)", findings["dup_exp"], "WARNING")

    if verbose:
        print("--- DETAIL TOUS CHAMPS (verbose) ---")
        print(f"{'champ':<60} {'dir':<4} {'prod':<4} {'cons':<4} {'expose':<6} statut")
        for leaf in sorted(data["all_leaves"]):
            prod = data["producers"].get(leaf, set())
            cons = data["consumers"].get(leaf, set())
            direction = "IHM->PLC" if is_ihm_input(leaf) else "PLC->IHM"
            if is_ihm_input(leaf):
                if cons:
                    status = "OK (entree IHM consommee)"
                else:
                    status = "ENTREE IHM INERTE"
            else:
                if prod and cons:
                    status = "OK"
                elif cons and not prod:
                    status = "LIAISON CASSEE"
                elif prod and not cons:
                    status = "CODE MORT (candidat)"
                else:
                    status = "non produit (IHM->PLC ?)"
            print(f"{leaf:<60} {direction:<8} {len(prod):<4} {len(cons):<4} {'?':<6} {status}")
        print()

    print("-" * 78)
    print(f"Resume : {errors} erreur(s), {warnings} avertissement(s)")
    if only_errors:
        code = 1 if errors else 0
    else:
        code = 1 if (errors or warnings) else 0
    print(f"Code de sortie : {code}")
    return code


# ---------------------------------------------------------------------------
# 8. Main
# ---------------------------------------------------------------------------

def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Vérifie les liaisons IHM dans le code ST.")
    ap.add_argument("--root", default=".", help="Racine du projet (défaut: .)")
    ap.add_argument("--only-errors", action="store_true",
                    help="Ne faire échouer que sur les ERROR (liaison cassée / réf. inconnue).")
    ap.add_argument("--verbose", action="store_true", help="Afficher le détail de tous les champs.")
    args = ap.parse_args(argv)

    root = Path(args.root).resolve()
    data = analyze(root)
    findings = compute_findings(data)
    return render(data, findings, args.verbose, args.only_errors)


if __name__ == "__main__":
    sys.exit(main())
