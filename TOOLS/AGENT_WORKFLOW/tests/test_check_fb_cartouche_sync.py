#!/usr/bin/env python3
"""Tests de check_fb_cartouche_sync.py (T089 AC1).

- mini-fixture : un FB `synced`, un `drift` (FB_CycleTime, pointeur -> chapo),
  un `no_pointer`, un `no_fiche` ;
- repo reel : FB_CycleTime DOIT ressortir `drift` (cas de reference AC1).
"""

from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

import pytest

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
REPO_ROOT = Path(__file__).resolve().parents[3]

spec = importlib.util.spec_from_file_location(
    "check_fb_cartouche_sync", SCRIPTS / "check_fb_cartouche_sync.py"
)
mod = importlib.util.module_from_spec(spec)
assert spec and spec.loader
spec.loader.exec_module(mod)


def _write(p: Path, text: str) -> None:
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text, encoding="utf-8")


CART_SYNCED = """(* =======================================================================
   ⚙️ FB_Synced — Brique de demonstration
   ------------------------------------------------
   \U0001F3AF Rôle : Faire une chose precise et bornee
   \U0001F4C4 Doc métier : DOC/AF/FB_Synced_v1.0.md
   ======================================================================= *)
FUNCTION_BLOCK PUBLIC FB_Synced
VAR_INPUT
    Enable : BOOL;
END_VAR
"""

FICHE_SYNCED = """# Fiche `FB_Synced` v1.0

## 1 · \U0001F3AF Rôle et profil

Rôle : **faire une chose precise et bornee** puis publier le resultat en secondes.

## 2 · Interface
rien
"""

CART_CYCLETIME = """(* =======================================================================
   ⚙️ FB_CycleTime — Mesure du temps de cycle reel de la tache
   ------------------------------------------------
   \U0001F3AF Rôle : Calcul du dt reel entre deux executions successives
   \U0001F4C4 Doc métier : DOC/AF/AF_Partie-03_Contrats_Composants_v9.9.md
   ======================================================================= *)
FUNCTION_BLOCK FB_CycleTime
VAR_INPUT
    DefaultValueS : REAL := 0.004;
END_VAR
"""

FICHE_CHAPO = """# Analyse Fonctionnelle — Partie 3 : Contrats Composants (v9.9)

## \U0001F3AF Rôle et perimetre

- **Rôle** : definir les contrats publics des FB, des DUT internes et des pages CFC.

## Autre section
rien
"""

CART_NO_POINTER = """(* =======================================================================
   \U0001F9CA FB_NoPointer — Brique sans pointeur doc
   ------------------------------------------------
   \U0001F3AF Rôle : Ne reference aucune fiche
   ======================================================================= *)
FUNCTION_BLOCK FB_NoPointer
VAR_INPUT
    X : BOOL;
END_VAR
"""

CART_NO_FICHE = """(* =======================================================================
   \U0001F4A6 FB_NoFiche — Pointeur casse
   ------------------------------------------------
   \U0001F3AF Rôle : Pointe une fiche absente
   \U0001F4C4 Doc métier : DOC/AF/CetteFicheNexistePas_v1.0.md
   ======================================================================= *)
FUNCTION_BLOCK FB_NoFiche
VAR_INPUT
    X : BOOL;
END_VAR
"""

REQUIRED_KEYS = {
    "file", "st_line", "pou_name", "emoji", "role", "doc_pointer",
    "doc_line", "fiche_existe", "nom_match", "role_match", "statut",
}


@pytest.fixture()
def fake_repo(tmp_path, monkeypatch):
    _write(tmp_path / "CODE" / "A_COMMUN" / "FB_Synced.st", CART_SYNCED)
    _write(tmp_path / "CODE" / "A_COMMUN" / "FB_CycleTime.st", CART_CYCLETIME)
    _write(tmp_path / "CODE" / "B_X" / "FB_NoPointer.st", CART_NO_POINTER)
    _write(tmp_path / "CODE" / "B_X" / "FB_NoFiche.st", CART_NO_FICHE)
    _write(tmp_path / "DOC" / "AF" / "FB_Synced_v1.0.md", FICHE_SYNCED)
    _write(tmp_path / "DOC" / "AF" / "AF_Partie-03_Contrats_Composants_v9.9.md", FICHE_CHAPO)

    out = tmp_path / "TOOLS" / "AGENT_WORKFLOW" / "config" / "fb_cartouche_sync.json"
    monkeypatch.setattr(mod, "REPO_ROOT", tmp_path)
    monkeypatch.setattr(mod, "OUT_PATH", out)
    rc = mod.main()
    assert rc == 0
    return json.loads(out.read_text(encoding="utf-8"))


def _by_name(payload, name):
    hits = [e for e in payload["fb"] if e["pou_name"] == name]
    assert len(hits) == 1, name
    return hits[0]


def test_payload_structure(fake_repo):
    assert set(fake_repo) >= {"generated_at", "source_head", "counts", "fb"}
    assert isinstance(fake_repo["fb"], list) and len(fake_repo["fb"]) == 4
    for e in fake_repo["fb"]:
        assert REQUIRED_KEYS <= set(e)
        assert e["statut"] in {"synced", "drift", "no_pointer", "no_fiche"}
    assert "T" in fake_repo["generated_at"]  # ISO 8601


def test_case_synced(fake_repo):
    e = _by_name(fake_repo, "FB_Synced")
    assert e["doc_pointer"] == "DOC/AF/FB_Synced_v1.0.md"
    assert e["fiche_existe"] is True
    assert e["nom_match"] is True
    assert e["role_match"] is True
    assert e["statut"] == "synced"


def test_case_drift_cycletime(fake_repo):
    e = _by_name(fake_repo, "FB_CycleTime")
    assert e["emoji"] == "⚙️"
    assert e["role"] == "Calcul du dt reel entre deux executions successives"
    assert e["fiche_existe"] is True
    assert e["nom_match"] is False   # H1 du chapo ne contient pas "FB_CycleTime"
    assert e["role_match"] is False
    assert e["statut"] == "drift"


def test_case_no_pointer(fake_repo):
    e = _by_name(fake_repo, "FB_NoPointer")
    assert e["doc_pointer"] is None
    assert e["statut"] == "no_pointer"
    assert e["fiche_existe"] is None


def test_case_no_fiche(fake_repo):
    e = _by_name(fake_repo, "FB_NoFiche")
    assert e["doc_pointer"] == "DOC/AF/CetteFicheNexistePas_v1.0.md"
    assert e["fiche_existe"] is False
    assert e["statut"] == "no_fiche"


def test_counts_consistent(fake_repo):
    c = fake_repo["counts"]
    assert c["synced"] == 1
    assert c["drift"] == 1
    assert c["no_pointer"] == 1
    assert c["no_fiche"] == 1
    assert sum(c.values()) == len(fake_repo["fb"])


@pytest.mark.skipif(
    not (REPO_ROOT / "CODE" / "A_COMMUN" / "FB_CycleTime.st").is_file(),
    reason="repo reel indisponible",
)
def test_real_repo_cycletime_is_synced(tmp_path, monkeypatch):
    """FB_CycleTime : cartouche corrige (T088) -> pointeur vers la sous-fiche dediee,
    nom + role verbatim -> statut synced (seul FB en synchronisation stricte du repo)."""
    out = tmp_path / "fb_cartouche_sync.json"
    monkeypatch.setattr(mod, "OUT_PATH", out)
    rc = mod.main()
    assert rc == 0
    payload = json.loads(out.read_text(encoding="utf-8"))
    e = _by_name(payload, "FB_CycleTime")
    assert e["doc_pointer"].endswith("AF_Partie-03_Contrats_Composants/FB_CycleTime_v1.0.md")
    assert e["statut"] == "synced"
    assert e["nom_match"] is True and e["role_match"] is True


def test_real_repo_has_covered_and_drift_buckets(tmp_path, monkeypatch):
    """Le relachement introduit le statut 'covered' (FB nomme dans un chapo de domaine)
    et reserve 'drift' aux vrais pointeurs suspects (fiche qui ne nomme jamais le FB)."""
    out = tmp_path / "fb_cartouche_sync.json"
    monkeypatch.setattr(mod, "OUT_PATH", out)
    assert mod.main() == 0
    payload = json.loads(out.read_text(encoding="utf-8"))
    statuts = {f["statut"] for f in payload["fb"]}
    assert "covered" in statuts
    covered = [f for f in payload["fb"] if f["statut"] == "covered"]
    assert covered and all(f["nom_in_body"] for f in covered)
    for f in payload["fb"]:
        if f["statut"] == "drift":
            assert f["fiche_existe"] and not f["nom_in_body"]


if __name__ == "__main__":
    sys.exit(pytest.main([__file__, "-v"]))
