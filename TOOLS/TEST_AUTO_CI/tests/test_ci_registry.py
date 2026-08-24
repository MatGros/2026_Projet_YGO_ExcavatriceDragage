"""Tests Pytest pour le framework TEST_AUTO_CI et la validité du registre de tests."""

from pathlib import Path
import pytest
import yaml

REPO_ROOT = Path(__file__).resolve().parents[3]
TEST_AUTO_CI = REPO_ROOT / "TOOLS" / "TEST_AUTO_CI"
REGISTRY_FILE = TEST_AUTO_CI / "registry.yaml"
CONFIG_FILE = TEST_AUTO_CI / "config.yaml"


def test_ci_registry_exists_and_valid():
    """Vérifie que registry.yaml est présent et bien formé."""
    assert REGISTRY_FILE.exists(), f"Fichier {REGISTRY_FILE} introuvable"
    data = yaml.safe_load(REGISTRY_FILE.read_text(encoding="utf-8"))
    assert isinstance(data, dict), "registry.yaml doit être un dictionnaire"
    assert "groups" in data or "tests" in data or len(data) > 0, "registry.yaml ne doit pas être vide"


def test_ci_all_referenced_source_files_exist():
    """Vérifie que tous les fichiers sources ST référencés dans registry.yaml existent bien sur disque."""
    data = yaml.safe_load(REGISTRY_FILE.read_text(encoding="utf-8"))
    missing = []

    def check_paths(node):
        if isinstance(node, dict):
            for k, v in node.items():
                if k in ("source", "test_file", "path") and isinstance(v, str):
                    p = REPO_ROOT / v
                    if not p.exists():
                        missing.append(v)
                else:
                    check_paths(v)
        elif isinstance(node, list):
            for item in node:
                check_paths(item)

    check_paths(data)
    assert not missing, f"Fichiers référencés dans registry.yaml introuvables sur disque :\n" + "\n".join(missing[:20])


def test_ci_config_is_valid():
    """Vérifie que config.yaml est valide."""
    if CONFIG_FILE.exists():
        cfg = yaml.safe_load(CONFIG_FILE.read_text(encoding="utf-8"))
        assert isinstance(cfg, dict), "config.yaml doit être un dictionnaire valide"
