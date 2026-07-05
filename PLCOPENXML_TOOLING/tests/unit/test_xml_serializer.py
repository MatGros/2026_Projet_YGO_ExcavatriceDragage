import xml.etree.ElementTree as ET

from generator.xml_serializer import serialize, write_file


def _sample_tree() -> ET.Element:
    root = ET.Element("project")
    root.set("xmlns", "http://www.plcopen.org/xml/tc6_0200")
    child = ET.SubElement(root, "types")
    ET.SubElement(child, "dataTypes")
    empty = ET.SubElement(child, "pous")
    var = ET.SubElement(empty, "variable")
    var.set("name", "X")
    ET.SubElement(var, "BOOL")
    return root


def test_output_starts_with_utf8_bom():
    data = serialize(_sample_tree())
    assert data[:3] == b"\xef\xbb\xbf"


def test_xml_declaration_uses_double_quotes():
    data = serialize(_sample_tree())
    text = data[3:].decode("utf-8")
    assert text.startswith('<?xml version="1.0" encoding="utf-8"?>\n')
    assert "version='1.0'" not in text


def test_no_trailing_newline_after_closing_tag():
    data = serialize(_sample_tree())
    text = data.decode("utf-8-sig")
    assert text.endswith("</project>")
    assert not text.endswith("\n")


def test_no_crlf_line_endings():
    data = serialize(_sample_tree())
    assert b"\r\n" not in data


def test_self_closing_empty_element_has_space_before_slash():
    data = serialize(_sample_tree())
    text = data.decode("utf-8-sig")
    assert "<dataTypes />" in text


def test_indentation_is_two_spaces():
    data = serialize(_sample_tree())
    text = data.decode("utf-8-sig")
    lines = text.splitlines()
    indented = [line for line in lines if line.startswith("    <") and not line.startswith("     ")]
    assert indented  # at least one element sits at 2 levels (4 spaces) deep


def test_no_namespace_prefixes_leak_into_tags():
    data = serialize(_sample_tree())
    text = data.decode("utf-8-sig")
    assert "ns0:" not in text
    assert 'xmlns="http://www.plcopen.org/xml/tc6_0200"' in text


def test_write_file_roundtrips_bytes_and_creates_parent_dirs(tmp_path):
    target = tmp_path / "nested" / "dir" / "Out.xml"
    write_file(_sample_tree(), target)
    assert target.read_bytes() == serialize(_sample_tree())
