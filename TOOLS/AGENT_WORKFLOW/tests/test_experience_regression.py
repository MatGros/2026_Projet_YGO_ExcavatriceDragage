"""Garde-fou : une derive reelle doit produire une entree d'experience citable
(pattern citant l'extrait decisif + action non vide).

Scenario reel : session T427-CC02 (2026-11-13). L'agent annonce le lancement de deux
experts, l'appel n'est jamais emis (nom de fichier en double), l'agent relance sans
que la machine le voie. Derive = annonce d'action sans retour d'outil.
Deterministe : aucun modele, aucun reseau.

Test ecrit par le juge A/B du 2026-11-13 (depose tel quel).
"""
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO))
sys.path.insert(0, str(REPO / "TOOLS" / "AGENT_WORKFLOW" / "scripts"))

import experience_log  # noqa: E402
from TOOLS.AGENT_SUPERVISOR.scripts import supervisor_service  # noqa: E402

# --- la fenetre reelle de la session T427-CC02 ---------------------------------
FENETRE = [
    {"role": "agent", "text": "Je lance deux experts en skills et en conception de workflow, "
                              "sur la version actuelle. Avec ces deux appels, on atteint la limite de 20 par session."},
    {"role": "agent", "text": "<total_tokens>14996880 tokens left</total_tokens>"},
    {"role": "agent", "text": "Le nom du fichier avait un `.md` en double, les appels n'ont donc pas "
                              "été envoyés. Je relance avec le bon nom."},
    {"role": "user", "text": "/reload-plugins — Reloaded: 8 plugins · 59 skills · 10 agents"},
    {"role": "agent", "text": "Tu as raison de vouloir des sources. Je lance trois agents de recherche."},
]
EXTRAIT_DECISIF = "`.md` en double"  # la phrase qui prouve que l'appel n'est jamais parti
SESSION = {"id": "T427-CC02", "alias": "T427", "context": FENETRE}
ALERT = {"id": "alrt-md-double-01",
         "reason": "annonce d'experts sans retour d'outil : l'appel n'a pas ete emis, l'agent "
                   "relance sans que l'echec soit remonte",
         "evidence": "Le nom du fichier avait un `.md` en double, les appels n'ont donc pas ete envoyes",
         "category": "unsupported_success",
         "evidence_provenance": {"event_id": "ev-0007"}}


def test_une_derive_reelle_produit_une_entree_citable(tmp_path, monkeypatch):
    monkeypatch.setattr(experience_log, "EXPERIENCE_DIR", tmp_path)
    monkeypatch.setattr(experience_log, "post_path", lambda _p: tmp_path / "poste.jsonl")
    monkeypatch.setattr(experience_log, "session_path", lambda _s: tmp_path / "session.jsonl")
    monkeypatch.setattr(experience_log, "all_log", lambda: tmp_path / "all.jsonl")

    pattern = supervisor_service._experience_pattern(SESSION, ALERT)
    supervisor_service._experience_write(SESSION, ALERT, pattern)

    entrees = experience_log.read("T427-CC02", limit=10)
    assert len(entrees) == 1, "la derive doit produire UNE entree d'experience"
    entree = entrees[0]
    assert (entree["poste"], entree["type"], entree["session_id"]) == ("superviseur", "constat", "T427-CC02")

    # 1. le pattern cite l'extrait decisif (la phrase qui prouve la derive)
    assert EXTRAIT_DECISIF in entree["pattern"], f"extrait decisif absent : {entree['pattern']!r}"

    # 2. le pattern preserve l'enchainement des roles
    for role in ("agent:", "user:"):
        assert role in entree["pattern"], f"chainage des roles perdu : {entree['pattern']!r}"

    # 3. une action non vide : sans elle, la revue periodique n'a rien a transformer
    assert entree["action"].strip(), "action vide : l'entree ne peut pas devenir une contre-mesure de revue"

    # 4. l'entree est ancrable (constat + evenement source)
    assert "alrt-md-double-01" in entree["refs"] and "ev-0007" in entree["refs"]
