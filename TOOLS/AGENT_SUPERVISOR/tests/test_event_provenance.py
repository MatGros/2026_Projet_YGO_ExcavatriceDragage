"""Authority boundaries observed in T428, using small synthetic counterparts."""
from TOOLS.AGENT_SUPERVISOR.scripts.platform_adapters import normalize


def claude(content, **metadata):
    return dict(type="user", message={"content": content}, **metadata)


def test_tool_proof_is_visible_without_becoming_human_approval():
    event = claude([dict(type="tool_result", tool_use_id="check-1", content='status: PENDING\nvalidated_by: ""', is_error=False)])
    role, text = normalize("claude", event)
    assert role == "tool"
    assert 'status: PENDING' in text and 'check-1' in text
    assert normalize("claude", claude("J3 validé, snapshot après import XML"))[0] == "user"


def test_replayed_summary_and_delegated_approval_are_not_new_user_instructions():
    assert normalize("claude", claude("Résumé : GO J5", isCompactSummary=True)) is None
    role, text = normalize("claude", claude('GO pour tout modifier', isMeta=True, origin={"kind": "peer"}))
    assert role == "tool" and "aucune autorité utilisateur" in text
    assert normalize("claude", claude('<local-command-stdout>Goal set: J5</local-command-stdout>')) is None


def test_human_goal_survives_without_treating_rename_as_permission():
    goal = '<command-name>/goal</command-name><command-args>go j3 + review à la fin</command-args>'
    assert normalize("claude", claude(goal)) == ("user", "[commande utilisateur /goal]\ngo j3 + review à la fin")
    assert normalize("claude", claude('<command-name>/rename</command-name><command-args>GO J5</command-args>')) is None


def test_large_proof_keeps_end_and_reports_omission_and_error():
    proof = "début\n" + "x" * 15000 + "\nFAIL : 3 erreurs"
    role, text = normalize("claude", claude([dict(type="tool_result", tool_use_id="check-2", is_error=True, content=proof)]))
    assert role == "tool" and "tool error" in text
    assert "caractères omis" in text and text.endswith("FAIL : 3 erreurs")
    assert len(text) < 8500


def test_codex_function_output_is_evidence_and_reasoning_is_not_a_user_message():
    event = dict(type="response_item", payload=dict(type="function_call_output", call_id="linkage", output="PASS (0 erreurs)"))
    role, text = normalize("codex", event)
    assert role == "tool" and "linkage" in text and "PASS" in text
    assert normalize("codex", dict(type="response_item", payload=dict(type="reasoning", summary=[]))) is None
