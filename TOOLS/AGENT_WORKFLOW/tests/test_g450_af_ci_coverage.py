from pathlib import Path
import sys

SCRIPTS = Path(__file__).parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

from G450_check_af_ci_coverage import assess, assess_component, ids_from_test_titles, registry_test_ids


def test_compact_test_title_expands_two_ids_and_ignores_asserts():
    text = "TEST 'TC-P01-004/009 title'\nEND_TEST\nASSERT_TRUE(X, 'TC-P01-123')"
    assert ids_from_test_titles(text) == {"TC-P01-004", "TC-P01-009"}


def test_assess_keeps_site_and_ignore_visible_but_not_missing():
    matrix = {"domains": {"AF-01": {"functions": {
        "F01.01": {"tc_couvrants": ["TC-P01-001"]},
        "F01.02": {"tc_couvrants": ["TC-P01-002"]},
        "F01.03": {"tc_couvrants": ["TC-P01-003"]},
        "F01.04": {"tc_couvrants": []},
    }, "validation_points": {
        "TC-P01-001": {"type": "💻 AUTO"},
        "TC-P01-002": {"type": "🧪 SITE"},
        "TC-P01-003": {"type": "💻 AUTO"},
    }}}}
    no_tc, missing, exceptions = assess(matrix, set(), {"TC-P01-003": {"FB_Safety"}})
    assert no_tc == ["AF-01 F01.04"]
    assert missing == ["AF-01 F01.01 -> TC-P01-001"]
    assert exceptions == ["AF-01 F01.03 -> TC-P01-003 (af_ignore: FB_Safety)"]


def test_registry_missing_test_path_is_reported(tmp_path):
    tested, ignored, missing_paths = registry_test_ids(
        tmp_path, {"FB_Demo": {"test": "missing/test.st", "af_ignore": ["TC-P99-001"]}}
    )
    assert tested == set()
    assert ignored == {"TC-P99-001": {"FB_Demo"}}
    assert missing_paths == ["missing/test.st"]


def test_component_assessment_supports_scenarios_and_reports_orphans():
    result = assess_component(
        {"F01.01": {"tc_couvrants": ["TC-P01-001", "TC-P01-SCEN-NOM"]}},
        {"TC-P01-001": {"type": "AUTO"}, "TC-P01-SCEN-NOM": {"type": "AUTO"}, "TC-P01-SCEN-DYN": {"type": "AUTO"}},
        {"TC-P01-001", "TC-P01-SCEN-NOM", "TC-P03-001"}, [],
    )
    assert result["catalog_tc_without_function"] == ["TC-P01-SCEN-DYN"]
    assert result["auto_tc_missing_test"] == ["TC-P01-SCEN-DYN"]
    assert result["test_tc_missing_catalog"] == []


def test_component_assessment_makes_legacy_ignore_visible():
    result = assess_component({"F01.01": {"tc_couvrants": ["TC-P01-001"]}}, {"TC-P01-001": {"type": "AUTO"}}, set(), ["TC-P01-001"])
    assert result["auto_tc_missing_test"] == []
    assert result["ignore_warnings"] == ["TC-P01-001 (raison/scope manquants)"]
