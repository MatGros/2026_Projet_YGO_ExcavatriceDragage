"""Garde-fous du filtrage Etat dans le catalogue AF + conformité HTML-rigide (v2)."""

import af_coverage_v2 as af


class _TextFile:
    def __init__(self, text: str) -> None:
        self.text = text

    def read_text(self, encoding: str) -> str:
        assert encoding == "utf-8"
        return self.text


def test_nv_tc_is_not_expected_by_coverage() -> None:
    # Tables markdown : le filtrage par Etat (V/V-I vs NV) doit rester inchangé.
    af_doc = _TextFile(
        "| ID | Intention | Preuve | Type | Ref | Etat |\n"
        "|---|---|---|---|---|---|\n"
        "| <nobr><code>TC-P99-001</code></nobr> | Validated | x | `AUTO` | x | `V` |\n"
        "| <nobr><code>TC-P99-002</code></nobr> | Proposal | x | `AUTO` | x | `NV` |\n"
    )
    test_st = _TextFile("")
    assert af.check_af_coverage(af_doc, test_st) == [("TC-P99-001", "Validated")]


def test_span_markup_fiche_is_not_flagged_as_extra() -> None:
    """Régression FB_Safety_EmergencyManagement_v1.2 : la fiche écrit ses IDs en `<span
    writing-mode: vertical-rl>` (et le type en `<code>`, pas en backtick). Sans prise en compte,
    `check_extra_tests` déclarait tous les IDs testés "absents du catalogue AF"."""
    af_doc = _TextFile(
        "<table>"
        "<tr>"
        '<td><span style="writing-mode: vertical-rl; transform: rotate(180deg);">TC-P01-001</span></td>'
        "<td>Coupure AU physique</td>"
        '<td><small><code>🟢 SITE</code></small></td>'
        "</tr>"
        "<tr>"
        '<td><span style="writing-mode: vertical-rl;">TC-P01-002</span></td>'
        "<td>Perte maintien A/B</td>"
        '<td><small><code>⚡ MIXTE</code></small></td>'
        "</tr>"
        "<tr>"
        '<td><span style="writing-mode: vertical-rl;">TC-P01-SCEN-NOM</span></td>'
        "<td>Scénario nominal</td>"
        '<td><small><code>💻 AUTO</code></small></td>'
        "</tr>"
        "</table>"
    )
    catalog_ids = {tid for tid, _t, _i, _e in af.parse_af_catalog(af_doc.text)}
    assert catalog_ids == {"TC-P01-001", "TC-P01-002", "TC-P01-SCEN-NOM"}

    test_st = _TextFile(
        "TEST 'TC-P01-001 Coupure AU physique (essai site)'\n"
        "TEST 'TC-P01-002 (partie AUTO) chaque canal indépendant'\n"
        "TEST 'TC-P01-SCEN-NOM Scenario nominal'\n"
    )
    assert af.check_extra_tests(af_doc, test_st) == []


def test_extract_test_ids_symmetric_suffixes() -> None:
    """Un TEST peut prouver plusieurs IDs (004/009) ; les suffixes nommés (SCEN-), sous-cas
    (.1) ou codes (TSV-) doivent rester un seul token, symétriquement du catalogue."""
    st = "TEST 'TC-P01-004/009 Reset acquitte l affichage'\n"
    st += "TEST 'TC-P03-014.1 sous-cas Cycltime'\n"
    st += "TEST 'TC-P14-TSV-01 code metier troubleshooting'\n"
    assert af.extract_test_ids(st) == {
        "TC-P01-004", "TC-P01-009", "TC-P03-014.1", "TC-P14-TSV-01",
    }


def test_prose_nobr_reference_not_added_as_catalog_when_tables_are_html() -> None:
    """Quand la fiche est en HTML rigide, une référence inline `<nobr><code>` (ex. historique
    dans un tableau markdown) ne doit PAS être doublée/confondue avec la table catalogue."""
    af_doc = _TextFile(
        "<table>"
        "<tr>"
        '<td><span style="writing-mode: vertical-rl;">TC-P02-001</span></td>'
        "<td>Ordre de programme</td>"
        '<td><small><code>💻 AUTO</code></small></td>'
        "</tr>"
        "</table>\n"
        "| v3.2 | mise en conformite <nobr><code>TC-P02-001</code></nobr> annoté |\n"
    )
    ids = {tid for tid, _t, _i, _e in af.parse_af_catalog(af_doc.text)}
    assert ids == {"TC-P02-001"}
