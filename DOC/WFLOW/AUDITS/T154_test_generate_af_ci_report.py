"""Garde-fou DOC-only T154 : extraction des identifiants TC des titres TEST."""
from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("T154_generate_af_ci_report.py")
SPEC = importlib.util.spec_from_file_location("t154_report", MODULE_PATH)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class TestTcTitleParsing(unittest.TestCase):
    def test_expands_compact_tc_title(self) -> None:
        self.assertEqual(
            MODULE.ids_from_text("TEST 'TC-P01-004/009 Reset'"),
            {"TC-P01-004", "TC-P01-009"},
        )

    def test_ignores_tc_outside_test_title_regex_contract(self) -> None:
        self.assertEqual(MODULE.ids_from_text("no tc here"), set())


if __name__ == "__main__":
    unittest.main()
