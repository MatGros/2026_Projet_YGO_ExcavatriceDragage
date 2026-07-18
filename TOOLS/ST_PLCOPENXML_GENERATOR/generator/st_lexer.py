from __future__ import annotations

from dataclasses import dataclass

# Token kinds produced by tokenize(). Concatenating every token's `text` in
# order always reproduces the original source exactly (round-trip invariant).
CODE = "code"
LINE_COMMENT = "line_comment"
BLOCK_COMMENT = "block_comment"
STRING = "string"

COMMENT_KINDS = (LINE_COMMENT, BLOCK_COMMENT)


@dataclass(frozen=True)
class Token:
    kind: str
    text: str
    line: int  # 1-based line number of the token's first character


def tokenize(source: str) -> list[Token]:
    tokens: list[Token] = []
    i = 0
    line = 1
    n = len(source)

    while i < n:
        two = source[i : i + 2]

        if two == "(*":
            end = source.find("*)", i + 2)
            text = source[i:] if end == -1 else source[i : end + 2]
            tokens.append(Token(BLOCK_COMMENT, text, line))
            line += text.count("\n")
            i += len(text)

        elif two == "//":
            end = source.find("\n", i)
            text = source[i:] if end == -1 else source[i:end]
            tokens.append(Token(LINE_COMMENT, text, line))
            i += len(text)
            # trailing '\n' (if any) is left for the next code chunk so it
            # stays part of the round-trip and line counting below.

        elif source[i] in ("'", '"'):
            quote = source[i]
            start_line = line
            j = i + 1
            while j < n:
                if source[j] == "$" and j + 1 < n:
                    j += 2
                    continue
                if source[j] == quote:
                    j += 1
                    break
                j += 1
            text = source[i:j]
            tokens.append(Token(STRING, text, start_line))
            line += text.count("\n")
            i = j

        else:
            start = i
            start_line = line
            j = i
            while j < n and source[j : j + 2] != "(*" and source[j : j + 2] != "//" and source[j] not in ("'", '"'):
                j += 1
            if j == start:
                j += 1
            text = source[start:j]
            tokens.append(Token(CODE, text, start_line))
            line += text.count("\n")
            i = j

    return tokens


def token_offsets(tokens: list[Token]) -> list[int]:
    """Character offset (into the original source) of each token's first character."""
    offsets: list[int] = []
    pos = 0
    for token in tokens:
        offsets.append(pos)
        pos += len(token.text)
    return offsets


def is_blank_code(token: Token) -> bool:
    return token.kind == CODE and token.text.strip() == ""


def mask(tokens: list[Token]) -> str:
    """Rebuild source-shaped text where comment/string tokens are blanked to
    spaces (newlines preserved) so keyword search stays alignment-safe with
    the original source, without a comment/string ever masquerading as a
    structural keyword."""
    parts: list[str] = []
    for token in tokens:
        if token.kind == CODE:
            parts.append(token.text)
        else:
            parts.append("".join(c if c == "\n" else " " for c in token.text))
    return "".join(parts)


def comment_text(token: Token) -> str:
    """Strip comment delimiters, return the inner text of a comment token."""
    if token.kind == LINE_COMMENT:
        return token.text[2:].strip()
    if token.kind == BLOCK_COMMENT:
        text = token.text
        if text.startswith("(*"):
            text = text[2:]
        if text.endswith("*)"):
            text = text[:-2]
        return text.strip()
    raise ValueError(f"not a comment token: {token.kind}")
