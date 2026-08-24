from TOOLS.converter.st_parser import parse_st_source


def test_region_pragmas_are_ignored_by_st_to_ld_parser() -> None:
    source = '''PROGRAM PRG_RegionDemo
VAR_OUTPUT
    Output : BOOL;
END_VAR

{region "§1 Source"}
Output := TRUE;
{endregion}
'''

    ast = parse_st_source(source)

    assert len(ast.statements) == 1
    assert ast.statements[0].target_var == "Output"
    assert ast.statements[0].expression == "TRUE"