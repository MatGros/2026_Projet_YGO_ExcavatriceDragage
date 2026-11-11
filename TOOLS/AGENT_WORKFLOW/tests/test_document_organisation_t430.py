"""T430 : mutations des fichiers-fixtures, jamais du corpus de production."""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path
from types import SimpleNamespace

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/check_document_organisation.py"


def load():
    spec = importlib.util.spec_from_file_location("organisation_t430_test", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def put(root, rel, text="# Document\n"):
    p = root / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text, encoding="utf-8")
    return p


def fixture(root):
    module = load()
    base = "DOC/WFLOW/TASKS/T_TEMP (A TRIIER)"
    put(root, base + "/AUDITS/TXXX_RAPPORT_v1.0.md")
    put(root, base + "/AUDITS/" + module.APPLICATION_REPORT)
    manifest = put(root, base + "/AUDITS/" + module.MANIFEST, json.dumps({
        "files": [{"source": "RAPPORT_v1.0.md", "target": "TXXX_RAPPORT_v1.0.md"}],
        "proposal_files": [{"source": "CORRESPONDANCE.json", "target": module.MANIFEST}],
    }))
    yaml_path = base + "/CONTRACTS/T123_CONTRAT_TEST.yaml"
    put(root, yaml_path, "contract:\n  task_id: T123\n")
    report = """# Rapport de migration
## Application du renommage — 2026-11-10
| Ancien nom | Nom applique |
|---|---|
| `TASK_CONTRACT_T123.yaml` | `T123_CONTRAT_TEST.yaml` |
| `TXXX_TRIAGE_CONTRACTS_VS_TASKS_20261110.md` | `TXXX_TRIAGE_CONTRACTS_VS_TASKS_20261110.md` |
| `ancien.yaml.bak_v1` | `T123_CONTRAT.yaml.bak_v1` |
## Suite validée — REVIEWS et TESTS, 2026-11-10
| Dossier | Ancien nom | Nom applique | Decision |
|---|---|---|---|
| REVIEWS | `REVIEW_T123.md` | `T123_REVUE.md` | GARDER |
| TESTS | `TEST_T123.md` | `T123_PLAN_TEST.md` | GARDER |
"""
    put(root, base + "/CONTRACTS/" + module.REPORT, report)
    put(root, base + "/REVIEWS/T123_REVUE.md")
    put(root, base + "/TESTS/T123_PLAN_TEST.md")
    put(root, "DOC/WFLOW/TASKS.yaml", "tasks:\n- id: T123\n  contrat: >\n    " + yaml_path + "\n")
    return module, root / base, manifest


def test_exact_destinations_with_spaces_and_real_txxx_are_valid(tmp_path):
    module, base, _ = fixture(tmp_path)
    expected, _ = module.load_migration(tmp_path)
    assert len(expected) == 7
    assert base / "AUDITS/TXXX_RAPPORT_v1.0.md" in expected
    assert module.check(tmp_path) == []


def test_removed_destination_fails_even_when_replaced_by_another_file(tmp_path):
    module, base, _ = fixture(tmp_path)
    (base / "REVIEWS/T123_REVUE.md").unlink()
    put(tmp_path, "DOC/WFLOW/TASKS/T_TEMP (A TRIIER)/REVIEWS/T123_AUTRE.md")
    errors = module.check(tmp_path)
    assert any("destination attendue absente" in e for e in errors)
    assert any("hors correspondance" in e for e in errors)


def test_yaml_coverage_loss_is_detected_with_file_still_present(tmp_path, monkeypatch):
    module, _, _ = fixture(tmp_path)
    real_loader = module.load_tool
    real_g530 = real_loader("G530_check_contract_refs")
    monkeypatch.setattr(module, "load_tool", lambda name: SimpleNamespace(
        discover_sources=lambda root: [], extract_paths=real_g530.extract_paths
    ) if name == "G530_check_contract_refs" else real_loader(name))
    errors = module.check(tmp_path)
    assert any("source YAML non couverte" in e for e in errors)


def test_invalid_version_suffix_is_rejected(tmp_path):
    module, base, _ = fixture(tmp_path)
    (base / "AUDITS/TXXX_RAPPORT_v1.0.md").rename(base / "AUDITS/TXXX_RAPPORT_V1_0.md")
    assert any("suffixe de version invalide" in e for e in module.check(tmp_path))


def test_catalogue_old_complete_path_is_rejected(tmp_path):
    module, _, _ = fixture(tmp_path)
    put(tmp_path, "DOC/WFLOW/TASKS.yaml", "tasks:\n- id: T123\n  contrat: DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T123.yaml\n")
    assert any("reference de migration obsolete : catalogue T123" in e for e in module.check(tmp_path))


def test_active_markdown_link_is_checked_but_historical_plaintext_is_preserved(tmp_path):
    module, base, _ = fixture(tmp_path)
    target = base / "REVIEWS/T123_REVUE.md"
    target.write_text("# Revue\nAncien chemin `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T123.yaml`.\n", encoding="utf-8")
    assert module.check(tmp_path) == []
    target.write_text("# Revue\n[Contrat](../CONTRACTS/TASK_CONTRACT_T123.yaml)\n", encoding="utf-8")
    assert any("reference de migration obsolete" in e for e in module.check(tmp_path))


def test_link_to_the_applied_but_invalid_version_name_is_rejected(tmp_path):
    module, base, _ = fixture(tmp_path)
    (base / "REVIEWS/T123_REVUE.md").write_text(
        "# Revue\n[Rapport](../AUDITS/TXXX_RAPPORT_V1_0.md)\n", encoding="utf-8"
    )
    assert any("reference de migration obsolete" in e for e in module.check(tmp_path))


def test_ambiguous_manifest_fails(tmp_path):
    module, _, manifest = fixture(tmp_path)
    put(tmp_path, "DOC/WFLOW/TASKS/T777/AUDITS/" + module.MANIFEST, manifest.read_text(encoding="utf-8"))
    assert any("absent ou ambigu" in e for e in module.check(tmp_path))


def test_example_and_archived_manifests_do_not_make_real_txxx_ambiguous(tmp_path):
    module, _, manifest = fixture(tmp_path)
    text = manifest.read_text(encoding="utf-8")
    put(tmp_path, "DOC/WFLOW/TASKS/TXXX/AUDITS/" + module.MANIFEST, text)
    put(tmp_path, "DOC/WFLOW/TASKS/T777/ARCHIVES/" + module.MANIFEST, text)
    assert module.check(tmp_path) == []


def test_duplicate_windows_destination_is_not_a_valid_correspondence(tmp_path):
    module, _, manifest = fixture(tmp_path)
    data = json.loads(manifest.read_text(encoding="utf-8"))
    data["files"].append({"source": "AUTRE.md", "target": "TXXX_RAPPORT_v1.0.md"})
    manifest.write_text(json.dumps(data), encoding="utf-8")
    assert any("collision Windows" in e for e in module.check(tmp_path))


def test_invalid_current_json_target_is_not_silently_normalised(tmp_path):
    module, _, manifest = fixture(tmp_path)
    data = json.loads(manifest.read_text(encoding="utf-8"))
    data["files"][0]["target"] = "TXXX_RAPPORT_V1_0.md"
    data["current_target_overrides"] = {
        "AUDITS/TXXX_RAPPORT_V1_0.md": "AUDITS/TXXX_RAPPORT_v1.0.md"
    }
    manifest.write_text(json.dumps(data), encoding="utf-8")
    assert any("suffixe de version invalide dans la cible declaree" in e for e in module.check(tmp_path))


def historical_test_target(root, base, module):
    (base / "TESTS/T123_PLAN_TEST.md").rename(base / "TESTS/T123_PLAN_TEST_v1.0.md")
    report = base / "CONTRACTS" / module.REPORT
    report.write_text(report.read_text(encoding="utf-8").replace(
        "`T123_PLAN_TEST.md`", "`T123_PLAN_TEST_V1_0.md`"
    ), encoding="utf-8")


def test_historical_table_needs_an_explicit_current_target_override(tmp_path):
    module, base, _ = fixture(tmp_path)
    historical_test_target(tmp_path, base, module)
    assert any("suffixe de version invalide dans la cible declaree" in e for e in module.check(tmp_path))


def test_explicit_override_repairs_only_the_historical_table_target(tmp_path):
    module, base, manifest = fixture(tmp_path)
    historical_test_target(tmp_path, base, module)
    data = json.loads(manifest.read_text(encoding="utf-8"))
    data["current_target_overrides"] = {
        "TESTS/T123_PLAN_TEST_V1_0.md": "TESTS/T123_PLAN_TEST_v1.0.md"
    }
    manifest.write_text(json.dumps(data), encoding="utf-8")
    assert module.check(tmp_path) == []


def test_missing_explicit_current_json_target_is_rejected(tmp_path):
    module, _, manifest = fixture(tmp_path)
    data = json.loads(manifest.read_text(encoding="utf-8"))
    data["files"][0]["current_target"] = "TXXX_RAPPORT_v1.1.md"
    manifest.write_text(json.dumps(data), encoding="utf-8")
    assert any("destination attendue absente" in e and "v1.1" in e for e in module.check(tmp_path))


def test_optional_markdown_titles_do_not_hide_obsolete_targets(tmp_path):
    module, base, _ = fixture(tmp_path)
    review = base / "REVIEWS/T123_REVUE.md"
    for link in [
        '[Contrat](../CONTRACTS/TASK_CONTRACT_T123.yaml "Contrat historique")',
        "[Contrat](../CONTRACTS/TASK_CONTRACT_T123.yaml 'Contrat historique')",
        "[Contrat](../CONTRACTS/TASK_CONTRACT_T123.yaml (Contrat historique))",
        '[Contrat](<../CONTRACTS/TASK_CONTRACT_T123.yaml> "Contrat historique")',
    ]:
        review.write_text("# Revue\n" + link + "\n", encoding="utf-8")
        assert any("reference de migration obsolete" in e for e in module.check(tmp_path)), link


def test_active_contract_scalar_checks_punctuated_paths_but_not_historical_results(tmp_path):
    module, base, _ = fixture(tmp_path)
    contract = base / "CONTRACTS/T123_CONTRAT_TEST.yaml"
    old = "DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T123.yaml"
    current = contract.relative_to(tmp_path).as_posix()
    template = ('contract:\n  task_id: T123\n  acceptance:\n'
                '  - verified_by: "Voir {active}."\n'
                'execution:\n  proof: "Ancienne mesure : ' + old + '."\n'
                'validation:\n  note: "Ancienne mesure : ' + old + '."\n')
    contract.write_text(template.format(active=old), encoding="utf-8")
    assert any("reference de migration obsolete" in e and " contract ->" in e for e in module.check(tmp_path))
    contract.write_text(template.format(active=current), encoding="utf-8")
    assert module.check(tmp_path) == []
