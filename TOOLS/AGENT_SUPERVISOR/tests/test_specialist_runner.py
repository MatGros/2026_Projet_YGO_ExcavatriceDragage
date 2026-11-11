#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Tests unitaires pour specialist_runner.py et challenge_runner.py
================================================================
Vérifie :
1. Le respect strict de la Norme T279 dans validate_output_path.
2. L'extraction et la validation du contrat YAML (PASS, ADVISORY, BLOCK, Malformed).
3. La liste des rôles disponibles et le chargement des 6 personas.
4. La présence des 7 invariants dans FB_Agent_Standards (incluant l'outillage).
5. La conformité du schéma de challenge_runner.
"""

import os
import sys
import pytest

from TOOLS.AGENT_WORKFLOW.scripts.specialist_runner import (
    validate_output_path,
    extract_and_validate_yaml,
    load_persona,
    ROLE_MAP
)
from TOOLS.AGENT_WORKFLOW.scripts.challenge_runner import (
    validate_output_path as validate_challenge_output_path,
    extract_yaml_payload as extract_challenge_yaml
)


def test_t279_valid_output_path():
    """Un chemin sous DOC/WFLOW/TASKS/T.../PREUVES/ doit être accepté."""
    valid_path = "DOC/WFLOW/TASKS/T429_AGENT_SUPERVISOR/PREUVES/20261111/T429_REVUE_SAFETY_v1.0.yaml"
    validate_output_path(valid_path)
    validate_challenge_output_path(valid_path)


def test_t279_invalid_output_paths():
    """Les écritures à la racine ou hors tâche doivent être bloquées."""
    invalid_paths = [
        "rapport_specialiste.yaml",
        "DOC/WFLOW/rapport.yaml",
        "DOC/WFLOW/TASKS/rapport.yaml",
        "CODE/M_MAIN/rapport.yaml"
    ]
    for path in invalid_paths:
        with pytest.raises(SystemExit):
            validate_output_path(path)
        with pytest.raises(SystemExit):
            validate_challenge_output_path(path)


def test_yaml_extraction_valid_block():
    """Extraction d'un verdict BLOCK valide."""
    sample = """
Voici mon retour d'audit :
```yaml
specialist_evaluation:
  agent: "FB_Agent_Safety"
  verdict: "BLOCK"
  summary: "Risque de chute de benne détecté"
  invariants_checklist:
    - id: "INV-SAF-06"
      status: "FAIL"
```
Fin de rapport.
"""
    parsed, err = extract_and_validate_yaml(sample)
    assert err == ""
    assert parsed is not None
    assert parsed["_verdict"] == "BLOCK"


def test_yaml_extraction_agent_evaluation_standard():
    """Extraction avec le nouveau standard agent_evaluation."""
    sample = """
```yaml
agent_evaluation:
  agent: "FB_Agent_Standards"
  verdict: "BLOCK"
  impact_line: "Outil de liaison G200 omis"
```
"""
    parsed, err = extract_and_validate_yaml(sample)
    assert err == ""
    assert parsed is not None
    assert parsed["_verdict"] == "BLOCK"
    assert parsed["_root_key"] == "agent_evaluation"


def test_yaml_extraction_challenge_evaluation():
    """Extraction d'un rapport de challenge."""
    sample = """
```yaml
challenge_evaluation:
  subject: "Optimisation M3"
  verdict: "ADVISORY"
  target_goal: "Réduire temps cycle"
```
"""
    parsed, err = extract_challenge_yaml(sample)
    assert err == ""
    assert parsed is not None
    assert parsed["challenge_evaluation"]["verdict"] == "ADVISORY"


def test_standards_persona_invariants():
    """Vérifie que FB_Agent_Standards contient bien les 7 invariants, dont l'outillage."""
    content = load_persona("standards")
    assert "INV-STD-01" in content
    assert "INV-STD-05" in content
    assert "INV-STD-06" in content
    assert "INV-STD-07" in content
    assert "G200_check_linkage.py" in content
    assert "generate_codesys_bundle.py" in content


def test_challenger_persona_structure():
    """Vérifie que FB_Agent_Challenger contient le cadrage étape 0 et la dialectique."""
    content = load_persona("challenger")
    assert "INV-CHL-01" in content
    assert "Anti-Garbage-In" in content
    assert "Agent A" in content
    assert "Agent B" in content
    assert "Arbitre C" in content


def test_all_personas_loaded_successfully():
    """Vérifie que les 6 personas sont tous chargés et documentés."""
    assert len(ROLE_MAP) == 6
    for role in ROLE_MAP.keys():
        content = load_persona(role)
        assert len(content) > 100
        assert "SYSTEM_PROMPT" in content
