"""T426: inspect a task record without hooks, writes, execution or success claims.

Default: advisory, exit 0 even with findings. --strict is an explicit CI check,
not installed in any hook. Input errors return 2. Requires PyYAML like the task UI.
This checks declarations and local evidence existence, not technical truth. A
blind review must cite two distinct local reports; that is a mechanical proxy,
not proof that reviewers were actually independent.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

import yaml


def inspect_record(record: dict, root: Path) -> list[dict[str, str]]:
    findings = []

    def flag(code, location, message):
        findings.append(dict(code=code, location=location, message=message))

    tracking = record.get("tracking")
    if not isinstance(tracking, dict):
        flag("TRACKING_ABSENT", "tracking", "Legacy record: tracking not supplied; no automatic migration.")
        return findings
    for key in ("user_need", "current_question", "next_action"):
        if not isinstance(tracking.get(key), str) or not tracking[key].strip():
            flag("CONTEXT_MISSING", f"tracking.{key}", "Provide the task-specific value.")
    owners = tracking.get("owners", {})
    if not isinstance(owners, dict) or not owners.get("accountable"):
        flag("OWNER_MISSING", "tracking.owners.accountable", "Name the accountable actor.")
    stagnation = tracking.get("stagnation", {})
    if not isinstance(stagnation, dict):
        flag("INVALID_POLICY", "tracking.stagnation", "Expected a mapping.")
        stagnation = {}
    threshold = stagnation.get("threshold", 3)
    if type(threshold) is not int or not 2 <= threshold <= 5:
        flag("INVALID_THRESHOLD", "tracking.stagnation.threshold", "Expected integer 2 through 5.")
        threshold = 3
    elif threshold != 3 and not stagnation.get("justification"):
        flag("THRESHOLD_REASON", "tracking.stagnation.justification", "Explain the non-default threshold.")
    experiments = tracking.get("experiments", [])
    if not isinstance(experiments, list):
        flag("INVALID_EXPERIMENTS", "tracking.experiments", "Expected a list.")
        return findings
    seen = set()
    streak = 0
    reviews = stagnation.get("blind_reviews", [])
    if not isinstance(reviews, list):
        flag("INVALID_REVIEWS", "tracking.stagnation.blind_reviews", "Expected review events as a list.")
        reviews = []
    reviewed_after = set()
    for review in reviews:
        if not isinstance(review, dict):
            flag("INVALID_REVIEW", "tracking.stagnation.blind_reviews", "Expected a mapping.")
            continue
        people = review.get("reviewers", [])
        evidence_paths = [p.get("evidence") for p in people if isinstance(p, dict)]
        valid_people = isinstance(people, list) and len(people) == 2 and all(
            isinstance(p, dict) and isinstance(p.get("actor"), str) and p["actor"].strip()
            and isinstance(p.get("evidence"), str)
            and (root / p["evidence"]).resolve().is_relative_to(root.resolve())
            and (root / p["evidence"]).is_file() for p in people)
        valid = (valid_people and len(set(evidence_paths)) == 2
                 and people[0]["actor"] != people[1]["actor"]
                 and review.get("independent") is True and isinstance(review.get("decision"), str)
                 and review["decision"].strip() and isinstance(review.get("after_experiment"), str))
        if valid:
            reviewed_after.add(review["after_experiment"])
        else:
            flag("REVIEW_INCOMPLETE", "tracking.stagnation.blind_reviews", "Two distinct reviewers, local reports, independence and next decision required.")
    review_due_at = None
    for index, exp in enumerate(experiments):
        loc = f"tracking.experiments[{index}]"
        if not isinstance(exp, dict):
            flag("INVALID_EXPERIMENT", loc, "Expected a mapping.")
            continue
        for key in ("id", "question", "prediction", "discriminating_observation",
                    "decision_if_confirmed", "decision_if_refuted"):
            if not isinstance(exp.get(key), str) or not exp[key].strip():
                flag("EXPERIMENT_MISSING", f"{loc}.{key}", "Required before an experiment.")
        ident = exp.get("id")
        if isinstance(ident, str):
            if ident in seen:
                flag("DUPLICATE_EXPERIMENT", f"{loc}.id", "Use a unique run identifier.")
            seen.add(ident)
        if exp.get("repeat_of") and not exp.get("repeat_reason"):
            flag("REPEAT_REASON", loc, "Explain what new evidence justifies the repeat.")
        result = exp.get("result")
        if result is None:  # A prepared experiment is not a failed or stalled run.
            continue
        if not isinstance(result, str) or result not in {"PASS", "FAIL", "INTERRUPTED", "NOT_TESTED", "CLEANUP_INCOMPLETE"}:
            flag("INVALID_RESULT", loc, "Unknown result state.")
            continue
        evidence = exp.get("evidence", [])
        if not isinstance(evidence, list):
            flag("INVALID_EVIDENCE", loc, "Expected local evidence paths as a list.")
            evidence = []
        if result == "PASS" and not evidence:
            flag("PASS_WITHOUT_EVIDENCE", loc, "PASS requires evidence; existence alone does not prove its contents.")
        for path in evidence:
            if not isinstance(path, str):
                flag("INVALID_EVIDENCE", loc, "Evidence must be a local path.")
                continue
            target = (root / path).resolve()
            if not target.is_relative_to(root.resolve()):
                flag("EVIDENCE_OUTSIDE_ROOT", loc, "Evidence path leaves the selected checkout.")
            elif not target.is_file():
                flag("EVIDENCE_MISSING", loc, f"Missing file: {path}")
        if result == "PASS":
            if exp.get("exception") or exp.get("build_state") == "FAIL" or exp.get("cleanup_state") == "FAIL":
                flag("CONTRADICTORY_PASS", loc, "PASS conflicts with exception, failed build or failed cleanup.")
            for phase in ("build", "cleanup"):
                state = exp.get(f"{phase}_state")
                required = exp.get(f"{phase}_required")
                if state in ("INTERRUPTED", "UNKNOWN", "CLEANUP_INCOMPLETE") or (required is True and state != "PASS"):
                    flag("INCOMPLETE_PASS", loc, f"{phase} is incomplete or not confirmed.")
            if exp.get("qualification") == "nominal" and (
                exp.get("source_identity") != "verified" or exp.get("substitutions_declared") is not True
                or type(exp.get("build_required")) is not bool or type(exp.get("cleanup_required")) is not bool
            ):
                flag("NOMINAL_UNSUPPORTED", loc, "Nominal requires verified identity, declared substitutions and explicit build/cleanup applicability.")
        informative = exp.get("information_gained")
        if informative is False:
            streak += 1
        elif informative is True:
            streak = 0
        elif result not in {"NOT_TESTED"}:
            flag("INFORMATION_UNASSESSED", loc, "Assess whether this run changed the next decision.")
        if streak >= threshold:
            review_due_at = loc
        if isinstance(ident, str) and ident in reviewed_after:
            streak = 0
            review_due_at = None
    for run_id in reviewed_after - seen:
        flag("REVIEW_UNKNOWN_RUN", "tracking.stagnation.blind_reviews", f"Review refers to unknown run: {run_id}")
    if review_due_at:
        flag("BLIND_REVIEW_DUE", review_due_at, "Consecutive uninformative runs: independent A/B review required.")
    return findings


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("record", type=Path)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[3])
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args(argv)
    try:
        data = yaml.safe_load(args.record.read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            raise ValueError("Task record must be a mapping")
        findings = inspect_record(data, args.root)
    except (OSError, ValueError, yaml.YAMLError) as exc:
        print(json.dumps({"state": "INPUT_ERROR", "message": str(exc)}, ensure_ascii=True))
        return 2
    print(json.dumps({"state": "FINDINGS" if findings else "NO_FINDINGS",
                      "mode": "strict" if args.strict else "advisory", "findings": findings}, ensure_ascii=True))
    return int(bool(findings) and args.strict)


if __name__ == "__main__":
    sys.exit(main())
