"""Registre des GO (T427, constat de revue n°2).

Un GO verbal se perd. Ce registre est append-only et refuse tout GO non
rattachable a un message identifie : c'est ce qui distingue un GO trace d'un
souvenir.
"""
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import go_registry as reg  # noqa: E402


def _go(**extra):
    base = {"task": "T427", "emitter": "exploitant", "ref": "2026-11-15 04:20 GO P1",
            "perimetre": "garde de perimetre", "text": "GO P1"}
    base.update(extra)
    return base


def test_enregistrement_et_lecture(tmp_path) -> None:
    item = reg.record(_go(), root=tmp_path, at="2026-11-15T04:20:00+01:00")
    assert item["seq"] == 1
    assert reg.entries("T427", tmp_path)[0]["ref"] == "2026-11-15 04:20 GO P1"


def test_sequence_croissante_append_only(tmp_path) -> None:
    reg.record(_go(), root=tmp_path, at="2026-11-15T04:20:00+01:00")
    second = reg.record(_go(ref="2026-11-15 05:00 GO lot 2"), root=tmp_path,
                        at="2026-11-15T05:00:00+01:00")
    assert second["seq"] == 2
    assert len(reg.entries("T427", tmp_path)) == 2, "aucune entree remplacee"


def test_ref_obligatoire(tmp_path) -> None:
    with pytest.raises(ValueError):
        reg.record(_go(ref=""), root=tmp_path)


def test_champs_obligatoires(tmp_path) -> None:
    with pytest.raises(ValueError):
        reg.record({"task": "T427"}, root=tmp_path)


def test_recherche_par_reference(tmp_path) -> None:
    reg.record(_go(), root=tmp_path, at="2026-11-15T04:20:00+01:00")
    reg.record(_go(ref="2026-11-15 05:00 GO lot 2", perimetre="garde shell"),
               root=tmp_path, at="2026-11-15T05:00:00+01:00")
    assert len(reg.find("T427", "lot 2", tmp_path)) == 1
    assert len(reg.find("T427", "GO", tmp_path)) == 2
    assert reg.find("T427", "inexistant", tmp_path) == []


def test_registres_separes_par_tache(tmp_path) -> None:
    reg.record(_go(), root=tmp_path, at="2026-11-15T04:20:00+01:00")
    reg.record(_go(**{"task": "T429"}), root=tmp_path, at="2026-11-15T04:21:00+01:00")
    assert len(reg.entries("T427", tmp_path)) == 1
    assert len(reg.entries("T429", tmp_path)) == 1


def test_cli_add_puis_list(tmp_path, capsys, monkeypatch) -> None:
    monkeypatch.setattr(reg, "ROOT", tmp_path)
    code = reg.main(["add", "--task", "T427", "--emitter", "exploitant",
                     "--ref", "2026-11-15 04:20", "--perimetre", "P1", "--text", "GO P1"])
    assert code == 0
    assert "GO seq=1" in capsys.readouterr().out
    reg.main(["list", "--task", "T427"])
    assert "GO enregistres pour T427 : 1" in capsys.readouterr().out
