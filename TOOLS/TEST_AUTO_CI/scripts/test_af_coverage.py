"""Garde-fous du filtrage Etat dans le catalogue AF."""

from af_coverage import check_af_coverage


class _TextFile:
    def __init__(self, text: str) -> None:
        self.text = text

    def read_text(self, encoding: str) -> str:
        assert encoding == "utf-8"
        return self.text


def test_nv_tc_is_not_expected_by_coverage() -> None:
    af_doc = _TextFile(
        "| ID | Intention | Preuve | Type | Ref | Etat |\n"
        "|---|---|---|---|---|---|\n"
        "| <nobr><code>TC-P99-001</code></nobr> | Validated | x | `AUTO` | x | `V` |\n"
        "| <nobr><code>TC-P99-002</code></nobr> | Proposal | x | `AUTO` | x | `NV` |\n"
    )
    test_st = _TextFile("")
    assert check_af_coverage(af_doc, test_st) == [("TC-P99-001", "Validated")]
