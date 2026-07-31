import pathlib
import sys

TOOLS_DIR = pathlib.Path(__file__).resolve().parents[2]
if str(TOOLS_DIR / 'core') not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR / 'core'))

import fb_gen


def test_extract_pou_interface_reads_inputs_and_outputs(tmp_path):
    xml_path = tmp_path / 'CODE_Bundle.xml'
    xml_path.write_text(
        '<?xml version="1.0"?>'
        '<root xmlns="http://www.plcopen.org/xml/tc6_0200">'
        '<pou name="FB_Test" pouType="functionBlock">'
        '<interface>'
        '<inputVars>'
        '<variable name="Enable"><type><BOOL /></type></variable>'
        '<variable name="Mode"><type><INT /></type></variable>'
        '</inputVars>'
        '<outputVars>'
        '<variable name="Ready"><type><BOOL /></type></variable>'
        '<variable name="ErrorId"><type><INT /></type></variable>'
        '</outputVars>'
        '</interface>'
        '</pou>'
        '</root>',
        encoding='utf-8',
    )

    interface = fb_gen.extract_pou_interface(str(xml_path), 'FB_Test')

    assert [var['name'] for var in interface['inputs']] == ['Enable', 'Mode']
    assert [var['python_type'] for var in interface['inputs']] == ['bool', 'int']
    assert [var['name'] for var in interface['outputs']] == ['Ready', 'ErrorId']
    assert interface['outputs'][0]['python_type'] == 'bool'
    assert interface['outputs'][1]['python_type'] == 'int'
