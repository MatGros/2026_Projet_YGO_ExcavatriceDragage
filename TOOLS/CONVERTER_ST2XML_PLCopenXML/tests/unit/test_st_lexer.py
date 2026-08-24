import pytest

from generator.st_lexer import (
    BLOCK_COMMENT,
    CODE,
    LINE_COMMENT,
    STRING,
    Token,
    comment_text,
    is_blank_code,
    mask,
    token_offsets,
    tokenize,
)

from conftest import CODE_DIR


def _roundtrip(source: str) -> str:
    return "".join(t.text for t in tokenize(source))


def test_roundtrip_identity_for_plain_code():
    source = "VAR_INPUT\n    Enable : BOOL;\nEND_VAR\n"
    assert _roundtrip(source) == source


def test_line_comment_stops_at_newline():
    source = "Enable : BOOL; // active la logique\nReset : BOOL;\n"
    tokens = tokenize(source)
    kinds = [t.kind for t in tokens]
    assert LINE_COMMENT in kinds
    comment = next(t for t in tokens if t.kind == LINE_COMMENT)
    assert comment.text == "// active la logique"
    assert _roundtrip(source) == source


def test_block_comment_spans_multiple_lines_and_tracks_line_numbers():
    source = "A;\n(* ligne1\nligne2\nligne3 *)\nB;\n"
    tokens = tokenize(source)
    block = next(t for t in tokens if t.kind == BLOCK_COMMENT)
    assert block.line == 2
    assert block.text == "(* ligne1\nligne2\nligne3 *)"
    following_code = tokens[tokens.index(block) + 1]
    assert following_code.line == 4
    assert _roundtrip(source) == source


def test_double_slash_inside_block_comment_does_not_start_line_comment():
    source = "(* see // not a real comment start *)\nCODE;\n"
    tokens = tokenize(source)
    assert tokens[0].kind == BLOCK_COMMENT
    assert tokens[0].text == "(* see // not a real comment start *)"
    assert _roundtrip(source) == source


def test_block_comment_start_inside_line_comment_does_not_start_block_comment():
    source = "// contains (* not a block start\nCODE;\n"
    tokens = tokenize(source)
    assert tokens[0].kind == LINE_COMMENT
    assert tokens[0].text == "// contains (* not a block start"
    assert _roundtrip(source) == source


def test_quote_characters_inside_line_comment_do_not_start_a_string():
    source = "// don't parse this as a string\nCODE;\n"
    tokens = tokenize(source)
    assert tokens[0].kind == LINE_COMMENT
    assert "'" in tokens[0].text
    assert _roundtrip(source) == source


def test_comment_delimiters_inside_string_are_not_comments():
    source = "X := 'has // and (* inside';\n"
    tokens = tokenize(source)
    string_tok = next(t for t in tokens if t.kind == STRING)
    assert string_tok.text == "'has // and (* inside'"
    assert _roundtrip(source) == source


def test_wstring_double_quoted_literal():
    source = 'CycleStateStr := "ARRÊT : SÉCURITÉ ABSENTE";\n'
    tokens = tokenize(source)
    string_tok = next(t for t in tokens if t.kind == STRING)
    assert string_tok.text == '"ARRÊT : SÉCURITÉ ABSENTE"'
    assert _roundtrip(source) == source


def test_dollar_escape_inside_string_does_not_close_it_early():
    source = "X := 'it$'s fine';\n"
    tokens = tokenize(source)
    string_tok = next(t for t in tokens if t.kind == STRING)
    assert string_tok.text == "'it$'s fine'"
    assert _roundtrip(source) == source


def test_unterminated_block_comment_consumes_to_eof_without_crashing():
    source = "CODE;\n(* never closed"
    tokens = tokenize(source)
    assert tokens[-1].kind == BLOCK_COMMENT
    assert tokens[-1].text == "(* never closed"
    assert _roundtrip(source) == source


def test_unterminated_string_consumes_to_eof_without_crashing():
    source = "X := 'never closed"
    tokens = tokenize(source)
    assert tokens[-1].kind == STRING
    assert _roundtrip(source) == source


def test_mask_preserves_length_and_newlines_but_blanks_comments_and_strings():
    source = "A; // comment\n(* block *)\nB := 'str';\n"
    masked = mask(tokenize(source))
    assert len(masked) == len(source)
    assert masked.count("\n") == source.count("\n")
    assert "comment" not in masked
    assert "block" not in masked
    assert "str" not in masked
    assert "A;" in masked
    assert "B :=" in masked


def test_comment_text_strips_delimiters_line_and_block():
    line = Token(LINE_COMMENT, "// hello world", 1)
    block = Token(BLOCK_COMMENT, "(* hello block *)", 1)
    assert comment_text(line) == "hello world"
    assert comment_text(block) == "hello block"


def test_comment_text_rejects_non_comment_token():
    with pytest.raises(ValueError):
        comment_text(Token(CODE, "X", 1))


@pytest.mark.parametrize("st_file", sorted(CODE_DIR.rglob("*.st")), ids=lambda p: p.name)
def test_roundtrip_over_every_real_st_file(st_file):
    source = st_file.read_text(encoding="utf-8")
    assert _roundtrip(source) == source


def test_token_offsets_match_cumulative_lengths():
    source = "A;\n// c\n(* b *)\n'x';\n"
    tokens = tokenize(source)
    offsets = token_offsets(tokens)
    for offset, token in zip(offsets, tokens):
        assert source[offset : offset + len(token.text)] == token.text


def test_is_blank_code_true_for_whitespace_only():
    assert is_blank_code(Token(CODE, "  \n\t\n", 1))


def test_is_blank_code_false_for_real_code_or_other_kinds():
    assert not is_blank_code(Token(CODE, "END_VAR", 1))
    assert not is_blank_code(Token(LINE_COMMENT, "// x", 1))
