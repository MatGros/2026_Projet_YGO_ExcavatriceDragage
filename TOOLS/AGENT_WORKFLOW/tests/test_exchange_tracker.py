"""Outillage des conventions d echange T427 v0.3 (lot 3).

Couvre les 4 parades du cycle 2 : identifiant canonique, echeance effective,
clause de silence (RECU sans reponse), journal par emetteur sans ecriture
concurrente ni trou silencieux.
"""
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import exchange_tracker as ex  # noqa: E402


def _consigne(**extra):
    base = {"kind": "consigne", "from": "T427-CC02", "to": "T000-CC10", "task": "T427",
            "objet": "verrou", "demande": "prendre le verrou", "preuve": "chemin cite",
            "echeance": "2026-11-16T10:00+01:00", "ref": "27b657"}
    base.update(extra)
    return base


# --- identifiant canonique (UC-11) ------------------------------------------------------

def test_id_canonique_stable_et_sensible_au_contenu() -> None:
    a = ex.canonical_id(_consigne())
    b = ex.canonical_id(_consigne())
    c = ex.canonical_id(_consigne(objet="autre objet"))
    assert a == b, "meme consigne = meme id (idempotence)"
    assert a != c, "un champ different = un id different"


# --- journal par emetteur ---------------------------------------------------------------

def test_sequence_propre_a_chaque_emetteur(tmp_path) -> None:
    a1 = ex.append(_consigne(), root=tmp_path, at="2026-11-15T10:00:00+01:00")
    a2 = ex.append(_consigne(objet="second"), root=tmp_path, at="2026-11-15T10:01:00+01:00")
    b1 = ex.append(_consigne(**{"from": "T429-MMX01"}), root=tmp_path,
                   at="2026-11-15T10:02:00+01:00")
    assert (a1["seq"], a2["seq"], b1["seq"]) == (1, 2, 1), "chaque emetteur a sa numerotation"


def test_trous_de_sequence_detectes(tmp_path) -> None:
    ex.append(_consigne(), root=tmp_path, at="2026-11-15T10:00:00+01:00")
    ex.append(_consigne(objet="deux"), root=tmp_path, at="2026-11-15T10:01:00+01:00")
    path = ex.emitter_path("T427", "T427-CC02", tmp_path)
    lignes = path.read_text(encoding="utf-8").splitlines()
    path.write_text("\n".join([lignes[0], lignes[1].replace('"seq": 2', '"seq": 3')]) + "\n",
                    encoding="utf-8")
    assert ex.gaps("T427", tmp_path) == {"T427-CC02": [2]}, "un trou de sequence est signale"


def test_kind_inconnu_refuse(tmp_path) -> None:
    with pytest.raises(ValueError):
        ex.append(_consigne(kind="blabla"), root=tmp_path)


def test_champs_obligatoires(tmp_path) -> None:
    with pytest.raises(ValueError):
        ex.append({"kind": "consigne", "from": "T427-CC02"}, root=tmp_path)


# --- echeance effective (correction du cycle 2) -----------------------------------------

def test_echeance_effective_prend_la_promesse_du_recu() -> None:
    thread = {"consigne": {"echeance": "2026-11-16T10:00+01:00"},
              "recu": {"when": "2026-11-16T12:00+01:00"}}
    assert ex.effective_deadline(thread) == "2026-11-16T12:00+01:00"


def test_echeance_effective_sans_recu_garde_la_consigne() -> None:
    thread = {"consigne": {"echeance": "2026-11-16T10:00+01:00"}, "recu": None}
    assert ex.effective_deadline(thread) == "2026-11-16T10:00+01:00"


# --- clause de silence ------------------------------------------------------------------

def test_sans_accuse_et_echeance_passee_est_en_retard(tmp_path) -> None:
    ex.append(_consigne(), root=tmp_path, at="2026-11-15T10:00:00+01:00")
    late = ex.overdue("T427", "2026-11-16T11:00:00+01:00", root=tmp_path)
    assert len(late) == 1 and late[0]["recu"] is False


def test_recu_sans_reponse_compte_comme_un_silence(tmp_path) -> None:
    consigne = ex.append(_consigne(), root=tmp_path, at="2026-11-15T10:00:00+01:00")
    ex.append({"kind": "recu", "from": "T000-CC10", "task": "T427", "id": consigne["id"],
               "when": "2026-11-15T14:00:00+01:00"}, root=tmp_path, at="2026-11-15T11:00:00+01:00")
    late = ex.overdue("T427", "2026-11-15T15:00:00+01:00", root=tmp_path)
    assert len(late) == 1, "le RECU seul ne cloture rien"
    assert late[0]["recu"] is True


def test_promesse_plus_tardive_ne_met_pas_en_retard(tmp_path) -> None:
    consigne = ex.append(_consigne(), root=tmp_path, at="2026-11-15T10:00:00+01:00")
    ex.append({"kind": "recu", "from": "T000-CC10", "task": "T427", "id": consigne["id"],
               "when": "2026-11-20T10:00:00+01:00"}, root=tmp_path, at="2026-11-15T11:00:00+01:00")
    assert ex.overdue("T427", "2026-11-16T11:00:00+01:00", root=tmp_path) == []


def test_reponse_cloture_l_echange(tmp_path) -> None:
    consigne = ex.append(_consigne(), root=tmp_path, at="2026-11-15T10:00:00+01:00")
    ex.append({"kind": "reponse", "from": "T000-CC10", "task": "T427", "id": consigne["id"],
               "preuve": "sortie de commande"}, root=tmp_path, at="2026-11-15T11:00:00+01:00")
    assert ex.overdue("T427", "2026-12-31T00:00:00+01:00", root=tmp_path) == []


def test_date_invalide_refusee(tmp_path) -> None:
    with pytest.raises(ValueError):
        ex.overdue("T427", "demain matin", root=tmp_path)


# --- CLI --------------------------------------------------------------------------------

def test_cli_send_puis_list(tmp_path, capsys, monkeypatch) -> None:
    monkeypatch.setattr(ex, "ROOT", tmp_path)
    code = ex.main(["send", "--from", "T427-CC02", "--to", "T000-CC10", "--task", "T427",
                    "--objet", "verrou", "--demande", "prendre", "--preuve", "chemin",
                    "--echeance", "2026-11-16T10:00+01:00", "--ref", "27b657"])
    assert code == 0
    assert "CONSIGNE id=" in capsys.readouterr().out
    ex.main(["list", "--task", "T427"])
    assert "echanges=1" in capsys.readouterr().out
