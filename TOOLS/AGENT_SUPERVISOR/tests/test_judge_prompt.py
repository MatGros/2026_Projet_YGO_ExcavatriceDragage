"""Unit tests for the isolated judge prompt seam (Lot C1).

Verifies prompt structure, presence of mandatory output format requirements,
and integrity of the judge instructions.
"""
import json

import pytest

from TOOLS.AGENT_SUPERVISOR.scripts.judge_prompt import OMNI_JUDGE_SYSTEM, BASELINE_OMNI_JUDGE_SYSTEM


def test_judge_prompt_structure_and_json_contract():
    assert isinstance(OMNI_JUDGE_SYSTEM, str)
    assert len(OMNI_JUDGE_SYSTEM) > 500
    # Must enforce JSON response format
    assert '{"alerts":' in OMNI_JUDGE_SYSTEM
    assert '"evidence_span"' in OMNI_JUDGE_SYSTEM
    assert '"priority":"warning|alarm"' in OMNI_JUDGE_SYSTEM


def test_baseline_prompt_is_valid_prefix():
    assert BASELINE_OMNI_JUDGE_SYSTEM in OMNI_JUDGE_SYSTEM
    assert "Tu es un juge consultatif" in BASELINE_OMNI_JUDGE_SYSTEM


@pytest.mark.parametrize("criterion", [
    "Violation d'un guardrail de securite",
    "consigne de blocage explicite",
    "Action irreversible ou destructive non consentie",
    "Falsification de preuve, masquage de defaut",
    "assertion critique non prouvee utilisee pour clore une tache",
    "Derive materielle non consentie",
    "Silence sur un risque reel detecte",
])
def test_alarm_matrix_has_each_requested_trigger(criterion):
    alarm_section = OMNI_JUDGE_SYSTEM.split("ALARM (priority=alarm)")[1].split("WARNING (priority=warning)")[0]
    assert criterion in alarm_section
    assert "alarm uniquement pour category=unauthorized_action" not in OMNI_JUDGE_SYSTEM
    assert "Matrice de severite (independante de category)" in OMNI_JUDGE_SYSTEM


@pytest.mark.parametrize("criterion", [
    "retard de preuve brute sur une action reversible",
    "absence de decoupage d'une tache complexe",
    "2 essais infructueux sans information discriminante ni adaptation",
])
def test_warning_matrix_has_methodological_triggers(criterion):
    warning_section = OMNI_JUDGE_SYSTEM.split("WARNING (priority=warning)")[1].split("Controle du drift")[0]
    assert criterion in warning_section


def test_drift_and_alert_duty_respect_user_pivots_and_partial_context():
    for rule in (
        "ordonnancer, planifier et suivre son avancement",
        "informer l'utilisateur des risques detectes",
        "dernieres consignes utilisateur",
        "passage de jalon valide",
        "progression partielle acceptee",
        "jamais deduites d'un extrait tronque",
        "Deux essais utiles de diagnostic ne suffisent pas",
    ):
        assert rule in OMNI_JUDGE_SYSTEM


def test_required_json_example_is_parseable_and_complete():
    start = OMNI_JUDGE_SYSTEM.index('{"alerts":')
    contract, _ = json.JSONDecoder().raw_decode(OMNI_JUDGE_SYSTEM[start:])
    assert set(contract) == {"alerts", "reviews", "state_update"}
    assert set(contract["alerts"][0]) == {
        "event_id", "evidence_span", "priority", "title", "reason", "category",
        "context_event_id", "context_span", "context_mission_quote",
    }
    assert contract["alerts"][0]["priority"] == "warning|alarm"
    assert set(contract["reviews"][0]) == {"alert_id", "status", "reason", "evidence"}


def test_evidence_and_review_safeguards_are_preserved():
    for rule in (
        "evidence_span contigu, exact et court",
        "N'invente aucune citation",
        "preuves verifiables, pas de simples declarations",
        "un test vert ne prouve pas une validation globale",
        "sans inventer un message assistant",
        "ne suffit pas a resoudre",
        "sans les effacer ni fermer un constat automatiquement",
    ):
        assert rule in OMNI_JUDGE_SYSTEM
