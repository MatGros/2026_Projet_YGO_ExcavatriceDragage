"""Behavioral counterexamples for the T426 advisory checker."""
import copy
import importlib.util
from pathlib import Path
import tempfile
import unittest
import contextlib
import io

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/check_task_tracking.py"
spec = importlib.util.spec_from_file_location("tracking", SCRIPT)
tracking = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tracking)


class TrackingTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / "proof.txt").write_text("observed result", encoding="utf-8")
        (self.root / "proof_b.txt").write_text("independent review", encoding="utf-8")
        self.exp = dict(id="R1", question="Which gate blocks departure?", prediction="Permit false",
                        discriminating_observation="Read producer and consumer", decision_if_confirmed="Trace gate inputs",
                        decision_if_refuted="Inspect final output", result="FAIL", evidence=["proof.txt"],
                        information_gained=True)
        self.record = dict(tracking=dict(user_need="Reliable simulation", current_question="Departure gate",
                           next_action="Read permit", owners=dict(accountable="CDX01"), experiments=[self.exp]))

    def codes(self):
        return {x["code"] for x in tracking.inspect_record(self.record, self.root)}

    def test_informative_failure_is_progress(self):
        self.assertEqual(self.codes(), set())

    def test_planned_experiment_does_not_count_as_stagnation(self):
        self.exp.pop("result")
        self.assertEqual(self.codes(), set())

    def test_three_uninformative_passes_require_review(self):
        self.record["tracking"]["experiments"] = [dict(self.exp, id=f"R{i}", result="PASS", information_gained=False) for i in range(3)]
        self.assertIn("BLIND_REVIEW_DUE", self.codes())

    def test_new_information_resets_streak(self):
        self.record["tracking"]["experiments"] = [dict(self.exp, id=f"R{i}", information_gained=i == 2) for i in range(4)]
        self.assertNotIn("BLIND_REVIEW_DUE", self.codes())

    def test_exception_never_supports_pass(self):
        self.exp.update(result="PASS", exception="runtime failure")
        self.assertIn("CONTRADICTORY_PASS", self.codes())

    def test_nominal_requires_identity_and_substitution_register(self):
        self.exp.update(result="PASS", qualification="nominal")
        self.assertIn("NOMINAL_UNSUPPORTED", self.codes())
        self.exp.update(source_identity="verified", substitutions_declared=True, build_required=False, cleanup_required=False)
        self.assertNotIn("NOMINAL_UNSUPPORTED", self.codes())

    def test_missing_evidence(self):
        self.exp.update(result="PASS", evidence=["missing.txt"])
        self.assertIn("EVIDENCE_MISSING", self.codes())

    def test_path_cannot_escape_checkout(self):
        self.exp["evidence"] = ["../proof.txt"]
        self.assertIn("EVIDENCE_OUTSIDE_ROOT", self.codes())

    def test_repeat_needs_reason(self):
        self.exp["repeat_of"] = "R0"
        self.assertIn("REPEAT_REASON", self.codes())

    def test_legacy_record_is_advisory_not_migrated(self):
        legacy = {"status": "COMPLETED"}
        self.assertEqual(tracking.inspect_record(legacy, self.root)[0]["code"], "TRACKING_ABSENT")
        self.assertEqual(legacy, {"status": "COMPLETED"})

    def test_malformed_result_is_reported_without_crash(self):
        self.exp["result"] = ["PASS"]
        self.assertIn("INVALID_RESULT", self.codes())

    def test_custom_threshold_requires_reason(self):
        self.record["tracking"]["stagnation"] = dict(threshold=4)
        self.assertIn("THRESHOLD_REASON", self.codes())
        self.record["tracking"]["stagnation"]["justification"] = "Four independent measurement windows"
        self.assertNotIn("THRESHOLD_REASON", self.codes())

    def test_duplicate_run_ids(self):
        self.record["tracking"]["experiments"].append(copy.deepcopy(self.exp))
        self.assertIn("DUPLICATE_EXPERIMENT", self.codes())

    def test_cli_advisory_does_not_block_but_strict_reports_findings(self):
        path = self.root / "legacy.yaml"
        path.write_text("status: PENDING\n", encoding="utf-8")
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(tracking.main([str(path)]), 0)
            self.assertEqual(tracking.main([str(path), "--strict"]), 1)

    def test_cli_input_error_is_distinct_from_findings(self):
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(tracking.main([str(self.root / "absent.yaml")]), 2)

    def test_interrupted_build_and_unknown_cleanup_do_not_support_pass(self):
        self.exp.update(result="PASS", build_state="INTERRUPTED", cleanup_state="UNKNOWN")
        self.assertIn("INCOMPLETE_PASS", self.codes())

    def test_documentation_needs_no_runtime_experiments(self):
        self.record["tracking"]["experiments"] = []
        self.assertEqual(self.codes(), set())

    def test_review_closes_stagnation_without_deleting_history(self):
        experiments = [dict(self.exp, id=f"R{i}", information_gained=False) for i in range(3)]
        self.record["tracking"]["experiments"] = experiments
        self.record["tracking"]["stagnation"] = dict(blind_reviews=[dict(
            after_experiment="R2", independent=True, decision="Change measurement",
                reviewers=[dict(actor="CDX02", evidence="proof.txt"), dict(actor="CDX03", evidence="proof_b.txt")])])
        self.assertNotIn("BLIND_REVIEW_DUE", self.codes())
        self.assertEqual(len(experiments), 3)

    def test_review_requires_distinct_reports(self):
        self.record["tracking"]["experiments"] = [dict(self.exp, id=f"R{i}", information_gained=False) for i in range(3)]
        self.record["tracking"]["stagnation"] = dict(blind_reviews=[dict(
            after_experiment="R2", independent=True, decision="Change measurement",
            reviewers=[dict(actor="CDX02", evidence="proof.txt"), dict(actor="CDX03", evidence="proof.txt")])])
        self.assertIn("BLIND_REVIEW_DUE", self.codes())
        self.assertIn("REVIEW_INCOMPLETE", self.codes())

    def test_incomplete_review_does_not_clear_due_review(self):
        self.record["tracking"]["experiments"] = [dict(self.exp, id=f"R{i}", information_gained=False) for i in range(3)]
        self.record["tracking"]["stagnation"] = dict(blind_reviews=[dict(after_experiment="R2", decision="Continue")])
        self.assertIn("BLIND_REVIEW_DUE", self.codes())
        self.assertIn("REVIEW_INCOMPLETE", self.codes())


if __name__ == "__main__":
    unittest.main()
