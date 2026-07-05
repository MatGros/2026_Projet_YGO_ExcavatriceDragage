from generator.diagnostics import DiagnosticCollector, Severity


def test_empty_collector_has_no_errors():
    diag = DiagnosticCollector()
    assert not diag.has_errors()
    assert len(diag) == 0


def test_info_warning_error_are_recorded_with_severity():
    diag = DiagnosticCollector()
    diag.info("informational", source="foo.st")
    diag.warning("watch out", source="foo.st")
    diag.error("boom", source="foo.st")

    assert len(diag) == 3
    assert [d.severity for d in diag] == [Severity.INFO, Severity.WARNING, Severity.ERROR]


def test_has_errors_true_only_when_error_present():
    diag = DiagnosticCollector()
    diag.info("fine")
    diag.warning("careful")
    assert not diag.has_errors()

    diag.error("failed")
    assert diag.has_errors()


def test_of_filters_by_severity():
    diag = DiagnosticCollector()
    diag.info("a")
    diag.info("b")
    diag.warning("c")

    assert len(diag.of(Severity.INFO)) == 2
    assert len(diag.of(Severity.WARNING)) == 1
    assert len(diag.of(Severity.ERROR)) == 0


def test_extend_merges_diagnostics_from_another_collector():
    parent = DiagnosticCollector()
    parent.info("parent-info")

    child = DiagnosticCollector()
    child.error("child-error")

    parent.extend(child)

    assert len(parent) == 2
    assert parent.has_errors()


def test_str_includes_severity_and_source():
    diag = DiagnosticCollector()
    diag.warning("stale pair", source="FB_Safety_Winch")
    rendered = str(diag.all[0])
    assert "WARNING" in rendered
    assert "FB_Safety_Winch" in rendered
    assert "stale pair" in rendered
