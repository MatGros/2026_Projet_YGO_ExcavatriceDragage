"""Regression guard for CODESYS LD import type-safe FB input wiring."""

from __future__ import annotations

import sys
from pathlib import Path

GENERATOR_ROOT = Path(__file__).resolve().parents[2] / "ST_PLCOPENXML_GENERATOR"
sys.path.insert(0, str(GENERATOR_ROOT))

from generator.ld_builder import build_ld_body


def test_non_bool_fb_arguments_are_invariables_not_ladder_contacts() -> None:
    """TIME/INT inputs must not be represented by BOOL-only LD contacts."""
    ld_body = build_ld_body(
        "instInput(InputRaw := RawSignal, FilterTime := CST_FilterTime, ChannelOk := TRUE);",
        instance_types={"instInput": "FB_Input"},
        instance_input_types={
            "instInput": {
                "InputRaw": "BOOL",
                "FilterTime": "TIME",
                "ChannelOk": "BOOL",
            }
        },
    )

    block = ld_body.find("LD/block")
    assert block is not None
    inputs = {variable.get("formalParameter"): variable for variable in block.findall("inputVariables/variable")}
    source_ids = {
        name: inputs[name].find("connectionPointIn/connection").get("refLocalId")
        for name in inputs
    }
    invariables = {variable.get("localId"): variable.findtext("expression") for variable in ld_body.findall("LD/inVariable")}
    contacts = [variable.text for variable in ld_body.findall("LD/contact/variable")]

    assert invariables[source_ids["FilterTime"]] == "CST_FilterTime"
    assert "CST_FilterTime" not in contacts
    assert source_ids["ChannelOk"] == "0"

    local_ids = {element.get("localId") for element in ld_body.iter() if element.get("localId")}
    referenced_ids = {
        connection.get("refLocalId")
        for connection in ld_body.findall(".//connection")
        if connection.get("refLocalId") != "0"
    }
    assert referenced_ids <= local_ids


def test_inline_st_comment_does_not_merge_or_drop_next_fb_call() -> None:
    """A `; (* comment *)` must still terminate the preceding LD statement."""
    ld_body = build_ld_body(
        """
        instFirst(InputRaw := RawFirst, FilterTime := CST_FilterTime, ChannelOk := TRUE);
        FirstState := NOT instFirst.State; (* qualified state *)
        instSecond(InputRaw := RawSecond, FilterTime := CST_FilterTime, ChannelOk := TRUE);
        """,
        instance_types={"instFirst": "FB_Input", "instSecond": "FB_Input"},
        instance_input_types={
            "instFirst": {"InputRaw": "BOOL", "FilterTime": "TIME", "ChannelOk": "BOOL"},
            "instSecond": {"InputRaw": "BOOL", "FilterTime": "TIME", "ChannelOk": "BOOL"},
        },
    )

    assert [block.get("instanceName") for block in ld_body.findall("LD/block")] == [
        "instFirst",
        "instSecond",
    ]
