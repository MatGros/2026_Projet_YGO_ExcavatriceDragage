import uuid

from generator.guid import object_guid


def test_guid_is_deterministic_across_calls():
    assert object_guid("function_block", "FB_Winch") == object_guid("function_block", "FB_Winch")


def test_guid_differs_by_name():
    assert object_guid("function_block", "FB_Winch") != object_guid("function_block", "FB_Chariot")


def test_guid_differs_by_kind_for_same_name():
    assert object_guid("function_block", "X") != object_guid("struct", "X")


def test_guid_is_syntactically_valid_uuid():
    value = object_guid("gvl", "GVL_DEBUG")
    parsed = uuid.UUID(value)
    assert str(parsed) == value
