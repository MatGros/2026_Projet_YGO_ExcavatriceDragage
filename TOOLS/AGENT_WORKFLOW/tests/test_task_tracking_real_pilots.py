"""T426 contract-backed compatibility scenarios, without writing to contracts."""
from __future__ import annotations

import importlib.util
from pathlib import Path
import unittest

import yaml

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/check_task_tracking.py"
spec = importlib.util.spec_from_file_location("tracking", SCRIPT)
tracking = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tracking)


class ContractBackedScenarioTests(unittest.TestCase):
    def setUp(self):
        self.root = Path(__file__).resolve().parents[3]
        # Fixtures locales : contenu reel des contrats pilotes T417-C et T280
        # captures au moment du prototype T426 (commit 2a5bf86d). Les emplacements
        # d'origine dans le depot ont bouge (fusions T426->T427, archivage) ; le
        # test ne depend plus d'aucun emplacement mobile.
        self.fixtures = Path(__file__).resolve().parent / "fixtures"
        self.t417 = self.fixtures / "TASK_CONTRACT_T417-C.yaml"
        self.t280 = self.fixtures / "TASK_CONTRACT_T280_TROUBLESHOOTING_WORKSPACE.yaml"
        self.assertTrue(self.t417.is_file(), "T417-C pilot contract is required")
        self.assertTrue(self.t280.is_file(), "T280 pilot contract is required")

    @staticmethod
    def load(path: Path) -> dict:
        return yaml.safe_load(path.read_text(encoding="utf-8"))

    def test_existing_contracts_are_legacy_warnings_only(self):
        for path in (self.t417, self.t280):
            findings = tracking.inspect_record(self.load(path), self.root)
            self.assertEqual([item["code"] for item in findings], ["TRACKING_ABSENT"])

    def test_in_memory_reprises_have_zero_false_positive_findings(self):
        technical = self.load(self.t417)
        technical["tracking"] = dict(
            user_need="Validate a real technical task without runtime launch",
            current_question="Does the declared evidence support the next decision?",
            next_action="Keep the CI scenario bounded",
            owners=dict(accountable="CDX01"),
            experiments=[dict(
                id="PILOT-TECH-1",
                question="Does the contract identify the evidence boundary?",
                prediction="The source contract is readable and the runtime is not claimed",
                discriminating_observation="The contract file is present",
                decision_if_confirmed="Keep the result exploratory",
                decision_if_refuted="Request a missing evidence path",
                result="FAIL",
                evidence=[str(self.t417.relative_to(self.root)).replace("\\", "/")],
                information_gained=True,
            )],
        )
        documentary = self.load(self.t280)
        documentary["tracking"] = dict(
            user_need="Review a documentation task without PLC gates",
            current_question="Is the task scope documented?",
            next_action="Review the acceptance criteria",
            owners=dict(accountable="CDX01"),
            experiments=[],
        )
        technical_findings = tracking.inspect_record(technical, self.root)
        documentary_findings = tracking.inspect_record(documentary, self.root)
        self.assertEqual(technical_findings, [])
        self.assertEqual(documentary_findings, [])
        self.assertEqual(len(technical_findings) + len(documentary_findings), 0)


if __name__ == "__main__":
    unittest.main()
