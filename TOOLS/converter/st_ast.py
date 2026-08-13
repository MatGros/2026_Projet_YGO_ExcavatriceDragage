"""Abstract Syntax Tree (AST) definitions for ST code and Ladder networks."""
from __future__ import annotations
from dataclasses import dataclass, field
from typing import Any


@dataclass
class VariableDecl:
    name: str
    data_type: str
    initial_value: str | None = None
    comment: str | None = None


@dataclass
class StatementAST:
    """Base class for parsed ST statements."""
    raw_text: str = ""


@dataclass
class FbCallAST(StatementAST):
    instance_name: str = ""
    fb_type: str = ""
    param_inputs: dict[str, str] = field(default_factory=dict)
    param_outputs: dict[str, list[str]] = field(default_factory=dict)


@dataclass
class BooleanNetworkAST(StatementAST):
    target_var: str = ""
    operator: str = "DIRECT"  # DIRECT, AND, OR
    operands: list[str] = field(default_factory=list)


@dataclass
class AssignmentAST(StatementAST):
    target_var: str = ""
    expression: str = ""


@dataclass
class ProgramAST:
    name: str
    pou_type: str = "program"
    inputs: list[VariableDecl] = field(default_factory=list)
    outputs: list[VariableDecl] = field(default_factory=list)
    locals: list[VariableDecl] = field(default_factory=list)
    inouts: list[VariableDecl] = field(default_factory=list)
    statements: list[StatementAST] = field(default_factory=list)
    documentation: str = ""
    unsupported_statements: list[str] = field(default_factory=list)
