"""Deterministic finding state, audit events and projections (no model calls)."""
from __future__ import annotations

import copy
import hashlib
import json


CLOSED = {"resolved", "false_positive", "ignored"}


def business_state(alert):
    return "closed" if alert.get("disposition") in CLOSED else "deferred" if alert.get("disposition") == "deferred" else "open"


def prepare_alert(alert):
    alert.setdefault("reference", "A-" + str(alert["id"])[:12])
    alert.setdefault("version", 1)
    alert.setdefault("comments", [])
    alert.setdefault("history", [])
    alert.setdefault("assessment", {"status": "active", "reason": alert.get("reason", ""), "evidence": alert.get("evidence", ""), "updated_at": alert.get("last_occurrence")})
    alert["business_state"] = business_state(alert)
    return alert


def counts(alerts):
    result = dict(unread=0, open=0, deferred=0, closed=0, follow_up=0, warnings=0, alarms=0, resolution_proposed=0)
    for alert in alerts:
        prepare_alert(alert)
        state = business_state(alert)
        result[state] += 1
        if alert.get("disposition", "new") == "new": result["unread"] += 1
        if state != "closed":
            result["follow_up"] += 1
            assessment = alert["assessment"].get("status")
            if assessment == "resolution_proposed": result["resolution_proposed"] += 1
            if assessment not in ("resolution_proposed", "withdrawn"):
                result["alarms" if alert.get("severity") in ("error", "alarm") else "warnings"] += 1
    return result


def record_event(session, kind, text, at, *, source_id=None, **fields):
    events = session.setdefault("events", [])
    if source_id:
        existing = next((e for e in events if e.get("source_id") == source_id and e.get("kind") == kind), None)
        if existing: return existing
    sequence = len(events) + 1
    seed = json.dumps([session["id"], kind, source_id, sequence, text], ensure_ascii=False)
    ident = hashlib.sha256(seed.encode()).hexdigest()[:32]
    event = dict(id=ident, ref="E-" + ident[:12], kind=kind, text=text, created_at=at, **fields)
    if source_id: event["source_id"] = source_id
    events.append(event)
    return event


def revise(alert, at, **changes):
    prepare_alert(alert)
    if all(alert.get(k) == v for k, v in changes.items()): return False
    alert["history"].append({k: copy.deepcopy(alert.get(k)) for k in ("version", "reason", "evidence", "severity", "assessment", "disposition") } | {"revised_at": at})
    alert.update(changes)
    alert["version"] += 1
    alert["business_state"] = business_state(alert)
    return True


def apply_reviews(session, result, messages, at):
    """Only an explicit, cited model review can change an assessment, never a user decision."""
    reviews = result.get("reviews", [])
    if not isinstance(reviews, list): return []
    reviewed = []
    sources = [m for m in messages if m.get("role") in ("user", "assistant", "tool", "user_comment")]  # T429: the user's comment is citable
    for review in reviews:
        if not isinstance(review, dict): continue
        alert = next((a for a in session["alerts"] if a["id"] == review.get("alert_id")), None)
        status = review.get("status")
        reason, evidence = review.get("reason"), review.get("evidence")
        if not alert or status not in ("active", "resolution_proposed", "withdrawn", "uncertain") or not isinstance(reason, str) or not reason.strip(): continue
        if not isinstance(evidence, str) or len(evidence.strip()) < 4 or not any(evidence in m["text"] for m in sources): continue
        assessment = dict(status=status, reason=reason, evidence=evidence, updated_at=at)
        reviewed.append(alert["id"])
        alert["review_state"] = "complete"
        alert.pop("review_error", None)
        old = alert.get("assessment", {})
        if status == "uncertain" and old.get("status") in ("resolution_proposed", "withdrawn"):
            continue  # T429: a sourced resolution is not lost because its proof left the bounded window
        if all(old.get(k) == assessment[k] for k in ("status", "reason", "evidence")): continue
        if old.get("status") == status:
            continue  # T429 (observed live: v18 -> v64): same opinion reworded is not a new version
        revise(alert, at, assessment=assessment)
        record_event(session, "finding_review", reason, at, alert_id=alert["id"], version=alert["version"], evidence=evidence)
    return reviewed
